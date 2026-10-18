import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../core/theme/app_palette.dart';
import '../../domain/entities/momentum.dart';
import '../widgets/large_title_scaffold.dart';
import 'momentum_mark.dart';

/// The intro on a cold launch: MOMENTUM holds still while the level above it
/// climbs, Building, Rolling, Strong, Unstoppable, to ATOMIC with a burst,
/// then the mark rises over "Atomic Momentum" and the intro fades into the
/// app. About two and a half seconds; a tap skips to the end.
class IntroScreen extends StatefulWidget {
  /// The whole intro, and with Reduce Motion (the final frame alone).
  static const duration = Duration(milliseconds: 2400);
  static const reducedDuration = Duration(milliseconds: 800);

  /// Each level below Atomic shows this long, one after another.
  static const wordSeconds = 0.3;

  /// When ATOMIC lands, when the mark rises, and when the fade begins.
  static const atomicAt = 1.2;
  static const markAt = 1.6;
  static const fadeAt = 2.1;

  /// The most one frame moves the intro on, so a stalled start (a busy first
  /// launch) pauses it instead of skipping it.
  static const maxStep = Duration(milliseconds: 50);

  final VoidCallback onDone;

  const IntroScreen({super.key, required this.onDone});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  Duration _lastTick = Duration.zero;
  bool _reduced = false;
  bool _started = false;
  bool _finished = false;

  /// Seconds of intro shown so far.
  double _elapsed = 0;

  double get _total => (_reduced ? IntroScreen.reducedDuration : IntroScreen.duration).inMilliseconds / 1000;
  double get _fadeFrom => _reduced ? _total - 0.3 : IntroScreen.fadeAt;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduced = MediaQuery.disableAnimationsOf(context);
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // The intro counts only time it was on screen: while the app is busy
  // starting up (loading a long history) frames stall, and a clock would
  // run the intro out before anyone saw it. A frame moves it on at most
  // IntroScreen.maxStep
  void _tick(Duration now) {
    final step = now - _lastTick;
    _lastTick = now;
    final seconds = (step > IntroScreen.maxStep ? IntroScreen.maxStep : step).inMicroseconds / 1e6;
    setState(() => _elapsed = math.min(_total, _elapsed + seconds));
    if (_elapsed >= _total && !_finished) {
      _finished = true;
      _ticker.stop();
      widget.onDone();
    }
  }

  void _skip() {
    if (_elapsed < _fadeFrom) setState(() => _elapsed = _fadeFrom);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    // Seconds into the intro; with Reduce Motion, the final frame throughout
    final t = _reduced ? IntroScreen.fadeAt : _elapsed;
    final opacity = 1 - _ease((_elapsed - _fadeFrom) / (_total - _fadeFrom));
    return Semantics(
      label: 'Momentum',
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('intro'),
        behavior: HitTestBehavior.opaque,
        onTap: _skip,
        child: Opacity(
          opacity: opacity,
          child: ColoredBox(
            color: palette.background,
            // Its own text style: it sits above the app's pages
            child: Material(type: MaterialType.transparency, child: _Frame(t: t)),
          ),
        ),
      ),
    );
  }
}

double _ease(double x) => Curves.easeOut.transform(x.clamp(0.0, 1.0));

/// One frame of the intro, [t] seconds in.
class _Frame extends StatelessWidget {
  final double t;

  const _Frame({required this.t});

  static const _markSize = 150.0;
  static const _wordHeight = 64.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    const levels = MomentumLevel.values;
    final climbing = levels.sublist(0, levels.length - 1);
    // The explainer's bar, brightening level by level
    const shades = [0.25, 0.4, 0.6, 0.8, 1.0];

    final markIn = _ease((t - IntroScreen.markAt) / 0.35);
    final momentumIn = _ease(t / 0.2);

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The mark's place is kept from the start, so nothing below moves
              SizedBox(
                height: _markSize,
                child: Opacity(
                  opacity: markIn,
                  child: Transform.translate(
                    offset: Offset(0, 16 * (1 - markIn)),
                    child: Transform.scale(
                      scale: 0.9 + 0.1 * markIn,
                      child: const MomentumMark(key: Key('introMark'), size: _markSize),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: _wordHeight,
                width: width,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    for (var i = 0; i < climbing.length; i++)
                      _ClimbingWord(
                        level: climbing[i],
                        local: (t - i * IntroScreen.wordSeconds) / IntroScreen.wordSeconds,
                        streak: palette.gauge.withValues(alpha: shades[i]),
                        width: width,
                      ),
                    _Atomic(t: t - IntroScreen.atomicAt, width: width),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Opacity(
                opacity: momentumIn,
                child: Text(
                  'MOMENTUM',
                  key: const Key('introMomentum'),
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: LargeTitleHeader.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 8,
                    color: palette.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

TextStyle _wordStyle(Color color) => TextStyle(
      fontFamily: LargeTitleHeader.fontFamily,
      fontSize: 44,
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.1,
    );

/// A level below Atomic: in from the left on a streak, out to the right.
/// [local] runs 0 to 1 over its turn.
class _ClimbingWord extends StatelessWidget {
  final MomentumLevel level;
  final double local;
  final Color streak;
  final double width;

  const _ClimbingWord({required this.level, required this.local, required this.streak, required this.width});

  @override
  Widget build(BuildContext context) {
    if (local < 0 || local > 1) return const SizedBox.shrink();
    final palette = AppPalette.of(context);
    final enter = _ease(local / 0.3);
    final leave = _ease((local - 0.75) / 0.25);
    final dx = -48 * (1 - enter) + 36 * leave;
    final opacity = enter * (1 - leave);
    final style = _wordStyle(palette.text);
    final wordWidth = (TextPainter(
      text: TextSpan(text: level.label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout())
        .width
        .clamp(0.0, width);
    return Opacity(
      key: Key('introWord_${level.name}'),
      opacity: opacity,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          SizedBox(width: width, height: _Frame._wordHeight),
          // The streak it rides in on, from the left edge to just short of the word
          Positioned(
            left: 0,
            width: (width / 2 - wordWidth / 2 + dx - 10).clamp(0.0, width),
            top: _Frame._wordHeight / 2 - 1.5,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(colors: [streak.withValues(alpha: 0), streak]),
                boxShadow: [BoxShadow(color: streak.withValues(alpha: streak.a * 0.6), blurRadius: 8)],
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(dx, 0),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(level.label, maxLines: 1, style: style),
            ),
          ),
        ],
      ),
    );
  }
}

/// ATOMIC: lands with a burst of rays and sparks, then stays. [t] is seconds
/// since it landed.
class _Atomic extends StatelessWidget {
  final double t;
  final double width;

  const _Atomic({required this.t, required this.width});

  @override
  Widget build(BuildContext context) {
    if (t < 0) return const SizedBox.shrink();
    final palette = AppPalette.of(context);
    final land = _ease(t / 0.15);
    final burst = (t / 0.5).clamp(0.0, 1.0);
    return Stack(
      key: const Key('introWord_atomic'),
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        SizedBox(width: width, height: _Frame._wordHeight),
        if (burst < 1)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _BurstPainter(progress: burst, palette: palette)),
            ),
          ),
        Opacity(
          opacity: land,
          child: Transform.scale(
            scale: 1.25 - 0.25 * land,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                MomentumLevel.atomic.label.toUpperCase(),
                maxLines: 1,
                style: _wordStyle(palette.text).copyWith(
                  letterSpacing: 6,
                  shadows: [Shadow(color: palette.accent.withValues(alpha: 0.6 * (1 - burst * 0.5)), blurRadius: 24)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Rays and sparks flying out from the middle as [progress] goes 0 to 1.
class _BurstPainter extends CustomPainter {
  final double progress;
  final AppPalette palette;

  _BurstPainter({required this.progress, required this.palette});

  static const _rays = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final reach = size.width * 0.55;
    final fade = 1 - progress;
    final grow = Curves.easeOutCubic.transform(progress);
    final random = math.Random(7);

    // A soft flash
    canvas.drawCircle(
      centre,
      reach * 0.5 * (0.4 + grow),
      Paint()
        ..color = palette.orbStart.withValues(alpha: 0.35 * fade)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, reach * 0.12),
    );
    for (var i = 0; i < _rays; i++) {
      final angle = i * 2 * math.pi / _rays + random.nextDouble() * 0.2;
      final length = reach * (0.35 + random.nextDouble() * 0.65);
      final direction = Offset(math.cos(angle), math.sin(angle) * 0.6);
      final start = centre + direction * length * grow * 0.3;
      final end = centre + direction * length * grow;
      canvas.drawLine(
        start,
        end,
        Paint()
          ..shader = LinearGradient(
            colors: [palette.orbStart.withValues(alpha: fade), palette.orbEnd.withValues(alpha: 0)],
          ).createShader(Rect.fromPoints(start, end))
          ..strokeWidth = 1.5 + random.nextDouble()
          ..strokeCap = StrokeCap.round,
      );
      // A spark further out along some rays
      if (i.isEven) {
        canvas.drawCircle(
          centre + direction * length * (0.4 + grow * 0.8),
          1.6,
          Paint()..color = palette.orbStart.withValues(alpha: fade),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.palette != palette;
}

/// Shows the intro over [child] (the app, building underneath) when
/// [enabled], then gets out of the way; [onDone] runs once it has gone.
class IntroGate extends StatefulWidget {
  final bool enabled;
  final VoidCallback? onDone;
  final Widget child;

  const IntroGate({super.key, required this.enabled, this.onDone, required this.child});

  @override
  State<IntroGate> createState() => _IntroGateState();
}

class _IntroGateState extends State<IntroGate> {
  late bool _showing = widget.enabled;

  void _done() {
    setState(() => _showing = false);
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    // The same shape with or without the intro, so the app keeps its state
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(excluding: _showing, child: widget.child),
        if (_showing) IntroScreen(onDone: _done),
      ],
    );
  }
}
