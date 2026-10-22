import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        children: [
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
          SwitchListTile(
            secondary: const Icon(Icons.developer_mode_outlined),
            title: const Text('Creator mode'),
            subtitle: const Text('Developer toggle'),
            value: role == UserRole.creator,
            onChanged: (creator) => ref
                .read(roleProvider.notifier)
                .set(creator ? UserRole.creator : UserRole.fan),
          ),
        ],
      ),
    );
  }
}
