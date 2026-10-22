import 'package:content/features/disguise/pin_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('set then verify accepts the right PIN, rejects a wrong one', () async {
    final store = PinStore();
    expect(await store.hasPin(), isFalse);
    await store.setPin('1234');
    expect(await store.hasPin(), isTrue);
    expect(await store.verify('1234'), isTrue);
    expect(await store.verify('4321'), isFalse);
  });

  test('stores a salted hash, never the PIN', () async {
    await PinStore().setPin('123456');
    final stored = Map.of(await const FlutterSecureStorage().readAll());
    expect(stored.keys, containsAll([pinHashKey, pinSaltKey]));
    expect(stored.values.join(), isNot(contains('123456')));
    expect(stored[pinHashKey], hasLength(64)); // SHA-256 hex.

    // A fresh salt per setPin, so the same PIN hashes differently.
    await PinStore().setPin('123456');
    expect(
      await const FlutterSecureStorage().read(key: pinHashKey),
      isNot(stored[pinHashKey]),
    );
  });

  test('rejects PINs that are not 4-6 digits', () {
    final store = PinStore();
    for (final bad in ['123', '1234567', '12a4', '']) {
      expect(() => store.setPin(bad), throwsArgumentError);
    }
  });

  test('five wrong attempts lock out for 30s, even the right PIN', () async {
    var now = DateTime(2026);
    final store = PinStore(now: () => now);
    await store.setPin('1234');
    for (var i = 0; i < 4; i++) {
      expect(await store.verify('0000'), isFalse);
    }
    expect(store.lockoutRemaining, Duration.zero);
    expect(await store.verify('0000'), isFalse);
    expect(store.lockoutRemaining, const Duration(seconds: 30));
    expect(await store.verify('1234'), isFalse);

    now = now.add(const Duration(seconds: 29));
    expect(await store.verify('1234'), isFalse);
    now = now.add(const Duration(seconds: 1));
    expect(await store.verify('1234'), isTrue);
  });

  test('clear removes the PIN', () async {
    final store = PinStore();
    await store.setPin('1234');
    await store.clear();
    expect(await store.hasPin(), isFalse);
    expect(await store.verify('1234'), isFalse);
    expect(await const FlutterSecureStorage().readAll(), isEmpty);
  });
}
