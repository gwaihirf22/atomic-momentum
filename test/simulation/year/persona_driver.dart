import 'package:atomic_momentum/core/dev/year_persona.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/quote_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';

import 'reference.dart';

/// Does what the persona does, through the app's providers (as its screens
/// would), and the same in the [Reference]'s ledger. Shared by the year
/// simulation and the year on a device.
class PersonaDriver {
  /// The app's habits (a new provider after a cold start).
  final HabitProvider Function() habits;
  final SettingsProvider settings;
  final QuoteProvider quotes;
  final Reference ref;

  /// Adds a habit (and remembers its id).
  final Future<void> Function(CreateHabitParams params) create;

  /// A habit's id by name.
  final String Function(String name) id;
  final void Function(DateTime at, String message) problem;

  PersonaDriver({
    required this.habits,
    required this.settings,
    required this.quotes,
    required this.ref,
    required this.create,
    required this.id,
    required this.problem,
  });

  /// The persona's own quote, once added.
  String? myQuote;

  /// "Another quote" picked: the day and the quote.
  ({DateTime day, String id})? shuffled;

  /// "Another quote" taps since this was last reset.
  int shuffles = 0;

  /// Does [action] at [now] in the app, and in the reference's ledger.
  Future<void> apply(PersonaAction action, DateTime now) async {
    final habits = this.habits();
    var ok = true;
    switch (action) {
      case CreateHabit(:final params):
        await create(params);
        ref.habits[params.name] = RefHabit(params, now);
      case SetTotal(:final habit, :final total):
        ok = await habits.updateHabitProgress(id(habit), total);
        ref.habits[habit]!.setTotal(now, total);
      case LogOn(:final habit, day: final date, :final amount):
        ok = await habits.updateProgressForDate(id(habit), date, amount);
        ref.habits[habit]!.logOn(date, amount);
      case TwoMinuteTap(:final habit):
        ok = await habits.setTwoMinute(id(habit), true);
        ref.habits[habit]!.tap(now);
      case HoldToFinish(:final habit, :final undo):
        final h = habits.getHabitById(id(habit))!;
        final before = h.periodDays(now);
        final r = ref.habits[habit]!;
        final refBefore = r.periodDays(now);
        if (refBefore.toString() != before.toString()) {
          problem(now, '$habit: the period\'s days before a hold are $before, expected $refBefore');
        }
        if (!h.isCompleted) {
          ok = await habits.updateHabitProgress(h.id, h.target);
          r.setTotal(now, r.target);
        } else {
          ok = await habits.setDays(h.id, {for (final d in before.keys) d: 0});
          for (final d in refBefore.keys) {
            r.setDay(d, 0);
          }
        }
        if (undo) {
          ok = await habits.setDays(h.id, before) && ok;
          for (final entry in refBefore.entries) {
            r.setDay(entry.key, entry.value);
          }
          final after = habits.getHabitById(id(habit))!.periodDays(now);
          if (after.toString() != before.toString()) problem(now, '$habit: Undo after a hold left $after, not $before');
        }
      case DayNote(:final habit, :final text):
        ok = await habits.setDayNote(id(habit), now, text);
        ref.habits[habit]!.note(now, text);
        if (habits.getHabitById(id(habit))!.dayNotes[day(now)] != text) problem(now, '$habit: the day note didn\'t stick');
      case StartFrom(:final habit, day: final date):
        final anchor = habits.getHabitById(id(habit))!.schedule.anchor;
        ok = await habits.startFrom(id(habit), date);
        ref.habits[habit]!.trackedFrom = day(date);
        if (habits.getHabitById(id(habit))!.schedule.anchor != anchor) problem(now, '$habit: Start from moved its reset day');
      case CountFrom(:final habit, day: final date, :final clearEarlier):
        final anchor = habits.getHabitById(id(habit))!.schedule.anchor;
        ok = await habits.countFrom(id(habit), date, clearEarlier: clearEarlier);
        ref.habits[habit]!.countFrom(date, clearEarlier: clearEarlier);
        if (habits.getHabitById(id(habit))!.schedule.anchor != anchor) problem(now, '$habit: Counts from moved its reset day');
      case EditHabit(:final habit, :final params):
        ok = await habits.updateHabitDetails(id(habit), params);
        final r = ref.habits[habit]!;
        if (params.target != null) r.target = params.target!;
        if (params.resetInterval != null) r.interval = params.resetInterval!;
        if (params.reminder != null) r.reminder = params.reminder;
        r.scheduleChanged();
      case DeleteHabit(:final habit):
        ok = await habits.deleteHabit(id(habit));
        ref.habits[habit]!.deleted = true;
      case FreezeDay(:final habit, day: final date):
        // Only where the app allows one (not a kept day, within reach)
        if (habits.getHabitById(id(habit))!.whyNoFreeze(date, now) == null) {
          ok = await habits.freeze(id(habit), date);
          ref.habits[habit]!.freeze(date);
          ref.firstFreezeOn ??= day(now);
        }
      case VacationMode(:final on):
        ok = on ? await habits.startVacation() : await habits.endVacation();
        for (final r in ref.live) {
          if (r.periodic) r.vacation(on, now);
        }
      case KeepQuote(:final habit, :final quoteId):
        ok = await habits.addQuote(id(habit), quoteId);
      case AddMyQuote(:final text, :final author):
        myQuote = (await quotes.addMine(text: text, author: author))?.id;
        ok = myQuote != null;
      case KeepMyQuote(:final habit):
        ok = await habits.addQuote(id(habit), myQuote!);
      case DeleteMyQuote():
        // As the quote sheet does: deleted, then taken off the habits that kept it
        ok = await quotes.deleteMine(myQuote!);
        for (final h in habits.habits.where((h) => h.quoteIds.contains(myQuote)).toList()) {
          ok = await habits.removeQuote(h.id, myQuote!) && ok;
        }
        if (shuffled?.id == myQuote) shuffled = null;
      case AnotherQuote():
        final before = quotes.today(settings.quoteFamilies, now: now);
        ok = await quotes.another(settings.quoteFamilies, now: now);
        final after = quotes.today(settings.quoteFamilies, now: now);
        if (after == null || after.id == before?.id) problem(now, '"Another quote" showed the same quote again');
        if (after != null) shuffled = (day: day(now), id: after.id);
        shuffles++;
      case ChangeSetting(:final setting):
        switch (setting) {
          // Then resynced, as the Settings screen does
          case QuietHoursSetting(:final quiet):
            await settings.setQuietHours(quiet);
            await habits.resyncStreakWarnings();
          case WarningLeadSetting(:final lead):
            await settings.setStreakWarningLeadTime(lead);
            await habits.resyncStreakWarnings();
          case WeekStartSetting(:final weekday):
            await settings.setWeekStart(weekday);
          case DayStartSetting(:final time):
            await settings.setDayStart(time);
          case InspireTabSetting(:final show):
            await settings.setShowInspireTab(show);
          case QuoteSourceSetting(:final family, :final on):
            await settings.setQuoteFamily(family, on);
        }
    }
    if (!ok) problem(now, '"$action" failed: ${habits.error ?? quotes.error}');
  }

}
