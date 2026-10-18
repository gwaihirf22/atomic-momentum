import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/health_source.dart';
import 'package:atomic_momentum/domain/entities/health_link.dart';

/// A scripted health store: [values] per metric and day, and a record of
/// what was asked, logged and removed.
class FakeHealthSource implements HealthSource {
  final values = <HealthMetric, Map<DateTime, int>>{};
  HealthAvailability available = HealthAvailability.available;
  final accessRequests = <Set<HealthMetric>>[];
  final logged = <HealthRecord>[];
  final removed = <HealthRecord>[];
  int reads = 0;

  @override
  bool isAndroid = false;

  @override
  String get name => isAndroid ? 'Health Connect' : 'Apple Health';

  @override
  Future<HealthAvailability> availability() async => available;

  @override
  Future<bool> requestAccess({required Set<HealthMetric> read, Set<HealthMetric> write = const {}}) async {
    accessRequests.add(read);
    return true;
  }

  @override
  Future<void> installHealthConnect() async {}

  @override
  Future<Map<DateTime, int>> dailyValues(HealthMetric metric, DateTime from, DateTime to) async {
    reads++;
    final days = values[metric] ?? const {};
    return {
      for (final e in days.entries)
        if (!e.key.isBefore(DateTime(from.year, from.month, from.day)) && !e.key.isAfter(to)) e.key: e.value,
    };
  }

  @override
  Future<HealthRecord?> log(HealthMetric metric, double baseAmount, DateTime at) async {
    final amount = baseAmount.round();
    final record = (metric: metric, start: at.subtract(Duration(seconds: amount)), end: at);
    logged.add(record);
    final day = DateTime(at.year, at.month, at.day);
    final days = values.putIfAbsent(metric, () => {});
    days[day] = (days[day] ?? 0) + amount;
    return record;
  }

  int samplesAdded = 0;

  @override
  Future<bool> addSampleData() async {
    samplesAdded++;
    return true;
  }

  @override
  Future<bool> remove(HealthRecord record) async {
    removed.add(record);
    // The fake's records last one second per unit logged
    final amount = record.end.difference(record.start).inSeconds;
    final day = DateTime(record.end.year, record.end.month, record.end.day);
    final days = values.putIfAbsent(record.metric, () => {});
    days[day] = (days[day] ?? 0) - amount;
    return true;
  }

  /// Puts the fake in place of the real store (after initializeDependencies).
  static FakeHealthSource install() {
    final fake = FakeHealthSource();
    if (sl.isRegistered<HealthSource>()) sl.unregister<HealthSource>();
    sl.registerSingleton<HealthSource>(fake);
    return fake;
  }
}
