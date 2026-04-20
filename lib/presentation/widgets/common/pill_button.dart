import 'dart:ui';

import 'package:flutter/material.dart';

// 顶栏用的圆形毛玻璃按钮，替代 IconButton
// 不带任何 MD 水波纹，按下只做一个轻微缩放
class PillButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double size;
  final Color baseColor; // 半透明底色
  final Color borderColor;

  const PillButton({
    super.key,
    required this.child,
    required this.onTap,
    this.size = 40,
    this.baseColor = const Color(0x33FFFFFF),
    this.borderColor = const Color(0x26FFFFFF),
  });

  @override
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.baseColor,
                shape: BoxShape.circle,
                border: Border.all(color: widget.borderColor, width: 0.5),
              ),
              alignment: Alignment.center,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

// 扁平矩形按钮，替代 FilledButton 之类
class FlatPillButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Color foreground;
  final Color background;

  const FlatPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.foreground = Colors.white,
    this.background = const Color(0x33FFFFFF),
  });

  @override
  State<FlatPillButton> createState() => _FlatPillButtonState();
}

class _FlatPillButtonState extends State<FlatPillButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: widget.background,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 0.5),
              ),
              child: Text(
                widget.label,
                style: TextStyle(color: widget.foreground, fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
