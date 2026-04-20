import 'dart:math';

import 'package:flutter/material.dart';

// 一条闪电由多段折线构成，外加若干分叉
class _Bolt {
  final List<Offset> main; // 主干顶点
  final List<List<Offset>> branches; // 若干分支，每条也是折线
  double life; // 1.0 → 0.0
  _Bolt(this.main, this.branches) : life = 1.0;
}

class ThunderLayer extends StatefulWidget {
  const ThunderLayer({super.key});

  @override
  State<ThunderLayer> createState() => _ThunderLayerState();
}

class _ThunderLayerState extends State<ThunderLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rng = Random();
  final List<_Bolt> _bolts = [];
  double _flashAlpha = 0;
  int _frames = 0;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat();
    _ctrl.addListener(_onTick);
  }

  void _onTick() {
    _frames++;
    var changed = false;

    // 闪电 life 衰减
    for (final b in _bolts) {
      b.life -= 0.06;
    }
    _bolts.removeWhere((b) => b.life <= 0);
    if (_bolts.isNotEmpty) changed = true;

    // 白屏 flash 衰减
    if (_flashAlpha > 0) {
      _flashAlpha = (_flashAlpha - 0.07).clamp(0.0, 1.0);
      changed = true;
    }

    // 随机触发一次雷击
    if (_frames > 50 && _rng.nextDouble() < 0.018 && _size != Size.zero) {
      _frames = 0;
      _bolts.add(_buildBolt(_size));
      _flashAlpha = 0.55;
      changed = true;
      // 120ms 后再来一次补闪，像真雷
      Future.delayed(const Duration(milliseconds: 110), () {
        if (!mounted || _size == Size.zero) return;
        setState(() {
          _bolts.add(_buildBolt(_size));
          _flashAlpha = 0.45;
        });
      });
    }

    if (changed) setState(() {});
  }

  // 生成一条闪电：主干 + 分叉
  _Bolt _buildBolt(Size size) {
    final startX = size.width * (0.15 + _rng.nextDouble() * 0.7);
    final main = _generatePolyline(
      start: Offset(startX, -10),
      end: Offset(startX + (_rng.nextDouble() - 0.5) * size.width * 0.35, size.height * 0.6),
      segments: 14,
      jitter: size.width * 0.04,
    );

    // 主干上几个点拉出短分叉
    final branches = <List<Offset>>[];
    for (var i = 3; i < main.length - 1; i++) {
      if (_rng.nextDouble() < 0.28) {
        final from = main[i];
        final dir = _rng.nextBool() ? 1 : -1;
        final to = Offset(
          from.dx + dir * (30 + _rng.nextDouble() * 70),
          from.dy + (20 + _rng.nextDouble() * 50),
        );
        branches.add(_generatePolyline(start: from, end: to, segments: 4 + _rng.nextInt(3), jitter: 10));
      }
    }
    return _Bolt(main, branches);
  }

  // 在两点间生成带抖动的折线
  List<Offset> _generatePolyline({
    required Offset start,
    required Offset end,
    required int segments,
    required double jitter,
  }) {
    final pts = <Offset>[start];
    for (var i = 1; i < segments; i++) {
      final t = i / segments;
      final base = Offset.lerp(start, end, t)!;
      final dx = (_rng.nextDouble() - 0.5) * 2 * jitter;
      final dy = (_rng.nextDouble() - 0.5) * jitter * 0.4;
      pts.add(base.translate(dx, dy));
    }
    pts.add(end);
    return pts;
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTick);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        _size = Size(c.maxWidth, c.maxHeight);
        return IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 分叉闪电主体
              CustomPaint(painter: _BoltPainter(_bolts)),
              // 全屏白闪
              if (_flashAlpha > 0)
                Container(color: Colors.white.withValues(alpha: _flashAlpha)),
            ],
          ),
        );
      },
    );
  }
}

class _BoltPainter extends CustomPainter {
  final List<_Bolt> bolts;
  _BoltPainter(this.bolts);

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bolts) {
      // 外发光：粗淡蓝光
      final glow = Paint()
        ..color = const Color(0xFFCAD8FF).withValues(alpha: 0.35 * b.life)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      _strokePoly(canvas, b.main, glow);
      for (final br in b.branches) {
        _strokePoly(canvas, br, glow..strokeWidth = 4);
      }

      // 内核：亮白细线
      final core = Paint()
        ..color = Colors.white.withValues(alpha: b.life.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      _strokePoly(canvas, b.main, core);
      for (final br in b.branches) {
        _strokePoly(canvas, br, core..strokeWidth = 1.3);
      }
    }
  }

  void _strokePoly(Canvas canvas, List<Offset> pts, Paint paint) {
    if (pts.length < 2) return;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BoltPainter oldDelegate) => true;
}
