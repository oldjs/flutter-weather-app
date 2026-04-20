import 'package:flutter/material.dart';

import '../../core/constants/weather_codes.dart';
import '../../core/theme/weather_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/weather.dart';
import 'glass_card.dart';

// 24小时横向滚动预报
class HourlyForecast extends StatelessWidget {
  final List<HourlyWeather> hourly;
  final WeatherTheme theme;

  const HourlyForecast({super.key, required this.hourly, required this.theme});

  @override
  Widget build(BuildContext context) {
    // 只展示未来 24 小时
    final now = DateTime.now();
    final items = hourly.where((h) => !h.time.isBefore(now.subtract(const Duration(minutes: 30)))).take(24).toList();
    return GlassCard(
      theme: theme,
      title: '小时预报',
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: SizedBox(
        height: 100,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 16),
          itemBuilder: (_, i) {
            final h = items[i];
            final isNow = i == 0;
            return Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isNow ? '现在' : Fmt.hourOnly(h.time),
                  style: TextStyle(color: theme.foreground, fontSize: 13),
                ),
                Icon(WeatherCodes.iconOf(h.weatherCode), color: theme.foreground, size: 22),
                Text(
                  '${Fmt.tempInt(h.temperature)}°',
                  style: TextStyle(color: theme.foreground, fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
