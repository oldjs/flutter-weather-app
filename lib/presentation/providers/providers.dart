import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/geo_sanity.dart';
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

// 按设备时区猜一个默认位置，作为"所有定位手段都失败"时的最后兜底
// 这 app 主要给中国用户用，所以 UTC+8/9 都兜底北京，不再给 UTC+9 兜东京
// （日本用户能从 IP 拿到正确坐标；fallback 只在 IP 也挂的极端情况才出现）
TargetLocation _fallbackByTimezone() {
  final offset = DateTime.now().timeZoneOffset.inHours;
  switch (offset) {
    case 8:
    case 9:
      return const TargetLocation(name: '北京', latitude: 39.9042, longitude: 116.4074);
    case 5:
    case 6:
      return const TargetLocation(name: '新德里', latitude: 28.6139, longitude: 77.2090);
    case 1:
    case 2:
      return const TargetLocation(name: 'Berlin', latitude: 52.52, longitude: 13.405);
    case 0:
      return const TargetLocation(name: 'London', latitude: 51.5074, longitude: -0.1278);
    case -5:
    case -4:
      return const TargetLocation(name: 'New York', latitude: 40.7128, longitude: -74.0060);
    case -8:
    case -7:
      return const TargetLocation(name: 'San Francisco', latitude: 37.7749, longitude: -122.4194);
    default:
      // 其它时区给个通用兜底：北京（大样本用户仍是东八区的中国用户）
      return const TargetLocation(name: '北京', latitude: 39.9042, longitude: 116.4074);
  }
}

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

  // 每一层都过坐标合理性闸门：挡住旧 mock location、跨境 IP 误判、系统残留
  // 脏数据（经典 bug：中国用户启动冷启看到东京）。不合理就继续往下走。
  _log('冷启动位置解析开始');

  // 1. 上次用过的城市
  final cachedCity = await cache.loadLastCity();
  if (cachedCity != null) {
    final lat = (cachedCity['latitude'] as num?)?.toDouble();
    final lon = (cachedCity['longitude'] as num?)?.toDouble();
    if (lat != null && lon != null && plausibleForDeviceTimezone(lat, lon)) {
      _log('命中 [1] 上次城市: ${cachedCity['name']} ($lat, $lon)');
      return TargetLocation(
        name: cachedCity['name'] as String? ?? '当前位置',
        latitude: lat,
        longitude: lon,
      );
    }
    _log('[1] 上次城市存在但坐标不合理，跳过');
  }

  // 2. 24h 内缓存的原始位置
  final cachedPos = await cache.loadPosition();
  if (cachedPos != null && plausibleForDeviceTimezone(cachedPos.latitude, cachedPos.longitude)) {
    _log('命中 [2] 缓存位置 (${cachedPos.latitude}, ${cachedPos.longitude})');
    return TargetLocation(name: '当前位置', latitude: cachedPos.latitude, longitude: cachedPos.longitude);
  }
  if (cachedPos != null) _log('[2] 缓存位置不合理，跳过');

  // 3. 系统 lastKnown
  final last = await locSvc.getLastKnown();
  if (last != null && plausibleForDeviceTimezone(last.latitude, last.longitude)) {
    await cache.savePosition(last.latitude, last.longitude);
    _log('命中 [3] 系统 lastKnown (${last.latitude}, ${last.longitude})');
    return TargetLocation(name: '当前位置', latitude: last.latitude, longitude: last.longitude);
  }
  if (last != null) _log('[3] lastKnown 不合理，跳过');

  // 4. IP 定位 —— 粗略但秒级返回，比等 GPS 强太多
  final ip = await ref.read(ipLocationServiceProvider).locate();
  if (ip != null && plausibleForDeviceTimezone(ip.latitude, ip.longitude)) {
    _log('命中 [4] IP 定位: ${ip.cityName} (${ip.latitude}, ${ip.longitude})');
    return TargetLocation(name: ip.cityName, latitude: ip.latitude, longitude: ip.longitude);
  }
  if (ip != null) _log('[4] IP 定位不合理，跳过');

  // 5. 默认北京
  final fb = _fallbackByTimezone();
  _log('[5] 全部失败，兜底 ${fb.name} (${fb.latitude}, ${fb.longitude})');
  return fb;
}

// release 也要出日志
void _log(String msg) {
  // ignore: avoid_print
  print('[Providers] $msg');
}

// 后台 GPS 精确化：fire-and-forget，成功就更新 targetLocation
// 差距小（< 5km）才触发更新，避免 IP 和 GPS 结果接近时还要重拉一次天气
void _refreshGpsInBackground(Ref ref, {required TargetLocation current}) {
  Future.microtask(() async {
    try {
      final pos = await ref.read(locationServiceProvider).getCurrent();
      // GPS 也能漂：mock location、车里 GPS 欺骗、硬件冷启动期间的脏坐标——
      // 时区对不上就当没拿到
      if (!plausibleForDeviceTimezone(pos.latitude, pos.longitude)) return;

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
      // GPS 坐标跟设备时区对不上就当 GPS 不可信，走兜底链路
      if (!plausibleForDeviceTimezone(fresh.latitude, fresh.longitude)) {
        return _fallbackAfterGpsFail('GPS 坐标异常', locSvc, cache);
      }
      await cache.savePosition(fresh.latitude, fresh.longitude);
      _manual = false; // 手动触发的定位仍算"自动位置"
      state = TargetLocation(name: '当前位置', latitude: fresh.latitude, longitude: fresh.longitude);
      return null;
    } on LocationException catch (e) {
      return _fallbackAfterGpsFail(e.message, locSvc, cache);
    }
  }

  // GPS 失败/异常时的统一兜底：last-known → IP → timezone fallback
  // 每一层都过坐标合理性校验
  Future<String?> _fallbackAfterGpsFail(String reason, LocationService locSvc, CacheService cache) async {
    final last = await locSvc.getLastKnown();
    if (last != null && plausibleForDeviceTimezone(last.latitude, last.longitude)) {
      await cache.savePosition(last.latitude, last.longitude);
      _manual = false;
      state = TargetLocation(name: '当前位置', latitude: last.latitude, longitude: last.longitude);
      return '$reason，已用上次位置';
    }
    final ip = await _ref.read(ipLocationServiceProvider).locate();
    if (ip != null && plausibleForDeviceTimezone(ip.latitude, ip.longitude)) {
      _manual = false;
      state = TargetLocation(name: ip.cityName, latitude: ip.latitude, longitude: ip.longitude);
      return '$reason，已用 IP 定位';
    }
    _manual = false;
    state = _fallbackByTimezone();
    return '$reason，已使用默认城市';
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
