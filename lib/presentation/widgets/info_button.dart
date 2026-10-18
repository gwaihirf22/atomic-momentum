import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';
import '../../domain/entities/momentum.dart';
import '../help/explainers.dart';
import 'large_title_scaffold.dart';
import 'orb_button.dart';

/// What a two-minute explainer shows as its example: the usual habit and
/// its tiny version ("Read 10 pages" and "Read one page").
typedef TwoMinuteExample = ({String usual, String tiny});

/// A small gray (i) that opens an explainer sheet for [topic].
class InfoButton extends StatelessWidget {
  final InfoTopic topic;

  /// For two-minute days: the habit's own example, if it has one.
  final TwoMinuteExample? example;

  /// For momentum: the score to mark on the levels.
  final double? momentum;

  const InfoButton({super.key, required this.topic, this.example, this.momentum});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: topic.buttonLabel,
      excludeSemantics: true,
      onTap: () => showInfoSheet(context, topic, example: example, momentum: momentum),
      child: GestureDetector(
        key: Key('info_${topic.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => showInfoSheet(context, topic, example: example, momentum: momentum),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(CupertinoIcons.info_circle, size: 21, color: AppPalette.of(context).textSecondary),
        ),
      ),
    );
  }
}

/// Opens the explainer for [topic] over everything (the tab bar included).
Future<void> showInfoSheet(BuildContext context, InfoTopic topic, {TwoMinuteExample? example, double? momentum}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppPalette.of(context).surface,
    builder: (context) => InfoSheet(topic: topic, example: example, momentum: momentum),
  );
}

/// An explainer: title, a short intro, a picture of the idea, its points
/// and where it comes from, then "Got it".
class InfoSheet extends StatelessWidget {
  final InfoTopic topic;
  final TwoMinuteExample? example;
  final double? momentum;

  const InfoSheet({super.key, required this.topic, this.example, this.momentum});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final explainer = Explainer.of(topic);

    return SafeArea(
      child: SingleChildScrollView(
        key: Key('infoSheet_${topic.name}'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              _Badge(topic: topic),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    explainer.title,
                    style: TextStyle(
                      fontFamily: LargeTitleHeader.fontFamily,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: palette.text,
                    ),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Text(explainer.intro, style: TextStyle(fontSize: 16, height: 1.4, color: palette.text)),
            const SizedBox(height: 16),
            switch (topic) {
              InfoTopic.twoMinute => _Example(example ?? (usual: 'Read 10 pages', tiny: 'Read one page')),
              InfoTopic.momentum => _Levels(score: momentum),
              InfoTopic.inspire || InfoTopic.health => const SizedBox.shrink(),
            },
            const SizedBox(height: 16),
            for (final point in explainer.points) ...[
              _Point(point),
              const SizedBox(height: 12),
            ],
            if (explainer.source != null)
              Text(explainer.source!, style: TextStyle(fontSize: 12, color: palette.textSecondary)),
            const SizedBox(height: 18),
            OrbButton(
              key: const Key('infoGotIt'),
              label: 'Got it',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final InfoTopic topic;

  const _Badge({required this.topic});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return switch (topic) {
      InfoTopic.twoMinute => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: palette.accent, width: 1.5),
          ),
          child: Text('2 min', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: palette.accent)),
        ),
      InfoTopic.momentum => Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: palette.goldTint, borderRadius: BorderRadius.circular(11)),
          child: Icon(Icons.bolt, size: 20, color: palette.gauge),
        ),
      InfoTopic.health => Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: palette.goldTint, borderRadius: BorderRadius.circular(11)),
          child: Icon(CupertinoIcons.heart_fill, size: 19, color: palette.danger),
        ),
      InfoTopic.inspire => Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: palette.goldTint, borderRadius: BorderRadius.circular(11)),
          child: Icon(CupertinoIcons.quote_bubble_fill, size: 19, color: palette.accent),
        ),
    };
  }
}

/// "Usually: read 10 pages → On a hard day: read one page".
class _Example extends StatelessWidget {
  final TwoMinuteExample example;

  const _Example(this.example);

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    Widget box(String label, String text, Color background, Color labelColor) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: labelColor)),
              const SizedBox(height: 3),
              Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: palette.text)),
            ],
          ),
        );

    return Semantics(
      label: 'For example: usually, ${example.usual}. On a hard day, ${example.tiny}.',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: box('USUALLY', example.usual, palette.raised, palette.textSecondary)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(CupertinoIcons.arrow_right, size: 16, color: palette.textSecondary),
          ),
          Expanded(child: box('ON A HARD DAY', example.tiny, palette.tint(palette.accent), palette.accent)),
        ]),
      ),
    );
  }
}

/// The four momentum levels as a bar, with [score] marked when given.
class _Levels extends StatelessWidget {
  final double? score;

  const _Levels({this.score});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    const levels = MomentumLevel.values;
    const shades = [0.3, 0.5, 0.75, 1.0];
    Color shade(int i) => palette.tint(palette.gauge, alpha: shades[i]);
    int to(int i) => i + 1 < levels.length ? levels[i + 1].from : 101;
    final current = score == null ? null : MomentumLevel.of(score!);

    return Semantics(
      label: 'Levels: ${[for (var i = 0; i < levels.length; i++) '${levels[i].label} from ${levels[i].from}'].join(', ')}'
          '${current == null ? '' : '. You are at ${score!.round()}, ${current.label}'}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth;
            return SizedBox(
              height: 22,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 5,
                  height: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Row(children: [
                      for (var i = 0; i < levels.length; i++)
                        Expanded(flex: to(i) - levels[i].from, child: ColoredBox(color: shade(i))),
                    ]),
                  ),
                ),
                if (score != null)
                  Positioned(
                    left: (width * score!.clamp(0, 100) / 100 - 2).clamp(0.0, width - 4),
                    top: 0,
                    width: 4,
                    height: 22,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: palette.text, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
              ]),
            );
          }),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (var i = 0; i < levels.length; i++)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: shade(i), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${levels[i].label} · ${levels[i].from}${i + 1 < levels.length ? '–${to(i) - 1}' : '+'}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: levels[i] == current ? FontWeight.w700 : FontWeight.w400,
                      color: levels[i] == current ? palette.text : palette.textSecondary,
                    ),
                  ),
                ]),
            ],
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final ExplainerPoint point;

  const _Point(this.point);

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final style = TextStyle(fontSize: 15, height: 1.4, color: palette.text);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        constraints: const BoxConstraints(minWidth: 24),
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: palette.raised, borderRadius: BorderRadius.circular(12)),
        child: point.icon != null
            ? Icon(point.icon, size: 12, color: palette.textSecondary)
            : Text(point.badge ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: palette.gauge)),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text.rich(
          TextSpan(children: [
            if (point.lead != null) TextSpan(text: '${point.lead}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: point.text),
          ]),
          style: style,
        ),
      ),
    ]);
  }
}
