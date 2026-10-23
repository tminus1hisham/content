import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';

/// Small section label above a grouped card.
class SettingsHeader extends StatelessWidget {
  const SettingsHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

/// Rounded card grouping a set of tiles: a raised surface with a hairline
/// border and hairline dividers between rows.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: scheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(cardRadius)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, child) in children.indexed) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

/// Leading icon in a tonal rounded square.
class SettingsIcon extends StatelessWidget {
  const SettingsIcon(this.icon, {this.color, super.key});

  final IconData icon;

  /// Icon colour; defaults to the accent.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SizedBox.square(
        dimension: 36,
        child: Icon(icon, size: 20, color: color ?? scheme.primary),
      ),
    );
  }
}

/// Navigational tile with tonal icon and trailing chevron.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.chevron = true,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: SettingsIcon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: chevron
          ? Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )
          : null,
      onTap: onTap,
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SettingsHeader('General'),
          SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.palette_outlined,
                title: 'Appearance',
                onTap: () => context.push('/settings/appearance'),
              ),
              SettingsTile(
                icon: Icons.apps_outlined,
                title: 'App icon & disguise',
                onTap: () => context.push('/settings/disguise'),
              ),
            ],
          ),
          const SettingsHeader('Security & privacy'),
          SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.lock_outline,
                title: 'Security',
                onTap: () => context.push('/settings/security'),
              ),
              SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy',
                subtitle: 'Notifications, sessions, blocks, your data',
                onTap: () => context.push('/settings/privacy'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
