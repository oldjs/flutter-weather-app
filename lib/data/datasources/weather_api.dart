import 'package:dio/dio.dart';
import 'package:lpinyin/lpinyin.dart';

// Open-Meteo 封装，返回原始 JSON map，让 repository 去解析
class WeatherApi {
  final Dio _dio;

  WeatherApi({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              // 20s 给跨国链路（CI runner 到欧洲的 open-meteo）留点余地
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
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
        'current':
            'temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,'
            'weather_code,wind_speed_10m,wind_direction_10m,surface_pressure,'
            'uv_index,is_day',
        'hourly': 'temperature_2m,precipitation_probability,weather_code,wind_speed_10m',
        'forecast_hours': 48,
        'daily': 'weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_sum',
        'forecast_days': 7,
        'timezone': 'auto',
      },
    );
    return resp.data as Map<String, dynamic>;
  }

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
      return null;
    }
  }

  // 城市搜索
  //
  // 踩过的坑：Open-Meteo 的 geocoding name 参数只匹配 GeoNames 里的"主名称"。
  // 中国很多大城市主名称是拼音（南京 → "Nanjing"、杭州 → "Hangzhou"、成都 → "Chengdu"），
  // 用汉字搜不到；而另一些（济南、上海、广州）主名称就是汉字，能直接搜到。
  // 而且返回列表并不按 population 排序，结果里经常先冒出来一堆同名的小村庄。
  //
  // 策略：
  //   1) 中文输入并行打两发请求：原汉字 + 整串拼音（无分隔），两路结果都收
  //   2) 按 id 去重合并
  //   3) 优先中国结果（country_code='CN'），都不是中国才降级到全部
  //   4) 按 (feature_code 行政级别 ASC, population DESC) 排序，让真正的大城市浮到顶
  //      这样"杭州"→"Hangzhou" 拿到的 PPLA 9.2M 会把 PPL 的"四川杭州村"压在底下
  //   5) 英文输入全球单次搜索，不变
  Future<List<dynamic>> searchCity(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final hasChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(q);

    if (!hasChinese) {
      // 纯英文/拼音，单次全球搜索
      return _rawSearch(q, language: 'en', count: 10);
    }

    // 中文：同时打 汉字 和 拼音 两路
    final pinyin = PinyinHelper.getPinyinE(q, defPinyin: '', separator: '').trim();
    final futures = <Future<List<dynamic>>>[
      _rawSearch(q, language: 'zh', count: 20).catchError((_) => <dynamic>[]),
    ];
    // 拼音和原文不一样才打第二路（避免"济南" 转出来还是中文时重复请求）
    if (pinyin.isNotEmpty && pinyin != q) {
      futures.add(_rawSearch(pinyin, language: 'zh', count: 20).catchError((_) => <dynamic>[]));
    }
    final responses = await Future.wait(futures);

    // 按 id 去重合并
    final byId = <Object, Map<String, dynamic>>{};
    for (final list in responses) {
      for (final raw in list) {
        final m = raw as Map<String, dynamic>;
        final id = m['id'] as Object?;
        if (id == null) continue;
        byId.putIfAbsent(id, () => m);
      }
    }
    final merged = byId.values.toList();

    // 中国优先，没有中国结果才退回全部
    final cn = merged.where((m) => m['country_code'] == 'CN').toList();
    final pool = cn.isNotEmpty ? cn : merged;

    // 排序：行政级别高的在前，同级别按人口降序
    pool.sort((a, b) {
      final ra = _featureRank(a['feature_code'] as String?);
      final rb = _featureRank(b['feature_code'] as String?);
      if (ra != rb) return ra.compareTo(rb);
      final pa = (a['population'] as num?)?.toInt() ?? 0;
      final pb = (b['population'] as num?)?.toInt() ?? 0;
      return pb.compareTo(pa);
    });

    // 最多返回 15 条，足够选了
    return pool.take(15).toList();
  }

  // 行政级别排名（越小越优先）
  // GeoNames feature_code: PPLC=首都, PPLA=省会, PPLA2=地级市驻地, PPLA3=县级市驻地, PPLA4=乡镇驻地, PPL=一般聚居地
  int _featureRank(String? fc) {
    switch (fc) {
      case 'PPLC':
        return 0;
      case 'PPLA':
        return 1;
      case 'PPLA2':
        return 2;
      case 'PPLA3':
        return 3;
      case 'PPLA4':
        return 4;
      case 'PPL':
        return 5;
      default:
        return 6;
    }
  }

  // 原始搜索，不做任何处理
  Future<List<dynamic>> _rawSearch(String name, {required String language, required int count}) async {
    if (name.isEmpty) return [];
    final resp = await _dio.get(
      'https://geocoding-api.open-meteo.com/v1/search',
      queryParameters: {'name': name, 'count': count, 'language': language, 'format': 'json'},
    );
    final data = resp.data as Map<String, dynamic>;
    return (data['results'] as List?) ?? [];
  }
}
