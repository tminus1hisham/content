import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const pinHashKey = 'lock.pinHash';
const pinSaltKey = 'lock.pinSalt';

/// The app PIN: 4-6 digits, kept only as a salted SHA-256 in secure storage.
/// Tests swap the backend with `FlutterSecureStorage.setMockInitialValues`.
class PinStore {
  PinStore({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const maxAttempts = 5;
  static const lockoutDuration = Duration(seconds: 30);
  static final _pinPattern = RegExp(r'^\d{4,6}$');

  final DateTime Function() _now;
  final _storage = const FlutterSecureStorage();
  int _failures = 0;
  DateTime? _lockedUntil;

  static bool isValid(String pin) => _pinPattern.hasMatch(pin);

  Future<bool> hasPin() async => await _storage.read(key: pinHashKey) != null;

  Future<void> setPin(String pin) async {
    if (!isValid(pin)) {
      throw ArgumentError.value(pin, 'pin', 'must be 4-6 digits');
    }
    final random = Random.secure();
    final salt = base64Encode(List.generate(16, (_) => random.nextInt(256)));
    await _storage.write(key: pinSaltKey, value: salt);
    await _storage.write(key: pinHashKey, value: _hash(salt, pin));
    _failures = 0;
    _lockedUntil = null;
  }

  /// Zero when attempts are allowed.
  Duration get lockoutRemaining {
    final until = _lockedUntil;
    if (until == null) return Duration.zero;
    final left = until.difference(_now());
    return left.isNegative ? Duration.zero : left;
  }

  /// False while locked out (without counting the attempt). Five wrong
  /// attempts in a row start a [lockoutDuration] lockout.
  Future<bool> verify(String pin) async {
    if (lockoutRemaining > Duration.zero) return false;
    final hash = await _storage.read(key: pinHashKey);
    final salt = await _storage.read(key: pinSaltKey);
    if (hash == null || salt == null) return false;
    if (_hash(salt, pin) == hash) {
      _failures = 0;
      return true;
    }
    if (++_failures >= maxAttempts) {
      _failures = 0;
      _lockedUntil = _now().add(lockoutDuration);
    }
    return false;
  }

  Future<void> clear() async {
    await _storage.delete(key: pinHashKey);
    await _storage.delete(key: pinSaltKey);
    _failures = 0;
    _lockedUntil = null;
  }

  static String _hash(String salt, String pin) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();
}

/// One instance per app so the in-memory lockout counter is shared.
final pinStoreProvider = Provider<PinStore>((ref) => PinStore());
