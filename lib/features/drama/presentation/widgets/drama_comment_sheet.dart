import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_sheet.dart';
import '../../../../core/widgets/glass_button.dart';
import '../../../../core/widgets/zovv_loader.dart';
import '../../domain/drama.dart';
import '../../domain/episode_extras.dart';

class DramaCommentSheet extends StatefulWidget {
  const DramaCommentSheet({
    super.key,
    required this.title,
    required this.episodeLabel,
    required this.load,
  });
  final String title;
  final String episodeLabel;
  final Future<CommentDigest> Function() load;
  @override
  State<DramaCommentSheet> createState() => DramaCommentSheetState();
}

class DramaCommentSheetState extends State<DramaCommentSheet> {
  late Future<CommentDigest> _future = widget.load();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GlassSheet(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .62,
        child: FutureBuilder<CommentDigest>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: ZovvLoader(size: 26));
            }
            if (snapshot.hasError) {
              final error = snapshot.error;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        error is PlaybackUnavailable
                            ? error.message
                            : '公开剧评暂时打不开，请稍后再试',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: palette.muted),
                      ),
                      const SizedBox(height: 16),
                      GlassButton(
                        label: '重试',
                        onPressed: () =>
                            setState(() => _future = widget.load()),
                      ),
                    ],
                  ),
                ),
              );
            }
            final digest = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '公开剧评',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${widget.title} · ${widget.episodeLabel}'
                        '${digest.total != null ? ' · 共 ${digest.total} 条' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: palette.muted),
                      ),
                      if (digest.notice != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          digest.notice!,
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.5,
                            color: palette.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Divider(height: 1, color: palette.line),
                Expanded(
                  child: digest.items.isEmpty
                      ? Center(
                          child: Text(
                            '官网暂未提供本集评论',
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.muted,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
                          itemCount: digest.items.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 22,
                            color: palette.line.withValues(alpha: .7),
                          ),
                          itemBuilder: (context, index) {
                            final comment = digest.items[index];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        comment.author.isEmpty
                                            ? '匿名用户'
                                            : comment.author,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: palette.ink,
                                        ),
                                      ),
                                    ),
                                    if (comment.likes != null)
                                      Text(
                                        '♡ ${comment.likes}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: palette.muted,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  comment.content,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.65,
                                    color: palette.ink,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
