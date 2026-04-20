import 'package:dio/dio.dart';

// IP 定位结果
class IpLocation {
  final double latitude;
  final double longitude;
  final String cityName;
  const IpLocation({required this.latitude, required this.longitude, required this.cityName});
}

// IP 地理位置兜底：GPS 挂了就用 IP 估一个位置
// 用 ipapi.co 免费接口，走 HTTPS，不需要 key
class IpLocationService {
  final Dio _dio;

  IpLocationService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 8),
              headers: {'Accept': 'application/json'},
            ),
          );

  // 拉 IP 定位，失败返回 null，永远不抛
  Future<IpLocation?> locate() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('https://ipapi.co/json/');
      final data = resp.data;
      if (data == null) return null;
      // ipapi 偶尔会返回 {"error": true} 限流响应
      if (data['error'] == true) return null;

      final lat = data['latitude'];
      final lon = data['longitude'];
      if (lat is! num || lon is! num) return null;

      // 城市名：优先 city，没有就用 region、国家兜底
      final city = (data['city'] as String?)?.trim();
      final region = (data['region'] as String?)?.trim();
      final country = (data['country_name'] as String?)?.trim();
      final name = [city, region, country].firstWhere((s) => s != null && s.isNotEmpty, orElse: () => null) ?? '当前位置';

      return IpLocation(latitude: lat.toDouble(), longitude: lon.toDouble(), cityName: name);
    } catch (_) {
      // 网络/解析失败都吞掉，让调用方走下一个 fallback
      return null;
    }
  }
}
