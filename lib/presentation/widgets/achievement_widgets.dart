import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../../core/feedback/haptics.dart';
import '../../core/services/freeze_bank.dart';
import '../../core/theme/app_palette.dart';
import '../../domain/services/achievements.dart';
import 'large_title_scaffold.dart';
import '../share/share_cards.dart';
import '../share/share_sheet.dart';
import 'orb_button.dart';

/// A round medal with a number and a word under it ("21 DAYS"). Earned
/// medals are in the orb's amber (gold for a habit formed, green for a habit
/// being broken); ones still to come are gray.
class AchievementMedal extends StatelessWidget {
  final String badge;
  final String unit;
  final AchievementKind? kind;
  final double size;

  /// Rays around it, for the celebration.
  final bool rays;

  const AchievementMedal({
    super.key,
    required this.badge,
    required this.unit,
    required this.size,
    this.kind,
    this.rays = false,
  });

  bool get earned => kind != null;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final (Gradient? gradient, Color? fill, Color ink) = switch (kind) {
      null => (null, palette.track, palette.textSecondary),
      AchievementKind.formed => (null, palette.gold, palette.onAccent),
      AchievementKind.clean => (null, palette.good, palette.onAccent),
      AchievementKind.fun => (null, palette.ice, palette.onColor(palette.ice)),
      _ => (palette.orb, null, AppPalette.onOrb),
    };
    final medal = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: BoxDecoration(shape: BoxShape.circle, color: fill, gradient: gradient),
      child: MediaQuery.withNoTextScaling(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              badge,
              style: TextStyle(
                fontFamily: LargeTitleHeader.fontFamily,
                fontSize: size * 0.34,
                height: 1,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            if (unit.isNotEmpty)
              Text(
                unit,
                style: TextStyle(fontSize: math.max(7, size * 0.085), fontWeight: FontWeight.w700, letterSpacing: 0.5, color: ink),
              ),
          ]),
        ),
      ),
    );
    if (!rays) return medal;
    return SizedBox(
      width: size * 1.5,
      height: size * 1.5,
      child: CustomPaint(
        painter: _RaysPainter(color: palette.gauge.withValues(alpha: 0.5)),
        child: Center(child: medal),
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  final Color color;

  _RaysPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final inner = i.isEven ? outer * 0.8 : outer * 0.86;
      canvas.drawLine(center + direction * inner, center + direction * (outer - 2), paint);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) => old.color != color;
}

/// A small tile for the shelf: an earned achievement, or the next one with
/// how far along it is.
class AchievementTile extends StatelessWidget {
  final Achievement? achievement;
  final AchievementProgress? progress;
  final VoidCallback? onTap;
  final double width;

  const AchievementTile.earned(Achievement this.achievement, {super.key, this.onTap, this.width = 112})
      : progress = null;

  const AchievementTile.next(AchievementProgress this.progress, {super.key, this.width = 112})
      : achievement = null,
        onTap = null;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final a = achievement;
    final p = progress;
    final title = a?.title ?? p!.title;
    final sub = a != null ? (a.habitName ?? DateFormat.MMMd().format(a.earnedOn)) : '${p!.current} of ${p.goal}';
    final habit = p?.habitName;

    final tile = Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(color: palette.raised, borderRadius: BorderRadius.circular(18)),
      child: Column(children: [
        AchievementMedal(badge: a?.badge ?? p!.badge, unit: a?.unit ?? p!.unit, kind: a?.kind, size: 52),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.2, fontWeight: FontWeight.w700, color: palette.text),
        ),
        const SizedBox(height: 2),
        Text(
          habit == null ? sub : '$sub · $habit',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, height: 1.2, color: palette.textSecondary),
        ),
        if (p != null) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: p.fraction,
              minHeight: 5,
              color: palette.gauge,
              backgroundColor: palette.track,
            ),
          ),
        ],
      ]),
    );

    return Semantics(
      button: onTap != null,
      label: a != null
          ? '${a.title}${a.habitName == null ? '' : ', ${a.habitName}'}, earned ${DateFormat.yMMMd().format(a.earnedOn)}'
          : 'Next: ${p!.title}${habit == null ? '' : ', $habit'}, ${p.current} of ${p.goal}',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        key: Key(a != null ? 'achievement_${a.id}' : 'nextAchievement_${p!.title}_${habit ?? ''}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: tile,
      ),
    );
  }
}

/// Shows [achievement] in a sheet: as a celebration when it's [isNew] (with
/// a haptic), or to look at again from the shelf.
Future<void> showAchievementSheet(
  BuildContext context,
  Achievement achievement, {
  bool isNew = false,
  AchievementProgress? next,
  FreezeEarned? freeze,
}) {
  if (isNew) Haptics.completed();
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppPalette.of(context).surface,
    builder: (context) => AchievementSheet(achievement: achievement, isNew: isNew, next: next, freeze: freeze),
  );
}

/// What a milestone did for the freeze bank: added one (and how many there
/// are now), or found it full.
typedef FreezeEarned = ({bool added, int available});

class AchievementSheet extends StatelessWidget {
  final Achievement achievement;
  final bool isNew;
  final AchievementProgress? next;
  final FreezeEarned? freeze;

  const AchievementSheet({super.key, required this.achievement, this.isNew = false, this.next, this.freeze});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final a = achievement;
    final n = next;
    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('achievementSheet'),
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(children: [
          Text(
            isNew ? 'NEW ACHIEVEMENT' : 'EARNED ${DateFormat.yMMMd().format(a.earnedOn).toUpperCase()}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1, color: palette.gauge),
          ),
          const SizedBox(height: 12),
          Semantics(
            label: '${a.badge} ${a.unit.toLowerCase()}',
            excludeSemantics: true,
            child: AchievementMedal(badge: a.badge, unit: a.unit, kind: a.kind, size: 132, rays: true),
          ),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text(
              a.title,
              key: const Key('achievementTitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: LargeTitleHeader.fontFamily,
                fontSize: 26,
                height: 1.15,
                fontWeight: FontWeight.w700,
                color: palette.text,
              ),
            ),
          ),
          // Not when the title already says it ("30 days without smoking")
          if (a.habitName != null && !a.title.toLowerCase().contains(a.habitName!.toLowerCase())) ...[
            const SizedBox(height: 4),
            Text(a.habitName!, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: palette.textSecondary)),
          ],
          const SizedBox(height: 10),
          Text(
            a.message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.45, color: palette.textSecondary),
          ),
          if (freeze case final f?) ...[
            const SizedBox(height: 14),
            Container(
              key: const Key('achievementFreeze'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: palette.tint(palette.ice), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(CupertinoIcons.snow, size: 16, color: palette.ice),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    f.added ? '+1 freeze · ${f.available} of ${FreezeBank.cap}' : 'Freeze bank full (${FreezeBank.cap} of ${FreezeBank.cap})',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: palette.text),
                  ),
                ),
              ]),
            ),
          ],
          if (n != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: palette.raised, borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  children: [
                    Text('Next: ${n.title}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: palette.text)),
                    Text('${n.goal - n.current} to go', style: TextStyle(fontSize: 14, color: palette.textSecondary)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: n.fraction,
                    minHeight: 8,
                    color: palette.gauge,
                    backgroundColor: palette.track,
                  ),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 22),
          OrbButton(
            key: const Key('achievementShare'),
            label: 'Share',
            onPressed: () => showShareSheet(
              context,
              card: (look, hideName) => AchievementShareCard(achievement: a, look: look, hideName: hideName),
              fileName: 'momentum-achievement.png',
              canHideName: a.habitName != null,
              // Habits being broken are often private
              hideNameByDefault: a.kind == AchievementKind.clean,
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            key: const Key('achievementDone'),
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: palette.text, minimumSize: const Size.fromHeight(48)),
            child: const Text('Done', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}
