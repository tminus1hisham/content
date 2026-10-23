import 'dart:io';

import 'package:content/app/router.dart';
import 'package:content/features/content/media_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'helpers.dart';

/// The commercial loop from IT.md §14, end to end through the UI: an
/// approved creator publishes a paid photo, a fan finds it, pays with M-Pesa
/// and only then sees it. (A widget test, so it runs headless in CI.)
class _FakePicker extends ImagePickerPlatform {
  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async => [
    XFile.fromData(
      File('assets/demo/6.jpg').readAsBytesSync(),
      name: 'sunset.jpg',
      mimeType: 'image/jpeg',
    ),
  ];
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _tab(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  testWidgets('creator sells a photo; a fan buys it and it unlocks', (
    tester,
  ) async {
    ImagePickerPlatform.instance = _FakePicker();
    await pumpApp(
      tester,
      signedInAs: 'creator@demo.ke',
      prefs: {roleKey: 'creator'},
    );

    // Creator publishes a KSh 300 photo.
    await _tap(tester, _tab('Studio'));
    await _tap(tester, find.text('New post'));
    await _tap(tester, find.byKey(const ValueKey('composer-photos')));
    await tester.enterText(
      find.byKey(const ValueKey('composer-caption')),
      'Sunset set',
    );
    await _tap(tester, find.text('Paid'));
    await tester.enterText(find.byKey(const ValueKey('composer-price')), '300');
    await _tap(tester, find.byKey(const ValueKey('composer-consent')));
    await _tap(tester, find.byKey(const ValueKey('composer-publish')));
    expect(find.text('Sunset set'), findsOneWidget);

    // Creator signs out; the fan signs in.
    await _tap(tester, _tab('Profile'));
    await _tap(tester, find.text('Log out'));
    await _tap(tester, find.text('Sign in'));
    await tester.enterText(
      find.byKey(const ValueKey('login-identifier')),
      'fan@demo.ke',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password')),
      'password123',
    );
    await _tap(tester, find.byKey(const ValueKey('login-submit')));
    expect(_tab('Discover'), findsOneWidget);

    // The fan finds it locked, pays, and it unlocks.
    await _tap(tester, find.text('Amani'));
    await _tap(tester, find.text('Unlock for KSh 300'));
    expect(find.byType(MediaView), findsNothing);
    await _tap(tester, find.byKey(const ValueKey('unlock')));
    await tester.enterText(
      find.byKey(const ValueKey('checkout-phone')),
      '0712 345 678',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.byKey(const ValueKey('checkout-pay')));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 2));
    }
    await tester.pumpAndSettle();
    expect(find.text('Payment received'), findsOneWidget);
    await _tap(tester, find.text('Done'));

    expect(find.byType(LockedMedia), findsNothing);
    expect(find.byType(MediaView), findsOneWidget);
    // The outer list, not the image carousel inside it.
    await tester.scrollUntilVisible(
      find.text('Sunset set'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Sunset set'), findsOneWidget);
  });
}
