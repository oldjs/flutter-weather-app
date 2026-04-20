import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

// 简单 KV 缓存，存天气 JSON 和上次使用的城市
class CacheService {
  static const _kWeatherJson = 'cache.weather.json';
  static const _kLastCity = 'cache.last_city';

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

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kWeatherJson);
    await sp.remove(_kLastCity);
  }
}
