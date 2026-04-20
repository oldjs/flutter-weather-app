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

// 定位封装，支持 30s 超时和上次已知位置快速返回
class LocationService {
  // 系统缓存的上次已知位置，秒级返回；可能为 null 或稍陈
  Future<Position?> getLastKnown() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      // 测试环境/平台不支持就算了
      return null;
    }
  }

  // 实时 GPS 定位，默认 30 秒超时（首次冷启动 GPS 锁定要久）
  Future<Position> getCurrent({Duration timeout = const Duration(seconds: 30)}) async {
    // 先看系统定位服务是不是开着
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      throw LocationException(LocationFailure.serviceDisabled, '定位服务未开启，请在系统设置中打开');
    }

    // 检查/申请权限
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

    try {
      // medium 精度走网络+GPS 混合定位，比 high 快得多
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: timeout),
      );
    } on TimeoutException {
      throw LocationException(LocationFailure.timeout, '定位超时，可能是 GPS 信号弱或室内环境');
    } on Exception catch (e) {
      throw LocationException(LocationFailure.unknown, '定位失败：$e');
    }
  }
}
