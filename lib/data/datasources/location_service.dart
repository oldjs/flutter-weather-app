import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';

// 定位失败原因
enum LocationFailure { serviceDisabled, permissionDenied, permissionDeniedForever, timeout, unknown }

class LocationException implements Exception {
  final LocationFailure failure;
  final String message;
  LocationException(this.failure, this.message);
  @override
  String toString() => message;
}

// 定位封装：Android 三段式降级，非 Android 两段式
//
// 为什么 Android 要三段式：
//   geolocator 默认走 FusedLocationProviderClient (GMS)。国产机 vivo/oppo/小米
//   常见无 GMS 或 GMS 不完整，Fused 调用会永久挂起/异常，导致"定位按钮点了没反应"。
//   官方 AndroidSettings.forceLocationManager=true 就是给这种机型的逃生通道：
//   绕开 Fused，直接走原生 android.location.LocationManager。
//
// 三段式：
//   1. Fused + 高精度 (20s)
//        有 GMS 的主流 Android 最快最准
//   2. LocationManager GPS_PROVIDER + 高精度 (15s)   ← 无 GMS 救命
//        强制原生路径，只用 GPS 芯片
//   3. LocationManager NETWORK_PROVIDER + 低精度 (10s)
//        基站 + WiFi 粗定位，无 GPS 信号也能拿到；同样不依赖 GMS
//
// 非 Android (iOS/Desktop/Web) 保留两段：高精度 → 低精度
//
// 日志用 print（release 也要能 logcat 看到），不用 debugPrint
class LocationService {
  // Fused 超时：vivo 这类可能直接挂起，别等太久
  static const _fusedTimeout = Duration(seconds: 20);
  // LocationManager GPS 超时
  static const _gpsTimeout = Duration(seconds: 15);
  // NETWORK_PROVIDER 超时（基站+WiFi 有网就快）
  static const _networkTimeout = Duration(seconds: 10);

  // release 也要出日志，用 print
  static void _log(String msg) {
    // ignore: avoid_print
    print('[LocationService] $msg');
  }

  // 是否在 Android 平台（web 上 Platform 不能用，要先挡 kIsWeb）
  bool get _isAndroid {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  // 系统缓存的上次已知位置，毫秒级返回；可能为 null
  Future<Position?> getLastKnown() async {
    final sw = Stopwatch()..start();
    try {
      final pos = await Geolocator.getLastKnownPosition();
      _log(
        'getLastKnown -> ${pos == null ? "null" : "(${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})"} '
        '${sw.elapsedMilliseconds}ms',
      );
      return pos;
    } catch (e) {
      _log('getLastKnown 异常 ${sw.elapsedMilliseconds}ms: $e');
      return null;
    }
  }

  // 实时定位：Android 三段，其它两段
  Future<Position> getCurrent() async {
    // 前置：服务开关 + 权限。失败直接抛，不走降级
    await _ensureServiceAndPermission();

    if (_isAndroid) {
      // 第一段：Fused（GMS）
      try {
        return await _tryOnce(
          label: 'Fused',
          settings: AndroidSettings(
            accuracy: LocationAccuracy.high,
            forceLocationManager: false,
            timeLimit: _fusedTimeout,
          ),
        );
      } on TimeoutException {
        _log('Fused 超时 → 降级 LocationManager GPS');
      } on _TransientLocationError catch (e) {
        _log('Fused 瞬时失败 ($e) → 降级 LocationManager GPS');
      }

      // 第二段：LocationManager + 高精度 GPS_PROVIDER（无 GMS 救命）
      try {
        return await _tryOnce(
          label: 'LocationManager.GPS',
          settings: AndroidSettings(
            accuracy: LocationAccuracy.high,
            forceLocationManager: true,
            timeLimit: _gpsTimeout,
          ),
        );
      } on TimeoutException {
        _log('LocationManager GPS 超时 → 降级 NETWORK_PROVIDER');
      } on _TransientLocationError catch (e) {
        _log('LocationManager GPS 瞬时失败 ($e) → 降级 NETWORK_PROVIDER');
      }

      // 第三段：LocationManager + 低精度 NETWORK_PROVIDER（基站+WiFi）
      try {
        return await _tryOnce(
          label: 'LocationManager.Network',
          settings: AndroidSettings(
            accuracy: LocationAccuracy.low,
            forceLocationManager: true,
            timeLimit: _networkTimeout,
          ),
        );
      } on TimeoutException {
        _log('NETWORK_PROVIDER 也超时，彻底失败');
        throw LocationException(LocationFailure.timeout, '定位超时，请检查 GPS 信号或网络');
      } on _TransientLocationError catch (e) {
        _log('NETWORK_PROVIDER 瞬时失败 ($e)，彻底失败');
        throw LocationException(LocationFailure.unknown, '定位失败：${e.cause}');
      }
    }

    // iOS / Desktop / Web：保留两段
    try {
      return await _tryOnce(
        label: 'Generic.High',
        settings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: _fusedTimeout),
      );
    } on TimeoutException {
      _log('Generic 高精度超时 → 降级低精度');
    } on _TransientLocationError catch (e) {
      _log('Generic 高精度瞬时失败 ($e) → 降级低精度');
    }

    try {
      return await _tryOnce(
        label: 'Generic.Low',
        settings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: _networkTimeout),
      );
    } on TimeoutException {
      throw LocationException(LocationFailure.timeout, '定位超时，请检查 GPS 信号或网络');
    } on _TransientLocationError catch (e) {
      throw LocationException(LocationFailure.unknown, '定位失败：${e.cause}');
    }
  }

  // 单次尝试：打日志、区分异常类型
  // - TimeoutException / _TransientLocationError：瞬时错误，让上层降级
  // - LocationException (service/permission)：直接抛，不降级
  Future<Position> _tryOnce({
    required String label,
    required LocationSettings settings,
  }) async {
    final force = settings is AndroidSettings ? settings.forceLocationManager : false;
    final timeout = settings.timeLimit?.inSeconds ?? 0;
    _log('尝试 $label acc=${settings.accuracy.name} force=$force timeout=${timeout}s');

    final sw = Stopwatch()..start();
    try {
      final pos = await Geolocator.getCurrentPosition(locationSettings: settings);
      _log(
        '$label 成功 (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}) '
        'acc=${pos.accuracy.toStringAsFixed(0)}m ${sw.elapsedMilliseconds}ms',
      );
      return pos;
    } on TimeoutException {
      _log('$label 超时 ${sw.elapsedMilliseconds}ms');
      rethrow;
    } on LocationServiceDisabledException {
      _log('$label 服务未开 ${sw.elapsedMilliseconds}ms');
      throw LocationException(LocationFailure.serviceDisabled, '定位服务未开启');
    } on PermissionDeniedException {
      _log('$label 权限被拒 ${sw.elapsedMilliseconds}ms');
      throw LocationException(LocationFailure.permissionDenied, '未授予定位权限');
    } catch (e) {
      // PlatformException / Fused 初始化失败 / 国产 ROM 魔改异常，都归为瞬时错误
      // 让上层降级到下一段，不把一切都当超时
      _log('$label 异常 ${sw.elapsedMilliseconds}ms: $e');
      throw _TransientLocationError(e.toString());
    }
  }

  // 前置条件：定位服务开 + 权限授予
  Future<void> _ensureServiceAndPermission() async {
    _log('检查定位服务 & 权限');
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    _log('  服务开关 = $serviceOn');
    if (!serviceOn) {
      throw LocationException(LocationFailure.serviceDisabled, '定位服务未开启，请在系统设置中打开');
    }

    var perm = await Geolocator.checkPermission();
    _log('  当前权限 = $perm');
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      _log('  请求后权限 = $perm');
    }
    if (perm == LocationPermission.deniedForever) {
      throw LocationException(LocationFailure.permissionDeniedForever, '定位权限被永久拒绝，请到系统设置中开启');
    }
    if (perm == LocationPermission.denied) {
      throw LocationException(LocationFailure.permissionDenied, '未授予定位权限');
    }
    _log('权限检查通过');
  }
}

// 内部标记：一次尝试失败但应该降级到下一段
// 用独立类型而不是复用 Exception，避免上层把它和权限/服务问题混起来
class _TransientLocationError implements Exception {
  final String cause;
  _TransientLocationError(this.cause);
  @override
  String toString() => cause;
}
