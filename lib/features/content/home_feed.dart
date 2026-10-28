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
import '../../core/money.dart';
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
    MediaQuery.textScalerOf(context).scale(14) / 14 > 1.4;

/// 20pt gutters, widening to centre a 640pt column on big screens.
double _gutter(BuildContext context) =>
    math.max(20, (MediaQuery.sizeOf(context).width - 640) / 2);

/// "Tuesday evening": the masthead's edition line.
String _edition(DateTime now) {
  final h = now.hour;
  final part = h < 5
      ? 'night'
      : h < 12
      ? 'morning'
      : h < 17
      ? 'afternoon'
      : h < 21
      ? 'evening'
      : 'night';
  return '${DateFormat.EEEE().format(now)} $part';
}

const ({String query, String? category}) _filter = (query: '', category: null);

/// IT.md F3: the fan's home. Masthead, browse chips and stories, a lead post,
/// then the feed with Creator Rooms woven in.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _scroll = ScrollController();

  /// Content has scrolled under the top bar: frost it.
  bool _under = false;

  /// Fresh rooms after a pull to refresh.
  int _refreshes = 0;

  /// Creators the fan doesn't follow, fixed at first load so a room stays put
  /// after its Follow flips.
  List<Creator>? _rooms;

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
    setState(() {
      _refreshes++;
      _rooms = null;
    });
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
    final found = ref.watch(discoveryProvider(_filter));
    if (found.hasValue && !found.isLoading) {
      _rooms ??= found.value!.where((c) => !c.isFollowing).take(10).toList();
    }
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
      data: (posts) => _feed(posts, live),
    );
    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: RefreshIndicator.adaptive(
          edgeOffset:
              MediaQuery.paddingOf(context).top + _TopBar.heightOf(context),
          onRefresh: _refresh,
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              _TopBar(under: _under),
              const SliverToBoxAdapter(child: _BrowseChips()),
              ...body,
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _feed(List<Post> posts, List<Map<String, dynamic>> live) {
    final rooms = [
      for (final c in _rooms ?? const <Creator>[])
        _CreatorRoom(key: ValueKey('room-${c.id}-$_refreshes'), creator: c),
    ];
    final stories = SliverToBoxAdapter(
      child: StoriesTray(posts: posts, live: live),
    );
    if (posts.isEmpty && _rooms != null && rooms.isEmpty) {
      return [
        stories,
        SliverFillRemaining(
          child: StateView(
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
      ];
    }
    // The gap between two items is the larger of their margins, never both.
    final items = <Widget>[];
    var owed = 0.0;
    void add(Widget w, {double above = 0, double below = 16}) {
      if (items.isNotEmpty) items.add(SizedBox(height: math.max(owed, above)));
      items.add(w);
      owed = below;
    }

    final text = Theme.of(context).textTheme;
    for (final (i, p) in posts.indexed) {
      if (i == 1) {
        add(
          Semantics(
            header: true,
            child: Text(
              'Latest from people you follow',
              style: text.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          above: 24,
          below: 12,
        );
      }
      add(
        Entrance(
          key: ValueKey(p.id),
          index: i,
          child: FeedPost(
            key: ValueKey('feed-post-${p.id}'),
            post: p,
            lead: i == 0,
          ),
        ),
      );
      // Rooms after the third and seventh posts; the rest close the feed.
      if ((i == 2 || i == 6) && rooms.isNotEmpty) {
        add(rooms.removeAt(0), above: 24, below: 24);
      }
    }
    for (final room in rooms) {
      add(room, above: 24, below: 24);
    }
    final gutter = _gutter(context);
    return [
      stories,
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          gutter,
          16,
          gutter,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        sliver: SliverList.list(children: items),
      ),
    ];
  }
}

/// The masthead: an edition line over the wordmark, with search and inbox.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.under});
  final bool under;

  static TextStyle? _eyebrowStyle(BuildContext context) =>
      Theme.of(context).textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );

  static TextStyle? _wordmarkStyle(BuildContext context) =>
      Theme.of(context).textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.75,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// Toolbar height that fits the masthead at the current text size.
  static double heightOf(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    double line(TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: 'Rg', style: style),
        textScaler: scaler,
        textDirection: Directionality.of(context),
      )..layout();
      final h = painter.height;
      painter.dispose();
      return h;
    }

    final title =
        line(_eyebrowStyle(context)) + 2 + line(_wordmarkStyle(context));
    return 16 + (_largeText(context) ? title + 8 + 48 : math.max(title, 48));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gutter = _gutter(context);
    final large = _largeText(context);
    Widget action(Key key, String tip, IconData icon, VoidCallback onTap) =>
        Pressable(
          child: IconButton(
            key: key,
            tooltip: tip,
            onPressed: onTap,
            icon: Icon(icon, size: 24),
          ),
        );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
      ],
    );
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_edition(DateTime.now()), style: _eyebrowStyle(context)),
        const SizedBox(height: 2),
        Semantics(
          header: true,
          child: Text('Raha', style: _wordmarkStyle(context)),
        ),
      ],
    );
    return SliverAppBar(
      floating: true,
      snap: true,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      toolbarHeight: heightOf(context),
      titleSpacing: 0,
      flexibleSpace: AnimatedOpacity(
        opacity: under ? 1 : 0,
        duration: motion(context, shortDuration),
        curve: easeOut,
        child: Glass(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          child: const SizedBox.expand(),
        ),
      ),
      // AppBar clamps its title's text scale; the masthead scales fully.
      title: MediaQuery(
        data: MediaQuery.of(context),
        child: Padding(
          padding: EdgeInsets.fromLTRB(gutter, 8, gutter - 12, 8),
          child: large
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    title,
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 12),
                    actions,
                  ],
                ),
        ),
      ),
    );
  }
}

/// Browse by category: each chip opens Search filtered to it.
class _BrowseChips extends ConsumerWidget {
  const _BrowseChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    if (categories.isEmpty) return const SizedBox.shrink();
    final gutter = _gutter(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 0),
      child: Row(
        spacing: 8,
        children: [
          for (final c in categories)
            Pressable(
              child: ActionChip(
                key: ValueKey('browse-$c'),
                label: Text(c),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                labelPadding: EdgeInsets.zero,
                onPressed: () => context.push(
                  '/search?category=${Uri.encodeQueryComponent(c)}',
                ),
              ),
            ),
        ],
      ),
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
    final gutter = _gutter(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
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
  static const _face = 44.0;
  static const _ring = 56.0;

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
    final text = Theme.of(context).textTheme;
    final brand = Brand.of(context);
    final large = _largeText(context);
    final ringed = c.live || !widget.seen;
    final circle = SizedBox.square(
      dimension: _ring,
      child: Stack(
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
          CreatorAvatar(id: c.id, name: c.name, size: _face),
          if (c.live)
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  gradient: brand.gradient,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: scheme.surface, width: 2),
                ),
                child: Text(
                  'LIVE',
                  style: text.labelSmall?.copyWith(
                    color: brandInk,
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
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _open,
            child: SizedBox(
              width: large ? 112 : 80,
              child: Column(
                children: [
                  circle,
                  const SizedBox(height: 4),
                  Text(
                    c.name,
                    maxLines: large ? null : 2,
                    overflow: large ? null : TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: text.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One feed post. [lead] is the large card that opens the feed. Otherwise a
/// locked post (or one without media) is a compact row with its unlock CTA,
/// and the rest are inset cards with 4:5 media.
class FeedPost extends ConsumerStatefulWidget {
  const FeedPost({super.key, required this.post, this.lead = false});
  final Post post;
  final bool lead;

  @override
  ConsumerState<FeedPost> createState() => _FeedPostState();
}

class _FeedPostState extends ConsumerState<FeedPost>
    with TickerProviderStateMixin {
  static const _burstDuration = Duration(milliseconds: 600);

  bool _expanded = false;

  /// Heart burst over the media: pop, hold, fade.
  late final _burst = AnimationController(
    vsync: this,
    duration: _burstDuration,
  );
  late final _burstScale = CurvedAnimation(
    parent: _burst,
    curve: const Interval(0, 0.5, curve: Curves.easeOutBack),
  );
  late final _burstFade = ReverseAnimation(
    CurvedAnimation(
      parent: _burst,
      curve: const Interval(0.65, 1, curve: easeOut),
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
  void initState() {
    super.initState();
    // Not every layout shows the burst or the like pop; create them up front
    // so dispose never builds a ticker on a deactivated element.
    _burst;
    _pop;
  }

  @override
  void dispose() {
    _burst.dispose();
    _pop.dispose();
    super.dispose();
  }

  Post get _post => widget.post;
  bool get _locked => _post.locked || _post.media.isEmpty;

  // Watched in build; handlers re-read so they never act on a stale frame.
  ({int likes, bool liked}) get _like =>
      ref.watch(likeOverridesProvider.select((m) => m[_post.id])) ??
      (likes: _post.likes, liked: _post.liked);
  bool get _liked => _like.liked;
  int get _likes => _like.likes;

  /// [want] null toggles.
  Future<void> _setLiked(bool? want) async {
    final now = ref.read(likeOverridesProvider)[_post.id]?.liked ?? _post.liked;
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
    // Reduced motion: no burst; the like button still fills.
    _burst.duration = motion(context, _burstDuration);
    if (_burst.duration != Duration.zero) _burst.forward(from: 0);
    _setLiked(true);
  }

  void _openPost() => context.push('/p/${_post.id}');
  void _openCreator() => context.push('/c/${_post.creatorHandle}');

  /// Same mapping as the post screen's unlock bar.
  void _unlock() {
    switch (_post.access) {
      case 'paid':
        context.push('/checkout/post/${_post.id}');
      case 'subscribers':
        context.push('/checkout/subscription/${_post.creatorId}');
      default:
        _openCreator();
    }
  }

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

  /// Taps open the post; a double tap likes it.
  Widget _tappable(Widget child) => Semantics(
    button: true,
    label: _locked ? 'Locked post: ${_post.caption}' : _post.caption,
    onTap: _openPost,
    child: GestureDetector(
      excludeFromSemantics: true,
      onTap: _openPost,
      onDoubleTap: _doubleTap,
      child: child,
    ),
  );

  Widget _media() => _locked
      ? LockedMedia(post: _post)
      : MediaView(mediaId: _post.media.first.id);

  Widget _heart() => IgnorePointer(
    child: AnimatedBuilder(
      animation: _burst,
      builder: (_, _) => !_burst.isAnimating
          ? const SizedBox.shrink()
          : Center(
              child: Opacity(
                opacity: _burstFade.value,
                child: Transform.scale(
                  scale: _burstScale.value,
                  child: const Icon(
                    Icons.favorite,
                    size: 96,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black38, blurRadius: 24)],
                  ),
                ),
              ),
            ),
    ),
  );

  Widget _likeButton({Color? color}) => ScaleTransition(
    scale: _popScale,
    child: IconButton(
      key: ValueKey('like-${_post.id}'),
      tooltip: _liked ? 'Unlike' : 'Like',
      onPressed: () => _setLiked(null),
      icon: Icon(
        _liked ? Icons.favorite : Icons.favorite_border,
        color: _liked ? Brand.of(context).glowB : color,
        size: 24,
      ),
    ),
  );

  Widget _moreButton({ButtonStyle? style}) => IconButton(
    tooltip: 'More',
    onPressed: _more,
    style: style,
    icon: const Icon(Icons.more_horiz, size: 24),
  );

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: widget.lead
        ? _leadCard(context)
        : _locked
        ? _lockedRow(context)
        : _insetCard(context),
  );

  Widget _leadCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final large = _largeText(context);
    final created = _post.createdAt;
    Widget details(Color fg, Color fg2) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            CreatorAvatar(
              id: _post.creatorId,
              name: _post.creatorName,
              size: 28,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _post.creatorName,
                    maxLines: large ? null : 1,
                    overflow: large ? null : TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                  if (created != null)
                    Text(
                      timeAgo(created),
                      style: text.bodySmall?.copyWith(color: fg2),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (_post.caption.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _post.caption,
            maxLines: large ? null : 2,
            overflow: large ? null : TextOverflow.ellipsis,
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
              color: fg,
            ),
          ),
        ],
      ],
    );
    final picture = Stack(
      fit: StackFit.expand,
      children: [
        _tappable(_media()),
        if (!large)
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.25, 0.6, 1],
                  colors: [Color(0x00000000), Color(0xD9000000), Colors.black],
                ),
              ),
            ),
          ),
        _heart(),
        Positioned(
          top: 12,
          left: 12,
          child: IgnorePointer(child: _AccessChip(post: _post)),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: _moreButton(
            style: IconButton.styleFrom(
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        if (!large)
          Positioned(
            left: 16,
            right: 4,
            bottom: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Taps fall through to the media.
                Expanded(
                  child: IgnorePointer(
                    child: details(Colors.white, Colors.white),
                  ),
                ),
                _likeButton(color: Colors.white),
              ],
            ),
          ),
      ],
    );
    if (!large) return SizedBox(height: 300, child: picture);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 220, child: picture),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 4, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: details(scheme.onSurface, scheme.onSurfaceVariant),
              ),
              _likeButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _lockedRow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final large = _largeText(context);
    final created = _post.createdAt;
    final thumb = ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(controlRadius)),
      child: SizedBox(
        width: large ? double.infinity : 88,
        height: large ? 160 : 104,
        child: LockedMedia(post: _post),
      ),
    );
    final details = Column(
      crossAxisAlignment: large
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: _post.creatorName,
            style: text.titleSmall,
            children: [
              if (created != null)
                TextSpan(
                  text: ' · ${timeAgo(created, short: true)}',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (_post.caption.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _post.caption,
            maxLines: large ? null : 2,
            overflow: large ? null : TextOverflow.ellipsis,
            style: text.bodyMedium,
          ),
        ],
        const SizedBox(height: 10),
        Pressable(
          child: FilledButton(
            style: brandButtonStyle(context),
            onPressed: _unlock,
            child: Text(switch (_post.access) {
              'paid' => 'Unlock · ${formatKes(_post.priceCents ?? 0)}',
              'subscribers' => 'Subscribe',
              _ => 'View profile',
            }),
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      label: 'Locked post: ${_post.caption}',
      onTap: _openPost,
      child: InkWell(
        excludeFromSemantics: true,
        onTap: _openPost,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: large
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [thumb, const SizedBox(height: 12), details],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    thumb,
                    const SizedBox(width: 12),
                    Expanded(child: details),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _insetCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final large = _largeText(context);
    final created = _post.createdAt;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _openCreator,
              borderRadius: BorderRadius.circular(controlRadius),
              child: Row(
                children: [
                  CreatorAvatar(
                    id: _post.creatorId,
                    name: _post.creatorName,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _post.creatorName,
                          maxLines: large ? null : 1,
                          overflow: large ? null : TextOverflow.ellipsis,
                          style: text.titleSmall,
                        ),
                        if (created != null)
                          Text(
                            timeAgo(created),
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _moreButton(),
        ],
      ),
    );
    final media = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(controlRadius)),
        child: _tappable(
          AspectRatio(
            aspectRatio: 4 / 5,
            child: Stack(fit: StackFit.expand, children: [_media(), _heart()]),
          ),
        ),
      ),
    );
    final caption = TextSpan(text: _post.caption, style: text.bodyMedium);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        media,
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _likeButton(),
              Text(
                '${NumberFormat.decimalPattern().format(_likes)} '
                '${_likes == 1 ? 'like' : 'likes'}',
                key: ValueKey('likes-${_post.id}'),
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        if (_post.caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final open = _expanded || large;
                final painter = TextPainter(
                  text: caption,
                  maxLines: 2,
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout(maxWidth: constraints.maxWidth);
                final clipped = !open && painter.didExceedMaxLines;
                painter.dispose();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      caption,
                      maxLines: open ? null : 2,
                      overflow: open ? null : TextOverflow.ellipsis,
                    ),
                    if (clipped)
                      Semantics(
                        button: true,
                        child: GestureDetector(
                          onTap: () => setState(() => _expanded = true),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
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
          ),
      ],
    );
  }
}

/// What a post costs to see, on media: "Free", "Subscribers", "KSh 150".
class _AccessChip extends StatelessWidget {
  const _AccessChip({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final label = post.access == 'paid' && post.priceCents != null
        ? formatKes(post.priceCents!)
        : accessLabels[post.access] ?? post.access;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.all(Radius.circular(controlRadius)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (post.locked) ...[
              const Icon(Icons.lock_outline, size: 14, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A creator the fan doesn't follow yet: banner, identity, Follow and a peek
/// at their latest posts. Tapping the room opens the creator.
class _CreatorRoom extends ConsumerStatefulWidget {
  const _CreatorRoom({super.key, required this.creator});
  final Creator creator;

  @override
  ConsumerState<_CreatorRoom> createState() => _CreatorRoomState();
}

class _CreatorRoomState extends ConsumerState<_CreatorRoom> {
  static const _banner = 112.0;
  static const _avatar = 56.0;

  late bool _following = widget.creator.isFollowing;

  /// A follow request is in flight: the button waits, keeping its label.
  bool _pending = false;

  Future<void> _toggle() async {
    final follow = !_following;
    follow ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
    setState(() => _pending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await setFollowing(ref.read(dioProvider), widget.creator.id, follow);
      if (mounted) setState(() => _following = follow);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.creator;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final large = _largeText(context);
    final key = ValueKey('suggest-follow-${c.handle}');
    final onFollow = _pending ? null : _toggle;
    final follow = _following
        ? FilledButton.tonalIcon(
            key: key,
            onPressed: onFollow,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Following'),
          )
        : OutlinedButton(
            key: key,
            onPressed: onFollow,
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.primary,
              side: BorderSide(color: scheme.primary),
            ),
            child: const Text('Follow'),
          );
    final meta = [
      '@${c.handle}',
      ?c.categories.firstOrNull,
      '${compactCount(c.followers)} followers',
    ].join(' · ');
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          c.displayName,
          maxLines: large ? null : 1,
          overflow: large ? null : TextOverflow.ellipsis,
          style: text.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          meta,
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
    Widget grid(List<Widget> tiles) => large
        ? Column(
            spacing: 8,
            children: [for (final t in tiles) SizedBox(height: 150, child: t)],
          )
        : Row(
            spacing: 8,
            children: [
              for (final t in tiles)
                Expanded(child: SizedBox(height: 150, child: t)),
            ],
          );
    final tiles = ref
        .watch(creatorPostsProvider(c.id))
        .when(
          loading: () => grid(const [
            Skeleton(height: 150, radius: controlRadius),
            Skeleton(height: 150, radius: controlRadius),
          ]),
          // Previews are a bonus: on error the room keeps identity and Follow.
          error: (_, _) => null,
          data: (posts) => posts.isEmpty
              ? null
              : grid([for (final p in posts.take(2)) _RoomTile(post: p)]),
        );
    // The avatar ring hangs this far below the banner.
    const overhang = _avatar / 2 + 3;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/c/${c.handle}'),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: _banner,
                  child: CreatorBanner(id: c.id),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, overhang + 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (large) ...[
                        identity,
                        const SizedBox(height: 12),
                        follow,
                      ] else
                        Row(
                          children: [
                            Expanded(child: identity),
                            const SizedBox(width: 12),
                            follow,
                          ],
                        ),
                      if (c.bio.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          c.bio,
                          maxLines: large ? null : 2,
                          overflow: large ? null : TextOverflow.ellipsis,
                          style: text.bodyMedium,
                        ),
                      ],
                      if (tiles != null) ...[const SizedBox(height: 12), tiles],
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              left: 13,
              top: _banner - _avatar / 2 - 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surfaceContainerLow,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: CreatorAvatar(
                    id: c.id,
                    name: c.displayName,
                    size: _avatar,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A Creator Room preview: the post, or its teaser cover and price when
/// locked. Opens the post.
class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final locked = post.locked || post.media.isEmpty;
    return Semantics(
      button: true,
      label: locked ? 'Locked post: ${post.caption}' : post.caption,
      child: GestureDetector(
        excludeFromSemantics: true,
        onTap: () => context.push('/p/${post.id}'),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(controlRadius)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (locked)
                LockedMedia(post: post)
              else
                MediaView(mediaId: post.media.first.id),
              if (locked)
                Positioned(top: 8, left: 8, child: _AccessChip(post: post)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loading: story circles, the lead card and a locked row.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    final gutter = _gutter(context);
    return Semantics(
      label: 'Loading',
      child: ExcludeSemantics(
        child: Shimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 0),
                child: Row(
                  spacing: 8,
                  children: [
                    for (var i = 0; i < 5; i++)
                      const SizedBox(
                        width: 80,
                        child: Column(
                          spacing: 4,
                          children: [
                            Skeleton(width: 56, height: 56, radius: 28),
                            Skeleton(width: 56, height: 12),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 0),
                child: const Skeleton(height: 300, radius: cardRadius),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 0),
                child: const Skeleton(height: 128, radius: cardRadius),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
