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
  final String ownerUserId;
  final String action; // 'create', 'update', 'delete'
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;

  PendingAction({
    required this.id,
    required this.table,
    required this.ownerUserId,
    required this.action,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'table': table,
      'ownerUserId': ownerUserId,
      'action': action,
      'payload': payload,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
      'lastError': lastError,
    };
  }

  factory PendingAction.fromJson(Map<String, dynamic> json) {
    return PendingAction(
      id: json['id'] as String,
      table: json['table'] as String,
      // Older queued actions may not contain an owner. Keep them unclaimed rather than
      // assigning them to whichever account happens to sign in next.
      ownerUserId: json['ownerUserId'] as String? ?? '',
      action: json['action'] as String,
      payload: json['payload'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      lastError: json['lastError'] as String?,
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
  bool _syncInProgress = false;

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
  final Map<String, String> _creatorNames = {};
  String creatorName(String? userId) => userId == null ? 'غير معروف' : (_creatorNames[userId] ?? 'عضو من فريق الجيم');

  bool get isOffline => _syncStatus == SyncStatus.offline;
  static const int _maxAutomaticRetries = 5;

  bool _isPermanentSyncError(Object error) {
    if (error is PostgrestException) {
      const permanentCodes = {
        '42501', // insufficient_privilege / RLS
        '42703', // undefined_column
        '42P01', // undefined_table
        '23502', // not_null_violation
        '23503', // foreign_key_violation
        '23514', // check_violation
        '23522', // numeric_value_out_of_range
      };
      return permanentCodes.contains(error.code);
    }
    return false;
  }

  // Prefer the live authenticated identity over the provider's cached profile.
  String? get _actorUserId => _supabase.auth.currentUser?.id ?? _userId;

  // --- Resolve Gym ID ---
  Future<String> requireGymId() async {
    if (_gymId != null && _gymId!.trim().isNotEmpty) {
      return _gymId!;
    }

    // Resolve identity before consulting any persisted profile data. Never trust
    // a cached gym association when it cannot be tied to the active account.
    final currentUser = _supabase.auth.currentUser;
    final expectedUserId = currentUser?.id ?? _userId;
    if (expectedUserId == null || expectedUserId.isEmpty) {
      throw Exception('المستخدم غير مسجل');
    }

    final prefs = await SharedPreferences.getInstance();
    final cachedProfileStr = prefs.getString('cached_user_profile');
    if (cachedProfileStr != null) {
      try {
        final map = jsonDecode(cachedProfileStr) as Map<String, dynamic>;
        if (map['id'] == expectedUserId && map['gym_id'] is String && (map['gym_id'] as String).isNotEmpty) {
          _gymId = map['gym_id'] as String;
          return _gymId!;
        }
      } catch (_) {}
    }

    // Query the authenticated user's profile; cached gym data has no reliable
    // ownership marker and is deliberately not used as an identity fallback.
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
  String get _keyPendingQueue => 'pending_queue_${_userId ?? "unclaimed"}_${_gymId ?? "default"}';

  // --- Initialize & Local Loading ---
  Future<void> _loadAllFromLocalCache() async {
    final prefs = await SharedPreferences.getInstance();

    // Only use a cached association when its profile belongs to the active user.
    if (_gymId == null) {
      final activeUserId = _supabase.auth.currentUser?.id ?? _userId;
      final cachedProfileStr = prefs.getString('cached_user_profile');
      if (activeUserId != null && cachedProfileStr != null) {
        try {
          final map = jsonDecode(cachedProfileStr) as Map<String, dynamic>;
          if (map['id'] == activeUserId && map['gym_id'] is String && (map['gym_id'] as String).isNotEmpty) {
            _gymId = map['gym_id'] as String;
          }
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
    } catch (e) {
      // Never treat unreadable persisted work as an empty queue: callers must
      // stop before saving, otherwise this could overwrite and destroy it.
      throw FormatException('تعذر قراءة العمليات المحلية المعلقة؛ تم الحفاظ على البيانات الأصلية.', e);
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
      ownerUserId: _userId ?? _supabase.auth.currentUser?.id ?? (throw StateError('لا يمكن حفظ عملية بدون حساب مسجل')),
      action: action,
      payload: payload,
      createdAt: DateTime.now(),
    ));
    await _savePendingQueue(queue);
  }

  // --- Global Synchronization ---
  Future<void> syncAll({bool forceRetry = false}) async {
    if (_syncInProgress) return;
    _syncInProgress = true;

    try {
      final online = await _networkInfo.isConnected;
      if (!online) {
        _syncStatus = SyncStatus.offline;
        notifyListeners();
        return;
      }

      final gymId = await requireGymId();
      _syncStatus = SyncStatus.syncing;
      _syncErrorMessage = null;
      notifyListeners();

      final queue = await _getPendingQueue();
      final remaining = <PendingAction>[];
      var failedCount = 0;
      var blockedCount = 0;

      for (final item in queue) {
        final activeUserId = _supabase.auth.currentUser?.id;
        if (activeUserId == null || activeUserId != item.ownerUserId) {
          // Keep the operation intact; never replay one account's queue as another.
          remaining.add(item);
          blockedCount++;
          continue;
        }
        if (!forceRetry && item.retryCount >= _maxAutomaticRetries) {
          remaining.add(item);
          blockedCount++;
          continue;
        }

        try {
          await _executePendingActionOnRemote(item);
        } catch (e) {
          final permanent = _isPermanentSyncError(e);
          final retryCount = permanent
              ? _maxAutomaticRetries
              : item.retryCount + 1;
          remaining.add(PendingAction(
            id: item.id,
            table: item.table,
            ownerUserId: item.ownerUserId,
            action: item.action,
            payload: item.payload,
            createdAt: item.createdAt,
            retryCount: retryCount,
            lastError: e.toString(),
          ));
          failedCount++;
        }
      }

      await _savePendingQueue(remaining);

      // Do not replace optimistic local records while a queued write is still
      // failing. Once the queue is clear, refresh from the authoritative source.
      if (failedCount == 0 && blockedCount == 0) {
        await _fetchRemoteData(gymId);
        _syncStatus = SyncStatus.synced;
      } else {
        _syncStatus = SyncStatus.error;
        if (blockedCount > 0) {
          _syncErrorMessage =
              'هناك $blockedCount عملية معلقة لم تُنفذ: قد تكون لحساب آخر، أو تحتاج إعادة محاولة يدوية، أو بياناتها القديمة بلا مالك محدد. لم يتم حذفها.';
        } else {
          _syncErrorMessage =
              'تعذر مزامنة $failedCount عملية. ستتم إعادة المحاولة تلقائياً للأخطاء المؤقتة.';
        }
      }
    } catch (e) {
      _syncStatus = SyncStatus.error;
      _syncErrorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _syncInProgress = false;
      notifyListeners();
    }
  }

  Future<void> _executePendingActionOnRemote(PendingAction action) async {
    var table = '';
    if (action.table == 'members') table = SupabaseConstants.tableMembers;
    else if (action.table == 'plans') table = SupabaseConstants.tableMembershipPlans;
    else if (action.table == 'memberships') table = SupabaseConstants.tableMemberships;
    else if (action.table == 'payments') table = SupabaseConstants.tablePayments;

    if (table.isEmpty) {
      throw StateError('Unsupported pending sync table: ${action.table}');
    }

    if (action.action == 'create') {
      await _supabase.from(table).upsert(action.payload);
    } else if (action.action == 'update') {
      await _supabase.from(table).update(action.payload).eq('id', action.payload['id'] as Object);
    } else if (action.action == 'delete') {
      if (action.table == 'payments') {
        await _supabase.from(table).delete().eq('id', action.payload['id'] as Object);
      } else {
        await _supabase.from(table).update({
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', action.payload['id'] as Object);
      }
    } else {
      throw StateError('Unsupported pending sync action: ${action.action}');
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

    // Resolve actor names for the audit labels shown in the app.
    final actorIds = <String>{
      ..._members.map((item) => item.createdBy).whereType<String>(),
      ..._memberships.map((item) => item.createdBy).whereType<String>(),
      ..._payments.map((item) => item.recordedBy).whereType<String>(),
    }.toList();
    if (actorIds.isNotEmpty) {
      try {
        final profiles = await _supabase.from('profiles').select('id, full_name').inFilter('id', actorIds);
        for (final row in profiles as List) {
          final id = row['id'] as String?;
          final name = row['full_name'] as String?;
          if (id != null && name != null && name.trim().isNotEmpty) _creatorNames[id] = name.trim();
        }
      } catch (_) {
        // Keep the UI usable if profile-name lookup is unavailable.
      }
    }
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
      createdBy: _actorUserId,
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
        await _supabase.from(SupabaseConstants.tableMembers).upsert(newMember.toJson());
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
      } on PostgrestException {
        rethrow;
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
      } on PostgrestException {
        rethrow;
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
        await _supabase.from(SupabaseConstants.tableMembershipPlans).upsert(newPlan.toJson());
      } on PostgrestException {
        rethrow;
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
      } on PostgrestException {
        rethrow;
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
      } on PostgrestException {
        rethrow;
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
      createdBy: _actorUserId,
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
        await _supabase.from(SupabaseConstants.tableMemberships).upsert(newMembership.toJson());
      } on PostgrestException {
        rethrow;
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
      recordedBy: _actorUserId,
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
        await _supabase.from(SupabaseConstants.tablePayments).upsert(newPayment.toJson());
      } on PostgrestException {
        rethrow;
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
      } on PostgrestException {
        rethrow;
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
      } on PostgrestException {
        rethrow;
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
      } on PostgrestException {
        rethrow;
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
      } on PostgrestException {
        rethrow;
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
