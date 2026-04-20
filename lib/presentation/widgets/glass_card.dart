import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/weather_theme.dart';

// iOS/小米风格的毛玻璃卡片：真实的背景模糊 + 半透明叠色 + 细描边
// 完全 Container + ClipRRect + BackdropFilter 实现，没有 Material 的 Card
class GlassCard extends StatelessWidget {
  final Widget child;
  final WeatherTheme theme;
  final EdgeInsetsGeometry padding;
  final String? title;
  final IconData? titleIcon;

  const GlassCard({
    super.key,
    required this.child,
    required this.theme,
    this.padding = const EdgeInsets.all(18),
    this.title,
    this.titleIcon,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        // 真实高斯模糊，这是毛玻璃效果的关键
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.cardBorder, width: 0.6),
          ),
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null) ...[
                Row(
                  children: [
                    if (titleIcon != null) ...[
                      Icon(titleIcon, size: 13, color: theme.subtleForeground),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      title!,
                      style: TextStyle(
                        color: theme.subtleForeground,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                // 标题下的细分隔线，代替 Divider
                const SizedBox(height: 10),
                Container(height: 0.5, color: theme.foreground.withValues(alpha: 0.12)),
                const SizedBox(height: 14),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}
