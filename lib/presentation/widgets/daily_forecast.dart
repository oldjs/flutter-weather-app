import 'package:flutter/material.dart';

import '../../core/constants/weather_codes.dart';
import '../../core/theme/weather_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/weather.dart';
import 'glass_card.dart';

// 7天预报列表
class DailyForecast extends StatelessWidget {
  final List<DailyWeather> daily;
  final WeatherTheme theme;

  const DailyForecast({super.key, required this.daily, required this.theme});

  @override
  Widget build(BuildContext context) {
    // 计算7天温度范围，用来画温度条
    final maxT = daily.map((d) => d.tempMax).reduce((a, b) => a > b ? a : b);
    final minT = daily.map((d) => d.tempMin).reduce((a, b) => a < b ? a : b);
    return GlassCard(
      theme: theme,
      title: '7天预报',
      child: Column(
        children: [
          for (final d in daily) _DailyRow(day: d, theme: theme, globalMax: maxT, globalMin: minT),
        ],
      ),
    );
  }
}

class _DailyRow extends StatelessWidget {
  final DailyWeather day;
  final WeatherTheme theme;
  final double globalMax;
  final double globalMin;
  const _DailyRow({required this.day, required this.theme, required this.globalMax, required this.globalMin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              Fmt.weekday(day.date),
              style: TextStyle(color: theme.foreground, fontSize: 14),
            ),
          ),
          Icon(WeatherCodes.iconOf(day.weatherCode), color: theme.foreground, size: 20),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              '${Fmt.tempInt(day.tempMin)}°',
              style: TextStyle(color: theme.subtleForeground, fontSize: 14),
            ),
          ),
          // 温度条
          Expanded(
            child: _TempRangeBar(
              min: day.tempMin,
              max: day.tempMax,
              globalMin: globalMin,
              globalMax: globalMax,
              theme: theme,
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${Fmt.tempInt(day.tempMax)}°',
              textAlign: TextAlign.right,
              style: TextStyle(color: theme.foreground, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// 画每日温度区间的小横条
class _TempRangeBar extends StatelessWidget {
  final double min;
  final double max;
  final double globalMin;
  final double globalMax;
  final WeatherTheme theme;
  const _TempRangeBar({
    required this.min,
    required this.max,
    required this.globalMin,
    required this.globalMax,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final totalRange = (globalMax - globalMin).clamp(1, 100).toDouble();
        final startRatio = (min - globalMin) / totalRange;
        final widthRatio = ((max - min) / totalRange).clamp(0.05, 1.0);
        final barWidth = c.maxWidth;
        return SizedBox(
          height: 6,
          child: Stack(
            children: [
              // 背景槽
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: theme.foreground.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // 当天温度区间
              Positioned(
                left: barWidth * startRatio,
                child: Container(
                  width: barWidth * widthRatio,
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [theme.accent.withValues(alpha: 0.6), theme.accent]),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
