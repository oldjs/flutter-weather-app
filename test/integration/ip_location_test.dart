import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/data/datasources/ip_location_service.dart';

// 真实 ipapi.co 接口测试，需要网络
void main() {
  test('IP 定位能返回合法的经纬度和城市名', () async {
    final svc = IpLocationService();
    final loc = await svc.locate();

    expect(loc, isNotNull, reason: 'ipapi.co 正常情况下必须返回定位结果');
    expect(loc!.latitude, inInclusiveRange(-90, 90), reason: '纬度必须在 -90..90');
    expect(loc.longitude, inInclusiveRange(-180, 180), reason: '经度必须在 -180..180');
    // 0,0 是"无效位置"在大洋中心，通常是 API 错误
    expect(loc.latitude == 0 && loc.longitude == 0, isFalse, reason: '不能返回 0,0 这种无效坐标');
    expect(loc.cityName, isNotEmpty, reason: '城市名不能为空');
  }, timeout: const Timeout(Duration(seconds: 20)));
}
