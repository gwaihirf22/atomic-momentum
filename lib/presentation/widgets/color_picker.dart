import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/entities/habit_color.dart';
import 'selectable_swatch.dart';
import 'package:flutter/cupertino.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_style.dart';

/// The colors offered in the full picker: 12 hue families x 6 shades.
/// Shade 500 of each family is named like the matching predefined color
/// (e.g. "Blue"), so existing habits' colors are found in the grid.
class ColorPalette {
  const ColorPalette._();

  static const shades = [300, 400, 500, 600, 700, 800];

  static final List<({String family, List<HabitColor> colors})> families = [
    for (final (name, swatch) in <(String, MaterialColor)>[
      ('Red', Colors.red),
      ('Pink', Colors.pink),
      ('Purple', Colors.purple),
      ('Deep Purple', Colors.deepPurple),
      ('Indigo', Colors.indigo),
      ('Blue', Colors.blue),
      ('Cyan', Colors.cyan),
      ('Teal', Colors.teal),
      ('Green', Colors.green),
      ('Amber', Colors.amber),
      ('Orange', Colors.orange),
      ('Blue Grey', Colors.blueGrey),
    ])
      (
        family: name,
        colors: [
          for (final shade in shades)
            HabitColor.fromColor(swatch[shade]!, name: shade == 500 ? name : '$name $shade'),
        ],
      ),
  ];

  static List<HabitColor> get all => [for (final f in families) ...f.colors];

  /// Common starting colors, offered when there's nothing more relevant.
  static List<HabitColor> get basics => HabitColor.predefinedColors.take(8).toList();

  /// [recent] color values first (most relevant first), then [basics];
  /// duplicates removed.
  static List<HabitColor> suggestions(Iterable<int> recent) {
    final seen = <int>{};
    return [
      for (final value in recent)
        if (seen.add(value)) resolve(value),
      for (final color in basics)
        if (seen.add(color.value)) color,
    ];
  }

  /// The named palette or predefined color with this value, else a Custom one.
  static HabitColor resolve(int value) {
    for (final color in [...HabitColor.predefinedColors, ...all]) {
      if (color.value == value) return color;
    }
    return HabitColor.fromColor(Color(value));
  }
}

/// One row: the current color, as many suggestions as fit, and a rainbow
/// "More colors" swatch that opens the full picker. Always a single row of
/// 44pt swatches, whatever the screen width.
class CompactColorPicker extends StatelessWidget {
  static const double _spacing = 12;

  final int selectedValue;
  final ValueChanged<HabitColor> onChanged;
  final List<HabitColor> suggestions;

  /// Prefix for the swatches' keys (e.g. "colorSwatch_" + color name).
  final String keyPrefix;

  const CompactColorPicker({
    Key? key,
    required this.selectedValue,
    required this.onChanged,
    required this.suggestions,
    this.keyPrefix = 'colorSwatch_',
  }) : super(key: key);

  Widget _swatch(BuildContext context, HabitColor color, {required bool selected}) {
    final palette = AppPalette.of(context);
    // Shown as the current theme draws it; the stored color is unchanged
    final fill = palette.habitColor(color.color);
    return SelectableSwatch(
      key: Key('$keyPrefix${color.name}'),
      semanticLabel: '${color.name} color',
      isSelected: selected,
      onTap: () => onChanged(color),
      fill: fill,
      borderColor: selected ? palette.text : null,
      borderWidth: 3,
      child: selected ? Icon(Icons.check, color: palette.onColor(fill), size: 22) : null,
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showColorPickerSheet(context, selectedValue: selectedValue);
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const step = SelectableSwatch.size + _spacing;
      final slots = math.max(3, ((constraints.maxWidth + _spacing) / step).floor());

      final current = ColorPalette.resolve(selectedValue);
      final others = suggestions.where((c) => c.value != selectedValue).take(slots - 2);

      final children = <Widget>[
        _swatch(context, current, selected: true),
        for (final color in others) _swatch(context, color, selected: false),
        SelectableSwatch(
          key: Key('${keyPrefix}More'),
          semanticLabel: 'More colors',
          isSelected: false,
          onTap: () => _openPicker(context),
          fill: Colors.transparent,
          borderColor: null,
          borderWidth: 0,
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(colors: [
                Colors.red, Colors.orange, Colors.yellow, Colors.green,
                Colors.cyan, Colors.blue, Colors.purple, Colors.red,
              ]),
            ),
            child: Center(
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: AppPalette.of(context).surface, shape: BoxShape.circle),
                child: Icon(Icons.add, size: 16, color: AppPalette.of(context).text),
              ),
            ),
          ),
        ),
      ];

      return Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: _spacing),
            children[i],
          ],
        ],
      );
    });
  }
}

/// The full color picker: a grid of [ColorPalette] colors and a Custom tab
/// with a hue wheel. Returns the chosen color, or null if dismissed.
Future<HabitColor?> showColorPickerSheet(BuildContext context, {required int selectedValue}) {
  return showModalBottomSheet<HabitColor>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _ColorPickerSheet(selectedValue: selectedValue),
  );
}

class _ColorPickerSheet extends StatelessWidget {
  final int selectedValue;

  const _ColorPickerSheet({required this.selectedValue});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            const Text('Choose a Color', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            isCupertino(context) ? const _SegmentedTabs() : const TabBar(tabs: [Tab(text: 'Grid'), Tab(text: 'Custom')]),
            Expanded(
              child: TabBarView(
                // Swiping would fight with dragging on the hue wheel
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _PaletteGrid(selectedValue: selectedValue),
                  _CustomColorTab(initial: Color(selectedValue)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grid / Custom as an iOS segmented control, driving the sheet's tabs.
class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs();

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: SizedBox(
          width: double.infinity,
          child: CupertinoSlidingSegmentedControl<int>(
            groupValue: controller.index,
            onValueChanged: (index) {
              if (index != null) controller.animateTo(index);
            },
            children: const {0: Text('Grid'), 1: Text('Custom')},
          ),
        ),
      ),
    );
  }
}

class _PaletteGrid extends StatelessWidget {
  final int selectedValue;

  const _PaletteGrid({required this.selectedValue});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final family in ColorPalette.families)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < family.colors.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  SelectableSwatch(
                    key: Key('paletteColor_${family.colors[i].name.replaceAll(' ', '_')}'),
                    semanticLabel: '${family.colors[i].name} color',
                    isSelected: family.colors[i].value == selectedValue,
                    onTap: () => Navigator.of(context).pop(family.colors[i]),
                    fill: palette.habitColor(family.colors[i].color),
                    borderColor: family.colors[i].value == selectedValue ? palette.text : null,
                    borderWidth: 3,
                    child: family.colors[i].value == selectedValue
                        ? Icon(Icons.check, size: 22, color: palette.onColor(palette.habitColor(family.colors[i].color)))
                        : null,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _CustomColorTab extends StatefulWidget {
  final Color initial;

  const _CustomColorTab({required this.initial});

  @override
  State<_CustomColorTab> createState() => _CustomColorTabState();
}

class _CustomColorTabState extends State<_CustomColorTab> {
  // Keeps custom colors readable as text and icons on light or dark cards
  static const _minSaturation = 0.2;
  static const _minBrightness = 0.35;
  static const _wheelSize = 220.0;

  late double _hue;
  late double _saturation;
  late double _brightness;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initial);
    _hue = hsv.hue;
    _saturation = math.max(hsv.saturation, _minSaturation);
    _brightness = math.max(hsv.value, _minBrightness);
  }

  Color get _color => HSVColor.fromAHSV(1, _hue, _saturation, _brightness).toColor();

  void _setHueFrom(Offset local) {
    const center = Offset(_wheelSize / 2, _wheelSize / 2);
    final delta = local - center;
    if (delta.distance < 8) return;
    // Screen y points down, so atan2 runs clockwise, matching the sweep gradient
    setState(() => _hue = (math.atan2(delta.dy, delta.dx) * 180 / math.pi + 360) % 360);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Semantics(
            label: 'Hue',
            value: '${_hue.round()} degrees',
            increasedValue: '${((_hue + 15) % 360).round()} degrees',
            decreasedValue: '${((_hue - 15 + 360) % 360).round()} degrees',
            onIncrease: () => setState(() => _hue = (_hue + 15) % 360),
            onDecrease: () => setState(() => _hue = (_hue - 15 + 360) % 360),
            child: GestureDetector(
              key: const Key('hueWheel'),
              onPanDown: (d) => _setHueFrom(d.localPosition),
              onPanUpdate: (d) => _setHueFrom(d.localPosition),
              child: SizedBox(
                width: _wheelSize,
                height: _wheelSize,
                child: CustomPaint(
                  painter: _HueRingPainter(hue: _hue),
                  child: Center(
                    child: Container(
                      key: const Key('customColorPreview'),
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(color: AppPalette.of(context).habitColor(_color), shape: BoxShape.circle),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _labelledSlider(
            label: 'Saturation',
            key: const Key('customSaturation'),
            value: _saturation,
            min: _minSaturation,
            onChanged: (v) => setState(() => _saturation = v),
          ),
          _labelledSlider(
            label: 'Brightness',
            key: const Key('customBrightness'),
            value: _brightness,
            min: _minBrightness,
            onChanged: (v) => setState(() => _brightness = v),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('useCustomColor'),
              onPressed: () => Navigator.of(context).pop(HabitColor.fromColor(_color)),
              child: const Text('Use This Color'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _labelledSlider({
    required String label,
    required Key key,
    required double value,
    required double min,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 88, child: Text(label)),
        Expanded(
          child: Slider.adaptive(key: key, value: value, min: min, max: 1, label: label, onChanged: onChanged),
        ),
      ],
    );
  }
}

class _HueRingPainter extends CustomPainter {
  static const _ringWidth = 26.0;

  final double hue;

  _HueRingPainter({required this.hue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - _ringWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _ringWidth
        ..shader = SweepGradient(colors: [
          for (var h = 0; h <= 360; h += 30) HSVColor.fromAHSV(1, h % 360.0, 1, 1).toColor(),
        ]).createShader(rect),
    );

    // Thumb at the chosen hue
    final angle = hue * math.pi / 180;
    final thumb = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    canvas.drawCircle(thumb, _ringWidth / 2 + 2, Paint()..color = Colors.white);
    canvas.drawCircle(thumb, _ringWidth / 2 - 2, Paint()..color = HSVColor.fromAHSV(1, hue, 1, 1).toColor());
  }

  @override
  bool shouldRepaint(_HueRingPainter old) => old.hue != hue;
}
