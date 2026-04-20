import 'dart:math';

import 'package:flutter/material.dart';

// 雷暴：底层雨 + 周期性闪电白屏
class ThunderLayer extends StatefulWidget {
  const ThunderLayer({super.key});

  @override
  State<ThunderLayer> createState() => _ThunderLayerState();
}

class _ThunderLayerState extends State<ThunderLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rng = Random();
  double _flashAlpha = 0;
  int _frames = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _ctrl.addListener(_onTick);
  }

  void _onTick() {
    _frames++;
    // 闪电是瞬时的：大部分时间 alpha=0，随机间隔快速闪两下
    if (_flashAlpha > 0) {
      _flashAlpha -= 0.08;
      if (_flashAlpha < 0) _flashAlpha = 0;
      setState(() {});
    } else if (_frames > 40 && _rng.nextDouble() < 0.02) {
      _frames = 0;
      _flashAlpha = 0.6;
      setState(() {});
      // 连续两次闪，更像真雷
      Future.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        setState(() => _flashAlpha = 0.5);
      });
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTick);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 闪电只是全屏白覆盖层
    return IgnorePointer(
      child: Container(color: Colors.white.withValues(alpha: _flashAlpha)),
    );
  }
}
