import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
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
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (user != null) _ProfileHeader(user.identifier, roles.join(' · ')),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader(this.name, this.roles);

  final String name;
  final String roles;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            child: const Icon(Icons.person, size: 32),
          ),
          const SizedBox(height: 12),
          Text(name, style: text.titleLarge, textAlign: TextAlign.center),
          if (roles.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              roles,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
