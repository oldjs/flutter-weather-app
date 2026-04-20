import 'package:dio/dio.dart';
import 'package:lpinyin/lpinyin.dart';

// Open-Meteo 封装，返回原始 JSON map，让 repository 去解析
class WeatherApi {
  final Dio _dio;

  WeatherApi({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              // 20s 给跨国链路（CI runner 到欧洲的 open-meteo）留点余地
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'Accept': 'application/json'},
            ),
          );

  // 拉当前/小时/每日天气一把梭
  Future<Map<String, dynamic>> fetchForecast({required double latitude, required double longitude}) async {
    final resp = await _dio.get(
      'https://api.open-meteo.com/v1/forecast',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'current':
            'temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,'
            'weather_code,wind_speed_10m,wind_direction_10m,surface_pressure,'
            'uv_index,is_day',
        'hourly': 'temperature_2m,precipitation_probability,weather_code,wind_speed_10m',
        'forecast_hours': 48,
        'daily': 'weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_sum',
        'forecast_days': 7,
        'timezone': 'auto',
      },
    );
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> fetchAirQuality({required double latitude, required double longitude}) async {
    try {
      final resp = await _dio.get(
        'https://air-quality-api.open-meteo.com/v1/air-quality',
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          'current': 'pm2_5,pm10,us_aqi',
          'timezone': 'auto',
        },
      );
      return resp.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // 中国省级行政区 → 该省主要城市 (汉字 + 拼音)
  //
  // 踩过的坑：Open-Meteo 的 name 参数只匹配 GeoNames 的 place name，**不匹配 admin1
  // （省份）**。用户搜"山东""河北""广东"这种省名，GeoNames 里只能找到字面叫"山东"
  // 的一堆小村子（辽宁、浙江、江苏都有），而真正的山东省城市一个都搜不到。
  //
  // 解决：这里硬编码 34 个省级行政区 → 主要城市的映射。用户搜省名时，并行把
  // 该省的省会/主要城市一起搜出来，最终让大城市排前面。
  static const Map<String, List<String>> _provinceHubs = {
    // 直辖市 (本身就是 place，hub 列进自己保证"北京市"这种带后缀写法也能走 hub 扩展)
    '北京': ['北京', 'Beijing'],
    '上海': ['上海', 'Shanghai'],
    '天津': ['天津', 'Tianjin'],
    '重庆': ['重庆', 'Chongqing'],
    // 东北三省
    '黑龙江': ['哈尔滨', 'Harbin'],
    '吉林': ['长春', 'Changchun'],
    '辽宁': ['沈阳', 'Shenyang', '大连', 'Dalian'],
    // 华北
    '河北': ['石家庄', 'Shijiazhuang'],
    '山西': ['太原', 'Taiyuan'],
    // 华东
    '山东': ['济南', 'Jinan', '青岛', 'Qingdao'],
    '江苏': ['南京', 'Nanjing', '苏州', 'Suzhou'],
    '浙江': ['杭州', 'Hangzhou'],
    '安徽': ['合肥', 'Hefei'],
    '福建': ['福州', 'Fuzhou', '厦门', 'Xiamen'],
    '江西': ['南昌', 'Nanchang'],
    // 中南
    '河南': ['郑州', 'Zhengzhou'],
    '湖北': ['武汉', 'Wuhan'],
    '湖南': ['长沙', 'Changsha'],
    '广东': ['广州', 'Guangzhou', '深圳', 'Shenzhen'],
    '海南': ['海口', 'Haikou'],
    // 西南
    '四川': ['成都', 'Chengdu'],
    '云南': ['昆明', 'Kunming'],
    '贵州': ['贵阳', 'Guiyang'],
    // 西北
    '陕西': ['西安', "Xi'an", 'Xian'],
    '甘肃': ['兰州', 'Lanzhou'],
    '青海': ['西宁', 'Xining'],
    // 自治区
    '西藏': ['拉萨', 'Lhasa'],
    '新疆': ['乌鲁木齐', 'Urumqi'],
    '宁夏': ['银川', 'Yinchuan'],
    '内蒙古': ['呼和浩特', 'Hohhot'],
    '广西': ['南宁', 'Nanning'],
    // 特别行政区 + 台湾
    '香港': ['香港', 'Hong Kong'],
    '澳门': ['澳门', 'Macau'],
    '台湾': ['台北', 'Taipei', '台中', 'Taichung'],
  };

  // 省份别名：带"省""市""自治区"后缀的写法也映射到主键
  // 例如 "山东省" → "山东"，"内蒙古自治区" → "内蒙古"
  static String? _canonicalProvince(String q) {
    if (_provinceHubs.containsKey(q)) return q;
    for (final suffix in const ['省', '市', '自治区', '特别行政区']) {
      if (q.endsWith(suffix)) {
        final base = q.substring(0, q.length - suffix.length);
        if (_provinceHubs.containsKey(base)) return base;
      }
    }
    return null;
  }

  // 城市搜索
  //
  // 策略：
  //   1) 原汉字 + 整串拼音 两路并行搜（拼音是为了命中 canonical name 是拼音的大城市：
  //      南京/杭州/成都 主名称是 "Nanjing"/"Hangzhou"/"Chengdu"，纯汉字搜不到）
  //   2) 如果输入命中省名，把该省主要城市也一路一路并行搜进来（GeoNames 的 name 参数
  //      不匹配 admin1，不做这一步搜"山东"就只能得到一堆同名小村子）
  //   3) 按 id 去重合并
  //   4) 优先中国结果，都不是中国才退回全部
  //   5) 排序：admin1 命中 query 的加权，再按 (feature_code, population) 排
  //   6) 英文输入全球单次搜索，不变
  Future<List<dynamic>> searchCity(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final hasChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(q);

    if (!hasChinese) {
      // 纯英文/拼音，单次全球搜索
      return _rawSearch(q, language: 'en', count: 10);
    }

    // 中文：汉字 + 拼音 两路并行
    final pinyin = PinyinHelper.getPinyinE(q, defPinyin: '', separator: '').trim();
    final futures = <Future<List<dynamic>>>[
      _rawSearch(q, language: 'zh', count: 20).catchError((_) => <dynamic>[]),
    ];
    // 拼音和原文不一样才打第二路（避免"济南"转出来还是中文时重复请求）
    if (pinyin.isNotEmpty && pinyin != q) {
      futures.add(_rawSearch(pinyin, language: 'zh', count: 20).catchError((_) => <dynamic>[]));
    }

    // 命中省名就把该省主要城市也一起查；跳过和前两路重复的词，少打几次请求
    final province = _canonicalProvince(q);
    if (province != null) {
      final already = <String>{q.toLowerCase(), pinyin.toLowerCase()};
      for (final hub in _provinceHubs[province]!) {
        final key = hub.toLowerCase();
        if (already.contains(key)) continue;
        futures.add(_rawSearch(hub, language: 'zh', count: 10).catchError((_) => <dynamic>[]));
        already.add(key);
      }
    }

    final responses = await Future.wait(futures);

    // 按 id 去重合并
    final byId = <Object, Map<String, dynamic>>{};
    for (final list in responses) {
      for (final raw in list) {
        final m = raw as Map<String, dynamic>;
        final id = m['id'] as Object?;
        if (id == null) continue;
        byId.putIfAbsent(id, () => m);
      }
    }
    final merged = byId.values.toList();

    // 中国优先，没有中国结果才退回全部
    final cn = merged.where((m) => m['country_code'] == 'CN').toList();
    final pool = cn.isNotEmpty ? cn : merged;

    // 排序：
    //   1) admin1 包含原 query（主要是省名场景）→ 加权在前
    //   2) 行政级别（PPLC > PPLA > PPLA2 ...）
    //   3) 人口降序
    pool.sort((a, b) {
      final ma = _adminMatchScore(a, q, province);
      final mb = _adminMatchScore(b, q, province);
      if (ma != mb) return mb.compareTo(ma); // 分高的在前
      final ra = _featureRank(a['feature_code'] as String?);
      final rb = _featureRank(b['feature_code'] as String?);
      if (ra != rb) return ra.compareTo(rb);
      final pa = (a['population'] as num?)?.toInt() ?? 0;
      final pb = (b['population'] as num?)?.toInt() ?? 0;
      return pb.compareTo(pa);
    });

    // 最多返回 15 条，足够选了
    return pool.take(15).toList();
  }

  // admin1 匹配得分：用户搜"山东"时，admin1="山东"的结果应该强力上浮
  // 返回 0/1/2，越高越匹配
  int _adminMatchScore(Map<String, dynamic> m, String query, String? province) {
    final admin1 = (m['admin1'] as String?) ?? '';
    if (admin1.isEmpty) return 0;
    // 命中 canonical province：搜"山东省" canonicalize 成"山东"，admin1 也叫"山东"
    if (province != null && admin1.contains(province)) return 2;
    // 直接包含原 query（用户搜具体城市时 admin1 不会命中，这里主要兜底）
    if (admin1.contains(query)) return 1;
    return 0;
  }

  // 行政级别排名（越小越优先）
  // GeoNames feature_code: PPLC=首都, PPLA=省会, PPLA2=地级市驻地, PPLA3=县级市驻地, PPLA4=乡镇驻地, PPL=一般聚居地
  int _featureRank(String? fc) {
    switch (fc) {
      case 'PPLC':
        return 0;
      case 'PPLA':
        return 1;
      case 'PPLA2':
        return 2;
      case 'PPLA3':
        return 3;
      case 'PPLA4':
        return 4;
      case 'PPL':
        return 5;
      default:
        return 6;
    }
  }

  // 原始搜索，不做任何处理
  Future<List<dynamic>> _rawSearch(String name, {required String language, required int count}) async {
    if (name.isEmpty) return [];
    final resp = await _dio.get(
      'https://geocoding-api.open-meteo.com/v1/search',
      queryParameters: {'name': name, 'count': count, 'language': language, 'format': 'json'},
    );
    final data = resp.data as Map<String, dynamic>;
    return (data['results'] as List?) ?? [];
  }
}
