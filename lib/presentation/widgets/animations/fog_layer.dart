import 'dart:math';

import 'package:flutter/material.dart';

// 雾：几条缓慢飘移的横向白带
class FogLayer extends StatefulWidget {
  const FogLayer({super.key});

  @override
  State<FogLayer> createState() => _FogLayerState();
}

class _Band {
  double x;
  final double y;
  final double width;
  final double height;
  final double speed;
  final double opacity;
  _Band({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.speed,
    required this.opacity,
  });
}

class _FogLayerState extends State<FogLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rng = Random();
  final List<_Band> _bands = [];
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 90))..repeat();
  }

  void _ensure(Size size) {
    if (size == _size && _bands.isNotEmpty) return;
    _size = size;
    _bands.clear();
    for (var i = 0; i < 6; i++) {
      _bands.add(
        _Band(
          x: _rng.nextDouble() * size.width,
          y: size.height * (0.2 + _rng.nextDouble() * 0.7),
          width: size.width * (0.6 + _rng.nextDouble() * 0.6),
          height: 40 + _rng.nextDouble() * 60,
          speed: 0.1 + _rng.nextDouble() * 0.2,
          opacity: 0.1 + _rng.nextDouble() * 0.18,
        ),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        _ensure(size);
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            for (final b in _bands) {
              b.x += b.speed;
              if (b.x > size.width) b.x = -b.width;
            }
            return CustomPaint(size: size, painter: _FogPainter(_bands));
          },
        );
      },
    );
  }
}

class _FogPainter extends CustomPainter {
  final List<_Band> bands;
  _FogPainter(this.bands);

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bands) {
      final rect = Rect.fromLTWH(b.x, b.y, b.width, b.height);
      // 横向椭圆的渐变雾带
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: b.opacity),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect);
      canvas.drawOval(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FogPainter oldDelegate) => true;
}
