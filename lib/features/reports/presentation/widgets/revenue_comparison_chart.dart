import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'revenue_chart_painter.dart';

class RevenueComparisonBarItem {
  final String label;
  final double current;
  final double previous;

  const RevenueComparisonBarItem({
    required this.label,
    required this.current,
    required this.previous,
  });
}

/// Shows a two-column comparison for one month, or two trend lines for a year.
class RevenueComparisonChart extends StatelessWidget {
  final String title;
  final String currentLabel;
  final String previousLabel;
  final List<RevenueComparisonBarItem> items;

  const RevenueComparisonChart({
    super.key,
    required this.title,
    required this.currentLabel,
    required this.previousLabel,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final isYearlyTrend = items.length > 1;

    return Card(
      color: palette.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _LegendItem(color: palette.primary, label: currentLabel),
                _LegendItem(color: palette.success, label: previousLabel),
              ],
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              Text(
                'لسه مفيش بيانات كفاية للرسم.',
                style: TextStyle(color: palette.textMuted, fontSize: 12),
              )
            else ...[
              Text(
                'الإيراد (ج.م)',
                textAlign: TextAlign.start,
                style: TextStyle(color: palette.textMuted, fontSize: 10),
              ),
              const SizedBox(height: 4),
              Directionality(
                textDirection: TextDirection.ltr,
                child: SizedBox(
                  height: 210,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: RevenueChartPainter(
                      items: items,
                      currentColor: palette.primary,
                      previousColor: palette.success,
                      gridColor: palette.border.withValues(alpha: 0.8),
                      labelColor: palette.textMuted,
                      isYearlyTrend: isYearlyTrend,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isYearlyTrend ? 'الشهور' : 'الفترة',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.textMuted, fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: context.appPalette.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

