import 'package:flutter/material.dart';

import '../../core/constants/weather_codes.dart';
import '../../core/theme/weather_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/weather.dart';

// 顶部大字温度和天气描述
class CurrentWeatherCard extends StatelessWidget {
  final String cityName;
  final CurrentWeather current;
  final WeatherTheme theme;

  const CurrentWeatherCard({super.key, required this.cityName, required this.current, required this.theme});

  @override
  Widget build(BuildContext context) {
    final kind = WeatherCodes.kindOf(current.weatherCode);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 城市名
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on_rounded, size: 18, color: theme.foreground),
            const SizedBox(width: 4),
            Text(
              cityName,
              style: TextStyle(color: theme.foreground, fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 巨型温度数字
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Fmt.tempInt(current.temperature),
              style: TextStyle(
                color: theme.foreground,
                fontSize: 128,
                height: 1,
                fontWeight: FontWeight.w200,
                letterSpacing: -4,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                '°',
                style: TextStyle(color: theme.foreground, fontSize: 56, fontWeight: FontWeight.w200),
              ),
            ),
          ],
        ),
        // 天气描述 + 图标
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(WeatherCodes.iconOf(current.weatherCode, isDay: current.isDay), color: theme.foreground, size: 24),
            const SizedBox(width: 8),
            Text(
              WeatherCodes.descriptionOf(current.weatherCode),
              style: TextStyle(color: theme.foreground, fontSize: 20),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 高低温 + 体感
        Text(
          '体感 ${Fmt.tempInt(current.apparentTemperature)}°   ${_kindToTag(kind)}',
          style: TextStyle(color: theme.subtleForeground, fontSize: 14),
        ),
      ],
    );
  }

  // 给天气加个简短标签
  String _kindToTag(WeatherKind k) {
    switch (k) {
      case WeatherKind.clear:
        return '天气晴朗';
      case WeatherKind.partlyCloudy:
        return '云淡风轻';
      case WeatherKind.cloudy:
        return '阴云密布';
      case WeatherKind.fog:
        return '能见度低';
      case WeatherKind.drizzle:
        return '注意路滑';
      case WeatherKind.rain:
        return '记得带伞';
      case WeatherKind.snow:
        return '注意保暖';
      case WeatherKind.thunderstorm:
        return '避免户外';
    }
  }
}
