import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/city.dart';
import '../providers/providers.dart';

// 城市搜索页：输入防抖 + 列表点击切换
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<City> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
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
    // 等用户停 400ms 再发请求，避免每键盘敲击都调 API
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
    ref.read(targetLocationProvider.notifier).set(TargetLocation(name: c.name, latitude: c.latitude, longitude: c.longitude));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1A2B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          onChanged: _onChanged,
          decoration: const InputDecoration(
            hintText: '搜索城市',
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white70));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '搜索失败：$_error',
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text('输入城市名开始搜索', style: TextStyle(color: Colors.white38)),
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
      itemBuilder: (_, i) {
        final c = _results[i];
        return ListTile(
          leading: const Icon(Icons.location_on_outlined, color: Colors.white70),
          title: Text(
            c.name,
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            [c.admin1, c.country].where((e) => e != null && e.isNotEmpty).join(' · '),
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          onTap: () => _pick(c),
        );
      },
    );
  }
}
