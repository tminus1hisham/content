import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../app/ui.dart';
import '../../core/prefs.dart';
import '../auth/auth_controller.dart';
import 'content_api.dart';
import 'discover_screens.dart';

const maxPins = 6;

/// Creators the fan pinned to the top of Following, in pin order. Kept on
/// this device, per account.
final pinnedCreatorsProvider = NotifierProvider<PinnedCreators, List<String>>(
  PinnedCreators.new,
);

class PinnedCreators extends Notifier<List<String>> {
  String? get _key {
    final user = ref.read(authProvider).user?.id;
    return user == null ? null : 'following.pins.$user';
  }

  @override
  List<String> build() {
    ref.watch(authProvider.select((a) => a.user?.id));
    final key = _key;
    return key == null
        ? const []
        : ref.read(sharedPreferencesProvider).getStringList(key) ?? const [];
  }

  /// Pins or unpins [id], dropping pins for creators no longer in
  /// [following]. False when pinning would pass [maxPins].
  bool toggle(String id, Iterable<String> following) {
    final key = _key;
    if (key == null) return false;
    final pins = state.where(following.contains).toList();
    if (!pins.remove(id)) {
      if (pins.length >= maxPins) return false;
      pins.add(id);
    }
    state = pins;
    ref.read(sharedPreferencesProvider).setStringList(key, pins);
    return true;
  }
}

/// Pins or unpins [c] and says so.
void _togglePin(BuildContext context, WidgetRef ref, Creator c) {
  final following = ref.read(followingProvider).valueOrNull ?? const [];
  final wasPinned = ref.read(pinnedCreatorsProvider).contains(c.id);
  final ok = ref
      .read(pinnedCreatorsProvider.notifier)
      .toggle(c.id, following.map((f) => f.id));
  HapticFeedback.selectionClick();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          !ok
              ? 'You can pin up to $maxPins creators'
              : wasPinned
              ? 'Unpinned ${c.displayName}'
              : 'Pinned ${c.displayName}',
        ),
      ),
    );
}

/// IT.md F4 follow list: the fan's pinned favourites above everyone they
/// follow, with a sliding Following / Subscribed switch.
class FollowingScreen extends ConsumerWidget {
  const FollowingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final following = ref.watch(followingProvider);
    final creators = following.valueOrNull ?? const <Creator>[];
    return DefaultTabController(
      length: 2,
      animationDuration: motion(context, mediumDuration),
      child: Scaffold(
        appBar: tabAppBar(
          context,
          'Following',
          actions: [
            TextButton(
              onPressed: creators.isEmpty
                  ? null
                  : () => _showPinSheet(context, creators),
              child: const Text('Edit pins'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _SlideTabs(),
            ),
            Expanded(
              child: asyncBody(
                following,
                () => ref.invalidate(followingProvider),
                (creators) => TabBarView(
                  children: [
                    _Shelves(
                      creators: creators,
                      heroPrefix: 'following-all',
                      promptPins: true,
                      empty: const StateView(
                        icon: Icons.favorite_outline,
                        title: 'Follow creators to see them here',
                        message: 'Tap Follow on any creator in Discover.',
                      ),
                    ),
                    _Shelves(
                      creators: [
                        for (final c in creators)
                          if (c.isSubscribed) c,
                      ],
                      heroPrefix: 'following-sub',
                      empty: const StateView(
                        icon: Icons.star_outline_rounded,
                        title: 'No subscriptions yet',
                        message:
                            "Subscribe to a creator and they'll show up here.",
                      ),
                    ),
                  ],
                ),
                loading: () => const SkeletonList(count: 4, itemHeight: 120),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two segments on a track; the lit pill slides between them and follows a
/// swipe across the pages.
class _SlideTabs extends StatelessWidget {
  const _SlideTabs();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: const BorderRadius.all(Radius.circular(controlRadius)),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: TabBar(
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: scheme.onSurface,
          borderRadius: const BorderRadius.all(
            Radius.circular(controlRadius - 4),
          ),
        ),
        dividerHeight: 0,
        labelColor: scheme.surface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        tabs: const [
          Tab(text: 'Following'),
          Tab(text: 'Subscribed'),
        ],
      ),
    );
  }
}

/// One page of the switch: pinned creators, then everyone else.
class _Shelves extends ConsumerStatefulWidget {
  const _Shelves({
    required this.creators,
    required this.heroPrefix,
    required this.empty,
    this.promptPins = false,
  });
  final List<Creator> creators;

  /// Both pages stay mounted, so their avatars need distinct hero tags.
  final String heroPrefix;
  final Widget empty;

  /// Invite the fan to pin when nothing is pinned yet.
  final bool promptPins;

  @override
  ConsumerState<_Shelves> createState() => _ShelvesState();
}

// Kept alive so swiping back doesn't replay the entrance or lose the scroll.
class _ShelvesState extends ConsumerState<_Shelves>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final creators = widget.creators;
    final bottom = 24 + MediaQuery.paddingOf(context).bottom;
    if (creators.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverFillRemaining(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottom),
              child: widget.empty,
            ),
          ),
        ],
      );
    }
    final pinIds = ref.watch(pinnedCreatorsProvider);
    final byId = {for (final c in creators) c.id: c};
    final pinned = [
      for (final id in pinIds)
        if (byId[id] != null) byId[id]!,
    ];
    final rest = [
      for (final c in creators)
        if (!pinIds.contains(c.id)) c,
    ];
    final gutter = gutterFor(context, 980);
    Widget header(String label) => SliverPadding(
      padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 10),
      sliver: SliverToBoxAdapter(
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
    Widget grid(List<Creator> list, {bool pinned = false}) => SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: gutter),
      sliver: _ShelfGrid(
        creators: list,
        heroPrefix: widget.heroPrefix,
        pinned: pinned,
      ),
    );
    return RefreshIndicator(
      onRefresh: () => ref.refresh(followingProvider.future),
      child: CustomScrollView(
        slivers: [
          if (pinned.isNotEmpty) ...[
            header('Pinned'),
            grid(pinned, pinned: true),
            header('Everyone else'),
          ] else if (widget.promptPins)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 8),
              sliver: SliverToBoxAdapter(
                child: _PinPrompt(
                  onChoose: () => _showPinSheet(context, creators),
                ),
              ),
            ),
          grid(rest),
          SliverToBoxAdapter(child: SizedBox(height: bottom)),
        ],
      ),
    );
  }
}

/// Creators in rows of two (four on wide screens, one at large text sizes),
/// each row as tall as its tallest tile.
class _ShelfGrid extends StatelessWidget {
  const _ShelfGrid({
    required this.creators,
    required this.heroPrefix,
    required this.pinned,
  });
  final List<Creator> creators;
  final String heroPrefix;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final columns = large
        ? 1
        : MediaQuery.sizeOf(context).width >= 720
        ? 4
        : 2;
    final rows = (creators.length / columns).ceil();
    Widget tile(int i) => Entrance(
      key: ValueKey(creators[i].id),
      index: i,
      child: _ShelfTile(
        creator: creators[i],
        heroTag: '$heroPrefix-${creators[i].id}',
        pinned: pinned,
        compact: large,
      ),
    );
    return SliverList.separated(
      itemCount: rows,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, row) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var col = 0; col < columns; col++) ...[
              if (col > 0) const SizedBox(width: 12),
              Expanded(
                child: row * columns + col < creators.length
                    ? tile(row * columns + col)
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A followed creator: ringed when subscribed. Long-press pins.
class _ShelfTile extends ConsumerWidget {
  const _ShelfTile({
    required this.creator,
    required this.heroTag,
    required this.pinned,
    required this.compact,
  });
  final Creator creator;
  final String heroTag;
  final bool pinned;

  /// A row instead of a stacked tile, for large text sizes.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = creator;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final avatar = avatarHero(
      heroTag,
      CreatorAvatar(
        id: c.id,
        name: c.displayName,
        size: compact ? 48 : 64,
        ring: c.isSubscribed,
      ),
    );
    final name = Text(
      c.displayName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: compact ? TextAlign.start : TextAlign.center,
      style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    );
    final handle = Text(
      c.isSubscribed ? '@${c.handle} · Subscribed' : '@${c.handle}',
      maxLines: compact ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      textAlign: compact ? TextAlign.start : TextAlign.center,
      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
    );
    final pin = Icon(
      Icons.push_pin,
      size: 16,
      color: scheme.primary,
      semanticLabel: 'Pinned',
    );
    return Pressable(
      child: Material(
        color: scheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(cardRadius)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          onTap: () => context.push('/c/${c.handle}', extra: heroTag),
          onLongPress: () => _togglePin(context, ref, c),
          child: compact
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      avatar,
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [name, handle],
                        ),
                      ),
                      if (pinned) pin,
                    ],
                  ),
                )
              : Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 18, 12, 16),
                      child: Column(
                        children: [
                          avatar,
                          const SizedBox(height: 10),
                          name,
                          const SizedBox(height: 2),
                          handle,
                        ],
                      ),
                    ),
                    if (pinned) Positioned(top: 10, right: 10, child: pin),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Shown above the shelf until something is pinned.
class _PinPrompt extends StatelessWidget {
  const _PinPrompt({required this.onChoose});
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: const BorderRadius.all(Radius.circular(cardRadius)),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.push_pin_outlined, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keep favourites close',
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Pin up to $maxPins creators to keep them at the top.',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onChoose, child: const Text('Choose')),
        ],
      ),
    );
  }
}

/// Every followed creator with a pin toggle; pinned ones first.
void _showPinSheet(BuildContext context, List<Creator> creators) {
  showModalBottomSheet<void>(
    context: context,
    // Above the shell's floating tab bar.
    useRootNavigator: true,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheet) => Consumer(
      builder: (sheet, ref, _) {
        final pins = ref.watch(pinnedCreatorsProvider);
        final text = Theme.of(sheet).textTheme;
        final muted = text.bodyMedium?.copyWith(
          color: Theme.of(sheet).colorScheme.onSurfaceVariant,
        );
        final ordered = [
          for (final id in pins) ...creators.where((c) => c.id == id),
          for (final c in creators)
            if (!pins.contains(c.id)) c,
        ];
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pinned creators', style: text.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      'Pin up to $maxPins. They stay at the top of Following '
                      'on this device.',
                      style: muted,
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    for (final c in ordered)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                        ),
                        leading: CreatorAvatar(
                          id: c.id,
                          name: c.displayName,
                          size: 40,
                        ),
                        title: Text(c.displayName),
                        subtitle: Text('@${c.handle}'),
                        trailing: IconButton(
                          isSelected: pins.contains(c.id),
                          icon: const Icon(Icons.push_pin_outlined),
                          selectedIcon: Icon(
                            Icons.push_pin,
                            color: Theme.of(sheet).colorScheme.primary,
                          ),
                          tooltip: pins.contains(c.id)
                              ? 'Unpin ${c.displayName}'
                              : 'Pin ${c.displayName}',
                          onPressed: () => _togglePin(sheet, ref, c),
                        ),
                        onTap: () => _togglePin(sheet, ref, c),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
