import 'dart:math';

import 'package:flutter/material.dart';

// 晴天：右上角一个柔和的光晕 + 呼吸效果
class SunLayer extends StatefulWidget {
  final bool isDay;
  const SunLayer({super.key, this.isDay = true});

  @override
  State<SunLayer> createState() => _SunLayerState();
}

class _SunLayerState extends State<SunLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    // 慢慢呼吸的光晕
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return CustomPaint(size: Size.infinite, painter: _SunPainter(_ctrl.value, widget.isDay));
      },
    );
  }
}

class _SunPainter extends CustomPainter {
  final double t; // 0..1
  final bool isDay;
  _SunPainter(this.t, this.isDay);

  @override
  void paint(Canvas canvas, Size size) {
    // 光源位置：白天右上，夜晚偏上居中（月亮感）
    final center = isDay ? Offset(size.width * 0.82, size.height * 0.18) : Offset(size.width * 0.7, size.height * 0.22);
    final baseRadius = min(size.width, size.height) * 0.35;
    final radius = baseRadius * (0.9 + t * 0.2);

    // 多层径向渐变模拟柔和光晕
    final colors = isDay
        ? [const Color(0xFFFFF2B3).withValues(alpha: 0.55), const Color(0xFFFFE38C).withValues(alpha: 0.0)]
        : [const Color(0xFFE8EEFF).withValues(alpha: 0.35), const Color(0xFFB8C6FF).withValues(alpha: 0.0)];

    final paint = Paint()
      ..shader = RadialGradient(colors: colors).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);

    // 主体太阳/月亮
    final corePaint = Paint()..color = isDay ? const Color(0xFFFFE38C) : const Color(0xFFF0F4FF);
    canvas.drawCircle(center, baseRadius * 0.28, corePaint);
  }

  @override
  bool shouldRepaint(covariant _SunPainter oldDelegate) => oldDelegate.t != t || oldDelegate.isDay != isDay;
}
