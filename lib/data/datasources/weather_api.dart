import 'package:dio/dio.dart';

// Open-Meteo 封装，返回原始 JSON map，让 repository 去解析
class WeatherApi {
  final Dio _dio;

  WeatherApi({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: {'Accept': 'application/json'},
            ),
          );

  // 拉当前/小时/每日天气一把梭
  Future<Map<String, dynamic>> fetchForecast({required double latitude, required double longitude}) async {
    final resp = await _dio.get(
      'https://api.open-meteo.com/v1/forecast',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        // 当前观测
        'current':
            'temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,'
            'weather_code,wind_speed_10m,wind_direction_10m,surface_pressure,'
            'uv_index,is_day',
        // 未来 48 小时
        'hourly': 'temperature_2m,precipitation_probability,weather_code,wind_speed_10m',
        'forecast_hours': 48,
        // 未来 7 天
        'daily': 'weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_sum',
        'forecast_days': 7,
        'timezone': 'auto',
      },
    );
    return resp.data as Map<String, dynamic>;
  }

  // 空气质量单独一个接口
  Future<Map<String, dynamic>?> fetchAirQuality({required double latitude, required double longitude}) async {
    try {
      final resp = await _dio.get(
        'https://air-quality-api.open-meteo.com/v1/air-quality',
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          'current': 'pm2_5,pm10,us_aqi',
          'timezone': 'auto',
        },
      );
      return resp.data as Map<String, dynamic>;
    } catch (_) {
      // 空气质量拉不到不影响主流程，吞掉
      return null;
    }
  }

  // 城市搜索：
  // - 输入含中文：language=zh，多拿一些结果，然后过滤出 country_code='CN'
  //   这样"上海""杭州"直接命中中国城市，不会混进海外同名地点
  // - 纯英文输入：全球搜索，language=en
  Future<List<dynamic>> searchCity(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final hasChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(q);
    final resp = await _dio.get(
      'https://geocoding-api.open-meteo.com/v1/search',
      queryParameters: {
        'name': q,
        // 中文多拿几条，方便过滤后还剩足够结果
        'count': hasChinese ? 20 : 10,
        'language': hasChinese ? 'zh' : 'en',
        'format': 'json',
      },
    );
    final data = resp.data as Map<String, dynamic>;
    final all = (data['results'] as List?) ?? [];

    if (!hasChinese) return all;

    // 中文输入优先展示中国结果；完全没中国结果才回退全部（例如搜"京都""东京"）
    final cn = all.where((e) {
      final m = e as Map<String, dynamic>;
      return m['country_code'] == 'CN';
    }).toList();
    return cn.isNotEmpty ? cn : all;
  }
}
