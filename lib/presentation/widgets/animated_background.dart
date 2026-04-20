import 'package:flutter/material.dart';

import '../../core/constants/weather_codes.dart';
import '../../core/theme/weather_theme.dart';
import 'animations/cloud_layer.dart';
import 'animations/fog_layer.dart';
import 'animations/rain_layer.dart';
import 'animations/snow_layer.dart';
import 'animations/sun_layer.dart';
import 'animations/thunder_layer.dart';

// 根据天气类型选背景：底层是渐变，上面叠一个对应动效
class AnimatedBackground extends StatelessWidget {
  final WeatherKind kind;
  final bool isDay;

  const AnimatedBackground({super.key, required this.kind, required this.isDay});

  @override
  Widget build(BuildContext context) {
    final theme = WeatherTheme.of(kind, isDay: isDay);
    return AnimatedContainer(
      // 切换天气时渐变会平滑过渡
      duration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: theme.gradient),
      ),
      child: Stack(children: [..._layersFor(kind)]),
    );
  }

  // 每种天气叠一组动效层
  List<Widget> _layersFor(WeatherKind kind) {
    switch (kind) {
      case WeatherKind.clear:
        return [SunLayer(isDay: isDay)];
      case WeatherKind.partlyCloudy:
        return [SunLayer(isDay: isDay), const CloudLayer(heavy: false)];
      case WeatherKind.cloudy:
        return const [CloudLayer(heavy: true)];
      case WeatherKind.fog:
        return const [CloudLayer(heavy: true), FogLayer()];
      case WeatherKind.drizzle:
        return const [CloudLayer(heavy: true), RainLayer(heavy: false)];
      case WeatherKind.rain:
        return const [CloudLayer(heavy: true), RainLayer(heavy: true)];
      case WeatherKind.snow:
        return const [CloudLayer(heavy: true), SnowLayer()];
      case WeatherKind.thunderstorm:
        return const [CloudLayer(heavy: true), RainLayer(heavy: true), ThunderLayer()];
    }
  }
}
