import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../app/ui.dart';
import '../../core/api_client.dart';
import '../../core/money.dart';
import '../commerce/commerce_api.dart';
import '../messages/messages_screens.dart';
import 'content_api.dart';
import 'media_view.dart';

Widget asyncBody<T>(
  AsyncValue<T> value,
  VoidCallback retry,
  Widget Function(T) builder, {
  Widget Function()? loading,
}) => value.when(
  data: builder,
  loading: loading ?? () => const SkeletonList(),
  error: (e, _) => StateView(
    icon: Icons.cloud_off_outlined,
    title: apiErrorMessage(e),
    action: TextButton(onPressed: retry, child: const Text('Try again')),
  ),
);

/// Side gutter that centres a [maxWidth] column on wide screens.
double _gutter(BuildContext context, [double maxWidth = 640]) =>
    math.max(16, (MediaQuery.sizeOf(context).width - maxWidth) / 2);

/// IT.md F3.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  String _query = '';
  String? _category;

  /// Last results, kept on screen while a new query loads, so typing doesn't
  /// flash a skeleton on every keystroke.
  List<Creator>? _last;

  @override
  Widget build(BuildContext context) {
    final filter = (query: _query, category: _category);
    final results = ref.watch(discoveryProvider(filter));
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    if (results.hasValue) _last = results.value;
    final shown = results.valueOrNull ?? (results.isLoading ? _last : null);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final gutter = _gutter(context, 980);
    // The header scrolls with the results, so large text never squeezes them.
    final header = <Widget>[
      SliverToBoxAdapter(
        child: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text('Discover', style: text.headlineMedium),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Find creators worth supporting.',
                      style: text.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SearchBar(
                      key: const ValueKey('discover-search'),
                      hintText: 'Search creators',
                      leading: const Icon(Icons.search),
                      onChanged: (q) => setState(() => _query = q.trim()),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: gutter - 4),
            children: [
              for (final category in categories)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(category),
                    selected: _category == category,
                    onSelected: (on) {
                      HapticFeedback.selectionClick();
                      setState(() => _category = on ? category : null);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    ];
    Widget fill(Widget child) => CustomScrollView(
      slivers: [
        ...header,
        SliverFillRemaining(child: child),
      ],
    );
    Widget list(List<Creator> creators) => creators.isEmpty
        ? fill(
            const StateView(
              icon: Icons.search_off_rounded,
              title: 'No creators found',
              message: 'Try another name or category.',
            ),
          )
        : CreatorList(
            creators: creators,
            heroPrefix: 'discover',
            leading: header,
          );
    return Scaffold(
      // Ambient light behind everything; the feed scrolls over it.
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackground()),
          shown != null
              ? list(shown)
              : results.when(
                  data: list,
                  loading: () => fill(const SkeletonList(itemHeight: 188)),
                  error: (e, _) => fill(
                    StateView(
                      icon: Icons.cloud_off_outlined,
                      title: apiErrorMessage(e),
                      action: TextButton(
                        onPressed: () =>
                            ref.invalidate(discoveryProvider(filter)),
                        child: const Text('Try again'),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class CreatorList extends StatelessWidget {
  const CreatorList({
    super.key,
    required this.creators,
    required this.heroPrefix,
    this.leading = const [],
  });
  final List<Creator> creators;

  /// Slivers scrolled above the list (a screen's header).
  final List<Widget> leading;

  /// Discover and Following both stay mounted in the tab stack, so their
  /// avatars need distinct hero tags.
  final String heroPrefix;

  @override
  Widget build(BuildContext context) {
    final gutter = _gutter(context, 980);
    // Two columns once a card would stretch past a comfortable reading width.
    final columns = MediaQuery.sizeOf(context).width >= 720 ? 2 : 1;
    final rows = (creators.length / columns).ceil();
    Widget card(int i) => Entrance(
      key: ValueKey(creators[i].id),
      index: i,
      child: CreatorCard(
        creator: creators[i],
        heroTag: '$heroPrefix-${creators[i].id}',
      ),
    );
    return CustomScrollView(
      slivers: [
        ...leading,
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            gutter,
            8,
            gutter,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          sliver: SliverList.separated(
            itemCount: rows,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, row) => columns == 1
                ? card(row)
                : IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var col = 0; col < columns; col++) ...[
                          if (col > 0) const SizedBox(width: 14),
                          Expanded(
                            child: row * columns + col < creators.length
                                ? card(row * columns + col)
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Hero for avatars that change size between routes.
Widget _avatarHero(String? tag, Widget child) => tag == null
    ? child
    : Hero(
        tag: tag,
        flightShuttleBuilder: (_, _, _, _, to) =>
            FittedBox(child: (to.widget as Hero).child),
        child: child,
      );

class CreatorCard extends StatelessWidget {
  const CreatorCard({super.key, required this.creator, required this.heroTag});
  final Creator creator;
  final String heroTag;

  static const _bannerHeight = 96.0;
  static const _avatarSize = 56.0;

  @override
  Widget build(BuildContext context) {
    final c = creator;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final card = scheme.surfaceContainerLow;
    Widget shell(Widget child) => Pressable(
      child: Material(
        color: card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(cardRadius)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          onTap: () => context.push('/c/${c.handle}', extra: heroTag),
          child: child,
        ),
      ),
    );
    final muted = text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    // Accessibility text sizes: a dense row reads better than a tall card.
    if (MediaQuery.textScalerOf(context).scale(1) > 1.4) {
      return shell(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _avatarHero(
                heroTag,
                CreatorAvatar(
                  id: c.id,
                  name: c.displayName,
                  size: 48,
                  ring: c.isSubscribed,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.displayName,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text('@${c.handle}', style: muted),
                    Text(
                      '${compactCount(c.followers)} followers',
                      style: muted,
                    ),
                  ],
                ),
              ),
              if (c.isFollowing)
                Icon(
                  Icons.favorite,
                  size: 18,
                  color: scheme.primary,
                  semanticLabel: 'Following',
                ),
            ],
          ),
        ),
      );
    }
    return shell(
      Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: _bannerHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CreatorBanner(id: c.id),
                    if (c.isFollowing)
                      const Positioned(
                        top: 12,
                        right: 12,
                        child: _GlassTag(
                          icon: Icons.favorite,
                          label: 'Following',
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 36, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            c.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.verified,
                          size: 16,
                          color: scheme.primary,
                          semanticLabel: 'Verified creator',
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${c.handle} · ${c.categories.join(', ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (c.bio.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        c.bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      '${compactCount(c.followers)} followers',
                      style: text.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 14,
            top: _bannerHeight - _avatarSize / 2 - 3,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(shape: BoxShape.circle, color: card),
              child: _avatarHero(
                heroTag,
                CreatorAvatar(
                  id: c.id,
                  name: c.displayName,
                  size: _avatarSize,
                  ring: c.isSubscribed,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small frosted label laid over imagery.
class _GlassTag extends StatelessWidget {
  const _GlassTag({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Glass(
      borderRadius: const BorderRadius.all(Radius.circular(999)),
      color: Colors.black.withValues(alpha: 0.32),
      border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FollowingScreen extends ConsumerWidget {
  const FollowingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: tabAppBar(context, 'Following'),
      body: asyncBody(
        ref.watch(followingProvider),
        () => ref.invalidate(followingProvider),
        (creators) => creators.isEmpty
            ? const StateView(
                icon: Icons.favorite_outline,
                title: 'Follow creators to see them here',
                message: 'Tap Follow on any creator in Discover.',
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(followingProvider.future),
                child: CreatorList(creators: creators, heroPrefix: 'following'),
              ),
        loading: () => const SkeletonList(itemHeight: 188),
      ),
    );
  }
}

/// IT.md F4.
class CreatorPage extends ConsumerStatefulWidget {
  const CreatorPage({super.key, required this.handle, this.heroTag});
  final String handle;

  /// Tag of the avatar this page was opened from, for the shared transition.
  final String? heroTag;

  @override
  ConsumerState<CreatorPage> createState() => _CreatorPageState();
}

class _CreatorPageState extends ConsumerState<CreatorPage> {
  /// Scrolled past the banner: the bar needs its own background again.
  bool _scrolled = false;

  bool _onScroll(ScrollNotification n) {
    final scrolled = n.metrics.axis == Axis.vertical && n.metrics.pixels > 96;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final handle = widget.handle;
    final creator = ref.watch(creatorProvider(handle));
    final loaded = creator.hasValue && !creator.hasError;
    // White over the dark banner; normal colours over the skeleton, an error,
    // or the page once the banner has scrolled away.
    final overBanner = loaded && !_scrolled;
    final onBanner = overBanner ? Colors.white : null;
    return Scaffold(
      extendBodyBehindAppBar: loaded,
      appBar: AppBar(
        backgroundColor: overBanner ? Colors.transparent : null,
        foregroundColor: onBanner,
        systemOverlayStyle: overBanner ? SystemUiOverlayStyle.light : null,
        title: Text('@$handle'),
        actions: [
          PopupMenuButton<String>(
            iconColor: onBanner,
            onSelected: (_) {
              final id = creator.valueOrNull?.id;
              if (id != null) {
                showReportDialog(
                  context,
                  ref,
                  targetType: 'user',
                  targetId: id,
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'report', child: Text('Report')),
            ],
          ),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: asyncBody(
          creator,
          () => ref.invalidate(creatorProvider(handle)),
          (c) => _CreatorBody(creator: c, heroTag: widget.heroTag),
        ),
      ),
    );
  }
}

class _CreatorBody extends ConsumerStatefulWidget {
  const _CreatorBody({required this.creator, this.heroTag});
  final Creator creator;
  final String? heroTag;

  @override
  ConsumerState<_CreatorBody> createState() => _CreatorBodyState();
}

class _CreatorBodyState extends ConsumerState<_CreatorBody> {
  late Creator _creator = widget.creator;
  bool _busy = false;

  Future<void> _toggleFollow() async {
    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    try {
      _creator = await setFollowing(
        ref.read(dioProvider),
        _creator.id,
        !_creator.isFollowing,
      );
      ref.invalidate(creatorPostsProvider(_creator.id));
      ref.invalidate(followingProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static const _avatarSize = 92.0;

  @override
  Widget build(BuildContext context) {
    final c = _creator;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final posts = ref.watch(creatorPostsProvider(c.id));
    final tier = ref.watch(tiersProvider(c.id)).valueOrNull?.firstOrNull;
    final bannerHeight = 168 + MediaQuery.paddingOf(context).top;
    final gutter = _gutter(context, 720);
    final postCount = posts.valueOrNull?.length;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: bannerHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CreatorBanner(id: c.id),
                        // Melts the banner into the page.
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.45, 1],
                              colors: [
                                scheme.surface.withValues(alpha: 0),
                                scheme.surface,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(gutter, 14, gutter, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            left: _avatarSize + 16,
                          ),
                          child: Wrap(
                            spacing: 20,
                            runSpacing: 8,
                            children: [
                              _Stat(
                                value: compactCount(c.followers),
                                label: 'followers',
                              ),
                              if (postCount != null)
                                _Stat(
                                  value: compactCount(postCount),
                                  label: postCount == 1 ? 'post' : 'posts',
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                c.displayName,
                                style: text.headlineSmall,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.verified,
                              size: 20,
                              color: scheme.primary,
                              semanticLabel: 'Verified creator',
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${c.handle}',
                          style: text.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        if (c.bio.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(c.bio, style: text.bodyLarge),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final category in c.categories)
                              Chip(label: Text(category)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _actions(c, tier),
                        const SizedBox(height: 28),
                        Text('Posts', style: text.titleMedium),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                left: gutter - 4,
                top: bannerHeight - _avatarSize * 0.62,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.surface,
                  ),
                  child: _avatarHero(
                    widget.heroTag,
                    CreatorAvatar(
                      id: c.id,
                      name: c.displayName,
                      size: _avatarSize,
                      ring: c.isSubscribed,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ...posts.when(
          loading: () => [
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              sliver: SliverGrid.builder(
                gridDelegate: _postGrid,
                itemCount: 4,
                itemBuilder: (_, _) => const Shimmer(
                  child: Skeleton(height: double.infinity, radius: cardRadius),
                ),
              ),
            ),
          ],
          error: (e, _) => [
            SliverToBoxAdapter(
              child: StateView(
                icon: Icons.cloud_off_outlined,
                title: apiErrorMessage(e),
              ),
            ),
          ],
          data: (items) => [
            if (items.isEmpty)
              const SliverToBoxAdapter(
                child: StateView(
                  icon: Icons.photo_library_outlined,
                  title: 'No posts yet',
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                gutter,
                0,
                gutter,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverGrid.builder(
                gridDelegate: _postGrid,
                itemCount: items.length,
                itemBuilder: (context, i) => Entrance(
                  index: i,
                  child: PostTile(post: items[i]),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// On phones Subscribe leads on its own row, with follow and message
  /// beneath; wider screens fit all three on one row.
  Widget _actions(Creator c, Map<String, dynamic>? tier) {
    final scheme = Theme.of(context).colorScheme;
    final subscribe = Pressable(
      child: FilledButton(
        key: const ValueKey('subscribe'),
        style: brandButtonStyle(context),
        onPressed: c.isSubscribed
            ? null
            : () => context.push('/checkout/subscription/${c.id}'),
        child: Text(
          c.isSubscribed
              ? 'Subscribed'
              : tier == null
              ? 'Subscribe'
              : 'Subscribe · '
                    '${formatKes(tier['priceCents'] as int)}/mo',
          textAlign: TextAlign.center,
        ),
      ),
    );
    final secondary = [
      Expanded(
        child: AnimatedSwitcher(
          duration: motion(context, shortDuration),
          switchInCurve: easeOut,
          switchOutCurve: easeOut,
          // Passthrough, so the button keeps the full slot width.
          layoutBuilder: (current, previous) => Stack(
            fit: StackFit.passthrough,
            alignment: Alignment.center,
            children: [...previous, ?current],
          ),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: 0.96, end: 1.0).animate(animation),
              child: child,
            ),
          ),
          child: c.isFollowing
              ? OutlinedButton.icon(
                  key: const ValueKey('follow'),
                  onPressed: _busy ? null : _toggleFollow,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Following'),
                )
              : FilledButton.tonal(
                  key: const ValueKey('follow'),
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.surfaceContainerHighest,
                    foregroundColor: scheme.onSurface,
                  ),
                  onPressed: _busy ? null : _toggleFollow,
                  child: const Text('Follow'),
                ),
        ),
      ),
      const SizedBox(width: 10),
      IconButton.outlined(
        key: const ValueKey('message-creator'),
        tooltip: 'Message',
        style: IconButton.styleFrom(
          minimumSize: const Size(52, 52),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(controlRadius)),
          ),
        ),
        onPressed: () => openChat(context, ref, c.id),
        icon: const Icon(Icons.chat_bubble_outline),
      ),
    ];
    if (MediaQuery.sizeOf(context).width >= 560) {
      return Row(
        children: [
          Expanded(flex: 2, child: subscribe),
          const SizedBox(width: 10),
          ...secondary,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        subscribe,
        const SizedBox(height: 10),
        Row(children: secondary),
      ],
    );
  }
}

const _postGrid = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 240,
  childAspectRatio: 0.78,
  mainAxisSpacing: 10,
  crossAxisSpacing: 10,
);

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: text.titleLarge?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label,
          style: text.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class PostTile extends StatelessWidget {
  const PostTile({super.key, required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(cardRadius)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              label: post.locked
                  ? 'Locked post: ${post.caption}'
                  : post.caption,
              child: post.locked || post.media.isEmpty
                  ? LockedMedia(post: post)
                  : MediaView(mediaId: post.media.first.id),
            ),
            // Ink above the image, so the press ripple is visible.
            Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: () => context.push('/p/${post.id}')),
            ),
          ],
        ),
      ),
    );
  }
}

/// IT.md F5: media only after the server authorises it.
class PostDetailScreen extends ConsumerWidget {
  const PostDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(postProvider(id));
    final locked = value.valueOrNull?.locked == true ? value.valueOrNull : null;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      // The unlock panel floats over the content.
      extendBody: true,
      appBar: AppBar(
        title: const Text('Post'),
        actions: [
          IconButton(
            tooltip: 'Report',
            onPressed: () => showReportDialog(
              context,
              ref,
              targetType: 'post',
              targetId: id,
            ),
            icon: const Icon(Icons.flag_outlined),
          ),
        ],
      ),
      body: asyncBody(
        value,
        () => ref.invalidate(postProvider(id)),
        (post) => ListView(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: CreatorAvatar(
                        id: post.creatorId,
                        name: post.creatorName,
                        size: 42,
                      ),
                      title: Text(post.creatorName, style: text.titleMedium),
                      subtitle: Text('@${post.creatorHandle}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/c/${post.creatorHandle}'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(cardRadius),
                        ),
                        child: AspectRatio(
                          aspectRatio: 4 / 5,
                          child: post.locked
                              ? LockedMedia(post: post)
                              : PageView(
                                  children: [
                                    for (final m in post.media)
                                      MediaView(
                                        mediaId: m.id,
                                        fit: BoxFit.contain,
                                      ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    if (post.caption.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Text(post.caption, style: text.bodyLarge),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // The price and exact access stay on screen while scrolling (IT.md F5).
      bottomNavigationBar: locked == null
          ? null
          : Glass(
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
              child: SafeArea(
                top: false,
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lock_outline,
                                size: 20,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(switch (locked.access) {
                                  'paid' =>
                                    'One-time purchase: permanent access to this post '
                                        '(${locked.media.length} item'
                                        '${locked.media.length == 1 ? '' : 's'}). '
                                        'Price in KES, all fees included.',
                                  'subscribers' =>
                                    'Available to subscribers of @${locked.creatorHandle}.',
                                  _ =>
                                    'Follow @${locked.creatorHandle} to see this post.',
                                }, style: text.bodyMedium),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Pressable(
                            child: FilledButton(
                              key: const ValueKey('unlock'),
                              style: brandButtonStyle(context),
                              onPressed: () => locked.access == 'followers'
                                  ? context.push('/c/${locked.creatorHandle}')
                                  : locked.access == 'paid'
                                  ? context.push('/checkout/post/${locked.id}')
                                  : context.push(
                                      '/checkout/subscription/${locked.creatorId}',
                                    ),
                              child: Text(switch (locked.access) {
                                'paid' =>
                                  'Unlock for ${formatKes(locked.priceCents!)}',
                                'subscribers' => 'Subscribe to unlock',
                                _ => 'Go to profile to follow',
                              }),
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
