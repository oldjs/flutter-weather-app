import 'package:flutter/material.dart';

import '../../core/constants/weather_codes.dart';
import '../../core/theme/weather_theme.dart';
import '../../domain/entities/weather.dart';
import 'glass_card.dart';

// 生活指数：穿衣、运动、洗车、紫外线
class LifeIndex extends StatelessWidget {
  final CurrentWeather current;
  final WeatherTheme theme;
  const LifeIndex({super.key, required this.current, required this.theme});

  @override
  Widget build(BuildContext context) {
    final kind = WeatherCodes.kindOf(current.weatherCode);
    final items = [
      _Item(icon: Icons.checkroom_rounded, label: '穿衣', tip: _dressTip(current.apparentTemperature)),
      _Item(icon: Icons.directions_run_rounded, label: '运动', tip: _sportTip(kind)),
      _Item(icon: Icons.local_car_wash_outlined, label: '洗车', tip: _washTip(kind)),
      _Item(
        icon: Icons.wb_sunny_outlined,
        label: '紫外线',
        tip: current.uvIndex >= 6 ? '做好防晒' : current.uvIndex >= 3 ? '适度防护' : '无需防护',
      ),
    ];
    return GlassCard(
      theme: theme,
      title: '生活指数',
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.8,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: items.map((i) => _row(i)).toList(),
      ),
    );
  }

  Widget _row(_Item i) => Row(
    children: [
      Icon(i.icon, color: theme.subtleForeground, size: 18),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              i.label,
              style: TextStyle(color: theme.subtleForeground, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              i.tip,
              style: TextStyle(color: theme.foreground, fontSize: 13, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ],
  );

  String _dressTip(double t) {
    if (t >= 28) return '短袖清爽';
    if (t >= 22) return '轻薄长袖';
    if (t >= 15) return '加件薄外套';
    if (t >= 8) return '厚外套';
    if (t >= 0) return '羽绒服';
    return '多层保暖';
  }

  String _sportTip(WeatherKind k) {
    switch (k) {
      case WeatherKind.rain:
      case WeatherKind.drizzle:
      case WeatherKind.thunderstorm:
        return '室内为宜';
      case WeatherKind.snow:
      case WeatherKind.fog:
        return '不宜户外';
      default:
        return '适宜户外';
    }
  }

  String _washTip(WeatherKind k) {
    switch (k) {
      case WeatherKind.rain:
      case WeatherKind.drizzle:
      case WeatherKind.thunderstorm:
      case WeatherKind.snow:
        return '不宜洗车';
      default:
        return '适宜洗车';
    }
  }
}

class _Item {
  final IconData icon;
  final String label;
  final String tip;
  _Item({required this.icon, required this.label, required this.tip});
}
