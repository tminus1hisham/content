import 'package:content/app/theme_controller.dart';
import 'package:content/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _confirm(WidgetTester tester) async {
  final confirm = find.byKey(const ValueKey('confirm-sheet-confirm'));
  await tester.ensureVisible(confirm);
  await tester.pumpAndSettle();
  await tester.tap(confirm);
  await tester.pumpAndSettle();
}

Future<void> _openSettings(WidgetTester tester, String mode) async {
  await pumpApp(tester, prefs: {'theme.mode': mode});
  await _tap(tester, 'Profile');
  await _tap(tester, 'Settings');
}

void main() {
  for (final mode in ['light', 'dark']) {
    testWidgets('settings background follows the accent in $mode mode', (
      tester,
    ) async {
      await _openSettings(tester, mode);
      final screen = find.byType(SettingsScreen);
      final container = ProviderScope.containerOf(tester.element(screen));
      final scaffold = find.descendant(
        of: screen,
        matching: find.byType(Scaffold),
      );
      final before = tester.widget<Scaffold>(scaffold).backgroundColor;
      await container.read(themeControllerProvider.notifier).setAccent(2);
      await tester.pumpAndSettle();
      final scheme = Theme.of(tester.element(scaffold)).colorScheme;
      final after = tester.widget<Scaffold>(scaffold).backgroundColor;
      expect(after, isNot(before));
      expect(
        after,
        Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.07),
          scheme.surface,
        ),
      );
      expect(find.text('fan@demo.ke'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('settings shortcuts and existing destinations remain connected', (
    tester,
  ) async {
    await _openSettings(tester, 'light');
    for (final (label, destination) in [
      ('Appearance', 'Accent colour'),
      ('Notifications', 'Discreet notifications'),
      ('Security', 'Set PIN'),
      ('Privacy', 'Discreet notifications'),
      ('App icon & disguise', 'App icon & disguise'),
    ]) {
      await _tap(tester, label);
      expect(find.text(destination), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    await _tap(tester, 'My profile');
    expect(find.text('Fan account'), findsOneWidget);
    await _tap(tester, 'Settings');
    await _tap(tester, 'Sign out');
    expect(find.text('Sign out?'), findsOneWidget);
    await _confirm(tester);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('cancelling the sign out sheet stays on settings', (
    tester,
  ) async {
    await _openSettings(tester, 'dark');
    await _tap(tester, 'Sign out');
    await tester.tap(find.byKey(const ValueKey('confirm-sheet-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsNothing);
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('settings stays usable on a narrow phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final dispatcher = tester.binding.platformDispatcher;
    dispatcher.textScaleFactorTestValue = 2;
    addTearDown(dispatcher.clearTextScaleFactorTestValue);
    await _openSettings(tester, 'dark');
    expect(
      tester.getTopLeft(find.text('Notifications')).dy,
      greaterThan(tester.getBottomLeft(find.text('Appearance')).dy),
    );
    await _tap(tester, 'Sign out');
    await _confirm(tester);
    expect(find.text('Create account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
