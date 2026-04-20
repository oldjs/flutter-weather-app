import 'package:equatable/equatable.dart';

// 当前天气
class CurrentWeather extends Equatable {
  final double temperature; // 实际气温 °C
  final double apparentTemperature; // 体感温度 °C
  final double humidity; // 相对湿度 %
  final double precipitation; // 降水量 mm
  final int weatherCode; // WMO 天气代码
  final double windSpeed; // 风速 km/h
  final double windDirection; // 风向 0-360°
  final double surfacePressure; // 气压 hPa
  final double uvIndex; // 紫外线
  final DateTime time; // 观测时间
  final bool isDay; // 白天还是夜晚

  const CurrentWeather({
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.precipitation,
    required this.weatherCode,
    required this.windSpeed,
    required this.windDirection,
    required this.surfacePressure,
    required this.uvIndex,
    required this.time,
    required this.isDay,
  });

  @override
  List<Object?> get props => [
    temperature,
    apparentTemperature,
    humidity,
    precipitation,
    weatherCode,
    windSpeed,
    windDirection,
    surfacePressure,
    uvIndex,
    time,
    isDay,
  ];
}

// 小时预报点
class HourlyWeather extends Equatable {
  final DateTime time;
  final double temperature;
  final int weatherCode;
  final double precipitationProbability; // 降水概率 %
  final double windSpeed;

  const HourlyWeather({
    required this.time,
    required this.temperature,
    required this.weatherCode,
    required this.precipitationProbability,
    required this.windSpeed,
  });

  @override
  List<Object?> get props => [time, temperature, weatherCode, precipitationProbability, windSpeed];
}

// 每日预报
class DailyWeather extends Equatable {
  final DateTime date;
  final int weatherCode;
  final double tempMax;
  final double tempMin;
  final DateTime sunrise;
  final DateTime sunset;
  final double uvIndexMax;
  final double precipitationSum;

  const DailyWeather({
    required this.date,
    required this.weatherCode,
    required this.tempMax,
    required this.tempMin,
    required this.sunrise,
    required this.sunset,
    required this.uvIndexMax,
    required this.precipitationSum,
  });

  @override
  List<Object?> get props => [date, weatherCode, tempMax, tempMin, sunrise, sunset, uvIndexMax, precipitationSum];
}

// 空气质量
class AirQuality extends Equatable {
  final double pm25;
  final double pm10;
  final int usAqi;

  const AirQuality({required this.pm25, required this.pm10, required this.usAqi});

  @override
  List<Object?> get props => [pm25, pm10, usAqi];
}

// 整合后的天气数据包
class WeatherBundle extends Equatable {
  final String cityName; // 城市显示名
  final double latitude;
  final double longitude;
  final CurrentWeather current;
  final List<HourlyWeather> hourly;
  final List<DailyWeather> daily;
  final AirQuality? airQuality; // 空气质量可能拉不到
  final DateTime fetchedAt; // 数据拉取时间
  final bool isStale; // 是否是降级用的缓存数据（网络挂时从本地读出的）

  const WeatherBundle({
    required this.cityName,
    required this.latitude,
    required this.longitude,
    required this.current,
    required this.hourly,
    required this.daily,
    required this.airQuality,
    required this.fetchedAt,
    this.isStale = false,
  });

  // 打上陈旧标记，让 UI 可以显示"缓存数据"提示
  WeatherBundle markStale() => WeatherBundle(
    cityName: cityName,
    latitude: latitude,
    longitude: longitude,
    current: current,
    hourly: hourly,
    daily: daily,
    airQuality: airQuality,
    fetchedAt: fetchedAt,
    isStale: true,
  );

  @override
  List<Object?> get props => [cityName, latitude, longitude, current, hourly, daily, airQuality, fetchedAt, isStale];
}
