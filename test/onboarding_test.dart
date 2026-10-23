import 'package:content/app/router.dart';
import 'package:content/core/api_client.dart';
import 'package:content/core/fake_backend.dart';
import 'package:content/core/prefs.dart';
import 'package:content/features/auth/fake_auth.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<Dio> _dioAs(String identifier) async {
  fakeLatency = Duration.zero;
  resetFakeBackend();
  final session = fakeAuthDb.sessionFor(identifier);
  FlutterSecureStorage.setMockInitialValues({
    accessTokenKey: session['accessToken'] as String,
  });
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container.read(dioProvider);
}

Future<String?> _errorCode(Future<Object?> request) =>
    request.then<String?>((_) => null, onError: (Object e) => apiErrorCode(e));

/// Scrolls [finder] into view, then taps it. Focus is dropped first: a
/// focused text field keeps scrolling its caret back on screen.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) =>
    _tap(tester, find.byKey(ValueKey(key)));

Future<void> _tapText(WidgetTester tester, String text) =>
    _tap(tester, find.text(text).last);

void main() {
  group('onboarding API rules', () {
    test('signing an outdated version or hash is refused', () async {
      final dio = await _dioAs('new@demo.ke');
      final offer = (await dio.get<Map>(
        '/contracts/offers/offer-standard',
      )).data!;
      Future<Object?> sign(Map<String, Object?> overrides) => dio.post<void>(
        '/contracts/offers/offer-standard/sign',
        data: {
          'version': offer['version'],
          'documentHash': offer['documentHash'],
          'signatureName': 'Zawadi Achieng',
          'consentToElectronicSignature': true,
          ...overrides,
        },
      );

      expect(await _errorCode(sign({'version': 'v0.9'})), 'VERSION_MISMATCH');
      expect(
        await _errorCode(sign({'documentHash': 'tampered'})),
        'VERSION_MISMATCH',
      );
      expect(
        await _errorCode(sign({'consentToElectronicSignature': false})),
        'SIGNATURE_INVALID',
      );
      expect(await _errorCode(sign({})), isNull);
      expect(
        (await dio.get<List>('/creators/me/contracts')).data,
        hasLength(1),
      );
    });

    test('cannot submit for review until every step is done', () async {
      final dio = await _dioAs('new@demo.ke');
      expect(
        await _errorCode(dio.post<void>('/creators/me/submit-review')),
        'ONBOARDING_INCOMPLETE',
      );
    });

    test('handles are unique', () async {
      final dio = await _dioAs('new@demo.ke');
      expect(
        await _errorCode(
          dio.patch<void>(
            '/creators/me',
            data: {'displayName': 'X', 'handle': 'Amani'},
          ),
        ),
        'HANDLE_TAKEN',
      );
    });
  });

  testWidgets('a new creator completes every step and submits for review', (
    tester,
  ) async {
    await pumpApp(
      tester,
      signedInAs: 'new@demo.ke',
      prefs: {roleKey: 'creator'},
    );
    await _tapText(tester, 'Finish setting up to start earning');
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Submit for review'),
          )
          .onPressed,
      isNull,
    );

    // C2 identity
    await _tapText(tester, 'Age and identity');
    await _tapText(tester, 'Start verification');
    await _tapText(tester, 'Check my result');
    expect(find.text('You are verified.'), findsOneWidget);
    await _tapText(tester, 'Back to setup');

    // C3 profile, with a taken handle first
    await _tapText(tester, 'Creator profile');
    await tester.enterText(
      find.byKey(const ValueKey('profile-name')),
      'Zawadi',
    );
    await tester.enterText(
      find.byKey(const ValueKey('profile-handle')),
      'amani',
    );
    await _tapKey(tester, 'profile-save');
    expect(find.text('That handle is taken'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('profile-handle')),
      'zawadi',
    );
    await _tapKey(tester, 'profile-save');

    // C4 contract: sign is disabled until scrolled to the end
    await _tapText(tester, 'Creator agreement');
    expect(find.text('Platform commission: 20%'), findsOneWidget);
    expect(find.text('Read to the end to sign'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('contract-sign')))
          .onPressed,
      isNull,
    );
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('contract-signature')),
      find.byKey(const ValueKey('contract-scroll')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('contract-signature')),
      'Zawadi Achieng',
    );
    // With the keyboard open, the sign button sits above it, not behind it.
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pumpAndSettle();
    final keyboardTop =
        (tester.view.physicalSize.height - 900) / tester.view.devicePixelRatio;
    expect(
      tester.getRect(find.byKey(const ValueKey('contract-sign'))).bottom,
      lessThanOrEqualTo(keyboardTop),
    );
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await _tapKey(tester, 'contract-consent');
    await _tapKey(tester, 'contract-sign');

    // C5 payout
    await _tapText(tester, 'Payout method');
    await tester.enterText(
      find.byKey(const ValueKey('payout-phone')),
      '0722 000 111',
    );
    await tester.enterText(
      find.byKey(const ValueKey('payout-name')),
      'Zawadi Achieng',
    );
    await _tapKey(tester, 'payout-save');
    expect(find.textContaining('+254 ••• 111'), findsWidgets);
    await tester.enterText(find.byKey(const ValueKey('payout-code')), fakeOtp);
    await _tapKey(tester, 'payout-verify');
    // Verifying returns to the step list, like the other steps.
    expect(find.text('Replace destination'), findsNothing);
    expect(find.text('Submit for review'), findsOneWidget);

    await _tapText(tester, 'Submit for review');
    expect(find.text('Under review'), findsOneWidget);
  });
}
