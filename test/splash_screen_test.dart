import 'package:content/core/prefs.dart';
import 'package:content/features/auth/auth_screens.dart';
import 'package:content/features/disguise/disguise_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpSplash(
  WidgetTester tester, {
  Disguise disguise = Disguise.none,
  bool reduceMotion = false,
}) async {
  SharedPreferences.setMockInitialValues({disguiseKey: disguise.name});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: reduceMotion,
            textScaler: TextScaler.linear(reduceMotion ? 2 : 1),
          ),
          child: const SplashScreen(),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows Raha branding and an accessible startup indicator', (
    tester,
  ) async {
    await pumpSplash(tester);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Raha'), findsOneWidget);
    expect(find.text('Closer to what you love.'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .semanticsLabel,
      'Loading Raha',
    );
    expect(tester.takeException(), isNull);
  });

  for (final disguise in Disguise.values.where(
    (value) => value != Disguise.none,
  )) {
    testWidgets('preserves the ${disguise.label} identity during startup', (
      tester,
    ) async {
      await pumpSplash(tester, disguise: disguise);
      expect(find.text(disguise.label), findsOneWidget);
      expect(find.byIcon(disguise.icon), findsOneWidget);
      expect(find.text('Raha'), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  }

  testWidgets('supports reduced motion and large text on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpSplash(tester, reduceMotion: true);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.6,
    );
    expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 1);
    expect(tester.takeException(), isNull);
  });
}
