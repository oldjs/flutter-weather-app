import 'package:dio/dio.dart';

// IP 定位结果
class IpLocation {
  final double latitude;
  final double longitude;
  final String cityName;
  final String? countryCode; // 2 字母 ISO 国码，用于和系统时区交叉验证
  const IpLocation({
    required this.latitude,
    required this.longitude,
    required this.cityName,
    required this.countryCode,
  });
}

// IP 地理位置兜底：GPS 挂了就用 IP 估一个位置
// 多提供商接力：有的 API 从数据中心 IP 被封（例如 ipapi.co 对 GitHub Actions）
class IpLocationService {
  final Dio _dio;

  IpLocationService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              headers: {'Accept': 'application/json'},
            ),
          );

  // release 也要出日志
  static void _log(String msg) {
    // ignore: avoid_print
    print('[IpLocationService] $msg');
  }

  // 顺序尝试多个 IP 提供商，每个结果再用系统时区做合理性校验
  // 返回的位置一定是跟设备时区自洽的（能避开 VPN/ISP 跨境路由把中国用户误定位到东京那种坑）
  Future<IpLocation?> locate() async {
    _log('开始 IP 定位');
    final r1 = await _tryIpapiCo();
    if (r1 != null && _matchesDeviceTimezone(r1)) {
      _log('ipapi.co 通过时区校验，使用');
      return r1;
    }
    if (r1 != null) _log('ipapi.co 结果 cc=${r1.countryCode} 与设备时区冲突，丢弃');

    final r2 = await _tryIpwhoIs();
    if (r2 != null && _matchesDeviceTimezone(r2)) {
      _log('ipwho.is 通过时区校验，使用');
      return r2;
    }
    if (r2 != null) _log('ipwho.is 结果 cc=${r2.countryCode} 与设备时区冲突，丢弃');

    _log('IP 定位全部失败/被拒');
    return null;
  }

  // 系统时区 vs IP 国家的一致性检查
  // 典型 bug 场景：用户在中国（设备时区 UTC+8），但 ISP 路由让 IP 看起来像日本 →
  //   ipwho.is 返回东京坐标；没有这个校验的话，用户就会看到"定位到东京"。
  // 只有当国家明显和时区冲突时才拒绝（一小时的边界国家不拒绝，避免过度过滤）
  bool _matchesDeviceTimezone(IpLocation ip) {
    final offset = DateTime.now().timeZoneOffset.inHours;
    final cc = ip.countryCode;
    if (cc == null) return true; // 国家未知就不判断

    // 设备在 UTC+8（中国标准时间），但 IP 却显示是日本/韩国（+9）→ 拒绝
    if (offset == 8 && (cc == 'JP' || cc == 'KR')) return false;
    // 反过来一样：设备在 UTC+9，IP 却是中国 → 拒绝
    if (offset == 9 && cc == 'CN') return false;
    // 设备在 UTC-5（美东）却显示中国日本韩国之类亚洲国家 → 拒绝
    if (offset <= -4 && {'CN', 'JP', 'KR', 'IN', 'RU'}.contains(cc)) return false;
    // 设备在亚洲（+5..+9）却显示美洲/西欧 → 拒绝
    if (offset >= 5 && offset <= 9 && {'US', 'CA', 'GB', 'DE', 'FR', 'BR'}.contains(cc)) return false;

    return true;
  }

  Future<IpLocation?> _tryIpapiCo() async {
    final sw = Stopwatch()..start();
    try {
      final resp = await _dio.get<Map<String, dynamic>>('https://ipapi.co/json/');
      final data = resp.data;
      if (data == null) {
        _log('ipapi.co 空响应 ${sw.elapsedMilliseconds}ms');
        return null;
      }
      if (data['error'] == true) {
        _log('ipapi.co error=${data['reason']} ${sw.elapsedMilliseconds}ms');
        return null;
      }
      final lat = data['latitude'];
      final lon = data['longitude'];
      if (lat is! num || lon is! num) {
        _log('ipapi.co 缺坐标 ${sw.elapsedMilliseconds}ms');
        return null;
      }
      if (lat == 0 && lon == 0) {
        _log('ipapi.co 坐标 (0,0) 丢弃');
        return null;
      }

      final city = (data['city'] as String?)?.trim();
      final region = (data['region'] as String?)?.trim();
      final country = (data['country_name'] as String?)?.trim();
      final cc = (data['country'] as String?)?.trim(); // ipapi.co 的 country 就是 ISO2
      final name = _firstNonEmpty([city, region, country]) ?? '当前位置';
      _log('ipapi.co -> $name cc=$cc ($lat,$lon) ${sw.elapsedMilliseconds}ms');
      return IpLocation(latitude: lat.toDouble(), longitude: lon.toDouble(), cityName: name, countryCode: cc);
    } catch (e) {
      _log('ipapi.co 异常 ${sw.elapsedMilliseconds}ms: $e');
      return null;
    }
  }

  Future<IpLocation?> _tryIpwhoIs() async {
    final sw = Stopwatch()..start();
    try {
      final resp = await _dio.get<Map<String, dynamic>>('https://ipwho.is/');
      final data = resp.data;
      if (data == null) {
        _log('ipwho.is 空响应 ${sw.elapsedMilliseconds}ms');
        return null;
      }
      if (data['success'] == false) {
        _log('ipwho.is success=false msg=${data['message']} ${sw.elapsedMilliseconds}ms');
        return null;
      }
      final lat = data['latitude'];
      final lon = data['longitude'];
      if (lat is! num || lon is! num) {
        _log('ipwho.is 缺坐标 ${sw.elapsedMilliseconds}ms');
        return null;
      }
      if (lat == 0 && lon == 0) {
        _log('ipwho.is 坐标 (0,0) 丢弃');
        return null;
      }

      final city = (data['city'] as String?)?.trim();
      final region = (data['region'] as String?)?.trim();
      final country = (data['country'] as String?)?.trim();
      final cc = (data['country_code'] as String?)?.trim(); // ipwho.is 用 country_code
      final name = _firstNonEmpty([city, region, country]) ?? '当前位置';
      _log('ipwho.is -> $name cc=$cc ($lat,$lon) ${sw.elapsedMilliseconds}ms');
      return IpLocation(latitude: lat.toDouble(), longitude: lon.toDouble(), cityName: name, countryCode: cc);
    } catch (e) {
      _log('ipwho.is 异常 ${sw.elapsedMilliseconds}ms: $e');
      return null;
    }
  }

  String? _firstNonEmpty(List<String?> xs) {
    for (final s in xs) {
      if (s != null && s.isNotEmpty) return s;
    }
    return null;
  }
}
