import 'package:equatable/equatable.dart';

// 搜索结果里的城市
class City extends Equatable {
  final String name; // 城市名
  final String? admin1; // 省/州
  final String? country; // 国家
  final double latitude;
  final double longitude;

  const City({
    required this.name,
    required this.admin1,
    required this.country,
    required this.latitude,
    required this.longitude,
  });

  // 用于列表展示的完整名称
  String get fullName {
    final parts = [name, if (admin1 != null && admin1!.isNotEmpty) admin1, if (country != null) country];
    return parts.join(', ');
  }

  @override
  List<Object?> get props => [name, admin1, country, latitude, longitude];
}
