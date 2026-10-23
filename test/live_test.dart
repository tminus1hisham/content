import 'dart:convert';

import 'package:content/app/router.dart';
import 'package:content/core/api_client.dart';
import 'package:content/core/fake_backend.dart';
import 'package:content/core/prefs.dart';
import 'package:content/features/auth/fake_auth.dart';
import 'package:content/features/live/live_connection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<Dio> _dioAs(String identifier, {bool reset = true}) async {
  fakeLatency = Duration.zero;
  if (reset) resetFakeBackend();
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

Future<String?> _code(Future<Object?> request) =>
    request.then<String?>((_) => null, onError: (Object e) => apiErrorCode(e));

Future<Map> _pay(Dio dio, Map<String, Object?> order) async {
  final created = (await dio.post<Map>('/orders', data: order)).data!;
  final payment = (await dio.post<Map>(
    '/orders/${created['id']}/checkout',
    data: {'method': 'mpesa', 'phone': '+254712345678'},
  )).data!;
  await dio.get<Object?>('/payments/${payment['id']}');
  return (await dio.get<Map>('/payments/${payment['id']}')).data!;
}

LiveEvent? _parse(String topic, Map<String, Object?> json, String? sender) =>
    parseLiveData(
      topic: topic,
      data: utf8.encode(jsonEncode(json)),
      senderIdentity: sender,
      senderName: 'Someone',
      creatorIdentity: 'creator',
    );

Future<void> _tap(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Pays in checkout: phone, Pay, wait for the fake M-Pesa, Done.
Future<void> _checkout(WidgetTester tester) async {
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
}

void main() {
  group('live data trust rules', () {
    test('tips are only believed from the server', () {
      expect(
        _parse('tip', {'name': 'A', 'amountCents': 100}, null),
        isA<TipEvent>(),
      );
      expect(
        _parse('tip', {'name': 'A', 'amountCents': 100}, 'viewer'),
        isNull,
      );
    });

    test('pins and moderation only from the creator (or server)', () {
      expect(_parse('pin', {'text': 'hi'}, 'creator'), isA<PinEvent>());
      expect(_parse('pin', {'text': 'hi'}, 'viewer'), isNull);
      expect(_parse('moderation', {'muted': 'x'}, 'viewer'), isNull);
      expect(
        _parse('moderation', {'muted': 'x'}, null),
        isA<ModerationEvent>(),
      );
    });

    test('chat needs a participant and drops muted ones', () {
      expect(_parse('chat', {'text': 'yo'}, 'viewer'), isA<ChatEvent>());
      expect(_parse('chat', {'text': 'yo'}, null), isNull);
      expect(
        parseLiveData(
          topic: 'chat',
          data: utf8.encode('{"text":"yo"}'),
          senderIdentity: 'viewer',
          senderName: 'V',
          creatorIdentity: 'creator',
          muted: {'viewer'},
        ),
        isNull,
      );
      expect(
        parseLiveData(
          topic: 'chat',
          data: utf8.encode('not json'),
          senderIdentity: 'viewer',
          senderName: 'V',
          creatorIdentity: 'creator',
        ),
        isNull,
      );
    });
  });

  group('live sessions (server rules)', () {
    test('a ticketed stream needs a ticket before a token', () async {
      final dio = await _dioAs('fan@demo.ke');
      expect(
        await _code(dio.post<Object?>('/live/sessions/live2/token')),
        'LIVE_ACCESS_DENIED',
      );
      final payment = await _pay(dio, {
        'type': 'ticket',
        'itemId': 'live2',
        'idempotencyKey': 't',
      });
      expect(payment['status'], 'succeeded');
      expect(
        await _code(dio.post<Object?>('/live/sessions/live2/token')),
        isNull,
      );
    });

    test('going live needs approval and the safety confirmation', () async {
      final newbie = await _dioAs('new@demo.ke');
      expect(
        await _code(
          newbie.post<Object?>(
            '/live/sessions',
            data: {'title': 'Hi', 'access': 'free', 'safetyConfirmed': true},
          ),
        ),
        'CREATOR_NOT_APPROVED',
      );
      final creator = await _dioAs('creator@demo.ke', reset: false);
      expect(
        await _code(
          creator.post<Object?>(
            '/live/sessions',
            data: {'title': 'Hi', 'access': 'free'},
          ),
        ),
        'SAFETY_CHECK_REQUIRED',
      );
    });

    test(
      'a removed viewer cannot rejoin; tips add up in the summary',
      () async {
        final creator = await _dioAs('creator@demo.ke');
        final session = (await creator.post<Map>(
          '/live/sessions',
          data: {'title': 'Q&A', 'access': 'free', 'safetyConfirmed': true},
        )).data!;
        await creator.post<void>(
          '/live/sessions/${session['id']}/moderation',
          data: {'action': 'remove', 'identity': 'u1'},
        );

        final fan = await _dioAs('fan@demo.ke', reset: false);
        expect(
          await _code(
            fan.post<Object?>('/live/sessions/${session['id']}/token'),
          ),
          'REMOVED_FROM_LIVE',
        );
        expect(
          await _code(
            fan.post<Object?>(
              '/orders',
              data: {'type': 'tip', 'itemId': session['id'], 'amountCents': 5},
            ),
          ),
          'PRICE_OUT_OF_RANGE',
        );
        await _pay(fan, {
          'type': 'tip',
          'itemId': session['id'],
          'amountCents': 20000,
          'idempotencyKey': 'tip1',
        });

        final again = await _dioAs('creator@demo.ke', reset: false);
        final summary = (await again.post<Map>(
          '/live/sessions/${session['id']}/end',
        )).data!;
        expect(summary['tipsCents'], 20000);
      },
    );
  });

  testWidgets('fan joins a free stream and chats', (tester) async {
    await pumpApp(tester);
    await _tap(tester, find.text('Live'));
    await _tap(tester, find.text('Morning HIIT, live'));

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('live-viewers'))).data,
      '3',
    );
    await tester.enterText(
      find.byKey(const ValueKey('live-chat-input')),
      'Jambo!',
    );
    await _tap(tester, find.byKey(const ValueKey('live-chat-send')));
    expect(find.textContaining('Jambo!'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    expect(find.textContaining('Hello from Nakuru'), findsOneWidget);
    expect(find.text("Video isn't available in this demo."), findsOneWidget);
    expect(find.textContaining('--dart-define'), findsNothing);
  });

  testWidgets('a ticketed stream asks for a ticket, then lets the fan in', (
    tester,
  ) async {
    await pumpApp(tester);
    await _tap(tester, find.text('Live'));
    await _tap(tester, find.text('Studio session: new beats'));
    expect(find.text('Buy ticket · KSh 200'), findsOneWidget);

    await _tap(tester, find.byKey(const ValueKey('live-buy')));
    await _checkout(tester);
    expect(find.byKey(const ValueKey('live-chat-input')), findsOneWidget);
  });

  testWidgets('fan tips during a stream and the tip shows in chat', (
    tester,
  ) async {
    await pumpApp(tester);
    await _tap(tester, find.text('Live'));
    await _tap(tester, find.text('Morning HIIT, live'));
    await _tap(tester, find.byKey(const ValueKey('live-tip')));
    await _tap(tester, find.text('KSh 100'));
    await _checkout(tester);
    expect(find.textContaining('sent a KSh 100 tip'), findsOneWidget);
  });

  testWidgets('creator goes live, mutes a viewer, pins and ends', (
    tester,
  ) async {
    await pumpApp(
      tester,
      signedInAs: 'creator@demo.ke',
      prefs: {roleKey: 'creator'},
    );
    await _tap(
      tester,
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Go live'),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('live-title')),
      'Late night chat',
    );
    await _tap(tester, find.byKey(const ValueKey('live-safety')));
    await _tap(tester, find.byKey(const ValueKey('live-start')));
    expect(find.text('Late night chat'), findsOneWidget);
    expect(find.byKey(const ValueKey('live-end')), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    await _tap(tester, find.textContaining('Hello from Nakuru'));
    await _tap(tester, find.text('Pin message'));
    expect(find.byKey(const ValueKey('live-pin')), findsOneWidget);

    await _tap(tester, find.textContaining('Hello from Nakuru').last);
    await _tap(tester, find.text('Mute Wanjiku'));
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.textContaining('Hello from Nakuru'),
      ),
      findsNothing,
    );

    await _tap(tester, find.byKey(const ValueKey('live-end')));
    await _tap(tester, find.text('End').last); // the dialog's button
    expect(find.text('Stream ended'), findsOneWidget);
    await _tap(tester, find.text('Done'));
    expect(find.byKey(const ValueKey('live-title')), findsOneWidget);
  });
}
