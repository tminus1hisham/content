import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/motion.dart';
import '../../app/schedule_picker.dart';
import '../../app/theme.dart';
import '../../app/ui.dart';
import '../../core/api_client.dart';
import '../../core/money.dart';
import '../onboarding/onboarding_controller.dart';
import 'content_api.dart';
import 'media_view.dart';

void _snack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

/// Side gutter that centres a [maxWidth] column on wide screens.
double _gutter(BuildContext context, [double maxWidth = 640]) =>
    math.max(16, (MediaQuery.sizeOf(context).width - maxWidth) / 2);

bool _largeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1) > 1.4;

/// Raised surface with a hairline border: the composer and dashboard cards.
class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(cardRadius)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Leading icon in a tonal rounded square.
class _IconTile extends StatelessWidget {
  const _IconTile(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SizedBox.square(
        dimension: 36,
        child: Icon(icon, size: 20, color: scheme.primary),
      ),
    );
  }
}

/// Lays [children] out in rows of [columns] equal-height cells; no fixed
/// heights, so large text grows the cards instead of overflowing them.
class _CardRows extends StatelessWidget {
  const _CardRows({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 4 : 2;
        const gap = 12.0;
        return Column(
          children: [
            for (var row = 0; row < children.length; row += columns) ...[
              if (row > 0) const SizedBox(height: gap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = row; i < row + columns; i++) ...[
                      if (i > row) const SizedBox(width: gap),
                      Expanded(
                        child: i < children.length
                            ? children[i]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// IT.md C7, shown on the creator Home tab once approved.
class CreatorDashboard extends ConsumerWidget {
  const CreatorDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(analyticsProvider);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final data = stats.valueOrNull;
    final loading = data == null && stats.isLoading;
    Widget stat(IconData icon, String label, Object? value) =>
        _StatCard(icon: icon, label: label, value: value, loading: loading);
    Widget action(IconData icon, String label, VoidCallback onTap) =>
        _ActionCard(icon: icon, label: label, onTap: onTap);
    final gutter = _gutter(context, 760);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(analyticsProvider.future),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          gutter,
          8,
          gutter,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          const Entrance(child: _Greeting()),
          const SizedBox(height: 24),
          Entrance(
            index: 1,
            child: _CardRows(
              children: [
                stat(Icons.favorite_outline, 'Followers', data?['followers']),
                stat(
                  Icons.workspace_premium_outlined,
                  'Subscribers',
                  data?['subscribers'],
                ),
                stat(Icons.photo_library_outlined, 'Posts', data?['posts']),
                stat(Icons.visibility_outlined, 'Views', data?['views']),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Semantics(
            header: true,
            child: Text(
              'Quick actions',
              style: text.titleMedium?.copyWith(color: scheme.onSurface),
            ),
          ),
          const SizedBox(height: 12),
          Entrance(
            index: 2,
            child: _CardRows(
              children: [
                action(
                  Icons.add_photo_alternate_outlined,
                  'New post',
                  () => context.push('/studio/new'),
                ),
                action(
                  Icons.videocam_outlined,
                  'Go live',
                  () => context.go('/go-live'),
                ),
                action(
                  Icons.account_balance_wallet_outlined,
                  'Earnings',
                  () => context.push('/earnings'),
                ),
                action(
                  Icons.chat_bubble_outline,
                  'Messages',
                  () => context.go('/messages'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Time-of-day greeting on a softly lit card.
class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final hour = DateTime.now().hour;
    final greeting = hour >= 5 && hour < 12
        ? 'Good morning'
        : hour >= 12 && hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(cardRadius)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: const BorderRadius.all(Radius.circular(cardRadius)),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: GlowBackground()),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified, size: 18, color: scheme.primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          statusLabels['approved']!,
                          style: text.labelLarge?.copyWith(
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    header: true,
                    child: Text(greeting, style: text.headlineMedium),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Here's how your page is doing.",
                    style: text.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.loading,
  });
  final IconData icon;
  final String label;
  final Object? value;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final v = value;
    final figure = v is int ? compactCount(v) : '${v ?? '–'}';
    return Semantics(
      label: loading ? '$label: loading' : '$label: $figure',
      excludeSemantics: true,
      child: _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            loading
                ? const Shimmer(child: Skeleton(width: 64, height: 32))
                : Text(
                    figure,
                    style: text.headlineMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
            const SizedBox(height: 2),
            Text(
              label,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      child: Material(
        color: scheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(cardRadius)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _IconTile(icon),
                const SizedBox(height: 14),
                Text(label, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _studioTabs = [
  ('Drafts', 'draft'),
  ('Published', 'published'),
  ('Scheduled', 'scheduled'),
  ('Archived', 'archived'),
];

const _emptyMessages = {
  'draft': 'Drafts you save appear here.',
  'published': 'Posts you publish appear here.',
  'scheduled': 'Posts you schedule appear here.',
  'archived': 'Unpublished posts appear here.',
};

/// IT.md C9.
class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key});

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  String _status = 'published';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final gutter = _gutter(context, 980);
    // The header scrolls with the posts, so large text never squeezes them.
    final header = <Widget>[
      SliverToBoxAdapter(
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text('Studio', style: text.headlineMedium),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your posts, drafts and schedule.',
                  style: text.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 16),
          child: Row(
            children: [
              for (final (i, (label, status)) in _studioTabs.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(label),
                  selected: _status == status,
                  onSelected: (_) {
                    if (_status == status) return;
                    HapticFeedback.selectionClick();
                    setState(() => _status = status);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    ];
    return Scaffold(
      // Lifted above the frosted tab bar the body extends behind.
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: FloatingActionButton.extended(
          // Depth from tone, not shadow (a shadow reads as a dark halo here).
          elevation: 0,
          highlightElevation: 0,
          onPressed: () => context.push('/studio/new'),
          icon: const Icon(Icons.add),
          label: const Text('New post'),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackground()),
          _PostList(
            key: ValueKey(_status),
            status: _status,
            header: header,
            gutter: gutter,
          ),
        ],
      ),
    );
  }
}

class _PostList extends ConsumerWidget {
  const _PostList({
    super.key,
    required this.status,
    required this.header,
    required this.gutter,
  });
  final String status;
  final List<Widget> header;
  final double gutter;

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    Post post,
    String action,
  ) async {
    final dio = ref.read(dioProvider);
    try {
      switch (action) {
        case 'publish':
          await dio.post<void>('/posts/${post.id}/publish');
        case 'unpublish':
          await dio.post<void>('/posts/${post.id}/unpublish');
        case 'delete':
          final ok = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete post?'),
              content: const Text(
                'Fans who bought it keep their purchase record.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (ok != true) return;
          await dio.delete<void>('/posts/${post.id}');
      }
      for (final (_, s) in _studioTabs) {
        ref.invalidate(myPostsProvider(s));
      }
      ref.invalidate(analyticsProvider);
    } catch (e) {
      if (context.mounted) _snack(context, apiErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = _largeText(context)
        ? const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 480,
            childAspectRatio: 0.8,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          )
        : const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 240,
            childAspectRatio: 0.78,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          );
    // Room for the floating "New post" button above the tab bar.
    final bottom = 96 + MediaQuery.paddingOf(context).bottom;
    Widget fill(Widget child) => SliverFillRemaining(child: child);
    final body = ref
        .watch(myPostsProvider(status))
        .when(
          loading: () => [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, bottom),
              sliver: SliverGrid.builder(
                gridDelegate: grid,
                itemCount: 6,
                itemBuilder: (_, _) => const Shimmer(
                  child: Skeleton(height: double.infinity, radius: cardRadius),
                ),
              ),
            ),
          ],
          error: (e, _) => [
            fill(
              StateView(
                icon: Icons.cloud_off_outlined,
                title: apiErrorMessage(e),
                action: TextButton(
                  onPressed: () => ref.invalidate(myPostsProvider(status)),
                  child: const Text('Try again'),
                ),
              ),
            ),
          ],
          data: (posts) => [
            if (posts.isEmpty)
              fill(
                StateView(
                  icon: Icons.photo_library_outlined,
                  title: 'Nothing here yet',
                  message: _emptyMessages[status],
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, bottom),
                sliver: SliverGrid.builder(
                  gridDelegate: grid,
                  itemCount: posts.length,
                  itemBuilder: (context, i) => Entrance(
                    index: i,
                    child: _StudioTile(
                      post: posts[i],
                      status: status,
                      onAction: (a) => _act(context, ref, posts[i], a),
                    ),
                  ),
                ),
              ),
          ],
        );
    return CustomScrollView(slivers: [...header, ...body]);
  }
}

/// A post in the Studio grid: its cover with status and access tags.
class _StudioTile extends StatelessWidget {
  const _StudioTile({
    required this.post,
    required this.status,
    required this.onAction,
  });
  final Post post;
  final String status;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final price = post.access == 'paid'
        ? ' · ${formatKes(post.priceCents ?? 0)}'
        : '';
    final scheduled = post.publishAt != null && status == 'scheduled';
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(cardRadius)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          post.media.isEmpty
              ? ColoredBox(
                  color: scheme.surfaceContainerHigh,
                  child: Icon(
                    Icons.image_outlined,
                    color: scheme.onSurfaceVariant,
                  ),
                )
              : MediaView(mediaId: post.media.first.id),
          // Scrim so the caption and tags read on any image.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.25, 0.5, 1],
                colors: [
                  Colors.black.withValues(alpha: 0.32),
                  Colors.black.withValues(alpha: 0),
                  Colors.black.withValues(alpha: 0),
                  Colors.black.withValues(alpha: 0.72),
                ],
              ),
            ),
          ),
          if (scheduled)
            Positioned(
              top: 10,
              left: 10,
              right: 56,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _Tag(
                  icon: Icons.schedule,
                  label: MaterialLocalizations.of(
                    context,
                  ).formatShortDate(post.publishAt!),
                ),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz, color: Colors.white),
              onSelected: onAction,
              itemBuilder: (_) => [
                if (status != 'published')
                  const PopupMenuItem(
                    value: 'publish',
                    child: Text('Publish now'),
                  ),
                if (status == 'published')
                  const PopupMenuItem(
                    value: 'unpublish',
                    child: Text('Unpublish'),
                  ),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  post.caption.isEmpty ? '(No caption)' : post.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Tag(
                      icon: switch (post.access) {
                        'paid' => Icons.lock_outline,
                        'subscribers' => Icons.workspace_premium_outlined,
                        'followers' => Icons.favorite_outline,
                        _ => Icons.public,
                      },
                      label: '${accessLabels[post.access]}$price',
                    ),
                    if (post.views != null)
                      _Tag(
                        icon: Icons.visibility_outlined,
                        label: '${post.views} views',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small translucent label over imagery. No backdrop blur: a grid of tiles
/// would stack dozens of them.
class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 5),
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

class _Picked {
  _Picked(this.file, this.kind, this.bytes);
  final XFile file;
  final String kind;
  final Uint8List? bytes; // images only, for the preview
}

/// IT.md C8: pick, describe, set access and price, review, publish.
class ComposerScreen extends ConsumerStatefulWidget {
  const ComposerScreen({super.key});

  @override
  ConsumerState<ComposerScreen> createState() => _ComposerScreenState();
}

class _ComposerScreenState extends ConsumerState<ComposerScreen> {
  final _caption = TextEditingController();
  final _price = TextEditingController();
  final _picked = <_Picked>[];
  String _access = 'free';
  DateTime? _publishAt;
  bool _consent = false;
  String? _progress;

  static const minKes = 10; // server limits, re-checked on publish
  static const maxKes = 50000;

  @override
  void dispose() {
    _caption.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _addPhotos() async {
    final files = await ImagePicker().pickMultiImage(imageQuality: 90);
    for (final f in files) {
      _picked.add(_Picked(f, 'image', await f.readAsBytes()));
    }
    setState(() {});
  }

  Future<void> _addVideo() async {
    final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (file != null) setState(() => _picked.add(_Picked(file, 'video', null)));
  }

  Future<void> _pickSchedule() async {
    final at = await showSchedulePicker(context, initial: _publishAt);
    if (at != null && mounted) setState(() => _publishAt = at);
  }

  int? get _priceKes => int.tryParse(_price.text);

  String? get _priceError {
    if (_access != 'paid') return null;
    final kes = _priceKes;
    if (kes == null || kes < minKes || kes > maxKes) {
      return 'Price must be between KSh 10 and KSh 50,000';
    }
    return null;
  }

  Future<void> _submit({required bool publish}) async {
    if (_picked.isEmpty) return _snack(context, 'Add a photo or video');
    if (_priceError != null) return _snack(context, _priceError!);
    if (publish && !_consent) {
      return _snack(context, 'Confirm the consent statement to publish');
    }
    final dio = ref.read(dioProvider);
    try {
      final ids = <String>[];
      for (final (i, p) in _picked.indexed) {
        setState(() => _progress = 'Uploading ${i + 1} of ${_picked.length}');
        ids.add(
          await uploadMedia(dio, ref.read(uploadDioProvider), p.file, p.kind),
        );
      }
      setState(() => _progress = 'Saving');
      await dio.post<void>(
        '/posts',
        data: {
          'caption': _caption.text.trim(),
          'mediaIds': ids,
          'access': _access,
          if (_access == 'paid') 'priceCents': _priceKes! * 100,
          'publish': publish,
          'consent': _consent,
          if (_publishAt != null)
            'publishAt': _publishAt!.toUtc().toIso8601String(),
        },
      );
      for (final (_, s) in _studioTabs) {
        ref.invalidate(myPostsProvider(s));
      }
      ref.invalidate(analyticsProvider);
      if (!mounted) return;
      _snack(
        context,
        !publish
            ? 'Draft saved'
            : _publishAt != null
            ? 'Post scheduled'
            : 'Post published',
      );
      context.pop();
    } catch (e) {
      if (mounted) _snack(context, apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  Widget _media(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final buttons = Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          key: const ValueKey('composer-photos'),
          onPressed: _addPhotos,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('Photos'),
        ),
        OutlinedButton.icon(
          onPressed: _addVideo,
          icon: const Icon(Icons.video_call_outlined),
          label: const Text('Video'),
        ),
      ],
    );
    return CustomPaint(
      painter: _DashedBorder(color: scheme.outline.withValues(alpha: 0.6)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _picked.isEmpty
            ? Column(
                children: [
                  const SizedBox(height: 8),
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 32,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Add photos or a video',
                    textAlign: TextAlign.center,
                    style: text.titleSmall,
                  ),
                  const SizedBox(height: 16),
                  buttons,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 96,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final (i, p) in _picked.indexed)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(controlRadius),
                                  ),
                                  child: SizedBox.square(
                                    dimension: 96,
                                    child: p.bytes != null
                                        ? Image.memory(
                                            p.bytes!,
                                            fit: BoxFit.cover,
                                          )
                                        : const ColoredBox(
                                            color: Colors.black87,
                                            child: Icon(
                                              Icons.videocam,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  child: IconButton.filledTonal(
                                    iconSize: 16,
                                    tooltip: 'Remove',
                                    onPressed: () =>
                                        setState(() => _picked.removeAt(i)),
                                    icon: const Icon(Icons.close),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  buttons,
                ],
              ),
      ),
    );
  }

  Widget _accessPanel(BuildContext context, bool approved) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Who can see this?', style: text.titleSmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final MapEntry(:key, :value) in accessLabels.entries)
                ChoiceChip(
                  label: Text(value),
                  selected: _access == key,
                  onSelected: approved || key == 'free' || key == 'followers'
                      ? (_) => setState(() => _access = key)
                      : null,
                ),
            ],
          ),
          if (!approved)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Paid and subscriber posts unlock once your creator setup '
                'is approved.',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          AnimatedSize(
            duration: motion(context, shortDuration),
            curve: easeOut,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: motion(context, shortDuration),
              switchInCurve: easeOut,
              switchOutCurve: easeOut,
              child: _access == 'paid'
                  ? Padding(
                      key: const ValueKey('price'),
                      padding: const EdgeInsets.only(top: 16),
                      child: TextField(
                        key: const ValueKey('composer-price'),
                        controller: _price,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: 'Price',
                          prefixText: 'KSh ',
                          errorText: _price.text.isEmpty ? null : _priceError,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _IconTile(Icons.receipt_long_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 7),
                    Text(switch (_access) {
                      'paid' when _priceKes != null =>
                        'Fans pay ${formatKes(_priceKes! * 100)} to unlock',
                      'paid' => 'Set a price',
                      'subscribers' => 'Included in your subscription',
                      'followers' => 'Free for your followers',
                      _ => 'Free for everyone signed in',
                    }, style: text.bodyLarge),
                    if (_access == 'paid')
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'A 20% platform commission applies under your '
                          'creator agreement.',
                          style: text.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final approved = ref.watch(creatorApprovedProvider);
    final busy = _progress != null;
    final gutter = _gutter(context);
    return Scaffold(
      appBar: AppBar(title: const Text('New post')),
      body: AbsorbPointer(
        absorbing: busy,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            gutter,
            8,
            gutter,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            _media(context),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('composer-caption'),
              controller: _caption,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Caption'),
            ),
            const SizedBox(height: 4),
            _accessPanel(context, approved),
            const SizedBox(height: 12),
            _Panel(
              padding: EdgeInsets.zero,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: const _IconTile(Icons.schedule),
                onTap: _pickSchedule,
                title: Text(
                  _publishAt == null
                      ? 'Publish now'
                      : 'Publish on ${MaterialLocalizations.of(context).formatMediumDate(_publishAt!)} '
                            'at ${TimeOfDay.fromDateTime(_publishAt!).format(context)}',
                ),
                trailing: _publishAt == null
                    ? TextButton(
                        onPressed: _pickSchedule,
                        child: const Text('Schedule'),
                      )
                    : IconButton(
                        tooltip: 'Publish now instead',
                        onPressed: () => setState(() => _publishAt = null),
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            _Panel(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: CheckboxListTile(
                key: const ValueKey('composer-consent'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                controlAffinity: ListTileControlAffinity.leading,
                value: _consent,
                onChanged: (v) => setState(() => _consent = v!),
                title: const Text(
                  'Everyone shown is 18+ and has consented to this being '
                  'shared. I own or have the rights to this content.',
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (busy) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(_progress!, textAlign: TextAlign.center),
            ] else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _submit(publish: false),
                      child: const Text('Save draft'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('composer-publish'),
                      style: brandButtonStyle(context),
                      onPressed: () => _submit(publish: true),
                      child: Text(_publishAt == null ? 'Publish' : 'Schedule'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Dashed rounded outline for the media drop zone.
class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.6),
          const Radius.circular(cardRadius),
        ),
      );
    const dash = 6.0, gap = 5.0;
    for (final metric in outline.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}
