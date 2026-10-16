import 'dart:ui' show Locale;
import 'package:intl/date_symbol_data_local.dart';

/// The day a week starts on in [locale]'s region (DateTime.monday..sunday),
/// from the CLDR data bundled with intl: Sunday in the US, Monday in most of
/// Europe, Saturday in much of the Middle East. Falls back to the language
/// (e.g. "en"), then to Monday (ISO 8601).
int regionalFirstDayOfWeek(Locale locale) {
  final symbols = dateTimeSymbolMap();
  final candidates = [
    if (locale.countryCode != null && locale.countryCode!.isNotEmpty)
      '${locale.languageCode}_${locale.countryCode}',
    locale.languageCode,
  ];
  for (final tag in candidates) {
    final data = symbols[tag];
    // intl numbers days 0 = Monday ... 6 = Sunday
    if (data != null) return data.FIRSTDAYOFWEEK + 1;
  }
  return DateTime.monday;
}

/// The seven weekdays (DateTime.monday..sunday) in display order, starting
/// with [firstDay].
List<int> weekdaysStartingOn(int firstDay) =>
    [for (var i = 0; i < 7; i++) (firstDay - 1 + i) % 7 + 1];
