import 'package:equatable/equatable.dart';

class HabitMetadata extends Equatable {
  final DateTime createdDate;
  final DateTime lastModifiedDate;
  final int version;
  final String? icon;
  final Map<String, dynamic> customFields;

  const HabitMetadata({
    required this.createdDate,
    required this.lastModifiedDate,
    required this.version,
    this.icon,
    required this.customFields,
  });

  factory HabitMetadata.create({
    String? icon,
    Map<String, dynamic>? customFields,
  }) {
    final now = DateTime.now();
    return HabitMetadata(
      createdDate: now,
      lastModifiedDate: now,
      version: 1,
      icon: icon,
      customFields: customFields ?? {},
    );
  }

  HabitMetadata updateModifiedDate() {
    return copyWith(lastModifiedDate: DateTime.now());
  }

  HabitMetadata incrementVersion() {
    return copyWith(
      version: version + 1,
      lastModifiedDate: DateTime.now(),
    );
  }

  HabitMetadata copyWith({
    DateTime? createdDate,
    DateTime? lastModifiedDate,
    int? version,
    String? icon,
    Map<String, dynamic>? customFields,
  }) {
    return HabitMetadata(
      createdDate: createdDate ?? this.createdDate,
      lastModifiedDate: lastModifiedDate ?? this.lastModifiedDate,
      version: version ?? this.version,
      icon: icon ?? this.icon,
      customFields: customFields ?? this.customFields,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'createdDate': createdDate.toIso8601String(),
      'lastModifiedDate': lastModifiedDate.toIso8601String(),
      'version': version,
      'icon': icon,
      'customFields': customFields,
    };
  }

  factory HabitMetadata.fromJson(Map<String, dynamic> json) {
    return HabitMetadata(
      createdDate: DateTime.parse(json['createdDate'] as String),
      lastModifiedDate: DateTime.parse(json['lastModifiedDate'] as String),
      version: json['version'] as int,
      icon: json['icon'] as String?,
      customFields: Map<String, dynamic>.from(json['customFields'] as Map),
    );
  }

  @override
  List<Object?> get props => [
        createdDate,
        lastModifiedDate,
        version,
        icon,
        customFields,
      ];

  @override
  String toString() => 'HabitMetadata(version: $version, icon: $icon)';
}