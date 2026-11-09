import 'package:flutter_test/flutter_test.dart';
import 'package:gym_eldeeb/data/models/payment.dart';

void main() {
  test('legacy payments default to active and new cancelled fields round-trip', () {
    final legacy = Payment.fromJson({
      'id': 'p1',
      'gym_id': 'g1',
      'amount': 250,
      'payment_method': 'cash',
      'paid_at': '2026-11-09T00:00:00Z',
      'created_at': '2026-11-09T00:00:00Z',
      'updated_at': '2026-11-09T00:00:00Z',
    });
    expect(legacy.isCancelled, isFalse);

    final cancelled = legacy.copyWith(
      isCancelled: true,
      cancelledAt: DateTime.utc(2026, 11, 9),
      cancellationReason: 'membership_cancelled',
    );
    final restored = Payment.fromJson(cancelled.toJson());
    expect(restored.isCancelled, isTrue);
    expect(restored.cancelledAt, DateTime.utc(2026, 11, 9));
    expect(restored.cancellationReason, 'membership_cancelled');
    expect(restored.amount, 250);
    expect(restored.membershipId, isNull);
  });
}
