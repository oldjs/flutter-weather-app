// 坐标 vs 设备时区的合理性校验
//
// 踩过的坑：GPS last-known / IP 定位 / 缓存位置 都可能给出明显错的坐标——
// 最常见是中国用户被甩到东京（ISP 跨境路由、旧 mock location、出差后的残留
// 定位）。设备时区一般是靠谱的（用户自己设过），拿它来交叉校验坐标能拦住
// 大部分"定位乱跑"的情况。
//
// 策略：
//   UTC+8  → 中国+东南亚白名单 lon 73..135, lat 0..55（把东京 139°E 拦住，
//             同时不误伤新加坡/马来西亚/菲律宾等同时区用户）
//   UTC+9  → 日韩白名单 lon 125..150, lat 30..46
//   其他时区 → 粗粒度经度带 |lon - off*15°| <= 35°
bool plausibleForDeviceTimezone(double lat, double lon) {
  // 物理合法性先判一道
  if (lat.isNaN || lon.isNaN) return false;
  if (lat.abs() > 90 || lon.abs() > 180) return false;
  // Null Island (0, 0) 九成是坏数据
  if (lat == 0 && lon == 0) return false;

  final off = DateTime.now().timeZoneOffset.inHours;

  // UTC+8 中国标准时间：中国 + 东南亚同时区国家
  // 经度 73..135 覆盖新疆到黑龙江、东京 139°E 会被挡住
  // 纬度 0..55 覆盖漠河到新加坡/马来西亚/菲律宾
  if (off == 8) {
    return lon >= 73 && lon <= 135 && lat >= 0 && lat <= 55;
  }
  // UTC+9 日本/韩国
  if (off == 9) {
    return lon >= 125 && lon <= 150 && lat >= 30 && lat <= 46;
  }

  // 其他时区给一个 ±35° 的粗经度带，跨境国家(俄罗斯、美国)也 hold 得住
  final expectedLon = off * 15.0;
  var dLon = (lon - expectedLon) % 360;
  if (dLon > 180) dLon -= 360;
  if (dLon < -180) dLon += 360;
  return dLon.abs() <= 35 && lat.abs() <= 75;
}
