import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/weather_codes.dart';
import '../../core/theme/weather_theme.dart';
import '../../domain/entities/weather.dart';
import '../providers/providers.dart';
import '../widgets/animated_background.dart';
import '../widgets/aqi_card.dart';
import '../widgets/current_weather_card.dart';
import '../widgets/daily_forecast.dart';
import '../widgets/detail_grid.dart';
import '../widgets/hourly_forecast.dart';
import '../widgets/life_index.dart';
import '../widgets/sun_arc.dart';
import 'search_screen.dart';

// 主页
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(weatherProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: weatherAsync.when(
        data: (w) => _Loaded(bundle: w),
        loading: () => const _Loading(),
        error: (e, _) => _ErrorView(error: e, onRetry: () => ref.invalidate(weatherProvider)),
      ),
    );
  }
}

// 加载中
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
            CircularProgressIndicator(color: Colors.white70),
            SizedBox(height: 16),
            Text('正在获取天气…', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

// 错误提示
class _ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

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
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: Colors.white70, size: 56),
              const SizedBox(height: 16),
              Text(
                '获取天气失败',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
            ],
          ),
        ),
      ),
    );
  }
}

// 数据加载完成后的页面
class _Loaded extends ConsumerWidget {
  final WeatherBundle bundle;
  const _Loaded({required this.bundle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = WeatherCodes.kindOf(bundle.current.weatherCode);
    final theme = WeatherTheme.of(kind, isDay: bundle.current.isDay);

    // 沉浸式：状态栏透明、图标跟着背景亮度走
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: theme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: theme.gradient.last,
        systemNavigationBarIconBrightness: theme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // 底层：渐变 + 天气动效
        AnimatedBackground(kind: kind, isDay: bundle.current.isDay),
        // 上层：可滚动内容，下拉刷新
        SafeArea(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(weatherProvider),
            backgroundColor: theme.cardBackground,
            color: theme.foreground,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(
                  child: _TopBar(
                    theme: theme,
                    onSearch: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    ),
                    onGps: () async {
                      // 点定位图标：拿一次 GPS 并刷新
                      try {
                        await ref.read(targetLocationProvider.notifier).useGps();
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('定位失败：$e')));
                      }
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 24),
                    child: CurrentWeatherCard(cityName: bundle.cityName, current: bundle.current, theme: theme),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverList.list(
                    children: [
                      HourlyForecast(hourly: bundle.hourly, theme: theme),
                      const SizedBox(height: 16),
                      DailyForecast(daily: bundle.daily, theme: theme),
                      if (bundle.airQuality != null) ...[
                        const SizedBox(height: 16),
                        AqiCard(air: bundle.airQuality!, theme: theme),
                      ],
                      const SizedBox(height: 16),
                      DetailGrid(current: bundle.current, theme: theme),
                      const SizedBox(height: 16),
                      if (bundle.daily.isNotEmpty) SunArc(today: bundle.daily.first, theme: theme),
                      const SizedBox(height: 16),
                      LifeIndex(current: bundle.current, theme: theme),
                      const SizedBox(height: 16),
                      _Footer(theme: theme, fetchedAt: bundle.fetchedAt),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// 顶栏：定位图标 + 搜索按钮
class _TopBar extends StatelessWidget {
  final WeatherTheme theme;
  final VoidCallback onSearch;
  final VoidCallback onGps;
  const _TopBar({required this.theme, required this.onSearch, required this.onGps});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.my_location_rounded, color: theme.foreground),
            onPressed: onGps,
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.search_rounded, color: theme.foreground),
            onPressed: onSearch,
          ),
        ],
      ),
    );
  }
}

// 数据来源声明 + 拉取时间
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
            style: TextStyle(color: theme.subtleForeground, fontSize: 11),
          ),
          Text(
            '更新于 ${fetchedAt.hour.toString().padLeft(2, '0')}:${fetchedAt.minute.toString().padLeft(2, '0')}',
            style: TextStyle(color: theme.subtleForeground, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
