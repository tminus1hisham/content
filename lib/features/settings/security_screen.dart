import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../disguise/lock_gate.dart';
import '../disguise/pin_pad.dart';
import 'settings_screen.dart';

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

    final disabled = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.38);
    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          SettingsGroup(
            children: [
              if (!hasPin)
                SettingsTile(
                  icon: Icons.pin_outlined,
                  title: 'Set PIN',
                  subtitle: 'Asked when the app opens',
                  onTap: setUp,
                )
              else ...[
                SettingsTile(
                  icon: Icons.pin_outlined,
                  title: 'Change PIN',
                  onTap: () async {
                    if (await showPinSheet(context, ref) && context.mounted) {
                      await setUp();
                    }
                  },
                ),
                SettingsTile(
                  icon: Icons.no_encryption_outlined,
                  title: 'Remove PIN',
                  subtitle: 'Also turns off the app disguise',
                  chevron: false,
                  onTap: () async {
                    if (await showPinSheet(context, ref)) {
                      await lock.removePin();
                      say('PIN removed');
                    }
                  },
                ),
              ],
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: SettingsIcon(
                  Icons.timer_outlined,
                  color: hasPin ? null : disabled,
                ),
                title: const Text('Lock again'),
                enabled: hasPin,
                trailing: DropdownButton<int>(
                  borderRadius: BorderRadius.circular(controlRadius),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                secondary: SettingsIcon(
                  Icons.fingerprint,
                  color: hasPin ? null : disabled,
                ),
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
        ],
      ),
    );
  }
}
