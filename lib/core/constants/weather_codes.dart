import 'package:flutter/material.dart';

// WMO 天气代码分类，方便判断动效和背景
enum WeatherKind {
  clear, // 晴
  partlyCloudy, // 多云
  cloudy, // 阴
  fog, // 雾
  drizzle, // 毛毛雨
  rain, // 雨
  snow, // 雪
  thunderstorm, // 雷暴
}

// WMO 代码映射工具
class WeatherCodes {
  // 把 WMO 代码归一化为简化的天气类型
  static WeatherKind kindOf(int code) {
    if (code == 0) return WeatherKind.clear;
    if (code == 1 || code == 2) return WeatherKind.partlyCloudy;
    if (code == 3) return WeatherKind.cloudy;
    if (code == 45 || code == 48) return WeatherKind.fog;
    if (code >= 51 && code <= 57) return WeatherKind.drizzle;
    if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) return WeatherKind.rain;
    if ((code >= 71 && code <= 77) || code == 85 || code == 86) return WeatherKind.snow;
    if (code >= 95 && code <= 99) return WeatherKind.thunderstorm;
    return WeatherKind.clear;
  }

  // 中文描述
  static String descriptionOf(int code) {
    switch (code) {
      case 0:
        return '晴';
      case 1:
        return '大部晴朗';
      case 2:
        return '多云';
      case 3:
        return '阴';
      case 45:
        return '雾';
      case 48:
        return '雾凇';
      case 51:
        return '小毛毛雨';
      case 53:
        return '中毛毛雨';
      case 55:
        return '大毛毛雨';
      case 56:
      case 57:
        return '冻雨';
      case 61:
        return '小雨';
      case 63:
        return '中雨';
      case 65:
        return '大雨';
      case 66:
      case 67:
        return '冻雨';
      case 71:
        return '小雪';
      case 73:
        return '中雪';
      case 75:
        return '大雪';
      case 77:
        return '雪粒';
      case 80:
        return '小阵雨';
      case 81:
        return '阵雨';
      case 82:
        return '强阵雨';
      case 85:
        return '小阵雪';
      case 86:
        return '大阵雪';
      case 95:
        return '雷阵雨';
      case 96:
        return '雷阵雨伴冰雹';
      case 99:
        return '强雷暴';
      default:
        return '未知';
    }
  }

  // 对应的 Material 图标，昼夜分开
  static IconData iconOf(int code, {bool isDay = true}) {
    final kind = kindOf(code);
    switch (kind) {
      case WeatherKind.clear:
        return isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round;
      case WeatherKind.partlyCloudy:
        return isDay ? Icons.wb_cloudy_rounded : Icons.cloud_rounded;
      case WeatherKind.cloudy:
        return Icons.cloud_rounded;
      case WeatherKind.fog:
        return Icons.foggy;
      case WeatherKind.drizzle:
      case WeatherKind.rain:
        return Icons.grain_rounded;
      case WeatherKind.snow:
        return Icons.ac_unit_rounded;
      case WeatherKind.thunderstorm:
        return Icons.flash_on_rounded;
    }
  }
}
