import 'dart:math';

import 'package:flutter/material.dart';

// 雪花粒子
// depth: 0..1，近大近亮近快，摆动幅度也更大
class _Flake {
  double x;
  double y;
  final double depth;
  final double radius;
  final double speedY;
  final double wobbleAmp; // 左右摆动幅度
  final double wobbleFreq; // 摆动频率
  final double wobblePhase; // 初相位
  final double alpha;
  _Flake({
    required this.x,
    required this.y,
    required this.depth,
    required this.radius,
    required this.speedY,
    required this.wobbleAmp,
    required this.wobbleFreq,
    required this.wobblePhase,
    required this.alpha,
  });
}

class SnowLayer extends StatefulWidget {
  const SnowLayer({super.key});

  @override
  State<SnowLayer> createState() => _SnowLayerState();
}

class _SnowLayerState extends State<SnowLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rng = Random();
  final List<_Flake> _flakes = [];
  Size _size = Size.zero;
  double _time = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat();
  }

  void _ensureFlakes(Size size) {
    if (size == _size && _flakes.isNotEmpty) return;
    _size = size;
    _flakes.clear();
    // 比雨少很多，雪花轻盈但密度适中
    final count = (size.width * size.height / 7000).round().clamp(40, 120);
    for (var i = 0; i < count; i++) {
      _flakes.add(_newFlake(size, fresh: false));
    }
  }

  _Flake _newFlake(Size size, {required bool fresh}) {
    final depth = pow(_rng.nextDouble(), 1.2).toDouble();
    final r = 1.0 + depth * 3.8;
    return _Flake(
      x: _rng.nextDouble() * size.width,
      y: fresh ? -r * 3 : _rng.nextDouble() * size.height,
      depth: depth,
      radius: r,
      // 近的快，远的慢；整体比雨慢得多
      speedY: 0.4 + depth * 2.2,
      // 近处摆动大一些
      wobbleAmp: 6 + depth * 22,
      wobbleFreq: 0.3 + _rng.nextDouble() * 0.9,
      wobblePhase: _rng.nextDouble() * pi * 2,
      alpha: 0.35 + depth * 0.55,
    );
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
        _ensureFlakes(size);
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            _time += 0.035;
            for (var i = 0; i < _flakes.length; i++) {
              final f = _flakes[i];
              f.y += f.speedY;
              if (f.y > size.height + f.radius * 2) {
                _flakes[i] = _newFlake(size, fresh: true);
              }
            }
            return CustomPaint(size: size, painter: _SnowPainter(_flakes, _time));
          },
        );
      },
    );
  }
}

class _SnowPainter extends CustomPainter {
  final List<_Flake> flakes;
  final double time;
  _SnowPainter(this.flakes, this.time);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final f in flakes) {
      // sin 波给雪花横向摆动，x 不修改原始值，保持飘浮的"无规律"感
      final sway = sin(time * f.wobbleFreq + f.wobblePhase) * f.wobbleAmp;
      final cx = f.x + sway;
      // 近处雪花加一圈柔光晕，强化景深
      if (f.depth > 0.6) {
        paint.color = Colors.white.withValues(alpha: f.alpha * 0.25);
        canvas.drawCircle(Offset(cx, f.y), f.radius * 2.4, paint);
      }
      paint.color = Colors.white.withValues(alpha: f.alpha);
      canvas.drawCircle(Offset(cx, f.y), f.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SnowPainter oldDelegate) => true;
}
