import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../disguise/lock_gate.dart';
import '../disguise/pin_pad.dart';

class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPin = ref.watch(lockProvider).hasPin ?? false;
    final lock = ref.read(lockProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    void say(String text) =>
        messenger.showSnackBar(SnackBar(content: Text(text)));

    Future<void> setUp() async {
      final pin = await showPinSetup(context);
      if (pin == null) return;
      await lock.setPin(pin);
      say('PIN saved');
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: ListView(
        children: [
          if (!hasPin)
            ListTile(
              leading: const Icon(Icons.pin_outlined),
              title: const Text('Set PIN'),
              subtitle: const Text('Asked when the app opens'),
              onTap: setUp,
            )
          else ...[
            ListTile(
              leading: const Icon(Icons.pin_outlined),
              title: const Text('Change PIN'),
              onTap: () async {
                if (await showPinSheet(context, ref) && context.mounted) {
                  await setUp();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.no_encryption_outlined),
              title: const Text('Remove PIN'),
              subtitle: const Text('Also turns off the app disguise'),
              onTap: () async {
                if (await showPinSheet(context, ref)) {
                  await lock.removePin();
                  say('PIN removed');
                }
              },
            ),
          ],
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Lock again'),
            enabled: hasPin,
            trailing: DropdownButton<int>(
              borderRadius: BorderRadius.circular(16),
              underline: const SizedBox.shrink(),
              value: ref.watch(relockProvider),
              onChanged: hasPin
                  ? (v) => ref.read(relockProvider.notifier).set(v!)
                  : null,
              items: [
                for (final MapEntry(:key, :value) in relockChoices.entries)
                  DropdownMenuItem(value: key, child: Text(value)),
              ],
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Unlock with biometrics'),
            subtitle: const Text('Fingerprint or face, instead of the PIN'),
            value: hasPin && ref.watch(biometricProvider),
            onChanged: !hasPin
                ? null
                : (enable) async {
                    if (enable && !await authenticateWithBiometrics()) {
                      say('Biometrics are not available on this device');
                      return;
                    }
                    await ref.read(biometricProvider.notifier).set(enable);
                  },
          ),
        ],
      ),
    );
  }
}
