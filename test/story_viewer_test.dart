import 'package:content/features/content/home_feed.dart';
import 'package:content/features/content/media_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

final _viewer = find.byKey(const ValueKey('story-viewer'));

/// The visible segment's `Story from <name>, <i> of <n>` label.
String _segment(WidgetTester tester) => tester
    .widget<Semantics>(find.byKey(const ValueKey('story-segment')))
    .properties
    .label!;

/// Seeded tray: c10 and c11 are live; Neema (c12) is the first story.
Future<void> _openNeema(WidgetTester tester) async {
  await pumpApp(tester);
  await tester.tap(find.byKey(const ValueKey('story-c12')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await _frame(tester);
}

/// One more frame: lets the progress ticker start and media requests land.
Future<void> _frame(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 16));

Future<void> _tapRight(WidgetTester tester) async {
  final size = tester.getSize(_viewer);
  await tester.tapAt(Offset(size.width * 0.85, size.height / 2));
  await tester.pump();
  await _frame(tester);
}

void main() {
  // The viewer auto-advances, so these pump fixed durations, never settle.
  testWidgets('tapping a tray story opens the viewer on that creator', (
    tester,
  ) async {
    await _openNeema(tester);
    expect(_viewer, findsOneWidget);
    expect(_segment(tester), 'Story from Neema Mushi, 1 of 3');
  });

  testWidgets('tapping the right side advances the segment', (tester) async {
    await _openNeema(tester);
    await _tapRight(tester);
    expect(_segment(tester), 'Story from Neema Mushi, 2 of 3');
  });

  testWidgets('the last segment moves on to the next creator', (tester) async {
    await _openNeema(tester);
    for (var i = 0; i < 3; i++) {
      await _tapRight(tester);
    }
    await tester.pump(const Duration(milliseconds: 400));
    await _frame(tester);
    expect(_segment(tester), isNot(startsWith('Story from Neema Mushi')));
    expect(_segment(tester), endsWith('1 of 3'));
  });

  testWidgets('close returns to the home', (tester) async {
    await _openNeema(tester);
    await tester.tap(
      find.descendant(of: _viewer, matching: find.byTooltip('Close')),
    );
    await tester.pumpAndSettle();
    expect(_viewer, findsNothing);
    expect(find.byType(StoriesTray), findsOneWidget);
  });

  testWidgets('progress auto-advances after five seconds', (tester) async {
    await _openNeema(tester);
    expect(_segment(tester), endsWith('1 of 3'));
    await tester.pump(const Duration(seconds: 5));
    await _frame(tester);
    expect(_segment(tester), 'Story from Neema Mushi, 2 of 3');
  });

  testWidgets('a locked segment shows LockedMedia and no MediaView', (
    tester,
  ) async {
    await _openNeema(tester);
    var sawLocked = false;
    for (var i = 0; i < 3; i++) {
      final locked = find.descendant(
        of: _viewer,
        matching: find.byType(LockedMedia),
      );
      if (locked.evaluate().isNotEmpty) {
        sawLocked = true;
        expect(
          find.descendant(of: _viewer, matching: find.byType(MediaView)),
          findsNothing,
        );
      }
      if (i < 2) await _tapRight(tester);
    }
    expect(sawLocked, isTrue);
  });

  testWidgets('the View post pill fits at 200% text with manual navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    final dispatcher = tester.platformDispatcher;
    dispatcher.textScaleFactorTestValue = 2.0;
    dispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      accessibleNavigation: true,
    );
    addTearDown(() {
      tester.view.reset();
      dispatcher.clearTextScaleFactorTestValue();
      dispatcher.clearAccessibilityFeaturesTestValue();
    });
    await _openNeema(tester);
    expect(find.text('View post'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
