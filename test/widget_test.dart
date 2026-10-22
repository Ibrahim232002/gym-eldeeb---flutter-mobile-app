import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_eldeeb/auth/auth_provider.dart';
import 'package:gym_eldeeb/auth/auth_repository.dart';
import 'package:gym_eldeeb/auth/auth_state.dart';
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
import 'package:gym_eldeeb/features/dashboard/dashboard_screen.dart';
import 'package:gym_eldeeb/core/services/data_sync_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

Widget _buildDashboardTestApp({
  required int selectedTab,
  UserProfile? profile,
  List<Member> members = const [],
  List<MembershipPlan> plans = const [],
  List<Membership> memberships = const [],
}) {
  SharedPreferences.setMockInitialValues({});
  final supabase = SupabaseClient('https://example.supabase.co', 'test-key');
  supabase.auth.stopAutoRefresh();
  final dataService = _DashboardTestDataSyncService(
    supabase: supabase,
    networkInfo: NetworkInfo(),
    members: members,
    plans: plans,
    memberships: memberships,
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

  _DashboardTestDataSyncService({
    required super.supabase,
    required super.networkInfo,
    required List<Member> members,
    required List<MembershipPlan> plans,
    required List<Membership> memberships,
  })  : _testMembers = members,
        _testPlans = plans,
        _testMemberships = memberships;

  @override
  SyncStatus get syncStatus => SyncStatus.synced;

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

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  group('Active membership overlap', () {
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
        'join_date': '2026-10-03',
        'created_by': 'user-1',
        'created_at': '2026-10-03T10:00:00.000Z',
        'updated_at': '2026-10-03T10:00:00.000Z',
      });

      expect(member.createdBy, 'user-1');
      expect(Member.fromJson(member.toJson()).createdBy, 'user-1');
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
    expect(find.text('معرف الحساب (User ID)'), findsNothing);
    expect(find.text(accountId), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings theme choice persists the selected appearance',
      (tester) async {
    await tester.pumpWidget(_buildDashboardTestApp(selectedTab: 6));
    await tester.pump(const Duration(milliseconds: 350));

    await tester.ensureVisible(find.text('داكن وأزرق'));
    await tester.tap(find.text('داكن وأزرق'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('gym_eldeeb_theme'), 'darkBlue');
    expect(tester.takeException(), isNull);
  });
}
