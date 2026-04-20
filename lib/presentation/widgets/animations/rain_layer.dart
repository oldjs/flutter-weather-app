import 'dart:math';

import 'package:flutter/material.dart';

// 雨滴粒子
class _Drop {
  double x;
  double y;
  double speed; // 下落速度 px/帧
  double length; // 雨丝长度
  double opacity;
  _Drop(this.x, this.y, this.speed, this.length, this.opacity);
}

class RainLayer extends StatefulWidget {
  final bool heavy; // true 暴雨，false 小雨
  const RainLayer({super.key, this.heavy = false});

  @override
  State<RainLayer> createState() => _RainLayerState();
}

class _RainLayerState extends State<RainLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rng = Random();
  final List<_Drop> _drops = [];
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    // 用一个长周期controller驱动重绘，每帧手动更新粒子位置
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  }

  void _ensureDrops(Size size) {
    if (size == _size && _drops.isNotEmpty) return;
    _size = size;
    _drops.clear();
    // 屏幕面积越大雨滴越多，暴雨加倍
    final base = (size.width * size.height / 6000).round();
    final count = widget.heavy ? base * 2 : base;
    for (var i = 0; i < count; i++) {
      _drops.add(_newDrop(size, fresh: false));
    }
  }

  _Drop _newDrop(Size size, {required bool fresh}) {
    // fresh=true 表示刚重生，从屏幕上方起步；否则随机高度，避免所有雨滴同时出现
    return _Drop(
      _rng.nextDouble() * size.width,
      fresh ? -_rng.nextDouble() * 80 : _rng.nextDouble() * size.height,
      6 + _rng.nextDouble() * (widget.heavy ? 14 : 8),
      8 + _rng.nextDouble() * (widget.heavy ? 18 : 10),
      0.3 + _rng.nextDouble() * 0.5,
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
            // 手动推进粒子
            for (var i = 0; i < _drops.length; i++) {
              final d = _drops[i];
              d.y += d.speed;
              d.x -= d.speed * 0.15; // 雨丝略向左斜
              if (d.y > size.height + 20 || d.x < -20) {
                _drops[i] = _newDrop(size, fresh: true);
              }
            }
            return CustomPaint(size: size, painter: _RainPainter(_drops));
          },
        );
      },
    );
  }
}

class _RainPainter extends CustomPainter {
  final List<_Drop> drops;
  _RainPainter(this.drops);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (final d in drops) {
      paint
        ..color = Colors.white.withValues(alpha: d.opacity)
        ..strokeWidth = 1.2;
      // 雨丝画成斜线
      canvas.drawLine(Offset(d.x, d.y), Offset(d.x + d.length * 0.15, d.y + d.length), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RainPainter oldDelegate) => true;
}
