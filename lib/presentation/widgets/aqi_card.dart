import 'package:flutter/material.dart';

import '../../core/theme/weather_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/weather.dart';
import 'glass_card.dart';

// AQI 卡片：数值 + 等级 + 颜色条
class AqiCard extends StatelessWidget {
  final AirQuality air;
  final WeatherTheme theme;
  const AqiCard({super.key, required this.air, required this.theme});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(air.usAqi);
    return GlassCard(
      theme: theme,
      title: '空气质量',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${air.usAqi}',
                style: TextStyle(color: theme.foreground, fontSize: 32, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    Fmt.aqiLevel(air.usAqi),
                    style: TextStyle(color: theme.foreground, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 6段颜色条 + 当前位置指针
          _AqiBar(aqi: air.usAqi),
          const SizedBox(height: 12),
          Row(
            children: [
              _pm('PM2.5', air.pm25),
              const SizedBox(width: 24),
              _pm('PM10', air.pm10),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pm(String label, double v) => Row(
    children: [
      Text(
        '$label ',
        style: TextStyle(color: theme.subtleForeground, fontSize: 12),
      ),
      Text(
        v.toStringAsFixed(0),
        style: TextStyle(color: theme.foreground, fontSize: 13, fontWeight: FontWeight.w500),
      ),
    ],
  );

  // 根据 AQI 值取对应等级色
  Color _colorFor(int aqi) {
    if (aqi <= 50) return const Color(0xFF4CAF50);
    if (aqi <= 100) return const Color(0xFFFFC107);
    if (aqi <= 150) return const Color(0xFFFF9800);
    if (aqi <= 200) return const Color(0xFFF44336);
    if (aqi <= 300) return const Color(0xFF9C27B0);
    return const Color(0xFF6A1B9A);
  }
}

class _AqiBar extends StatelessWidget {
  final int aqi;
  const _AqiBar({required this.aqi});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        // 以 500 为满，超过就钉在末端
        final ratio = (aqi / 500).clamp(0.0, 1.0);
        return SizedBox(
          height: 14,
          child: Stack(
            children: [
              Container(
                height: 6,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF4CAF50),
                      Color(0xFFFFC107),
                      Color(0xFFFF9800),
                      Color(0xFFF44336),
                      Color(0xFF9C27B0),
                      Color(0xFF6A1B9A),
                    ],
                  ),
                ),
              ),
              // 指针
              Positioned(
                left: (c.maxWidth - 10) * ratio,
                child: Container(
                  width: 10,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)],
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
