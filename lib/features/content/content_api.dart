import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../auth/auth_controller.dart';

class Creator {
  const Creator({
    required this.id,
    required this.handle,
    required this.displayName,
    required this.bio,
    required this.categories,
    required this.followers,
    required this.isFollowing,
    required this.isSubscribed,
  });

  factory Creator.fromJson(Map<String, dynamic> json) => Creator(
    id: json['id'] as String,
    handle: json['handle'] as String,
    displayName: json['displayName'] as String,
    bio: json['bio'] as String? ?? '',
    categories: (json['categories'] as List? ?? []).cast<String>(),
    followers: json['followers'] as int? ?? 0,
    isFollowing: json['isFollowing'] as bool? ?? false,
    isSubscribed: json['isSubscribed'] as bool? ?? false,
  );

  final String id;
  final String handle;
  final String displayName;
  final String bio;
  final List<String> categories;
  final int followers;
  final bool isFollowing;
  final bool isSubscribed;
}

class PostMedia {
  const PostMedia(this.id, this.kind);
  final String id;
  final String kind; // image | video
}

class Post {
  const Post({
    required this.id,
    required this.creatorId,
    required this.creatorHandle,
    required this.creatorName,
    required this.caption,
    required this.access,
    required this.priceCents,
    required this.status,
    required this.locked,
    required this.media,
    this.publishAt,
    this.views,
    this.createdAt,
    this.likes = 0,
    this.liked = false,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'] as Map<String, dynamic>;
    return Post(
      id: json['id'] as String,
      creatorId: creator['id'] as String,
      creatorHandle: creator['handle'] as String? ?? '',
      creatorName: creator['displayName'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
      access: json['access'] as String,
      priceCents: json['priceCents'] as int?,
      status: json['status'] as String,
      locked: json['locked'] as bool,
      media: [
        for (final m in json['media'] as List)
          PostMedia(m['id'] as String, m['kind'] as String? ?? 'image'),
      ],
      publishAt: json['publishAt'] == null
          ? null
          : DateTime.parse(json['publishAt'] as String).toLocal(),
      views: json['views'] as int?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String).toLocal(),
      likes: json['likes'] as int? ?? 0,
      liked: json['liked'] as bool? ?? false,
    );
  }

  final String id;
  final String creatorId;
  final String creatorHandle;
  final String creatorName;
  final String caption;

  /// free | followers | subscribers | paid
  final String access;
  final int? priceCents;

  /// draft | scheduled | published | archived
  final String status;
  final bool locked;
  final List<PostMedia> media;
  final DateTime? publishAt;
  final int? views;
  final DateTime? createdAt;
  final int likes;
  final bool liked;
}

const accessLabels = {
  'free': 'Free',
  'followers': 'Followers',
  'subscribers': 'Subscribers',
  'paid': 'Paid',
};

Future<T> _get<T>(Ref ref, String path, [Map<String, dynamic>? query]) async =>
    (await ref.read(dioProvider).get<T>(path, queryParameters: query)).data
        as T;

List<Creator> _creators(List<dynamic> json) => [
  for (final c in json) Creator.fromJson(c as Map<String, dynamic>),
];

List<Post> _posts(List<dynamic> json) => [
  for (final p in json) Post.fromJson(p as Map<String, dynamic>),
];

final categoriesProvider = FutureProvider<List<String>>(
  (ref) async =>
      (await _get<List<dynamic>>(ref, '/discovery/categories')).cast<String>(),
);

final discoveryProvider = FutureProvider.autoDispose
    .family<List<Creator>, ({String query, String? category})>(
      (ref, filter) async => _creators(
        await _get<List<dynamic>>(ref, '/discovery/creators', {
          if (filter.query.isNotEmpty) 'q': filter.query,
          'category': ?filter.category,
        }),
      ),
    );

final followingProvider = FutureProvider.autoDispose<List<Creator>>(
  (ref) async =>
      _creators(await _get<List<dynamic>>(ref, '/fans/me/following')),
);

final creatorProvider = FutureProvider.autoDispose.family<Creator, String>(
  (ref, handle) async => Creator.fromJson(
    await _get<Map<String, dynamic>>(ref, '/creators/$handle'),
  ),
);

final creatorPostsProvider = FutureProvider.autoDispose
    .family<List<Post>, String>(
      (ref, creatorId) async =>
          _posts(await _get<List<dynamic>>(ref, '/creators/$creatorId/posts')),
    );

final postProvider = FutureProvider.autoDispose.family<Post, String>(
  (ref, id) async =>
      Post.fromJson(await _get<Map<String, dynamic>>(ref, '/posts/$id')),
);

final myPostsProvider = FutureProvider.autoDispose.family<List<Post>, String>(
  (ref, status) async => _posts(
    await _get<List<dynamic>>(ref, '/creators/me/posts', {'status': status}),
  ),
);

final feedProvider = FutureProvider.autoDispose<List<Post>>(
  (ref) async => _posts(await _get<List<dynamic>>(ref, '/feed')),
);

final analyticsProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) => _get<Map<String, dynamic>>(ref, '/creators/me/analytics'),
);

/// Short-lived delivery URL for a media item, or a 403
/// `CONTENT_ACCESS_DENIED`. Auto-disposed so it is re-requested, never kept.
final mediaAccessProvider = FutureProvider.autoDispose
    .family<({String url, String kind}), String>((ref, mediaId) async {
      final json = await _get<Map<String, dynamic>>(
        ref,
        '/media/$mediaId/access',
      );
      return (url: json['url'] as String, kind: json['kind'] as String);
    });

Future<Creator> setFollowing(Dio dio, String creatorId, bool follow) async {
  final path = '/creators/$creatorId/follow';
  final response = follow
      ? await dio.post<Map<String, dynamic>>(path)
      : await dio.delete<Map<String, dynamic>>(path);
  return Creator.fromJson(response.data!);
}

Future<({int likes, bool liked})> setLiked(
  Dio dio,
  String postId,
  bool like,
) async {
  final path = '/posts/$postId/like';
  final response = like
      ? await dio.post<Map<String, dynamic>>(path)
      : await dio.delete<Map<String, dynamic>>(path);
  return (
    likes: response.data!['likes'] as int,
    liked: response.data!['liked'] as bool,
  );
}

/// Optimistic like state by post id, shared by the feed and the story viewer
/// so it survives a post scrolling away. Cleared when the feed is refreshed
/// or the signed-in account changes.
final likeOverridesProvider =
    StateProvider<Map<String, ({int likes, bool liked})>>((ref) {
      // Another account on this device must not inherit these hearts.
      ref.watch(authProvider.select((a) => a.user?.id));
      return {};
    });

/// Latest like request per post: only that one may touch the shown state.
final _likeSeq = <String, int>{};

/// Optimistic like/unlike. Applies the server's count only if no later tap
/// has happened; rolls back to the pre-tap value only on error of the latest.
/// Rethrows so the caller can show the error.
Future<void> toggleLike(
  Dio dio,
  StateController<Map<String, ({int likes, bool liked})>> store,
  Post post,
  bool like,
) async {
  void put(({int likes, bool liked}) v) =>
      store.state = {...store.state, post.id: v};
  final before = store.state[post.id] ?? (likes: post.likes, liked: post.liked);
  final seq = _likeSeq[post.id] = (_likeSeq[post.id] ?? 0) + 1;
  put((likes: before.likes + (like ? 1 : -1), liked: like));
  try {
    final r = await setLiked(dio, post.id, like);
    if (_likeSeq[post.id] == seq) put(r);
  } catch (_) {
    if (_likeSeq[post.id] == seq) put(before);
    rethrow;
  }
}

/// Upload session → PUT to the signed URL → complete. Returns the media id.
// ponytail: one PUT per file; switch to the storage provider's resumable
// protocol (tus / multipart) once the Spring API picks it (FR-CNT-002).
Future<String> uploadMedia(
  Dio dio,
  Dio uploadDio,
  XFile file,
  String kind,
) async {
  final bytes = await file.readAsBytes();
  final session = (await dio.post<Map<String, dynamic>>(
    '/media/upload-sessions',
    data: {
      'kind': kind,
      'mimeType':
          file.mimeType ?? (kind == 'video' ? 'video/mp4' : 'image/jpeg'),
      'size': bytes.length,
    },
  )).data!;
  await uploadDio.put<void>(
    session['uploadUrl'] as String,
    data: bytes,
    options: Options(contentType: 'application/octet-stream'),
  );
  await dio.post<void>('/media/upload-sessions/${session['id']}/complete');
  return session['id'] as String;
}
