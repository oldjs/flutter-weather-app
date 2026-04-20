import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'presentation/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 中文星期名称初始化
  await initializeDateFormatting('zh_CN');

  // 沉浸式：让渐变背景一直延伸到状态栏和导航栏
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  runApp(const ProviderScope(child: WeatherApp()));
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 用 MaterialApp 只是为了拿 Navigator/Localizations，
    // 但把所有 MD 视觉默认值全部归零，避免任何 Material 味儿泄漏出来
    return MaterialApp(
      title: 'Weather',
      debugShowCheckedModeBanner: false,
      theme: _buildBareTheme(),
      // 全局兜底：所有 Text 默认无装饰，避免某些输入法/系统字体在父层漏下的黄色波浪线
      builder: (context, child) {
        return DefaultTextStyle.merge(
          style: const TextStyle(
            decoration: TextDecoration.none,
            decorationColor: Colors.transparent,
            decorationThickness: 0,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const HomeScreen(),
    );
  }
}

// 去 Material 风格的空主题：
// 无水波纹、无高亮色、无分隔线、无 AppBar 色、无 Scaffold 色
ThemeData _buildBareTheme() {
  const bg = Colors.black;
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: bg,
    canvasColor: bg,
    // 关键：消灭 InkWell / InkResponse 的水波纹
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    focusColor: Colors.transparent,
    dividerColor: Colors.transparent,
    // 字体：系统默认（避免 Roboto 的 MD 感）
    fontFamily: null,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        // 用 Cupertino 风格的页面过渡，不要 MD 的上滑
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
  return base.copyWith(
    textSelectionTheme: const TextSelectionThemeData(cursorColor: Colors.white, selectionColor: Color(0x44FFFFFF)),
  );
}
