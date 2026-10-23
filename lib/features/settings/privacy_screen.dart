import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../auth/auth_controller.dart';

typedef _Json = Map<String, dynamic>;

void _snack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

final _preferencesProvider = FutureProvider.autoDispose<_Json>(
  (ref) async =>
      (await ref.read(dioProvider).get<_Json>('/users/me/preferences')).data!,
);

final _sessionsProvider = FutureProvider.autoDispose<List<_Json>>(
  (ref) async =>
      ((await ref.read(dioProvider).get<List<dynamic>>('/auth/sessions')).data!)
          .cast<_Json>(),
);

final _blocksProvider = FutureProvider.autoDispose<List<_Json>>(
  (ref) async =>
      ((await ref.read(dioProvider).get<List<dynamic>>('/users/me/blocks'))
              .data!)
          .cast<_Json>(),
);

const _notificationPrefs = {
  'discreetNotifications': (
    'Discreet notifications',
    'Show "You have a new notification" without names or previews',
  ),
  'messageAlerts': ('Message alerts', 'When someone messages you'),
  'newContentAlerts': ('New content alerts', 'When creators you follow post'),
};

/// IT.md F12, US-F04 and the privacy parts of C13.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  Future<void> _setPref(
    WidgetRef ref,
    BuildContext context,
    String key,
    bool value,
  ) async {
    try {
      await ref
          .read(dioProvider)
          .patch<void>('/users/me/preferences', data: {key: value});
      ref.invalidate(_preferencesProvider);
    } catch (e) {
      if (context.mounted) _snack(context, apiErrorMessage(e));
    }
  }

  Future<void> _revoke(WidgetRef ref, BuildContext context, _Json s) async {
    try {
      await ref.read(dioProvider).delete<void>('/auth/sessions/${s['id']}');
      if (s['current'] == true) {
        await ref.read(authProvider.notifier).logout();
        return;
      }
      ref.invalidate(_sessionsProvider);
      if (context.mounted) _snack(context, 'Signed out of ${s['device']}');
    } catch (e) {
      if (context.mounted) _snack(context, apiErrorMessage(e));
    }
  }

  Future<void> _unblock(WidgetRef ref, BuildContext context, _Json user) async {
    try {
      await ref.read(dioProvider).delete<void>('/users/${user['id']}/block');
      ref.invalidate(_blocksProvider);
    } catch (e) {
      if (context.mounted) _snack(context, apiErrorMessage(e));
    }
  }

  Future<void> _exportData(WidgetRef ref, BuildContext context) async {
    try {
      final result =
          (await ref.read(dioProvider).post<_Json>('/users/me/data-export'))
              .data!;
      if (context.mounted) {
        _snack(
          context,
          'Request ${result['reference']} received. We will email you a '
          'download link.',
        );
      }
    } catch (e) {
      if (context.mounted) _snack(context, apiErrorMessage(e));
    }
  }

  Future<void> _deleteAccount(WidgetRef ref, BuildContext context) async {
    final confirm = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Delete account?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Your account closes in 30 days. Sign in before then to '
                'cancel. Purchase and payout records are kept as the law '
                'requires. Type DELETE to confirm.',
              ),
              TextField(
                key: const ValueKey('delete-confirm'),
                controller: confirm,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: confirm.text == 'DELETE'
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('Delete account'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(dioProvider)
          .post<void>(
            '/users/me/deletion-request',
            data: {'confirm': 'DELETE'},
          );
      await ref.read(authProvider.notifier).logout();
    } catch (e) {
      if (context.mounted) _snack(context, apiErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    Widget header(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(title, style: text.titleSmall),
    );
    final prefs = ref.watch(_preferencesProvider).valueOrNull;
    final sessions = ref.watch(_sessionsProvider).valueOrNull ?? const [];
    final blocks = ref.watch(_blocksProvider).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        children: [
          header('Notifications'),
          for (final MapEntry(:key, value: (title, subtitle))
              in _notificationPrefs.entries)
            SwitchListTile(
              key: ValueKey('pref-$key'),
              title: Text(title),
              subtitle: Text(subtitle),
              value: prefs?[key] == true,
              onChanged: prefs == null
                  ? null
                  : (v) => _setPref(ref, context, key, v),
            ),
          header('Active sessions'),
          for (final s in sessions)
            ListTile(
              leading: const Icon(Icons.devices),
              title: Text(
                '${s['device']}${s['current'] == true ? ' (this device)' : ''}',
              ),
              subtitle: Text(
                'Signed in ${MaterialLocalizations.of(context).formatMediumDate(DateTime.parse(s['createdAt'] as String).toLocal())}',
              ),
              trailing: TextButton(
                onPressed: () => _revoke(ref, context, s),
                child: const Text('Sign out'),
              ),
            ),
          header('Blocked accounts'),
          if (blocks.isEmpty)
            const ListTile(title: Text('You have not blocked anyone')),
          for (final b in blocks)
            ListTile(
              leading: const Icon(Icons.block),
              title: Text(b['displayName'] as String),
              trailing: TextButton(
                onPressed: () => _unblock(ref, context, b),
                child: const Text('Unblock'),
              ),
            ),
          header('Your data'),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Request a copy of my data'),
            onTap: () => _exportData(ref, context),
          ),
          ListTile(
            leading: const Icon(Icons.policy_outlined),
            title: const Text('Privacy notice'),
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Privacy notice'),
                content: const Text(
                  'We collect what we need to run your account, process '
                  'payments and keep the platform safe. Creators never see '
                  'your email, phone number or payment details. The full '
                  'notice will be published here.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: Icon(
              Icons.delete_forever_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Delete my account',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => _deleteAccount(ref, context),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
