import 'dart:math';

import 'package:flutter/material.dart';

// 雾气由多层模糊大色块构成，不同速度、不同透明度漂移
// 越"远"(small depth) 越慢越淡、越"近"越快越明显，产生深度感
class _FogBlob {
  double x;
  final double y;
  final double w;
  final double h;
  final double speed;
  final double alpha;
  final double blur;
  _FogBlob({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.speed,
    required this.alpha,
    required this.blur,
  });
}

class FogLayer extends StatefulWidget {
  const FogLayer({super.key});

  @override
  State<FogLayer> createState() => _FogLayerState();
}

class _FogLayerState extends State<FogLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rng = Random();
  final List<_FogBlob> _blobs = [];
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 120))..repeat();
  }

  void _ensure(Size size) {
    if (size == _size && _blobs.isNotEmpty) return;
    _size = size;
    _blobs.clear();
    // 三层：远、中、近
    _addLayer(size, count: 3, depth: 0.2); // 远
    _addLayer(size, count: 4, depth: 0.55); // 中
    _addLayer(size, count: 3, depth: 0.9); // 近
  }

  void _addLayer(Size size, {required int count, required double depth}) {
    for (var i = 0; i < count; i++) {
      _blobs.add(
        _FogBlob(
          x: _rng.nextDouble() * size.width * 1.2 - size.width * 0.1,
          y: size.height * (0.1 + _rng.nextDouble() * 0.8),
          w: size.width * (0.55 + _rng.nextDouble() * 0.7),
          h: 60 + _rng.nextDouble() * 90 + depth * 40,
          speed: 0.15 + depth * 0.55,
          alpha: 0.06 + depth * 0.18,
          blur: 20 + depth * 30,
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
            for (final b in _blobs) {
              b.x += b.speed;
              if (b.x > size.width) b.x = -b.w;
            }
            return CustomPaint(size: size, painter: _FogPainter(_blobs));
          },
        );
      },
    );
  }
}

class _FogPainter extends CustomPainter {
  final List<_FogBlob> blobs;
  _FogPainter(this.blobs);

  @override
  void paint(Canvas canvas, Size size) {
    // 裁剪到屏幕，避免大块模糊溢出
    canvas.clipRect(Offset.zero & size);
    for (final b in blobs) {
      final rect = Rect.fromLTWH(b.x, b.y, b.w, b.h);
      // BlurMaskFilter 给雾气真正的模糊感，不是硬边椭圆
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: b.alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, b.blur);
      canvas.drawOval(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FogPainter oldDelegate) => true;
}
