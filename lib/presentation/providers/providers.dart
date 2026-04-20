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

// 当前目标位置：城市名 + 经纬度；null 表示还没决定（等定位或缓存）
class TargetLocation {
  final String name;
  final double latitude;
  final double longitude;
  const TargetLocation({required this.name, required this.latitude, required this.longitude});
}

// 北京作为最后的兜底位置
const _defaultFallback = TargetLocation(name: '北京', latitude: 39.9042, longitude: 116.4074);

// 多级 fallback 解析目标位置：缓存 → 上次已知 → 新 GPS → IP → 默认北京
// 永远不会抛，拿不到就返回北京 + 抛一个旗标让 UI 提示
Future<TargetLocation> _resolveLocation(Ref ref, {required bool preferFreshGps}) async {
  final loc = ref.read(locationServiceProvider);

  // 非强制 GPS 场景（启动时）才优先用缓存的城市
  if (!preferFreshGps) {
    final cachedCity = await ref.read(cacheServiceProvider).loadLastCity();
    if (cachedCity != null) {
      return TargetLocation(
        name: cachedCity['name'] as String? ?? '当前位置',
        latitude: (cachedCity['latitude'] as num).toDouble(),
        longitude: (cachedCity['longitude'] as num).toDouble(),
      );
    }
  }

  // 先问系统要上次已知位置，秒出不卡屏
  final last = await loc.getLastKnown();
  // 启动时拿到就用；手动定位按钮要求更新位置就不能用陈旧值
  if (last != null && !preferFreshGps) {
    return TargetLocation(name: '当前位置', latitude: last.latitude, longitude: last.longitude);
  }

  // 真正去锁 GPS，30 秒超时
  try {
    final pos = await loc.getCurrent();
    return TargetLocation(name: '当前位置', latitude: pos.latitude, longitude: pos.longitude);
  } catch (_) {
    // GPS 挂了：手动点定位的场景若之前拿到 lastKnown 就先用上
    if (last != null) {
      return TargetLocation(name: '当前位置', latitude: last.latitude, longitude: last.longitude);
    }
    // 再试 IP 定位（室内或没 GPS 模块也能用）
    final ip = await ref.read(ipLocationServiceProvider).locate();
    if (ip != null) {
      return TargetLocation(name: ip.cityName, latitude: ip.latitude, longitude: ip.longitude);
    }
    // 最后兜底：直接用北京，不让 App 卡死
    return _defaultFallback;
  }
}

// 手动选择城市/重新定位会写入这个 Notifier
class TargetLocationNotifier extends StateNotifier<TargetLocation?> {
  TargetLocationNotifier(this._ref) : super(null);
  final Ref _ref;

  void set(TargetLocation loc) => state = loc;

  // 主动调一次 GPS，返回一条展示给用户的消息（成功返回 null）
  // 不抛异常，GPS 失败时自己走 lastKnown → IP → 默认 的兜底链
  Future<String?> useGps() async {
    final locSvc = _ref.read(locationServiceProvider);
    try {
      final fresh = await locSvc.getCurrent();
      state = TargetLocation(name: '当前位置', latitude: fresh.latitude, longitude: fresh.longitude);
      return null;
    } on LocationException catch (e) {
      // 先用上次已知位置顶上
      final last = await locSvc.getLastKnown();
      if (last != null) {
        state = TargetLocation(name: '当前位置', latitude: last.latitude, longitude: last.longitude);
        return '${e.message}，已用上次位置';
      }
      // 再试 IP 定位
      final ip = await _ref.read(ipLocationServiceProvider).locate();
      if (ip != null) {
        state = TargetLocation(name: ip.cityName, latitude: ip.latitude, longitude: ip.longitude);
        return '${e.message}，已用 IP 定位';
      }
      // 全都不行，用默认城市
      state = _defaultFallback;
      return '${e.message}，已使用默认城市';
    }
  }
}

final targetLocationProvider = StateNotifierProvider<TargetLocationNotifier, TargetLocation?>((ref) {
  return TargetLocationNotifier(ref);
});

// 初次启动流程：缓存 → lastKnown → GPS → IP → 默认，永不抛
final initialLocationProvider = FutureProvider<TargetLocation>((ref) async {
  return _resolveLocation(ref, preferFreshGps: false);
});

// 天气数据
final weatherProvider = FutureProvider.autoDispose<WeatherBundle>((ref) async {
  final repo = ref.watch(weatherRepositoryProvider);

  // 优先看手动选的城市
  final manual = ref.watch(targetLocationProvider);
  TargetLocation loc;
  if (manual != null) {
    loc = manual;
  } else {
    loc = await ref.watch(initialLocationProvider.future);
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
