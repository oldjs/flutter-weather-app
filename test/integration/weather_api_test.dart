import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/data/datasources/weather_api.dart';

// 真实接口集成测试：直接打 Open-Meteo 的线上接口
// 不是 mock，跑的时候需要网络
void main() {
  final api = WeatherApi();

  group('Open-Meteo forecast', () {
    test('北京坐标能返回可解析的完整天气数据', () async {
      // 北京天安门附近
      final json = await api.fetchForecast(latitude: 39.9042, longitude: 116.4074);

      // 顶层结构
      expect(json, isA<Map<String, dynamic>>());
      expect(json['latitude'], isA<num>());
      expect(json['longitude'], isA<num>());

      // 当前观测
      final current = json['current'] as Map<String, dynamic>;
      expect(current['temperature_2m'], isA<num>(), reason: '必须有当前气温');
      expect(current['relative_humidity_2m'], isA<num>(), reason: '必须有湿度');
      expect(current['weather_code'], isA<num>(), reason: '必须有天气代码');
      expect(current['wind_speed_10m'], isA<num>(), reason: '必须有风速');
      expect(current['is_day'], isA<num>(), reason: '必须有日夜标志');
      expect(current['time'], isA<String>());
      // 时间格式能解析
      expect(() => DateTime.parse(current['time'] as String), returnsNormally);

      // 小时预报：至少 24 小时
      final hourly = json['hourly'] as Map<String, dynamic>;
      final hourlyTimes = hourly['time'] as List;
      expect(hourlyTimes.length, greaterThanOrEqualTo(24), reason: '至少返回 24 小时');
      expect(hourly['temperature_2m'], isA<List>());
      expect(hourly['weather_code'], isA<List>());

      // 每日预报：至少 7 天
      final daily = json['daily'] as Map<String, dynamic>;
      final dailyTimes = daily['time'] as List;
      expect(dailyTimes.length, greaterThanOrEqualTo(7), reason: '至少返回 7 天');
      expect(daily['temperature_2m_max'], isA<List>());
      expect(daily['temperature_2m_min'], isA<List>());
      expect(daily['sunrise'], isA<List>());
      expect(daily['sunset'], isA<List>());

      // 温度要合理（北京极端范围约 -30..45）
      final t = (current['temperature_2m'] as num).toDouble();
      expect(t, inInclusiveRange(-40, 50), reason: '气温得落在物理合理范围');
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('Open-Meteo air quality', () {
    test('北京坐标能返回 AQI + PM2.5', () async {
      final json = await api.fetchAirQuality(latitude: 39.9042, longitude: 116.4074);
      expect(json, isNotNull, reason: '空气质量接口必须返回数据');

      final current = json!['current'] as Map<String, dynamic>;
      expect(current['us_aqi'], isA<num>(), reason: '必须有 US AQI');
      expect(current['pm2_5'], isA<num>(), reason: '必须有 PM2.5');
      expect(current['pm10'], isA<num>(), reason: '必须有 PM10');

      // AQI 合理范围
      final aqi = (current['us_aqi'] as num).toInt();
      expect(aqi, inInclusiveRange(0, 500), reason: 'AQI 得在 0..500');
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('Open-Meteo geocoding', () {
    test('搜"济南"：首条结果必须在山东，不能是辽宁', () async {
      final results = await api.searchCity('济南');
      expect(results, isNotEmpty, reason: '济南必须能搜到结果');

      final first = results.first as Map<String, dynamic>;
      // 必须是中国
      expect(first['country_code'], equals('CN'), reason: '首条结果必须在中国');
      // 省份必须是山东（Open-Meteo 中文可能返回 "山东" 或 "山东省"）
      final admin1 = first['admin1'] as String?;
      expect(
        admin1,
        anyOf(contains('山东'), equalsIgnoringCase('Shandong')),
        reason: '首条济南必须在山东，不能是辽宁或别的省',
      );
      // 明确否定：不能是辽宁
      expect(admin1?.contains('辽宁'), isNot(isTrue), reason: '济南首条绝不能出辽宁');

      // 经纬度应该在济南周围（济南约 36.67°N, 117.00°E）
      final lat = (first['latitude'] as num).toDouble();
      final lon = (first['longitude'] as num).toDouble();
      expect(lat, closeTo(36.67, 0.5), reason: '纬度应在济南附近');
      expect(lon, closeTo(117.00, 0.5), reason: '经度应在济南附近');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('搜"上海"：首条必须是中国上海', () async {
      final results = await api.searchCity('上海');
      expect(results, isNotEmpty);
      final first = results.first as Map<String, dynamic>;
      expect(first['country_code'], equals('CN'));
      final lat = (first['latitude'] as num).toDouble();
      expect(lat, closeTo(31.23, 1.0), reason: '上海纬度约 31.23');
    }, timeout: const Timeout(Duration(seconds: 30)));

    // 这三个是用户反馈里直接炸裂的 case：Open-Meteo 的 name 参数只匹配主名称，
    // 而南京/杭州/成都主名称是拼音，纯汉字搜会返回一堆同名小村子
    // 靠 searchCity 内部并行走拼音兜底才能拿到真正的大城市
    test('搜"南京"：首条必须是江苏南京（pop>1M，不能是云南的南京村）', () async {
      final results = await api.searchCity('南京');
      expect(results, isNotEmpty, reason: '南京必须能搜到结果');
      final first = results.first as Map<String, dynamic>;
      expect(first['country_code'], equals('CN'));
      final admin1 = first['admin1'] as String?;
      expect(admin1, anyOf(contains('江苏'), equalsIgnoringCase('Jiangsu')), reason: '南京首条必须在江苏，不是云南');
      final pop = (first['population'] as num?)?.toInt() ?? 0;
      expect(pop, greaterThan(1000000), reason: '首条必须是大城市级别（pop>1M），不能是小村子');
      final lat = (first['latitude'] as num).toDouble();
      expect(lat, closeTo(32.06, 0.5), reason: '南京纬度约 32.06');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('搜"杭州"：首条必须是浙江杭州（pop>1M，不能是四川的杭州村）', () async {
      final results = await api.searchCity('杭州');
      expect(results, isNotEmpty);
      final first = results.first as Map<String, dynamic>;
      expect(first['country_code'], equals('CN'));
      final admin1 = first['admin1'] as String?;
      expect(admin1, anyOf(contains('浙江'), equalsIgnoringCase('Zhejiang')), reason: '杭州首条必须在浙江，不是四川');
      final pop = (first['population'] as num?)?.toInt() ?? 0;
      expect(pop, greaterThan(1000000));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('搜"成都"：首条必须是四川成都（pop>1M）', () async {
      final results = await api.searchCity('成都');
      expect(results, isNotEmpty);
      final first = results.first as Map<String, dynamic>;
      expect(first['country_code'], equals('CN'));
      final admin1 = first['admin1'] as String?;
      expect(admin1, anyOf(contains('四川'), equalsIgnoringCase('Sichuan')), reason: '成都首条必须在四川');
      final pop = (first['population'] as num?)?.toInt() ?? 0;
      expect(pop, greaterThan(1000000));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('搜"北京"：首条必须是首都级别', () async {
      final results = await api.searchCity('北京');
      expect(results, isNotEmpty);
      final first = results.first as Map<String, dynamic>;
      expect(first['country_code'], equals('CN'));
      expect(first['feature_code'], equals('PPLC'), reason: '北京必须是 PPLC（首都）');
      final lat = (first['latitude'] as num).toDouble();
      expect(lat, closeTo(39.90, 0.5));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('搜英文"London"：走全球搜索，能命中伦敦', () async {
      final results = await api.searchCity('London');
      expect(results, isNotEmpty);
      final hasLondonUK = results.any((e) {
        final m = e as Map<String, dynamic>;
        return m['country_code'] == 'GB';
      });
      expect(hasLondonUK, isTrue, reason: '英文搜 London 应能返回英国伦敦');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('空字符串直接返回空列表，不报错', () async {
      final results = await api.searchCity('');
      expect(results, isEmpty);
    });
  });
}
