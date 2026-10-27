import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/zovv_refresh.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_surface.dart';
import '../domain/drama.dart';
import 'widgets/drama_poster.dart';
import 'widgets/drama_skeleton.dart';

class DramaSearchScreen extends StatefulWidget {
  const DramaSearchScreen({
    super.key,
    required this.dramas,
    required this.onOpen,
    this.repository,
    this.onRefreshCatalog,
  });
  final List<Drama> dramas;
  final ValueChanged<Drama> onOpen;
  final DramaRepository? repository;
  final Future<void> Function()? onRefreshCatalog;
  @override
  State<DramaSearchScreen> createState() => _DramaSearchScreenState();
}

class _DramaSearchScreenState extends State<DramaSearchScreen> {
  /// Debug-only probe so a UI check can pre-fill a query on a device without a
  /// Chinese IME: `--dart-define=ZOVV_SEARCH_PROBE=荒年萌宠`.
  static const _probeQuery = String.fromEnvironment('ZOVV_SEARCH_PROBE');
  final _text = TextEditingController();
  Timer? _debounce;
  String _query = '';
  List<Drama>? _remote;
  bool _loading = false;
  String? _error;
  String? _notice;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    if (kDebugMode && _probeQuery.isNotEmpty) {
      _text.text = _probeQuery;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _changed(_probeQuery);
      });
    }
  }

  void _changed(String value) {
    _debounce?.cancel();
    ++_request;
    setState(() {
      _query = value;
      _error = null;
      _notice = null;
      _remote = null;
      _loading =
          value.trim().isNotEmpty &&
          widget.repository is SearchableDramaRepository;
    });
    if (_loading) {
      _debounce = Timer(const Duration(milliseconds: 400), () => _search());
    }
  }

  Future<void> _search() async {
    _debounce?.cancel();
    final query = _query.trim();
    if (query.isEmpty || widget.repository is! SearchableDramaRepository) {
      if (query.isEmpty) await widget.onRefreshCatalog?.call();
      return;
    }
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });
    try {
      final searchable = widget.repository as SearchableDramaRepository;
      final SearchOutcome outcome;
      if (searchable is NotedSearchableDramaRepository) {
        outcome = await (searchable as NotedSearchableDramaRepository)
            .searchWithNotice(query);
      } else {
        outcome = SearchOutcome(dramas: await searchable.search(query));
      }
      if (!mounted || request != _request) return;
      setState(() {
        _remote = outcome.dramas;
        _notice = outcome.notice;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _error = '来源搜索暂不可用，请重试';
      });
    }
  }

  @override
  void dispose() {
    ++_request;
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final query = _query.trim().toLowerCase();
    final results =
        query.isNotEmpty && widget.repository is SearchableDramaRepository
        ? _remote ?? <Drama>[]
        : widget.dramas
              .where(
                (item) =>
                    query.isEmpty ||
                    '${item.title} ${item.subtitle} ${item.category}'
                        .toLowerCase()
                        .contains(query),
              )
              .toList();
    return ZovvRefresh(
      onRefresh: _search,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 125),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '找一个好故事',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w600,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 22),
            GlassSurface(
              radius: 14,
              child: TextField(
                key: const Key('drama-search'),
                controller: _text,
                onChanged: _changed,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) {
                  FocusScope.of(context).unfocus();
                  _search();
                },
                style: TextStyle(fontSize: 14, color: palette.ink),
                decoration: InputDecoration(
                  hintText: '搜索剧名、题材',
                  hintStyle: TextStyle(color: palette.muted, fontSize: 14),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 22,
                    color: palette.muted,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清空搜索',
                          color: palette.muted,
                          onPressed: () {
                            _text.clear();
                            _changed('');
                          },
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              _loading
                  ? '正在寻找…'
                  : query.isEmpty
                  ? '随心探索'
                  : '找到 ${results.length} 个故事',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: palette.ink,
              ),
            ),
            if (!_loading && _notice != null) ...[
              const SizedBox(height: 8),
              Text(
                _notice!,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  color: palette.muted,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_error != null && results.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '更新失败，保留上次搜索结果。下拉可重试。',
                  style: TextStyle(color: palette.muted, fontSize: 12),
                ),
              ),
            if (_loading && _remote == null)
              const DramaGridSkeleton(rows: 2)
            else if (_error != null && results.isEmpty)
              Center(
                child: Column(
                  children: [
                    Text(_error!, style: TextStyle(color: palette.ink)),
                    TextButton(onPressed: _search, child: const Text('重试')),
                  ],
                ),
              )
            else if (results.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 75),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 38,
                        color: palette.muted,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '还没有找到这个故事',
                        style: TextStyle(fontSize: 16, color: palette.ink),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '换个剧名或题材试试',
                        style: TextStyle(color: palette.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  for (final drama in results) ...[
                    _SearchResultTile(
                      drama: drama,
                      onTap: () => widget.onOpen(drama),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Search hit with poster, episode count and a short intro so a viewer can
/// judge a title before opening it.
class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.drama, required this.onTap});
  final Drama drama;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final meta = drama.episodeCount > 0
        ? '${drama.category} · ${drama.episodeLabel}'
        : drama.category;
    return Semantics(
      key: Key('drama-card-${drama.id}'),
      button: true,
      label: '查看${drama.title}',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: palette.isDark
                ? Colors.white.withValues(alpha: .04)
                : Colors.white.withValues(alpha: .6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 76,
                height: 106,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: DramaPoster(drama: drama, showTitle: false),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      drama.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      meta,
                      style: TextStyle(fontSize: 10.5, color: palette.muted),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      drama.description.isEmpty
                          ? '简介暂缺，点开后可查看详情'
                          : drama.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.5,
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}
