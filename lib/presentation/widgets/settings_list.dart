import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_style.dart';

/// A group of settings: an inset grouped list on iPhone and Mac (like the
/// Settings app), a headed list on Android.
class SettingsSection extends StatelessWidget {
  final String? header;
  final String? footer;
  final List<Widget> children;

  const SettingsSection({super.key, this.header, this.footer, required this.children});

  @override
  Widget build(BuildContext context) {
    final footerText =
        footer == null ? null : Text(footer!, style: TextStyle(fontSize: 13, color: secondaryLabel(context)));

    if (isCupertino(context)) {
      return CupertinoListSection.insetGrouped(
        header: header == null ? null : Text(header!.toUpperCase()),
        footer: footerText,
        children: children,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null) SectionHeader(header!),
        ...children,
        if (footerText != null) Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: footerText),
        const Divider(),
      ],
    );
  }
}

/// The colored rounded-square icon iOS Settings rows use.
class _SettingsIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _SettingsIcon(this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 29,
      height: 29,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)),
      child: Icon(icon, size: 18, color: Colors.white),
    );
  }
}

/// A settings row: an icon, a title, an optional current [value], and a
/// chevron when it opens something.
class SettingsTile extends StatelessWidget {
  /// Keys the tappable row (tests and VoiceOver focus).
  final Key? tileKey;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;
  final bool enabled;
  final bool showChevron;

  const SettingsTile({
    super.key,
    this.tileKey,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
    this.enabled = true,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return Opacity(
        opacity: enabled ? 1 : 0.45,
        child: CupertinoListTile(
          key: tileKey,
          leading: _SettingsIcon(icon, iconColor),
          title: _TitleAndValue(title: title, value: value),
          subtitle: subtitle == null ? null : _Wrapping(subtitle!),
          trailing: showChevron && onTap != null ? const CupertinoListTileChevron() : null,
          onTap: enabled ? onTap : null,
        ),
      );
    }
    return ListTile(
      key: tileKey,
      enabled: enabled,
      leading: Icon(icon, color: enabled ? iconColor : null),
      title: _TitleAndValue(title: title, value: value),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: showChevron && onTap != null ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
    );
  }
}

/// Text that wraps instead of being cut off. CupertinoListTile makes its
/// title and subtitle single-line with "…"; an explicit line count overrides
/// that, and no label of ours needs more lines than this.
class _Wrapping extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const _Wrapping(this.text, {this.style});

  @override
  Widget build(BuildContext context) => Text(text, maxLines: 6, style: style);
}

/// A row's title with its current value: side by side when both fit, as in
/// the Settings app, otherwise the value goes under the title (as iOS does
/// with large text) so neither is cut off.
class _TitleAndValue extends StatelessWidget {
  final String title;
  final String? value;

  const _TitleAndValue({required this.title, this.value});

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    if (value == null) return _Wrapping(title);
    final valueStyle = TextStyle(color: secondaryLabel(context));

    return LayoutBuilder(builder: (context, constraints) {
      final style = DefaultTextStyle.of(context).style;
      double widthOf(String text, TextStyle s) => (TextPainter(
            text: TextSpan(text: text, style: s),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout())
              .width;

      const gap = 12.0;
      final fits = widthOf(title, style) + gap + widthOf(value, style.merge(valueStyle)) <= constraints.maxWidth;
      if (fits) {
        return Row(
          children: [
            Expanded(child: _Wrapping(title)),
            const SizedBox(width: gap),
            Text(value, style: valueStyle),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [_Wrapping(title), _Wrapping(value, style: valueStyle)],
      );
    });
  }
}

/// A settings row with an on/off switch; tapping anywhere on the row toggles
/// it, and the switch carries the row's title for VoiceOver.
class SettingsSwitchTile extends StatelessWidget {
  final Key? tileKey;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool value;

  /// Null disables the row.
  final ValueChanged<bool>? onChanged;

  const SettingsSwitchTile({
    super.key,
    this.tileKey,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      final enabled = onChanged != null;
      return MergeSemantics(
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: CupertinoListTile(
            key: tileKey,
            leading: _SettingsIcon(icon, iconColor),
            title: _Wrapping(title),
            subtitle: subtitle == null ? null : _Wrapping(subtitle!),
            trailing: CupertinoSwitch(value: value, onChanged: onChanged),
            onTap: enabled ? () => onChanged!(!value) : null,
          ),
        ),
      );
    }
    return SwitchListTile(
      key: tileKey,
      secondary: Icon(icon, color: onChanged != null ? iconColor : null),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
}
