import 'dart:async';

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

// 定位封装：两段式重试
// - 第一次：高精度 GPS，30s 超时
// - 第一次超时再降级到低精度（网络定位 Cell+WiFi），15s 超时
// - 区分 TimeoutException 和其它异常，不把一切都当超时
class LocationService {
  // 首次/高精度超时
  static const _firstTimeout = Duration(seconds: 30);
  // 降级重试超时
  static const _retryTimeout = Duration(seconds: 15);

  // 系统缓存的上次已知位置，毫秒级返回；可能为 null
  Future<Position?> getLastKnown() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      // 测试环境/平台不支持就算了
      return null;
    }
  }

  // 实时 GPS 定位，高→低两段重试
  Future<Position> getCurrent() async {
    // 先检查前置条件，这些失败不是"超时"要如实报
    await _ensureServiceAndPermission();

    // 第一段：高精度 30s
    // LocationAccuracy.high 让系统优先走 GPS + Fused Provider，精度更可靠
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: _firstTimeout),
      );
    } on TimeoutException {
      // 高精度拿不到就走降级，不抛
    } on LocationServiceDisabledException {
      throw LocationException(LocationFailure.serviceDisabled, '定位服务未开启');
    } on PermissionDeniedException {
      throw LocationException(LocationFailure.permissionDenied, '未授予定位权限');
    } on Exception catch (e) {
      // 其他错误：硬件故障、平台异常等，按原样抛出，别伪装成超时
      throw LocationException(LocationFailure.unknown, '定位失败：$e');
    }

    // 第二段：低精度 15s
    // LocationAccuracy.low 会优先走网络定位（基站+Wi-Fi），室内/没 GPS 信号也能拿到粗略位置
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: _retryTimeout),
      );
    } on TimeoutException {
      throw LocationException(LocationFailure.timeout, '定位超时，请检查 GPS 信号或网络');
    } on LocationServiceDisabledException {
      throw LocationException(LocationFailure.serviceDisabled, '定位服务未开启');
    } on PermissionDeniedException {
      throw LocationException(LocationFailure.permissionDenied, '未授予定位权限');
    } on Exception catch (e) {
      throw LocationException(LocationFailure.unknown, '定位失败：$e');
    }
  }

  // 前置条件：定位服务开 + 权限授予
  Future<void> _ensureServiceAndPermission() async {
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      throw LocationException(LocationFailure.serviceDisabled, '定位服务未开启，请在系统设置中打开');
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      throw LocationException(LocationFailure.permissionDeniedForever, '定位权限被永久拒绝，请到系统设置中开启');
    }
    if (perm == LocationPermission.denied) {
      throw LocationException(LocationFailure.permissionDenied, '未授予定位权限');
    }
  }
}
