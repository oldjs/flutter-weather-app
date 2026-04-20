import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

// 替代 SnackBar 的自定义 Toast
// 从顶部下滑进入，2.4 秒后淡出，走 Overlay 不依赖 Scaffold
class Toast {
  static OverlayEntry? _current;
  static Timer? _timer;

  static void show(BuildContext context, String message) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    // 先清掉上一条
    _current?.remove();
    _timer?.cancel();

    final entry = OverlayEntry(builder: (_) => _ToastView(message: message));
    _current = entry;
    overlay.insert(entry);

    _timer = Timer(const Duration(milliseconds: 2400), () {
      _current?.remove();
      _current = null;
    });
  }
}

class _ToastView extends StatefulWidget {
  final String message;
  const _ToastView({required this.message});

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 240))..forward();
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, -0.4), end: Offset.zero).animate(_opacity);

    // 2 秒后自己淡出
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) _ctrl.reverse();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Positioned(
      top: padding.top + 16,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _opacity,
            child: SlideTransition(
              position: _slide,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
                    ),
                    child: Text(
                      widget.message,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
