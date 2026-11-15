import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/data_sync_service.dart';
import '../../../core/utils/gym_clock.dart';
import '../../../core/utils/rtl_support.dart';
import '../domain/revenue_report_calculator.dart';
import 'widgets/revenue_comparison_chart.dart';

class RevenueReportsScreen extends ConsumerStatefulWidget {
  const RevenueReportsScreen({super.key});

  @override
  ConsumerState<RevenueReportsScreen> createState() =>
      _RevenueReportsScreenState();
}

class _RevenueReportsScreenState extends ConsumerState<RevenueReportsScreen> {
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    final today = GymClock.today();
    _selectedYear = today.year;
    _selectedMonth = today.month;
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(dataSyncServiceProvider);
    final payments = data.payments;
    final gymId = data.gymId ?? '';
    final today = GymClock.today();
    final currentYear = today.year;
    final currentMonth = today.month;
    final currentDay = today.day;

    final paymentYears = payments
        .where((payment) => payment.gymId == gymId)
        .map((payment) => GymClock.inCairo(payment.paidAt).year)
        .toList();
    final earliestYear = paymentYears.isEmpty
        ? currentYear - 5
        : paymentYears.reduce((a, b) => a < b ? a : b);
    final firstAvailableYear =
        earliestYear < currentYear - 5 ? earliestYear : currentYear - 5;
    final years = [
      for (var year = currentYear; year >= firstAvailableYear; year--) year,
    ];
    if (!years.contains(_selectedYear)) {
      _selectedYear = currentYear;
    }

    final isCurrentMonth =
        _selectedYear == currentYear && _selectedMonth == currentMonth;
    final monthThroughDay = isCurrentMonth ? currentDay : null;

    final monthTotal = RevenueReportCalculator.forMonth(
      payments,
      gymId: gymId,
      year: _selectedYear,
      month: _selectedMonth,
      throughDay: monthThroughDay,
    );

    final previousMonthDate = DateTime(_selectedYear, _selectedMonth - 1, 1);
    final previousMonthDays = DateUtils.getDaysInMonth(
      previousMonthDate.year,
      previousMonthDate.month,
    );
    final previousMonthDay = isCurrentMonth
        ? (currentDay < previousMonthDays ? currentDay : previousMonthDays)
        : null;
    final previousMonthTotal = RevenueReportCalculator.forMonth(
      payments,
      gymId: gymId,
      year: previousMonthDate.year,
      month: previousMonthDate.month,
      throughDay: previousMonthDay,
    );

    final previousYearDays =
        DateUtils.getDaysInMonth(_selectedYear - 1, _selectedMonth);
    final previousYearDay = isCurrentMonth
        ? (currentDay < previousYearDays ? currentDay : previousYearDays)
        : null;
    final sameMonthLastYear = RevenueReportCalculator.forMonth(
      payments,
      gymId: gymId,
      year: _selectedYear - 1,
      month: _selectedMonth,
      throughDay: previousYearDay,
    );

    final annualThroughMonth =
        _selectedYear == currentYear ? currentMonth : null;
    final annualThroughDay = _selectedYear == currentYear ? currentDay : null;
    final annualTotal = RevenueReportCalculator.forYear(
      payments,
      gymId: gymId,
      year: _selectedYear,
      throughMonth: annualThroughMonth,
      throughDay: annualThroughDay,
    );
    final previousYearTotal = RevenueReportCalculator.forYear(
      payments,
      gymId: gymId,
      year: _selectedYear - 1,
      throughMonth: annualThroughMonth,
      throughDay: annualThroughDay,
    );
    final annualMonths = RevenueReportCalculator.monthlyTotals(
      payments,
      gymId: gymId,
      year: _selectedYear,
      throughMonth: annualThroughMonth,
      throughDay: annualThroughDay,
    );
    final maxMonthRevenue = annualMonths.values.fold<double>(
      0,
      (maximum, total) =>
          total.revenue > maximum ? total.revenue : maximum,
    );
    final previousAnnualMonths = RevenueReportCalculator.monthlyTotals(
      payments,
      gymId: gymId,
      year: _selectedYear - 1,
      throughMonth: annualThroughMonth,
      throughDay: annualThroughDay,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'تابع الإيرادات المحصّلة حسب تاريخ استلام الدفع',
          style: TextStyle(
            color: context.appPalette.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                key: ValueKey<int>(_selectedYear),
                initialValue: _selectedYear,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'السنة',
                  prefixIcon: Icon(Icons.calendar_today_rounded),
                ),
                items: years
                    .map(
                      (year) => DropdownMenuItem<int>(
                        value: year,
                        child: Text('$year'),
                      ),
                    )
                    .toList(),
                onChanged: (year) {
                  if (year == null) return;
                  setState(() {
                    _selectedYear = year;
                    _selectedMonth =
                        year == currentYear ? currentMonth : 12;
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<int>(
                key: ValueKey<String>('$_selectedYear-$_selectedMonth'),
                initialValue: _selectedMonth,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'الشهر',
                  prefixIcon: Icon(Icons.date_range_rounded),
                ),
                items: [
                  for (var month = 1; month <= 12; month++)
                    DropdownMenuItem<int>(
                      value: month,
                      child: Text(_monthName(month)),
                    ),
                ],
                onChanged: (month) {
                  if (month != null) {
                    setState(() => _selectedMonth = month);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _summaryCard(
          context,
          title: 'إيراد ${_monthName(_selectedMonth)} $_selectedYear',
          amount: monthTotal.revenue,
          details: '${monthTotal.paymentCount} دفعة محسوبة • '
              '${monthTotal.cancelledCount} دفعة ملغاة '
              '(${RtlSupport.formatEgp(monthTotal.cancelledAmount)}) مستبعدة',
          icon: Icons.payments_rounded,
        ),
        if (isCurrentMonth)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'الأرقام حتى اليوم $currentDay فقط، والمقارنات تستخدم '
                  'نفس عدد الأيام من الفترات السابقة.',
              style: TextStyle(
                color: context.appPalette.textMuted,
                fontSize: 11,
              ),
            ),
          ),
        const SizedBox(height: 16),
        _comparisonCard(
          context,
          title: 'مقارنة بالشهر السابق '
              '(${_monthName(previousMonthDate.month)} ${previousMonthDate.year})',
          comparison: RevenueReportCalculator.compare(
            monthTotal,
            previousMonthTotal,
          ),
        ),
        const SizedBox(height: 10),
        _comparisonCard(
          context,
          title: 'مقارنة بنفس الشهر السنة السابقة (${_selectedYear - 1})',
          comparison: RevenueReportCalculator.compare(
            monthTotal,
            sameMonthLastYear,
          ),
        ),
        const SizedBox(height: 10),
        RevenueComparisonChart(
          title: 'الرسم البياني لمقارنة الشهر',
          currentLabel: '${_monthName(_selectedMonth)} $_selectedYear',
          previousLabel: '${_monthName(previousMonthDate.month)} '
              '${previousMonthDate.year}',
          items: [
            RevenueComparisonBarItem(
              label: 'إجمالي الإيراد المحصّل',
              current: monthTotal.revenue,
              previous: previousMonthTotal.revenue,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _summaryCard(
          context,
          title: _selectedYear == currentYear
              ? 'إجمالي إيرادات $_selectedYear حتى الآن'
              : 'إجمالي إيرادات سنة $_selectedYear',
          amount: annualTotal.revenue,
          details: '${annualTotal.paymentCount} دفعة محسوبة خلال الفترة',
          icon: Icons.account_balance_wallet_rounded,
        ),
        const SizedBox(height: 10),
        _comparisonCard(
          context,
          title: 'مقارنة سنوية مع ${_selectedYear - 1}'
              '${_selectedYear == currentYear ? ' (نفس المدة)' : ''}',
          comparison: RevenueReportCalculator.compare(
            annualTotal,
            previousYearTotal,
          ),
        ),
        const SizedBox(height: 10),
        RevenueComparisonChart(
          title: 'مقارنة الإيرادات شهر بشهر',
          currentLabel: '$_selectedYear',
          previousLabel: '${_selectedYear - 1}',
          items: [
            for (var month = 1; month <= 12; month++)
              RevenueComparisonBarItem(
                label: _monthName(month),
                current: annualMonths[month]?.revenue ?? 0,
                previous: previousAnnualMonths[month]?.revenue ?? 0,
              ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          'تفصيل إيرادات شهور سنة $_selectedYear',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          _selectedYear == currentYear
              ? 'الشهر الحالي محسوب حتى اليوم، والشهور القادمة لا تدخل في الإجمالي.'
              : 'كل شهر محسوب بالكامل حسب تاريخ التحصيل.',
          style: TextStyle(
            color: context.appPalette.textMuted,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: context.appPalette.surfaceCard,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                for (var month = 1; month <= 12; month++)
                  _monthBar(
                    context,
                    month: month,
                    total: annualMonths[month] ?? const RevenueTotals(),
                    maxRevenue: maxMonthRevenue,
                    isSelected: month == _selectedMonth,
                    onTap: () => setState(() => _selectedMonth = month),
                  ),
              ],
            ),
          ),
        ),
        if (data.syncStatus == SyncStatus.offline)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'أنت غير متصل بالإنترنت. التقرير يعرض آخر بيانات محفوظة على الجهاز.',
              style: TextStyle(
                color: context.appPalette.warning,
                fontSize: 12,
              ),
            ),
          ),
        if (data.syncStatus == SyncStatus.error)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              data.syncErrorMessage ??
                  'تعذر تحديث البيانات. الأرقام المعروضة قد لا تشمل آخر التغييرات.',
              style: TextStyle(
                color: context.appPalette.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _summaryCard(
    BuildContext context, {
    required String title,
    required double amount,
    required String details,
    required IconData icon,
  }) {
    return Card(
      color: context.appPalette.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor:
                  context.appPalette.success.withValues(alpha: 0.14),
              child: Icon(icon, color: context.appPalette.success),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.appPalette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    RtlSupport.formatEgp(amount),
                    style: TextStyle(
                      color: context.appPalette.success,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    details,
                    style: TextStyle(
                      color: context.appPalette.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _comparisonCard(
    BuildContext context, {
    required String title,
    required RevenueComparison comparison,
  }) {
    final isUp = comparison.trend == RevenueTrend.up;
    final isDown = comparison.trend == RevenueTrend.down;
    final color = isUp
        ? context.appPalette.success
        : isDown
            ? context.appPalette.error
            : context.appPalette.textSecondary;
    final icon = isUp
        ? Icons.trending_up_rounded
        : isDown
            ? Icons.trending_down_rounded
            : Icons.trending_flat_rounded;
    final changeText = comparison.percentageChange == null
        ? comparison.current.revenue > 0
            ? 'إيراد جديد؛ لا توجد قيمة سابقة لحساب النسبة'
            : 'لا توجد إيرادات في الفترتين'
        : '${comparison.percentageChange! > 0 ? '+' : ''}'
            '${comparison.percentageChange!.toStringAsFixed(1)}%';

    return Card(
      color: context.appPalette.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                color: context.appPalette.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    changeText,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${comparison.difference > 0 ? '+' : ''}'
                      '${RtlSupport.formatEgp(comparison.difference)}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'الحالي: ${RtlSupport.formatEgp(comparison.current.revenue)}  •  السابق: '
                  '${RtlSupport.formatEgp(comparison.previous.revenue)}',
              style: TextStyle(
                color: context.appPalette.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthBar(
    BuildContext context, {
    required int month,
    required RevenueTotals total,
    required double maxRevenue,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final progress = maxRevenue <= 0 ? 0.0 : total.revenue / maxRevenue;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              child: Text(
                _monthName(month),
                style: TextStyle(
                  color: isSelected
                      ? context.appPalette.primary
                      : context.appPalette.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 11,
                ),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 9,
                  backgroundColor: context.appPalette.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isSelected
                        ? context.appPalette.primary
                        : context.appPalette.success,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 92,
              child: Text(
                RtlSupport.formatEgp(total.revenue),
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: context.appPalette.textPrimary,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _monthName(int month) => const [
        'يناير',
        'فبراير',
        'مارس',
        'أبريل',
        'مايو',
        'يونيو',
        'يوليو',
        'أغسطس',
        'سبتمبر',
        'أكتوبر',
        'نوفمبر',
        'ديسمبر',
      ][month - 1];
}
