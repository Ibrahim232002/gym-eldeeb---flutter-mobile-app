import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_eldeeb/auth/auth_provider.dart';
import 'package:gym_eldeeb/auth/auth_repository.dart';
import 'package:gym_eldeeb/auth/auth_state.dart';
import 'package:gym_eldeeb/core/services/data_sync_service.dart';
import 'package:gym_eldeeb/core/network/network_info.dart';
import 'package:gym_eldeeb/core/theme/app_colors.dart';
import 'package:gym_eldeeb/core/theme/app_theme_controller.dart';
import 'package:gym_eldeeb/data/models/member.dart';
import 'package:gym_eldeeb/data/models/membership.dart';
import 'package:gym_eldeeb/data/models/membership_plan.dart';
import 'package:gym_eldeeb/data/models/payment.dart';
import 'package:gym_eldeeb/data/models/user_profile.dart';
import 'package:gym_eldeeb/data/local/local_storage_service.dart';
import 'package:gym_eldeeb/core/theme/app_theme.dart';
import 'package:gym_eldeeb/core/utils/member_identity.dart';
import 'package:gym_eldeeb/features/dashboard/dashboard_screen.dart';
import 'package:gym_eldeeb/features/auth/login_screen.dart';
import 'package:gym_eldeeb/widgets/member_photo.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

Widget _buildDashboardTestApp({
  required int selectedTab,
  UserProfile? profile,
  List<Member> members = const [],
  List<MembershipPlan> plans = const [],
  List<Membership> memberships = const [],
  SyncStatus syncStatus = SyncStatus.synced,
  String? syncErrorMessage,
  bool syncSucceeds = true,
  void Function(bool forceRetry)? onSync,
}) {
  SharedPreferences.setMockInitialValues({});
  final supabase = SupabaseClient('https://example.supabase.co', 'test-key');
  supabase.auth.stopAutoRefresh();
  final dataService = _DashboardTestDataSyncService(
    supabase: supabase,
    networkInfo: _OfflineNetworkInfo(),
    members: members,
    plans: plans,
    memberships: memberships,
    syncStatus: syncStatus,
    syncErrorMessage: syncErrorMessage,
    syncSucceeds: syncSucceeds,
    onSync: onSync,
  );
  final authNotifier = AuthNotifier(
    AuthRepository(supabase, LocalStorageService(), NetworkInfo()),
  );
  if (profile != null) {
    authNotifier.state = AuthState.authenticatedNoGym(profile);
  }

  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith((ref) => authNotifier),
      dataSyncServiceProvider.overrideWith((ref) => dataService),
      selectedTabProvider.overrideWith((ref) => selectedTab),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: const DashboardScreen(),
    ),
  );
}

class _DashboardTestDataSyncService extends DataSyncService {
  final List<Member> _testMembers;
  final List<MembershipPlan> _testPlans;
  final List<Membership> _testMemberships;
  SyncStatus _testSyncStatus;
  String? _testSyncErrorMessage;
  final bool _syncSucceeds;
  final void Function(bool forceRetry)? _onSync;

  _DashboardTestDataSyncService({
    required super.supabase,
    required super.networkInfo,
    required List<Member> members,
    required List<MembershipPlan> plans,
    required List<Membership> memberships,
    required SyncStatus syncStatus,
    required String? syncErrorMessage,
    required bool syncSucceeds,
    required void Function(bool forceRetry)? onSync,
  })  : _testMembers = members,
        _testPlans = plans,
        _testMemberships = memberships,
        _testSyncStatus = syncStatus,
        _testSyncErrorMessage = syncErrorMessage,
        _syncSucceeds = syncSucceeds,
        _onSync = onSync;

  @override
  SyncStatus get syncStatus => _testSyncStatus;

  @override
  String? get syncErrorMessage => _testSyncErrorMessage;

  @override
  Future<void> syncAll({bool forceRetry = false}) async {
    _onSync?.call(forceRetry);
    _testSyncStatus = SyncStatus.syncing;
    notifyListeners();
    await Future<void>.delayed(Duration.zero);
    _testSyncStatus = _syncSucceeds ? SyncStatus.synced : SyncStatus.error;
    _testSyncErrorMessage =
        _syncSucceeds ? null : 'عملية مزامنة ما زالت معلقة.';
    notifyListeners();
  }

  @override
  List<Member> get members => _testMembers;

  @override
  List<MembershipPlan> get plans =>
      _testPlans.where((plan) => plan.deletedAt == null).toList();

  @override
  List<MembershipPlan> get activePlans => selectableMembershipPlans(_testPlans);

  @override
  List<Membership> get memberships => _testMemberships
      .where((membership) => membership.deletedAt == null)
      .toList();
}

class _OfflineNetworkInfo extends NetworkInfo {
  @override
  Future<bool> get isConnected async => false;
}

class _OnlineNetworkInfo extends NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

class _MutableNetworkInfo extends NetworkInfo {
  bool connected;

  _MutableNetworkInfo(this.connected);

  @override
  Future<bool> get isConnected async => connected;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  group('Member duplicate identity', () {
    Member member({
      String id = 'member-1',
      String gymId = 'gym-1',
      String fullName = 'أحمد محمد',
      String? phone = '01012345678',
      DateTime? deletedAt,
    }) =>
        Member(
          id: id,
          gymId: gymId,
          fullName: fullName,
          phone: phone,
          joinDate: DateTime(2026, 10, 1),
          createdAt: DateTime(2026, 10, 1),
          updatedAt: DateTime(2026, 10, 1),
          deletedAt: deletedAt,
        );

    test('normalizes name whitespace/case and phone formatting/digits', () {
      expect(normalizeMemberName('  Jane   DOE  '), 'jane doe');
      expect(
        normalizeMemberPhone('٠١٠ ١٢٣٤-٥٦٧٨'),
        normalizeMemberPhone('+20 (10) 1234 5678'),
      );
      expect(
        normalizeMemberPhone('01012345678'),
        isNot(normalizeMemberPhone('01012345679')),
      );
    });

    test('detects duplicate name and phone, excluding current or other gyms',
        () {
      final existing = member();
      expect(
        duplicateMemberField(
          member(id: 'new', fullName: '  أحمد   محمد ', phone: null),
          [existing],
        ),
        DuplicateMemberField.name,
      );
      expect(
        duplicateMemberField(
          member(id: 'new', fullName: 'اسم مختلف', phone: '+20 10 1234 5678'),
          [existing],
        ),
        DuplicateMemberField.phone,
      );
      expect(
        duplicateMemberField(
          member(id: 'member-1', fullName: 'اسم مختلف'),
          [existing],
          excludingMemberId: 'member-1',
        ),
        isNull,
      );
      expect(
        duplicateMemberField(
          member(id: 'new', gymId: 'gym-2'),
          [existing],
        ),
        isNull,
      );
      expect(
        duplicateMemberField(
          member(id: 'new', fullName: 'أحمد محمد', phone: null),
          [member(deletedAt: DateTime(2026, 10, 10))],
        ),
        isNull,
      );
    });

    test('photo viewer sizing keeps landscape and portrait aspect ratios', () {
      expect(
        memberPhotoPreviewSize(const Size(400, 100), const Size(328, 620)),
        const Size(328, 82),
      );
      expect(
        memberPhotoPreviewSize(const Size(100, 400), const Size(328, 620)),
        const Size(155, 620),
      );
    });

    test('offline create blocks duplicates found in gym cache', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'cache_members_gym-1',
        jsonEncode([member().toJson()]),
      );
      final supabase = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
      );
      final service = DataSyncService(
        supabase: supabase,
        networkInfo: _OfflineNetworkInfo(),
        initialGymId: 'gym-1',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await expectLater(
        service.addMember(
          fullName: 'اسم آخر',
          phone: '+20 10 1234 5678',
          joinDate: DateTime(2026, 10, 22),
        ),
        throwsA(
          isA<DuplicateMemberException>().having(
            (error) => error.field,
            'field',
            DuplicateMemberField.phone,
          ),
        ),
      );
      expect(service.members, hasLength(1));
      service.dispose();
    });

    test('offline edit blocks duplicates without replacing the saved member',
        () async {
      SharedPreferences.setMockInitialValues({});
      final first = member(phone: '01011111111');
      final second = member(
        id: 'member-2',
        fullName: 'اسم محفوظ آخر',
        phone: '01022222222',
      );
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'cache_members_gym-1',
        jsonEncode([first.toJson(), second.toJson()]),
      );
      final service = DataSyncService(
        supabase: SupabaseClient('https://example.supabase.co', 'test-key'),
        networkInfo: _OfflineNetworkInfo(),
        initialGymId: 'gym-1',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await expectLater(
        service.editMember(second.copyWith(fullName: '  أحمد   محمد ')),
        throwsA(
          isA<DuplicateMemberException>().having(
            (error) => error.field,
            'field',
            DuplicateMemberField.name,
          ),
        ),
      );
      expect(
        service.members.firstWhere((item) => item.id == second.id).fullName,
        second.fullName,
      );
      service.dispose();
    });
  });

  group('Membership and server-side uniqueness', () {
    Membership membership({
      String id = 'membership-1',
      String memberId = 'member-1',
      String status = 'active',
      DateTime? startDate,
      DateTime? endDate,
      DateTime? deletedAt,
    }) {
      return Membership(
        id: id,
        gymId: 'gym-1',
        memberId: memberId,
        startDate: startDate ?? DateTime(2026, 10, 1),
        endDate: endDate ?? DateTime(2026, 10, 31),
        status: status,
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
        deletedAt: deletedAt,
      );
    }

    test('rejects overlapping active periods for the same member ID', () {
      final existing = membership();
      final proposed = membership(
        id: 'membership-2',
        startDate: DateTime(2026, 10, 20),
        endDate: DateTime(2026, 11, 19),
      );

      expect(existing.overlapsActivePeriod(proposed), isTrue);
    });

    test('allows a renewal starting the day after the inclusive end date', () {
      final existing = membership();
      final renewal = membership(
        id: 'membership-2',
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
      );

      expect(existing.overlapsActivePeriod(renewal), isFalse);
    });

    test('treats a shared end/start calendar day as overlapping', () {
      final existing = membership(endDate: DateTime(2026, 10, 31));
      final proposed = membership(
        id: 'membership-2',
        startDate: DateTime(2026, 10, 31),
        endDate: DateTime(2026, 11, 30),
      );

      expect(existing.overlapsActivePeriod(proposed), isTrue);
    });

    test('does not block canceled, deleted, or different-member history', () {
      final proposed = membership(id: 'membership-2');

      expect(
        membership(id: 'cancelled', status: 'cancelled')
            .overlapsActivePeriod(proposed),
        isFalse,
      );
      expect(
        membership(id: 'deleted', deletedAt: DateTime(2026, 10, 2))
            .overlapsActivePeriod(proposed),
        isFalse,
      );
      expect(
        membership(id: 'other-member', memberId: 'member-2')
            .overlapsActivePeriod(proposed),
        isFalse,
      );
    });

    test('maps only the configured member unique indexes to field messages',
        () {
      const duplicateName = PostgrestException(
        message:
            'duplicate key value violates unique constraint "members_unique_active_name_per_gym"',
        code: '23505',
      );
      const duplicatePhone = PostgrestException(
        message: 'duplicate key value violates unique constraint',
        details: 'Key violates members_unique_active_phone_per_gym',
        code: '23505',
      );
      const unrelatedUniqueViolation = PostgrestException(
        message:
            'duplicate key value violates unique constraint "members_other_key"',
        code: '23505',
      );
      const otherError = PostgrestException(
        message: 'duplicate key value violates unique constraint',
        details: 'members_unique_active_name_per_gym',
        code: '23503',
      );

      expect(
        DuplicateMemberException(
          duplicateMemberFieldForPostgrestException(duplicateName)!,
        ).toString(),
        'اسم العضو مسجل بالفعل في هذا الجيم.',
      );
      expect(
        DuplicateMemberException(
          duplicateMemberFieldForPostgrestException(duplicatePhone)!,
        ).toString(),
        'رقم الموبايل مسجل بالفعل في هذا الجيم.',
      );
      expect(
        duplicateMemberFieldForPostgrestException(unrelatedUniqueViolation),
        isNull,
      );
      expect(duplicateMemberFieldForPostgrestException(otherError), isNull);
    });

    test('queued duplicate member sync failure stays pending and is reported',
        () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final queuedAction = PendingAction(
        id: 'member-create-1',
        table: 'members',
        action: 'create',
        payload: {
          'id': 'member-1',
          'gym_id': 'gym-1',
          'full_name': 'Duplicate name',
          'join_date': '2026-10-01',
        },
        createdAt: DateTime.utc(2026, 10, 1),
      );
      await preferences.setString(
        'pending_queue_gym-1',
        jsonEncode([queuedAction.toJson()]),
      );

      var requestCount = 0;
      final supabase = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: http_testing.MockClient((request) async {
          requestCount++;
          expect(request.url.path, '/rest/v1/members');
          return http.Response(
            jsonEncode({
              'code': '23505',
              'message':
                  'duplicate key value violates unique constraint "members_unique_active_name_per_gym"',
              'details': null,
              'hint': null,
            }),
            409,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      supabase.auth.stopAutoRefresh();
      final service = DataSyncService(
        supabase: supabase,
        networkInfo: _OnlineNetworkInfo(),
        initialGymId: 'gym-1',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await service.syncAll();

      final remainingActions = decodePendingActions(
        preferences.getString('pending_queue_gym-1'),
      );
      expect(requestCount, greaterThan(0));
      expect(
        remainingActions.single.lastError,
        contains('members_unique_active_name_per_gym'),
      );
      expect(service.syncStatus, SyncStatus.error);
      expect(service.syncErrorMessage, 'اسم العضو مسجل بالفعل في هذا الجيم.');
      expect(remainingActions, hasLength(1));
      expect(remainingActions.single.id, queuedAction.id);
      expect(remainingActions.single.retryCount, 5);
      service.dispose();
      await supabase.dispose();
    });
  });

  test('successful forced retry clears sync warning and pending payment',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final payment = Payment(
      id: 'payment-retry',
      gymId: 'gym-1',
      amount: 125,
      paymentMethod: 'cash',
      paidAt: DateTime.utc(2026, 10, 22),
      createdAt: DateTime.utc(2026, 10, 22),
      updatedAt: DateTime.utc(2026, 10, 22),
    );
    await preferences.setString(
      'pending_queue_gym-1',
      jsonEncode([
        PendingAction(
          id: 'payment-action',
          table: 'payments',
          action: 'create',
          payload: payment.toJson(),
          createdAt: payment.createdAt,
        ).toJson(),
      ]),
    );

    var paymentAttempts = 0;
    final supabase = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: http_testing.MockClient((request) async {
        if (request.url.path == '/rest/v1/payments' &&
            request.method == 'POST') {
          paymentAttempts++;
          if (paymentAttempts == 1) {
            return http.Response(
              jsonEncode({
                'code': '23505',
                'message': 'duplicate payment id',
                'details': null,
                'hint': null,
              }),
              409,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          return http.Response('', 204, request: request);
        }
        if (request.method == 'GET') {
          final List<Map<String, dynamic>> rows =
              request.url.path == '/rest/v1/payments' ? [payment.toJson()] : [];
          return http.Response(
            jsonEncode(rows),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return http.Response('Unexpected request', 500, request: request);
      }),
    );
    supabase.auth.stopAutoRefresh();
    final network = _MutableNetworkInfo(false);
    final service = DataSyncService(
      supabase: supabase,
      networkInfo: network,
      initialGymId: 'gym-1',
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    network.connected = true;

    await service.syncAll();
    expect(service.syncStatus, SyncStatus.error);
    expect(await service.isPaymentPending(payment.id), isTrue);

    await service.syncAll(forceRetry: true);

    expect(paymentAttempts, 2);
    expect(service.syncStatus, SyncStatus.synced);
    expect(service.syncErrorMessage, isNull);
    expect(await service.isPaymentPending(payment.id), isFalse);
    expect(service.payments.single.id, payment.id);
    service.dispose();
    await supabase.dispose();
  });

  test('plan duration uses inclusive calendar-day end dates', () {
    final plan = MembershipPlan(
      id: 'plan-1',
      gymId: 'gym-1',
      name: 'Monthly',
      durationDays: 30,
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    );

    expect(
      plan.endDateFor(DateTime(2026, 10, 1)),
      DateTime.utc(2026, 10, 30),
    );
  });

  test('new subscription choices exclude inactive and deleted plans', () {
    MembershipPlan plan(
      String id, {
      bool isActive = true,
      DateTime? deletedAt,
    }) =>
        MembershipPlan(
          id: id,
          gymId: 'gym-1',
          name: id,
          isActive: isActive,
          createdAt: DateTime(2026, 10, 1),
          updatedAt: DateTime(2026, 10, 1),
          deletedAt: deletedAt,
        );

    final selectable = selectableMembershipPlans([
      plan('active'),
      plan('inactive', isActive: false),
      plan('deleted', deletedAt: DateTime(2026, 10, 2)),
      plan('inactive-and-deleted',
          isActive: false, deletedAt: DateTime(2026, 10, 2)),
    ]);

    expect(selectable.map((item) => item.id), ['active']);
  });

  group('Expiring membership boundaries', () {
    Membership membership({
      DateTime? startDate,
      DateTime? endDate,
      String status = 'active',
      DateTime? deletedAt,
    }) =>
        Membership(
          id: 'membership-expiring',
          gymId: 'gym-1',
          memberId: 'member-1',
          startDate: startDate ?? DateTime(2026, 10, 1),
          endDate: endDate ?? DateTime(2026, 10, 22),
          status: status,
          createdAt: DateTime(2026, 10, 1),
          updatedAt: DateTime(2026, 10, 1),
          deletedAt: deletedAt,
        );

    final today = DateTime(2026, 10, 22, 15);

    test('includes subscriptions expiring today and in seven days', () {
      expect(
        membership(endDate: DateTime(2026, 10, 22)).isExpiringWithinDays(today),
        isTrue,
      );
      expect(
        membership(endDate: DateTime(2026, 10, 29)).isExpiringWithinDays(today),
        isTrue,
      );
    });

    test('a September 24 start uses the selected plan duration', () {
      final plan = MembershipPlan(
        id: 'monthly-plan',
        gymId: 'gym-1',
        name: 'Monthly',
        durationDays: 30,
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      );
      final startDate = DateTime.utc(2026, 9, 24);
      final endDate = plan.endDateFor(startDate);
      final septemberMembership = membership(
        startDate: startDate,
        endDate: endDate,
      );

      expect(endDate, DateTime.utc(2026, 10, 23));
      expect(septemberMembership.isExpiringWithinDays(today), isTrue);
      expect(
        expiringMembershipsWithinDays(
          [septemberMembership],
          DateTime.utc(2026, 10, 22, 23, 59),
        ),
        [septemberMembership],
      );
    });

    test('shared expiry list includes the seven-day edge only', () {
      final expiringToday = membership(endDate: DateTime.utc(2026, 10, 22));
      final expiringInSevenDays =
          membership(endDate: DateTime.utc(2026, 10, 29));
      final justOutsideWindow = membership(endDate: DateTime.utc(2026, 10, 30));

      expect(
        expiringMembershipsWithinDays(
          [expiringToday, expiringInSevenDays, justOutsideWindow],
          DateTime(2026, 10, 22, 23, 59),
        ),
        [expiringToday, expiringInSevenDays],
      );
    });

    test('excludes expired, cancelled, deleted, and not-yet-started plans', () {
      expect(
        membership(endDate: DateTime(2026, 10, 21)).isExpiringWithinDays(today),
        isFalse,
      );
      expect(
        membership(status: 'cancelled').isExpiringWithinDays(today),
        isFalse,
      );
      expect(
        membership(deletedAt: DateTime(2026, 10, 20))
            .isExpiringWithinDays(today),
        isFalse,
      );
      expect(
        membership(startDate: DateTime(2026, 10, 23))
            .isExpiringWithinDays(today),
        isFalse,
      );
      expect(
        membership(endDate: DateTime(2026, 10, 30)).isExpiringWithinDays(today),
        isFalse,
      );
    });
  });

  test('member search normalizes Arabic digits and matches partial phone', () {
    final member = Member(
      id: 'member-1',
      gymId: 'gym-1',
      fullName: 'أحمد محمد',
      phone: '+20 ١٠٠-٢٣٤-٥٦٧٨',
      joinDate: DateTime(2026, 10, 1),
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    );

    expect(memberMatchesSearch(member, 'محمد'), isTrue);
    expect(memberMatchesSearch(member, '100234'), isTrue);
    expect(memberMatchesSearch(member, '١٠٠٢٣٤'), isTrue);
    expect(memberMatchesSearch(member, '999999'), isFalse);
  });

  test('theme selection is persisted and applies distinct palettes', () async {
    SharedPreferences.setMockInitialValues({});
    final themeController = AppThemeController();
    await Future<void>.delayed(Duration.zero);

    await themeController.setTheme(AppThemeVariant.darkPurple);
    final preferences = await SharedPreferences.getInstance();

    expect(themeController.state, AppThemeVariant.darkPurple);
    expect(preferences.getString('gym_eldeeb_theme'), 'darkPurple');
    expect(
      AppColors.paletteFor(AppThemeVariant.darkBlue).primary,
      AppColors.darkBluePalette.primary,
    );
    expect(
      AppColors.paletteFor(AppThemeVariant.darkPurple).primary,
      AppColors.darkPurplePalette.primary,
    );
    expect(
      AppColors.paletteFor(AppThemeVariant.darkGreen).primary,
      AppColors.darkGreenPalette.primary,
    );
    expect(
      AppColors.paletteFor(AppThemeVariant.neutral).background,
      AppColors.neutralPalette.background,
    );
    expect(AppColors.paletteFor(AppThemeVariant.light).primary,
        AppColors.lightPalette.primary);
    final restoredController = AppThemeController();
    await Future<void>.delayed(Duration.zero);
    expect(restoredController.state, AppThemeVariant.darkPurple);
    themeController.dispose();
    restoredController.dispose();
  });

  group('Pending action queue decoding', () {
    test('keeps queued membership bundle operations', () {
      final actions = decodePendingActions('''[
        {
          "id": "queue-1",
          "table": "membership_bundle",
          "action": "create_with_initial_payment",
          "payload": {
            "membership": {"id": "membership-1"},
            "payment": null
          },
          "createdAt": "2026-10-04T12:00:00.000Z"
        }
      ]''');

      expect(actions, hasLength(1));
      expect(actions.single.table, 'membership_bundle');
      expect(actions.single.payload['membership'], {'id': 'membership-1'});
    });

    test('reports corrupt JSON instead of returning an empty queue', () {
      expect(() => decodePendingActions('[invalid'), throwsFormatException);
    });
  });

  test('membership creation guard rejects simultaneous requests per member',
      () async {
    final guard = MembershipCreationGuard();
    final releaseFirstRequest = Completer<void>();
    final firstRequest = guard.run('member-1', () async {
      await releaseFirstRequest.future;
      return 'created';
    });

    await expectLater(
      guard.run('member-1', () async => 'duplicate'),
      throwsA(isA<DuplicateActiveMembershipException>()),
    );

    releaseFirstRequest.complete();
    expect(await firstRequest, 'created');
    expect(await guard.run('member-1', () async => 'next request'),
        'next request');
  });

  group('Offline payment and subscription creation', () {
    test('general and membership payments retry without duplicate rows',
        () async {
      SharedPreferences.setMockInitialValues({});
      final supabase = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
      );
      supabase.auth.stopAutoRefresh();
      final service = DataSyncService(
        supabase: supabase,
        networkInfo: _OfflineNetworkInfo(),
        initialGymId: 'gym-1',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final paidAt = DateTime.utc(2026, 10, 22, 10);
      const generalPaymentId = '00000000-0000-4000-8000-000000000001';
      const membershipPaymentId = '00000000-0000-4000-8000-000000000002';

      final generalPayment = await service.recordPayment(
        paymentId: generalPaymentId,
        membershipId: null,
        amount: 125,
        paymentMethod: 'cash',
        paidAt: paidAt,
        notes: 'General income',
      );
      await service.recordPayment(
        paymentId: generalPaymentId,
        membershipId: null,
        amount: 125,
        paymentMethod: 'cash',
        paidAt: paidAt,
        notes: 'General income',
      );
      final membershipPayment = await service.recordPayment(
        paymentId: membershipPaymentId,
        membershipId: 'existing-membership',
        amount: 75,
        paymentMethod: 'card',
        paidAt: paidAt,
        notes: 'Outstanding balance',
      );

      expect(generalPayment.membershipId, isNull);
      expect(membershipPayment.membershipId, 'existing-membership');
      expect(service.payments, hasLength(2));
      final preferences = await SharedPreferences.getInstance();
      final queued = decodePendingActions(
        preferences.getString('pending_queue_gym-1'),
      );
      expect(queued, hasLength(2));
      expect(queued.map((action) => action.payload['id']).toSet(),
          {generalPaymentId, membershipPaymentId});
      service.dispose();
    });

    test('offline subscription queues one bundle with optional initial payment',
        () async {
      SharedPreferences.setMockInitialValues({});
      final plan = MembershipPlan(
        id: 'plan-monthly',
        gymId: 'gym-1',
        name: 'Monthly',
        durationDays: 30,
        price: 500,
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'cache_plans_gym-1',
        jsonEncode([plan.toJson()]),
      );
      final supabase = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
      );
      supabase.auth.stopAutoRefresh();
      final service = DataSyncService(
        supabase: supabase,
        networkInfo: _OfflineNetworkInfo(),
        initialGymId: 'gym-1',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final startDate = DateTime.utc(2026, 10, 1);
      final initialPaymentResult = await service.createMembership(
        memberId: 'member-1',
        planId: plan.id,
        startDate: startDate,
        endDate: startDate.add(const Duration(days: 60)),
        price: plan.price,
        initialPaymentAmount: plan.price,
        paymentNotes: 'Initial payment',
      );
      expect(initialPaymentResult.isPending, isTrue);
      expect(
        initialPaymentResult.membership.endDate,
        plan.endDateFor(startDate),
      );

      final noPaymentResult = await service.createMembership(
        memberId: 'member-2',
        planId: plan.id,
        startDate: startDate,
        endDate: plan.endDateFor(startDate),
        price: plan.price,
      );
      expect(noPaymentResult.isPending, isTrue);
      await expectLater(
        service.createMembership(
          memberId: 'member-1',
          planId: plan.id,
          startDate: startDate,
          endDate: plan.endDateFor(startDate),
          price: plan.price,
          initialPaymentAmount: plan.price,
          paymentNotes: 'Initial payment',
        ),
        throwsA(isA<DuplicateActiveMembershipException>()),
      );

      final queued = decodePendingActions(
        preferences.getString('pending_queue_gym-1'),
      );
      expect(queued, hasLength(2));
      final queuedPayments =
          queued.map((action) => action.payload['payment']).toList();
      expect(queuedPayments.whereType<Map<String, dynamic>>(), hasLength(1));
      expect(queuedPayments, contains(null));
      service.dispose();
    });
  });

  group('Creator attribution serialization', () {
    test('Member preserves created_by across JSON round-trip', () {
      final member = Member.fromJson({
        'id': 'member-1',
        'gym_id': 'gym-1',
        'full_name': 'Test Member',
        'photo_path': 'gym-1/member-1.jpg',
        'join_date': '2026-10-03',
        'created_by': 'user-1',
        'created_at': '2026-10-03T10:00:00.000Z',
        'updated_at': '2026-10-03T10:00:00.000Z',
      });

      expect(member.createdBy, 'user-1');
      expect(Member.fromJson(member.toJson()).createdBy, 'user-1');
      expect(member.photoPath, 'gym-1/member-1.jpg');
      expect(member.copyWith(clearPhotoPath: true).photoPath, isNull);
    });

    test('Membership preserves created_by across JSON round-trip', () {
      final membership = Membership.fromJson({
        'id': 'membership-1',
        'gym_id': 'gym-1',
        'member_id': 'member-1',
        'start_date': '2026-10-03',
        'end_date': '2026-11-03',
        'created_by': 'user-1',
        'created_at': '2026-10-03T10:00:00.000Z',
        'updated_at': '2026-10-03T10:00:00.000Z',
      });

      expect(membership.createdBy, 'user-1');
      expect(Membership.fromJson(membership.toJson()).createdBy, 'user-1');
    });

    test('Payment preserves recorded_by across JSON round-trip', () {
      final payment = Payment.fromJson({
        'id': 'payment-1',
        'gym_id': 'gym-1',
        'amount': 150,
        'payment_method': 'cash',
        'paid_at': '2026-10-03T10:00:00.000Z',
        'recorded_by': 'user-1',
        'created_at': '2026-10-03T10:00:00.000Z',
        'updated_at': '2026-10-03T10:00:00.000Z',
      });

      expect(payment.recordedBy, 'user-1');
      expect(Payment.fromJson(payment.toJson()).recordedBy, 'user-1');
    });

    test('Legacy rows without attribution remain readable', () {
      expect(
        Member.fromJson({
          'id': 'legacy-member',
          'gym_id': 'gym-1',
          'full_name': 'Legacy',
        }).createdBy,
        isNull,
      );
      expect(
        Membership.fromJson({
          'id': 'legacy-membership',
          'gym_id': 'gym-1',
          'member_id': 'legacy-member',
        }).createdBy,
        isNull,
      );
      expect(
        Payment.fromJson({
          'id': 'legacy-payment',
          'gym_id': 'gym-1',
          'amount': 10,
          'paid_at': '2026-10-03T10:00:00.000Z',
        }).recordedBy,
        isNull,
      );
    });
  });

  test('member photo deletion rejects paths outside the active gym', () async {
    SharedPreferences.setMockInitialValues({});
    final supabase = SupabaseClient('https://example.supabase.co', 'test-key');
    final service = DataSyncService(
      supabase: supabase,
      networkInfo: _OfflineNetworkInfo(),
      initialGymId: 'gym-1',
    );

    await expectLater(
      service.deleteMemberPhoto('gym-2/member-1.jpg'),
      throwsArgumentError,
    );
  });

  test('offline member photo removal queues update before photo deletion',
      () async {
    SharedPreferences.setMockInitialValues({});
    final supabase = SupabaseClient('https://example.supabase.co', 'test-key');
    final service = DataSyncService(
      supabase: supabase,
      networkInfo: _OfflineNetworkInfo(),
      initialGymId: 'gym-1',
    );
    final member = Member(
      id: 'member-1',
      gymId: 'gym-1',
      fullName: 'Photo member',
      photoPath: 'gym-1/member-1.jpg',
      joinDate: DateTime(2026, 10, 1),
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    );

    await service.editMember(
      member.copyWith(clearPhotoPath: true),
      photoPathToDelete: member.photoPath,
    );

    final preferences = await SharedPreferences.getInstance();
    final queue = decodePendingActions(
      preferences.getString('pending_queue_gym-1'),
    );
    expect(queue, hasLength(1));
    expect(queue.single.action, 'update_with_photo_cleanup');
    expect(queue.single.payload['photo_path_to_delete'], member.photoPath);
    expect(
      (queue.single.payload['member'] as Map<String, dynamic>)['photo_path'],
      isNull,
    );
  });

  testWidgets('themed action buttons respect finite horizontal constraints',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('تسجيل'),
                  ),
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('إلغاء'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard quick actions fit narrow RTL screens and stay active',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in [320.0, 360.0, 390.0]) {
      tester.view.physicalSize = Size(width, 720);
      var addedMember = false;
      var createdSubscription = false;
      var recordedPayment = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width - 32,
                  child: DashboardQuickActions(
                    onAddMember: () => addedMember = true,
                    onNewSubscription: () => createdSubscription = true,
                    onRecordPayment: () => recordedPayment = true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('إضافة عضو'), findsOneWidget);
      expect(find.text('اشتراك جديد'), findsOneWidget);
      expect(find.text('تسجيل دفعة'), findsOneWidget);
      expect(find.text('استيراد CSV'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('إضافة عضو'));
      await tester.tap(find.text('اشتراك جديد'));
      await tester.tap(find.text('تسجيل دفعة'));
      expect(addedMember, isTrue);
      expect(createdSubscription, isTrue);
      expect(recordedPayment, isTrue);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('payment dialog stays scrollable on a short screen with keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      _buildDashboardTestApp(
        selectedTab: 0,
        members: [
          Member(
            id: 'member-1',
            gymId: 'gym-1',
            fullName: 'عضو تجريبي باسم طويل يظهر كاملاً في القائمة',
            joinDate: DateTime(2026, 10, 1),
            createdAt: DateTime(2026, 10, 1),
            updatedAt: DateTime(2026, 10, 1),
          ),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.ensureVisible(find.text('تسجيل دفعة'));
    await tester.tap(find.text('تسجيل دفعة'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('تسجيل دفعة إيراد جديدة'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.ensureVisible(find.byType(TextFormField).last);
    await tester.pump();

    expect(find.text('تسجيل الدفعة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('payment member search finds and selects a member by phone',
      (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildDashboardTestApp(
        selectedTab: 0,
        members: [
          Member(
            id: 'member-phone',
            gymId: 'gym-1',
            fullName: 'عضو البحث بالهاتف',
            phone: '01012345678',
            joinDate: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.ensureVisible(find.text('تسجيل دفعة'));
    await tester.tap(find.text('تسجيل دفعة'));
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.byTooltip('بحث عن عضو'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('اختر العضو المسدد'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      isEmpty,
    );

    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(find.byType(TextField).last, '01012345678');
    await tester.pump();
    expect(find.text('عضو البحث بالهاتف'), findsNWidgets(2));

    await tester.tap(find.text('عضو البحث بالهاتف').last);
    await tester.pump();
    expect(
      find.text('عضو البحث بالهاتف • 01012345678'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('بحث عن عضو'));
    await tester.pump(const Duration(milliseconds: 350));
    final searchField = tester.widget<TextField>(find.byType(TextField).last);
    expect(searchField.controller!.text, isEmpty);
    expect(find.text('عضو البحث بالهاتف • 01012345678'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending sync warning stays visible until retry succeeds',
      (tester) async {
    var retryWasForced = false;
    await tester.pumpWidget(
      _buildDashboardTestApp(
        selectedTab: 0,
        syncStatus: SyncStatus.error,
        syncErrorMessage: 'تعذر تأكيد التغيير من الخادم.',
        syncSucceeds: false,
        onSync: (forceRetry) => retryWasForced = forceRetry,
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(
        find.byKey(const ValueKey('dashboard-pending-sync-banner'),
            skipOffstage: false),
        findsOneWidget);
    await tester.tap(find.byTooltip('تحديث البيانات'));
    await tester.pumpAndSettle();
    expect(retryWasForced, isTrue);
    expect(
        find.byKey(const ValueKey('dashboard-pending-sync-banner'),
            skipOffstage: false),
        findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      _buildDashboardTestApp(
        selectedTab: 0,
        syncStatus: SyncStatus.error,
        syncErrorMessage: 'تعذر تأكيد التغيير من الخادم.',
        syncSucceeds: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(
        find.byKey(const ValueKey('dashboard-pending-sync-banner'),
            skipOffstage: false),
        findsOneWidget);
    await tester.tap(find.byTooltip('تحديث البيانات'));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('dashboard-pending-sync-banner'),
            skipOffstage: false),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('subscription edit status dropdown fits a narrow RTL dialog',
      (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final date = DateTime(2026, 10, 22);
    final member = Member(
      id: 'member-edit',
      gymId: 'gym-1',
      fullName: 'عضو تعديل',
      joinDate: date,
      createdAt: date,
      updatedAt: date,
    );

    await tester.pumpWidget(
      _buildDashboardTestApp(
        selectedTab: 3,
        members: [member],
        memberships: [
          Membership(
            id: 'membership-edit',
            gymId: 'gym-1',
            memberId: member.id,
            startDate: date,
            endDate: date.add(const Duration(days: 30)),
            status: 'active',
            createdAt: date,
            updatedAt: date,
          ),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.ensureVisible(find.byTooltip('تعديل بيانات الاشتراك'));
    await tester.pump();
    await tester.tap(find.byTooltip('تعديل بيانات الاشتراك'));
    await tester.pump(const Duration(milliseconds: 350));

    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    await tester.pump(const Duration(milliseconds: 350));
    await tester
        .ensureVisible(find.byType(DropdownButtonFormField<String>).last);
    await tester.pump();
    final statusDropdown = find.descendant(
      of: find.byType(DropdownButtonFormField<String>).last,
      matching: find.byType(DropdownButton<String>),
    );
    expect(tester.widget<DropdownButton<String>>(statusDropdown).isExpanded,
        isTrue);
    expect(find.text('ساري ومفعل (Active)'), findsOneWidget);
    expect(
      tester.getRect(find.byType(DropdownButtonFormField<String>).last).right,
      lessThanOrEqualTo(320),
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    expect(find.text('منتهي (Expired)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('member picker dialog has an opaque app-themed background',
      (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final date = DateTime(2026, 10, 22);
    final member = Member(
      id: 'member-picker',
      gymId: 'gym-1',
      fullName: 'medo',
      joinDate: date,
      createdAt: date,
      updatedAt: date,
    );
    final plan = MembershipPlan(
      id: 'plan-picker',
      gymId: 'gym-1',
      name: 'Monthly',
      durationDays: 30,
      price: 500,
      createdAt: date,
      updatedAt: date,
    );

    await tester.pumpWidget(
      _buildDashboardTestApp(
        selectedTab: 0,
        members: [member],
        plans: [plan],
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('اشتراك جديد'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byTooltip('بحث عن عضو'));
    await tester.pump(const Duration(milliseconds: 350));

    final pickerDialog = tester.widget<Dialog>(find.byType(Dialog).last);
    expect(pickerDialog.backgroundColor, AppColors.darkGoldPalette.surfaceCard);
    expect(pickerDialog.backgroundColor!.a, 1);
    expect(pickerDialog.surfaceTintColor, Colors.transparent);
    expect(find.text('اختر العضو'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login displays the updated Arabic headline on a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final supabase = SupabaseClient('https://example.supabase.co', 'test-key');
    supabase.auth.stopAutoRefresh();
    final authNotifier = AuthNotifier(
      AuthRepository(supabase, LocalStorageService(), NetworkInfo()),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith((ref) => authNotifier),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('أهلاً بيك في جيم الديب'), findsOneWidget);
    expect(find.text('سجل دخولك لمتابعة صالة الألعاب الرياضية والاشتراكات'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new subscriptions only offer active plans', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();

    await tester.pumpWidget(
      _buildDashboardTestApp(
        selectedTab: 0,
        members: [
          Member(
            id: 'member-1',
            gymId: 'gym-1',
            fullName: 'عضو الباقات',
            phone: '01012345678',
            joinDate: now,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        plans: [
          MembershipPlan(
            id: 'active-plan',
            gymId: 'gym-1',
            name: 'الباقة النشطة',
            durationDays: 30,
            price: 300,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
          MembershipPlan(
            id: 'inactive-plan',
            gymId: 'gym-1',
            name: 'الباقة المعطلة',
            durationDays: 30,
            price: 700,
            isActive: false,
            createdAt: now,
            updatedAt: now,
          ),
          MembershipPlan(
            id: 'deleted-plan',
            gymId: 'gym-1',
            name: 'الباقة المحذوفة',
            durationDays: 30,
            price: 500,
            isActive: true,
            deletedAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.ensureVisible(find.text('اشتراك جديد'));
    await tester.tap(find.text('اشتراك جديد'));
    await tester.pump(const Duration(milliseconds: 350));

    final paymentConfirmation =
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
    expect(paymentConfirmation.value, isFalse);
    await tester.tap(find.byTooltip('بحث عن عضو'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(find.byType(TextField).last, '01012345678');
    await tester.pump();
    expect(find.text('عضو الباقات'), findsNWidgets(2));
    await tester.tap(find.text('01012345678').last);
    await tester.pump();
    expect(find.text('عضو الباقات • 01012345678'), findsOneWidget);

    final planDropdown = find.byType(DropdownButtonFormField<String>).last;
    await tester.tap(planDropdown);
    await tester.pumpAndSettle();
    expect(find.text('الباقة النشطة (300.0 ج.م)'), findsNWidgets(2));
    expect(find.text('الباقة المعطلة (700.0 ج.م)'), findsNothing);
    expect(find.text('الباقة المحذوفة (500.0 ج.م)'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expiry shortcut opens only eligible expiring memberships',
      (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = DateTime.now();
    final dateOnly = DateTime(today.year, today.month, today.day);

    final activeMember = Member(
      id: 'member-expiring',
      gymId: 'gym-1',
      fullName: 'عضو ينتهي اشتراكه',
      joinDate: dateOnly,
      createdAt: dateOnly,
      updatedAt: dateOnly,
    );
    final expiredMember = Member(
      id: 'member-expired',
      gymId: 'gym-1',
      fullName: 'عضو انتهى اشتراكه',
      joinDate: dateOnly,
      createdAt: dateOnly,
      updatedAt: dateOnly,
    );

    await tester.pumpWidget(
      _buildDashboardTestApp(
        selectedTab: 0,
        members: [activeMember, expiredMember],
        memberships: [
          Membership(
            id: 'expires-today',
            gymId: 'gym-1',
            memberId: activeMember.id,
            startDate: dateOnly.subtract(const Duration(days: 30)),
            endDate: dateOnly,
            status: 'active',
            createdAt: dateOnly,
            updatedAt: dateOnly,
          ),
          Membership(
            id: 'already-expired',
            gymId: 'gym-1',
            memberId: expiredMember.id,
            startDate: dateOnly.subtract(const Duration(days: 32)),
            endDate: dateOnly.subtract(const Duration(days: 1)),
            status: 'active',
            createdAt: dateOnly,
            updatedAt: dateOnly,
          ),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.ensureVisible(find.text('ينتهي قريباً (٧ أيام)'));
    await tester.tap(find.text('ينتهي قريباً (٧ أيام)'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('عضو ينتهي اشتراكه'), findsOneWidget);
    expect(find.text('عضو انتهى اشتراكه'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expiring membership cards expose chat and member details',
      (tester) async {
    tester.view.physicalSize = const Size(420, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = DateTime.now();
    final dateOnly = DateTime(today.year, today.month, today.day);
    final member = Member(
      id: 'member-expiring-actions',
      gymId: 'gym-1',
      fullName: 'عضو أزرار الانتهاء',
      phone: '01012345678',
      joinDate: dateOnly,
      createdAt: dateOnly,
      updatedAt: dateOnly,
    );

    await tester.pumpWidget(
      _buildDashboardTestApp(
        selectedTab: 7,
        members: [member],
        memberships: [
          Membership(
            id: 'membership-expiring-actions',
            gymId: 'gym-1',
            memberId: member.id,
            startDate: dateOnly.subtract(const Duration(days: 30)),
            endDate: dateOnly,
            createdAt: dateOnly,
            updatedAt: dateOnly,
          ),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byTooltip('مراسلة واتساب'), findsOneWidget);
    expect(find.byTooltip('عرض تفاصيل العضو'), findsOneWidget);
    await tester.tap(find.byTooltip('عرض تفاصيل العضو'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('رقم الهاتف المسجل'), findsOneWidget);
    expect(find.text(member.fullName), findsNWidgets(2));

    Navigator.of(tester.element(find.text('رقم الهاتف المسجل'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('مراسلة واتساب'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('مراسلة ${member.fullName} عبر واتساب:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('member photo preview is compact and preserves wide aspect',
      (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final photo = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Center(
            child: MemberPhotoAvatar(
              gymId: 'gym-1',
              fullName: 'عضو الصورة',
              photoBytes: photo,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(MemberPhotoAvatar));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    final photoSurface = tester.getSize(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(ClipRRect),
      ),
    );
    expect(photoSurface.width, lessThanOrEqualTo(328));
    expect(photoSurface.height, lessThan(400));
    expect(find.byTooltip('إغلاق معاينة الصورة'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('إغلاق معاينة الصورة'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('member and subscription screens show one page action each',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildDashboardTestApp(selectedTab: 1),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('إضافة عضو جديد'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('الاشتراكات'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('تسجيل اشتراك لعضو'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile settings do not display the account ID', (tester) async {
    const accountId = 'profile-uuid-that-must-not-be-visible';
    await tester.pumpWidget(
      _buildDashboardTestApp(
        selectedTab: 6,
        profile: const UserProfile(id: accountId, fullName: 'مدرب تجريبي'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('الاسم بالكامل'), findsOneWidget);
    expect(find.text('مدرب تجريبي'), findsOneWidget);
    expect(find.text('اسم الصالة (العربي)'), findsOneWidget);
    expect(find.text('اسم الصالة (English)'), findsNothing);
    expect(find.text('معرف الحساب (User ID)'), findsNothing);
    expect(find.text(accountId), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings theme choice persists the selected appearance',
      (tester) async {
    await tester.pumpWidget(_buildDashboardTestApp(selectedTab: 6));
    await tester.pump(const Duration(milliseconds: 350));

    final themeDropdown = find.byType(DropdownButtonFormField<AppThemeVariant>);
    await tester.ensureVisible(themeDropdown);
    await tester.tap(themeDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('داكن وأزرق').last);
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('gym_eldeeb_theme'), 'darkBlue');
    expect(tester.takeException(), isNull);
  });
}
