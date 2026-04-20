import 'dart:math';

import 'package:flutter/material.dart';

// 云朵漂移：几团半透明云在屏幕上方水平飘过
class CloudLayer extends StatefulWidget {
  final bool heavy; // 阴天云更多更厚
  const CloudLayer({super.key, this.heavy = false});

  @override
  State<CloudLayer> createState() => _CloudLayerState();
}

class _Cloud {
  double x;
  final double y;
  final double scale;
  final double speed;
  final double opacity;
  _Cloud({required this.x, required this.y, required this.scale, required this.speed, required this.opacity});
}

class _CloudLayerState extends State<CloudLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rng = Random();
  final List<_Cloud> _clouds = [];
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  }

  void _ensure(Size size) {
    if (size == _size && _clouds.isNotEmpty) return;
    _size = size;
    _clouds.clear();
    final count = widget.heavy ? 6 : 4;
    for (var i = 0; i < count; i++) {
      _clouds.add(
        _Cloud(
          x: _rng.nextDouble() * size.width,
          y: 30 + _rng.nextDouble() * size.height * 0.4,
          scale: 0.7 + _rng.nextDouble() * 0.8,
          speed: 0.15 + _rng.nextDouble() * 0.3,
          opacity: widget.heavy ? 0.65 + _rng.nextDouble() * 0.2 : 0.35 + _rng.nextDouble() * 0.3,
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
            for (final c in _clouds) {
              c.x += c.speed;
              if (c.x > size.width + 120) c.x = -200;
            }
            return CustomPaint(size: size, painter: _CloudPainter(_clouds));
          },
        );
      },
    );
  }
}

class _CloudPainter extends CustomPainter {
  final List<_Cloud> clouds;
  _CloudPainter(this.clouds);

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in clouds) {
      final paint = Paint()..color = Colors.white.withValues(alpha: c.opacity);
      // 一朵云用三个圆叠一起
      final base = Offset(c.x, c.y);
      canvas.drawCircle(base, 28 * c.scale, paint);
      canvas.drawCircle(base.translate(30 * c.scale, -10 * c.scale), 34 * c.scale, paint);
      canvas.drawCircle(base.translate(60 * c.scale, 0), 26 * c.scale, paint);
      canvas.drawCircle(base.translate(90 * c.scale, 4 * c.scale), 22 * c.scale, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CloudPainter oldDelegate) => true;
}
