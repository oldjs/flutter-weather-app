import 'package:intl/intl.dart';

// 格式化工具
class Fmt {
  // 24h 时间 13:00
  static String hm(DateTime t) => DateFormat('HH:mm').format(t);

  // 小时预报里显示小时
  static String hourOnly(DateTime t) => DateFormat('HH').format(t) + '时';

  // 周几
  static String weekday(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(t.year, t.month, t.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '明天';
    // intl的中文本地化已经提供"周一..周日"
    return DateFormat('EEEE', 'zh_CN').format(t);
  }

  // 日期 M/d
  static String mdDate(DateTime t) => DateFormat('M/d').format(t);

  // 温度：四舍五入到整数，不加°
  static String tempInt(double t) => t.round().toString();

  // 风向角度转文字
  static String windDirText(double deg) {
    const names = ['北', '东北', '东', '东南', '南', '西南', '西', '西北'];
    // 每 45° 一个方向，从北偏 -22.5° 算起
    final idx = (((deg + 22.5) % 360) / 45).floor() % 8;
    return names[idx];
  }

  // 紫外线等级
  static String uvLevel(double uv) {
    if (uv < 3) return '弱';
    if (uv < 6) return '中等';
    if (uv < 8) return '强';
    if (uv < 11) return '很强';
    return '极强';
  }

  // AQI 等级
  static String aqiLevel(int aqi) {
    if (aqi <= 50) return '优';
    if (aqi <= 100) return '良';
    if (aqi <= 150) return '轻度污染';
    if (aqi <= 200) return '中度污染';
    if (aqi <= 300) return '重度污染';
    return '严重污染';
  }
}
