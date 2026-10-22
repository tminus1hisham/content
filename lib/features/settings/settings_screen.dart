import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Appearance'),
            onTap: () => context.push('/settings/appearance'),
          ),
          ListTile(
            leading: const Icon(Icons.apps_outlined),
            title: const Text('App icon & disguise'),
            onTap: () => context.push('/settings/disguise'),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Security'),
            onTap: () => context.push('/settings/security'),
          ),
          const ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text('Privacy'),
            subtitle: Text('Coming soon'),
          ),
        ],
      ),
    );
  }
}
