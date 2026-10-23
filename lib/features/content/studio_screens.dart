import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/schedule_picker.dart';
import '../../core/api_client.dart';
import '../../core/money.dart';
import '../onboarding/onboarding_controller.dart';
import 'content_api.dart';
import 'discover_screens.dart';
import 'media_view.dart';

void _snack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

/// IT.md C7, shown on the creator Home tab once approved.
class CreatorDashboard extends ConsumerWidget {
  const CreatorDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(analyticsProvider);
    Widget stat(String label, Object? value) => Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                '${value ?? '–'}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(label),
            ],
          ),
        ),
      ),
    );
    final data = stats.valueOrNull;
    return RefreshIndicator(
      onRefresh: () => ref.refresh(analyticsProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              stat('Followers', data?['followers']),
              stat('Subscribers', data?['subscribers']),
            ],
          ),
          Row(
            children: [
              stat('Posts', data?['posts']),
              stat('Views', data?['views']),
            ],
          ),
          const SizedBox(height: 16),
          Text('Quick actions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('New post'),
                onPressed: () => context.push('/studio/new'),
              ),
              ActionChip(
                avatar: const Icon(Icons.videocam_outlined),
                label: const Text('Go live'),
                onPressed: () => context.go('/go-live'),
              ),
              ActionChip(
                avatar: const Icon(Icons.chat_bubble_outline),
                label: const Text('Messages'),
                onPressed: () => context.go('/messages'),
              ),
            ],
          ),
        ],
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

/// IT.md C9.
class StudioScreen extends StatelessWidget {
  const StudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _studioTabs.length,
      initialIndex: 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Studio'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [for (final (label, _) in _studioTabs) Tab(text: label)],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/studio/new'),
          icon: const Icon(Icons.add),
          label: const Text('New post'),
        ),
        body: TabBarView(
          children: [
            for (final (_, status) in _studioTabs) _PostList(status: status),
          ],
        ),
      ),
    );
  }
}

class _PostList extends ConsumerWidget {
  const _PostList({required this.status});
  final String status;

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
    return asyncBody(
      ref.watch(myPostsProvider(status)),
      () => ref.invalidate(myPostsProvider(status)),
      (posts) => posts.isEmpty
          ? const Center(child: Text('Nothing here yet'))
          : ListView.builder(
              itemCount: posts.length,
              itemBuilder: (context, i) {
                final post = posts[i];
                final price = post.access == 'paid'
                    ? ' · ${formatKes(post.priceCents ?? 0)}'
                    : '';
                return ListTile(
                  leading: SizedBox.square(
                    dimension: 56,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: post.media.isEmpty
                          ? const Icon(Icons.image_outlined)
                          : MediaView(mediaId: post.media.first.id),
                    ),
                  ),
                  title: Text(
                    post.caption.isEmpty ? '(No caption)' : post.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${accessLabels[post.access]}$price'
                    '${post.views != null ? ' · ${post.views} views' : ''}'
                    '${post.publishAt != null && status == 'scheduled' ? ' · ${MaterialLocalizations.of(context).formatShortDate(post.publishAt!)}' : ''}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (a) => _act(context, ref, post, a),
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
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
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

  @override
  Widget build(BuildContext context) {
    final approved = ref.watch(creatorApprovedProvider);
    final text = Theme.of(context).textTheme;
    final busy = _progress != null;
    return Scaffold(
      appBar: AppBar(title: const Text('New post')),
      body: AbsorbPointer(
        absorbing: busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
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
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox.square(
                              dimension: 96,
                              child: p.bytes != null
                                  ? Image.memory(p.bytes!, fit: BoxFit.cover)
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
                  OutlinedButton.icon(
                    key: const ValueKey('composer-photos'),
                    onPressed: _addPhotos,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Photos'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _addVideo,
                    icon: const Icon(Icons.video_call_outlined),
                    label: const Text('Video'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('composer-caption'),
              controller: _caption,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Caption'),
            ),
            Text('Who can see this?', style: text.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                for (final MapEntry(:key, :value) in accessLabels.entries)
                  ButtonSegment(
                    value: key,
                    label: Text(value),
                    enabled: approved || key == 'free' || key == 'followers',
                  ),
              ],
              selected: {_access},
              onSelectionChanged: (s) => setState(() => _access = s.first),
            ),
            if (!approved)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Paid and subscriber posts unlock once your creator setup '
                  'is approved.',
                  style: text.bodySmall,
                ),
              ),
            if (_access == 'paid') ...[
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('composer-price'),
                controller: _price,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Price',
                  prefixText: 'KSh ',
                  errorText: _price.text.isEmpty ? null : _priceError,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
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
            Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(switch (_access) {
                  'paid' when _priceKes != null =>
                    'Fans pay ${formatKes(_priceKes! * 100)} to unlock',
                  'paid' => 'Set a price',
                  'subscribers' => 'Included in your subscription',
                  'followers' => 'Free for your followers',
                  _ => 'Free for everyone signed in',
                }),
                subtitle: _access == 'paid'
                    ? const Text(
                        'A 20% platform commission applies under your '
                        'creator agreement.',
                      )
                    : null,
              ),
            ),
            CheckboxListTile(
              key: const ValueKey('composer-consent'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _consent,
              onChanged: (v) => setState(() => _consent = v!),
              title: const Text(
                'Everyone shown is 18+ and has consented to this being '
                'shared. I own or have the rights to this content.',
              ),
            ),
            const SizedBox(height: 8),
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
