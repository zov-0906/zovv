import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/soft_background.dart';
import '../domain/startup_config.dart';

/// Default launch: a quiet entrance, with a single welcome action on first use.
class StartupScreen extends StatefulWidget {
  const StartupScreen({
    super.key,
    required this.config,
    required this.onComplete,
  });
  final StartupConfig config;
  final VoidCallback onComplete;
  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _animation;
  bool _done = false;
  bool _resumeAnimation = false;
  bool _reduced = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animation =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1800),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed &&
              !widget.config.fullSequence) {
            _finish();
          }
        });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _animation.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
  }

  void _finish() {
    if (_done) return;
    _done = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onComplete();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_resumeAnimation) _animation.forward();
      _resumeAnimation = false;
    } else if (_animation.isAnimating) {
      _resumeAnimation = true;
      _animation.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: palette.isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: palette.canvas,
        systemNavigationBarIconBrightness: palette.isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Material(
        color: palette.canvas,
        child: SoftBackground(
          child: SafeArea(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                final enter = Curves.easeOutCubic.transform(
                  (_animation.value / .65).clamp(0, 1),
                );
                final exit = widget.config.fullSequence
                    ? 0.0
                    : Curves.easeInOut.transform(
                        ((_animation.value - .72) / .28).clamp(0, 1),
                      );
                return Opacity(
                  opacity: 1 - exit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 22,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text(
                              'ZOVV',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              key: const Key('startup-skip'),
                              onPressed: _finish,
                              child: Text(
                                '跳过',
                                style: TextStyle(
                                  color: palette.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              child: Opacity(
                                opacity: enter,
                                child: Transform.translate(
                                  offset: Offset(
                                    0,
                                    _reduced ? 0 : 18 * (1 - enter),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Transform.scale(
                                        scale: _reduced ? 1 : .92 + enter * .08,
                                        child: const GlassSurface(
                                          radius: 38,
                                          padding: EdgeInsets.all(30),
                                          child: BrandMark(size: 68),
                                        ),
                                      ),
                                      const SizedBox(height: 34),
                                      const Text(
                                        'ZOVV',
                                        style: TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 5,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        widget.config.fullSequence
                                            ? '让日常，多一点可能。'
                                            : '每次开启，都是新的可能。',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: palette.muted,
                                          height: 1.6,
                                        ),
                                      ),
                                      const SizedBox(height: 44),
                                      if (!widget.config.fullSequence)
                                        _StartupTrace(
                                          value: _animation.value,
                                          track: palette.line,
                                          accent: palette.accent,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (widget.config.fullSequence) ...[
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              key: const Key('startup-start'),
                              onPressed: _animation.value < .65
                                  ? null
                                  : _finish,
                              style: FilledButton.styleFrom(
                                backgroundColor: palette.ink,
                                foregroundColor: palette.canvas,
                                minimumSize: const Size(0, 56),
                                shape: const StadiumBorder(),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('开始使用', style: TextStyle(fontSize: 15)),
                                  SizedBox(width: 12),
                                  Icon(Icons.arrow_forward_rounded, size: 18),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                        Text(
                          'YOUR SPACE. MORE POSSIBILITIES.',
                          style: TextStyle(
                            fontSize: 9,
                            color: palette.muted,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Hand-drawn launch trace: hairline track with a soft head, no Material bar.
class _StartupTrace extends StatelessWidget {
  const _StartupTrace({
    required this.value,
    required this.track,
    required this.accent,
  });
  final double value;
  final Color track;
  final Color accent;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 34,
    height: 3,
    child: CustomPaint(painter: _TracePainter(value, track, accent)),
  );
}

class _TracePainter extends CustomPainter {
  _TracePainter(this.value, this.track, this.accent);
  final double value;
  final Color track;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = track,
    );
    final progress = value.clamp(0.0, 1.0);
    if (progress <= 0) return;
    final width = size.width * progress;
    final head = Offset(width, size.height / 2);
    canvas.drawCircle(
      head,
      size.height * 2.2,
      Paint()..color = accent.withValues(alpha: .18),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, width, size.height), radius),
      Paint()..color = accent,
    );
    canvas.drawCircle(
      head,
      size.height * .9,
      Paint()..color = Colors.white.withValues(alpha: .85),
    );
  }

  @override
  bool shouldRepaint(_TracePainter oldDelegate) => oldDelegate.value != value;
}
