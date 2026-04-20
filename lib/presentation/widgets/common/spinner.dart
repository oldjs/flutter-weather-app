import 'dart:math';

import 'package:flutter/material.dart';

// 自定义加载指示器：一段圆弧在转
// 完全 CustomPaint，没有 MD 圈圈的感觉
class Spinner extends StatefulWidget {
  final double size;
  final double strokeWidth;
  final Color color;

  const Spinner({super.key, this.size = 36, this.strokeWidth = 2.5, this.color = Colors.white});

  @override
  State<Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<Spinner> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          return CustomPaint(
            painter: _SpinnerPainter(
              t: _ctrl.value,
              color: widget.color,
              strokeWidth: widget.strokeWidth,
            ),
          );
        },
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  final double t;
  final Color color;
  final double strokeWidth;

  _SpinnerPainter({required this.t, required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = min(size.width, size.height) / 2 - strokeWidth;

    // 底层淡一圈
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color.withValues(alpha: 0.2);
    canvas.drawCircle(center, radius, bg);

    // 主弧：旋转 + 略微呼吸的长度
    final sweepLen = pi * 1.2;
    final startAngle = t * 2 * pi - pi / 2;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..color = color;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepLen, false, arc);
  }

  @override
  bool shouldRepaint(covariant _SpinnerPainter oldDelegate) => oldDelegate.t != t;
}
