import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'spinner.dart';

// 自定义下拉刷新 Sliver，基于 CupertinoSliverRefreshControl
// 不用 RefreshIndicator 的 MD 小圆环，而是用我们自己的 Spinner
class PullRefresh extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const PullRefresh({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return CupertinoSliverRefreshControl(
      onRefresh: onRefresh,
      builder: (context, mode, pulled, threshold, indicator) {
        // 计算拉动进度，0 到 1
        final progress = (pulled / threshold).clamp(0.0, 1.2);
        return Center(
          child: SizedBox(
            height: pulled,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: mode == RefreshIndicatorMode.refresh || mode == RefreshIndicatorMode.armed
                  ? const Spinner(size: 22, strokeWidth: 2, color: Colors.white)
                  // 拉动阶段显示一个随进度变大的圆点组，给点反馈
                  : Opacity(
                      opacity: progress.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.6 + 0.4 * progress,
                        child: const Spinner(size: 22, strokeWidth: 2, color: Colors.white),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}
