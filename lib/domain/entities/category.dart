import 'package:equatable/equatable.dart';

/// Ids of the categories every install starts with. They match the names
/// habits were stored with before categories became editable, so existing
/// data keeps pointing at the right category.
class BuiltInCategoryIds {
  const BuiltInCategoryIds._();

  static const body = 'body';
  static const spirit = 'spirit';
  static const mind = 'mind';
  static const social = 'social';
  static const career = 'career';
  static const creative = 'creative';

  static const all = [body, spirit, mind, social, career, creative];
}

/// A user-editable grouping for habits.
///
/// A category deleted by the user is kept (with [deletedAt] set) so it can be
/// restored; its habits keep their [id] and show as [uncategorized] meanwhile.
class Category extends Equatable {
  static const maxCount = 24;
  static const maxNameLength = 20;

  /// Never stored on a category: stands in for deleted or unknown ids.
  static const uncategorizedId = '_uncategorized';
  static const _fallbackColor = 0xFF8E8E93; // iOS system grey

  final String id;
  final String name;

  /// Key into the icon library (presentation layer).
  final String iconKey;
  final int colorValue;
  final int sortOrder;
  final DateTime? deletedAt;

  /// One of the defaults seeded on first launch; otherwise it's like any other.
  final bool builtIn;

  const Category({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorValue,
    required this.sortOrder,
    this.deletedAt,
    this.builtIn = false,
  });

  static const uncategorized = Category(
    id: uncategorizedId,
    name: 'Uncategorized',
    iconKey: 'tag',
    colorValue: _fallbackColor,
    sortOrder: 1 << 30,
  );

  static const defaults = [
    Category(id: BuiltInCategoryIds.body, name: 'Body', iconKey: 'heart',
        colorValue: 0xFF2196F3, sortOrder: 0, builtIn: true),
    Category(id: BuiltInCategoryIds.spirit, name: 'Spirit', iconKey: 'leaf',
        colorValue: 0xFF9C27B0, sortOrder: 1, builtIn: true),
    Category(id: BuiltInCategoryIds.mind, name: 'Mind', iconKey: 'book',
        colorValue: 0xFF00BCD4, sortOrder: 2, builtIn: true),
    Category(id: BuiltInCategoryIds.social, name: 'Social', iconKey: 'people',
        colorValue: 0xFF4CAF50, sortOrder: 3, builtIn: true),
    Category(id: BuiltInCategoryIds.career, name: 'Career', iconKey: 'briefcase',
        colorValue: 0xFFFF9800, sortOrder: 4, builtIn: true),
    Category(id: BuiltInCategoryIds.creative, name: 'Creative', iconKey: 'paintbrush',
        colorValue: 0xFFE91E63, sortOrder: 5, builtIn: true),
  ];

  bool get isDeleted => deletedAt != null;

  Category copyWith({String? name, String? iconKey, int? colorValue, int? sortOrder}) {
    return Category(
      id: id,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      colorValue: colorValue ?? this.colorValue,
      sortOrder: sortOrder ?? this.sortOrder,
      deletedAt: deletedAt,
      builtIn: builtIn,
    );
  }

  Category markDeleted(DateTime at) => _withDeletedAt(at);

  /// Back from Recently Deleted (copyWith can't clear [deletedAt]).
  Category restored({required int sortOrder, String? name}) =>
      _withDeletedAt(null, sortOrder: sortOrder, name: name);

  Category _withDeletedAt(DateTime? at, {int? sortOrder, String? name}) {
    return Category(
      id: id,
      name: name ?? this.name,
      iconKey: iconKey,
      colorValue: colorValue,
      sortOrder: sortOrder ?? this.sortOrder,
      deletedAt: at,
      builtIn: builtIn,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': iconKey,
        'color': colorValue,
        'sortOrder': sortOrder,
        'builtIn': builtIn,
        if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
      };

  /// Lenient about everything except a usable id and name: a bad color,
  /// order or date falls back to a default rather than losing the category.
  /// Unknown icon keys are kept so an icon from a newer version survives.
  factory Category.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! String || id.isEmpty || name is! String || name.trim().isEmpty) {
      throw FormatException('Category needs a non-empty id and name: $json');
    }
    final icon = json['icon'];
    final color = json['color'];
    final sortOrder = json['sortOrder'];
    final deletedAt = json['deletedAt'];

    return Category(
      id: id,
      name: name,
      iconKey: icon is String && icon.isNotEmpty ? icon : 'tag',
      colorValue: color is int ? color : _fallbackColor,
      sortOrder: sortOrder is int ? sortOrder : 0,
      deletedAt: deletedAt is String ? DateTime.tryParse(deletedAt) : null,
      builtIn: json['builtIn'] == true,
    );
  }

  @override
  List<Object?> get props => [id, name, iconKey, colorValue, sortOrder, deletedAt, builtIn];

  @override
  String toString() => 'Category($id, $name${isDeleted ? ', deleted' : ''})';
}
