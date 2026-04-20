import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:weather_app/main.dart';

void main() {
  testWidgets('App boots without throwing', (tester) async {
    // 基本起飞测试：应用能构建出 MaterialApp
    await tester.pumpWidget(const ProviderScope(child: WeatherApp()));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
