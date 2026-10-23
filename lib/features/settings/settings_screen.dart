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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

/// Rounded card grouping a set of tiles.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(cardRadius)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// Leading icon in a tonal rounded square.
class SettingsIcon extends StatelessWidget {
  const SettingsIcon(this.icon, {super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: SizedBox.square(
        dimension: 36,
        child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
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
