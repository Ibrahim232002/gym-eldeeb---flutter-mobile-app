import 'package:flutter_test/flutter_test.dart';
import 'package:gym_eldeeb/data/models/member.dart';
import 'package:gym_eldeeb/data/models/membership.dart';
import 'package:gym_eldeeb/data/models/payment.dart';

void main() {
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
}
