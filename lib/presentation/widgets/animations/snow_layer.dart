import 'dart:math';

import 'package:flutter/material.dart';

// 雪花粒子
class _Flake {
  double x;
  double y;
  double r; // 半径
  double speedY;
  double speedX;
  double wobbleSeed; // 摆动相位
  _Flake(this.x, this.y, this.r, this.speedY, this.speedX, this.wobbleSeed);
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
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
  }

  void _ensureFlakes(Size size) {
    if (size == _size && _flakes.isNotEmpty) return;
    _size = size;
    _flakes.clear();
    final count = (size.width * size.height / 12000).round();
    for (var i = 0; i < count; i++) {
      _flakes.add(_newFlake(size, fresh: false));
    }
  }

  _Flake _newFlake(Size size, {required bool fresh}) {
    final r = 1.5 + _rng.nextDouble() * 3.5;
    return _Flake(
      _rng.nextDouble() * size.width,
      fresh ? -r * 2 : _rng.nextDouble() * size.height,
      r,
      0.5 + _rng.nextDouble() * 1.5, // 雪花比雨慢很多
      (_rng.nextDouble() - 0.5) * 0.6,
      _rng.nextDouble() * pi * 2,
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
            _t += 0.05;
            for (var i = 0; i < _flakes.length; i++) {
              final f = _flakes[i];
              f.y += f.speedY;
              // 加点水平摆动，显得轻盈
              f.x += f.speedX + sin(_t + f.wobbleSeed) * 0.4;
              if (f.y > size.height + 5 || f.x < -10 || f.x > size.width + 10) {
                _flakes[i] = _newFlake(size, fresh: true);
              }
            }
            return CustomPaint(size: size, painter: _SnowPainter(_flakes));
          },
        );
      },
    );
  }
}

class _SnowPainter extends CustomPainter {
  final List<_Flake> flakes;
  _SnowPainter(this.flakes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final f in flakes) {
      paint.color = Colors.white.withValues(alpha: 0.8);
      canvas.drawCircle(Offset(f.x, f.y), f.r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SnowPainter oldDelegate) => true;
}
