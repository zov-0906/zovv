import 'package:flutter/material.dart';

import '../../../core/widgets/zovv_loader.dart';
import '../../../core/widgets/glass_button.dart';
import '../application/drama_library_controller.dart';
import '../domain/drama.dart';
import 'drama_detail_screen.dart';

class DramaDetailsPage extends StatefulWidget {
  const DramaDetailsPage({
    super.key,
    required this.summary,
    required this.repository,
    required this.library,
  });
  final Drama summary;
  final DramaRepository repository;
  final DramaLibraryController library;
  @override
  State<DramaDetailsPage> createState() => _DramaDetailsPageState();
}

class _DramaDetailsPageState extends State<DramaDetailsPage> {
  late Future<Drama> _details;
  @override
  void initState() {
    super.initState();
    _details = _load();
  }

  Future<Drama> _load() async {
    try {
      return widget.repository is DetailedDramaRepository
          ? await (widget.repository as DetailedDramaRepository).fetchDetails(
              widget.summary,
            )
          : widget.summary;
    } catch (error) {
      if (error is PlaybackUnavailable) rethrow;
      throw const PlaybackUnavailable('详情数据暂时无法读取，请重新加载');
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Drama>(
    future: _details,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return DramaDetailScreen(
          drama: snapshot.data!,
          repository: widget.repository,
          library: widget.library,
        );
      }
      return Scaffold(
        appBar: AppBar(title: Text(widget.summary.title)),
        body: Center(
          child: snapshot.hasError
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('来源详情暂不可用'),
                    if (snapshot.error is PlaybackUnavailable)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                        child: Text(
                          (snapshot.error as PlaybackUnavailable).message,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (snapshot.error is PlaybackUnavailable &&
                        (snapshot.error as PlaybackUnavailable).requestId !=
                            null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '问题编号：${(snapshot.error as PlaybackUnavailable).requestId}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 16),
                    GlassButton(
                      label: '重新加载',
                      icon: Icons.refresh_rounded,
                      onPressed: () => setState(() => _details = _load()),
                    ),
                  ],
                )
              : const ZovvLoader(size: 30),
        ),
      );
    },
  );
}
