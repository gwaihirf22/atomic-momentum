import 'package:flutter/cupertino.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/habit_category.dart';

/// The flat (SF Symbols-style) icons a category can use, keyed by stable
/// strings so stored categories stay valid if Flutter's icon font changes.
/// Map order is the order shown in the icon picker.
class CategoryIcons {
  const CategoryIcons._();

  static const fallback = CupertinoIcons.tag_fill;

  static const Map<String, IconData> library = {
    // The built-in categories' icons
    'heart': CupertinoIcons.heart_fill,
    'leaf': CupertinoIcons.leaf_arrow_circlepath,
    'book': CupertinoIcons.book_fill,
    'people': CupertinoIcons.person_2_fill,
    'briefcase': CupertinoIcons.briefcase_fill,
    'paintbrush': CupertinoIcons.paintbrush_fill,
    // People and communication
    'person': CupertinoIcons.person_fill,
    'group': CupertinoIcons.person_3_fill,
    'chat': CupertinoIcons.chat_bubble_2_fill,
    'phone': CupertinoIcons.phone_fill,
    'envelope': CupertinoIcons.envelope_fill,
    // Creative and media
    'music_note': CupertinoIcons.music_note_2,
    'headphones': CupertinoIcons.headphones,
    'mic': CupertinoIcons.mic_fill,
    'camera': CupertinoIcons.camera_fill,
    'film': CupertinoIcons.film_fill,
    'pencil': CupertinoIcons.pencil,
    'doc': CupertinoIcons.doc_text_fill,
    'lightbulb': CupertinoIcons.lightbulb_fill,
    'sparkles': CupertinoIcons.sparkles,
    // Goals and energy
    'star': CupertinoIcons.star_fill,
    'flag': CupertinoIcons.flag_fill,
    'rosette': CupertinoIcons.rosette,
    'flame': CupertinoIcons.flame_fill,
    'bolt': CupertinoIcons.bolt_fill,
    'sport': CupertinoIcons.sportscourt_fill,
    'stopwatch': CupertinoIcons.stopwatch_fill,
    // Health and rest
    'moon': CupertinoIcons.moon_fill,
    'sun': CupertinoIcons.sun_max_fill,
    'bed': CupertinoIcons.bed_double_fill,
    'drop': CupertinoIcons.drop_fill,
    'capsule': CupertinoIcons.capsule_fill,
    // Home, money and work
    'house': CupertinoIcons.house_fill,
    'cart': CupertinoIcons.cart_fill,
    'money': CupertinoIcons.money_dollar_circle_fill,
    'chart': CupertinoIcons.chart_bar_fill,
    'laptop': CupertinoIcons.device_laptop,
    // Outdoors
    'airplane': CupertinoIcons.airplane,
    'tree': CupertinoIcons.tree,
    'paw': CupertinoIcons.paw,
  };

  static IconData of(String key) => library[key] ?? fallback;

  /// Spoken name for VoiceOver, e.g. "music note".
  static String label(String key) => key.replaceAll('_', ' ');
}

/// Flutter-side appearance of a category; the domain entity stays Flutter-free.
extension CategoryAppearance on Category {
  IconData get icon => CategoryIcons.of(iconKey);
  Color get color => Color(colorValue);
}

/// Transitional: the fixed categories' icons, from the same library.
extension HabitCategoryIcon on HabitCategory {
  IconData get icon => CategoryIcons.of(
      Category.defaults.firstWhere((c) => c.id == name).iconKey);
}
