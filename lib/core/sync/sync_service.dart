import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/habit.dart';
import '../../domain/sync/freeze_replay.dart';
import '../../domain/sync/habit_change_listener.dart';
import '../../domain/sync/hlc.dart';
import '../../domain/sync/sync_merge.dart';
import '../../domain/sync/sync_records.dart';
import '../../presentation/providers/category_provider.dart';
import '../../presentation/providers/habit_provider.dart';
import '../../presentation/providers/quote_provider.dart';
import '../../presentation/providers/settings_provider.dart';
import '../../presentation/providers/theme_provider.dart';
import '../dev/year_of_use.dart';
import '../logging/log.dart';
import '../services/freeze_bank.dart';
import 'cloud_transport.dart';
import 'habit_records.dart';
import 'meta_records.dart';
import 'sync_store.dart';

/// Where sync stands, for Settings.
enum SyncState {
  off,
  syncing,
  synced,

  /// No connection: changes wait and go when there is one.
  offline,

  /// Not signed in to iCloud (or Google) on this device.
  noAccount,

  /// iCloud (or Drive) is full.
  full,

  /// The account changed, or another device deleted the copy in the cloud:
  /// sync stopped, to be turned on again.
  stopped,

  /// Another device has a newer version of the app.
  needsUpdate,

  /// Developer → "Load a year of use" is on: sync waits until it's put back.
  paused,

  /// This build can't sync.
  unavailable,

  failed,
}

/// Sync between this person's devices (Momentum Plus): records each change
/// as it's made, exchanges records through a [CloudTransport], merges every
/// device's, and brings the result in through the providers. See
/// docs/design/sync.md.
class SyncService extends ChangeNotifier with WidgetsBindingObserver implements HabitChangeListener {
  final SharedPreferences _prefs;
  final CloudTransport transport;

  /// How long after a change sync waits, so a run of taps goes together.
  final Duration delay;

  SyncService({required SharedPreferences prefs, required this.transport, this.delay = const Duration(seconds: 3)})
      : _prefs = prefs,
        _store = SyncStore(prefs);

  final SyncStore _store;
  HlcClock? _clock;
  MergedState _merged = SyncMerge.merge(const {});

  HabitProvider? _habits;
  SettingsProvider? _settings;
  ThemeProvider? _theme;
  CategoryProvider? _categories;
  QuoteProvider? _quotes;
  FreezeBank? _bank;
  StreamSubscription<void>? _wakes;

  SyncState _state = SyncState.off;
  SyncState get state => _state;

  bool get isOn => _store.isOn;

  /// When everything last went through.
  DateTime? get lastSynced => _store.lastSynced;

  /// This device's id while sync is on.
  String? get device => _store.device;

  /// Connects sync to the app (the providers the app shows), and starts it
  /// if it's on.
  void attach({
    required HabitProvider habits,
    SettingsProvider? settings,
    ThemeProvider? theme,
    CategoryProvider? categories,
    QuoteProvider? quotes,
    FreezeBank? bank,
  }) {
    _detach();
    _habits = habits;
    _settings = settings;
    _theme = theme;
    _categories = categories;
    _quotes = quotes;
    _bank = bank;
    if (isOn) _listen();
  }

  void _listen() {
    final device = _store.device;
    if (device == null || _habits == null) return;
    _clock = HlcClock(device, last: _store.clock);
    _merged = SyncMerge.merge(_replicas());
    _habits!.syncListener = this;
    for (final source in _metaSources) {
      source.addListener(_schedule);
    }
    _wakes = transport.wakes.listen((_) => _schedule());
    WidgetsBinding.instance.addObserver(this);
    _state = SyncState.syncing;
    notifyListeners();
    _schedule(now: true);
  }

  List<Listenable> get _metaSources => [_settings, _theme, _categories, _quotes, _bank].whereType<Listenable>().toList();

  void _detach() {
    if (_habits?.syncListener == this) _habits!.syncListener = null;
    for (final source in _metaSources) {
      source.removeListener(_schedule);
    }
    _wakes?.cancel();
    _wakes = null;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule(now: true);
    if (state == AppLifecycleState.paused) unawaited(_store.save());
  }

  Map<String, Records> _replicas() => {
        ..._store.others,
        if (_store.device != null) _store.device!: _store.own,
      };

  /// Can this device sync at all (signed in, a build with iCloud)?
  Future<CloudAvailability> availability() async {
    try {
      return await transport.availability();
    } catch (e) {
      logWarning('Sync: availability failed: $e');
      return CloudAvailability.unavailable;
    }
  }

  // Recording ------------------------------------------------------------

  @override
  void habitChanged(Habit? before, Habit? after) {
    final clock = _clock;
    final device = _store.device;
    if (clock == null || device == null || !isOn) return;
    final id = (after ?? before)!.id;
    _recordOwn(HabitRecords.changes(
      before: before,
      after: after,
      merged: _merged.habits[id],
      device: device,
      stamp: clock.tick,
    ));
    _schedule();
  }

  void _recordOwn(Records records) {
    final device = _store.device;
    if (records.isEmpty || device == null) return;
    _store.own.addAll(records);
    _merged.add(device, records);
    for (final key in records.keys) {
      _store.dirty.add(SyncBuckets.nameFor(device, key));
    }
  }

  // Running --------------------------------------------------------------

  Timer? _timer;
  bool _running = false;

  /// Just joined: what came from the cloud hasn't been brought in yet.
  bool _joined = false;
  bool _again = false;

  void _schedule({bool now = false}) {
    if (!isOn) return;
    _timer?.cancel();
    _timer = Timer(now ? Duration.zero : delay, () => unawaited(syncNow()));
  }

  /// Pushes this device's changes, takes in the others', and brings them
  /// into the app. One run at a time; asked again while running, it runs
  /// once more after.
  Future<void> syncNow() async {
    if (!isOn || _habits == null || _clock == null) return;
    if (_running) {
      _again = true;
      return;
    }
    if (YearOfUse.hasBackup(_prefs)) {
      _setState(SyncState.paused);
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        await _runOnce();
      } while (_again && isOn);
    } finally {
      _running = false;
    }
  }

  Future<void> _runOnce() async {
    final device = _store.device!;
    _setState(SyncState.syncing);
    try {
      // What changed in settings, categories, quotes and the rest
      final view = MetaRecords.read(_prefs);
      _recordOwn(MetaRecords.changes(_store.base, view, _clock!.tick));
      _store.base = view;

      if (_store.dirty.isNotEmpty) {
        final names = Set.of(_store.dirty);
        await transport.push(SyncBuckets.encode(device, _store.own, names: names));
        _store.dirty.removeAll(names);
      }

      final pulled = await transport.pull();
      var newer = false;
      var restored = false;
      for (final entry in pulled.entries) {
        final records = SyncBuckets.decode(entry.value);
        if (records == null) {
          _setState(SyncState.needsUpdate);
          await _store.save();
          return;
        }
        final owner = SyncBuckets.deviceOf(entry.key);
        if (owner == device) {
          restored |= _isRestored(records);
          continue;
        }
        final known = _store.others[owner] ??= {};
        for (final record in records.entries) {
          final had = known[record.key];
          if (had == null || record.value.stamp > had.stamp) {
            known[record.key] = record.value;
            _clock!.receive(record.value.stamp);
            newer = true;
          }
        }
      }
      if (restored) {
        // A copy of this device restored from a backup (here or onto another
        // phone): take a new id, and join again
        logWarning('Sync: this device was restored from a backup; joining again');
        await _rejoin();
        // Straight on to bringing the cloud in, before anything is tapped
        // against this device's old copy
        _again = true;
        return;
      }
      if (newer || _joined) await _apply();
      _joined = false;
      _store.clock = _clock!.last;
      _store.lastSynced = clock.now();
      await _store.save();
      _setState(SyncState.synced);
    } on CloudException catch (e) {
      await _store.save();
      switch (e.problem) {
        case CloudProblem.offline:
          _setState(SyncState.offline);
        case CloudProblem.full:
          _setState(SyncState.full);
        case CloudProblem.accountChanged || CloudProblem.deleted:
          await _stop();
        case CloudProblem.other:
          logWarning('Sync failed: $e');
          _setState(SyncState.failed);
      }
    } catch (e) {
      logWarning('Sync failed: $e');
      await _store.save();
      _setState(SyncState.failed);
    }
  }

  /// Whether the cloud has records of this device's that it doesn't: it's
  /// a copy restored from a backup (the cloud moved on since).
  bool _isRestored(Records cloud) {
    for (final entry in cloud.entries) {
      final mine = _store.own[entry.key];
      if (mine == null || entry.value.stamp > mine.stamp) return true;
    }
    return false;
  }

  /// Brings every device's records into the app: everything that isn't a
  /// habit first (so achievements celebrated elsewhere aren't celebrated
  /// again), then the habits through [HabitProvider.applySynced].
  Future<void> _apply() async {
    _merged = SyncMerge.merge(_replicas());
    final local = MetaRecords.read(_prefs);
    final view = MetaRecords.viewOf(_merged);
    final areas = await MetaRecords.write(_prefs, view, local);
    if (await MetaRecords.writeBank(_prefs, view, _bankBalance(view))) areas.add(MetaArea.bank);
    _store.base = MetaRecords.read(_prefs);
    if (areas.contains(MetaArea.categories)) await _categories?.load();
    if (areas.contains(MetaArea.quotes)) await _quotes?.load();
    if (areas.contains(MetaArea.bank)) _bank?.reload();
    if (areas.contains(MetaArea.theme)) _theme?.reload();
    if (areas.contains(MetaArea.order)) _habits?.refreshOrder();
    if (areas.contains(MetaArea.settings)) {
      _settings?.reload();
      // Week start, quiet hours, review time: notifications are planned again
      await _habits?.resyncStreakWarnings();
    }
    await _habits?.applySynced(_habitChanges);
  }

  /// The habits that differ once merged (null: deleted on another device).
  /// Runs inside [HabitProvider.applySynced], with this device's latest
  /// changes already in [_merged].
  Map<String, Habit?> _habitChanges(Map<String, Habit> local) {
    final now = clock.now();
    final changes = <String, Habit?>{};
    for (final merged in _merged.habits.values) {
      final mine = local[merged.id];
      if (merged.isDeleted) {
        if (mine != null) changes[merged.id] = null;
        continue;
      }
      final built = HabitRecords.build(merged, local: mine, now: now);
      if (built == null) continue;
      if (mine == null || !sameHabit(mine, built)) changes[merged.id] = built;
    }
    return changes;
  }

  /// Whether two copies of a habit hold the same (what syncs).
  static bool sameHabit(Habit a, Habit b) =>
      jsonEquals(HabitRecords.fieldsOf(a), HabitRecords.fieldsOf(b)) &&
      mapEquals(a.history, b.history) &&
      setEquals(a.twoMinuteDays, b.twoMinuteDays) &&
      setEquals(a.frozenDays, b.frozenDays) &&
      mapEquals(a.dayNotes, b.dayNotes);

  /// The freeze bank, replayed from what's merged.
  int _bankBalance(Map<String, Object?> view) {
    final credits = {
      for (final entry in (_merged.sets[MetaRecords.creditedSet] ?? const <String, Stamped>{}).entries)
        entry.key: entry.value.stamp.day,
    };
    final spends = [
      for (final habit in _merged.habits.values)
        if (!habit.isDeleted)
          for (final day in habit.days.values)
            if (day.marks[SyncKeys.frozenMark] case final Stamped mark when mark.value == true) mark.stamp.day,
    ];
    return FreezeReplay.balance(
      credits: credits,
      spends: spends,
      adjust: (view[MetaRecords.bankAdjust] as num?)?.toInt() ?? 0,
      start: FreezeBank.start,
      cap: FreezeBank.cap,
    );
  }

  // Turning on and off -----------------------------------------------------

  /// Turns sync on: joins whatever is in the cloud. What's already there
  /// wins for settings; this device's habits are added, and its days only
  /// where it has more, so nothing is lowered or lost. False when this
  /// device can't sync (see [state]).
  Future<bool> turnOn() async {
    if (isOn) return true;
    final habits = _habits;
    if (habits == null) return false;
    final availability = await this.availability();
    if (availability != CloudAvailability.available) {
      _setState(switch (availability) {
        CloudAvailability.noAccount => SyncState.noAccount,
        _ => SyncState.unavailable,
      });
      return false;
    }
    _setState(SyncState.syncing);
    try {
      await _join(habits);
    } on CloudException catch (e) {
      await _store.clear();
      _setState(e.problem == CloudProblem.offline ? SyncState.offline : SyncState.failed);
      return false;
    }
    _listen();
    // What's in the cloud comes in before anything else is tapped here
    await syncNow();
    return true;
  }

  Future<void> _join(HabitProvider habits) async {
    final device = SyncStore.newDeviceId();
    await transport.resetCursor();
    final pulled = await transport.pull();
    final others = <String, Records>{};
    for (final entry in pulled.entries) {
      final records = SyncBuckets.decode(entry.value);
      if (records == null) throw const CloudException(CloudProblem.other, 'A newer version of Momentum is syncing');
      (others[SyncBuckets.deviceOf(entry.key)] ??= {}).addAll(records);
    }
    final cloud = SyncMerge.merge(others);
    final clock = HlcClock(device);
    for (final records in others.values) {
      for (final record in records.values) {
        clock.receive(record.stamp);
      }
    }

    final own = <String, Stamped>{};
    for (final habit in habits.habits) {
      final merged = cloud.habits[habit.id];
      if (merged == null) {
        own.addAll(HabitRecords.changes(before: null, after: habit, merged: null, device: device, stamp: clock.tick));
      } else if (!merged.isDeleted) {
        own.addAll(_joinDays(habit, merged, clock));
      }
    }
    final local = MetaRecords.read(_prefs);
    final cloudView = MetaRecords.viewOf(cloud);
    for (final entry in local.entries) {
      if (!cloudView.containsKey(entry.key)) own[entry.key] = Stamped(entry.value, clock.tick());
    }
    if (!cloudView.containsKey(MetaRecords.bankAdjust)) {
      // What the bank holds now that its events don't explain
      _store.own = own;
      _store.device = device;
      _store.others = others;
      _merged = SyncMerge.merge(_replicas());
      final replayed = _bankBalance(const {});
      own[MetaRecords.bankAdjust] = Stamped(MetaRecords.localBankBalance(_prefs) - replayed, clock.tick());
    }

    _store
      ..isOn = true
      ..device = device
      ..own = own
      ..others = others
      ..base = local
      ..clock = clock.last
      ..dirty = {for (final key in own.keys) SyncBuckets.nameFor(device, key)};
    await _store.save();
    _joined = true;
  }

  /// A local habit's days that the cloud's copy doesn't have, or has less
  /// of. Its settings are left to the cloud's.
  Records _joinDays(Habit habit, MergedHabit merged, HlcClock clock) {
    final records = <String, Stamped>{};
    final generation = HabitRecords.generationOf(merged);
    for (final entry in habit.history.entries) {
      final day = SyncKeys.day(entry.key);
      final cloudTotal = merged.total(day, generation);
      if (entry.value <= cloudTotal) continue;
      records[habit.health != null ? SyncKeys.dayValue(habit.id, day) : SyncKeys.count(habit.id, day, generation)] =
          Stamped(
        habit.health != null ? {'v': entry.value, 'g': generation} : entry.value - cloudTotal,
        clock.tick(),
      );
    }
    void marks(Iterable<DateTime> days, String kind, Object value) {
      for (final date in days) {
        final day = SyncKeys.day(date);
        if (merged.days[day]?.marks.containsKey(kind) == true) continue;
        records[SyncKeys.mark(habit.id, day, kind)] = Stamped(value, clock.tick());
      }
    }

    marks(habit.twoMinuteDays, SyncKeys.twoMinuteMark, true);
    marks(habit.frozenDays, SyncKeys.frozenMark, true);
    for (final note in habit.dayNotes.entries) {
      final day = SyncKeys.day(note.key);
      if (merged.days[day]?.marks.containsKey(SyncKeys.noteMark) == true) continue;
      records[SyncKeys.mark(habit.id, day, SyncKeys.noteMark)] = Stamped(note.value, clock.tick());
    }
    return records;
  }

  Future<void> _rejoin() async {
    final habits = _habits;
    _detach();
    await _store.clear();
    if (habits == null) return;
    await _join(habits);
    _listen();
  }

  /// Turns sync off. Everything stays on this device; [deleteCloud] also
  /// removes the copy in the cloud, for every device.
  Future<void> turnOff({bool deleteCloud = false}) async {
    _detach();
    await _store.clear();
    _merged = SyncMerge.merge(const {});
    _clock = null;
    if (deleteCloud) {
      try {
        await transport.deleteAll();
      } catch (e) {
        logWarning('Sync: deleting the copy in the cloud failed: $e');
      }
    }
    _setState(SyncState.off);
  }

  /// Stops (the account changed, or the copy in the cloud was deleted):
  /// off, to be turned on again by the person.
  Future<void> _stop() async {
    _detach();
    await _store.clear();
    _merged = SyncMerge.merge(const {});
    _clock = null;
    _setState(SyncState.stopped);
  }

  void _setState(SyncState state) {
    if (_state == state) return;
    _state = state;
    notifyListeners();
  }
}
