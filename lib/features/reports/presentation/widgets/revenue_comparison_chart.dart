import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

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
                    painter: _RevenueChartPainter(
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

class _RevenueChartPainter extends CustomPainter {
  final List<RevenueComparisonBarItem> items;
  final Color currentColor;
  final Color previousColor;
  final Color gridColor;
  final Color labelColor;
  final bool isYearlyTrend;

  const _RevenueChartPainter({
    required this.items,
    required this.currentColor,
    required this.previousColor,
    required this.gridColor,
    required this.labelColor,
    required this.isYearlyTrend,
  });

  static const _left = 48.0;
  static const _right = 12.0;
  static const _top = 8.0;
  static const _bottom = 34.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty || size.width <= _left + _right) return;

    final values = <double>[
      for (final item in items) item.current,
      for (final item in items) item.previous,
    ];
    final rawMaximum = values.fold<double>(
      0,
      (maximum, value) => math.max(maximum, value).toDouble(),
    );
    final maximum = _niceMaximum(rawMaximum);
    final plotWidth = size.width - _left - _right;
    final plotHeight = size.height - _top - _bottom;
    if (plotHeight <= 0) return;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = labelColor.withValues(alpha: 0.65)
      ..strokeWidth = 1.1;

    for (var tick = 0; tick <= 4; tick++) {
      final ratio = tick / 4;
      final y = _top + plotHeight * ratio;
      canvas.drawLine(
        Offset(_left, y),
        Offset(size.width - _right, y),
        gridPaint,
      );
      final value = maximum * (1 - ratio);
      _drawText(
        canvas,
        _formatAxisValue(value),
        Offset(0, y - 7),
        width: _left - 7,
        color: labelColor,
        fontSize: 9,
        align: TextAlign.end,
        direction: TextDirection.ltr,
      );
    }

    canvas.drawLine(
      Offset(_left, _top),
      Offset(_left, _top + plotHeight),
      axisPaint,
    );
    canvas.drawLine(
      Offset(_left, _top + plotHeight),
      Offset(size.width - _right, _top + plotHeight),
      axisPaint,
    );

    if (isYearlyTrend) {
      _paintYearLines(
        canvas,
        plotWidth: plotWidth,
        plotHeight: plotHeight,
        maximum: maximum,
        labelColor: labelColor,
      );
    } else {
      _paintMonthBars(
        canvas,
        plotWidth: plotWidth,
        plotHeight: plotHeight,
        maximum: maximum,
        labelColor: labelColor,
      );
    }
  }

  void _paintMonthBars(
    Canvas canvas, {
    required double plotWidth,
    required double plotHeight,
    required double maximum,
    required Color labelColor,
  }) {
    final barWidth = math.min(42.0, plotWidth / 5).toDouble();
    final centers = [
      _left + plotWidth * 0.32,
      _left + plotWidth * 0.68,
    ];
    final values = [items.first.current, items.first.previous];
    final colors = [currentColor, previousColor];
    const labels = ['الشهر الحالي', 'الشهر اللي فات'];

    for (var index = 0; index < 2; index++) {
      final value = values[index];
      final barHeight =
          (value / maximum).clamp(0.0, 1.0).toDouble() * plotHeight;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centers[index] - barWidth / 2,
          _top + plotHeight - barHeight,
          barWidth,
          math.max(2.0, barHeight).toDouble(),
        ),
        const Radius.circular(5),
      );
      canvas.drawRRect(rect, Paint()..color = colors[index]);
      _drawText(
        canvas,
        _formatAxisValue(value),
        Offset(centers[index] - 38, _top + plotHeight - barHeight - 17),
        width: 76,
        color: colors[index],
        fontSize: 9,
        align: TextAlign.center,
        direction: TextDirection.rtl,
      );
      _drawText(
        canvas,
        labels[index],
        Offset(centers[index] - 48, _top + plotHeight + 8),
        width: 96,
        color: labelColor,
        fontSize: 9,
        align: TextAlign.center,
        direction: TextDirection.rtl,
      );
    }
  }

  void _paintYearLines(
    Canvas canvas, {
    required double plotWidth,
    required double plotHeight,
    required double maximum,
    required Color labelColor,
  }) {
    final currentPath = Path();
    final previousPath = Path();
    final currentPoints = <Offset>[];
    final previousPoints = <Offset>[];

    for (var index = 0; index < items.length; index++) {
      final x = _left +
          (items.length == 1
              ? plotWidth / 2
              : plotWidth * index / (items.length - 1));
      final currentY = _top +
          plotHeight -
          (items[index].current / maximum).clamp(0.0, 1.0).toDouble() *
              plotHeight;
      final previousY = _top +
          plotHeight -
          (items[index].previous / maximum).clamp(0.0, 1.0).toDouble() *
              plotHeight;
      final currentPoint = Offset(x, currentY);
      final previousPoint = Offset(x, previousY);
      currentPoints.add(currentPoint);
      previousPoints.add(previousPoint);

      if (index == 0) {
        currentPath.moveTo(x, currentY);
        previousPath.moveTo(x, previousY);
      } else {
        currentPath.lineTo(x, currentY);
        previousPath.lineTo(x, previousY);
      }

      _drawText(
        canvas,
        _shortMonth(items[index].label),
        Offset(x - 14, _top + plotHeight + 8),
        width: 28,
        color: labelColor,
        fontSize: 8,
        align: TextAlign.center,
        direction: TextDirection.rtl,
      );
    }

    canvas.drawPath(
      previousPath,
      Paint()
        ..color = previousColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      currentPath,
      Paint()
        ..color = currentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    for (final point in previousPoints) {
      _paintPoint(canvas, point, previousColor, 3.2);
    }
    for (final point in currentPoints) {
      _paintPoint(canvas, point, currentColor, 3.4);
    }
  }

  void _paintPoint(Canvas canvas, Offset point, Color color, double radius) {
    canvas.drawCircle(point, radius, Paint()..color = color);
    canvas.drawCircle(
      point,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  double _niceMaximum(double value) {
    if (value <= 0) return 1;
    final magnitude =
        math.pow(10, (math.log(value) / math.ln10).floor()).toDouble();
    final scaled = value / magnitude;
    final step = scaled <= 1
        ? 1
        : scaled <= 2
            ? 2
            : scaled <= 5
                ? 5
                : 10;
    return step * magnitude;
  }

  String _formatAxisValue(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      final digits = value >= 10000 ? 0 : 1;
      return '${(value / 1000).toStringAsFixed(digits)}k';
    }
    return value.toStringAsFixed(0);
  }

  String _shortMonth(String value) =>
      value.length > 3 ? value.substring(0, 3) : value;

  void _drawText(
    Canvas canvas,
    String value,
    Offset offset, {
    required double width,
    required Color color,
    required double fontSize,
    required TextAlign align,
    required TextDirection direction,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: direction,
      textAlign: align,
      maxLines: 1,
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _RevenueChartPainter oldDelegate) {
    return oldDelegate.items != items ||
        oldDelegate.currentColor != currentColor ||
        oldDelegate.previousColor != previousColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.isYearlyTrend != isYearlyTrend;
  }
}
