import '../entities/city.dart';
import '../entities/weather.dart';

// 仓库抽象，让presentation层不依赖data层的具体实现
abstract class WeatherRepository {
  // 拉取一次完整天气数据
  Future<WeatherBundle> fetchWeather({
    required double latitude,
    required double longitude,
    required String cityName,
  });

  // 城市搜索
  Future<List<City>> searchCity(String query);

  // 读缓存
  Future<WeatherBundle?> getCachedWeather();

  // 清缓存（调试用）
  Future<void> clearCache();
}
