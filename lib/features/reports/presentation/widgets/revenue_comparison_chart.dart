import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/rtl_support.dart';

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
    final maximum = items.fold<double>(0, (value, item) {
      final itemMaximum =
          item.current > item.previous ? item.current : item.previous;
      return itemMaximum > value ? itemMaximum : value;
    });

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
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _LegendItem(color: palette.primary, label: currentLabel),
                _LegendItem(color: palette.success, label: previousLabel),
              ],
            ),
            const SizedBox(height: 14),
            if (items.isEmpty)
              Text(
                'لا توجد بيانات كافية للمقارنة.',
                style: TextStyle(color: palette.textMuted, fontSize: 12),
              )
            else
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 13),
                  child: _ComparisonBars(
                    item: item,
                    maximum: maximum,
                    currentColor: palette.primary,
                    previousColor: palette.success,
                    labelColor: palette.textSecondary,
                    mutedColor: palette.textMuted,
                    trackColor: palette.border,
                  ),
                ),
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

class _ComparisonBars extends StatelessWidget {
  final RevenueComparisonBarItem item;
  final double maximum;
  final Color currentColor;
  final Color previousColor;
  final Color labelColor;
  final Color mutedColor;
  final Color trackColor;

  const _ComparisonBars({
    required this.item,
    required this.maximum,
    required this.currentColor,
    required this.previousColor,
    required this.labelColor,
    required this.mutedColor,
    required this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          item.label,
          style: TextStyle(
            color: labelColor,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 6),
        _BarValue(
          value: item.current,
          maximum: maximum,
          color: currentColor,
          trackColor: trackColor,
          mutedColor: mutedColor,
        ),
        const SizedBox(height: 5),
        _BarValue(
          value: item.previous,
          maximum: maximum,
          color: previousColor,
          trackColor: trackColor,
          mutedColor: mutedColor,
        ),
      ],
    );
  }
}

class _BarValue extends StatelessWidget {
  final double value;
  final double maximum;
  final Color color;
  final Color trackColor;
  final Color mutedColor;

  const _BarValue({
    required this.value,
    required this.maximum,
    required this.color,
    required this.trackColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    final progress = maximum <= 0 ? 0.0 : (value / maximum).clamp(0.0, 1.0);

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: trackColor.withValues(alpha: 0.55)),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      widthFactor: progress,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        SizedBox(
          width: 88,
          child: Text(
            RtlSupport.formatEgp(value),
            textAlign: TextAlign.end,
            style: TextStyle(
              color: value == 0 ? mutedColor : color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
