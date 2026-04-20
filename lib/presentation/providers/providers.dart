import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/cache_service.dart';
import '../../data/datasources/ip_location_service.dart';
import '../../data/datasources/location_service.dart';
import '../../data/datasources/weather_api.dart';
import '../../data/repositories/weather_repository_impl.dart';
import '../../domain/entities/weather.dart';
import '../../domain/repositories/weather_repository.dart';

// 数据源 & 仓库
final weatherApiProvider = Provider<WeatherApi>((ref) => WeatherApi());
final cacheServiceProvider = Provider<CacheService>((ref) => CacheService());
final locationServiceProvider = Provider<LocationService>((ref) => LocationService());
final ipLocationServiceProvider = Provider<IpLocationService>((ref) => IpLocationService());

final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  return WeatherRepositoryImpl(api: ref.watch(weatherApiProvider), cache: ref.watch(cacheServiceProvider));
});

// 当前目标位置
class TargetLocation {
  final String name;
  final double latitude;
  final double longitude;
  const TargetLocation({required this.name, required this.latitude, required this.longitude});
}

// 北京做最后兜底
const _defaultFallback = TargetLocation(name: '北京', latitude: 39.9042, longitude: 116.4074);

// 启动时的位置解析链（按速度由快到慢）：
//   1. 上次用户选/定位的城市（cache.last_city，秒出，给之前有数据的用户稳定体验）
//   2. 24h 内缓存的原始 GPS 位置（cache.position）
//   3. 系统 getLastKnownPosition（毫秒级）
//   4. getCurrent（高精度 30s → 低精度 15s 两段重试）
//   5. IP 兜底定位
//   6. 默认北京
// 全链路不会抛异常
Future<TargetLocation> _resolveInitial(Ref ref) async {
  final cache = ref.read(cacheServiceProvider);
  final locSvc = ref.read(locationServiceProvider);

  // 1. 上次用过的城市（用户手动搜过或者上次 GPS 成功后记下的）
  final cachedCity = await cache.loadLastCity();
  if (cachedCity != null) {
    return TargetLocation(
      name: cachedCity['name'] as String? ?? '当前位置',
      latitude: (cachedCity['latitude'] as num).toDouble(),
      longitude: (cachedCity['longitude'] as num).toDouble(),
    );
  }

  // 2. 我们自己缓存的 24h 内位置（跨重启也活着）
  final cachedPos = await cache.loadPosition();
  if (cachedPos != null) {
    return TargetLocation(name: '当前位置', latitude: cachedPos.latitude, longitude: cachedPos.longitude);
  }

  // 3. 系统 lastKnown（Geolocator 维护的内存缓存）
  final last = await locSvc.getLastKnown();
  if (last != null) {
    await cache.savePosition(last.latitude, last.longitude);
    return TargetLocation(name: '当前位置', latitude: last.latitude, longitude: last.longitude);
  }

  // 4. 真正 getCurrent（内部已经做高→低两段重试）
  try {
    final pos = await locSvc.getCurrent();
    await cache.savePosition(pos.latitude, pos.longitude);
    return TargetLocation(name: '当前位置', latitude: pos.latitude, longitude: pos.longitude);
  } catch (_) {
    // 5. IP 兜底
    final ip = await ref.read(ipLocationServiceProvider).locate();
    if (ip != null) {
      return TargetLocation(name: ip.cityName, latitude: ip.latitude, longitude: ip.longitude);
    }
    // 6. 默认北京
    return _defaultFallback;
  }
}

// 手动"刷新定位"按钮用的 Notifier
class TargetLocationNotifier extends StateNotifier<TargetLocation?> {
  TargetLocationNotifier(this._ref) : super(null);
  final Ref _ref;

  void set(TargetLocation loc) => state = loc;

  // 用户主动点"定位"按钮：这里希望拿最新位置，不用 lastKnown
  // 返回值：null = 成功；非 null = 一条给用户看的降级原因
  Future<String?> useGps() async {
    final locSvc = _ref.read(locationServiceProvider);
    final cache = _ref.read(cacheServiceProvider);
    try {
      // getCurrent 内部已经做了高精度→低精度两段重试
      final fresh = await locSvc.getCurrent();
      await cache.savePosition(fresh.latitude, fresh.longitude);
      state = TargetLocation(name: '当前位置', latitude: fresh.latitude, longitude: fresh.longitude);
      return null;
    } on LocationException catch (e) {
      // GPS 彻底挂了才走 fallback：lastKnown → IP → 默认
      final last = await locSvc.getLastKnown();
      if (last != null) {
        await cache.savePosition(last.latitude, last.longitude);
        state = TargetLocation(name: '当前位置', latitude: last.latitude, longitude: last.longitude);
        return '${e.message}，已用上次位置';
      }
      final ip = await _ref.read(ipLocationServiceProvider).locate();
      if (ip != null) {
        state = TargetLocation(name: ip.cityName, latitude: ip.latitude, longitude: ip.longitude);
        return '${e.message}，已用 IP 定位';
      }
      state = _defaultFallback;
      return '${e.message}，已使用默认城市';
    }
  }
}

final targetLocationProvider = StateNotifierProvider<TargetLocationNotifier, TargetLocation?>((ref) {
  return TargetLocationNotifier(ref);
});

// 冷启动定位解析（永不抛）
final initialLocationProvider = FutureProvider<TargetLocation>((ref) async {
  return _resolveInitial(ref);
});

// 天气数据
final weatherProvider = FutureProvider.autoDispose<WeatherBundle>((ref) async {
  final repo = ref.watch(weatherRepositoryProvider);

  // 手动选的城市优先
  final manual = ref.watch(targetLocationProvider);
  TargetLocation loc;
  if (manual != null) {
    loc = manual;
  } else {
    loc = await ref.watch(initialLocationProvider.future);
  }

  try {
    return await repo.fetchWeather(latitude: loc.latitude, longitude: loc.longitude, cityName: loc.name);
  } catch (_) {
    // 网络挂了就退回缓存天气，打上 stale 标记让 UI 显"缓存数据"
    final cached = await repo.getCachedWeather();
    if (cached != null) return cached.markStale();
    rethrow;
  }
});
