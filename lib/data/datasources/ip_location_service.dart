import 'package:dio/dio.dart';

// IP 定位结果
class IpLocation {
  final double latitude;
  final double longitude;
  final String cityName;
  const IpLocation({required this.latitude, required this.longitude, required this.cityName});
}

// IP 地理位置兜底：GPS 挂了就用 IP 估一个位置
// 多提供商接力：有的 API 从数据中心 IP 被封（例如 ipapi.co 对 GitHub Actions），
// 所以按顺序试多个，任何一个成功就返回
class IpLocationService {
  final Dio _dio;

  IpLocationService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              // 比默认长一点，ipapi.co 偶尔慢
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              headers: {'Accept': 'application/json'},
            ),
          );

  // 顺序尝试多个 IP 定位提供商，都失败才返回 null
  Future<IpLocation?> locate() async {
    // 1. ipapi.co —— 国内用户走这个通常没问题
    final r1 = await _tryIpapiCo();
    if (r1 != null) return r1;
    // 2. ipwho.is —— 数据中心 IP 也不拦，CI 里靠这个兜底
    final r2 = await _tryIpwhoIs();
    if (r2 != null) return r2;
    return null;
  }

  Future<IpLocation?> _tryIpapiCo() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('https://ipapi.co/json/');
      final data = resp.data;
      if (data == null) return null;
      // ipapi.co 限流时返回 {"error": true, "reason": "..."}
      if (data['error'] == true) return null;
      final lat = data['latitude'];
      final lon = data['longitude'];
      if (lat is! num || lon is! num) return null;
      if (lat == 0 && lon == 0) return null;

      final city = (data['city'] as String?)?.trim();
      final region = (data['region'] as String?)?.trim();
      final country = (data['country_name'] as String?)?.trim();
      final name = _firstNonEmpty([city, region, country]) ?? '当前位置';
      return IpLocation(latitude: lat.toDouble(), longitude: lon.toDouble(), cityName: name);
    } catch (_) {
      return null;
    }
  }

  Future<IpLocation?> _tryIpwhoIs() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('https://ipwho.is/');
      final data = resp.data;
      if (data == null) return null;
      // ipwho.is 出错返回 success: false
      if (data['success'] == false) return null;
      final lat = data['latitude'];
      final lon = data['longitude'];
      if (lat is! num || lon is! num) return null;
      if (lat == 0 && lon == 0) return null;

      final city = (data['city'] as String?)?.trim();
      final region = (data['region'] as String?)?.trim();
      final country = (data['country'] as String?)?.trim();
      final name = _firstNonEmpty([city, region, country]) ?? '当前位置';
      return IpLocation(latitude: lat.toDouble(), longitude: lon.toDouble(), cityName: name);
    } catch (_) {
      return null;
    }
  }

  String? _firstNonEmpty(List<String?> xs) {
    for (final s in xs) {
      if (s != null && s.isNotEmpty) return s;
    }
    return null;
  }
}
