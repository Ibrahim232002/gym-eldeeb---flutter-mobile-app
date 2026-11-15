import '../../../core/utils/gym_clock.dart';
import '../../../data/models/payment.dart';

class RevenueTotals {
  final double revenue;
  final int paymentCount;
  final double cancelledAmount;
  final int cancelledCount;

  const RevenueTotals({
    this.revenue = 0,
    this.paymentCount = 0,
    this.cancelledAmount = 0,
    this.cancelledCount = 0,
  });

  bool get hasPayments => paymentCount > 0 || cancelledCount > 0;
}

enum RevenueTrend { up, down, unchanged }

class RevenueComparison {
  final RevenueTotals current;
  final RevenueTotals previous;
  final double difference;
  final double? percentageChange;
  final RevenueTrend trend;

  const RevenueComparison({
    required this.current,
    required this.previous,
    required this.difference,
    required this.percentageChange,
    required this.trend,
  });

  bool get hasPreviousRevenue => previous.revenue > 0;
}

class RevenueReportCalculator {
  const RevenueReportCalculator._();

  static RevenueTotals forMonth(
    Iterable<Payment> payments, {
    required String gymId,
    required int year,
    required int month,
    int? throughDay,
  }) {
    return _sum(
      payments,
      gymId: gymId,
      matches: (date) =>
          date.year == year &&
          date.month == month &&
          (throughDay == null || date.day <= throughDay),
    );
  }

  static RevenueTotals forYear(
    Iterable<Payment> payments, {
    required String gymId,
    required int year,
    int? throughMonth,
    int? throughDay,
  }) {
    return _sum(
      payments,
      gymId: gymId,
      matches: (date) {
        if (date.year != year) return false;
        if (throughMonth != null && date.month > throughMonth) return false;
        if (throughMonth != null &&
            throughDay != null &&
            date.month == throughMonth &&
            date.day > throughDay) {
          return false;
        }
        return true;
      },
    );
  }

  static Map<int, RevenueTotals> monthlyTotals(
    Iterable<Payment> payments, {
    required String gymId,
    required int year,
    int? throughMonth,
    int? throughDay,
  }) {
    return {
      for (var month = 1; month <= 12; month++)
        month: throughMonth != null && month > throughMonth
            ? const RevenueTotals()
            : forMonth(
                payments,
                gymId: gymId,
                year: year,
                month: month,
                throughDay: month == throughMonth ? throughDay : null,
              ),
    };
  }

  static RevenueComparison compare(
    RevenueTotals current,
    RevenueTotals previous,
  ) {
    final difference = current.revenue - previous.revenue;
    final trend = difference > 0
        ? RevenueTrend.up
        : difference < 0
            ? RevenueTrend.down
            : RevenueTrend.unchanged;
    final percentage = previous.revenue > 0
        ? (difference / previous.revenue) * 100
        : null;

    return RevenueComparison(
      current: current,
      previous: previous,
      difference: difference,
      percentageChange: percentage,
      trend: trend,
    );
  }

  static RevenueTotals _sum(
    Iterable<Payment> payments, {
    required String gymId,
    required bool Function(DateTime cairoDate) matches,
  }) {
    var revenue = 0.0;
    var paymentCount = 0;
    var cancelledAmount = 0.0;
    var cancelledCount = 0;

    for (final payment in payments) {
      if (payment.gymId != gymId) continue;
      final cairoDate = GymClock.inCairo(payment.paidAt);
      if (!matches(cairoDate)) continue;

      if (payment.isCancelled) {
        cancelledAmount += payment.amount;
        cancelledCount++;
      } else {
        revenue += payment.amount;
        paymentCount++;
      }
    }

    return RevenueTotals(
      revenue: revenue,
      paymentCount: paymentCount,
      cancelledAmount: cancelledAmount,
      cancelledCount: cancelledCount,
    );
  }
}
