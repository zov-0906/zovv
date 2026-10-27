import 'package:flutter/material.dart';

import 'glass_surface.dart';
import 'zovv_loader.dart';

/// One refresh state machine and visual language on Android and iOS.
class ZovvRefresh extends StatefulWidget {
  const ZovvRefresh({super.key, required this.child, required this.onRefresh});
  final Widget child;
  final Future<void> Function() onRefresh;
  @override
  State<ZovvRefresh> createState() => _ZovvRefreshState();
}

class _ZovvRefreshState extends State<ZovvRefresh> {
  RefreshIndicatorStatus? _status;
  Future<void>? _pending;
  double _pull = 0;
  Future<void> _refresh() =>
      _pending ??= _perform().whenComplete(() => _pending = null);
  Future<void> _perform() async {
    try {
      await widget.onRefresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(const SnackBar(content: Text('更新失败，保留已加载内容。请稍后重试。')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible =
        _status != null &&
        _status != RefreshIndicatorStatus.done &&
        _status != RefreshIndicatorStatus.canceled;
    final running =
        _status == RefreshIndicatorStatus.refresh ||
        _status == RefreshIndicatorStatus.snap;
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notice) {
            if (notice.depth == 0 && notice.metrics.axis == Axis.vertical) {
              final pull = (-notice.metrics.pixels).clamp(0.0, 96.0);
              if ((_pull - pull).abs() > 1) setState(() => _pull = pull);
            }
            return false;
          },
          child: RefreshIndicator.noSpinner(
            onRefresh: _refresh,
            onStatusChange: (value) {
              if (mounted) setState(() => _status = value);
            },
            child: widget.child,
          ),
        ),
        AnimatedPositioned(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 120),
          top: 8 + (running ? 0 : _pull * .2),
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: Center(
                child: GlassSurface(
                  radius: 18,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (running)
                        const ZovvLoader(size: 16)
                      else
                        Icon(
                          _status == RefreshIndicatorStatus.armed
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 16,
                        ),
                      const SizedBox(width: 8),
                      Text(
                        running
                            ? '正在更新故事…'
                            : _status == RefreshIndicatorStatus.armed
                            ? '松开刷新'
                            : '下拉刷新',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
