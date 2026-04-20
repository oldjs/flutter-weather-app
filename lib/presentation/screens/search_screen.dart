import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/city.dart';
import '../providers/providers.dart';
import '../widgets/common/pill_button.dart';
import '../widgets/common/spinner.dart';

// 搜索页：无 Scaffold、无 AppBar、无 TextField MD 边框、无 ListTile
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  List<City> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // 进入页面自动聚焦输入框
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    // 400ms 防抖
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(weatherRepositoryProvider);
      final list = await repo.searchCity(q);
      if (!mounted) return;
      setState(() {
        _results = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _pick(City c) {
    ref
        .read(targetLocationProvider.notifier)
        .set(TargetLocation(name: c.name, latitude: c.latitude, longitude: c.longitude));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: GestureDetector(
        // 点空白处收起键盘
        onTap: () => _focus.unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Container(
          // 深色渐变底
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0A1326), Color(0xFF0F1A2B), Color(0xFF141F35)],
            ),
          ),
          child: Column(
            children: [
              SizedBox(height: padding.top + 12),
              _Header(
                controller: _controller,
                focus: _focus,
                onChanged: _onChanged,
                onBack: () => Navigator.of(context).pop(),
                onClear: () {
                  _controller.clear();
                  _onChanged('');
                },
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: Spinner(size: 28, strokeWidth: 2, color: Colors.white70));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            '搜索失败：$_error',
            style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_rounded, size: 40, color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(height: 14),
              Text(
                _controller.text.trim().isEmpty ? '输入城市名开始搜索' : '没有找到匹配的城市',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14, letterSpacing: 0.3),
              ),
            ],
          ),
        ),
      );
    }
    // 自定义列表，不用 ListTile
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 40),
      itemCount: _results.length,
      itemBuilder: (_, i) => _CityRow(
        city: _results[i],
        onTap: () => _pick(_results[i]),
        showDivider: i != _results.length - 1,
      ),
    );
  }
}

// 顶部：返回按钮 + 自定义搜索框（没有 MD 下划线）
class _Header extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  final VoidCallback onBack;
  final VoidCallback onClear;
  const _Header({
    required this.controller,
    required this.focus,
    required this.onChanged,
    required this.onBack,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          PillButton(
            onTap: onBack,
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.6), size: 18),
                      const SizedBox(width: 10),
                      // CupertinoTextField 没有 MD 下划线/浮动标签
                      // 关键：autocorrect/enableSuggestions/spellCheck 都要关掉，
                      // 否则部分 Android 输入法会给识别不了的词加红/黄下划线
                      Expanded(
                        child: CupertinoTextField(
                          controller: controller,
                          focusNode: focus,
                          onChanged: onChanged,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            decoration: TextDecoration.none,
                            decorationColor: Colors.transparent,
                            decorationThickness: 0,
                          ),
                          placeholder: '搜索城市',
                          placeholderStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 15,
                            decoration: TextDecoration.none,
                          ),
                          // 显式去掉所有 Cupertino 外框，完全由父容器画
                          decoration: const BoxDecoration(),
                          cursorColor: Colors.white,
                          cursorWidth: 1.5,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          // 关掉各种可能导致下划线/波浪线的装饰
                          autocorrect: false,
                          enableSuggestions: false,
                          spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.search,
                        ),
                      ),
                      // 有输入时显示清除按钮
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: controller,
                        builder: (_, v, __) {
                          if (v.text.isEmpty) return const SizedBox.shrink();
                          return GestureDetector(
                            onTap: onClear,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.cancel_rounded,
                                color: Colors.white.withValues(alpha: 0.55),
                                size: 18,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 单个城市行：自绘，无 ListTile
class _CityRow extends StatefulWidget {
  final City city;
  final VoidCallback onTap;
  final bool showDivider;
  const _CityRow({required this.city, required this.onTap, required this.showDivider});

  @override
  State<_CityRow> createState() => _CityRowState();
}

class _CityRowState extends State<_CityRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final sub = [widget.city.admin1, widget.city.country].where((e) => e != null && e.isNotEmpty).join(' · ');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _pressed ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  // 左侧小指示点
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.4), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.city.name,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        if (sub.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            sub,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.35), size: 20),
                ],
              ),
            ),
            // 自定义分隔线，不用 Divider
            if (widget.showDivider)
              Container(
                height: 0.5,
                margin: const EdgeInsets.only(left: 20),
                color: Colors.white.withValues(alpha: 0.08),
              ),
          ],
        ),
      ),
    );
  }
}
