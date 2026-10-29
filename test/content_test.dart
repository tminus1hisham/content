import 'dart:io';
import 'dart:typed_data';

import 'package:content/app/router.dart';
import 'package:content/core/api_client.dart';
import 'package:content/core/demo_images.dart';
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
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'every demo identity has five local photos and creator posts own theirs',
    () async {
      final dio = await _dioAs('fan@demo.ke');
      final allPhotos = <String>{};
      for (final id in demoPhotoSets.keys) {
        for (var number = 1; number <= 5; number++) {
          final path = demoImageFor(id, number: number)!;
          expect(File(path).existsSync(), isTrue, reason: path);
          expect(allPhotos.add(path), isTrue, reason: 'Shared photo: $path');
        }
      }
      expect(demoImageFor('unseeded-user'), isNull);
      final creators = (await dio.get<List>('/discovery/creators')).data!;
      for (final creator in creators) {
        final id = creator['id'] as String;
        final posts = (await dio.get<List>('/creators/$id/posts')).data!;
        final photos = <String>{};
        for (final post in posts) {
          expect(post['media'], isNotEmpty);
          for (final item in post['media']) {
            final media = fakeContentDb.media[item['id']]!;
            expect(media.ownerId, id);
            expect(
              media.asset,
              startsWith('assets/demo/${demoPhotoSets[id]}-'),
            );
            photos.add(media.asset!);
          }
        }
        expect(photos.length, greaterThanOrEqualTo(5), reason: id);
        final publicPhoto = demoImageFor(id, number: 4);
        expect(
          posts.any(
            (post) =>
                post['access'] == 'free' &&
                (post['media'] as List).any(
                  (item) =>
                      fakeContentDb.media[item['id']]?.asset == publicPhoto,
                ),
          ),
          isTrue,
          reason: 'Avatar and banner must use a free photo: $id',
        );
      }
    },
  );

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

    test('feed is newest first and hides restricted and own posts', () async {
      final dio = await _dioAs('fan@demo.ke');
      List<Map> feed(Response<List> r) => r.data!.cast<Map>();
      final before = feed(await dio.get('/feed'));
      final times = [for (final p in before) p['createdAt'] as String];
      expect(before, isNotEmpty);
      expect(times, [...times]..sort((a, b) => b.compareTo(a)));

      final hidden = before.first['id'] as String;
      fakeContentDb.restrictPost(hidden);
      final after = feed(await dio.get('/feed'));
      expect(after.map((p) => p['id']), isNot(contains(hidden)));
      expect(after, hasLength(before.length - 1));

      final creator = await _dioAs('creator@demo.ke');
      final own = feed(await creator.get('/feed'));
      expect(own.map((p) => p['creator']['id']), isNot(contains('u2')));
    });

    test('likes are idempotent and show on the post', () async {
      final dio = await _dioAs('fan@demo.ke');
      final id = ((await dio.get<List>('/feed')).data!.first as Map)['id'];
      Future<Map> post() async => (await dio.get<Map>('/posts/$id')).data!;
      final start = (await post())['likes'] as int;
      expect((await post())['liked'], false);

      await dio.post('/posts/$id/like');
      final liked = (await dio.post<Map>('/posts/$id/like')).data!;
      expect(liked, {'likes': start + 1, 'liked': true});
      expect(await post(), containsPair('likes', start + 1));
      expect(await post(), containsPair('liked', true));

      final unliked = (await dio.delete<Map>('/posts/$id/like')).data!;
      expect(unliked, {'likes': start, 'liked': false});
      expect(await post(), containsPair('liked', false));
    });

    test('liking an unknown post is 404', () async {
      final dio = await _dioAs('fan@demo.ke');
      expect(await _result(dio.post('/posts/nope/like')), 'NOT_FOUND');
    });
  });

  testWidgets('fan browses a creator; locked posts never load media', (
    tester,
  ) async {
    await pumpApp(tester);
    await openCreator(tester, 'Amani');
    expect(find.text('Unlock for KSh 150'), findsOneWidget);

    await openPostTile(tester, 'Unlock for KSh 150');
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
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('composer-consent')),
      200,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .last,
    );
    await _tap(tester, find.byKey(const ValueKey('composer-consent')));
    await _tap(tester, find.byKey(const ValueKey('composer-publish')));

    expect(find.text('Studio session'), findsOneWidget);
    expect(find.textContaining('Paid · KSh 200'), findsOneWidget);
  });
}
