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

// 定位封装，返回经纬度或抛 LocationException
class LocationService {
  Future<Position> getCurrent() async {
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

    // 拿一次位置，10 秒超时
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 10)),
      );
      return pos;
    } on Exception catch (e) {
      throw LocationException(LocationFailure.timeout, '定位超时：$e');
    }
  }
}
