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

class DuplicateActiveMembershipException implements Exception {
  const DuplicateActiveMembershipException();

  @override
  String toString() => 'هذا العضو لديه اشتراك ساري خلال هذه الفترة.';
}

class MembershipCreationGuard {
  final Set<String> _inFlightMemberIds = {};

  Future<T> run<T>(String memberId, Future<T> Function() operation) async {
    if (!_inFlightMemberIds.add(memberId)) {
      throw const DuplicateActiveMembershipException();
    }
    try {
      return await operation();
    } finally {
      _inFlightMemberIds.remove(memberId);
    }
  }
}

class MembershipCreationResult {
  final Membership membership;
  final bool isPending;

  const MembershipCreationResult({
    required this.membership,
    required this.isPending,
  });
}

/// Pending offline action representation
class PendingAction {
  final String id;
  final String table;
  final String action; // 'create', 'update', 'delete'
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;

  PendingAction({
    required this.id,
    required this.table,
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
      action: json['action'] as String,
      payload: json['payload'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      lastError: json['lastError'] as String?,
    );
  }
}

List<PendingAction> decodePendingActions(String? encodedQueue) {
  if (encodedQueue == null) return [];
  try {
    final list = jsonDecode(encodedQueue) as List<dynamic>;
    return list
        .map((item) => PendingAction.fromJson(item as Map<String, dynamic>))
        .toList();
  } catch (error) {
    throw FormatException(
      'تعذر قراءة قائمة العمليات المعلقة. تم الاحتفاظ بالبيانات الأصلية دون تغيير.',
      error,
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
  final String? _userId;

  SyncStatus _syncStatus = SyncStatus.syncing;
  String? _syncErrorMessage;
  bool _syncInProgress = false;
  final MembershipCreationGuard _membershipCreationGuard =
      MembershipCreationGuard();

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
  String? get gymId => _gymId;
  List<Member> get members =>
      _members.where((m) => m.deletedAt == null).toList();
  List<MembershipPlan> get plans =>
      _plans.where((p) => p.deletedAt == null).toList();
  List<MembershipPlan> get activePlans => selectableMembershipPlans(_plans);
  List<Membership> get memberships =>
      _memberships.where((m) => m.deletedAt == null).toList();
  List<Payment> get payments => _payments;
  final Map<String, String> _creatorNames = {};
  String creatorName(String? userId) => userId == null
      ? 'غير معروف'
      : (_creatorNames[userId] ?? 'عضو من فريق الجيم');

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
        '23P01', // exclusion_violation: overlapping active membership
        '22023', // invalid idempotency request
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
        if (map['id'] == expectedUserId &&
            map['gym_id'] is String &&
            (map['gym_id'] as String).isNotEmpty) {
          _gymId = map['gym_id'] as String;
          return _gymId!;
        }
      } catch (_) {}
    }

    // Query the authenticated user's profile; cached gym data has no reliable
    // ownership marker and is deliberately not used as an identity fallback.
    if (currentUser != null) {
      try {
        final res = await _supabase
            .from('profiles')
            .select('gym_id')
            .eq('id', currentUser.id)
            .maybeSingle();
        if (res != null &&
            res['gym_id'] != null &&
            (res['gym_id'] as String).isNotEmpty) {
          _gymId = res['gym_id'] as String;
          return _gymId!;
        }
      } catch (_) {}
    }

    throw Exception(
        'لم يتم العثور على صالة جيم مرتبطة بهذا الحساب. يرجى الانضمام للجيم برمز الدعوة أولاً.');
  }

  // --- SharedPreferences Cache Keys ---
  String get _keyMembers => 'cache_members_${_gymId ?? "default"}';
  String get _keyPlans => 'cache_plans_${_gymId ?? "default"}';
  String get _keyMemberships => 'cache_memberships_${_gymId ?? "default"}';
  String get _keyPayments => 'cache_payments_${_gymId ?? "default"}';
  String get _keyPendingQueue => 'pending_queue_${_gymId ?? "default"}';

  // --- Initialize & Local Loading ---
  Future<void> _loadAllFromLocalCache() async {
    late final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (error) {
      _setInitialLoadError(error);
      return;
    }

    // Only use a cached association when its profile belongs to the active user.
    if (_gymId == null) {
      final activeUserId = _supabase.auth.currentUser?.id ?? _userId;
      final cachedProfileStr = prefs.getString('cached_user_profile');
      if (activeUserId != null && cachedProfileStr != null) {
        try {
          final map = jsonDecode(cachedProfileStr) as Map<String, dynamic>;
          if (map['id'] == activeUserId &&
              map['gym_id'] is String &&
              (map['gym_id'] as String).isNotEmpty) {
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
        _members = list
            .map((item) => Member.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    // Plans
    final plansStr = prefs.getString(_keyPlans);
    if (plansStr != null) {
      try {
        final list = jsonDecode(plansStr) as List<dynamic>;
        _plans = list
            .map(
                (item) => MembershipPlan.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    // Memberships
    final membershipsStr = prefs.getString(_keyMemberships);
    if (membershipsStr != null) {
      try {
        final list = jsonDecode(membershipsStr) as List<dynamic>;
        _memberships = list
            .map((item) => Membership.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    // Payments
    final paymentsStr = prefs.getString(_keyPayments);
    if (paymentsStr != null) {
      try {
        final list = jsonDecode(paymentsStr) as List<dynamic>;
        _payments = list
            .map((item) => Payment.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    notifyListeners();

    // Attempt initial sync if online
    late final bool online;
    try {
      online = await _networkInfo.isConnected;
    } catch (error) {
      _setInitialLoadError(error);
      return;
    }
    if (online) {
      syncAll();
    } else {
      _syncStatus = SyncStatus.offline;
      notifyListeners();
    }
  }

  void _setInitialLoadError(Object error) {
    _syncStatus = SyncStatus.error;
    _syncErrorMessage = error.toString().replaceAll('Exception: ', '');
    notifyListeners();
  }

  // --- Pending Queue Operations ---
  Future<List<PendingAction>> _getPendingQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyPendingQueue);
    return decodePendingActions(str);
  }

  Future<void> _savePendingQueue(List<PendingAction> queue) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(queue.map((item) => item.toJson()).toList());
    await prefs.setString(_keyPendingQueue, jsonStr);
  }

  Future<void> _addToQueue(
      String table, String action, Map<String, dynamic> payload) async {
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

  Future<void> _queuePendingWrite(
    String table,
    String action,
    Map<String, dynamic> payload, {
    Object? error,
  }) async {
    await _addToQueue(table, action, payload);
    _syncStatus = error == null ? SyncStatus.offline : SyncStatus.error;
    _syncErrorMessage = error == null
        ? 'تم حفظ التغييرات محلياً، وستتم مزامنتها عند توفر الاتصال.'
        : 'تعذر تأكيد التغيير من الخادم، وحُفظ محلياً لإعادة المحاولة: $error';
    notifyListeners();
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
      var duplicateMembershipCount = 0;

      for (final item in queue) {
        if (!forceRetry && item.retryCount >= _maxAutomaticRetries) {
          remaining.add(item);
          blockedCount++;
          if (item.lastError?.contains('23P01') == true ||
              item.lastError?.contains('ACTIVE_MEMBERSHIP_OVERLAP') == true) {
            duplicateMembershipCount++;
          }
          continue;
        }

        try {
          await _executePendingActionOnRemote(item);
        } catch (e) {
          if (e is PostgrestException && e.code == '23P01') {
            duplicateMembershipCount++;
          }
          final permanent = _isPermanentSyncError(e);
          final retryCount =
              permanent ? _maxAutomaticRetries : item.retryCount + 1;
          remaining.add(PendingAction(
            id: item.id,
            table: item.table,
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
        if (duplicateMembershipCount > 0) {
          _syncErrorMessage =
              'تعذر تأكيد اشتراك معلّق لأن للعضو اشتراكاً سارياً في الفترة نفسها. راجع الطلب قبل إعادة المحاولة.';
        } else if (blockedCount > 0) {
          _syncErrorMessage =
              'هناك $blockedCount عملية معلقة بسبب خطأ دائم. راجع الصلاحيات أو البيانات ثم استخدم المزامنة اليدوية لإعادة المحاولة.';
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
    if (action.table == 'members' &&
        action.action == 'update_with_photo_cleanup') {
      final memberPayload = action.payload['member'] as Map<String, dynamic>;
      final photoPath = action.payload['photo_path_to_delete'] as String;
      await _supabase
          .from(SupabaseConstants.tableMembers)
          .update(memberPayload)
          .eq('id', memberPayload['id'] as Object);
      await deleteMemberPhoto(photoPath);
      return;
    }

    if (action.table == 'membership_bundle' &&
        action.action == 'create_with_initial_payment') {
      final rawMembership =
          action.payload['membership'] as Map<String, dynamic>;
      final queuedMembership = Membership.fromJson(rawMembership);
      final queuedPlanId = queuedMembership.planId;
      if (queuedPlanId != null) {
        final activePlan = await _supabase
            .from(SupabaseConstants.tableMembershipPlans)
            .select('id')
            .eq('id', queuedPlanId)
            .eq('is_active', true)
            .isFilter('deleted_at', null)
            .maybeSingle();
        if (activePlan == null) {
          throw StateError(
              'تعذر مزامنة الاشتراك لأن الباقة أصبحت معطلة أو محذوفة.');
        }
      }
      await _supabase.rpc<Map<String, dynamic>>(
        'create_membership_with_initial_payment',
        params: {
          'p_membership': action.payload['membership'],
          'p_payment': action.payload['payment'],
        },
      );
      return;
    }

    var table = '';
    if (action.table == 'members') {
      table = SupabaseConstants.tableMembers;
    } else if (action.table == 'plans')
      table = SupabaseConstants.tableMembershipPlans;
    else if (action.table == 'memberships')
      table = SupabaseConstants.tableMemberships;
    else if (action.table == 'payments')
      table = SupabaseConstants.tablePayments;
    else if (action.table == 'gyms')
      table = SupabaseConstants.tableGyms;
    else if (action.table == 'profiles')
      table = SupabaseConstants.tableProfiles;

    if (table.isEmpty) {
      throw StateError('Unsupported pending sync table: ${action.table}');
    }

    if (action.action == 'create') {
      await _supabase.from(table).upsert(action.payload);
    } else if (action.action == 'update') {
      await _supabase
          .from(table)
          .update(action.payload)
          .eq('id', action.payload['id'] as Object);
    } else if (action.action == 'delete') {
      if (action.table == 'payments') {
        await _supabase
            .from(table)
            .delete()
            .eq('id', action.payload['id'] as Object);
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
    _members = (membersResponse as List)
        .map((json) => Member.fromJson(json as Map<String, dynamic>))
        .toList();
    await prefs.setString(
        _keyMembers, jsonEncode(_members.map((m) => m.toJson()).toList()));

    // Fetch plans
    final plansResponse = await _supabase
        .from(SupabaseConstants.tableMembershipPlans)
        .select()
        .eq('gym_id', gymId)
        .order('name', ascending: true);
    _plans = (plansResponse as List)
        .map((json) => MembershipPlan.fromJson(json as Map<String, dynamic>))
        .toList();
    await prefs.setString(
        _keyPlans, jsonEncode(_plans.map((p) => p.toJson()).toList()));

    // Fetch memberships
    final membershipsResponse = await _supabase
        .from(SupabaseConstants.tableMemberships)
        .select()
        .eq('gym_id', gymId)
        .order('start_date', ascending: false);
    _memberships = (membershipsResponse as List)
        .map((json) => Membership.fromJson(json as Map<String, dynamic>))
        .toList();
    await prefs.setString(_keyMemberships,
        jsonEncode(_memberships.map((m) => m.toJson()).toList()));

    // Fetch payments
    final paymentsResponse = await _supabase
        .from(SupabaseConstants.tablePayments)
        .select()
        .eq('gym_id', gymId)
        .order('paid_at', ascending: false);
    _payments = (paymentsResponse as List)
        .map((json) => Payment.fromJson(json as Map<String, dynamic>))
        .toList();
    await prefs.setString(
        _keyPayments, jsonEncode(_payments.map((p) => p.toJson()).toList()));

    // Resolve actor names for the audit labels shown in the app.
    final actorIds = <String>{
      ..._members.map((item) => item.createdBy).whereType<String>(),
      ..._memberships.map((item) => item.createdBy).whereType<String>(),
      ..._payments.map((item) => item.recordedBy).whereType<String>(),
    }.toList();
    if (actorIds.isNotEmpty) {
      try {
        final profiles = await _supabase
            .from('profiles')
            .select('id, full_name')
            .inFilter('id', actorIds);
        for (final row in profiles as List) {
          final id = row['id'] as String?;
          final name = row['full_name'] as String?;
          if (id != null && name != null && name.trim().isNotEmpty)
            _creatorNames[id] = name.trim();
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
    Uint8List? photoBytes,
    String photoExtension = 'jpg',
  }) async {
    final gymId = await requireGymId();
    final memberId = const Uuid().v4();
    final photoPath = photoBytes == null
        ? null
        : await uploadMemberPhoto(
            memberId: memberId,
            photoBytes: photoBytes,
            extension: photoExtension,
          );

    final newMember = Member(
      id: memberId,
      gymId: gymId,
      fullName: fullName.trim(),
      phone: phone?.trim(),
      notes: notes?.trim(),
      photoPath: photoPath,
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
    await prefs.setString(
        _keyMembers, jsonEncode(_members.map((m) => m.toJson()).toList()));

    // 3. Persist to Supabase or queue if offline
    final online = await _networkInfo.isConnected;
    if (online) {
      try {
        await _supabase
            .from(SupabaseConstants.tableMembers)
            .upsert(newMember.toJson());
      } catch (e) {
        await _queuePendingWrite(
          'members',
          'create',
          newMember.toJson(),
          error: e,
        );
      }
    } else {
      await _queuePendingWrite('members', 'create', newMember.toJson());
    }

    return newMember;
  }

  Future<bool> editMember(
    Member updated, {
    String? photoPathToDelete,
  }) async {
    final edited = updated.copyWith(updatedAt: DateTime.now());

    _members = _members.map((m) => m.id == edited.id ? edited : m).toList();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyMembers, jsonEncode(_members.map((m) => m.toJson()).toList()));

    final online = await _networkInfo.isConnected;
    var persistedRemotely = false;
    if (online) {
      try {
        await _supabase
            .from(SupabaseConstants.tableMembers)
            .update(edited.toJson())
            .eq('id', edited.id);
        if (photoPathToDelete != null) {
          await deleteMemberPhoto(photoPathToDelete);
        }
        persistedRemotely = true;
      } catch (error) {
        await _queueMemberUpdate(
          edited,
          photoPathToDelete: photoPathToDelete,
          error: error,
        );
      }
    } else {
      await _queueMemberUpdate(
        edited,
        photoPathToDelete: photoPathToDelete,
      );
    }
    return persistedRemotely;
  }

  Future<void> _queueMemberUpdate(
    Member member, {
    String? photoPathToDelete,
    Object? error,
  }) async {
    if (photoPathToDelete == null) {
      await _queuePendingWrite('members', 'update', member.toJson(),
          error: error);
      return;
    }
    await _queuePendingWrite(
      'members',
      'update_with_photo_cleanup',
      {
        'member': member.toJson(),
        'photo_path_to_delete': photoPathToDelete,
      },
      error: error,
    );
  }

  Future<String> uploadMemberPhoto({
    required String memberId,
    required Uint8List photoBytes,
    String extension = 'jpg',
  }) async {
    if (photoBytes.isEmpty) {
      throw ArgumentError.value(photoBytes, 'photoBytes', 'الصورة فارغة.');
    }
    final normalizedExtension = extension.toLowerCase();
    if (normalizedExtension != 'jpg' && normalizedExtension != 'jpeg') {
      throw ArgumentError.value(
        extension,
        'extension',
        'صيغة الصورة غير مدعومة.',
      );
    }
    final gymId = await requireGymId();
    final path = '$gymId/$memberId.$normalizedExtension';
    await _supabase.storage
        .from(SupabaseConstants.bucketMemberPhotos)
        .uploadBinary(
          path,
          photoBytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    return path;
  }

  Future<void> deleteMemberPhoto(String photoPath) async {
    final gymId = await requireGymId();
    if (!photoPath.startsWith('$gymId/')) {
      throw ArgumentError.value(
        photoPath,
        'photoPath',
        'لا يمكن الوصول إلى صور صالة أخرى.',
      );
    }
    await _supabase.storage
        .from(SupabaseConstants.bucketMemberPhotos)
        .remove([photoPath]);
  }

  Future<void> deleteMember(String id) async {
    _members = _members
        .map((m) => m.id == id
            ? m.copyWith(deletedAt: DateTime.now(), updatedAt: DateTime.now())
            : m)
        .toList();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyMembers, jsonEncode(_members.map((m) => m.toJson()).toList()));

    final online = await _networkInfo.isConnected;
    if (online) {
      try {
        await _supabase.from(SupabaseConstants.tableMembers).update({
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', id);
      } catch (error) {
        await _queuePendingWrite(
          'members',
          'delete',
          {'id': id},
          error: error,
        );
      }
    } else {
      await _queuePendingWrite('members', 'delete', {'id': id});
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
    await prefs.setString(
        _keyPlans, jsonEncode(_plans.map((p) => p.toJson()).toList()));

    final online = await _networkInfo.isConnected;
    if (online) {
      try {
        await _supabase
            .from(SupabaseConstants.tableMembershipPlans)
            .upsert(newPlan.toJson());
      } catch (error) {
        await _queuePendingWrite(
          'plans',
          'create',
          newPlan.toJson(),
          error: error,
        );
      }
    } else {
      await _queuePendingWrite('plans', 'create', newPlan.toJson());
    }

    return newPlan;
  }

  Future<void> editPlan(MembershipPlan updated) async {
    final edited = updated.copyWith(updatedAt: DateTime.now());

    _plans = _plans.map((p) => p.id == edited.id ? edited : p).toList();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyPlans, jsonEncode(_plans.map((p) => p.toJson()).toList()));

    final online = await _networkInfo.isConnected;
    if (online) {
      try {
        await _supabase
            .from(SupabaseConstants.tableMembershipPlans)
            .update(edited.toJson())
            .eq('id', edited.id);
      } catch (error) {
        await _queuePendingWrite(
          'plans',
          'update',
          edited.toJson(),
          error: error,
        );
      }
    } else {
      await _queuePendingWrite('plans', 'update', edited.toJson());
    }
  }

  Future<void> deletePlan(String id) async {
    _plans = _plans
        .map((p) => p.id == id
            ? p.copyWith(deletedAt: DateTime.now(), updatedAt: DateTime.now())
            : p)
        .toList();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyPlans, jsonEncode(_plans.map((p) => p.toJson()).toList()));

    final online = await _networkInfo.isConnected;
    if (online) {
      try {
        await _supabase.from(SupabaseConstants.tableMembershipPlans).update({
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', id);
      } catch (error) {
        await _queuePendingWrite(
          'plans',
          'delete',
          {'id': id},
          error: error,
        );
      }
    } else {
      await _queuePendingWrite('plans', 'delete', {'id': id});
    }
  }

  // --- Memberships CRUD ---

  Future<MembershipCreationResult> createMembership({
    required String memberId,
    required String? planId,
    required DateTime startDate,
    required DateTime endDate,
    required double price,
    double? initialPaymentAmount,
    String paymentMethod = 'cash',
    DateTime? paymentDate,
    String? paymentNotes,
  }) async {
    return _membershipCreationGuard.run(
      memberId,
      () => _createMembershipOnce(
        memberId: memberId,
        planId: planId,
        startDate: startDate,
        endDate: endDate,
        price: price,
        initialPaymentAmount: initialPaymentAmount,
        paymentMethod: paymentMethod,
        paymentDate: paymentDate,
        paymentNotes: paymentNotes,
      ),
    );
  }

  Future<MembershipCreationResult> _createMembershipOnce({
    required String memberId,
    required String? planId,
    required DateTime startDate,
    required DateTime endDate,
    required double price,
    required double? initialPaymentAmount,
    required String paymentMethod,
    required DateTime? paymentDate,
    required String? paymentNotes,
  }) async {
    final selectedPlan = planId == null
        ? null
        : activePlans.where((plan) => plan.id == planId).firstOrNull;
    if (planId != null && selectedPlan == null) {
      throw StateError('الباقة المحددة غير متاحة للاشتراكات الجديدة.');
    }
    final actualEndDate = selectedPlan?.endDateFor(startDate) ?? endDate;

    final startDay =
        DateTime.utc(startDate.year, startDate.month, startDate.day);
    final endDay = DateTime.utc(
        actualEndDate.year, actualEndDate.month, actualEndDate.day);
    if (!price.isFinite || price < 0) {
      throw ArgumentError.value(price, 'price', 'يجب أن يكون سعراً صالحاً.');
    }
    if (initialPaymentAmount != null &&
        (!initialPaymentAmount.isFinite || initialPaymentAmount <= 0)) {
      throw ArgumentError.value(
        initialPaymentAmount,
        'initialPaymentAmount',
        'يجب أن تكون الدفعة أكبر من صفر.',
      );
    }
    if (startDay.isAfter(endDay)) {
      throw ArgumentError(
          'تاريخ بداية الاشتراك يجب ألا يتجاوز تاريخ الانتهاء.');
    }

    final gymId = await requireGymId();

    final newMembership = Membership(
      id: const Uuid().v4(),
      gymId: gymId,
      memberId: memberId,
      planId: planId,
      startDate: startDate,
      endDate: actualEndDate,
      price: price,
      status: 'active',
      createdBy: _actorUserId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final online = await _networkInfo.isConnected;
    if (_memberships.any((existing) =>
        existing.deletedAt == null &&
        existing.overlapsActivePeriod(newMembership))) {
      throw const DuplicateActiveMembershipException();
    }

    final pendingQueue = await _getPendingQueue();
    if (pendingQueue
        .any((action) => _queuedMembershipOverlaps(action, newMembership))) {
      throw const DuplicateActiveMembershipException();
    }

    final payment = initialPaymentAmount == null
        ? null
        : Payment(
            id: const Uuid().v4(),
            gymId: gymId,
            membershipId: newMembership.id,
            amount: initialPaymentAmount,
            paymentMethod: paymentMethod,
            paidAt: paymentDate ?? DateTime.now(),
            recordedBy: _actorUserId,
            notes: paymentNotes?.trim(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
    final queuePayload = {
      'membership': newMembership.toJson(),
      'payment': payment?.toJson(),
    };

    if (!online) {
      await _queuePendingWrite(
        'membership_bundle',
        'create_with_initial_payment',
        queuePayload,
      );
      return MembershipCreationResult(
          membership: newMembership, isPending: true);
    }

    try {
      if (planId != null) {
        final activePlan = await _supabase
            .from(SupabaseConstants.tableMembershipPlans)
            .select('id')
            .eq('id', planId)
            .eq('is_active', true)
            .isFilter('deleted_at', null)
            .maybeSingle();
        if (activePlan == null) {
          throw StateError('تم إيقاف الباقة المحددة أو حذفها.');
        }
      }

      final conflicts = await _supabase
          .from(SupabaseConstants.tableMemberships)
          .select('id')
          .eq('member_id', memberId)
          .eq('status', 'active')
          .isFilter('deleted_at', null)
          .lte('start_date', _dateOnly(endDay))
          .gte('end_date', _dateOnly(startDay))
          .limit(1);
      if ((conflicts as List).isNotEmpty) {
        throw const DuplicateActiveMembershipException();
      }

      final response = await _supabase.rpc<Map<String, dynamic>>(
        'create_membership_with_initial_payment',
        params: {
          'p_membership': newMembership.toJson(),
          'p_payment': payment?.toJson(),
        },
      );
      final result = response;
      final confirmedMembership = Membership.fromJson(
          Map<String, dynamic>.from(result['membership'] as Map));
      final confirmedPayment = result['payment'] is Map
          ? Payment.fromJson(
              Map<String, dynamic>.from(result['payment'] as Map))
          : null;

      _memberships = [
        confirmedMembership,
        ..._memberships.where((item) => item.id != confirmedMembership.id),
      ];
      if (confirmedPayment != null) {
        _payments = [
          confirmedPayment,
          ..._payments.where((item) => item.id != confirmedPayment.id),
        ];
      }
      await _persistMembershipAndPaymentCache();
      notifyListeners();
      return MembershipCreationResult(
          membership: confirmedMembership, isPending: false);
    } on PostgrestException catch (error) {
      if (error.code == '23P01') {
        throw const DuplicateActiveMembershipException();
      }
      rethrow;
    } catch (error) {
      if (!await _networkInfo.isConnected) {
        await _queuePendingWrite(
          'membership_bundle',
          'create_with_initial_payment',
          queuePayload,
          error: error,
        );
        return MembershipCreationResult(
            membership: newMembership, isPending: true);
      }
      rethrow;
    }
  }

  bool _queuedMembershipOverlaps(PendingAction action, Membership proposed) {
    if (action.table == 'membership_bundle') {
      final rawMembership = action.payload['membership'];
      if (rawMembership is Map<String, dynamic>) {
        return Membership.fromJson(rawMembership)
            .overlapsActivePeriod(proposed);
      }
    }
    if (action.table == 'memberships' && action.action == 'create') {
      return Membership.fromJson(action.payload).overlapsActivePeriod(proposed);
    }
    return false;
  }

  String _dateOnly(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> _persistMembershipAndPaymentCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMemberships,
        jsonEncode(_memberships.map((item) => item.toJson()).toList()));
    await prefs.setString(_keyPayments,
        jsonEncode(_payments.map((item) => item.toJson()).toList()));
  }

  // --- Payments CRUD ---

  Future<Payment> recordPayment({
    String? paymentId,
    required String? membershipId,
    required double amount,
    required String paymentMethod,
    required DateTime paidAt,
    String? notes,
  }) async {
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'يجب أن يكون أكبر من صفر.');
    }
    final gymId = await requireGymId();

    final newPayment = Payment(
      id: paymentId ?? const Uuid().v4(),
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

    final existingPayment =
        _payments.where((payment) => payment.id == newPayment.id).firstOrNull;
    if (existingPayment != null &&
        (existingPayment.gymId != newPayment.gymId ||
            existingPayment.membershipId != newPayment.membershipId ||
            existingPayment.amount != newPayment.amount ||
            existingPayment.paymentMethod != newPayment.paymentMethod ||
            existingPayment.paidAt != newPayment.paidAt ||
            existingPayment.recordedBy != newPayment.recordedBy ||
            existingPayment.notes != newPayment.notes)) {
      throw StateError('تم استخدام معرّف الدفعة لعملية مختلفة.');
    }
    final paymentToRecord = existingPayment ?? newPayment;
    if (existingPayment == null) {
      _payments = [newPayment, ..._payments];
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _keyPayments, jsonEncode(_payments.map((p) => p.toJson()).toList()));
    }

    final online = await _networkInfo.isConnected;
    if (online) {
      try {
        await _supabase
            .from(SupabaseConstants.tablePayments)
            .upsert(paymentToRecord.toJson());
      } catch (error) {
        await _queuePaymentWrite(paymentToRecord, error: error);
      }
    } else {
      await _queuePaymentWrite(paymentToRecord);
    }

    return paymentToRecord;
  }

  Future<void> _queuePaymentWrite(Payment payment, {Object? error}) async {
    final queue = await _getPendingQueue();
    if (queue.any((action) =>
        action.table == 'payments' &&
        action.action == 'create' &&
        action.payload['id'] == payment.id)) {
      return;
    }
    await _queuePendingWrite('payments', 'create', payment.toJson(),
        error: error);
  }

  Future<void> editMembership(Membership updated) async {
    final edited = updated.copyWith(updatedAt: DateTime.now());

    _memberships =
        _memberships.map((m) => m.id == edited.id ? edited : m).toList();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMemberships,
        jsonEncode(_memberships.map((m) => m.toJson()).toList()));

    final online = await _networkInfo.isConnected;
    if (online) {
      try {
        await _supabase
            .from(SupabaseConstants.tableMemberships)
            .update(edited.toJson())
            .eq('id', edited.id);
      } catch (error) {
        await _queuePendingWrite(
          'memberships',
          'update',
          edited.toJson(),
          error: error,
        );
      }
    } else {
      await _queuePendingWrite('memberships', 'update', edited.toJson());
    }
  }

  Future<void> deleteMembership(String id) async {
    final now = DateTime.now();
    _memberships = _memberships.where((m) => m.id != id).toList();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMemberships,
        jsonEncode(_memberships.map((m) => m.toJson()).toList()));

    final online = await _networkInfo.isConnected;
    if (online) {
      try {
        await _supabase.from(SupabaseConstants.tableMemberships).update({
          'deleted_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        }).eq('id', id);
      } catch (error) {
        await _queuePendingWrite(
          'memberships',
          'delete',
          {'id': id},
          error: error,
        );
      }
    } else {
      await _queuePendingWrite('memberships', 'delete', {'id': id});
    }
  }

  Future<void> editPayment(Payment updated) async {
    final edited = updated.copyWith(updatedAt: DateTime.now());

    _payments = _payments.map((p) => p.id == edited.id ? edited : p).toList();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyPayments, jsonEncode(_payments.map((p) => p.toJson()).toList()));

    final online = await _networkInfo.isConnected;
    if (online) {
      try {
        await _supabase
            .from(SupabaseConstants.tablePayments)
            .update(edited.toJson())
            .eq('id', edited.id);
      } catch (error) {
        await _queuePendingWrite(
          'payments',
          'update',
          edited.toJson(),
          error: error,
        );
      }
    } else {
      await _queuePendingWrite('payments', 'update', edited.toJson());
    }
  }

  Future<void> deletePayment(String id) async {
    _payments = _payments.where((p) => p.id != id).toList();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyPayments, jsonEncode(_payments.map((p) => p.toJson()).toList()));

    final online = await _networkInfo.isConnected;
    if (online) {
      try {
        await _supabase
            .from(SupabaseConstants.tablePayments)
            .delete()
            .eq('id', id);
      } catch (error) {
        await _queuePendingWrite(
          'payments',
          'delete',
          {'id': id},
          error: error,
        );
      }
    } else {
      await _queuePendingWrite('payments', 'delete', {'id': id});
    }
  }

  Future<void> updateGymInfo({required String name}) async {
    final gymId = await requireGymId();
    final updateData = {
      'name': name.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    final prefs = await SharedPreferences.getInstance();
    final cachedGym = jsonDecode(prefs.getString('cached_user_gym') ?? '{}')
        as Map<String, dynamic>;
    await prefs.setString(
      'cached_user_gym',
      jsonEncode({...cachedGym, 'id': gymId, ...updateData}),
    );

    final online = await _networkInfo.isConnected;
    if (online) {
      try {
        await _supabase
            .from(SupabaseConstants.tableGyms)
            .update(updateData)
            .eq('id', gymId);
      } catch (error) {
        await _queuePendingWrite(
          'gyms',
          'update',
          {'id': gymId, ...updateData},
          error: error,
        );
        rethrow;
      }
    } else {
      await _queuePendingWrite('gyms', 'update', {'id': gymId, ...updateData});
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
      try {
        await _supabase
            .from(SupabaseConstants.tableProfiles)
            .update(updateData)
            .eq('id', userId);
      } catch (error) {
        await _queuePendingWrite(
          'profiles',
          'update',
          {'id': userId, ...updateData},
          error: error,
        );
        rethrow;
      }
    } else {
      await _queuePendingWrite(
        'profiles',
        'update',
        {'id': userId, ...updateData},
      );
    }
    notifyListeners();
  }
}
