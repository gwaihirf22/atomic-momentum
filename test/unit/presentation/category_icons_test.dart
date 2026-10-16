import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/presentation/widgets/category_icons.dart';

void main() {
  test('the library has 40 icons under unique keys', () {
    expect(CategoryIcons.library.length, 40);
    expect(CategoryIcons.library.values.toSet().length, 40, reason: 'no duplicate icons');
  });

  test('built-in categories keep exactly their previous icons', () {
    final icons = {for (final c in Category.defaults) c.id: c.icon};
    expect(icons, {
      'body': CupertinoIcons.heart_fill,
      'spirit': CupertinoIcons.leaf_arrow_circlepath,
      'mind': CupertinoIcons.book_fill,
      'social': CupertinoIcons.person_2_fill,
      'career': CupertinoIcons.briefcase_fill,
      'creative': CupertinoIcons.paintbrush_fill,
    });
  });

  test('every default icon key is in the library', () {
    for (final c in Category.defaults) {
      expect(CategoryIcons.library.containsKey(c.iconKey), isTrue, reason: c.iconKey);
    }
  });

  test('unknown keys fall back to a tag', () {
    expect(CategoryIcons.of('nope'), CategoryIcons.fallback);
    expect(Category.uncategorized.icon, CupertinoIcons.tag_fill);
  });

  test('labels read naturally', () {
    expect(CategoryIcons.label('music_note'), 'music note');
  });
}
