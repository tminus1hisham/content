import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/prefs.dart';
import 'decoy_calculator.dart';
import 'decoy_calendar.dart';
import 'decoy_notes.dart';
import 'decoy_weather.dart';
import 'disguise_controller.dart';
import 'pin_pad.dart';
import 'pin_store.dart';

class LockState {
  const LockState({this.hasPin, this.unlocked = false});

  /// Null until secure storage has been read at startup.
  final bool? hasPin;

  /// In memory only, so every cold start is locked.
  final bool unlocked;
}

class LockController extends Notifier<LockState> {
  static const relockAfter = Duration(seconds: 60);
  DateTime? _backgroundedAt;

  @override
  LockState build() {
    final listener = AppLifecycleListener(onStateChange: _onLifecycle);
    ref.onDispose(listener.dispose);
    _load();
    return const LockState();
  }

  Future<void> _load() async {
    final hasPin = await ref.read(pinStoreProvider).hasPin();
    if (state.hasPin != null) return; // setPin/removePin already decided.
    // A disguise without a PIN could never be unlocked (e.g. keychain wiped).
    if (!hasPin && ref.read(disguiseProvider) != Disguise.none) {
      await ref.read(disguiseProvider.notifier).set(Disguise.none);
    }
    state = LockState(hasPin: hasPin, unlocked: state.unlocked);
  }

  void _onLifecycle(AppLifecycleState lifecycle) {
    switch (lifecycle) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        _backgroundedAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        final at = _backgroundedAt;
        _backgroundedAt = null;
        if (at != null && DateTime.now().difference(at) > relockAfter) lock();
      case _:
        break;
    }
  }

  void unlock() => state = LockState(hasPin: state.hasPin, unlocked: true);

  void lock() => state = LockState(hasPin: state.hasPin);

  Future<void> setPin(String pin) async {
    await ref.read(pinStoreProvider).setPin(pin);
    state = const LockState(hasPin: true, unlocked: true);
  }

  /// Also turns off the disguise and biometrics, which both depend on the PIN.
  Future<void> removePin() async {
    await ref.read(pinStoreProvider).clear();
    await ref.read(disguiseProvider.notifier).set(Disguise.none);
    await ref.read(biometricProvider.notifier).set(false);
    state = LockState(hasPin: false, unlocked: state.unlocked);
  }
}

final lockProvider = NotifierProvider<LockController, LockState>(
  LockController.new,
);

/// Router redirect: a disguised, locked app shows the decoy; an undisguised
/// app with a PIN shows the PIN lock.
String? lockRedirect(Ref ref, String location, String home) {
  final lock = ref.read(lockProvider);
  final disguise = ref.read(disguiseProvider);
  final gate = lock.unlocked
      ? null
      : disguise != Disguise.none
      ? '/decoy'
      : lock.hasPin != false
      ? '/lock'
      : null;
  if (gate != null) return location == gate ? null : gate;
  return location == '/decoy' || location == '/lock' ? home : null;
}

const biometricKey = 'lock.biometric';

class BiometricController extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).get(biometricKey) == true;

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref.read(sharedPreferencesProvider).setBool(biometricKey, enabled);
  }
}

final biometricProvider = NotifierProvider<BiometricController, bool>(
  BiometricController.new,
);

/// False when the device has no biometrics or the user cancels.
Future<bool> authenticateWithBiometrics() async {
  final auth = LocalAuthentication();
  try {
    return await auth.isDeviceSupported() &&
        await auth.canCheckBiometrics &&
        await auth.authenticate(localizedReason: 'Unlock', biometricOnly: true);
  } on Exception {
    return false;
  }
}

class LockScreen extends ConsumerWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(lockProvider).hasPin == null) return const Scaffold();
    final unlock = ref.read(lockProvider.notifier).unlock;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: PinPad(
            title: 'Enter PIN',
            onSubmit: (pin) async {
              final error = await checkPin(ref, pin);
              if (error == null) unlock();
              return error;
            },
            onBiometric: ref.watch(biometricProvider)
                ? () async {
                    if (await authenticateWithBiometrics()) unlock();
                  }
                : null,
          ),
        ),
      ),
    );
  }
}

/// The working decoy app for the active disguise, in a neutral theme.
class DecoyScreen extends ConsumerWidget {
  const DecoyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Theme(
      data: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Theme.of(context).brightness,
        ),
      ),
      child: switch (ref.watch(disguiseProvider)) {
        Disguise.calculator => const DecoyCalculator(),
        Disguise.notes => const DecoyNotes(),
        Disguise.calendar => const DecoyCalendar(),
        Disguise.weather => const DecoyWeather(),
        Disguise.none => const Scaffold(),
      },
    );
  }
}
