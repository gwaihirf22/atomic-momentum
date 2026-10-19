import 'package:shared_preferences/shared_preferences.dart';

/// [SharedPreferences] kept in memory only: what the tours' example world
/// stores in, so the repositories, providers, freeze bank and achievement
/// store run unchanged without ever writing the person's own storage.
class MemoryPrefs implements SharedPreferences {
  final Map<String, Object> _values;

  MemoryPrefs([Map<String, Object>? values]) : _values = {...?values};

  @override
  Set<String> getKeys() => Set<String>.from(_values.keys);

  @override
  Object? get(String key) => _values[key];

  @override
  bool? getBool(String key) => _values[key] as bool?;

  @override
  int? getInt(String key) => _values[key] as int?;

  @override
  double? getDouble(String key) => _values[key] as double?;

  @override
  String? getString(String key) => _values[key] as String?;

  @override
  bool containsKey(String key) => _values.containsKey(key);

  @override
  List<String>? getStringList(String key) => (_values[key] as List<dynamic>?)?.cast<String>().toList();

  @override
  Future<bool> setBool(String key, bool value) => _set(key, value);

  @override
  Future<bool> setInt(String key, int value) => _set(key, value);

  @override
  Future<bool> setDouble(String key, double value) => _set(key, value);

  @override
  Future<bool> setString(String key, String value) => _set(key, value);

  @override
  Future<bool> setStringList(String key, List<String> value) => _set(key, value.toList());

  @override
  Future<bool> remove(String key) async {
    _values.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    _values.clear();
    return true;
  }

  @override
  Future<bool> commit() async => true;

  @override
  Future<void> reload() async {}

  Future<bool> _set(String key, Object value) async {
    _values[key] = value;
    return true;
  }
}
