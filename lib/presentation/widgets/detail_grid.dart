import 'package:flutter/material.dart';

import '../../core/theme/weather_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/weather.dart';
import 'glass_card.dart';

// 湿度/风/气压/紫外线 等四宫格详情
class DetailGrid extends StatelessWidget {
  final CurrentWeather current;
  final WeatherTheme theme;
  const DetailGrid({super.key, required this.current, required this.theme});

  @override
  Widget build(BuildContext context) {
    final items = [
      _Item(icon: Icons.water_drop_outlined, label: '湿度', value: '${current.humidity.round()}%'),
      _Item(
        icon: Icons.air,
        label: '风',
        value: '${Fmt.windDirText(current.windDirection)} ${current.windSpeed.round()} km/h',
      ),
      _Item(icon: Icons.compress_rounded, label: '气压', value: '${current.surfacePressure.round()} hPa'),
      _Item(icon: Icons.wb_sunny_outlined, label: '紫外线', value: '${Fmt.uvLevel(current.uvIndex)} ${current.uvIndex.toStringAsFixed(1)}'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items.map((i) => _Tile(item: i, theme: theme)).toList(),
    );
  }
}

class _Item {
  final IconData icon;
  final String label;
  final String value;
  _Item({required this.icon, required this.label, required this.value});
}

class _Tile extends StatelessWidget {
  final _Item item;
  final WeatherTheme theme;
  const _Tile({required this.item, required this.theme});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      theme: theme,
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(item.icon, color: theme.subtleForeground, size: 16),
              const SizedBox(width: 6),
              Text(
                item.label,
                style: TextStyle(color: theme.subtleForeground, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.value,
            style: TextStyle(color: theme.foreground, fontSize: 18, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
