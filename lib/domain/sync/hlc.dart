import 'dart:math' as math;

import 'package:clock/clock.dart';

/// When a synced record was set, and on which device: a hybrid logical
/// clock. The wall time (ms) keeps stamps close to real time, the count
/// orders changes within the same millisecond or after a clock jumped back,
/// and the device id breaks ties, so no two devices' stamps are ever equal.
class Hlc implements Comparable<Hlc> {
  final int wall;
  final int count;
  final String device;

  const Hlc(this.wall, this.count, this.device);

  static const zero = Hlc(0, 0, '');

  @override
  int compareTo(Hlc other) {
    if (wall != other.wall) return wall.compareTo(other.wall);
    if (count != other.count) return count.compareTo(other.count);
    return device.compareTo(other.device);
  }

  bool operator >(Hlc other) => compareTo(other) > 0;
  bool operator <(Hlc other) => compareTo(other) < 0;

  /// The day it was set on, in local time.
  DateTime get day {
    final t = DateTime.fromMillisecondsSinceEpoch(wall);
    return DateTime(t.year, t.month, t.day);
  }

  String encode() => '${wall.toRadixString(36)}:${count.toRadixString(36)}:$device';

  static Hlc decode(String text) {
    final first = text.indexOf(':');
    final second = text.indexOf(':', first + 1);
    if (first < 0 || second < 0) throw FormatException('Not a stamp: $text');
    return Hlc(
      int.parse(text.substring(0, first), radix: 36),
      int.parse(text.substring(first + 1, second), radix: 36),
      text.substring(second + 1),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Hlc && other.wall == wall && other.count == count && other.device == device;

  @override
  int get hashCode => Object.hash(wall, count, device);

  @override
  String toString() => 'Hlc(${encode()})';
}

/// This device's clock: every stamp it hands out is later than every stamp
/// it has made or seen, even when the phone's clock is wrong or goes back.
class HlcClock {
  final String device;
  Hlc _last;

  HlcClock(this.device, {Hlc? last}) : _last = last == null ? Hlc.zero : Hlc(last.wall, last.count, device);

  /// The latest stamp made or seen (to keep for next time).
  Hlc get last => _last;

  /// A new stamp, for a change made now.
  Hlc tick() {
    final physical = clock.now().millisecondsSinceEpoch;
    final wall = math.max(physical, _last.wall);
    final count = wall == _last.wall ? _last.count + 1 : 0;
    return _last = Hlc(wall, count, device);
  }

  /// Takes in a stamp from another device, so this one's next is later.
  void receive(Hlc remote) {
    if (remote.wall > _last.wall || (remote.wall == _last.wall && remote.count > _last.count)) {
      _last = Hlc(remote.wall, remote.count, device);
    }
  }
}
