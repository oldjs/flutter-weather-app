import 'dart:math';

import 'package:flutter/material.dart';

// 一朵云由一簇叠加的椭圆组成，每个椭圆有自己的偏移/缩放/透明度
// 多朵云按深度分层漂移：近云大而清晰，远云小而模糊
class _CloudBlob {
  final double dx;
  final double dy;
  final double rx;
  final double ry;
  final double alpha;
  const _CloudBlob({required this.dx, required this.dy, required this.rx, required this.ry, required this.alpha});
}

class _Cloud {
  double x;
  final double y;
  final double scale;
  final double speed;
  final double depth; // 0..1，越大越近
  final List<_CloudBlob> blobs;
  _Cloud({
    required this.x,
    required this.y,
    required this.scale,
    required this.speed,
    required this.depth,
    required this.blobs,
  });
}

class CloudLayer extends StatefulWidget {
  final bool heavy; // 阴天：更多更厚
  const CloudLayer({super.key, this.heavy = false});

  @override
  State<CloudLayer> createState() => _CloudLayerState();
}

class _CloudLayerState extends State<CloudLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rng = Random();
  final List<_Cloud> _clouds = [];
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 120))..repeat();
  }

  void _ensure(Size size) {
    if (size == _size && _clouds.isNotEmpty) return;
    _size = size;
    _clouds.clear();
    final count = widget.heavy ? 9 : 5;
    for (var i = 0; i < count; i++) {
      _clouds.add(_newCloud(size));
    }
  }

  _Cloud _newCloud(Size size) {
    final depth = _rng.nextDouble();
    final scale = 0.55 + depth * 1.4;
    return _Cloud(
      x: _rng.nextDouble() * size.width * 1.2 - size.width * 0.1,
      // 云多集中在上半屏
      y: 20 + _rng.nextDouble() * size.height * (widget.heavy ? 0.6 : 0.35),
      scale: scale,
      // 近云飘得快，远云慢
      speed: 0.08 + depth * 0.45,
      depth: depth,
      blobs: _buildBlobs(),
    );
  }

  // 随机生成一朵云的 6-10 个重叠椭圆块，模拟蓬松形状
  List<_CloudBlob> _buildBlobs() {
    final n = 6 + _rng.nextInt(5);
    final blobs = <_CloudBlob>[];
    for (var i = 0; i < n; i++) {
      // 以 (0,0) 为中心沿水平方向铺开，局部上下起伏
      final dx = (i - n / 2) * (18 + _rng.nextDouble() * 10);
      final dy = (_rng.nextDouble() - 0.5) * 16;
      final rx = 28 + _rng.nextDouble() * 24;
      final ry = 18 + _rng.nextDouble() * 14;
      blobs.add(_CloudBlob(dx: dx, dy: dy, rx: rx, ry: ry, alpha: 0.6 + _rng.nextDouble() * 0.4));
    }
    return blobs;
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
            for (var i = 0; i < _clouds.length; i++) {
              final cl = _clouds[i];
              cl.x += cl.speed;
              // 飘出右边，重置到屏幕左边一个距离外
              if (cl.x > size.width + 220 * cl.scale) {
                _clouds[i] = _Cloud(
                  x: -240 * cl.scale,
                  y: cl.y,
                  scale: cl.scale,
                  speed: cl.speed,
                  depth: cl.depth,
                  blobs: cl.blobs,
                );
              }
            }
            return CustomPaint(size: size, painter: _CloudPainter(_clouds, widget.heavy));
          },
        );
      },
    );
  }
}

class _CloudPainter extends CustomPainter {
  final List<_Cloud> clouds;
  final bool heavy;
  _CloudPainter(this.clouds, this.heavy);

  @override
  void paint(Canvas canvas, Size size) {
    // 先远后近，保证近云盖在远云上
    final sorted = [...clouds]..sort((a, b) => a.depth.compareTo(b.depth));

    for (final c in sorted) {
      // 阴天云偏灰白；一般云纯白
      final baseColor = heavy ? const Color(0xFFE6EAF0) : Colors.white;
      // 远云整体更淡，近云更实
      final baseAlpha = heavy ? 0.55 + c.depth * 0.35 : 0.35 + c.depth * 0.45;

      // 用 BlurMaskFilter 给每块椭圆柔化边缘；远云模糊更大
      final blur = 6 + (1 - c.depth) * 10;
      final paint = Paint()..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

      for (final b in c.blobs) {
        paint.color = baseColor.withValues(alpha: (baseAlpha * b.alpha).clamp(0.0, 1.0));
        final rect = Rect.fromCenter(
          center: Offset(c.x + b.dx * c.scale, c.y + b.dy * c.scale),
          width: b.rx * 2 * c.scale,
          height: b.ry * 2 * c.scale,
        );
        canvas.drawOval(rect, paint);
      }

      // 阴天再在云底压一道浅灰阴影，增强体积
      if (heavy && c.depth > 0.6) {
        final shade = Paint()
          ..color = const Color(0xFF8A94A4).withValues(alpha: 0.15 * c.depth)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
        for (final b in c.blobs) {
          final rect = Rect.fromCenter(
            center: Offset(c.x + b.dx * c.scale, c.y + (b.dy + 10) * c.scale),
            width: b.rx * 1.8 * c.scale,
            height: b.ry * 1.4 * c.scale,
          );
          canvas.drawOval(rect, shade);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CloudPainter oldDelegate) => true;
}
