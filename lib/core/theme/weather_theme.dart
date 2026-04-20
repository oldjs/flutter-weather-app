import 'package:flutter/material.dart';

import '../constants/weather_codes.dart';

// 根据天气类型 + 昼夜 提供背景渐变和主色
class WeatherTheme {
  final List<Color> gradient; // 从上到下的渐变
  final Color accent; // UI 强调色（进度条、小图标）
  final Brightness brightness; // 深色背景用浅内容，反之亦然

  const WeatherTheme({required this.gradient, required this.accent, required this.brightness});

  // 主入口：根据天气类型和昼夜选主题
  static WeatherTheme of(WeatherKind kind, {required bool isDay}) {
    switch (kind) {
      case WeatherKind.clear:
        // 晴天：白天橙蓝渐变、夜晚深紫蓝
        return isDay
            ? const WeatherTheme(
                gradient: [Color(0xFF2E8BFF), Color(0xFF5EC3FF), Color(0xFFBFE4FF)],
                accent: Color(0xFFFFD166),
                brightness: Brightness.dark,
              )
            : const WeatherTheme(
                gradient: [Color(0xFF0B1E3F), Color(0xFF162D5B), Color(0xFF294173)],
                accent: Color(0xFFB8C6FF),
                brightness: Brightness.dark,
              );
      case WeatherKind.partlyCloudy:
        return isDay
            ? const WeatherTheme(
                gradient: [Color(0xFF4A8FD8), Color(0xFF7FB0DC), Color(0xFFC9D9E7)],
                accent: Color(0xFFFFFFFF),
                brightness: Brightness.dark,
              )
            : const WeatherTheme(
                gradient: [Color(0xFF1B2338), Color(0xFF2A3656), Color(0xFF3B4A70)],
                accent: Color(0xFFDBE3FF),
                brightness: Brightness.dark,
              );
      case WeatherKind.cloudy:
        return const WeatherTheme(
          gradient: [Color(0xFF4B5563), Color(0xFF6B7280), Color(0xFF9CA3AF)],
          accent: Color(0xFFE5E7EB),
          brightness: Brightness.dark,
        );
      case WeatherKind.fog:
        return const WeatherTheme(
          gradient: [Color(0xFF6B7280), Color(0xFF9CA3AF), Color(0xFFD1D5DB)],
          accent: Color(0xFFF3F4F6),
          brightness: Brightness.dark,
        );
      case WeatherKind.drizzle:
      case WeatherKind.rain:
        return const WeatherTheme(
          gradient: [Color(0xFF1F2B44), Color(0xFF34466A), Color(0xFF5A6F95)],
          accent: Color(0xFF8EC5FF),
          brightness: Brightness.dark,
        );
      case WeatherKind.snow:
        return const WeatherTheme(
          gradient: [Color(0xFF4A6FA5), Color(0xFF8AB0D6), Color(0xFFD6E6F5)],
          accent: Color(0xFFFFFFFF),
          brightness: Brightness.dark,
        );
      case WeatherKind.thunderstorm:
        return const WeatherTheme(
          gradient: [Color(0xFF111827), Color(0xFF1F2937), Color(0xFF374151)],
          accent: Color(0xFFFDE68A),
          brightness: Brightness.dark,
        );
    }
  }

  // UI 主色（白字/黑字）
  Color get foreground => brightness == Brightness.dark ? Colors.white : Colors.black87;

  Color get subtleForeground => foreground.withValues(alpha: 0.7);

  Color get cardBackground => foreground.withValues(alpha: 0.12);

  Color get cardBorder => foreground.withValues(alpha: 0.15);
}
