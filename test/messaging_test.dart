import 'package:content/core/api_client.dart';
import 'package:content/core/fake_backend.dart';
import 'package:content/core/prefs.dart';
import 'package:content/features/auth/fake_auth.dart';
import 'package:content/features/content/fake_content.dart';
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

Future<Map> _attachment(Dio dio) async {
  final thread = (await dio.get<Map>('/conversations/conv1/messages')).data!;
  return ((thread['messages'] as List).last as Map)['attachment'] as Map;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('messaging (server rules)', () {
    test('a paid attachment stays hidden until bought', () async {
      final dio = await _dioAs('fan@demo.ke');
      final locked = await _attachment(dio);
      expect(locked['locked'], isTrue);
      expect(locked['mediaId'], isNull);
      expect(
        await _code(dio.get<Object?>('/media/msg-media-1/access')),
        'CONTENT_ACCESS_DENIED',
      );

      final order = (await dio.post<Map>(
        '/orders',
        data: {'type': 'message', 'itemId': 'msg2', 'idempotencyKey': 'a'},
      )).data!;
      expect(order['totalCents'], 10000);
      final payment = (await dio.post<Map>(
        '/orders/${order['id']}/checkout',
        data: {'method': 'mpesa', 'phone': '+254712345678'},
      )).data!;
      await dio.get<Object?>('/payments/${payment['id']}');
      await dio.get<Object?>('/payments/${payment['id']}');

      final unlocked = await _attachment(dio);
      expect(unlocked['locked'], isFalse);
      expect(unlocked['mediaId'], 'msg-media-1');
      expect(
        await _code(dio.get<Object?>('/media/msg-media-1/access')),
        isNull,
      );
    });

    test('blocking stops messages in both directions', () async {
      // The token store is shared, so sign in again before each actor acts.
      Future<String?> creatorSends() async {
        final creator = await _dioAs('creator@demo.ke', reset: false);
        return _code(
          creator.post<Object?>(
            '/conversations/conv1/messages',
            data: {'text': 'hi'},
          ),
        );
      }

      await (await _dioAs('fan@demo.ke')).post<void>('/users/u2/block');
      expect(await creatorSends(), 'BLOCKED');

      await (await _dioAs(
        'fan@demo.ke',
        reset: false,
      )).delete<void>('/users/u2/block');
      expect(await creatorSends(), isNull);
    });

    test('fans cannot open chats with other fans', () async {
      final dio = await _dioAs('fan@demo.ke');
      expect(
        await _code(
          dio.post<Object?>('/conversations', data: {'userId': 'u3'}),
        ),
        'NOT_ALLOWED',
      );
    });

    test('only approved creators can sell in messages', () async {
      final dio = await _dioAs('new@demo.ke');
      final chat = (await dio.post<Map>(
        '/conversations',
        data: {'userId': 'u2'},
      )).data!;
      fakeContentDb.media['own'] = FakeMedia('own', 'u3', 'image');
      expect(
        await _code(
          dio.post<Object?>(
            '/conversations/${chat['id']}/messages',
            data: {
              'text': '',
              'attachment': {'mediaId': 'own', 'priceCents': 5000},
            },
          ),
        ),
        'CREATOR_NOT_APPROVED',
      );
    });

    test('reports about minors are urgent and get a case reference', () async {
      final dio = await _dioAs('fan@demo.ke');
      final urgent = (await dio.post<Map>(
        '/reports',
        data: {'targetType': 'post', 'targetId': 'p2', 'reason': 'minor'},
      )).data!;
      final normal = (await dio.post<Map>(
        '/reports',
        data: {'targetType': 'user', 'targetId': 'u2', 'reason': 'scam'},
      )).data!;
      expect(urgent['priority'], 'urgent');
      expect(normal['priority'], 'normal');
      expect(urgent['caseId'], startsWith('CASE-'));
    });
  });

  testWidgets('fan reads a chat, sees a locked attachment and replies', (
    tester,
  ) async {
    await pumpApp(tester);
    await _tap(tester, find.text('Inbox'));
    await _tap(tester, find.text('Amani'));
    expect(find.text('Thanks for following! 💃'), findsOneWidget);
    expect(find.text('Unlock for KSh 100'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('chat-input')), 'Hello!');
    await _tap(tester, find.byKey(const ValueKey('chat-send')));
    expect(find.text('Hello!'), findsOneWidget);
  });

  testWidgets('message a creator from their page, then report them', (
    tester,
  ) async {
    await pumpApp(tester);
    await _tap(tester, find.text('Zuri Wambui'));
    await _tap(tester, find.byKey(const ValueKey('message-creator')));
    expect(find.text('Zuri Wambui'), findsOneWidget); // chat title

    await _tap(tester, find.byType(PopupMenuButton<String>));
    await _tap(tester, find.text('Report'));
    await _tap(tester, find.text('Spam or scam'));
    await _tap(tester, find.text('Send report'));
    expect(find.textContaining('case reference is CASE-'), findsOneWidget);
  });

  testWidgets('blocking from the chat closes the composer', (tester) async {
    await pumpApp(tester);
    await _tap(tester, find.text('Inbox'));
    await _tap(tester, find.text('Amani'));
    await _tap(tester, find.byType(PopupMenuButton<String>));
    await _tap(tester, find.text('Block'));
    expect(find.text('You can no longer message each other.'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-input')), findsNothing);
  });
}
