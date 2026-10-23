import 'package:content/app/schedule_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 23, 19, 30);
  DateTime? result;

  Future<void> open(WidgetTester tester) async {
    result = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  result = await showSchedulePicker(context, now: now),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  ChoiceChip chip(WidgetTester tester, String label) =>
      tester.widget(find.widgetWithText(ChoiceChip, label));

  testWidgets('picking a day and slot returns that DateTime', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('schedule-day-1')));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, '6:00 PM'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('schedule-confirm')));
    await tester.pumpAndSettle();
    expect(result, DateTime(2026, 10, 24, 18, 0));
  });

  testWidgets('past slots are disabled on today only', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('schedule-day-0')));
    await tester.pump();
    expect(chip(tester, '6:00 PM').onSelected, isNull);
    expect(chip(tester, '8:00 PM').onSelected, isNotNull);
    await tester.tap(find.byKey(const Key('schedule-day-1')));
    await tester.pump();
    expect(chip(tester, '6:00 PM').onSelected, isNotNull);
  });

  testWidgets('confirm is disabled until a time is chosen', (tester) async {
    await open(tester);
    FilledButton button() =>
        tester.widget(find.byKey(const Key('schedule-confirm')));
    expect(button().onPressed, isNull);
    await tester.tap(find.byKey(const Key('schedule-day-1')));
    await tester.pump();
    expect(button().onPressed, isNull);
    await tester.tap(find.widgetWithText(ChoiceChip, '9:00 AM'));
    await tester.pump();
    expect(button().onPressed, isNotNull);
  });

  testWidgets('a time that has passed says so instead of "Goes live"', (
    tester,
  ) async {
    await open(tester);
    // 9:00 AM tomorrow, then switch the day to today: 9:00 AM has passed.
    await tester.tap(find.byKey(const Key('schedule-day-1')));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, '9:00 AM'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('schedule-day-0')));
    await tester.pump();
    expect(
      find.text('That time has passed. Pick a later one.'),
      findsOneWidget,
    );
    expect(find.textContaining('Goes live'), findsNothing);
  });
}
