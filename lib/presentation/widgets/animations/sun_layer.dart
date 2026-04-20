import 'dart:math';

import 'package:flutter/material.dart';

// 光线粒子：慢悠悠漂浮的小亮点，模拟阳光里的浮尘/镜头颗粒
class _LightDust {
  double x;
  double y;
  final double r;
  final double vx;
  final double vy;
  final double alpha;
  final double twinkleSeed;
  _LightDust({
    required this.x,
    required this.y,
    required this.r,
    required this.vx,
    required this.vy,
    required this.alpha,
    required this.twinkleSeed,
  });
}

class SunLayer extends StatefulWidget {
  final bool isDay;
  const SunLayer({super.key, this.isDay = true});

  @override
  State<SunLayer> createState() => _SunLayerState();
}

class _SunLayerState extends State<SunLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rng = Random();
  final List<_LightDust> _dust = [];
  Size _size = Size.zero;
  double _time = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  }

  void _ensureDust(Size size) {
    if (size == _size && _dust.isNotEmpty) return;
    _size = size;
    _dust.clear();
    // 浮尘粒子不多，精致感优先
    final count = (size.width * size.height / 14000).round().clamp(25, 60);
    for (var i = 0; i < count; i++) {
      _dust.add(_newDust(size));
    }
  }

  _LightDust _newDust(Size size, {bool fromBottom = false}) {
    final r = 0.8 + _rng.nextDouble() * 2.4;
    return _LightDust(
      x: _rng.nextDouble() * size.width,
      // 首次填充时 y 全屏随机，回收时从底部边缘飘上来
      y: fromBottom ? size.height + 10 : _rng.nextDouble() * size.height,
      r: r,
      vx: (_rng.nextDouble() - 0.5) * 0.3,
      vy: -(_rng.nextDouble() * 0.25 + 0.05), // 略向上飘
      alpha: 0.15 + _rng.nextDouble() * 0.45,
      twinkleSeed: _rng.nextDouble() * pi * 2,
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
        _ensureDust(size);
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            _time += 0.025;
            for (var i = 0; i < _dust.length; i++) {
              final p = _dust[i];
              p.x += p.vx;
              p.y += p.vy;
              if (p.y < -10 || p.x < -10 || p.x > size.width + 10) {
                _dust[i] = _newDust(size, fromBottom: true);
              }
            }
            return CustomPaint(size: size, painter: _SunPainter(dust: _dust, time: _time, isDay: widget.isDay));
          },
        );
      },
    );
  }
}

class _SunPainter extends CustomPainter {
  final List<_LightDust> dust;
  final double time;
  final bool isDay;
  _SunPainter({required this.dust, required this.time, required this.isDay});

  @override
  void paint(Canvas canvas, Size size) {
    if (isDay) {
      _paintSun(canvas, size);
      _paintLensFlare(canvas, size);
    } else {
      _paintMoon(canvas, size);
    }
    _paintDust(canvas);
  }

  // 白天太阳：右上角三层径向渐变，核心、中层光晕、外层大光晕
  void _paintSun(Canvas canvas, Size size) {
    final sun = Offset(size.width * 0.78, size.height * 0.18);
    // 外层大光晕
    final outer = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFFFFF3C4).withValues(alpha: 0.55), const Color(0x00FFF3C4)],
      ).createShader(Rect.fromCircle(center: sun, radius: size.width * 0.55));
    canvas.drawCircle(sun, size.width * 0.55, outer);
    // 中层
    final mid = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFFFFE38A).withValues(alpha: 0.75), const Color(0x00FFE38A)],
      ).createShader(Rect.fromCircle(center: sun, radius: size.width * 0.22));
    canvas.drawCircle(sun, size.width * 0.22, mid);
    // 核心 + 轻微呼吸
    final pulse = 1 + 0.06 * sin(time * 1.2);
    final core = Paint()
      ..shader = const RadialGradient(
        colors: [Colors.white, Color(0xFFFFD66B)],
      ).createShader(Rect.fromCircle(center: sun, radius: 32 * pulse));
    canvas.drawCircle(sun, 32 * pulse, core);
  }

  // 镜头光晕：从太阳到屏幕对角线方向排一串半透明小圆
  void _paintLensFlare(Canvas canvas, Size size) {
    final sun = Offset(size.width * 0.78, size.height * 0.18);
    final target = Offset(size.width * 0.2, size.height * 0.85);
    final axis = target - sun;
    final breathe = 0.7 + 0.3 * sin(time * 0.8);

    const spots = [
      _FlareSpot(t: 0.25, radius: 18, color: Color(0x55FFE3A3)),
      _FlareSpot(t: 0.42, radius: 30, color: Color(0x33FFB887)),
      _FlareSpot(t: 0.6, radius: 12, color: Color(0x66FFF3C4)),
      _FlareSpot(t: 0.78, radius: 44, color: Color(0x22A3C8FF)),
      _FlareSpot(t: 0.92, radius: 20, color: Color(0x44FFFFFF)),
    ];

    for (final s in spots) {
      final center = sun + axis * s.t;
      final alpha = s.color.a * breathe;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [s.color.withValues(alpha: alpha), s.color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: s.radius * 2));
      canvas.drawCircle(center, s.radius * 2, paint);
    }
  }

  // 夜晚：柔和月亮 + 月面浅影
  void _paintMoon(Canvas canvas, Size size) {
    final moon = Offset(size.width * 0.78, size.height * 0.2);
    final halo = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withValues(alpha: 0.25), const Color(0x00FFFFFF)],
      ).createShader(Rect.fromCircle(center: moon, radius: 120));
    canvas.drawCircle(moon, 120, halo);
    final body = Paint()..color = const Color(0xFFF4F1E6);
    canvas.drawCircle(moon, 28, body);
    final shade = Paint()..color = const Color(0xFFD6D0B8).withValues(alpha: 0.6);
    canvas.drawCircle(moon.translate(6, -4), 6, shade);
    canvas.drawCircle(moon.translate(-8, 6), 4, shade);
  }

  // 浮尘粒子 + 闪烁
  void _paintDust(Canvas canvas) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in dust) {
      final twinkle = 0.5 + 0.5 * sin(time * 2 + p.twinkleSeed);
      paint.color = Colors.white.withValues(alpha: p.alpha * twinkle);
      canvas.drawCircle(Offset(p.x, p.y), p.r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SunPainter oldDelegate) => true;
}

// 镜头光晕里的一个光斑
class _FlareSpot {
  final double t;
  final double radius;
  final Color color;
  const _FlareSpot({required this.t, required this.radius, required this.color});
}
