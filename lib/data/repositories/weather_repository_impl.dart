import '../../domain/entities/city.dart';
import '../../domain/entities/weather.dart';
import '../../domain/repositories/weather_repository.dart';
import '../datasources/cache_service.dart';
import '../datasources/weather_api.dart';

class WeatherRepositoryImpl implements WeatherRepository {
  final WeatherApi api;
  final CacheService cache;

  WeatherRepositoryImpl({required this.api, required this.cache});

  @override
  Future<WeatherBundle> fetchWeather({
    required double latitude,
    required double longitude,
    required String cityName,
  }) async {
    // 并发拉取 天气和空气质量，加快首屏
    final futures = await Future.wait([
      api.fetchForecast(latitude: latitude, longitude: longitude),
      api.fetchAirQuality(latitude: latitude, longitude: longitude),
    ]);
    final forecast = futures[0] as Map<String, dynamic>;
    final airJson = futures[1] as Map<String, dynamic>?;

    final bundle = _parseBundle(
      forecast: forecast,
      airJson: airJson,
      cityName: cityName,
      latitude: latitude,
      longitude: longitude,
    );

    // 写缓存，顺便记一下当前城市方便下次冷启动恢复
    await cache.saveWeatherJson({
      'forecast': forecast,
      'air': airJson,
      'cityName': cityName,
      'latitude': latitude,
      'longitude': longitude,
      'fetchedAt': bundle.fetchedAt.toIso8601String(),
    });
    await cache.saveLastCity({'name': cityName, 'latitude': latitude, 'longitude': longitude});

    return bundle;
  }

  @override
  Future<List<City>> searchCity(String query) async {
    final list = await api.searchCity(query);
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return City(
        name: m['name'] as String? ?? '',
        admin1: m['admin1'] as String?,
        country: m['country'] as String?,
        latitude: (m['latitude'] as num).toDouble(),
        longitude: (m['longitude'] as num).toDouble(),
      );
    }).toList();
  }

  @override
  Future<WeatherBundle?> getCachedWeather() async {
    final raw = await cache.loadWeatherJson();
    if (raw == null) return null;
    try {
      return _parseBundle(
        forecast: raw['forecast'] as Map<String, dynamic>,
        airJson: raw['air'] as Map<String, dynamic>?,
        cityName: raw['cityName'] as String? ?? '未知',
        latitude: (raw['latitude'] as num).toDouble(),
        longitude: (raw['longitude'] as num).toDouble(),
        fetchedAtOverride: DateTime.tryParse(raw['fetchedAt'] as String? ?? ''),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearCache() => cache.clear();

  // 把 open-meteo 的扁平数组转成领域对象
  WeatherBundle _parseBundle({
    required Map<String, dynamic> forecast,
    required Map<String, dynamic>? airJson,
    required String cityName,
    required double latitude,
    required double longitude,
    DateTime? fetchedAtOverride,
  }) {
    final current = forecast['current'] as Map<String, dynamic>;
    final currentWeather = CurrentWeather(
      temperature: _toDouble(current['temperature_2m']),
      apparentTemperature: _toDouble(current['apparent_temperature']),
      humidity: _toDouble(current['relative_humidity_2m']),
      precipitation: _toDouble(current['precipitation']),
      weatherCode: (current['weather_code'] as num?)?.toInt() ?? 0,
      windSpeed: _toDouble(current['wind_speed_10m']),
      windDirection: _toDouble(current['wind_direction_10m']),
      surfacePressure: _toDouble(current['surface_pressure']),
      uvIndex: _toDouble(current['uv_index']),
      time: DateTime.parse(current['time'] as String),
      isDay: (current['is_day'] as num?)?.toInt() == 1,
    );

    // 小时预报转置：open-meteo 每个字段是独立数组
    final hourlyMap = forecast['hourly'] as Map<String, dynamic>;
    final hourlyTimes = (hourlyMap['time'] as List).cast<String>();
    final hourlyTemps = (hourlyMap['temperature_2m'] as List).cast<num>();
    final hourlyCodes = (hourlyMap['weather_code'] as List).cast<num>();
    final hourlyPP = (hourlyMap['precipitation_probability'] as List?)?.cast<num?>() ?? [];
    final hourlyWS = (hourlyMap['wind_speed_10m'] as List).cast<num>();
    final hourly = <HourlyWeather>[];
    for (var i = 0; i < hourlyTimes.length; i++) {
      hourly.add(
        HourlyWeather(
          time: DateTime.parse(hourlyTimes[i]),
          temperature: hourlyTemps[i].toDouble(),
          weatherCode: hourlyCodes[i].toInt(),
          precipitationProbability: (i < hourlyPP.length ? hourlyPP[i]?.toDouble() : null) ?? 0,
          windSpeed: hourlyWS[i].toDouble(),
        ),
      );
    }

    final dailyMap = forecast['daily'] as Map<String, dynamic>;
    final dailyTimes = (dailyMap['time'] as List).cast<String>();
    final dailyCodes = (dailyMap['weather_code'] as List).cast<num>();
    final dailyMax = (dailyMap['temperature_2m_max'] as List).cast<num>();
    final dailyMin = (dailyMap['temperature_2m_min'] as List).cast<num>();
    final dailySunrise = (dailyMap['sunrise'] as List).cast<String>();
    final dailySunset = (dailyMap['sunset'] as List).cast<String>();
    final dailyUv = (dailyMap['uv_index_max'] as List?)?.cast<num?>() ?? [];
    final dailyPrecip = (dailyMap['precipitation_sum'] as List?)?.cast<num?>() ?? [];
    final daily = <DailyWeather>[];
    for (var i = 0; i < dailyTimes.length; i++) {
      daily.add(
        DailyWeather(
          date: DateTime.parse(dailyTimes[i]),
          weatherCode: dailyCodes[i].toInt(),
          tempMax: dailyMax[i].toDouble(),
          tempMin: dailyMin[i].toDouble(),
          sunrise: DateTime.parse(dailySunrise[i]),
          sunset: DateTime.parse(dailySunset[i]),
          uvIndexMax: (i < dailyUv.length ? dailyUv[i]?.toDouble() : null) ?? 0,
          precipitationSum: (i < dailyPrecip.length ? dailyPrecip[i]?.toDouble() : null) ?? 0,
        ),
      );
    }

    AirQuality? air;
    if (airJson != null && airJson['current'] is Map<String, dynamic>) {
      final a = airJson['current'] as Map<String, dynamic>;
      air = AirQuality(
        pm25: _toDouble(a['pm2_5']),
        pm10: _toDouble(a['pm10']),
        usAqi: (a['us_aqi'] as num?)?.toInt() ?? 0,
      );
    }

    return WeatherBundle(
      cityName: cityName,
      latitude: latitude,
      longitude: longitude,
      current: currentWeather,
      hourly: hourly,
      daily: daily,
      airQuality: air,
      fetchedAt: fetchedAtOverride ?? DateTime.now(),
    );
  }

  // 统一 num→double 转换（open-meteo 偶尔会缺字段）
  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
