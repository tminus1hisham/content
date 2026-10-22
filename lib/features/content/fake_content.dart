import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/fake_backend.dart';
import '../auth/fake_auth.dart';
import '../onboarding/fake_onboarding.dart';

/// In-memory media, posts, discovery and follows (IT.md §9.6–9.7).
/// Paid and subscriber access is granted by M6 checkout via [grantPurchase]
/// and [grantSubscription].
const minPriceCents = 1000; // KSh 10
const maxPriceCents = 5000000; // KSh 50,000
const categories = [
  'Fitness',
  'Dance',
  'Music',
  'Comedy',
  'Lifestyle',
  'Fashion',
  'Art',
  'Cooking',
  'Gaming',
  'Education',
];

class FakeMedia {
  FakeMedia(this.id, this.ownerId, this.kind, {this.asset});
  final String id;
  final String ownerId;
  final String kind; // image | video
  final String? asset;
  Uint8List? bytes;
}

class _Post {
  _Post({
    required this.id,
    required this.creatorId,
    required this.caption,
    required this.mediaIds,
    required this.access,
    required this.priceCents,
    required this.status,
    required this.createdAt,
    this.publishAt,
  });
  final String id;
  final String creatorId;
  String caption;
  final List<String> mediaIds;
  final String access; // free | followers | subscribers | paid
  final int? priceCents;
  String status; // draft | scheduled | published | archived | removed
  final DateTime createdAt;
  final DateTime? publishAt;
  int views = 0;
}

class FakeContentDb {
  final media = <String, FakeMedia>{};
  final _posts = <String, _Post>{};
  final _extraCreators = <String, Map<String, Object?>>{};
  final _follows = <String>{}; // 'fanId|creatorId'
  final _purchases = <String>{}; // 'fanId|postId'
  final _subscriptions = <String>{}; // 'fanId|creatorId'
  var _seq = 0;

  FakeContentDb() {
    reset();
  }

  void reset() {
    media.clear();
    _posts.clear();
    _extraCreators.clear();
    _follows.clear();
    _purchases.clear();
    _subscriptions.clear();
    _seq = 0;
    for (final (id, handle, name, bio, cats) in [
      (
        'c10',
        'zuri',
        'Zuri Wambui',
        'Fitness coach. Daily workouts.',
        ['Fitness'],
      ),
      (
        'c11',
        'kofi',
        'Kofi Mensah',
        'Afrobeats producer and singer.',
        ['Music'],
      ),
      (
        'c12',
        'neema',
        'Neema Mushi',
        'Home cooking from Arusha.',
        ['Cooking', 'Lifestyle'],
      ),
    ]) {
      _extraCreators[id] = {
        'displayName': name,
        'handle': handle,
        'bio': bio,
        'categories': cats,
        'language': 'en',
        'location': '',
        'discoverable': true,
      };
    }
    final seeds = [
      ('u2', 'Behind the scenes at rehearsal', 'free', null, 1),
      ('u2', 'Full routine, uncut', 'paid', 15000, 2),
      ('u2', 'Members-only Q&A', 'subscribers', null, 3),
      ('c10', 'Morning stretch routine', 'free', null, 4),
      ('c10', '30-day programme', 'paid', 50000, 5),
      ('c11', 'New single preview', 'free', null, 6),
      ('c12', 'Pilau, my way', 'followers', null, 1),
    ];
    for (final (creatorId, caption, access, price, asset) in seeds) {
      final mediaId = 'm${++_seq}';
      media[mediaId] = FakeMedia(
        mediaId,
        creatorId,
        'image',
        asset: 'assets/demo/$asset.jpg',
      );
      final id = 'p${++_seq}';
      _posts[id] = _Post(
        id: id,
        creatorId: creatorId,
        caption: caption,
        mediaIds: [mediaId],
        access: access,
        priceCents: price,
        status: 'published',
        createdAt: DateTime.utc(2026, 10, 1).add(Duration(hours: _seq)),
      );
    }
  }

  void grantPurchase(String fanId, String postId) =>
      _purchases.add('$fanId|$postId');

  void grantSubscription(String fanId, String creatorId) =>
      _subscriptions.add('$fanId|$creatorId');

  bool isSubscribed(String fanId, String creatorId) =>
      _subscriptions.contains('$fanId|$creatorId');

  /// Public post price, for checkout to price orders on the "server".
  ({String creatorId, int priceCents})? paidPost(String postId) {
    final post = _posts[postId];
    if (post == null || post.access != 'paid' || post.status != 'published') {
      return null;
    }
    return (creatorId: post.creatorId, priceCents: post.priceCents!);
  }

  Map<String, Object?>? creatorProfile(String id) =>
      _extraCreators[id] ??
      (fakeOnboardingDb.isApproved(id) ? fakeOnboardingDb.profileOf(id) : null);

  Iterable<String> get _creatorIds => [
    ..._extraCreators.keys,
    ...fakeOnboardingDb.approvedIds,
  ];

  String? _idForHandle(String handle) => _creatorIds
      .where((id) => creatorProfile(id)?['handle'] == handle)
      .firstOrNull;

  Map<String, Object?> creatorJson(String id, String? viewerId) {
    final profile = creatorProfile(id)!;
    return {
      'id': id,
      'handle': profile['handle'],
      'displayName': profile['displayName'],
      'bio': profile['bio'],
      'categories': profile['categories'],
      'location': profile['location'],
      'verified': true,
      'followers': _follows.where((f) => f.endsWith('|$id')).length,
      'isFollowing': _follows.contains('$viewerId|$id'),
      'isSubscribed': isSubscribed(viewerId ?? '', id),
    };
  }

  bool _canView(_Post post, String viewerId) {
    if (post.creatorId == viewerId) return true;
    if (post.status != 'published') return false;
    return switch (post.access) {
      'free' => true,
      'followers' =>
        _follows.contains('$viewerId|${post.creatorId}') ||
            isSubscribed(viewerId, post.creatorId),
      'subscribers' => isSubscribed(viewerId, post.creatorId),
      'paid' => _purchases.contains('$viewerId|${post.id}'),
      _ => false,
    };
  }

  Map<String, Object?> _postJson(_Post post, String viewerId) {
    final profile = creatorProfile(post.creatorId);
    return {
      'id': post.id,
      'creator': {
        'id': post.creatorId,
        'handle': profile?['handle'],
        'displayName': profile?['displayName'],
      },
      'caption': post.caption,
      'access': post.access,
      'priceCents': post.priceCents,
      'status': post.status,
      'locked': !_canView(post, viewerId),
      'media': [
        for (final id in post.mediaIds) {'id': id, 'kind': media[id]?.kind},
      ],
      'createdAt': post.createdAt.toIso8601String(),
      if (post.publishAt != null)
        'publishAt': post.publishAt!.toIso8601String(),
      if (post.creatorId == viewerId) 'views': post.views,
    };
  }

  List<Map<String, Object?>> _sorted(Iterable<_Post> posts, String viewerId) =>
      [
        for (final p
            in posts.toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
          _postJson(p, viewerId),
      ];

  (int, Object?) _signedIn(
    RequestOptions req,
    (int, Object?) Function(String userId) handle,
  ) {
    final userId = fakeAuthDb.callerId(req);
    return userId == null ? FakeAuthDb.unauthorized : handle(userId);
  }

  static (int, Object?) _error(int status, String code, String message) =>
      (status, {'code': code, 'message': message});

  static const _notFound = (404, {'code': 'NOT_FOUND', 'message': 'Not found'});

  (int, Object?) _ownPost(
    RequestOptions req,
    String id,
    (int, Object?) Function(_Post post, String userId) handle,
  ) => _signedIn(req, (userId) {
    final post = _posts[id];
    if (post == null || post.creatorId != userId) return _notFound;
    return handle(post, userId);
  });

  Map<String, FakeHandler> get routes => {
    'POST /media/upload-sessions': (req, _) => _signedIn(req, (userId) {
      final kind = (req.data as Map)['kind'];
      if (kind != 'image' && kind != 'video') {
        return _error(400, 'UNSUPPORTED_MEDIA', 'Upload a photo or video');
      }
      final id = 'm${++_seq}';
      media[id] = FakeMedia(id, userId, kind as String);
      return (201, {'id': id, 'uploadUrl': 'https://fake.local/upload/$id'});
    }),
    // Stands in for the storage provider's signed upload URL.
    'PUT /upload/{id}': (req, params) {
      final item = media[params['id']];
      if (item == null) return _notFound;
      final data = req.data;
      item.bytes = data is Uint8List
          ? data
          : Uint8List.fromList((data as List).cast<int>());
      return (200, null);
    },
    'POST /media/upload-sessions/{id}/complete': (req, params) =>
        _signedIn(req, (userId) {
          final item = media[params['id']];
          if (item == null || item.ownerId != userId) return _notFound;
          if (item.bytes == null) {
            return _error(409, 'UPLOAD_INCOMPLETE', 'Upload did not finish');
          }
          return (200, {'mediaId': item.id, 'status': 'ready'});
        }),
    'GET /media/{id}/status': (req, params) =>
        (200, {'status': media.containsKey(params['id']) ? 'ready' : 'failed'}),
    'GET /media/{id}/access': (req, params) => _signedIn(req, (userId) {
      final item = media[params['id']];
      if (item == null) return _notFound;
      final allowed =
          item.ownerId == userId ||
          _posts.values.any(
            (p) => p.mediaIds.contains(item.id) && _canView(p, userId),
          );
      if (!allowed) {
        return _error(
          403,
          'CONTENT_ACCESS_DENIED',
          'Unlock this post to view it',
        );
      }
      return (
        200,
        {
          'url': item.asset != null
              ? 'asset://${item.asset}'
              : 'fake-media://${item.id}',
          'kind': item.kind,
          'expiresAt': DateTime.now()
              .add(const Duration(minutes: 5))
              .toUtc()
              .toIso8601String(),
        },
      );
    }),
    'POST /posts': (req, _) => _signedIn(req, (userId) {
      final body = req.data as Map;
      final access = body['access'] as String? ?? 'free';
      final price = body['priceCents'] as int?;
      final publish = body['publish'] == true;
      final mediaIds = ((body['mediaIds'] as List?) ?? []).cast<String>();
      if (mediaIds.isEmpty ||
          mediaIds.any((id) => media[id]?.ownerId != userId)) {
        return _error(400, 'MEDIA_REQUIRED', 'Add a photo or video');
      }
      if (!['free', 'followers', 'subscribers', 'paid'].contains(access)) {
        return _error(400, 'INVALID_ACCESS', 'Choose who can see this');
      }
      if ((access == 'paid' || access == 'subscribers') &&
          !fakeOnboardingDb.isApproved(userId)) {
        return _error(
          403,
          'CREATOR_NOT_APPROVED',
          'Finish creator setup before selling content',
        );
      }
      if (access == 'paid' &&
          (price == null || price < minPriceCents || price > maxPriceCents)) {
        return _error(
          400,
          'PRICE_OUT_OF_RANGE',
          'Price must be between KSh 10 and KSh 50,000',
        );
      }
      if (publish && body['consent'] != true) {
        return _error(
          400,
          'CONSENT_REQUIRED',
          'Confirm everyone shown is an adult who consented',
        );
      }
      final publishAt = body['publishAt'] == null
          ? null
          : DateTime.parse(body['publishAt'] as String);
      final id = 'p${++_seq}';
      _posts[id] = _Post(
        id: id,
        creatorId: userId,
        caption: (body['caption'] as String? ?? '').trim(),
        mediaIds: mediaIds,
        access: access,
        priceCents: access == 'paid' ? price : null,
        status: !publish
            ? 'draft'
            : publishAt != null && publishAt.isAfter(DateTime.now())
            ? 'scheduled'
            : 'published',
        createdAt: DateTime.now().toUtc(),
        publishAt: publishAt,
      );
      return (201, _postJson(_posts[id]!, userId));
    }),
    'GET /posts/{id}': (req, params) => _signedIn(req, (userId) {
      final post = _posts[params['id']];
      if (post == null ||
          (post.creatorId != userId && post.status != 'published')) {
        return _notFound;
      }
      if (post.creatorId != userId) post.views++;
      return (200, _postJson(post, userId));
    }),
    'POST /posts/{id}/publish': (req, params) =>
        _ownPost(req, params['id']!, (post, userId) {
          post.status = 'published';
          return (200, _postJson(post, userId));
        }),
    'POST /posts/{id}/unpublish': (req, params) =>
        _ownPost(req, params['id']!, (post, userId) {
          post.status = 'archived';
          return (200, _postJson(post, userId));
        }),
    // Kept, not erased: purchases must stay traceable (IT.md C9).
    'DELETE /posts/{id}': (req, params) =>
        _ownPost(req, params['id']!, (post, _) {
          post.status = 'removed';
          return (204, null);
        }),
    'GET /creators/me/posts': (req, _) => _signedIn(req, (userId) {
      final status = req.queryParameters['status'];
      return (
        200,
        _sorted(
          _posts.values.where(
            (p) =>
                p.creatorId == userId &&
                p.status != 'removed' &&
                (status == null || p.status == status),
          ),
          userId,
        ),
      );
    }),
    'GET /creators/me/analytics': (req, _) => _signedIn(req, (userId) {
      final own = _posts.values.where(
        (p) => p.creatorId == userId && p.status != 'removed',
      );
      return (
        200,
        {
          'followers': _follows.where((f) => f.endsWith('|$userId')).length,
          'subscribers': _subscriptions
              .where((s) => s.endsWith('|$userId'))
              .length,
          'posts': own.length,
          'views': own.fold<int>(0, (sum, p) => sum + p.views),
        },
      );
    }),
    'GET /creators/{handle}': (req, params) => _signedIn(req, (userId) {
      final id = _idForHandle(params['handle']!);
      return id == null ? _notFound : (200, creatorJson(id, userId));
    }),
    'GET /creators/{id}/posts': (req, params) => _signedIn(req, (userId) {
      return (
        200,
        _sorted(
          _posts.values.where(
            (p) => p.creatorId == params['id'] && p.status == 'published',
          ),
          userId,
        ),
      );
    }),
    'GET /discovery/categories': (_, _) => (200, categories),
    'GET /discovery/creators': (req, _) => _signedIn(req, (userId) {
      final q = (req.queryParameters['q'] as String? ?? '').toLowerCase();
      final category = req.queryParameters['category'] as String?;
      final found = _creatorIds.where((id) {
        final p = creatorProfile(id)!;
        if (id == userId || p['discoverable'] == false) return false;
        if (category != null && !(p['categories'] as List).contains(category)) {
          return false;
        }
        return q.isEmpty ||
            (p['displayName'] as String).toLowerCase().contains(q) ||
            (p['handle'] as String).contains(q);
      });
      return (200, [for (final id in found) creatorJson(id, userId)]);
    }),
    'POST /creators/{id}/follow': (req, params) => _signedIn(req, (userId) {
      if (creatorProfile(params['id']!) == null) return _notFound;
      _follows.add('$userId|${params['id']}');
      return (200, creatorJson(params['id']!, userId));
    }),
    'DELETE /creators/{id}/follow': (req, params) => _signedIn(req, (userId) {
      _follows.remove('$userId|${params['id']}');
      return (200, creatorJson(params['id']!, userId));
    }),
    'GET /fans/me/following': (req, _) => _signedIn(req, (userId) {
      final ids = _follows
          .where((f) => f.startsWith('$userId|'))
          .map((f) => f.split('|')[1]);
      return (200, [for (final id in ids) creatorJson(id, userId)]);
    }),
  };
}

final fakeContentDb = FakeContentDb();
