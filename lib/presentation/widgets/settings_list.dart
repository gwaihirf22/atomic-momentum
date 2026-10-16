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
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle!, maxLines: 2),
          additionalInfo: value == null ? null : _ValueText(value!),
          trailing: showChevron && onTap != null ? const CupertinoListTileChevron() : null,
          onTap: enabled ? onTap : null,
        ),
      );
    }
    return ListTile(
      key: tileKey,
      enabled: enabled,
      leading: Icon(icon, color: enabled ? iconColor : null),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null) _ValueText(value!, color: secondaryLabel(context)),
          if (showChevron && onTap != null) const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// A row's current value, shortened rather than pushing the title off
/// screen (long values, large text sizes).
class _ValueText extends StatelessWidget {
  final String text;
  final Color? color;

  const _ValueText(this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.4),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: color == null ? null : TextStyle(color: color),
      ),
    );
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
            title: Text(title),
            subtitle: subtitle == null ? null : Text(subtitle!, maxLines: 3),
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
