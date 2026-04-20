import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

// 缓存的原始位置（不含城市名）
class CachedPosition {
  final double latitude;
  final double longitude;
  final DateTime savedAt;
  const CachedPosition({required this.latitude, required this.longitude, required this.savedAt});
}

// 简单 KV 缓存
// - 天气 JSON
// - 上次使用的城市（城市名 + 经纬度）
// - 上次成功拿到的原始 GPS 位置（经纬度 + 时间戳，24h 内可用）
class CacheService {
  static const _kWeatherJson = 'cache.weather.json';
  static const _kLastCity = 'cache.last_city';
  static const _kPosition = 'cache.position';

  Future<void> saveWeatherJson(Map<String, dynamic> wrapper) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kWeatherJson, jsonEncode(wrapper));
  }

  Future<Map<String, dynamic>?> loadWeatherJson() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kWeatherJson);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLastCity(Map<String, dynamic> city) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLastCity, jsonEncode(city));
  }

  Future<Map<String, dynamic>?> loadLastCity() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kLastCity);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // 缓存原始 GPS 位置；下次冷启动如果 Geolocator 的 lastKnown 被系统清了还能当兜底
  Future<void> savePosition(double latitude, double longitude) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      _kPosition,
      jsonEncode({'lat': latitude, 'lon': longitude, 'savedAt': DateTime.now().toIso8601String()}),
    );
  }

  // 只返回 maxAge 以内的缓存位置，太老当无效
  Future<CachedPosition?> loadPosition({Duration maxAge = const Duration(hours: 24)}) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kPosition);
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.tryParse(m['savedAt'] as String? ?? '');
      if (savedAt == null) return null;
      if (DateTime.now().difference(savedAt) > maxAge) return null;
      final lat = (m['lat'] as num?)?.toDouble();
      final lon = (m['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) return null;
      return CachedPosition(latitude: lat, longitude: lon, savedAt: savedAt);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kWeatherJson);
    await sp.remove(_kLastCity);
    await sp.remove(_kPosition);
  }
}
