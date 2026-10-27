import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../app/ui.dart';
import '../../core/api_client.dart';
import '../live/live_screens.dart';
import 'content_api.dart';
import 'home_feed.dart';
import 'media_view.dart';

typedef StoryCreator = ({String id, String handle, String name, bool live});

/// The stories tray order: live creators first, then unseen, then seen; ties
/// keep feed order. The viewer steps through creators in this order too.
List<StoryCreator> storyOrder(
  List<Map<String, dynamic>> live,
  List<Post> posts,
  Set<String> seen,
) {
  final byId = <String, StoryCreator>{};
  for (final s in live) {
    final c = s['creator'] as Map;
    final id = c['id'] as String;
    byId[id] = (
      id: id,
      handle: c['handle'] as String? ?? '',
      name: c['displayName'] as String? ?? '',
      live: true,
    );
  }
  for (final p in posts) {
    byId.putIfAbsent(
      p.creatorId,
      () => (
        id: p.creatorId,
        handle: p.creatorHandle,
        name: p.creatorName,
        live: false,
      ),
    );
  }
  int rank(StoryCreator c) => c.live ? 0 : (seen.contains(c.id) ? 2 : 1);
  // List.sort is not stable; break ties on feed order.
  final order = byId.values.toList();
  return [...order]..sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    return r != 0 ? r : order.indexOf(a).compareTo(order.indexOf(b));
  });
}

/// A creator's story: their newest three feed posts with media (the feed is
/// newest first), played oldest first.
List<Post> storySegments(List<Post> posts, String creatorId) => posts
    .where((p) => p.creatorId == creatorId && p.media.isNotEmpty)
    .take(3)
    .toList()
    .reversed
    .toList();

const _segmentDuration = Duration(seconds: 5);
const _dismissDistance = 120.0;
const _dismissVelocity = 700.0;

typedef _Story = ({StoryCreator creator, List<Post> posts});

/// Full-screen stories, opened from the tray at [creatorId]. Swipe sideways
/// between creators, down to dismiss; tap to step, hold to pause.
class StoryViewer extends ConsumerStatefulWidget {
  const StoryViewer({super.key, required this.creatorId});
  final String creatorId;

  @override
  ConsumerState<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends ConsumerState<StoryViewer>
    with TickerProviderStateMixin {
  /// Taken once, so marking creators seen doesn't reshuffle the pages.
  List<_Story>? _stories;
  PageController? _pages;
  int _page = 0;

  /// Segment each creator page is on, so going back resumes where it was.
  final _segment = <int, int>{};
  final _liked = <String, bool>{};

  late final _progress =
      AnimationController(vsync: this, duration: _segmentDuration)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) _next();
        });

  /// How far the viewer has been dragged down, in px.
  late final _drag = AnimationController.unbounded(vsync: this);

  bool _chrome = true;
  bool _armed = false;
  bool _closing = false;

  @override
  void dispose() {
    _progress.dispose();
    _drag.dispose();
    _pages?.dispose();
    super.dispose();
  }

  /// Screen-reader navigation: no auto-advance, explicit buttons instead.
  bool get _manual => MediaQuery.accessibleNavigationOf(context);

  void _restart() {
    _progress.value = 0;
    if (!_manual) _progress.forward();
  }

  void _resume() {
    if (mounted && !_closing && !_manual) _progress.forward();
  }

  void _onPage(int i) {
    final id = _stories![i].creator.id;
    ref
        .read(seenStoriesProvider.notifier)
        .update((s) => s.contains(id) ? s : {...s, id});
    setState(() => _page = i);
    _restart();
  }

  void _go(int i) {
    _progress.stop();
    final d = motion(context, mediumDuration);
    d == Duration.zero
        ? _pages!.jumpToPage(i)
        : _pages!.animateToPage(i, duration: d, curve: easeInOut);
  }

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    _progress.stop();
    context.pop();
  }

  void _next() {
    if (_closing) return;
    final stories = _stories!;
    final seg = _segment[_page] ?? 0;
    if (seg < stories[_page].posts.length - 1) {
      setState(() => _segment[_page] = seg + 1);
      _restart();
    } else if (_page < stories.length - 1) {
      _go(_page + 1);
    } else {
      _close();
    }
  }

  void _prev() {
    final seg = _segment[_page] ?? 0;
    if (seg > 0) {
      setState(() => _segment[_page] = seg - 1);
      _restart();
    } else if (_page > 0) {
      _segment[_page - 1] = _stories![_page - 1].posts.length - 1;
      _go(_page - 1);
    } else {
      _restart();
    }
  }

  void _tap(TapUpDetails d) =>
      d.localPosition.dx < MediaQuery.sizeOf(context).width / 3
      ? _prev()
      : _next();

  void _hold(bool down) {
    setState(() => _chrome = !down);
    down ? _progress.stop() : _resume();
  }

  void _dragStart(DragStartDetails _) {
    _progress.stop();
    _drag.stop();
  }

  void _dragUpdate(DragUpdateDetails d) {
    _drag.value = math.max(0, _drag.value + d.delta.dy);
    final past = _drag.value > _dismissDistance;
    if (past && !_armed) HapticFeedback.lightImpact();
    _armed = past;
  }

  void _dragEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dy;
    if (_drag.value > _dismissDistance || v > _dismissVelocity) {
      _close();
      return;
    }
    _armed = false;
    if (motion(context, mediumDuration) == Duration.zero) {
      _drag.value = 0;
    } else {
      // Critically damped, ~0.3s response, carrying the finger's velocity.
      _drag.animateWith(
        SpringSimulation(
          SpringDescription.withDampingRatio(mass: 1, stiffness: 440),
          _drag.value,
          0,
          v,
        ),
      );
    }
    _resume();
  }

  Future<void> _like(Post post) async {
    final was = _liked[post.id] ?? post.liked;
    final like = !was;
    like ? HapticFeedback.lightImpact() : HapticFeedback.selectionClick();
    setState(() => _liked[post.id] = like);
    try {
      final r = await setLiked(ref.read(dioProvider), post.id, like);
      if (!mounted) return;
      setState(() => _liked[post.id] = r.liked);
      ref.invalidate(feedProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _liked[post.id] = was);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  Future<void> _viewPost(Post post) async {
    // Paused while away, so the viewer can't advance or pop underneath.
    _progress.stop();
    await context.push('/p/${post.id}');
    _resume();
  }

  /// Snapshots the stories once the feed (and live list) have loaded.
  bool _load() {
    if (_stories != null) return true;
    final posts = ref.watch(feedProvider).valueOrNull;
    final live = ref.watch(liveNowProvider);
    if (posts == null || !(live.hasValue || live.hasError)) return false;
    final seen = ref.read(seenStoriesProvider);
    final stories = <_Story>[
      for (final c in storyOrder(live.valueOrNull ?? const [], posts, seen))
        if (!c.live) (creator: c, posts: storySegments(posts, c.id)),
    ]..removeWhere((s) => s.posts.isEmpty);
    _stories = stories;
    _page = math.max(
      0,
      stories.indexWhere((s) => s.creator.id == widget.creatorId),
    );
    _pages = PageController(initialPage: _page);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      stories.isEmpty ? _close() : _onPage(_page);
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_load()) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final stories = _stories!;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final pages = PageView.builder(
      controller: _pages,
      itemCount: stories.length,
      onPageChanged: _onPage,
      itemBuilder: (context, i) {
        final page = _story(context, i);
        if (reduce) return page;
        // Cube: each page turns about the edge it shares with its neighbour.
        return AnimatedBuilder(
          animation: _pages!,
          child: page,
          builder: (context, child) {
            final p = _pages!.position.haveDimensions
                ? _pages!.page!
                : _page.toDouble();
            final d = (i - p).clamp(-1.0, 1.0);
            return Transform(
              alignment: d > 0 ? Alignment.centerLeft : Alignment.centerRight,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(-d * math.pi / 2),
              child: child,
            );
          },
        );
      },
    );
    return Scaffold(
      key: const ValueKey('story-viewer'),
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: _drag,
        builder: (context, child) {
          final t = (_drag.value / 400).clamp(0.0, 1.0);
          return ColoredBox(
            color: Colors.black.withValues(alpha: 1 - t),
            child: Transform.translate(
              offset: Offset(0, _drag.value),
              child: Transform.scale(
                scale: 1 - 0.15 * t,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28 * t),
                  clipBehavior: t == 0 ? Clip.none : Clip.antiAlias,
                  child: child,
                ),
              ),
            ),
          );
        },
        child: GestureDetector(
          excludeFromSemantics: true,
          onTapUp: _tap,
          onLongPressStart: (_) => _hold(true),
          onLongPressEnd: (_) => _hold(false),
          onVerticalDragStart: _dragStart,
          onVerticalDragUpdate: _dragUpdate,
          onVerticalDragEnd: _dragEnd,
          child: pages,
        ),
      ),
    );
  }

  Widget _story(BuildContext context, int i) {
    final s = _stories![i];
    final seg = (_segment[i] ?? 0).clamp(0, s.posts.length - 1);
    final post = s.posts[seg];
    final liked = _liked[post.id] ?? post.liked;
    final manual = _manual;
    final created = post.createdAt;
    const white = Colors.white;
    Widget round(String tip, IconData icon, VoidCallback onTap, {Key? key}) =>
        Pressable(
          scale: 0.92,
          child: _Glassy(
            child: IconButton(
              key: key,
              tooltip: tip,
              onPressed: onTap,
              color: white,
              icon: Icon(icon),
            ),
          ),
        );
    final chrome = SafeArea(
      child: AnimatedOpacity(
        opacity: _chrome ? 1 : 0,
        duration: motion(context, shortDuration),
        curve: easeOut,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: _Bars(
                count: s.posts.length,
                index: seg,
                progress: i == _page ? _progress : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
              child: Row(
                children: [
                  CreatorAvatar(
                    id: s.creator.id,
                    name: s.creator.name,
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      s.creator.handle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (created != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      timeAgo(created, short: true),
                      style: TextStyle(color: white.withValues(alpha: 0.7)),
                    ),
                  ],
                  const Spacer(),
                  round('Close', Icons.close_rounded, _close),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  if (manual) ...[
                    round('Previous', Icons.chevron_left_rounded, _prev),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Pressable(
                        child: _Glassy(
                          child: Semantics(
                            button: true,
                            child: InkWell(
                              onTap: () => _viewPost(post),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.open_in_full_rounded,
                                      size: 18,
                                      color: white,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'View post',
                                      style: TextStyle(
                                        color: white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Pressable(
                    scale: 0.92,
                    child: _Glassy(
                      child: IconButton(
                        key: const ValueKey('story-like'),
                        tooltip: liked ? 'Unlike' : 'Like',
                        onPressed: () => _like(post),
                        icon: Icon(
                          liked ? Icons.favorite : Icons.favorite_border,
                          color: liked ? Brand.of(context).glowB : white,
                        ),
                      ),
                    ),
                  ),
                  if (manual) ...[
                    const SizedBox(width: 8),
                    round('Next', Icons.chevron_right_rounded, _next),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        Semantics(
          key: const ValueKey('story-segment'),
          label:
              'Story from ${s.creator.name}, ${seg + 1} of ${s.posts.length}',
          child: post.locked
              ? LockedMedia(post: post)
              : MediaView(mediaId: post.media.first.id),
        ),
        // Scrims keep the white chrome legible over bright media.
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.18, 0.8, 1],
                colors: [
                  Color(0x73000000),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0x59000000),
                ],
              ),
            ),
          ),
        ),
        chrome,
      ],
    );
  }
}

/// The dark frosted pill/circle behind story controls.
class _Glassy extends StatelessWidget {
  const _Glassy({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Glass(
    borderRadius: const BorderRadius.all(Radius.circular(999)),
    color: Colors.black.withValues(alpha: 0.35),
    border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

/// One thin bar per segment: past full, current filling, future empty.
class _Bars extends StatelessWidget {
  const _Bars({required this.count, required this.index, this.progress});
  final int count;
  final int index;
  final Animation<double>? progress;

  @override
  Widget build(BuildContext context) {
    final p = progress ?? kAlwaysDismissedAnimation;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: p,
        builder: (context, _) => Row(
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 2.5,
                  alignment: AlignmentDirectional.centerStart,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    widthFactor: i < index ? 1 : (i > index ? 0 : p.value),
                    heightFactor: 1,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.circular(2)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
