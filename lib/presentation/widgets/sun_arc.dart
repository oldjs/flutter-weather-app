import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/weather_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/weather.dart';
import 'glass_card.dart';

// 日出日落弧线：根据当前时间在弧线上显示太阳位置
class SunArc extends StatelessWidget {
  final DailyWeather today;
  final WeatherTheme theme;
  const SunArc({super.key, required this.today, required this.theme});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      theme: theme,
      title: '日出日落',
      child: Column(
        children: [
          SizedBox(
            height: 100,
            child: LayoutBuilder(
              builder: (_, c) {
                return CustomPaint(
                  size: Size(c.maxWidth, c.maxHeight),
                  painter: _ArcPainter(sunrise: today.sunrise, sunset: today.sunset, theme: theme),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _timeLabel('日出', Fmt.hm(today.sunrise)),
              _timeLabel('日落', Fmt.hm(today.sunset)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeLabel(String k, String v) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        k,
        style: TextStyle(color: theme.subtleForeground, fontSize: 12),
      ),
      const SizedBox(height: 2),
      Text(
        v,
        style: TextStyle(color: theme.foreground, fontSize: 15, fontWeight: FontWeight.w500),
      ),
    ],
  );
}

class _ArcPainter extends CustomPainter {
  final DateTime sunrise;
  final DateTime sunset;
  final WeatherTheme theme;
  _ArcPainter({required this.sunrise, required this.sunset, required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final pad = 16.0;
    final rect = Rect.fromLTWH(pad, 0, size.width - pad * 2, size.height * 1.6);
    // 底层虚线弧
    final bgPaint = Paint()
      ..color = theme.foreground.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    _drawDashedArc(canvas, rect, pi, pi, bgPaint);

    // 计算太阳当前位置对应的弧度比例
    final now = DateTime.now();
    double ratio;
    if (now.isBefore(sunrise)) {
      ratio = 0;
    } else if (now.isAfter(sunset)) {
      ratio = 1;
    } else {
      ratio = now.difference(sunrise).inSeconds / sunset.difference(sunrise).inSeconds;
    }

    // 已走过的弧线
    final fgPaint = Paint()
      ..color = theme.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, pi, pi * ratio, false, fgPaint);

    // 太阳位置
    final angle = pi + pi * ratio;
    final cx = rect.center.dx + rect.width / 2 * cos(angle);
    final cy = rect.center.dy + rect.height / 2 * sin(angle);
    final sunPaint = Paint()..color = theme.accent;
    canvas.drawCircle(Offset(cx, cy), 6, sunPaint);
    // 光晕
    final halo = Paint()..color = theme.accent.withValues(alpha: 0.25);
    canvas.drawCircle(Offset(cx, cy), 14, halo);

    // 地平线
    final horizonPaint = Paint()
      ..color = theme.foreground.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height * 0.8), Offset(size.width, size.height * 0.8), horizonPaint);
  }

  // 手绘虚线弧
  void _drawDashedArc(Canvas canvas, Rect rect, double startAngle, double sweep, Paint paint) {
    const dashCount = 40;
    final step = sweep / dashCount;
    for (var i = 0; i < dashCount; i++) {
      if (i.isOdd) continue;
      canvas.drawArc(rect, startAngle + step * i, step, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) =>
      oldDelegate.sunrise != sunrise || oldDelegate.sunset != sunset;
}
