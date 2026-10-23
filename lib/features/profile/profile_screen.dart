import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/ui.dart';
import '../../core/api_client.dart';
import '../auth/auth_controller.dart';
import '../settings/settings_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleProvider);
    final user = ref.watch(authProvider).user;
    final roles = user?.roles ?? const <String>{};

    Future<void> becomeCreator() async {
      try {
        await ref.read(roleProvider.notifier).set(UserRole.creator);
        await ref.read(authProvider.notifier).setRoles({...roles, 'creator'});
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
        }
      }
    }

    return Scaffold(
      // Ambient light behind the header; the groups scroll over it.
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackground()),
          ListView(
            // Clears the frosted tab bar the shell draws over the body.
            padding: EdgeInsets.only(
              bottom: 24 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              _ProfileHeader(user?.id, user?.identifier, roles.join(' · ')),
              const SettingsHeader('Account'),
              SettingsGroup(
                children: [
                  if (role == UserRole.fan)
                    SettingsTile(
                      icon: Icons.collections_bookmark_outlined,
                      title: 'My library',
                      subtitle: 'Purchases, receipts and subscriptions',
                      onTap: () => context.push('/library'),
                    )
                  else
                    SettingsTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Earnings',
                      subtitle: 'Balance, transactions and payouts',
                      onTap: () => context.push('/earnings'),
                    ),
                  SettingsTile(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () => context.push('/settings'),
                  ),
                ],
              ),
              const SettingsHeader('More'),
              SettingsGroup(
                children: [
                  if (roles.containsAll({'fan', 'creator'}))
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      secondary: const SettingsIcon(Icons.swap_horiz),
                      title: const Text('Creator view'),
                      value: role == UserRole.creator,
                      onChanged: (creator) => ref
                          .read(roleProvider.notifier)
                          .set(creator ? UserRole.creator : UserRole.fan),
                    )
                  else if (!roles.contains('creator'))
                    SettingsTile(
                      icon: Icons.videocam_outlined,
                      title: 'Become a creator',
                      subtitle: 'Sell content and go live',
                      onTap: becomeCreator,
                    ),
                  SettingsTile(
                    icon: Icons.logout,
                    title: 'Log out',
                    chevron: false,
                    onTap: () => ref.read(authProvider.notifier).logout(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader(this.id, this.name, this.roles);

  final String? id;
  final String? name;
  final String roles;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final id = this.id;
    final name = this.name;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (name != null)
          Text(
            name,
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        if (roles.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            roles,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
    final avatar = id == null || name == null
        ? null
        : CreatorAvatar(id: id, name: name, size: 64);
    // Accessibility text sizes: stack, so the name gets the full width.
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text('Profile', style: text.headlineMedium),
            ),
            if (avatar != null) ...[
              const SizedBox(height: 20),
              if (large) ...[
                avatar,
                const SizedBox(height: 12),
                details,
              ] else
                Row(
                  children: [
                    avatar,
                    const SizedBox(width: 16),
                    Expanded(child: details),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
