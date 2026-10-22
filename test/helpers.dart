import 'package:content/core/api_client.dart';
import 'package:content/core/fake_backend.dart';
import 'package:content/core/prefs.dart';
import 'package:content/features/auth/auth_controller.dart';
import 'package:content/features/auth/fake_auth.dart';
import 'package:content/features/disguise/pin_store.dart';
import 'package:content/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cold-starts the app against the fake backend. By default the 18+ gate is
/// passed and [signedInAs] (a seeded fake user) is signed in; pass null to
/// start signed out.
Future<void> pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  bool adult = true,
  String? signedInAs = 'fan@demo.ke',
  String? pin,
}) async {
  fakeLatency = Duration.zero;
  resetFakeBackend();
  final secure = <String, String>{};
  if (signedInAs != null) {
    final session = fakeAuthDb.sessionFor(signedInAs);
    secure[accessTokenKey] = session['accessToken'] as String;
    secure[refreshTokenKey] = session['refreshToken'] as String;
  }
  FlutterSecureStorage.setMockInitialValues(secure);
  if (pin != null) await PinStore().setPin(pin);
  SharedPreferences.setMockInitialValues({
    if (adult) ageConfirmedKey: true,
    ...prefs,
  });
  final sharedPrefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(sharedPrefs)],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();
}
