import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Widget tests normally draw text in a placeholder font whose glyphs are
/// all 1em squares, far wider than real text. To check what fits on a
/// phone, this loads Roboto (bundled with the Flutter SDK) under the font
/// families iOS text uses, and the app's own Sora.
///
/// Roboto runs a few percent narrower than Apple's SF Pro, so callers
/// should scale text by [sfWidthAllowance] to stay on the safe side.
const sfWidthAllowance = 1.08;

bool _loaded = false;

Future<void> loadRealFonts() async {
  if (_loaded) return;
  _loaded = true;

  const dir = 'flutter/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String path) async => ByteData.view(Uint8List.fromList(await File(path).readAsBytes()).buffer);

  for (final family in ['CupertinoSystemText', 'CupertinoSystemDisplay', '.SF Pro Text', '.SF Pro Display', 'Roboto']) {
    final loader = FontLoader(family);
    for (final weight in ['Regular', 'Medium', 'Bold']) {
      loader.addFont(read('$dir/Roboto-$weight.ttf'));
    }
    await loader.load();
  }

  final sora = FontLoader('Sora')
    ..addFont(read('assets/fonts/Sora/Sora-SemiBold.ttf'))
    ..addFont(read('assets/fonts/Sora/Sora-Bold.ttf'));
  await sora.load();
}
