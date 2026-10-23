import 'package:content/app/birth_date_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime? result;

  Future<void> open(WidgetTester tester) async {
    result = null;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en', 'US'), Locale('en', 'GB')],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showBirthDatePicker(
                    context,
                    now: DateTime(2026, 10, 23),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  void moveWheel(WidgetTester tester, DateTime to) {
    tester
        .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
        .onDateTimeChanged(to);
  }

  testWidgets('Continue is disabled until the wheel moves', (tester) async {
    await open(tester);
    expect(find.text('Scroll to your birthday'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('dob-continue')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('an adult date shows the age and Continue returns it', (
    tester,
  ) async {
    await open(tester);
    moveWheel(tester, DateTime(1990, 1, 15));
    await tester.pump();
    expect(find.text('36 years'), findsOneWidget);
    expect(find.text('15 January 1990'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dob-continue')));
    await tester.pumpAndSettle();
    expect(result, DateTime(1990, 1, 15));
  });

  testWidgets('an under-18 date uses the error colours', (tester) async {
    await open(tester);
    moveWheel(tester, DateTime(2015, 1, 1));
    await tester.pump();
    expect(find.text('11 years'), findsOneWidget);
    final scheme = Theme.of(tester.element(find.text('11 years'))).colorScheme;
    expect(
      tester.widget<Text>(find.text('11 years')).style?.color,
      scheme.onErrorContainer,
    );
  });

  testWidgets('typed date is read as dd/mm/yyyy', (tester) async {
    await open(tester);
    await tester.tap(find.text('Type it instead'));
    await tester.pumpAndSettle();
    expect(find.text('dd/mm/yyyy'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '15/06/1995');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(result, DateTime(1995, 6, 15));
  });
}
