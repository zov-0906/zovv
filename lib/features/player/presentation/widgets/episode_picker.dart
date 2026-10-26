import 'package:flutter/material.dart';

import '../../../../core/widgets/glass_button.dart';
import '../../../drama/domain/drama.dart';

/// A bounded grid keeps long series navigable and opens at the current episode.
class EpisodePicker extends StatefulWidget {
  const EpisodePicker({
    super.key,
    required this.episodes,
    required this.current,
    required this.onSelected,
  });
  final List<Episode> episodes;
  final int current;
  final ValueChanged<int> onSelected;
  @override
  State<EpisodePicker> createState() => _EpisodePickerState();
}

class _EpisodePickerState extends State<EpisodePicker> {
  late int _chunk = widget.current ~/ 50;
  final _scroll = ScrollController();
  bool _positioned = false;
  void _changeChunk(int delta) {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() => _chunk += delta);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = _chunk * 50;
    final end = (start + 50).clamp(0, widget.episodes.length);
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: '前 50 集',
              onPressed: _chunk > 0 ? () => _changeChunk(-1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text('${start + 1}–$end 集', textAlign: TextAlign.center),
            ),
            IconButton(
              tooltip: '后 50 集',
              onPressed: end < widget.episodes.length
                  ? () => _changeChunk(1)
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (!_positioned) {
                _positioned = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || !_scroll.hasClients) return;
                  final rowHeight = (constraints.maxWidth - 32) / 5 / 1.55 + 8;
                  final offset = ((widget.current - start) ~/ 5) * rowHeight;
                  _scroll.jumpTo(
                    offset.clamp(0, _scroll.position.maxScrollExtent),
                  );
                });
              }
              return GridView.builder(
                controller: _scroll,
                key: ValueKey(_chunk),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.55,
                ),
                itemCount: end - start,
                itemBuilder: (context, offset) {
                  final index = start + offset;
                  final episode = widget.episodes[index];
                  return GlassButton(
                    compact: true,
                    label: '${episode.number}',
                    selected: index == widget.current,
                    icon: episode.locked ? Icons.lock_outline_rounded : null,
                    onPressed: episode.locked
                        ? null
                        : () => widget.onSelected(index),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
