import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/report_models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// نمودار میله‌ای گروهی (بدون وابستگی). محور زمان از راست به چپ (قدیمی‌ترین در راست).
class BarChartView extends StatelessWidget {
  final ChartData data;
  final double height;
  const BarChartView({super.key, required this.data, this.height = 240});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = [cs.primary, cs.tertiary, cs.secondary];
    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'برای نمایش نمودار داده‌ای وجود ندارد.',
            style: TextStyle(color: AppColors.muted(context)),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            for (var i = 0; i < data.series.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colors[i % colors.length],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    data.series[i].name,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _BarPainter(
              data,
              colors,
              AppColors.muted(context),
              AppColors.line(context),
              Theme.of(context).textTheme.bodySmall?.fontFamily,
            ),
          ),
        ),
      ],
    );
  }
}

class _BarPainter extends CustomPainter {
  final ChartData data;
  final List<Color> colors;
  final Color textColor;
  final Color gridColor;
  final String? fontFamily;
  _BarPainter(
    this.data,
    this.colors,
    this.textColor,
    this.gridColor,
    this.fontFamily,
  );

  TextPainter _tp(String s, double maxWidth, {double size = 11}) {
    final p = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: textColor,
          fontSize: size,
          fontFamily: fontFamily ?? AppTheme.font,
        ),
      ),
      textDirection: TextDirection.rtl,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 10.0, rightPad = 70.0, topPad = 8.0, bottomPad = 26.0;
    final chart = Rect.fromLTRB(
      leftPad,
      topPad,
      size.width - rightPad,
      size.height - bottomPad,
    );
    var maxV = 0.0;
    for (final s in data.series) {
      for (final v in s.values) {
        maxV = math.max(maxV, v);
      }
    }
    if (maxV <= 0) maxV = 1;
    final niceMax = _niceMax(maxV);
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = chart.bottom - chart.height * i / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
      final tp = _tp(fmtShort(niceMax * i / 4), rightPad - 6);
      tp.paint(canvas, Offset(chart.right + 6, y - tp.height / 2));
    }
    final n = data.labels.length;
    final groupW = chart.width / n;
    final sCount = data.series.length;
    final barW = math.min(34.0, (groupW * 0.7) / sCount);
    final every = groupW < 56 ? (56 / groupW).ceil() : 1;
    for (var g = 0; g < n; g++) {
      // g=0 در سمت راست
      final cx = chart.right - groupW * (g + 0.5);
      final startX = cx - (barW * sCount) / 2;
      for (var s = 0; s < sCount; s++) {
        final v = data.series[s].values[g];
        final h = chart.height * (v / niceMax);
        if (h > 0) {
          final rect = RRect.fromRectAndCorners(
            Rect.fromLTWH(startX + s * barW, chart.bottom - h, barW - 2, h),
            topLeft: const Radius.circular(5),
            topRight: const Radius.circular(5),
          );
          canvas.drawRRect(rect, Paint()..color = colors[s % colors.length]);
        }
      }
      if (g % every == 0) {
        final tp = _tp(data.labels[g], groupW * every - 4);
        tp.paint(canvas, Offset(cx - tp.width / 2, chart.bottom + 6));
      }
    }
  }

  double _niceMax(double v) {
    final e = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    final f = v / e;
    final nf = f <= 1 ? 1 : (f <= 2 ? 2 : (f <= 5 ? 5 : 10));
    return nf * e;
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) =>
      old.data != data || old.textColor != textColor;
}
