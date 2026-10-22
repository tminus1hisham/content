import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../disguise/disguise_controller.dart';
import '../disguise/lock_gate.dart';
import '../disguise/pin_pad.dart';
import '../disguise/pin_store.dart';

class DisguiseScreen extends ConsumerWidget {
  const DisguiseScreen({super.key});

  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    Disguise disguise,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (disguise != Disguise.none &&
        !await ref.read(pinStoreProvider).hasPin()) {
      if (!context.mounted) return;
      final pin = await showPinSetup(context);
      if (pin == null) return;
      await ref.read(lockProvider.notifier).setPin(pin);
    }
    try {
      await ref.read(disguiseProvider.notifier).set(disguise);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            disguise == Disguise.none
                ? 'Disguise off'
                : 'Now disguised as ${disguise.label}',
          ),
        ),
      );
    } on PlatformException {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't change the app icon")),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(disguiseProvider);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('App icon & disguise')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Disguise changes the app icon and name on your home screen. '
            'While it is on, opening the app shows a working decoy app. '
            'Your PIN gets you back in:\n'
            '• Calculator: type your PIN, then press =\n'
            '• Notes, Calendar, Weather: press and hold the title at the top, '
            'then enter your PIN',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final d in Disguise.values)
                _Option(
                  disguise: d,
                  selected: d == current,
                  onTap: () => _choose(context, ref, d),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Good to know', style: textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Android: the home screen may take a few seconds to show the new '
            'icon.\niPhone: the system shows a confirmation alert, and the name '
            'under the icon cannot change.',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.disguise,
    required this.selected,
    required this.onTap,
  });
  final Disguise disguise;
  final bool selected;
  final VoidCallback onTap;

  static const _tiles = {
    Disguise.none: Color(0xFF455A64),
    Disguise.weather: Color(0xFF3D7DCA),
    Disguise.notes: Color(0xFFE9A23B),
    Disguise.calendar: Color(0xFF5B6B7F),
    Disguise.calculator: Color(0xFF2E3440),
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 96,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? scheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _tiles[disguise],
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(disguise.icon, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 6),
              Text(disguise == Disguise.none ? 'Default' : disguise.label),
            ],
          ),
        ),
      ),
    );
  }
}
