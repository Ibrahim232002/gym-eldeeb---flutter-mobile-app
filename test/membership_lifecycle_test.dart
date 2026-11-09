import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_eldeeb/auth/auth_provider.dart';
import 'package:gym_eldeeb/auth/auth_repository.dart';
import 'package:gym_eldeeb/core/network/network_info.dart';
import 'package:gym_eldeeb/core/services/data_sync_service.dart';
import 'package:gym_eldeeb/core/theme/app_theme.dart';
import 'package:gym_eldeeb/core/utils/gym_clock.dart';
import 'package:gym_eldeeb/core/utils/rtl_support.dart';
import 'package:gym_eldeeb/data/local/local_storage_service.dart';
import 'package:gym_eldeeb/data/models/member.dart';
import 'package:gym_eldeeb/data/models/membership.dart';
import 'package:gym_eldeeb/data/models/payment.dart';
import 'package:gym_eldeeb/features/dashboard/dashboard_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Network extends NetworkInfo {
  bool online = false;
  @override
  Future<bool> get isConnected async => online;
}

final _today = GymClock.today();
Member _member(
        {String id = 'member', bool manual = false, DateTime? deleted}) =>
    Member(
        id: id,
        gymId: 'gym',
        fullName: 'أحمد محمد',
        joinDate: _today,
        createdAt: _today,
        updatedAt: _today,
        isActive: false,
        manuallyDeactivated: manual,
        deletedAt: deleted);
Membership _membership(
        {String id = 'membership',
        String memberId = 'member',
        String gymId = 'gym',
        String status = 'active',
        DateTime? start,
        DateTime? end,
        DateTime? deleted}) =>
    Membership(
        id: id,
        gymId: gymId,
        memberId: memberId,
        startDate: start ?? _today,
        endDate: end ?? _today,
        status: status,
        price: 250,
        deletedAt: deleted,
        createdAt: _today,
        updatedAt: _today);
Payment _payment({String? membershipId = 'membership'}) => Payment(
    id: 'payment',
    gymId: 'gym',
    membershipId: membershipId,
    amount: 250,
    paymentMethod: 'cash',
    paidAt: DateTime.now(),
    recordedBy: 'coach',
    createdAt: _today,
    updatedAt: _today,
    notes: 'دفعة اشتراك');

Future<void> _cache(
    {List<Member> members = const [],
    List<Membership> memberships = const [],
    List<Payment> payments = const [],
    List<PendingAction> queue = const []}) async {
  SharedPreferences.setMockInitialValues({
    'cache_members_gym': jsonEncode(members.map((m) => m.toJson()).toList()),
    'cache_memberships_gym':
        jsonEncode(memberships.map((m) => m.toJson()).toList()),
    'cache_payments_gym': jsonEncode(payments.map((p) => p.toJson()).toList()),
    'cache_creator_names_gym': jsonEncode({'coach': 'كابتن محمود'}),
    'pending_queue_gym': jsonEncode(queue.map((p) => p.toJson()).toList()),
  });
}

http.Response _json(Object data, http.Request request, [int status = 200]) =>
    http.Response(jsonEncode(data), status,
        headers: {'content-type': 'application/json'}, request: request);

Future<DataSyncService> _service(
  _Network network, {
  Future<http.Response> Function(http.Request)? respond,
}) async {
  final client = SupabaseClient('https://example.supabase.co', 'test-key',
      httpClient: MockClient(respond ?? (r) async => _json([], r)));
  client.auth.stopAutoRefresh();
  final service = DataSyncService(
      supabase: client, networkInfo: network, initialGymId: 'gym');
  await Future<void>.delayed(const Duration(milliseconds: 20));
  addTearDown(() async {
    service.dispose();
    await client.dispose();
  });
  return service;
}

Future<MembershipCreationResult> _renew(DataSyncService service,
        {DateTime? start}) =>
    service.createMembership(
        memberId: 'member',
        planId: null,
        startDate: start ?? _today,
        endDate: (start ?? _today).add(const Duration(days: 29)),
        price: 250,
        initialPaymentAmount: 250,
        paymentMethod: 'cash');

void main() {
  setUpAll(() async => initializeDateFormatting('ar'));

  test(
      'Cairo clock is independent of device timezone in winter, summer and DST',
      () {
    for (final pair in {
      '2026-01-01T21:59:59Z': '2026-01-01',
      '2026-01-01T22:00:00Z': '2026-01-02',
      '2026-07-01T20:59:59Z': '2026-07-01',
      '2026-07-01T21:00:00Z': '2026-07-02',
      '2026-04-23T21:59:59Z': '2026-04-23',
      '2026-04-23T22:00:00Z': '2026-04-24',
      '2026-10-29T21:59:59Z': '2026-10-29',
      '2026-10-29T22:00:00Z': '2026-10-30',
    }.entries) {
      expect(GymClock.today(DateTime.parse(pair.key)),
          DateTime.parse('${pair.value}T00:00:00Z'));
    }
    expect(GymClock.untilNextDay(DateTime.parse('2026-04-23T21:59:59Z')),
        const Duration(seconds: 1));
    expect(GymClock.untilNextDay(DateTime.parse('2026-10-29T21:59:59Z')),
        const Duration(seconds: 1));
  });

  test('valid through end date, expired next day, other valid record wins', () {
    final member = _member();
    final valid = _membership();
    final tomorrow = _today.add(const Duration(days: 1));
    expect(memberIsActiveOn(member, [valid], _today), isTrue);
    expect(memberIsActiveOn(member, [valid], tomorrow), isFalse);
    expect(
        memberIsActiveOn(
            member,
            [
              valid,
              _membership(
                  id: 'next',
                  start: tomorrow,
                  end: tomorrow.add(const Duration(days: 29)))
            ],
            tomorrow),
        isTrue);
  });

  test(
      'future, invalid, cancelled, deleted and other-gym records do not activate',
      () {
    final future = _membership(
        start: _today.add(const Duration(days: 2)),
        end: _today.add(const Duration(days: 30)));
    for (final records in [
      [future, _membership(end: _today.subtract(const Duration(days: 1)))],
      [_membership(status: 'cancelled')],
      [_membership(status: 'expired')],
      [_membership(deleted: _today)],
      [_membership(gymId: 'other')],
      [_membership(memberId: 'other')],
      <Membership>[],
    ]) {
      expect(memberIsActiveOn(_member(), records, _today), isFalse);
    }
    expect(memberIsActiveOn(_member(manual: true), [_membership()], _today),
        isFalse);
  });

  test(
      'expiry excludes deleted, missing and mismatched parents without erasing history',
      () {
    final memberships = [
      _membership(),
      _membership(id: 'missing', memberId: 'missing'),
      _membership(id: 'other-gym', gymId: 'other')
    ];
    expect(
        expiringMembershipsWithinDays(memberships, _today, members: [_member()])
            .map((m) => m.id),
        ['membership']);
    expect(
        expiringMembershipsWithinDays(memberships, _today,
            members: [_member(deleted: _today)]),
        isEmpty);
    expect(memberships, hasLength(3));
  });

  test('membership log hides superseded history but keeps the latest expired period', () {
    final old = _membership(
      id: 'old',
      start: _today.subtract(const Duration(days: 30)),
      end: _today.subtract(const Duration(days: 1)),
      status: 'expired',
    );
    final renewed = _membership(
      id: 'renewed',
      start: _today,
      end: _today.add(const Duration(days: 29)),
    );
    expect(
      membershipLogEntries([old, renewed], _today, members: [_member()])
          .map((item) => item.id),
      ['renewed'],
    );
    expect(
      membershipLogEntries([old], _today, members: [_member()])
          .map((item) => item.id),
      ['old'],
    );

    final future = _membership(
      id: 'future',
      start: _today.add(const Duration(days: 5)),
      end: _today.add(const Duration(days: 34)),
    );
    expect(
      membershipLogEntries([old, future], _today, members: [_member()])
          .map((item) => item.id),
      ['future'],
    );
    expect(
      membershipLogEntries([renewed, future], _today, members: [_member()])
          .map((item) => item.id),
      ['renewed'],
    );
    expect(
      membershipLogEntries([old], _today,
          members: [_member(deleted: _today)]),
      isEmpty,
    );
  });

  for (final manual in [false, true]) {
    test(
        'confirmed renewal immediately activates (manual=$manual) and survives restart',
        () async {
      final member = _member(manual: manual);
      await _cache(members: [member]);
      final network = _Network();
      final service = await _service(network, respond: (r) async {
        if (r.url.path
            .endsWith('/rpc/create_membership_with_initial_payment')) {
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          return _json({
            'membership': body['p_membership'],
            'payment': body['p_payment'],
            'member': member
                .copyWith(
                    isActive: true,
                    manuallyDeactivated: false,
                    activationRevision: 1)
                .toJson()
          }, r);
        }
        return _json([], r);
      });
      network.online = true;
      final result = await _renew(service);
      expect(result.isPending, isFalse);
      expect(service.members.single.isActive, isTrue);
      expect(service.members.single.manuallyDeactivated, isFalse);
      await service
          .editMember(member.copyWith(notes: 'dialog opened before renewal'));
      expect(service.members.single.isActive, isTrue);
      final restarted = await _service(_Network());
      expect(restarted.members.single.isActive, isTrue);
      expect(restarted.payments.single.amount, 250);
      expect(restarted.payments.single.paymentMethod, 'cash');
    });
  }

  test('future renewal clears manual hold but does not activate early',
      () async {
    final member = _member(manual: true);
    await _cache(members: [member]);
    final network = _Network();
    final service = await _service(network, respond: (r) async {
      if (r.url.path.endsWith('/rpc/create_membership_with_initial_payment')) {
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        return _json({
          'membership': body['p_membership'],
          'payment': body['p_payment'],
          'member': member
              .copyWith(manuallyDeactivated: false, activationRevision: 1)
              .toJson()
        }, r);
      }
      return _json([], r);
    });
    network.online = true;
    await _renew(service, start: _today.add(const Duration(days: 3)));
    expect(service.members.single.isActive, isFalse);
    expect(service.members.single.manuallyDeactivated, isFalse);
  });

  test(
      'failed renewal preserves activation, old memberships and payment history',
      () async {
    final member = _member(manual: true);
    final old = _membership(
        end: _today.subtract(const Duration(days: 1)),
        start: _today.subtract(const Duration(days: 30)),
        status: 'expired');
    final originalPayment = _payment();
    await _cache(
        members: [member], memberships: [old], payments: [originalPayment]);
    final network = _Network();
    final service = await _service(network, respond: (r) async {
      if (r.method == 'POST') {
        return _json({'code': '23514', 'message': 'payment rejected'}, r, 400);
      }
      return _json([], r);
    });
    network.online = true;
    await expectLater(_renew(service), throwsA(isA<PostgrestException>()));
    expect(service.members.single.isActive, isFalse);
    expect(service.members.single.manuallyDeactivated, isTrue);
    expect(service.memberships.single.id, old.id);
    expect(service.payments.single.toJson(), originalPayment.toJson());
  });

  test(
      'offline renewal waits for confirmation and stale profile update omits activation',
      () async {
    final member = _member(manual: true);
    await _cache(members: [member]);
    final network = _Network();
    Map<String, dynamic>? serverMember;
    Map<String, dynamic>? serverMembership;
    Map<String, dynamic>? serverPayment;
    var rpcCalls = 0;
    final service = await _service(network, respond: (r) async {
      if (r.url.path.endsWith('/rpc/create_membership_with_initial_payment')) {
        rpcCalls++;
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        serverMembership = body['p_membership'] as Map<String, dynamic>;
        serverPayment = body['p_payment'] as Map<String, dynamic>;
        serverMember = member
            .copyWith(
                isActive: true,
                manuallyDeactivated: false,
                activationRevision: 1)
            .toJson();
        return _json({
          'membership': serverMembership,
          'payment': serverPayment,
          'member': serverMember
        }, r);
      }
      if (r.method == 'PATCH' && r.url.path.endsWith('/members')) {
        final payload = jsonDecode(r.body) as Map;
        expect(payload.containsKey('is_active'), isFalse);
        expect(payload.containsKey('manually_deactivated'), isFalse);
        expect(payload.containsKey('activation_revision'), isFalse);
        expect(payload.containsKey('deleted_at'), isFalse);
        return http.Response('', 204, request: r);
      }
      final List<Map<String, dynamic>?> rows = switch (r.url.path) {
        '/rest/v1/members' => [if (serverMember != null) serverMember],
        '/rest/v1/memberships' => [
            if (serverMembership != null) serverMembership
          ],
        '/rest/v1/payments' => [if (serverPayment != null) serverPayment],
        _ => [],
      };
      return _json(rows, r);
    });
    expect((await _renew(service)).isPending, isTrue);
    expect(service.members.single.isActive, isFalse);
    expect(service.memberships, isEmpty);
    await service.editMember(member.copyWith(notes: 'offline edit'));
    network.online = true;
    await service.syncAll();
    expect(service.members.single.isActive, isTrue);
    await service.syncAll();
    expect(rpcCalls, 1);
    expect(service.payments, hasLength(1));
  });

  test(
      'deleted-member expiry disappears offline while payment and coach names remain',
      () async {
    await _cache(
        members: [_member()],
        memberships: [_membership()],
        payments: [_payment()]);
    final service = await _service(_Network());
    expect(service.expiringMemberships, hasLength(1));
    await service.deleteMember('member');
    expect(service.expiringMemberships, isEmpty);
    expect(service.memberships, hasLength(1));
    expect(service.payments, hasLength(1));
    expect(service.paymentMemberName(service.payments.single),
        'أحمد محمد (محذوف)');
    expect(service.creatorName('coach'), 'كابتن محمود');
    expect(service.paymentMemberName(_payment(membershipId: 'missing')),
        'عضو غير متاح');
    await service.deleteMembership('membership');
    expect(service.paymentMemberName(service.payments.single),
        'أحمد محمد (محذوف)');
  });

  test(
      'superseded offline deactivation refreshes server state instead of reverting renewal',
      () async {
    final old = _member(manual: true);
    final confirmed = old.copyWith(
        manuallyDeactivated: false, activationRevision: 2, isActive: true);
    await _cache(members: [
      old
    ], memberships: [
      _membership()
    ], queue: [
      PendingAction(
        id: 'old-intent',
        table: 'members',
        action: 'set_activation',
        createdAt: _today,
        payload: {
          'p_member_id': old.id,
          'p_is_active': false,
          'p_expected_revision': 0
        },
      )
    ]);
    final network = _Network();
    final service = await _service(network, respond: (r) async {
      if (r.url.path.endsWith('/rpc/set_member_activation')) {
        return _json({
          'code': '22023',
          'message': 'MEMBER_ACTIVATION_CHANGED_REFRESH_REQUIRED'
        }, r, 400);
      }
      if (r.url.path.endsWith('/members')) {
        return _json(
            r.url.queryParameters.containsKey('id')
                ? confirmed.toJson()
                : [confirmed.toJson()],
            r);
      }
      if (r.url.path.endsWith('/memberships')) {
        return _json([_membership().toJson()], r);
      }
      return _json([], r);
    });
    network.online = true;
    await service.syncAll();
    expect(service.members.single.isActive, isTrue);
    expect(service.members.single.activationRevision, 2);
    expect(service.syncStatus, SyncStatus.synced);
    final prefs = await SharedPreferences.getInstance();
    expect(decodePendingActions(prefs.getString('pending_queue_gym')), isEmpty);
  });

  testWidgets(
      'payment history shows both names and unchanged totals on a narrow RTL screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final current = _payment();
    final missing = current.copyWith(
        id: 'unavailable',
        membershipId: 'missing',
        amount: 125,
        paymentMethod: 'card');
    final lastMonth = current.copyWith(
        id: 'last-month',
        amount: 999,
        notes: 'دفعة شهر سابق',
        paidAt: DateTime(current.paidAt.year, current.paidAt.month, 0));
    await _cache(
        members: [_member(deleted: _today)],
        memberships: [_membership()],
        payments: [current, missing, lastMonth]);
    final client = SupabaseClient('https://example.supabase.co', 'test-key');
    client.auth.stopAutoRefresh();
    final network = _Network();
    final service = DataSyncService(
        supabase: client, networkInfo: network, initialGymId: 'gym');
    final auth =
        AuthNotifier(AuthRepository(client, LocalStorageService(), network));
    await tester.pumpWidget(ProviderScope(
        overrides: [
          dataSyncServiceProvider.overrideWith((ref) => service),
          authNotifierProvider.overrideWith((ref) => auth),
          selectedTabProvider.overrideWith((ref) => 4),
        ],
        child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Directionality(
                textDirection: TextDirection.rtl, child: DashboardScreen()))));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('العضو: أحمد محمد (محذوف)'), findsOneWidget);
    expect(find.text('سجّل الدفعة: كابتن محمود'), findsNWidgets(2));
    expect(find.text('طريقة الدفع: نقدي'), findsOneWidget);
    expect(find.text('العضو: عضو غير متاح'), findsOneWidget);
    expect(find.text('طريقة الدفع: بطاقة/تحويل'), findsOneWidget);
    expect(find.text(RtlSupport.formatEgp(375)), findsOneWidget);
    expect(find.text('دفعة شهر سابق'), findsNothing);
    expect(service.payments.fold<double>(0, (sum, p) => sum + p.amount), 1374);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
