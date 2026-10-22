import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/api_client.dart';
import '../auth/auth_controller.dart';

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
        children: [
          if (user != null)
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(user.identifier),
              subtitle: Text(roles.join(' · ')),
            ),
          if (role == UserRole.fan)
            const ListTile(
              leading: Icon(Icons.collections_bookmark_outlined),
              title: Text('My library'),
              subtitle: Text('Coming soon'),
            )
          else
            const ListTile(
              leading: Icon(Icons.account_balance_wallet_outlined),
              title: Text('Earnings'),
              subtitle: Text('Coming soon'),
            ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () => context.push('/settings'),
          ),
          const Divider(),
          if (roles.containsAll({'fan', 'creator'}))
            SwitchListTile(
              secondary: const Icon(Icons.swap_horiz),
              title: const Text('Creator view'),
              value: role == UserRole.creator,
              onChanged: (creator) => ref
                  .read(roleProvider.notifier)
                  .set(creator ? UserRole.creator : UserRole.fan),
            )
          else if (!roles.contains('creator'))
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Become a creator'),
              subtitle: const Text('Sell content and go live'),
              onTap: becomeCreator,
            ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log out'),
            onTap: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}
