import 'package:equatable/equatable.dart';

/// The sounds a notification can make: iOS's own, one of the app's tones
/// (in the iOS bundle and Android res/raw as `<name>.wav`), or none.
enum NotifySound {
  system,
  chime,
  ding,
  soft,
  silent;

  /// The bundled file, or null for iOS's own sound or silence.
  String? get fileName => switch (this) {
        chime || ding || soft => '$name.wav',
        _ => null,
      };

  String get label => switch (this) {
        system => 'iOS default',
        chime => 'Chime',
        ding => 'Ding',
        soft => 'Soft',
        silent => 'Silent',
      };

  static NotifySound? fromJson(dynamic value) => NotifySound.values.where((s) => s.name == value).firstOrNull;
}

/// How one habit's notifications arrive.
class HabitNotify extends Equatable {
  /// Null: the default sound from Settings.
  final NotifySound? sound;

  /// Breaks through Focus (iOS "Time Sensitive"), if Settings allows it.
  final bool timeSensitive;

  /// "Don't miss twice" warnings for this habit (build habits only).
  final bool streakWarnings;

  const HabitNotify({this.sound, this.timeSensitive = false, this.streakWarnings = true});

  static const standard = HabitNotify();

  bool get isStandard => this == standard;

  HabitNotify copyWith({NotifySound? sound, bool clearSound = false, bool? timeSensitive, bool? streakWarnings}) =>
      HabitNotify(
        sound: clearSound ? null : (sound ?? this.sound),
        timeSensitive: timeSensitive ?? this.timeSensitive,
        streakWarnings: streakWarnings ?? this.streakWarnings,
      );

  Map<String, dynamic> toJson() => {
        if (sound != null) 'sound': sound!.name,
        if (timeSensitive) 'timeSensitive': true,
        if (!streakWarnings) 'streakWarnings': false,
      };

  factory HabitNotify.fromJson(dynamic json) {
    if (json is! Map) return standard;
    return HabitNotify(
      sound: NotifySound.fromJson(json['sound']),
      timeSensitive: json['timeSensitive'] == true,
      streakWarnings: json['streakWarnings'] != false,
    );
  }

  @override
  List<Object?> get props => [sound, timeSensitive, streakWarnings];
}
