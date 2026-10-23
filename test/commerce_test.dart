import 'package:content/app/router.dart';
import 'package:content/core/api_client.dart';
import 'package:content/core/fake_backend.dart';
import 'package:content/core/prefs.dart';
import 'package:content/features/auth/fake_auth.dart';
import 'package:content/features/commerce/fake_commerce.dart';
import 'package:content/features/content/media_view.dart';
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

Future<String> _paidPostId(Dio dio) async {
  final posts = (await dio.get<List>('/creators/u2/posts')).data!;
  return (posts.firstWhere((p) => p['access'] == 'paid') as Map)['id']
      as String;
}

Future<Map> _buy(
  Dio dio,
  String postId, {
  String phone = '+254712345678',
}) async {
  final order = (await dio.post<Map>(
    '/orders',
    data: {'type': 'post', 'itemId': postId, 'idempotencyKey': 'k-$phone'},
  )).data!;
  final payment = (await dio.post<Map>(
    '/orders/${order['id']}/checkout',
    data: {'method': 'mpesa', 'phone': phone},
  )).data!;
  await dio.get<Map>('/payments/${payment['id']}');
  return (await dio.get<Map>('/payments/${payment['id']}')).data!;
}

int _ledgerTotal() =>
    fakeCommerceDb.ledger.fold<int>(0, (sum, e) => sum + e.amountCents);

Future<String?> _code(Future<Object?> request) =>
    request.then<String?>((_) => null, onError: (Object e) => apiErrorCode(e));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Lets the checkout screen poll twice (the fake settles on the 2nd check).
Future<void> _waitForPayment(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(seconds: 2));
  }
  await tester.pumpAndSettle();
}

void main() {
  group('payments (server rules)', () {
    test(
      'the server prices the order; the same key gives the same order',
      () async {
        final dio = await _dioAs('fan@demo.ke');
        final postId = await _paidPostId(dio);
        Future<Map> order() async => (await dio.post<Map>(
          '/orders',
          data: {
            'type': 'post',
            'itemId': postId,
            'idempotencyKey': 'same',
            'amountCents': 1, // ignored
          },
        )).data!;
        final first = await order();
        final second = await order();
        expect(first['id'], second['id']);
        expect(first['totalCents'], 15000);
      },
    );

    test('a repeated provider callback posts the sale once', () async {
      final dio = await _dioAs('fan@demo.ke');
      final payment = await _buy(dio, await _paidPostId(dio));
      expect(payment['status'], 'succeeded');
      final entries = fakeCommerceDb.ledger.length;

      fakeCommerceDb.providerCallback(payment['id'] as String, success: true);
      await dio.post<void>(
        '/payments/provider-webhooks/mpesa',
        data: {'paymentId': payment['id'], 'resultCode': 0},
      );

      expect(fakeCommerceDb.ledger.length, entries);
      expect(_ledgerTotal(), 0);
    });

    test('a failed payment does not unlock the post', () async {
      final dio = await _dioAs('fan@demo.ke');
      final postId = await _paidPostId(dio);
      final payment = await _buy(dio, postId, phone: '+254712345000');
      expect(payment['status'], 'failed');
      expect((await dio.get<Map>('/posts/$postId')).data!['locked'], isTrue);
    });

    test('a sale credits the creator 80% as pending', () async {
      final fan = await _dioAs('fan@demo.ke');
      await _buy(fan, await _paidPostId(fan));
      final creator = await _dioAs('creator@demo.ke', reset: false);
      final earnings = (await creator.get<Map>('/creators/me/earnings')).data!;
      expect(earnings['pendingCents'], 12000); // KSh 150 - 20%
      expect(earnings['availableCents'], 1245000);
      expect(_ledgerTotal(), 0);
    });

    test('payouts respect the minimum, the balance and idempotency', () async {
      final dio = await _dioAs('creator@demo.ke');
      Future<Object?> request(int cents, [String key = 'p1']) => dio.post(
        '/creators/me/payout-requests',
        data: {
          'amountCents': cents,
          'payoutMethodId': 'pm-u2',
          'idempotencyKey': key,
        },
      );

      final before = (await dio.get<Map>('/creators/me/earnings')).data!;
      expect(await _code(request(50000)), 'AMOUNT_OUT_OF_RANGE');
      expect(await _code(request(1300000)), 'INSUFFICIENT_BALANCE');
      expect(await _code(request(200000)), isNull);
      expect(await _code(request(200000)), isNull); // same key: no new payout

      final earnings = (await dio.get<Map>('/creators/me/earnings')).data!;
      expect(earnings['availableCents'], 1045000);
      expect(
        earnings['reservedCents'],
        (before['reservedCents'] as int) + 200000,
      );
      expect(
        (await dio.get<List>(
          '/creators/me/payout-requests',
        )).data!.where((p) => p['amountCents'] == 200000),
        hasLength(1),
      );
      expect(_ledgerTotal(), 0);
    });
  });

  testWidgets('fan pays with M-Pesa and the post unlocks', (tester) async {
    await pumpApp(tester);
    await _tap(tester, find.text('Amani'));
    await _tap(tester, find.text('Unlock for KSh 150'));
    await _tap(tester, find.byKey(const ValueKey('unlock')));

    expect(find.text('One-time payment. No renewal.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('checkout-phone')),
      '0712 345 678',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.byKey(const ValueKey('checkout-pay')));
    // Short frames: long enough for the request, well before the first poll.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.text('Check your phone'), findsOneWidget);

    await _waitForPayment(tester);
    expect(find.text('Payment received'), findsOneWidget);
    await _tap(tester, find.text('Done'));

    expect(find.byType(LockedMedia), findsNothing);
    expect(find.byType(MediaView), findsWidgets);
  });

  testWidgets('the profile shows Subscribed as soon as checkout is done', (
    tester,
  ) async {
    await pumpApp(tester);
    await _tap(tester, find.text('Amani'));
    await _tap(tester, find.byKey(const ValueKey('subscribe')));
    await tester.enterText(
      find.byKey(const ValueKey('checkout-phone')),
      '0712 345 678',
    );
    await _tap(tester, find.byKey(const ValueKey('checkout-pay')));
    await _waitForPayment(tester);
    expect(find.text('Payment received'), findsOneWidget);
    await _tap(tester, find.text('Done'));

    expect(find.text('Subscribed'), findsOneWidget);
    expect(find.textContaining('Subscribe ·'), findsNothing);
  });

  testWidgets('a failed payment says so and keeps the post locked', (
    tester,
  ) async {
    await pumpApp(tester);
    await _tap(tester, find.text('Amani'));
    await _tap(tester, find.text('Unlock for KSh 150'));
    await _tap(tester, find.byKey(const ValueKey('unlock')));
    await tester.enterText(
      find.byKey(const ValueKey('checkout-phone')),
      '0712 345 000',
    );
    await _tap(tester, find.byKey(const ValueKey('checkout-pay')));
    await _waitForPayment(tester);

    expect(find.text('Payment failed'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(LockedMedia), findsOneWidget);
  });

  testWidgets('a reversed payment says so and keeps the post locked', (
    tester,
  ) async {
    await pumpApp(tester);
    await _tap(tester, find.text('Amani'));
    await _tap(tester, find.text('Unlock for KSh 150'));
    await _tap(tester, find.byKey(const ValueKey('unlock')));
    await tester.enterText(
      find.byKey(const ValueKey('checkout-phone')),
      '0712 345 888',
    );
    await _tap(tester, find.byKey(const ValueKey('checkout-pay')));
    await _waitForPayment(tester);

    expect(find.text('Payment reversed'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(LockedMedia), findsOneWidget);
  });

  testWidgets('creator requests a payout from available earnings', (
    tester,
  ) async {
    await pumpApp(
      tester,
      signedInAs: 'creator@demo.ke',
      prefs: {roleKey: 'creator'},
    );
    await _tap(tester, find.text('Profile'));
    await _tap(tester, find.text('Earnings'));
    Text available() =>
        tester.widget<Text>(find.byKey(const ValueKey('earnings-available')));
    expect(available().data, 'KSh 12,450');

    await _tap(tester, find.text('Request payout'));
    await tester.enterText(find.byKey(const ValueKey('payout-amount')), '2000');
    await _tap(tester, find.byKey(const ValueKey('payout-submit')));
    await _tap(tester, find.text('Confirm'));

    expect(available().data, 'KSh 10,450');
    expect(find.text('Requested'), findsNWidgets(2)); // seeded + this one
  });
}
