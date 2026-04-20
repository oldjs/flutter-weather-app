import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/weather_codes.dart';
import '../../core/theme/weather_theme.dart';
import '../../domain/entities/weather.dart';
import '../providers/providers.dart';
import '../widgets/animated_background.dart';
import '../widgets/aqi_card.dart';
import '../widgets/common/pill_button.dart';
import '../widgets/common/pull_refresh.dart';
import '../widgets/common/spinner.dart';
import '../widgets/common/toast.dart';
import '../widgets/current_weather_card.dart';
import '../widgets/daily_forecast.dart';
import '../widgets/detail_grid.dart';
import '../widgets/hourly_forecast.dart';
import '../widgets/life_index.dart';
import '../widgets/sun_arc.dart';
import 'search_screen.dart';

// 主页：无 Scaffold、无 AppBar，整屏自绘
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(weatherProvider);
    // 整个页面用 ColoredBox + Stack 承载，不用 Scaffold
    return ColoredBox(
      color: Colors.black,
      child: weatherAsync.when(
        data: (w) => _Loaded(bundle: w),
        loading: () => const _Loading(),
        error: (e, _) => _ErrorView(
          error: e,
          onRetry: () {
            // 重试要把定位和天气都重新跑一遍，否则还是停在旧错误上
            ref.invalidate(initialLocationProvider);
            ref.invalidate(weatherProvider);
          },
          onSearch: () => Navigator.of(context).push(
            PageRouteBuilder(
              opaque: true,
              transitionDuration: const Duration(milliseconds: 240),
              pageBuilder: (_, a, __) => FadeTransition(opacity: a, child: const SearchScreen()),
            ),
          ),
        ),
      ),
    );
  }
}

// 加载中：渐变底 + 自定义 Spinner
class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1F2B44), Color(0xFF5A6F95)],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Spinner(size: 32, strokeWidth: 2.5, color: Colors.white),
            SizedBox(height: 16),
            Text(
              '正在获取天气…',
              style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

// 错误提示：无 Scaffold，居中图标+文字+自定义按钮
// 提供"重试"和"搜索城市"两个出口，不让用户卡死
class _ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onSearch;
  const _ErrorView({required this.error, required this.onRetry, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2B2B3A), Color(0xFF4A4A6A)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off, color: Colors.white.withValues(alpha: 0.7), size: 56),
                const SizedBox(height: 20),
                const Text(
                  '获取天气失败',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 28),
                // 两个按钮并排：主操作重试，次操作手动搜城市
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FlatPillButton(label: '重试', onTap: onRetry),
                    const SizedBox(width: 12),
                    FlatPillButton(
                      label: '搜索城市',
                      onTap: onSearch,
                      background: const Color(0x1AFFFFFF),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 数据加载完成：全屏沉浸 + 毛玻璃卡片滚动
class _Loaded extends ConsumerWidget {
  final WeatherBundle bundle;
  const _Loaded({required this.bundle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = WeatherCodes.kindOf(bundle.current.weatherCode);
    final theme = WeatherTheme.of(kind, isDay: bundle.current.isDay);

    // 沉浸式系统栏：状态栏透明 + 图标配色跟随背景亮暗
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: theme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: theme.brightness,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: theme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 底层：渐变 + 天气动效
          AnimatedBackground(kind: kind, isDay: bundle.current.isDay),
          // 顶部再压一层轻度遮罩，让上半屏文字更易读
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [Color(0x40000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
          // 上层：可滚动内容
          SafeArea(
            child: CustomScrollView(
              // iOS 风格的回弹滚动
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                // 自定义下拉刷新
                PullRefresh(onRefresh: () async => ref.invalidate(weatherProvider)),
                // 缓存数据提示条，只在降级时显示
                if (bundle.isStale)
                  SliverToBoxAdapter(
                    child: _StaleBanner(
                      theme: theme,
                      onSearch: () => Navigator.of(context).push(
                        PageRouteBuilder(
                          opaque: true,
                          transitionDuration: const Duration(milliseconds: 240),
                          pageBuilder: (_, a, __) => FadeTransition(opacity: a, child: const SearchScreen()),
                        ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: _TopBar(
                    theme: theme,
                    onSearch: () => Navigator.of(context).push(
                      PageRouteBuilder(
                        opaque: true,
                        transitionDuration: const Duration(milliseconds: 240),
                        pageBuilder: (_, a, __) => FadeTransition(opacity: a, child: const SearchScreen()),
                      ),
                    ),
                    onGps: () async {
                      // 新 useGps 不抛异常，返回 null 表示成功，否则就是降级说明
                      final msg = await ref.read(targetLocationProvider.notifier).useGps();
                      if (msg != null && context.mounted) {
                        Toast.show(context, msg);
                      }
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 28, bottom: 28),
                    child: CurrentWeatherCard(cityName: bundle.cityName, current: bundle.current, theme: theme),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 40),
                  sliver: SliverList.list(
                    children: [
                      HourlyForecast(hourly: bundle.hourly, theme: theme),
                      const SizedBox(height: 14),
                      DailyForecast(daily: bundle.daily, theme: theme),
                      if (bundle.airQuality != null) ...[
                        const SizedBox(height: 14),
                        AqiCard(air: bundle.airQuality!, theme: theme),
                      ],
                      const SizedBox(height: 14),
                      DetailGrid(current: bundle.current, theme: theme),
                      const SizedBox(height: 14),
                      if (bundle.daily.isNotEmpty) SunArc(today: bundle.daily.first, theme: theme),
                      const SizedBox(height: 14),
                      LifeIndex(current: bundle.current, theme: theme),
                      const SizedBox(height: 20),
                      _Footer(theme: theme, fetchedAt: bundle.fetchedAt),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 顶栏：两个毛玻璃圆按钮 + 中间小品牌点（装饰）
class _TopBar extends StatelessWidget {
  final WeatherTheme theme;
  final VoidCallback onSearch;
  final VoidCallback onGps;
  const _TopBar({required this.theme, required this.onSearch, required this.onGps});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Row(
        children: [
          PillButton(
            onTap: onGps,
            child: Icon(Icons.my_location_rounded, color: theme.foreground, size: 20),
          ),
          const Spacer(),
          // 中间三个小圆点，纯装饰，看着像小米顶栏那种层级感
          _PageIndicator(theme: theme),
          const Spacer(),
          PillButton(
            onTap: onSearch,
            child: Icon(Icons.search_rounded, color: theme.foreground, size: 20),
          ),
        ],
      ),
    );
  }
}

// 顶部装饰：三个小圆点
class _PageIndicator extends StatelessWidget {
  final WeatherTheme theme;
  const _PageIndicator({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(1),
        const SizedBox(width: 6),
        _dot(0.4),
        const SizedBox(width: 6),
        _dot(0.4),
      ],
    );
  }

  Widget _dot(double alpha) => Container(
    width: 6,
    height: 6,
    decoration: BoxDecoration(color: theme.foreground.withValues(alpha: alpha * 0.85), shape: BoxShape.circle),
  );
}

// 陈旧数据提示条：网络拉不到时会显示，提醒用户当前是缓存数据
// 可点击跳搜索页手动换个城市试试
class _StaleBanner extends StatelessWidget {
  final WeatherTheme theme;
  final VoidCallback onSearch;
  const _StaleBanner({required this.theme, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: GestureDetector(
        onTap: onSearch,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD166).withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFD166).withValues(alpha: 0.4), width: 0.6),
          ),
          child: Row(
            children: [
              Icon(Icons.wifi_off_rounded, size: 16, color: theme.foreground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '网络异常，显示的是缓存数据',
                  style: TextStyle(color: theme.foreground, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '搜索城市 >',
                style: TextStyle(color: theme.foreground.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 数据来源 + 拉取时间
class _Footer extends StatelessWidget {
  final WeatherTheme theme;
  final DateTime fetchedAt;
  const _Footer({required this.theme, required this.fetchedAt});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(
            '数据由 Open-Meteo 提供',
            style: TextStyle(color: theme.subtleForeground, fontSize: 11, letterSpacing: 0.2),
          ),
          const SizedBox(height: 2),
          Text(
            '更新于 ${fetchedAt.hour.toString().padLeft(2, '0')}:${fetchedAt.minute.toString().padLeft(2, '0')}',
            style: TextStyle(color: theme.subtleForeground, fontSize: 11, letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}
