import 'package:content/core/prefs.dart';
import 'package:content/features/disguise/disguise_controller.dart';
import 'package:content/features/disguise/icon_switcher.dart';
import 'package:content/features/disguise/lock_gate.dart';
import 'package:content/features/disguise/pin_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final iconCalls = <String>[];

Future<ProviderContainer> _container(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(
        await SharedPreferences.getInstance(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    iconCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(IconSwitcher.channel, (call) async {
          expect(call.method, 'setIcon');
          iconCalls.add(call.arguments as String);
          return null;
        });
  });

  test('cannot enable a disguise without a PIN', () async {
    final container = await _container({});
    await expectLater(
      container.read(disguiseProvider.notifier).set(Disguise.calculator),
      throwsStateError,
    );
    expect(container.read(disguiseProvider), Disguise.none);
    expect(iconCalls, isEmpty);
  });

  test('with a PIN the choice persists, restores, switches the icon', () async {
    final container = await _container({});
    await container.read(pinStoreProvider).setPin('1234');
    await container.read(disguiseProvider.notifier).set(Disguise.notes);
    expect(
      container.read(sharedPreferencesProvider).getString(disguiseKey),
      'notes',
    );
    expect(iconCalls, ['notes']);

    final fresh = await _container({disguiseKey: 'notes'});
    expect(fresh.read(disguiseProvider), Disguise.notes);

    await container.read(disguiseProvider.notifier).set(Disguise.none);
    expect(iconCalls, ['notes', 'default']);
  });

  test('a bad stored value falls back to none', () async {
    for (final bad in <Object>['neon', 3]) {
      final container = await _container({disguiseKey: bad});
      expect(container.read(disguiseProvider), Disguise.none);
    }
  });

  test('removing the PIN resets the disguise to none', () async {
    final container = await _container({});
    final lock = container.read(lockProvider.notifier);
    await lock.setPin('1234');
    await container.read(disguiseProvider.notifier).set(Disguise.weather);

    await lock.removePin();
    expect(container.read(disguiseProvider), Disguise.none);
    expect(
      container.read(sharedPreferencesProvider).getString(disguiseKey),
      'none',
    );
    expect(await container.read(pinStoreProvider).hasPin(), isFalse);
    expect(iconCalls.last, 'default');
  });
}
