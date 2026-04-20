import 'dart:math';

import 'package:flutter/material.dart';

// 雨滴粒子
// depth: 0..1，越接近 1 越"近"：更大、更粗、更快、更亮
class _Drop {
  double x;
  double y;
  final double depth;
  final double speed;
  final double length;
  final double thickness;
  final double opacity;
  _Drop({
    required this.x,
    required this.y,
    required this.depth,
    required this.speed,
    required this.length,
    required this.thickness,
    required this.opacity,
  });
}

// 溅落水花
class _Splash {
  final double x;
  final double y;
  double life; // 1.0 → 0.0
  _Splash({required this.x, required this.y, required this.life});
}

class RainLayer extends StatefulWidget {
  final bool heavy;
  const RainLayer({super.key, this.heavy = false});

  @override
  State<RainLayer> createState() => _RainLayerState();
}

class _RainLayerState extends State<RainLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rng = Random();
  final List<_Drop> _drops = [];
  final List<_Splash> _splashes = [];
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    // 长周期 controller 做时间源，手动推进粒子
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat();
  }

  void _ensureDrops(Size size) {
    if (size == _size && _drops.isNotEmpty) return;
    _size = size;
    _drops.clear();
    // 屏幕面积算出基准数量：小雨 ~150 滴，暴雨 ~250 滴
    final area = size.width * size.height;
    final base = (area / 2500).round();
    final count = widget.heavy ? base : (base * 0.55).round();
    for (var i = 0; i < count; i++) {
      _drops.add(_newDrop(size, fresh: false));
    }
  }

  _Drop _newDrop(Size size, {required bool fresh}) {
    // depth 按 pow 分布，近滴数量略少，视觉更有层次
    final depth = pow(_rng.nextDouble(), 0.8).toDouble();
    return _Drop(
      // 雨从屏幕外一点开始，落下时会斜向左移
      x: _rng.nextDouble() * size.width * 1.2 - size.width * 0.05,
      y: fresh ? -_rng.nextDouble() * 60 - 10 : _rng.nextDouble() * size.height,
      depth: depth,
      speed: (widget.heavy ? 7 : 4.5) + depth * (widget.heavy ? 22 : 14),
      length: 5 + depth * (widget.heavy ? 26 : 18),
      thickness: 0.5 + depth * 1.8,
      opacity: 0.12 + depth * 0.65,
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
        _ensureDrops(size);
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            // 手动推进雨滴
            for (var i = 0; i < _drops.length; i++) {
              final d = _drops[i];
              d.y += d.speed;
              // 风向：雨丝斜向左
              d.x -= d.speed * 0.18;
              if (d.y > size.height || d.x < -size.width * 0.1) {
                // 只有"近处"的雨滴才溅起水花，粒子数有上限避免堆积
                if (d.depth > 0.55 && d.y > size.height && _splashes.length < 60) {
                  _splashes.add(_Splash(x: d.x, y: size.height - 2, life: 1.0));
                }
                _drops[i] = _newDrop(size, fresh: true);
              }
            }
            // 更新水花
            for (var i = _splashes.length - 1; i >= 0; i--) {
              _splashes[i].life -= 0.08;
              if (_splashes[i].life <= 0) _splashes.removeAt(i);
            }
            return CustomPaint(size: size, painter: _RainPainter(_drops, _splashes));
          },
        );
      },
    );
  }
}

class _RainPainter extends CustomPainter {
  final List<_Drop> drops;
  final List<_Splash> splashes;
  _RainPainter(this.drops, this.splashes);

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()..strokeCap = StrokeCap.round;
    // 先画远景（透明度低的），再画近景，模拟前后叠加
    for (final d in drops) {
      line
        ..color = Colors.white.withValues(alpha: d.opacity)
        ..strokeWidth = d.thickness;
      canvas.drawLine(
        Offset(d.x, d.y),
        Offset(d.x - d.length * 0.18, d.y + d.length),
        line,
      );
    }
    // 水花：以落点为中心向两侧斜上小短线 + 中心小光点
    final splash = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final s in splashes) {
      final a = s.life;
      final spread = (1 - a) * 10;
      splash
        ..color = Colors.white.withValues(alpha: a * 0.55)
        ..strokeWidth = 1.1;
      canvas.drawLine(Offset(s.x - spread, s.y), Offset(s.x - spread - 4, s.y - 3), splash);
      canvas.drawLine(Offset(s.x + spread, s.y), Offset(s.x + spread + 4, s.y - 3), splash);
      // 中心小光点
      final dot = Paint()..color = Colors.white.withValues(alpha: a * 0.35);
      canvas.drawCircle(Offset(s.x, s.y - 1), 1.2, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _RainPainter oldDelegate) => true;
}
