import 'package:content/core/api_client.dart';
import 'package:content/core/fake_backend.dart';
import 'package:content/core/prefs.dart';
import 'package:content/features/auth/auth_controller.dart';
import 'package:content/features/auth/fake_auth.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<void> _enter(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(ValueKey(key)), text);
  await tester.pump();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

void main() {
  group('normalizeIdentifier', () {
    test('Kenyan phone formats become E.164', () {
      expect(normalizeIdentifier('0712 345 678'), '+254712345678');
      expect(normalizeIdentifier('0112-345-678'), '+254112345678');
      expect(normalizeIdentifier('254712345678'), '+254712345678');
      expect(normalizeIdentifier('+254 712 345 678'), '+254712345678');
    });

    test('emails are lower-cased; junk is rejected', () {
      expect(normalizeIdentifier(' Fan@Demo.KE '), 'fan@demo.ke');
      expect(normalizeIdentifier('+447911123456'), '+447911123456');
      expect(normalizeIdentifier('0812345678'), isNull);
      expect(normalizeIdentifier('not-an-email@'), isNull);
      expect(normalizeIdentifier(''), isNull);
    });
  });

  test('isAdult turns true on the 18th birthday', () {
    final born = DateTime(2008, 10, 23);
    expect(isAdult(born, DateTime(2026, 10, 22)), isFalse);
    expect(isAdult(born, DateTime(2026, 10, 23)), isTrue);
  });

  group('token refresh', () {
    late ProviderContainer container;

    setUp(() async {
      fakeLatency = Duration.zero;
      fakeAuthDb.reset();
      final session = fakeAuthDb.sessionFor('fan@demo.ke');
      FlutterSecureStorage.setMockInitialValues({
        accessTokenKey: session['accessToken'] as String,
        refreshTokenKey: session['refreshToken'] as String,
      });
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
    });

    test('a 401 refreshes the session once and retries', () async {
      final before = await secureStorage.read(key: accessTokenKey);
      fakeAuthDb.expireAccessTokens();

      final me = await container.read(dioProvider).get<Map>('/users/me');

      expect(me.data!['identifier'], 'fan@demo.ke');
      expect(await secureStorage.read(key: accessTokenKey), isNot(before));
      expect(container.read(sessionExpiredProvider), 0);
    });

    test('a rejected refresh clears tokens and signals expiry', () async {
      fakeAuthDb.reset(); // invalidates both tokens
      final error = await container
          .read(dioProvider)
          .get<Map>('/users/me')
          .then<Object?>((_) => null, onError: (Object e) => e);

      expect((error as DioException).response?.statusCode, 401);
      expect(await secureStorage.read(key: accessTokenKey), isNull);
      expect(await secureStorage.read(key: refreshTokenKey), isNull);
      expect(container.read(sessionExpiredProvider), 1);
    });
  });

  testWidgets('signed out: welcome, then sign in lands on Discover', (
    tester,
  ) async {
    await pumpApp(tester, signedInAs: null);
    expect(find.text('Create account'), findsOneWidget);

    await _tapText(tester, 'Sign in');
    await _enter(tester, 'login-identifier', 'fan@demo.ke');
    await _enter(tester, 'login-password', 'wrong-password');
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Wrong email/phone or password'), findsOneWidget);

    await _enter(tester, 'login-password', 'password123');
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Discover'), findsWidgets);
  });

  testWidgets('the terms warning clears once the box is ticked', (
    tester,
  ) async {
    await pumpApp(tester, signedInAs: null);
    await _tapText(tester, 'Create account');
    await _enter(tester, 'register-identifier', '0712 345 678');
    await _enter(tester, 'register-password', 'longenough');
    await tester.ensureVisible(find.byKey(const ValueKey('register-submit')));
    await tester.tap(find.byKey(const ValueKey('register-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Accept the terms to continue'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('register-terms')));
    await tester.tap(find.byKey(const ValueKey('register-terms')));
    await tester.pumpAndSettle();
    expect(find.text('Accept the terms to continue'), findsNothing);
  });

  testWidgets('register, verify the OTP, choose creator', (tester) async {
    await pumpApp(tester, signedInAs: null);
    await _tapText(tester, 'Create account');
    await _enter(tester, 'register-identifier', '0712 345 678');
    await _enter(tester, 'register-password', 'longenough');
    await tester.ensureVisible(find.byKey(const ValueKey('register-terms')));
    await tester.tap(find.byKey(const ValueKey('register-terms')));
    await tester.ensureVisible(find.byKey(const ValueKey('register-submit')));
    await tester.tap(find.byKey(const ValueKey('register-submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('+254712345678'), findsOneWidget);
    await _enter(tester, 'verify-code', '000000');
    await tester.tap(find.byKey(const ValueKey('verify-submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('That code is not right'), findsOneWidget);

    await _enter(tester, 'verify-code', fakeOtp);
    await tester.tap(find.byKey(const ValueKey('verify-submit')));
    await tester.pumpAndSettle();
    expect(find.text('How will you use the app?'), findsOneWidget);

    await _tapText(tester, 'Creator');
    expect(find.text('Studio'), findsOneWidget);
    expect(find.text('Discover'), findsNothing);
  });

  testWidgets('age gate: under 18 is refused, adult continues', (tester) async {
    Future<void> enterBirthDate(String date) async {
      await _tapText(tester, 'Enter date of birth');
      await _tapText(tester, 'Type it instead');
      await tester.enterText(find.byType(TextField), date);
      await _tapText(tester, 'OK');
    }

    await pumpApp(tester, adult: false, signedInAs: null);
    expect(find.text('Adults only'), findsOneWidget);

    final now = DateTime.now();
    await enterBirthDate('${now.month}/${now.day}/${now.year - 10}');
    expect(find.textContaining('must be 18 or older'), findsOneWidget);
    expect(find.text('Create account'), findsNothing);
  });

  testWidgets('age gate: an adult birth date opens the welcome screen', (
    tester,
  ) async {
    await pumpApp(tester, adult: false, signedInAs: null);
    await _tapText(tester, 'Enter date of birth');
    await _tapText(tester, 'Type it instead');
    await tester.enterText(find.byType(TextField), '01/15/1990');
    await _tapText(tester, 'OK');
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('log out returns to the welcome screen', (tester) async {
    await pumpApp(tester);
    await _tapText(tester, 'Profile');
    await _tapText(tester, 'Log out');
    expect(find.text('Create account'), findsOneWidget);
    expect(await secureStorage.read(key: accessTokenKey), isNull);
  });
}
