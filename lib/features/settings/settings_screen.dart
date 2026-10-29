import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/confirm_sheet.dart';
import '../../app/theme.dart';
import '../../app/theme_controller.dart';
import '../../app/ui.dart';
import '../../core/api_client.dart';
import '../auth/auth_controller.dart';
import 'update_tile.dart';

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

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final user = ref.watch(authProvider).user;
    final mode = ref.watch(themeControllerProvider).themeMode;
    Color tint(double opacity) => Color.alphaBlend(
      scheme.primary.withValues(alpha: opacity),
      scheme.surface,
    );

    final shortcuts = [
      _SettingsShortcut(
        icon: Icons.light_mode_outlined,
        title: 'Appearance',
        subtitle: switch (mode) {
          ThemeMode.system => 'System',
          ThemeMode.light => 'Light',
          ThemeMode.dark => 'Dark',
        },
        onTap: () => context.push('/settings/appearance'),
      ),
      _SettingsShortcut(
        icon: Icons.notifications_outlined,
        title: 'Notifications',
        subtitle: 'Manage alerts',
        onTap: () => context.push('/settings/privacy'),
      ),
    ];

    return Theme(
      data: theme.copyWith(
        colorScheme: scheme.copyWith(surfaceContainerLow: tint(0.025)),
      ),
      child: Scaffold(
        backgroundColor: tint(0.07),
        appBar: AppBar(backgroundColor: tint(0.07)),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text('Settings', style: text.headlineLarge),
                          ),
                          // 
                        ],
                      ),
                    ),
                    if (user != null) ...[
                      SettingsGroup(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: CreatorAvatar(
                              id: user.id,
                              name: user.identifier,
                              size: 56,
                            ),
                            title: const Text('My profile'),
                            subtitle: Text(user.identifier),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.go('/profile'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 17),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 340 ||
                              MediaQuery.textScalerOf(context).scale(14) >
                                  19.6) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                shortcuts[0],
                                const SizedBox(height: 10),
                                shortcuts[1],
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: shortcuts[0]),
                              const SizedBox(width: 12),
                              Expanded(child: shortcuts[1]),
                            ],
                          );
                        },
                      ),
                    ),
                    const SettingsHeader('Account & privacy'),
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
                          subtitle: 'Sessions, blocks and your data',
                          onTap: () => context.push('/settings/privacy'),
                        ),
                      ],
                    ),
                    const SettingsHeader('App preferences'),
                    SettingsGroup(
                      children: [
                        SettingsTile(
                          icon: Icons.apps_outlined,
                          title: 'App icon & disguise',
                          onTap: () => context.push('/settings/disguise'),
                        ),
                        if (!kIsWeb &&
                            defaultTargetPlatform == TargetPlatform.android)
                          const UpdateTile(),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Material(
                        color: scheme.errorContainer.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(cardRadius),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 6,
                          ),
                          leading: Icon(Icons.logout, color: scheme.error),
                          title: Text(
                            'Sign out',
                            style: TextStyle(color: scheme.error),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: scheme.error,
                          ),
                          onTap: () async {
                            final confirmed = await showConfirmSheet(
                              context,
                              icon: Icons.logout,
                              title: 'Sign out?',
                              message:
                                  'You will need your email and password to '
                                  'sign back in.',
                              confirmLabel: 'Sign out',
                              destructive: true,
                            );
                            if (!confirmed) return;
                            try {
                              await ref.read(authProvider.notifier).logout();
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(apiErrorMessage(e))),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsShortcut extends StatelessWidget {
  const _SettingsShortcut({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      color: Color.alphaBlend(
        scheme.primary.withValues(alpha: 0.14),
        scheme.surface,
      ),
      borderRadius: BorderRadius.circular(cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: scheme.primary, size: 30),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: scheme.primary, size: 20),
                ],
              ),
              const SizedBox(height: 16),
              Text(title, style: text.titleSmall),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: text.bodyMedium?.copyWith(color: scheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
