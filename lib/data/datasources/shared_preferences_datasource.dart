import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_habit_datasource.dart';
import '../models/habit_model.dart';
import '../../core/exceptions/storage_exceptions.dart';
import '../../core/logging/log.dart';

/// Habits as one JSON list in SharedPreferences.
///
/// What's stored is decoded once and kept, with each habit's JSON: a save
/// serializes only the habits it changes and writes the list in one go, so
/// a tap doesn't decode and re-encode a year of every habit's history. If
/// something else writes the key (a backup being restored), it's read again.
class SharedPreferencesDataSource implements LocalHabitDataSource {
  final SharedPreferences _prefs;

  static const String _habitsKey = 'atomic_momentum_habits_v2';

  /// Where habits are kept (for the developer tools that back them up).
  static const habitsKey = _habitsKey;

  SharedPreferencesDataSource(this._prefs);

  /// The stored string these were read from (or last written).
  String? _readFrom;
  List<HabitModel> _models = const [];
  Map<String, Map<String, dynamic>> _json = const {};

  /// How many times the stored list has been decoded (for tests).
  int decodes = 0;

  List<HabitModel> _load() {
    final stored = _prefs.getString(_habitsKey);
    if (stored == null || stored.isEmpty) {
      _readFrom = stored;
      _models = const [];
      _json = const {};
      return _models;
    }
    if (identical(stored, _readFrom) || stored == _readFrom) return _models;
    decodes++;
    final list = jsonDecode(stored) as List<dynamic>;
    final models = <HabitModel>[];
    final json = <String, Map<String, dynamic>>{};
    for (final item in list) {
      final map = item as Map<String, dynamic>;
      final model = HabitModel.fromJson(map);
      models.add(model);
      json[model.id] = map;
    }
    _readFrom = stored;
    _models = models;
    _json = json;
    return models;
  }

  @override
  Future<List<HabitModel>> getHabits() async {
    try {
      // Validity depends on the clock (nothing dated well in the future)
      return _load().where((habit) => habit.isValid()).toList();
    } catch (e) {
      throw StorageException('Failed to load habits: $e');
    }
  }

  @override
  Future<void> saveHabit(HabitModel habit) => saveHabits([habit]);

  @override
  Future<void> saveHabits(List<HabitModel> changed) async {
    if (changed.isEmpty) return;
    try {
      final models = List.of(_load().where((habit) => habit.isValid()));
      final json = Map.of(_json);
      for (final habit in changed) {
        final index = models.indexWhere((h) => h.id == habit.id);
        if (index >= 0) {
          models[index] = habit;
        } else {
          models.add(habit);
        }
        json[habit.id] = habit.toCompactJson();
      }
      await _saveAll(models, json);
    } catch (e) {
      throw StorageException('Failed to save habit: $e');
    }
  }

  /// Writes the whole list, dropping (and logging) any invalid habit.
  Future<void> _saveAll(List<HabitModel> habits, Map<String, Map<String, dynamic>> json) async {
    try {
      final validHabits = habits.where((habit) => habit.isValid()).toList();

      if (validHabits.length != habits.length) {
        final invalidCount = habits.length - validHabits.length;
        logWarning('Warning: Filtered out $invalidCount invalid habits during save');
      }

      final habitsJson = jsonEncode([
        for (final habit in validHabits) json[habit.id] ?? habit.toCompactJson(),
      ]);

      final success = await _prefs.setString(_habitsKey, habitsJson);
      if (!success) {
        throw StorageException('Failed to write habits to storage');
      }
      _readFrom = habitsJson;
      _models = validHabits;
      _json = {for (final habit in validHabits) habit.id: json[habit.id] ?? habit.toCompactJson()};
    } catch (e) {
      throw StorageException('Failed to save habits: $e');
    }
  }

  @override
  Future<void> deleteHabit(String id) async {
    try {
      final habits = await getHabits();
      final filteredHabits = habits.where((habit) => habit.id != id).toList();

      if (filteredHabits.length == habits.length) {
        throw StorageException('Habit with ID $id not found');
      }

      await _saveAll(filteredHabits, _json);
    } catch (e) {
      throw StorageException('Failed to delete habit: $e');
    }
  }
}
