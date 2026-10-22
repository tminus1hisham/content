import 'dart:io';
import 'dart:typed_data';

import 'package:content/app/router.dart';
import 'package:content/core/api_client.dart';
import 'package:content/core/fake_backend.dart';
import 'package:content/core/prefs.dart';
import 'package:content/features/auth/fake_auth.dart';
import 'package:content/features/content/fake_content.dart';
import 'package:content/features/content/media_view.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
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

Future<Object?> _result(Future<Response<Object?>> request) =>
    request.then((r) => r.statusCode, onError: (Object e) => apiErrorCode(e));

/// Amani's paid post and its media, from the seed data.
Future<(String postId, String mediaId)> _paidPost(Dio dio) async {
  final posts = (await dio.get<List>('/creators/u2/posts')).data!;
  final paid = posts.firstWhere((p) => p['access'] == 'paid') as Map;
  return (paid['id'] as String, (paid['media'] as List).first['id'] as String);
}

class _FakePicker extends ImagePickerPlatform {
  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async => [
    XFile.fromData(
      File('assets/demo/3.jpg').readAsBytesSync(),
      name: 'pic.jpg',
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

void main() {
  group('content access (server side)', () {
    test('paid media is denied until bought', () async {
      final dio = await _dioAs('fan@demo.ke');
      final (postId, mediaId) = await _paidPost(dio);

      expect(
        await _result(dio.get('/media/$mediaId/access')),
        'CONTENT_ACCESS_DENIED',
      );
      expect((await dio.get<Map>('/posts/$postId')).data!['locked'], isTrue);

      fakeContentDb.grantPurchase('u1', postId);
      expect(await _result(dio.get('/media/$mediaId/access')), 200);
      expect((await dio.get<Map>('/posts/$postId')).data!['locked'], isFalse);
    });

    test('followers-only posts unlock on follow', () async {
      final dio = await _dioAs('fan@demo.ke');
      final post =
          ((await dio.get<List>('/creators/c12/posts')).data!).first as Map;
      expect(post['locked'], isTrue);
      await dio.post<void>('/creators/c12/follow');
      expect(
        (await dio.get<Map>('/posts/${post['id']}')).data!['locked'],
        isFalse,
      );
    });

    test('selling needs approval, a valid price and consent', () async {
      final dio = await _dioAs('new@demo.ke');
      final session = (await dio.post<Map>(
        '/media/upload-sessions',
        data: {'kind': 'image'},
      )).data!;
      fakeContentDb.media[session['id']]!.bytes = Uint8List(1);
      Future<Object?> create(Map<String, Object?> body) => _result(
        dio.post(
          '/posts',
          data: {
            'mediaIds': [session['id']],
            ...body,
          },
        ),
      );

      expect(
        await create({'access': 'paid', 'priceCents': 20000}),
        'CREATOR_NOT_APPROVED',
      );
      expect(
        await create({'access': 'free', 'publish': true}),
        'CONSENT_REQUIRED',
      );
      expect(
        await create({'access': 'free', 'publish': true, 'consent': true}),
        201,
      );

      final approved = await _dioAs('creator@demo.ke');
      final own = (await approved.post<Map>(
        '/media/upload-sessions',
        data: {'kind': 'image'},
      )).data!;
      fakeContentDb.media[own['id']]!.bytes = Uint8List(1);
      expect(
        await _result(
          approved.post(
            '/posts',
            data: {
              'mediaIds': [own['id']],
              'access': 'paid',
              'priceCents': 500,
            },
          ),
        ),
        'PRICE_OUT_OF_RANGE',
      );
    });

    test('discovery searches by name and category', () async {
      final dio = await _dioAs('fan@demo.ke');
      List<String> handles(Response<List> r) => [
        for (final c in r.data!) c['handle'] as String,
      ];
      expect(
        handles(
          await dio.get('/discovery/creators', queryParameters: {'q': 'zur'}),
        ),
        ['zuri'],
      );
      expect(
        handles(
          await dio.get(
            '/discovery/creators',
            queryParameters: {'category': 'Cooking'},
          ),
        ),
        ['neema'],
      );
    });
  });

  testWidgets('fan browses a creator; locked posts never load media', (
    tester,
  ) async {
    await pumpApp(tester);
    await _tap(tester, find.text('Amani'));
    expect(find.text('Unlock for KSh 150'), findsOneWidget);

    await _tap(tester, find.text('Unlock for KSh 150'));
    expect(find.text('Post'), findsOneWidget);
    expect(find.byType(LockedMedia), findsOneWidget);
    expect(find.byType(MediaView), findsNothing);
    expect(find.byKey(const ValueKey('unlock')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const ValueKey('follow')));
    expect(find.text('Following'), findsWidgets);
  });

  testWidgets('approved creator publishes a paid photo', (tester) async {
    ImagePickerPlatform.instance = _FakePicker();
    await pumpApp(
      tester,
      signedInAs: 'creator@demo.ke',
      prefs: {roleKey: 'creator'},
    );
    await _tap(tester, find.text('Studio'));
    await _tap(tester, find.text('New post'));
    await _tap(tester, find.byKey(const ValueKey('composer-photos')));
    expect(find.byType(Image), findsWidgets);
    await tester.enterText(
      find.byKey(const ValueKey('composer-caption')),
      'Studio session',
    );
    await _tap(tester, find.text('Paid'));
    await tester.enterText(find.byKey(const ValueKey('composer-price')), '5');
    await tester.pump();
    expect(
      find.text('Price must be between KSh 10 and KSh 50,000'),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(const ValueKey('composer-price')), '200');
    await tester.pump();
    expect(find.text('Fans pay KSh 200 to unlock'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('composer-consent')));
    await _tap(tester, find.byKey(const ValueKey('composer-publish')));

    expect(find.text('Studio session'), findsOneWidget);
    expect(find.textContaining('Paid · KSh 200'), findsOneWidget);
  });
}
