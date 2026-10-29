import 'package:content/core/api_client.dart';
import 'package:content/core/fake_backend.dart';
import 'package:content/core/prefs.dart';
import 'package:content/features/auth/auth_controller.dart';
import 'package:content/features/auth/fake_auth.dart';
import 'package:content/features/content/discover_screens.dart';
import 'package:content/features/disguise/pin_store.dart';
import 'package:content/main.dart';
import 'package:flutter/material.dart';
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
  List<Override> overrides = const [],
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
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
        ...overrides,
      ],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();
}

/// From the fan home: search for [name] and open their creator page.
Future<void> openCreator(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const ValueKey('home-search')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('discover-search')), name);
  await tester.pumpAndSettle();
  final card = find.descendant(
    of: find.byType(CreatorCard),
    matching: find.text(name),
  );
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await tester.tap(card);
  await tester.pumpAndSettle();
}
