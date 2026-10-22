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
          const ListTile(
            leading: Icon(Icons.apps_outlined),
            title: Text('App icon & disguise'),
            subtitle: Text('Coming soon'),
          ),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Security'),
            subtitle: Text('Coming soon'),
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
