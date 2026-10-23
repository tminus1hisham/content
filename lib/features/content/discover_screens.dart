import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/money.dart';
import '../commerce/commerce_api.dart';
import '../messages/messages_screens.dart';
import 'content_api.dart';
import 'media_view.dart';

Widget asyncBody<T>(
  AsyncValue<T> value,
  VoidCallback retry,
  Widget Function(T) builder,
) => value.when(
  data: builder,
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (e, _) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(apiErrorMessage(e)),
        TextButton(onPressed: retry, child: const Text('Try again')),
      ],
    ),
  ),
);

/// IT.md F3.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  String _query = '';
  String? _category;

  @override
  Widget build(BuildContext context) {
    final filter = (query: _query, category: _category);
    final results = ref.watch(discoveryProvider(filter));
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              key: const ValueKey('discover-search'),
              hintText: 'Search creators',
              leading: const Icon(Icons.search),
              onChanged: (q) => setState(() => _query = q.trim()),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final category in categories)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(category),
                      selected: _category == category,
                      onSelected: (on) =>
                          setState(() => _category = on ? category : null),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: asyncBody(
              results,
              () => ref.invalidate(discoveryProvider(filter)),
              (creators) => creators.isEmpty
                  ? const Center(child: Text('No creators found'))
                  : CreatorList(creators: creators),
            ),
          ),
        ],
      ),
    );
  }
}

class CreatorList extends StatelessWidget {
  const CreatorList({super.key, required this.creators});
  final List<Creator> creators;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: creators.length,
      itemBuilder: (context, i) {
        final c = creators[i];
        return ListTile(
          leading: CircleAvatar(child: Text(c.displayName[0])),
          title: Text(c.displayName),
          subtitle: Text(
            '@${c.handle} · ${c.categories.join(', ')}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: c.isFollowing ? const Icon(Icons.favorite, size: 18) : null,
          onTap: () => context.push('/c/${c.handle}'),
        );
      },
    );
  }
}

class FollowingScreen extends ConsumerWidget {
  const FollowingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Following')),
      body: asyncBody(
        ref.watch(followingProvider),
        () => ref.invalidate(followingProvider),
        (creators) => creators.isEmpty
            ? const Center(child: Text('Follow creators to see them here'))
            : RefreshIndicator(
                onRefresh: () => ref.refresh(followingProvider.future),
                child: CreatorList(creators: creators),
              ),
      ),
    );
  }
}

/// IT.md F4.
class CreatorPage extends ConsumerWidget {
  const CreatorPage({super.key, required this.handle});
  final String handle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creator = ref.watch(creatorProvider(handle));
    return Scaffold(
      appBar: AppBar(
        title: Text('@$handle'),
        actions: [
          PopupMenuButton<String>(
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
      body: asyncBody(
        creator,
        () => ref.invalidate(creatorProvider(handle)),
        (c) => _CreatorBody(creator: c),
      ),
    );
  }
}

class _CreatorBody extends ConsumerStatefulWidget {
  const _CreatorBody({required this.creator});
  final Creator creator;

  @override
  ConsumerState<_CreatorBody> createState() => _CreatorBodyState();
}

class _CreatorBodyState extends ConsumerState<_CreatorBody> {
  late Creator _creator = widget.creator;
  bool _busy = false;

  Future<void> _toggleFollow() async {
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

  @override
  Widget build(BuildContext context) {
    final c = _creator;
    final text = Theme.of(context).textTheme;
    final posts = ref.watch(creatorPostsProvider(c.id));
    final tier = ref.watch(tiersProvider(c.id)).valueOrNull?.firstOrNull;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      child: Text(c.displayName[0], style: text.headlineSmall),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  c.displayName,
                                  style: text.titleLarge,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified,
                                size: 18,
                                semanticLabel: 'Verified creator',
                              ),
                            ],
                          ),
                          Text('${c.followers} followers'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (c.bio.isNotEmpty) Text(c.bio),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final category in c.categories)
                      Chip(label: Text(category)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: c.isFollowing
                          ? OutlinedButton(
                              key: const ValueKey('follow'),
                              onPressed: _busy ? null : _toggleFollow,
                              child: const Text('Following'),
                            )
                          : FilledButton.tonal(
                              key: const ValueKey('follow'),
                              onPressed: _busy ? null : _toggleFollow,
                              child: const Text('Follow'),
                            ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      key: const ValueKey('message-creator'),
                      tooltip: 'Message',
                      onPressed: () => openChat(context, ref, c.id),
                      icon: const Icon(Icons.chat_bubble_outline),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('subscribe'),
                        onPressed: c.isSubscribed
                            ? null
                            : () => context.push(
                                '/checkout/subscription/${c.id}',
                              ),
                        child: Text(
                          c.isSubscribed
                              ? 'Subscribed'
                              : tier == null
                              ? 'Subscribe'
                              : 'Subscribe · '
                                    '${formatKes(tier['priceCents'] as int)}/mo',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        ...posts.when(
          loading: () => [
            const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (e, _) => [
            SliverToBoxAdapter(child: Center(child: Text(apiErrorMessage(e)))),
          ],
          data: (items) => [
            if (items.isEmpty)
              const SliverToBoxAdapter(
                child: Center(child: Text('No posts yet')),
              ),
            SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                childAspectRatio: 0.8,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) => PostTile(post: items[i]),
            ),
          ],
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
    return InkWell(
      onTap: () => context.push('/p/${post.id}'),
      child: Semantics(
        label: post.locked ? 'Locked post: ${post.caption}' : post.caption,
        child: post.locked || post.media.isEmpty
            ? LockedMedia(post: post)
            : MediaView(mediaId: post.media.first.id),
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
    return Scaffold(
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
            ListTile(
              leading: CircleAvatar(child: Text(post.creatorName[0])),
              title: Text(post.creatorName),
              subtitle: Text('@${post.creatorHandle}'),
              onTap: () => context.push('/c/${post.creatorHandle}'),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: post.locked
                      ? LockedMedia(post: post)
                      : PageView(
                          children: [
                            for (final m in post.media)
                              MediaView(mediaId: m.id, fit: BoxFit.contain),
                          ],
                        ),
                ),
              ),
            ),
            if (post.caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(post.caption),
              ),
          ],
        ),
      ),
      // The price and exact access stay on screen while scrolling (IT.md F5).
      bottomNavigationBar: locked == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(switch (locked.access) {
                      'paid' =>
                        'One-time purchase: permanent access to this post '
                            '(${locked.media.length} item'
                            '${locked.media.length == 1 ? '' : 's'}). '
                            'Price in KES, all fees included.',
                      'subscribers' =>
                        'Available to subscribers of @${locked.creatorHandle}.',
                      _ => 'Follow @${locked.creatorHandle} to see this post.',
                    }, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 8),
                    FilledButton(
                      key: const ValueKey('unlock'),
                      onPressed: () => locked.access == 'followers'
                          ? context.push('/c/${locked.creatorHandle}')
                          : locked.access == 'paid'
                          ? context.push('/checkout/post/${locked.id}')
                          : context.push(
                              '/checkout/subscription/${locked.creatorId}',
                            ),
                      child: Text(switch (locked.access) {
                        'paid' => 'Unlock for ${formatKes(locked.priceCents!)}',
                        'subscribers' => 'Subscribe to unlock',
                        _ => 'Go to profile to follow',
                      }),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
