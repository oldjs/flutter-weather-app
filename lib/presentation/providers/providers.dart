import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/cache_service.dart';
import '../../data/datasources/location_service.dart';
import '../../data/datasources/weather_api.dart';
import '../../data/repositories/weather_repository_impl.dart';
import '../../domain/entities/weather.dart';
import '../../domain/repositories/weather_repository.dart';

// 数据源 & 仓库
final weatherApiProvider = Provider<WeatherApi>((ref) => WeatherApi());
final cacheServiceProvider = Provider<CacheService>((ref) => CacheService());
final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  return WeatherRepositoryImpl(api: ref.watch(weatherApiProvider), cache: ref.watch(cacheServiceProvider));
});

// 当前目标位置：城市名 + 经纬度；null 表示还没决定（等定位或缓存）
class TargetLocation {
  final String name;
  final double latitude;
  final double longitude;
  const TargetLocation({required this.name, required this.latitude, required this.longitude});
}

// 手动选择城市/重新定位会写入这个 Notifier
class TargetLocationNotifier extends StateNotifier<TargetLocation?> {
  TargetLocationNotifier(this._ref) : super(null);
  final Ref _ref;

  void set(TargetLocation loc) => state = loc;

  // 主动调一次 GPS
  Future<void> useGps() async {
    final pos = await _ref.read(locationServiceProvider).getCurrent();
    state = TargetLocation(name: '当前位置', latitude: pos.latitude, longitude: pos.longitude);
  }
}

final targetLocationProvider = StateNotifierProvider<TargetLocationNotifier, TargetLocation?>((ref) {
  return TargetLocationNotifier(ref);
});

// 初次启动流程：先用缓存城市、否则定位；解析出 TargetLocation
final initialLocationProvider = FutureProvider<TargetLocation>((ref) async {
  final cache = ref.watch(cacheServiceProvider);
  final cachedCity = await cache.loadLastCity();
  if (cachedCity != null) {
    return TargetLocation(
      name: cachedCity['name'] as String? ?? '当前位置',
      latitude: (cachedCity['latitude'] as num).toDouble(),
      longitude: (cachedCity['longitude'] as num).toDouble(),
    );
  }
  // 没有缓存，走定位
  final loc = ref.watch(locationServiceProvider);
  final pos = await loc.getCurrent();
  return TargetLocation(name: '当前位置', latitude: pos.latitude, longitude: pos.longitude);
});

// 天气数据：依赖 TargetLocation，拿到位置后拉一次
final weatherProvider = FutureProvider.autoDispose<WeatherBundle>((ref) async {
  final repo = ref.watch(weatherRepositoryProvider);

  // 优先看手动选的城市
  final manual = ref.watch(targetLocationProvider);
  TargetLocation loc;
  if (manual != null) {
    loc = manual;
  } else {
    // 否则用初次启动解析出的位置
    final initial = await ref.watch(initialLocationProvider.future);
    loc = initial;
  }

  try {
    return await repo.fetchWeather(latitude: loc.latitude, longitude: loc.longitude, cityName: loc.name);
  } catch (e) {
    // 网络挂了就退回缓存
    final cached = await repo.getCachedWeather();
    if (cached != null) return cached;
    rethrow;
  }
});
