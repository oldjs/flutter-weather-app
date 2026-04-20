import 'package:flutter/material.dart';

import '../../core/theme/weather_theme.dart';

// 毛玻璃风格的卡片容器，全局复用
class GlassCard extends StatelessWidget {
  final Widget child;
  final WeatherTheme theme;
  final EdgeInsetsGeometry padding;
  final String? title;

  const GlassCard({
    super.key,
    required this.child,
    required this.theme,
    this.padding = const EdgeInsets.all(16),
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.cardBorder, width: 1),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: TextStyle(color: theme.subtleForeground, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}
