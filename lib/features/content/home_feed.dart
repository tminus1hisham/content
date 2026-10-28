import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../app/ui.dart';
import '../../core/api_client.dart';
import '../live/live_screens.dart';
import 'content_api.dart';
import 'discover_screens.dart';
import 'media_view.dart';
import 'story_viewer.dart';

/// Bumped by the shell when the fan re-taps the Discover tab: scroll to top.
final homeScrollTopProvider = StateProvider<int>((_) => 0);

/// Creators whose stories the fan has opened.
// ponytail: in-memory; persist in prefs if users ask
final seenStoriesProvider = StateProvider<Set<String>>((_) => {});

/// The one way into a creator's stories: the live room when they're live,
/// else the story viewer (which marks them seen), else their page.
void openStories(BuildContext context, String creatorId) {
  final container = ProviderScope.containerOf(context, listen: false);
  final live = container
      .read(liveNowProvider)
      .valueOrNull
      ?.where((s) => (s['creator'] as Map)['id'] == creatorId)
      .firstOrNull;
  final posts = container.read(feedProvider).valueOrNull ?? const <Post>[];
  if (live == null && storySegments(posts, creatorId).isNotEmpty) {
    context.push('/stories/$creatorId');
    return;
  }
  container
      .read(seenStoriesProvider.notifier)
      .update((seen) => {...seen, creatorId});
  if (live != null) {
    context.push('/live/${live['id']}');
    return;
  }
  final handle = posts
      .where((p) => p.creatorId == creatorId)
      .firstOrNull
      ?.creatorHandle;
  if (handle != null) context.push('/c/$handle');
}

/// "2 days ago", or "2d" when [short].
String timeAgo(DateTime t, {bool short = false, DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(t);
  String unit(int n, String name, String abbr) =>
      short ? '$n$abbr' : '$n $name${n == 1 ? '' : 's'} ago';
  if (d.inMinutes < 1) return short ? 'now' : 'Just now';
  if (d.inHours < 1) return unit(d.inMinutes, 'minute', 'm');
  if (d.inDays < 1) return unit(d.inHours, 'hour', 'h');
  if (d.inDays < 7) return unit(d.inDays, 'day', 'd');
  if (d.inDays < 35) return unit(d.inDays ~/ 7, 'week', 'w');
  return (short ? DateFormat.MMMd() : DateFormat.yMMMd()).format(t);
}

bool _largeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1) > 1.4;

/// IT.md F3: the fan's home. Stories, then a feed of followed and
/// discoverable creators' posts.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _scroll = ScrollController();

  /// Content has scrolled under the top bar: frost it.
  bool _under = false;

  /// Fresh suggestions after a pull to refresh.
  int _refreshes = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final under = n.metrics.pixels > 0;
    if (under != _under) setState(() => _under = under);
    return false;
  }

  void _toTop() {
    if (!_scroll.hasClients) return;
    final d = motion(context, mediumDuration);
    d == Duration.zero
        ? _scroll.jumpTo(0)
        : _scroll.animateTo(0, duration: d, curve: easeInOut);
  }

  Future<List<Post>> _refresh() {
    HapticFeedback.mediumImpact();
    setState(() => _refreshes++);
    ref.invalidate(liveNowProvider);
    ref.invalidate(discoveryProvider);
    // Fresh server data is authoritative: drop the optimistic overrides.
    return ref.refresh(feedProvider.future).whenComplete(() {
      ref.read(likeOverridesProvider.notifier).state = {};
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(homeScrollTopProvider, (_, _) => _toTop());
    final feed = ref.watch(feedProvider);
    final live = ref.watch(liveNowProvider).valueOrNull ?? const [];
    final side = math.max(0.0, (MediaQuery.sizeOf(context).width - 470) / 2);
    Widget fill(Widget child) => SliverFillRemaining(child: child);
    final body = feed.when(
      loading: () => [const SliverToBoxAdapter(child: _HomeSkeleton())],
      error: (_, _) => [
        fill(
          asyncBody(
            feed,
            () => ref.invalidate(feedProvider),
            (_) => const SizedBox.shrink(),
          ),
        ),
      ],
      data: (posts) => posts.isEmpty && live.isEmpty
          ? [
              fill(
                StateView(
                  icon: Icons.dynamic_feed_outlined,
                  title: 'Your feed is quiet',
                  message: 'Follow creators to fill it up.',
                  action: FilledButton.icon(
                    style: brandButtonStyle(context),
                    onPressed: () => context.push('/search'),
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Find creators'),
                  ),
                ),
              ),
            ]
          : _feed(posts, live, side),
    );
    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: RefreshIndicator.adaptive(
          edgeOffset: MediaQuery.paddingOf(context).top + kToolbarHeight,
          onRefresh: _refresh,
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              _TopBar(under: _under),
              ...body,
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _feed(
    List<Post> posts,
    List<Map<String, dynamic>> live,
    double side,
  ) {
    final items = <Widget>[
      for (final (i, p) in posts.indexed)
        Entrance(
          key: ValueKey(p.id),
          index: i,
          child: FeedPost(key: ValueKey('feed-post-${p.id}'), post: p),
        ),
    ];
    // Suggestions after the second post, or last when the feed is short.
    items.insert(
      math.min(2, items.length),
      _Suggested(key: ValueKey('suggested-$_refreshes')),
    );
    return [
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: side),
        sliver: SliverToBoxAdapter(
          child: StoriesTray(posts: posts, live: live),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          side,
          4,
          side,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        sliver: SliverList.list(children: items),
      ),
    ];
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.under});
  final bool under;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brand = Brand.of(context);
    Widget action(Key key, String tip, IconData icon, VoidCallback onTap) =>
        Pressable(
          scale: 0.92,
          child: IconButton(
            key: key,
            tooltip: tip,
            onPressed: onTap,
            icon: Icon(icon),
          ),
        );
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      titleSpacing: 16,
      flexibleSpace: AnimatedOpacity(
        opacity: under ? 1 : 0,
        duration: motion(context, shortDuration),
        curve: easeOut,
        child: Glass(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          child: const SizedBox.expand(),
        ),
      ),
      title: Semantics(
        header: true,
        label: 'Raha',
        child: ExcludeSemantics(
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: brand.gradient.createShader,
            // A wordmark, not body text: it keeps its drawn size.
            child: Text(
              'Raha',
              textScaler: TextScaler.noScaling,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
      actions: [
        action(
          const ValueKey('home-search'),
          'Search',
          Icons.search_rounded,
          () => context.push('/search'),
        ),
        action(const ValueKey('home-inbox'), 'Inbox', Icons.mail_outline, () {
          HapticFeedback.selectionClick();
          context.go('/inbox');
        }),
        const SizedBox(width: 4),
      ],
    );
  }
}

/// Story circles: live creators first, then unseen, then seen.
class StoriesTray extends ConsumerWidget {
  const StoriesTray({super.key, required this.posts, required this.live});
  final List<Post> posts;
  final List<Map<String, dynamic>> live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seen = ref.watch(seenStoriesProvider);
    final creators = storyOrder(live, posts, seen);
    if (creators.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in creators)
            _StoryCircle(
              key: ValueKey('story-${c.id}'),
              creator: c,
              seen: seen.contains(c.id),
            ),
        ],
      ),
    );
  }
}

class _StoryCircle extends StatefulWidget {
  const _StoryCircle({super.key, required this.creator, required this.seen});
  final StoryCreator creator;
  final bool seen;

  @override
  State<_StoryCircle> createState() => _StoryCircleState();
}

class _StoryCircleState extends State<_StoryCircle>
    with SingleTickerProviderStateMixin {
  static const _avatar = 68.0;
  static const _ring = _avatar + 12;

  late final _spin = AnimationController(vsync: this, duration: mediumDuration);

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  /// Opens at once; the ring's spin is a flourish alongside the push.
  void _open() {
    HapticFeedback.selectionClick();
    if (motion(context, _spin.duration!) != Duration.zero) {
      _spin.forward(from: 0);
    }
    openStories(context, widget.creator.id);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.creator;
    final scheme = Theme.of(context).colorScheme;
    final brand = Brand.of(context);
    final ringed = c.live || !widget.seen;
    final circle = SizedBox(
      width: _ring,
      height: _ring,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: CurvedAnimation(parent: _spin, curve: easeInOut),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: ringed ? brand.gradient : null,
                border: ringed
                    ? null
                    : Border.all(color: scheme.outlineVariant),
              ),
            ),
          ),
          Container(
            width: _ring - 6,
            height: _ring - 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surface,
            ),
          ),
          CreatorAvatar(id: c.id, name: c.name, size: _avatar),
          if (c.live)
            Positioned(
              bottom: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: brand.gradient,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: scheme.surface, width: 2),
                ),
                child: const Text(
                  'LIVE',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return Semantics(
      button: true,
      label: c.live ? '${c.name}, live now' : "${c.name}'s story",
      onTap: _open,
      child: ExcludeSemantics(
        child: Pressable(
          scale: 0.92,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _open,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                children: [
                  circle,
                  if (!_largeText(context)) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      width: _ring,
                      child: Text(
                        c.handle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One post, edge to edge: header, 4:5 media, likes and caption.
class FeedPost extends ConsumerStatefulWidget {
  const FeedPost({super.key, required this.post});
  final Post post;

  @override
  ConsumerState<FeedPost> createState() => _FeedPostState();
}

class _FeedPostState extends ConsumerState<FeedPost>
    with TickerProviderStateMixin {
  bool _expanded = false;

  /// Heart burst over the media: 450ms pop, 250ms hold, 200ms fade.
  late final _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final _burstScale = CurvedAnimation(
    parent: _burst,
    curve: const Interval(0, 0.5, curve: Curves.easeOutBack),
  );
  late final _burstFade = ReverseAnimation(
    CurvedAnimation(
      parent: _burst,
      curve: const Interval(0.78, 1, curve: easeOut),
    ),
  );

  /// The like button's 1 → 1.25 → 1 pop.
  late final _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  late final _popScale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 1),
  ]).animate(CurvedAnimation(parent: _pop, curve: easeOut));

  @override
  void dispose() {
    _burst.dispose();
    _pop.dispose();
    super.dispose();
  }

  Post get _post => widget.post;

  // Watched in build; handlers re-read so they never act on a stale frame.
  ({int likes, bool liked}) get _like =>
      ref.watch(likeOverridesProvider.select((m) => m[_post.id])) ??
      (likes: _post.likes, liked: _post.liked);
  bool get _liked => _like.liked;
  int get _likes => _like.likes;

  /// [want] null toggles.
  Future<void> _setLiked(bool? want) async {
    final now =
        ref.read(likeOverridesProvider)[_post.id]?.liked ?? _post.liked;
    final like = want ?? !now;
    if (like == now) return;
    like ? HapticFeedback.lightImpact() : HapticFeedback.selectionClick();
    if (motion(context, pressDuration) != Duration.zero) {
      _pop.forward(from: 0);
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await toggleLike(
        ref.read(dioProvider),
        ref.read(likeOverridesProvider.notifier),
        _post,
        like,
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  void _doubleTap() {
    _burst.forward(from: 0);
    _setLiked(true);
  }

  void _openPost() => context.push('/p/${_post.id}');
  void _openCreator() => context.push('/c/${_post.creatorHandle}');

  void _more() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      // Above the shell's floating tab bar.
      useRootNavigator: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('View profile'),
            onTap: () {
              Navigator.pop(sheet);
              _openCreator();
            },
          ),
          ListTile(
            leading: const Icon(Icons.open_in_full_rounded),
            title: const Text('View post'),
            onTap: () {
              Navigator.pop(sheet);
              _openPost();
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontSize: 12,
    );
    final created = _post.createdAt;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
      child: Row(
        children: [
          Expanded(
            child: Pressable(
              child: InkWell(
                onTap: _openCreator,
                borderRadius: BorderRadius.circular(controlRadius),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      CreatorAvatar(
                        id: _post.creatorId,
                        name: _post.creatorName,
                        size: 32,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                text: _post.creatorHandle,
                                children: [
                                  const TextSpan(text: ' '),
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Icon(
                                      Icons.verified,
                                      size: 14,
                                      color: scheme.primary,
                                      semanticLabel: 'Verified',
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (created != null)
                              Text(timeAgo(created, short: true), style: muted),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Pressable(
            scale: 0.92,
            child: IconButton(
              tooltip: 'More',
              onPressed: _more,
              icon: const Icon(Icons.more_horiz),
            ),
          ),
        ],
      ),
    );
    final locked = _post.locked || _post.media.isEmpty;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final media = Semantics(
      button: true,
      label: locked ? 'Locked post: ${_post.caption}' : _post.caption,
      onTap: _openPost,
      child: GestureDetector(
        excludeFromSemantics: true,
        onTap: _openPost,
        onDoubleTap: _doubleTap,
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: Stack(
            fit: StackFit.expand,
            children: [
              locked
                  ? LockedMedia(post: _post)
                  : MediaView(mediaId: _post.media.first.id),
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _burst,
                  builder: (_, _) => !_burst.isAnimating
                      ? const SizedBox.shrink()
                      : Center(
                          // Reduced motion: the heart just appears, then goes.
                          child: Opacity(
                            opacity: reduce ? 1 : _burstFade.value,
                            child: Transform.scale(
                              scale: reduce ? 1 : _burstScale.value,
                              child: const Icon(
                                Icons.favorite,
                                size: 96,
                                color: Colors.white,
                                shadows: [
                                  Shadow(color: Colors.black38, blurRadius: 24),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final likeColor = Brand.of(context).glowB;
    final handleStyle = text.bodyMedium?.copyWith(fontWeight: FontWeight.w700);
    final caption = TextSpan(
      style: text.bodyMedium,
      children: [
        TextSpan(text: _post.creatorHandle, style: handleStyle),
        TextSpan(text: ' ${_post.caption}'),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        media,
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Pressable(
            scale: 0.92,
            child: ScaleTransition(
              scale: _popScale,
              child: IconButton(
                key: ValueKey('like-${_post.id}'),
                tooltip: _liked ? 'Unlike' : 'Like',
                onPressed: () => _setLiked(null),
                icon: Icon(
                  _liked ? Icons.favorite : Icons.favorite_border,
                  color: _liked ? likeColor : null,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${NumberFormat.decimalPattern().format(_likes)} '
                '${_likes == 1 ? 'like' : 'likes'}',
                key: ValueKey('likes-${_post.id}'),
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (_post.caption.isNotEmpty) ...[
                const SizedBox(height: 4),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final painter = TextPainter(
                      text: caption,
                      maxLines: 2,
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                    )..layout(maxWidth: constraints.maxWidth);
                    final clipped = !_expanded && painter.didExceedMaxLines;
                    painter.dispose();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          caption,
                          maxLines: _expanded ? null : 2,
                          overflow: _expanded ? null : TextOverflow.ellipsis,
                        ),
                        if (clipped)
                          Semantics(
                            button: true,
                            child: GestureDetector(
                              onTap: () => setState(() => _expanded = true),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Text(
                                  'more',
                                  style: text.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
              if (created != null) ...[
                const SizedBox(height: 6),
                Text(timeAgo(created), style: muted),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

const ({String query, String? category}) _filter = (query: '', category: null);

/// "Suggested for you": creators the fan doesn't follow yet.
class _Suggested extends ConsumerStatefulWidget {
  const _Suggested({super.key});

  @override
  ConsumerState<_Suggested> createState() => _SuggestedState();
}

class _SuggestedState extends ConsumerState<_Suggested> {
  /// Fixed at first load, so a card stays put after its Follow flips.
  List<Creator>? _creators;

  @override
  Widget build(BuildContext context) {
    final loaded = ref.watch(discoveryProvider(_filter)).valueOrNull;
    if (loaded != null) {
      _creators ??= loaded.where((c) => !c.isFollowing).take(10).toList();
    }
    final creators = _creators ?? const <Creator>[];
    if (creators.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Semantics(
              header: true,
              child: Text(
                'Suggested for you',
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final c in creators)
                  _SuggestedCard(key: ValueKey('suggest-${c.id}'), creator: c),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestedCard extends ConsumerStatefulWidget {
  const _SuggestedCard({super.key, required this.creator});
  final Creator creator;

  @override
  ConsumerState<_SuggestedCard> createState() => _SuggestedCardState();
}

class _SuggestedCardState extends ConsumerState<_SuggestedCard> {
  late bool _following = widget.creator.isFollowing;
  int _seq = 0;

  Future<void> _toggle() async {
    final follow = !_following;
    follow ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
    final seq = ++_seq;
    setState(() => _following = follow);
    try {
      await setFollowing(ref.read(dioProvider), widget.creator.id, follow);
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() => _following = !follow);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.creator;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final key = ValueKey('suggest-follow-${c.handle}');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        width: 156,
        child: Pressable(
          child: Material(
            color: scheme.surfaceContainerLow,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: const BorderRadius.all(Radius.circular(cardRadius)),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            child: InkWell(
              onTap: () => context.push('/c/${c.handle}'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                child: Column(
                  children: [
                    CreatorAvatar(
                      id: c.id,
                      name: c.displayName,
                      size: 88,
                      ring: c.isSubscribed,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      c.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${compactCount(c.followers)} followers',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: _following
                          ? OutlinedButton(
                              key: key,
                              onPressed: _toggle,
                              child: const Text('Following'),
                            )
                          : FilledButton(
                              key: key,
                              style: brandButtonStyle(context),
                              onPressed: _toggle,
                              child: const Text('Follow'),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Loading: story circles and two post-shaped blocks.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget post() => const Padding(
      padding: EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                Skeleton(width: 32, height: 32, radius: 16),
                SizedBox(width: 10),
                Skeleton(width: 120),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 4 / 5,
            child: Skeleton(height: double.infinity, radius: 0),
          ),
        ],
      ),
    );
    return Semantics(
      label: 'Loading',
      child: ExcludeSemantics(
        child: Shimmer(
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                child: Row(
                  children: [
                    for (var i = 0; i < 5; i++)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Skeleton(width: 80, height: 80, radius: 40),
                      ),
                  ],
                ),
              ),
              post(),
              post(),
            ],
          ),
        ),
      ),
    );
  }
}
