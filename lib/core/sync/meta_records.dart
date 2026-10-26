import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/category_repository_impl.dart';
import '../../data/repositories/quote_repository_impl.dart';
import '../../domain/sync/hlc.dart';
import '../../domain/sync/sync_merge.dart';
import '../../domain/sync/sync_records.dart';
import '../services/achievement_store.dart';
import '../services/freeze_bank.dart';
import '../services/habit_order.dart';

/// What changed when merged records were written back, so the app can
/// reload just those parts.
enum MetaArea { categories, quotes, order, settings, theme, achievements, bank }

/// Everything synced that isn't a habit, as records: categories, own and
/// saved quotes, the habit order, settings, appearance, achievements
/// celebrated and the freeze bank. Read from and written to the same prefs
/// keys the app already uses, compared with what was last synced.
class MetaRecords {
  const MetaRecords._();

  /// Settings in groups that change together (hour and minute, quiet
  /// hours' switch and times), by the prefs keys each holds.
  static const settingGroups = {
    'streakWarnings': ['streakWarningEnabled', 'streakWarningLeadHours', 'streakWarningRemindFirstMiss'],
    'weekStart': ['weekStartDay'],
    'reminderTime': ['defaultReminderHour', 'defaultReminderMinute'],
    'dayStart': ['dayStartHour', 'dayStartMinute'],
    'addHabitStyle': ['addHabitStyle'],
    'notifySound': ['notifySound'],
    'quietHours': ['quietHoursEnabled', 'quietHoursStart', 'quietHoursEnd'],
    'showInspireTab': ['showInspireTab'],
    'playIntro': ['playIntro'],
    'quoteFamiliesOff': ['quoteFamiliesOff'],
    'vacationNotices': ['vacationNotices'],
    'weeklyReview': ['weeklyReview', 'weeklyReviewHour', 'weeklyReviewMinute'],
  };

  /// Settings that stay on each device: greetings seen are rewritten on
  /// every launch, time-sensitive alerts follow this phone's permission,
  /// and health cards dismissed are a set ([dismissedSet]).
  static const localSettings = ['greetingsSeen', 'allowTimeSensitive', 'healthCardDismissed'];

  static const themeKeys = ['themeMode', 'dayTheme'];

  static const seenSet = 'seen';
  static const creditedSet = 'credited';
  static const dismissedSet = 'dismissed';

  /// The bank's balance from before sync that its events don't explain,
  /// set once, by the first device to join.
  static final bankAdjust = SyncKeys.other('bank.adjust');
  static final firstSpent = SyncKeys.earliest('bank.firstSpent');
  static final fundReached = SyncKeys.earliest('bank.fund');

  static String _category(String id) => SyncKeys.other('cat/$id');
  static String _quote(String id) => SyncKeys.other('quote/$id');
  static String _saved(String id) => SyncKeys.other('saved/$id');
  static final _order = SyncKeys.other('order');
  static final _grouped = SyncKeys.other('grouped');
  static String _setting(String group) => SyncKeys.other('s/$group');
  static final _theme = SyncKeys.other('theme');

  /// Everything synced that isn't a habit, as it stands in [prefs], by key.
  static Map<String, Object?> read(SharedPreferences prefs) {
    final view = <String, Object?>{};
    for (final category in _list(prefs.getString(CategoryRepositoryImpl.storageKey))) {
      if (category is Map && category['id'] is String) view[_category(category['id'] as String)] = category;
    }
    for (final quote in _list(prefs.getString(QuoteRepositoryImpl.mineKey))) {
      if (quote is Map && quote['id'] is String) view[_quote(quote['id'] as String)] = quote;
    }
    for (final id in prefs.getStringList(QuoteRepositoryImpl.savedKey) ?? const <String>[]) {
      view[_saved(id)] = true;
    }
    final order = prefs.getStringList(HabitOrder.orderKey);
    if (order != null) view[_order] = order;
    final grouped = prefs.getBool(HabitOrder.groupKey);
    if (grouped != null) view[_grouped] = grouped;
    for (final group in settingGroups.entries) {
      final values = {
        for (final key in group.value)
          if (prefs.get(key) != null) key: prefs.get(key),
      };
      if (values.isNotEmpty) view[_setting(group.key)] = values;
    }
    final theme = {
      for (final key in themeKeys)
        if (prefs.get(key) != null) key: prefs.get(key),
    };
    if (theme.isNotEmpty) view[_theme] = theme;
    for (final id in prefs.getStringList(AchievementStore.key) ?? const <String>[]) {
      view[SyncKeys.element(seenSet, id)] = true;
    }
    for (final id in prefs.getStringList('healthCardDismissed') ?? const <String>[]) {
      view[SyncKeys.element(dismissedSet, id)] = true;
    }
    final bank = _map(prefs.getString(FreezeBank.key));
    for (final id in bank['credited'] as List? ?? const []) {
      if (id is String) view[SyncKeys.element(creditedSet, id)] = true;
    }
    if (bank['firstSpentOn'] is String) view[firstSpent] = bank['firstSpentOn'];
    if (bank['fundReachedOn'] is String) view[fundReached] = bank['fundReachedOn'];
    return view;
  }

  /// Records for what changed from [base] (what was last synced) to [now].
  /// Members of sets are only ever added.
  static Records changes(Map<String, Object?> base, Map<String, Object?> now, Hlc Function() stamp) {
    final records = <String, Stamped>{};
    for (final entry in now.entries) {
      if (base.containsKey(entry.key) && jsonEquals(base[entry.key], entry.value)) continue;
      records[entry.key] = Stamped(entry.value, stamp());
    }
    for (final key in base.keys) {
      if (now.containsKey(key) || SyncKeys.ruleOf(key) != MergeRule.latest) continue;
      records[key] = Stamped(null, stamp());
    }
    return records;
  }

  /// What [merged] says for everything that isn't a habit, by key, in the
  /// same shape as [read] (a value of null: removed).
  static Map<String, Object?> viewOf(MergedState merged) {
    final view = <String, Object?>{};
    for (final entry in merged.values.entries) {
      view[entry.key] = entry.value.value;
    }
    for (final set in merged.sets.entries) {
      for (final item in set.value.keys) {
        view[SyncKeys.element(set.key, item)] = true;
      }
    }
    return view;
  }

  /// Writes [merged] (from [viewOf]) into [prefs] where it differs from
  /// [local] (from [read]). Keys no device has a record of are left alone.
  /// Returns the parts that changed.
  static Future<Set<MetaArea>> write(
    SharedPreferences prefs,
    Map<String, Object?> merged,
    Map<String, Object?> local,
  ) async {
    final changed = <MetaArea>{};
    bool differs(String key) => merged.containsKey(key) && !jsonEquals(merged[key], local[key]);
    Iterable<String> keysUnder(String prefix) =>
        {...merged.keys, ...local.keys}.where((k) => k.startsWith(prefix));

    // Categories, in their order
    final categoryKeys = keysUnder(SyncKeys.other('cat/'));
    if (categoryKeys.any(differs)) {
      final list = [
        for (final key in categoryKeys)
          if ((merged.containsKey(key) ? merged[key] : local[key]) case final Map<String, dynamic> category) category,
      ]..sort((a, b) => ((a['sortOrder'] as num?) ?? 0).compareTo((b['sortOrder'] as num?) ?? 0));
      await prefs.setString(CategoryRepositoryImpl.storageKey, jsonEncode(list));
      changed.add(MetaArea.categories);
    }

    // Own quotes, then saved ones (kept in the order they were saved here)
    final quoteKeys = keysUnder(SyncKeys.other('quote/'));
    if (quoteKeys.any(differs)) {
      final current = _list(prefs.getString(QuoteRepositoryImpl.mineKey));
      final ids = [
        for (final q in current)
          if (q is Map && q['id'] is String) q['id'] as String,
      ];
      for (final key in quoteKeys) {
        final id = key.substring(SyncKeys.other('quote/').length);
        if (!ids.contains(id)) ids.add(id);
      }
      final list = [
        for (final id in ids)
          if ((merged.containsKey(_quote(id)) ? merged[_quote(id)] : local[_quote(id)]) case final Map<String, dynamic> q)
            q,
      ];
      await prefs.setString(QuoteRepositoryImpl.mineKey, jsonEncode(list));
      changed.add(MetaArea.quotes);
    }
    final savedKeys = keysUnder(SyncKeys.other('saved/'));
    if (savedKeys.any(differs)) {
      final prefix = SyncKeys.other('saved/').length;
      bool isSaved(String key) => (merged.containsKey(key) ? merged[key] : local[key]) == true;
      final current = prefs.getStringList(QuoteRepositoryImpl.savedKey) ?? const <String>[];
      final ids = [
        for (final id in current)
          if (isSaved(_saved(id))) id,
        for (final key in savedKeys.toList()..sort())
          if (isSaved(key) && !current.contains(key.substring(prefix))) key.substring(prefix),
      ];
      await prefs.setStringList(QuoteRepositoryImpl.savedKey, ids);
      changed.add(MetaArea.quotes);
    }

    if (differs(_order) || differs(_grouped)) {
      final order = merged[_order];
      if (order is List) await prefs.setStringList(HabitOrder.orderKey, order.cast<String>());
      final grouped = merged[_grouped];
      if (grouped is bool) await prefs.setBool(HabitOrder.groupKey, grouped);
      changed.add(MetaArea.order);
    }

    for (final group in settingGroups.entries) {
      final key = _setting(group.key);
      if (!differs(key)) continue;
      final values = merged[key] is Map ? merged[key] as Map : const {};
      for (final pref in group.value) {
        await _put(prefs, pref, values[pref]);
      }
      changed.add(MetaArea.settings);
    }
    if (differs(_theme)) {
      final values = merged[_theme] is Map ? merged[_theme] as Map : const {};
      for (final pref in themeKeys) {
        await _put(prefs, pref, values[pref]);
      }
      changed.add(MetaArea.theme);
    }

    Set<String> members(String set) => {
          for (final key in {...merged.keys, ...local.keys})
            if (key.startsWith(SyncKeys.element(set, ''))) key.substring(SyncKeys.element(set, '').length),
        };
    final seen = members(seenSet);
    if (!seen.every((id) => local.containsKey(SyncKeys.element(seenSet, id)))) {
      await prefs.setStringList(AchievementStore.key, seen.toList()..sort());
      changed.add(MetaArea.achievements);
    }
    final dismissed = members(dismissedSet);
    if (!dismissed.every((id) => local.containsKey(SyncKeys.element(dismissedSet, id)))) {
      await prefs.setStringList('healthCardDismissed', dismissed.toList()..sort());
      changed.add(MetaArea.settings);
    }
    return changed;
  }

  /// Writes the freeze bank as merged: [available] from the replay, the
  /// milestones credited on any device, and its first days.
  static Future<bool> writeBank(SharedPreferences prefs, Map<String, Object?> merged, int available) async {
    final bank = _map(prefs.getString(FreezeBank.key));
    final prefix = SyncKeys.element(creditedSet, '');
    final credited = {
      for (final c in bank['credited'] as List? ?? const []) c,
      for (final key in merged.keys)
        if (key.startsWith(prefix)) key.substring(prefix.length),
    }.toList()
      ..sort();
    final next = {
      ...bank,
      'available': available,
      'credited': credited,
      'started': true,
      if (merged[firstSpent] is String) 'firstSpentOn': merged[firstSpent],
      if (merged[fundReached] is String) 'fundReachedOn': merged[fundReached],
    };
    if (jsonEquals(next, bank)) return false;
    await prefs.setString(FreezeBank.key, jsonEncode(next));
    return true;
  }

  /// The bank's balance stored on this device.
  static int localBankBalance(SharedPreferences prefs) =>
      (_map(prefs.getString(FreezeBank.key))['available'] as num?)?.toInt() ?? FreezeBank.start;

  static Future<void> _put(SharedPreferences prefs, String key, Object? value) async {
    switch (value) {
      case null:
        await prefs.remove(key);
      case bool b:
        await prefs.setBool(key, b);
      case int i:
        await prefs.setInt(key, i);
      case double d:
        await prefs.setDouble(key, d);
      case String s:
        await prefs.setString(key, s);
      case List l:
        await prefs.setStringList(key, l.cast<String>());
    }
  }

  static List<dynamic> _list(String? raw) {
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : const [];
    } catch (_) {
      return const [];
    }
  }

  static Map<String, dynamic> _map(String? raw) {
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }
}
