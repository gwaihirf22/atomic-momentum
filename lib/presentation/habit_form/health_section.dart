import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import '../../core/injection/injection_container.dart';
import '../../core/services/health_source.dart';
import '../../core/theme/app_palette.dart';
import '../../domain/entities/health_link.dart';
import '../help/explainers.dart';
import '../inspire/quote_widgets.dart' show QuoteChoiceChip;
import '../widgets/adaptive.dart';
import '../widgets/info_button.dart';
import 'habit_draft.dart';
import 'sections.dart' show FormSectionHeader;

/// Filling a habit in from Apple Health (iPhone) or Health Connect
/// (Android): a switch, which metric, and for water and mindful minutes
/// whether logging also logs to Health. Only habits being built; nothing
/// shows where there's no health store.
class HealthSection extends StatefulWidget {
  final HabitDraft draft;
  final bool showHeader;

  /// Wraps the section when it shows (a form's card), so nothing is left
  /// behind where it doesn't.
  final Widget Function(Widget section)? wrap;

  const HealthSection(this.draft, {super.key, this.showHeader = true, this.wrap});

  @override
  State<HealthSection> createState() => _HealthSectionState();
}

class _HealthSectionState extends State<HealthSection> {
  late final HealthSource _source = get<HealthSource>();
  late final Future<HealthAvailability> _availability = _source.availability();

  HabitDraft get _draft => widget.draft;

  /// What Health holds today per metric, for the preview (read once each).
  final _today = <HealthMetric, Future<int?>>{};

  @override
  void initState() {
    super.initState();
    // A link that came with the habit (a quick pick, or editing): ask for
    // access, or drop a new habit's link where this phone can't fill it in
    _availability.then((availability) {
      final link = _draft.health;
      if (!mounted || link == null) return;
      final usable = availability == HealthAvailability.available && link.metric.availableOn(isAndroid: _source.isAndroid);
      if (usable) {
        _source.requestAccess(read: {link.metric}, write: {if (link.logsToHealth) link.metric});
      } else if (!_draft.isEditing) {
        _draft.setHealth(null);
      }
    });
  }

  bool _available(HealthMetric metric) => metric.availableOn(isAndroid: _source.isAndroid);

  HealthMetric? get _suggestion =>
      HealthMetric.suggestFor(_draft.name.text, _draft.units.text, available: _available);

  /// Today's amount of [metric] in Health, or null if it couldn't be read.
  Future<int?> _todayIn(HealthMetric metric) => _today.putIfAbsent(metric, () async {
        final now = clock.now();
        final day = DateTime(now.year, now.month, now.day);
        final values = await _source.dailyValues(metric, day, day);
        return values[day];
      });

  Future<void> _turnOn(HealthAvailability availability) async {
    if (availability == HealthAvailability.needsHealthConnect) {
      final install = await confirmAdaptive(
        context,
        title: 'Install Health Connect?',
        message: 'Android keeps health data in the Health Connect app. Install it, then come back.',
        confirmLabel: 'Install',
        confirmKey: const Key('installHealthConnect'),
      );
      if (install) await _source.installHealthConnect();
      return;
    }
    await _choose(_suggestion ?? HealthMetric.values.firstWhere(_available));
  }

  Future<void> _choose(HealthMetric metric, {bool? logToHealth}) async {
    _draft.setHealth(metric, logToHealth: logToHealth);
    final link = _draft.health!;
    await _source.requestAccess(read: {metric}, write: {if (link.logsToHealth) metric});
    // Read again now that access may have been given
    _today.remove(metric);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HealthAvailability>(
      future: _availability,
      builder: (context, snapshot) {
        final availability = snapshot.data;
        if (availability == null || availability == HealthAvailability.unsupported) return const SizedBox.shrink();
        return ListenableBuilder(
          listenable: _draft,
          builder: (context, _) {
            if (_draft.isBreak) return const SizedBox.shrink();
            final section = _content(context, availability);
            return widget.wrap?.call(section) ?? section;
          },
        );
      },
    );
  }

  Widget _content(BuildContext context, HealthAvailability availability) {
    final palette = AppPalette.of(context);
    final link = _draft.health;
    final name = _source.name;
    final metrics = [for (final m in HealthMetric.values) if (m.availableOn(isAndroid: _source.isAndroid)) m];
    final unavailable = link != null && !link.metric.availableOn(isAndroid: _source.isAndroid);

    return Column(
      key: const Key('healthSection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeader) FormSectionHeader(name, trailing: const InfoButton(topic: InfoTopic.health)),
        if (link == null && _suggestion != null && availability == HealthAvailability.available)
          _Suggestion(
            text: '${_suggestion!.label} from $name?',
            onLink: () => _choose(_suggestion!),
          ),
        SwitchListTile.adaptive(
          key: const Key('healthSwitch'),
          contentPadding: EdgeInsets.zero,
          title: Text('Fill in from $name'),
          subtitle: const Text('The higher of Health and what you log counts'),
          value: link != null,
          onChanged: (on) => on ? _turnOn(availability) : _draft.setHealth(null),
        ),
        if (link != null) ...[
          const SizedBox(height: 6),
          if (unavailable)
            Text(
              '${link.metric.label} isn\'t in $name on this phone, so it stays logged by hand.',
              style: TextStyle(fontSize: 13, color: palette.textSecondary),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final metric in metrics)
                QuoteChoiceChip(
                  key: Key('healthMetric_${metric.name}'),
                  label: metric.label,
                  selected: link.metric == metric,
                  onTap: () => _choose(metric),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _note(link.metric),
            key: const Key('healthNote'),
            style: TextStyle(fontSize: 13, color: palette.textSecondary),
          ),
          if (!unavailable)
            FutureBuilder<int?>(
              key: ValueKey(link.metric),
              future: _todayIn(link.metric),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) return const SizedBox(height: 22);
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _preview(link.metric, snapshot.data, name),
                    key: const Key('healthPreview'),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: palette.text),
                  ),
                );
              },
            ),
          if (link.metric.writable)
            SwitchListTile.adaptive(
              key: const Key('healthLogSwitch'),
              contentPadding: EdgeInsets.zero,
              title: Text('Also log to $name'),
              subtitle: Text(link.metric == HealthMetric.water
                  ? 'Each glass you add goes into $name too'
                  : 'Minutes you add go into $name as mindful minutes'),
              value: link.logToHealth,
              onChanged: (on) => _choose(link.metric, logToHealth: on),
            ),
        ],
      ],
    );
  }

  /// "Apple Health shows 4,512 steps today", so a wrong link is plain to see.
  static String _preview(HealthMetric metric, int? value, String name) {
    final when = metric == HealthMetric.sleepHours ? 'last night' : 'today';
    if (value == null || value == 0) {
      return '$name has no ${metric.label.toLowerCase()} for $when yet. If that\'s wrong, check permissions.';
    }
    final amount = NumberFormat.decimalPattern().format(value);
    return '$name shows $amount ${metric.unit} $when.';
  }

  static String _note(HealthMetric metric) => switch (metric) {
        HealthMetric.steps => 'Counts your steps each day.',
        HealthMetric.exerciseMinutes => 'Counts exercise minutes each day.',
        HealthMetric.workouts => 'Counts workouts started each day.',
        HealthMetric.sleepHours => 'Hours asleep, counted on the morning you wake (to the nearest hour).',
        HealthMetric.mindfulMinutes => 'Counts mindful minutes each day.',
        HealthMetric.water => 'Counts water in 250 ml glasses.',
      };
}

/// "Exercise from Apple Health?" with Link: a suggestion from the habit's
/// name, never linked without a tap.
class _Suggestion extends StatelessWidget {
  final String text;
  final VoidCallback onLink;

  const _Suggestion({required this.text, required this.onLink});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      key: const Key('healthSuggestion'),
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(color: palette.goldTint, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(CupertinoIcons.heart_fill, size: 16, color: palette.danger),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: palette.text))),
        TextButton(
          key: const Key('healthSuggestionLink'),
          onPressed: onLink,
          style: TextButton.styleFrom(foregroundColor: palette.accent, minimumSize: const Size(44, 44)),
          child: const Text('Link'),
        ),
      ]),
    );
  }
}
