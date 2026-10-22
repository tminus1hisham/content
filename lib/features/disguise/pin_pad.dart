import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lock_gate.dart';
import 'pin_store.dart';

/// Digit keypad with dots for 4-6 digit PINs. Keys are `pin-0`..`pin-9`,
/// `pin-back`, `pin-ok` and `pin-bio`.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.title,
    required this.onSubmit,
    this.onBiometric,
  });

  final String title;

  /// Returns an error message to show, or null when the PIN was accepted.
  final Future<String?> Function(String pin) onSubmit;

  /// Shows a fingerprint key when set.
  final Future<void> Function()? onBiometric;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';
  String? _error;
  bool _busy = false;

  void _digit(String d) {
    if (_pin.length < 6) setState(() => _pin += d);
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final error = await widget.onSubmit(_pin);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      if (error != null) _pin = '';
    });
  }

  Widget _key(String id, Widget child, VoidCallback? onPressed) => Padding(
    padding: const EdgeInsets.all(6),
    child: SizedBox.square(
      dimension: 68,
      child: TextButton(
        key: ValueKey('pin-$id'),
        style: TextButton.styleFrom(shape: const CircleBorder()),
        onPressed: _busy ? null : onPressed,
        child: child,
      ),
    ),
  );

  Widget _digitKey(String d) => _key(
    d,
    Text(d, style: Theme.of(context).textTheme.headlineSmall),
    () => _digit(d),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onBiometric = widget.onBiometric;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Semantics(
          label: '${_pin.length} digits entered',
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 6; i++)
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length ? scheme.primary : null,
                    border: Border.all(
                      color: i < 4 ? scheme.outline : scheme.outlineVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 32,
          child: Center(
            child: Text(_error ?? '', style: TextStyle(color: scheme.error)),
          ),
        ),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [for (final d in row) _digitKey(d)],
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            onBiometric == null
                ? _key('none', const SizedBox(), null)
                : _key(
                    'bio',
                    const Icon(Icons.fingerprint, semanticLabel: 'Biometrics'),
                    onBiometric,
                  ),
            _digitKey('0'),
            _key(
              'back',
              const Icon(Icons.backspace_outlined, semanticLabel: 'Delete'),
              _pin.isEmpty
                  ? null
                  : () => setState(
                      () => _pin = _pin.substring(0, _pin.length - 1),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const ValueKey('pin-ok'),
          onPressed: !_busy && PinStore.isValid(_pin) ? _submit : null,
          child: const Text('OK'),
        ),
      ],
    );
  }
}

/// Null when [pin] is correct, else a message (including lockout time).
Future<String?> checkPin(WidgetRef ref, String pin) async {
  final store = ref.read(pinStoreProvider);
  if (await store.verify(pin)) return null;
  final wait = store.lockoutRemaining;
  return wait > Duration.zero
      ? 'Too many attempts. Try again in ${(wait.inMilliseconds / 1000).ceil()}s'
      : 'Wrong PIN';
}

/// Bottom sheet asking for the current PIN (or biometrics when enabled).
/// True when it was entered correctly.
Future<bool> showPinSheet(BuildContext context, WidgetRef ref) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: PinPad(
          title: 'Enter PIN',
          onSubmit: (pin) async {
            final error = await checkPin(ref, pin);
            if (error == null && sheetContext.mounted) {
              Navigator.pop(sheetContext, true);
            }
            return error;
          },
          onBiometric: ref.read(biometricProvider)
              ? () async {
                  if (await authenticateWithBiometrics() &&
                      sheetContext.mounted) {
                    Navigator.pop(sheetContext, true);
                  }
                }
              : null,
        ),
      ),
    ),
  );
  return ok ?? false;
}

/// Full-screen choose-and-confirm flow. Returns the new PIN, or null if cancelled.
Future<String?> showPinSetup(BuildContext context) =>
    Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _PinSetupPage(),
      ),
    );

class _PinSetupPage extends StatefulWidget {
  const _PinSetupPage();

  @override
  State<_PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<_PinSetupPage> {
  String? _first;
  bool _mismatch = false;

  @override
  Widget build(BuildContext context) {
    final first = _first;
    return Scaffold(
      appBar: AppBar(title: const Text('Set PIN')),
      body: Center(
        child: SingleChildScrollView(
          child: PinPad(
            // A new key resets the pad between steps.
            key: ValueKey(first == null ? 'choose$_mismatch' : 'confirm'),
            title: first != null
                ? 'Confirm your PIN'
                : _mismatch
                ? "PINs didn't match. Try again"
                : 'Choose a 4-6 digit PIN',
            onSubmit: (pin) async {
              if (first == null) {
                setState(() => _first = pin);
              } else if (pin == first) {
                Navigator.pop(context, pin);
              } else {
                setState(() {
                  _first = null;
                  _mismatch = true;
                });
              }
              return null;
            },
          ),
        ),
      ),
    );
  }
}

/// AppBar title for a decoy; a long press opens the PIN sheet.
class DecoyTitle extends ConsumerWidget {
  const DecoyTitle(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onLongPress: () async {
        if (await showPinSheet(context, ref)) {
          ref.read(lockProvider.notifier).unlock();
        }
      },
      child: Text(label),
    );
  }
}
