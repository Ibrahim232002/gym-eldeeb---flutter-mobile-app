import 'package:flutter_test/flutter_test.dart';
import 'package:gym_eldeeb/data/models/payment.dart';
import 'package:gym_eldeeb/features/reports/domain/revenue_report_calculator.dart';

Payment _payment({
  required String id,
  String gymId = 'gym-1',
  required DateTime paidAt,
  double amount = 100,
  bool isCancelled = false,
}) {
  return Payment(
    id: id,
    gymId: gymId,
    amount: amount,
    paidAt: paidAt,
    isCancelled: isCancelled,
    createdAt: paidAt,
    updatedAt: paidAt,
  );
}

void main() {
  group('RevenueReportCalculator', () {
    test('groups payments by Cairo calendar month, not UTC month', () {
      final payments = [
        _payment(
          id: 'november',
          paidAt: DateTime.utc(2026, 10, 31, 22, 30),
          amount: 250,
        ),
        _payment(
          id: 'october',
          paidAt: DateTime.utc(2026, 10, 31, 21, 59),
          amount: 150,
        ),
      ];

      expect(
        RevenueReportCalculator.forMonth(
          payments,
          gymId: 'gym-1',
          year: 2026,
          month: 11,
        ).revenue,
        250,
      );
      expect(
        RevenueReportCalculator.forMonth(
          payments,
          gymId: 'gym-1',
          year: 2026,
          month: 10,
        ).revenue,
        150,
      );
    });

    test('excludes cancelled payments from revenue but reports them separately',
        () {
      final payments = [
        _payment(id: 'paid', paidAt: DateTime.utc(2026, 11, 4), amount: 300),
        _payment(
          id: 'cancelled',
          paidAt: DateTime.utc(2026, 11, 5),
          amount: 250,
          isCancelled: true,
        ),
      ];

      final total = RevenueReportCalculator.forMonth(
        payments,
        gymId: 'gym-1',
        year: 2026,
        month: 11,
      );

      expect(total.revenue, 300);
      expect(total.paymentCount, 1);
      expect(total.cancelledAmount, 250);
      expect(total.cancelledCount, 1);
    });

    test('does not include another gym payment', () {
      final total = RevenueReportCalculator.forMonth(
        [
          _payment(
            id: 'other-gym',
            gymId: 'gym-2',
            paidAt: DateTime.utc(2026, 11, 4),
            amount: 900,
          ),
        ],
        gymId: 'gym-1',
        year: 2026,
        month: 11,
      );

      expect(total.revenue, 0);
      expect(total.paymentCount, 0);
    });

    test('supports month-to-date cutoffs for fair comparisons', () {
      final payments = [
        _payment(id: 'day-14', paidAt: DateTime.utc(2026, 11, 14), amount: 100),
        _payment(id: 'day-15', paidAt: DateTime.utc(2026, 11, 15), amount: 200),
        _payment(id: 'day-16', paidAt: DateTime.utc(2026, 11, 16), amount: 400),
      ];

      final total = RevenueReportCalculator.forMonth(
        payments,
        gymId: 'gym-1',
        year: 2026,
        month: 11,
        throughDay: 15,
      );

      expect(total.revenue, 300);
      expect(total.paymentCount, 2);
    });

    test('builds annual monthly totals and year-to-date totals', () {
      final payments = [
        _payment(id: 'jan', paidAt: DateTime.utc(2026, 1, 12), amount: 100),
        _payment(id: 'feb', paidAt: DateTime.utc(2026, 2, 12), amount: 200),
        _payment(id: 'mar', paidAt: DateTime.utc(2026, 3, 12), amount: 300),
      ];

      final monthly = RevenueReportCalculator.monthlyTotals(
        payments,
        gymId: 'gym-1',
        year: 2026,
        throughMonth: 2,
        throughDay: 15,
      );
      final annual = RevenueReportCalculator.forYear(
        payments,
        gymId: 'gym-1',
        year: 2026,
        throughMonth: 2,
        throughDay: 15,
      );

      expect(monthly[1]!.revenue, 100);
      expect(monthly[2]!.revenue, 200);
      expect(monthly[3]!.revenue, 0);
      expect(annual.revenue, 300);
      expect(annual.paymentCount, 2);
    });

    test('returns a null percentage when the previous period is zero', () {
      final comparison = RevenueReportCalculator.compare(
        const RevenueTotals(revenue: 250),
        const RevenueTotals(),
      );

      expect(comparison.difference, 250);
      expect(comparison.percentageChange, isNull);
      expect(comparison.trend, RevenueTrend.up);
    });

    test('calculates downward and unchanged comparisons', () {
      final down = RevenueReportCalculator.compare(
        const RevenueTotals(revenue: 50),
        const RevenueTotals(revenue: 100),
      );
      final unchanged = RevenueReportCalculator.compare(
        const RevenueTotals(revenue: 100),
        const RevenueTotals(revenue: 100),
      );

      expect(down.difference, -50);
      expect(down.percentageChange, -50);
      expect(down.trend, RevenueTrend.down);
      expect(unchanged.percentageChange, 0);
      expect(unchanged.trend, RevenueTrend.unchanged);
    });
  });
}
