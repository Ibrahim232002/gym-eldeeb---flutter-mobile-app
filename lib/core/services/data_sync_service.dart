import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../auth/auth_provider.dart';
import '../constants/supabase_constants.dart';
import '../network/network_info.dart';

import '../../data/models/member.dart';
import '../../data/models/membership_plan.dart';
import '../../data/models/membership.dart';
import '../../data/models/payment.dart';

/// Sync Status enumeration
enum SyncStatus { synced, syncing, offline, error }

/// Pending offline action representation
class PendingAction {
  final String id;
  final String table;
  final String action; // 'create', 'update', 'delete'
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  PendingAction({
    required this.id,
    required this.table,
    required this.action,
    required this.payload,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'table': table,
      'action': action,
      'payload': payload,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PendingAction.fromJson(Map<String, dynamic> json) {
    return PendingAction(
      id: json['id'] as String,
      table: json['table'] as String,
      action: json['action'] as String,
      payload: json['payload'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Provider for DataSyncService
final dataSyncServiceProvider = ChangeNotifierProvider<DataSyncService>((ref) {
  final supabase = Supabase.instance.client;
  final networkInfo = NetworkInfo();
  final authNotifier = ref.watch(authNotifierProvider);

  // Retrieve gymId from gym or fallback to profile gymId
  final gymId = authNotifier.gym?.id ?? authNotifier.profile?.gymId;
  final userId = authNotifier.profile?.id ?? supabase.auth.currentUser?.id;

  final service = DataSyncService(
    supabase: supabase,
    networkInfo: networkInfo,
    initialGymId: gymId,
    initialUserId: userId,
  );

  // Automatically trigger sync when network returns
  ref.listen(networkStatusProvider, (previous, next) {
    final status = next.asData?.value;
    if (status == NetworkStatus.online) {
      service.syncAll();
    }
  });

  return service;
});

/// Production Offline-First Data Sync & Local Caching Service
///
/// Implements local caches for members, plans, memberships, and payments using SharedPreferences,
/// manages a pending queue of offline creates/updates, and synchronizes with Supabase upon reconnection.
class DataSyncService extends ChangeNotifier {
  final SupabaseClient _supabase;
  final NetworkInfo _networkInfo;
  String? _gymId;
  String? _userId;

  SyncStatus _syncStatus = SyncStatus.synced;
  String? _syncErrorMessage;

  List<Member> _members = [];
  List<MembershipPlan> _plans = [];
  List<Membership> _memberships = [];
  List<Payment> _payments = [];

  DataSyncService({
    required SupabaseClient supabase,
    required NetworkInfo networkInfo,
    String? initialGymId,
    String? initialUserId,
  })  : _supabase = supabase,
        _networkInfo = networkInfo,
        _gymId = initialGymId,
        _userId = initialUserId {
    _loadAllFromLocalCache();
  }

  // --- Getters ---
  SyncStatus get syncStatus => _syncStatus;
  String? get syncErrorMessage => _syncErrorMessage;
  List<Member> get members => _members.where((m) => m.deletedAt == null).toList();
  List<MembershipPlan> get plans => _plans.where((p) => p.deletedAt == null).toList();
  List<Membership> get memberships => _memberships.where((m) => m.deletedAt == null).toList();
  List<Payment> get payments => _payments;

  bool get isOffline => _syncStatus == SyncStatus.offline;

  // --- Resolve Gym ID ---
  Future<String> requireGymId() async {
    if (_gymId != null && _gymId!.trim().isNotEmpty) {
      return _gymId!;
    }

    // 1. Check SharedPreferences cached profile
    final prefs = await SharedPreferences.getInstance();
    final cachedProfileStr = prefs.getString('cached_user_profile');
    if (cachedProfileStr != null) {
      try {
        final map = jsonDecode(cachedProfileStr);
        if (map['gym_id'] != null && (map['gym_id'] as String).isNotEmpty) {
          _gymId = map['gym_id'] as String;
          return _gymId!;
        }
      } catch (_) {}
    }

    // 2. Check SharedPreferences cached gym
    final cachedGymStr = prefs.getString('cached_user_gym');
    if (cachedGymStr != null) {
      try {
        final map = jsonDecode(cachedGymStr);
        if (map['id'] != null && (map['id'] as String).isNotEmpty) {
          _gymId = map['id'] as String;
          return _gymId!;
        }
      } catch (_) {}
    }

    // 3. Fallback: Query Supabase profiles table directly
    final currentUser = _supabase.auth.currentUser;
    if (currentUser != null) {
      try {
        final res = await _supabase.from('profiles').select('gym_id').eq('id', currentUser.id).maybeSingle();
        if (res != null && res['gym_id'] != null && (res['gym_id'] as String).isNotEmpty) {
          _gymId = res['gym_id'] as String;
          return _gymId!;
        }
      } catch (_) {}
    }

    throw Exception('لم يتم العثور على صالة جيم مرتبطة بهذا الحساب. يرجى الانضمام للجيم برمز الدعوة أولاً.');
  }

  // --- SharedPreferences Cache Keys ---
  String get _keyMembers => 'cache_members_${_gymId ?? "default"}';
  String get _keyPlans => 'cache_plans_${_gymId ?? "default"}';
  String get _keyMemberships => 'cache_memberships_${_gymId ?? "default"}';
  String get _keyPayments => 'cache_payments_${_gymId ?? "default"}';
  String get _keyPendingQueue => 'pending_queue_${_gymId ?? "default"}';

  // --- Initialize & Local Loading ---
  Future<void> _loadAllFromLocalCache() async {
    final prefs = await SharedPreferences.getInstance();

    // If _gymId is null, attempt to resolve from cached profile
    if (_gymId == null) {
      final cachedProfileStr = prefs.getString('cached_user_profile');
      if (cachedProfileStr != null) {
        try {
          final map = jsonDecode(cachedProfileStr);
          if (map['gym_id'] != null) _gymId = map['gym_id'] as String;
        } catch (_) {}
      }
    }

    // Members
    final membersStr = prefs.getString(_keyMembers);
    if (membersStr != null) {
      try {
        final list = jsonDecode(membersStr) as List<dynamic>;
        _members = list.map((item) => Member.fromJson(item as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    // Plans
    final plansStr = prefs.getString(_keyPlans);
    if (plansStr != null) {
      try {
        final list = jsonDecode(plansStr) as List<dynamic>;
        _plans = list.map((item) => MembershipPlan.fromJson(item as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    // Memberships
    final membershipsStr = prefs.getString(_keyMemberships);
    if (membershipsStr != null) {
      try {
        final list = jsonDecode(membershipsStr) as List<dynamic>;
        _memberships = list.map((item) => Membership.fromJson(item as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    // Payments
    final paymentsStr = prefs.getString(_keyPayments);
    if (paymentsStr != null) {
      try {
        final list = jsonDecode(paymentsStr) as List<dynamic>;
        _payments = list.map((item) => Payment.fromJson(item as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    notifyListeners();

    // Attempt initial sync if online
    final online = await _networkInfo.isConnected;
    if (online) {
      syncAll();
    } else {
      _syncStatus = SyncStatus.offline;
      notifyListeners();
    }
  }

  // --- Pending Queue Operations ---
  Future<List<PendingAction>> _getPendingQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyPendingQueue);
    if (str == null) return [];
    try {
      final list = jsonDecode(str) as List<dynamic>;
      return list.map((item) => PendingAction.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _savePendingQueue(List<PendingAction> queue) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(queue.map((item) => item.toJson()).toList());
    await prefs.setString(_keyPendingQueue, jsonStr);
  }

  Future<void> _addToQueue(String table, String action, Map<String, dynamic> payload) async {
    final queue = await _getPendingQueue();
    queue.add(PendingAction(
      id: const Uuid().v4(),
      table: table,
      action: action,
      payload: payload,
      createdAt: DateTime.now(),
    ));
    await _savePendingQueue(queue);
  }

  // --- Global Synchronization ---
  Future<void> syncAll() async {
    final online = await _networkInfo.isConnected;
    if (!online) {
      _syncStatus = SyncStatus.offline;
      notifyListeners();
      return;
    }

    try {
      final gymId = await requireGymId();
      _syncStatus = SyncStatus.syncing;
      _syncErrorMessage = null;
      notifyListeners();

      // 1. Process pending offline queue
      final queue = await _getPendingQueue();
      if (queue.isNotEmpty) {
        final remaining = <PendingAction>[];
        for (final item in queue) {
          try {
            await _executePendingActionOnRemote(item);
          } catch (_) {
            remaining.add(item);
          }
        }
        await _savePendingQueue(remaining);
      }

      // 2. Fetch fresh remote data and update local cache
      await _fetchRemoteData(gymId);

      _syncStatus = SyncStatus.synced;
    } catch (e) {
      _syncStatus = SyncStatus.error;
      _syncErrorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      notifyListeners();
    }
  }

  Future<void> _executePendingActionOnRemote(PendingAction action) async {
    var table = '';
    if (action.table == 'members') table = SupabaseConstants.tableMembers;
    else if (action.table == 'plans') table = SupabaseConstants.tableMembershipPlans;
    else if (action.table == 'memberships') table = SupabaseConstants.tableMemberships;
    else if (action.table == 'payments') table = SupabaseConstants.tablePayments;

    if (table.isEmpty) return;

    if (action.action == 'create') {
      await _supabase.from(table).upsert(action.payload);
    } else if (action.action == 'update') {
      await _supabase.from(table).update(action.payload).eq('id', action.payload['id'] as Object);
    } else if (action.action == 'delete') {
      await _supabase.from(table).update({
        'deleted_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', action.payload['id'] as Object);
    }
  }

  Future<void> _fetchRemoteData(String gymId) async {
    final prefs = await SharedPreferences.getInstance();

    // Fetch members
    final membersResponse = await _supabase
        .from(SupabaseConstants.tableMembers)
        .select()
        .eq('gym_id', gymId)
        .order('full_name', ascending: true);
    _members = (membersResponse as List).map((json) => Member.fromJson(json as Map<String, dynamic>)).toList();
    await prefs.setString(_keyMembers, jsonEncode(_members.map((m) => m.toJson()).toList()));

    // Fetch plans
    final plansResponse = await _supabase
        .from(SupabaseConstants.tableMembershipPlans)
        .select()
        .eq('gym_id', gymId)
        .order('name', ascending: true);
    _plans = (plansResponse as List).map((json) => MembershipPlan.fromJson(json as Map<String, dynamic>)).toList();
    await prefs.setString(_keyPlans, jsonEncode(_plans.map((p) => p.toJson()).toList()));

    // Fetch memberships
    final membershipsResponse = await _supabase
        .from(SupabaseConstants.tableMemberships)
        .select()
        .eq('gym_id', gymId)
        .order('start_date', ascending: false);
    _memberships = (membershipsResponse as List).map((json) => Membership.fromJson(json as Map<String, dynamic>)).toList();
    await prefs.setString(_keyMemberships, jsonEncode(_memberships.map((m) => m.toJson()).toList()));

    // Fetch payments
    final paymentsResponse = await _supabase
        .from(SupabaseConstants.tablePayments)
        .select()
        .eq('gym_id', gymId)
        .order('paid_at', ascending: false);
    _payments = (paymentsResponse as List).map((json) => Payment.fromJson(json as Map<String, dynamic>)).toList();
    await prefs.setString(_keyPayments, jsonEncode(_payments.map((p) => p.toJson()).toList()));
  }

  // ==========================================
  // --- BUSINESS CRUD OPERATIONS ---
  // ==========================================

  // --- Members CRUD ---

  Future<Member> addMember({
    required String fullName,
    String? phone,
    String? notes,
    required DateTime joinDate,
  }) async {
    final gymId = await requireGymId();

    final newMember = Member(
      id: const Uuid().v4(),
      gymId: gymId,
      fullName: fullName.trim(),
      phone: phone?.trim(),
      notes: notes?.trim(),
      joinDate: joinDate,
      isActive: true,
      createdBy: _userId ?? _supabase.auth.currentUser?.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncVersion: 1,
    );

    // 1. Immediately update in-memory list so UI updates instantly without restart
    _members = [newMember, ..._members.where((m) => m.id != newMember.id)];
    notifyListeners();

    // 2. Persist to local cache
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMembers, jsonEncode(_members.map((m) => m.toJson()).toList()));

    // 3. Persist to Supabase or queue if offline
    final online = await _networkInfo.isConnected;
    if (online) {
      try {
        await _supabase.from(SupabaseConstants.tableMembers).insert(newMember.toJson());
      } catch (e) {
        await _addToQueue('members', 'create', newMember.toJson());
      }
    } else {
      await _addToQueue('members', 'create', newMember.toJson());
      _syncStatus = SyncStatus.offline;
      notifyListeners();
    }

    return newMember;
  }

  Future<void> editMember(Member updated) async {
    final edited = updated.copyWith(updatedAt: DateTime.now());

    _members = _members.map((m) => m.id == edited.id ? edited : m).toList();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMembers, jsonEncode(_members.map((m) => m.toJson()).toList()));

    final online = await _networkInfo.isConnected;
    if (online) {
      try {
        await _supabase.from(SupabaseConstants.tableMembers).update(edited.toJson()).eq('id', edited.id);
      } catch (_) {
        await _addToQueue('members', 'update', edited.toJson());
      }
    } else {
      await _addToQueue('members', 'update', edited.toJson());
      _syncStatus = SyncStatus.offline;
      notifyListeners();
    }
  }

  Future<void> deleteMember(String id) async {
    _members = _members.map((m) => m.id == id ? m.copyWith(deletedAt: DateTime.now(), updatedAt: DateTime.now()) : m).toList();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMembers, jsonEncode(_members.map((m) => m.toJson()).toList()));

    final online = await _networkInfo.isConnected;
    if (online) {
      try {
        await _supabase.from(SupabaseConstants.tableMembers).update({
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', id);
      } catch (_) {
        await _addToQueue('members', 'delete', {'id': id});
      }
    } else {
      await _addToQueue('members', 'delete', {'id': id});
      _syncStatus = SyncStatus.offline;
      notifyListeners();
    }
  }

  // --- Plans CRUD ---

  Future<MembershipPlan> addPlan({
    required String name,
    required int durationDays,
    required double price,
  }) async {
    final gymId = await requireGymId();

    final newPlan = MembershipPlan(
      id: const Uuid().v4(),
      gymId: gymId,
      name: name.trim(),
      durationDays: durationDays,
      price: price,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _plans = [..._plans, newPlan];
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPlans, jsonEncode(_plans.map((p) => p.toJson()).toList()));

    final online = await _networkInfo.isConnected;
    if (online) {
      try {
        await _supabase.from(SupabaseConstants.tableMembershipPlans).insert(newPlan.toJson());
      } catch (_) {
        await _addToQueue('plans', 'create', newPlan.toJson());
      }
    } else {
      await _addToQueue('plans', 'create', newPlan.toJson());
      _syncStatus = SyncStatus.offline;
      notifyListeners();
    }

    return newPlan;
  }

  Future<void> editPlan(MembershipPlan updated) async {
    final edited = updated.copyWith(updatedAt: DateTime.now());

    _plans = _plans.map((p) => p.id == edited.id ? edited : p).toList();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPlans, jsonEncode(_plans.map((p) => p.toJson()).toList()));

    final online = await _networkInfo.isConnected;
    if (online) {
      try {
        await _supabase.from(SupabaseConstants.tableMembershipPlans).update(edited.toJson()).eq('id', edited.id);
      } catch (_) {
        await _addToQueue('plans', 'update', edited.toJson());
      }
    } else {
      await _addToQueue('plans', 'update', edited.toJson());
      _syncStatus = SyncStatus.offline;
      notifyListeners();
    }
  }

  Future<void> deletePlan(String id) async {
    _plans = _plans.map((p) => p.id == id ? p.copyWith(deletedAt: DateTime.now(), updatedAt: DateTime.now()) : p).toList();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPlans, jsonEncode(_plans.map((p) => p.toJson()).toList()));

    final online = await _networkInfo.isConnected;
    if (online) {
      try {
        await _supabase.from(SupabaseConstants.tableMembershipPlans).update({
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', id);
      } catch (_) {
        await _addToQueue('plans', 'delete', {'id': id});
      }
    } else {
      await _addToQueue('plans', 'delete', {'id': id});
      _syncStatus = SyncStatus.offline;
      notifyListeners();
    }
  }

  // --- Memberships CRUD ---

  Future<Membership> createMembership({
    required String memberId,
    required String? planId,
    required DateTime startDate,
    required DateTime endDate,
    required double price,
  }) async {
    final gymId = await requireGymId();

    final newMembership = Membership(
      id: const Uuid().v4(),
      gymId: gymId,
      memberId: memberId,
      planId: planId,
      startDate: startDate,
      endDate: endDate,
      price: price,
      status: 'active',
      createdBy: _userId ?? _supabase.auth.currentUser?.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _memberships = [newMembership, ..._memberships];
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMemberships, jsonEncode(_memberships.map((m) => m.toJson()).toList()));

    final online = await _networkInfo.isConnected;
    if (online) {
      try {
        await _supabase.from(SupabaseConstants.tableMemberships).insert(newMembership.toJson());
      } catch (_) {
        await _addToQueue('memberships', 'create', newMembership.toJson());
      }
    } else {
      await _addToQueue('memberships', 'create', newMembership.toJson());
      _syncStatus = SyncStatus.offline;
      notifyListeners();
    }
    return newMembership;
  }

  // --- Payments CRUD ---

  Future<Payment> recordPayment({
    required String? membershipId,
    required double amount,
    required String paymentMethod,
    required DateTime paidAt,
    String? notes,
  }) async {
    final gymId = await requireGymId();

    final newPayment = Payment(
      id: const Uuid().v4(),
      gymId: gymId,
      membershipId: membershipId,
      amount: amount,
      paymentMethod: paymentMethod,
      paidAt: paidAt,
      recordedBy: _userId ?? _supabase.auth.currentUser?.id,
      notes: notes?.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _payments = [newPayment, ..._payments];
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPayments, jsonEncode(_payments.map((p) => p.toJson()).toList()));

    final online = await _networkInfo.isConnected;
    if (online) {
      try {
        await _supabase.from(SupabaseConstants.tablePayments).insert(newPayment.toJson());
      } catch (_) {
        await _addToQueue('payments', 'create', newPayment.toJson());
      }
    } else {
      await _addToQueue('payments', 'create', newPayment.toJson());
      _syncStatus = SyncStatus.offline;
      notifyListeners();
    }

    return newPayment;
  }

  Future<void> editMembership(Membership updated) async {
    final edited = updated.copyWith(updatedAt: DateTime.now());

    _memberships = _memberships.map((m) => m.id == edited.id ? edited : m).toList();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMemberships, jsonEncode(_memberships.map((m) => m.toJson()).toList()));

    final online = await _networkInfo.isConnected;
    if (online) {
      try {
        await _supabase.from(SupabaseConstants.tableMemberships).update(edited.toJson()).eq('id', edited.id);
      } catch (_) {
        await _addToQueue('memberships', 'update', edited.toJson());
      }
    } else {
      await _addToQueue('memberships', 'update', edited.toJson());
      _syncStatus = SyncStatus.offline;
      notifyListeners();
    }
  }

  Future<void> deleteMembership(String id) async {
    final now = DateTime.now();
    _memberships = _memberships.where((m) => m.id != id).toList();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMemberships, jsonEncode(_memberships.map((m) => m.toJson()).toList()));

    final online = await _networkInfo.isConnected;
    if (online) {
      try {
        await _supabase.from(SupabaseConstants.tableMemberships).update({
          'deleted_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        }).eq('id', id);
      } catch (_) {
        await _addToQueue('memberships', 'delete', {'id': id});
      }
    } else {
      await _addToQueue('memberships', 'delete', {'id': id});
      _syncStatus = SyncStatus.offline;
      notifyListeners();
    }
  }

  Future<void> editPayment(Payment updated) async {
    final edited = updated.copyWith(updatedAt: DateTime.now());

    _payments = _payments.map((p) => p.id == edited.id ? edited : p).toList();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPayments, jsonEncode(_payments.map((p) => p.toJson()).toList()));

    final online = await _networkInfo.isConnected;
    if (online) {
      try {
        await _supabase.from(SupabaseConstants.tablePayments).update(edited.toJson()).eq('id', edited.id);
      } catch (_) {
        await _addToQueue('payments', 'update', edited.toJson());
      }
    } else {
      await _addToQueue('payments', 'update', edited.toJson());
      _syncStatus = SyncStatus.offline;
      notifyListeners();
    }
  }

  Future<void> deletePayment(String id) async {
    _payments = _payments.where((p) => p.id != id).toList();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPayments, jsonEncode(_payments.map((p) => p.toJson()).toList()));

    final online = await _networkInfo.isConnected;
    if (online) {
      try {
        await _supabase.from(SupabaseConstants.tablePayments).delete().eq('id', id);
      } catch (_) {
        await _addToQueue('payments', 'delete', {'id': id});
      }
    } else {
      await _addToQueue('payments', 'delete', {'id': id});
      _syncStatus = SyncStatus.offline;
      notifyListeners();
    }
  }

  Future<void> updateGymInfo({
    required String name,
    String? phone,
    required String currency,
  }) async {
    final gymId = await requireGymId();
    final updateData = {
      'name': name.trim(),
      'phone': phone?.trim(),
      'currency': currency.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_user_gym', jsonEncode({'id': gymId, ...updateData}));

    final online = await _networkInfo.isConnected;
    if (online) {
      await _supabase.from(SupabaseConstants.tableGyms).update(updateData).eq('id', gymId);
    }
    notifyListeners();
  }

  Future<void> updateProfileName(String newFullName) async {
    final userId = _userId ?? _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('المستخدم غير مسجل');

    final updateData = {
      'full_name': newFullName.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    final prefs = await SharedPreferences.getInstance();
    final cachedProfileStr = prefs.getString('cached_user_profile');
    if (cachedProfileStr != null) {
      try {
        final map = jsonDecode(cachedProfileStr);
        map['full_name'] = newFullName.trim();
        await prefs.setString('cached_user_profile', jsonEncode(map));
      } catch (_) {}
    }

    final online = await _networkInfo.isConnected;
    if (online) {
      await _supabase.from(SupabaseConstants.tableProfiles).update(updateData).eq('id', userId);
    }
    notifyListeners();
  }
}
