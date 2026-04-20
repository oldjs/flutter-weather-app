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

// ---------------- 启动时的"快路径"位置解析 ----------------
//
// 核心原则：永远不阻塞等 GPS。GPS 放后台慢慢锁，拿到再更新。
// 所有步骤加起来应该在 2 秒内完成（IP 定位接口 8s 超时兜底）：
//
//   1. 上次用过的城市（内存/SharedPreferences，毫秒级）
//   2. 24h 内缓存的 GPS 位置（毫秒级）
//   3. 系统 getLastKnownPosition（毫秒级，可能返回 null）
//   4. IP 定位 ipapi.co（秒级，HTTPS，不要 key）
//   5. 默认北京
//
// 不调 getCurrent！那个最多等 45 秒，首屏体验会崩。
Future<TargetLocation> _resolveInitialFast(Ref ref) async {
  final cache = ref.read(cacheServiceProvider);
  final locSvc = ref.read(locationServiceProvider);

  // 1. 上次用过的城市
  final cachedCity = await cache.loadLastCity();
  if (cachedCity != null) {
    return TargetLocation(
      name: cachedCity['name'] as String? ?? '当前位置',
      latitude: (cachedCity['latitude'] as num).toDouble(),
      longitude: (cachedCity['longitude'] as num).toDouble(),
    );
  }

  // 2. 24h 内缓存的原始位置
  final cachedPos = await cache.loadPosition();
  if (cachedPos != null) {
    return TargetLocation(name: '当前位置', latitude: cachedPos.latitude, longitude: cachedPos.longitude);
  }

  // 3. 系统 lastKnown
  final last = await locSvc.getLastKnown();
  if (last != null) {
    await cache.savePosition(last.latitude, last.longitude);
    return TargetLocation(name: '当前位置', latitude: last.latitude, longitude: last.longitude);
  }

  // 4. IP 定位 —— 粗略但秒级返回，比等 GPS 强太多
  final ip = await ref.read(ipLocationServiceProvider).locate();
  if (ip != null) {
    return TargetLocation(name: ip.cityName, latitude: ip.latitude, longitude: ip.longitude);
  }

  // 5. 默认北京
  return _defaultFallback;
}

// 后台 GPS 精确化：fire-and-forget，成功就更新 targetLocation
// 差距小（< 5km）才触发更新，避免 IP 和 GPS 结果接近时还要重拉一次天气
void _refreshGpsInBackground(Ref ref, {required TargetLocation current}) {
  Future.microtask(() async {
    try {
      final pos = await ref.read(locationServiceProvider).getCurrent();
      await ref.read(cacheServiceProvider).savePosition(pos.latitude, pos.longitude);

      // 距离差太小就不更新，省一次刷新
      final dx = pos.latitude - current.latitude;
      final dy = pos.longitude - current.longitude;
      final farEnough = (dx * dx + dy * dy) > 0.005 * 0.005; // 约 500m
      if (!farEnough) return;

      // 用户没有手动指定城市时才刷 —— 手动选了就别覆盖
      final notifier = ref.read(targetLocationProvider.notifier);
      if (notifier.isManual) return;
      notifier.setAuto(TargetLocation(name: '当前位置', latitude: pos.latitude, longitude: pos.longitude));
    } catch (_) {
      // GPS 后台刷新失败不影响用户，默默丢掉
    }
  });
}

// ---------------- 位置状态 Notifier ----------------
class TargetLocationNotifier extends StateNotifier<TargetLocation?> {
  TargetLocationNotifier(this._ref) : super(null);
  final Ref _ref;
  bool _manual = false; // 用户是不是手动选过城市

  // 手动指定（搜索页选中）
  void set(TargetLocation loc) {
    _manual = true;
    state = loc;
  }

  // 后台 GPS 精确化自动刷新，不覆盖手动选择
  void setAuto(TargetLocation loc) {
    if (_manual) return;
    state = loc;
  }

  bool get isManual => _manual;

  // 主动点"定位"按钮：希望拿最新位置
  // 返回一条给用户的说明（null = 成功）；不抛异常
  Future<String?> useGps() async {
    final locSvc = _ref.read(locationServiceProvider);
    final cache = _ref.read(cacheServiceProvider);
    try {
      final fresh = await locSvc.getCurrent();
      await cache.savePosition(fresh.latitude, fresh.longitude);
      _manual = false; // 手动触发的定位仍算"自动位置"
      state = TargetLocation(name: '当前位置', latitude: fresh.latitude, longitude: fresh.longitude);
      return null;
    } on LocationException catch (e) {
      // GPS 彻底失败再走兜底
      final last = await locSvc.getLastKnown();
      if (last != null) {
        await cache.savePosition(last.latitude, last.longitude);
        _manual = false;
        state = TargetLocation(name: '当前位置', latitude: last.latitude, longitude: last.longitude);
        return '${e.message}，已用上次位置';
      }
      final ip = await _ref.read(ipLocationServiceProvider).locate();
      if (ip != null) {
        _manual = false;
        state = TargetLocation(name: ip.cityName, latitude: ip.latitude, longitude: ip.longitude);
        return '${e.message}，已用 IP 定位';
      }
      _manual = false;
      state = _defaultFallback;
      return '${e.message}，已使用默认城市';
    }
  }
}

final targetLocationProvider = StateNotifierProvider<TargetLocationNotifier, TargetLocation?>((ref) {
  return TargetLocationNotifier(ref);
});

// 冷启动定位解析（永不阻塞 GPS）
// 解析完立刻触发后台 GPS 精确化
final initialLocationProvider = FutureProvider<TargetLocation>((ref) async {
  final fast = await _resolveInitialFast(ref);
  // 后台 GPS 精确化，不等待
  _refreshGpsInBackground(ref, current: fast);
  return fast;
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
    // 网络挂了退回缓存，打上 stale 让 UI 提示
    final cached = await repo.getCachedWeather();
    if (cached != null) return cached.markStale();
    rethrow;
  }
});
