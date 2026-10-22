import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'calculator_engine.dart';
import 'lock_gate.dart';
import 'pin_store.dart';

/// Working calculator. Typing the PIN and pressing `=` (with no pending
/// operator) unlocks the real app instead of calculating.
class DecoyCalculator extends ConsumerStatefulWidget {
  const DecoyCalculator({super.key});

  @override
  ConsumerState<DecoyCalculator> createState() => _DecoyCalculatorState();
}

class _DecoyCalculatorState extends ConsumerState<DecoyCalculator> {
  final _engine = CalculatorEngine();
  String _typed = ''; // Digits typed since the last non-digit key.

  static const _rows = [
    ['AC', '±', '%', '÷'],
    ['7', '8', '9', '×'],
    ['4', '5', '6', '−'],
    ['1', '2', '3', '+'],
    ['0', '.', '='],
  ];

  Future<void> _press(String key) async {
    if (RegExp(r'^\d$').hasMatch(key)) {
      _typed += key;
    } else {
      final candidate = _typed;
      _typed = '';
      if (key == '=' &&
          _engine.pendingOp == null &&
          PinStore.isValid(candidate) &&
          await ref.read(pinStoreProvider).verify(candidate)) {
        ref.read(lockProvider.notifier).unlock();
        return;
      }
    }
    setState(() => _engine.press(key));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Calculator')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: FittedBox(
                    child: Text(
                      _engine.display,
                      key: const ValueKey('calc-display'),
                      style: Theme.of(context).textTheme.displayLarge,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final row in _rows)
                Row(
                  children: [
                    for (final key in row)
                      Expanded(
                        flex: key == '0' ? 2 : 1,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: SizedBox(
                            height: 64,
                            child: _button(key, scheme),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _button(String key, ColorScheme scheme) {
    final isOp = '÷×−+='.contains(key);
    final isFn = key == 'AC' || key == '±' || key == '%';
    final active = key == _engine.pendingOp;
    final style = FilledButton.styleFrom(
      padding: EdgeInsets.zero,
      textStyle: Theme.of(context).textTheme.headlineSmall,
      backgroundColor: active
          ? scheme.inversePrimary
          : isOp
          ? scheme.primary
          : isFn
          ? scheme.secondaryContainer
          : scheme.surfaceContainerHighest,
      foregroundColor: active
          ? scheme.onSurface
          : isOp
          ? scheme.onPrimary
          : isFn
          ? scheme.onSecondaryContainer
          : scheme.onSurface,
    );
    return FilledButton(
      key: ValueKey('calc-$key'),
      style: style,
      onPressed: () => _press(key),
      child: Text(key),
    );
  }
}
