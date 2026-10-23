import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../app/ui.dart';
import '../../core/api_client.dart';
import '../../core/money.dart';
import '../auth/auth_controller.dart';
import '../content/content_api.dart';
import '../content/discover_screens.dart';
import '../content/media_view.dart';
import '../onboarding/onboarding_controller.dart';

typedef _Json = Map<String, dynamic>;

void _snack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

final conversationsProvider = FutureProvider.autoDispose<List<_Json>>(
  (ref) async =>
      ((await ref.read(dioProvider).get<List<dynamic>>('/conversations')).data!)
          .cast<_Json>(),
);

final threadProvider = FutureProvider.autoDispose.family<_Json, String>(
  (ref, id) async =>
      (await ref.read(dioProvider).get<_Json>('/conversations/$id/messages'))
          .data!,
);

/// Opens (or creates) the chat with [userId].
Future<void> openChat(
  BuildContext context,
  WidgetRef ref,
  String userId,
) async {
  try {
    final conversation =
        (await ref
                .read(dioProvider)
                .post<_Json>('/conversations', data: {'userId': userId}))
            .data!;
    if (context.mounted) context.push('/chat/${conversation['id']}');
  } catch (e) {
    if (context.mounted) _snack(context, apiErrorMessage(e));
  }
}

const reportReasons = {
  'minor': 'Someone under 18',
  'non_consensual': 'Shared without consent',
  'harassment': 'Harassment or threats',
  'impersonation': 'Impersonation',
  'scam': 'Spam or scam',
  'other': 'Something else',
};

/// IT.md US-F03: reason, details, then a case reference.
Future<void> showReportDialog(
  BuildContext context,
  WidgetRef ref, {
  required String targetType,
  required String targetId,
}) async {
  String? reason;
  final details = TextEditingController();
  final send = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Report'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioGroup<String>(
                groupValue: reason,
                onChanged: (v) => setState(() => reason = v),
                child: Column(
                  children: [
                    for (final MapEntry(:key, :value) in reportReasons.entries)
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: key,
                        title: Text(value),
                      ),
                  ],
                ),
              ),
              TextField(
                controller: details,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Details (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: reason == null
                ? null
                : () => Navigator.pop(context, true),
            child: const Text('Send report'),
          ),
        ],
      ),
    ),
  );
  if (send != true) return;
  try {
    final result =
        (await ref
                .read(dioProvider)
                .post<_Json>(
                  '/reports',
                  data: {
                    'targetType': targetType,
                    'targetId': targetId,
                    'reason': reason,
                    'details': details.text.trim(),
                  },
                ))
            .data!;
    if (context.mounted) {
      _snack(
        context,
        'Report sent. Your case reference is ${result['caseId']}.',
      );
    }
  } catch (e) {
    if (context.mounted) _snack(context, apiErrorMessage(e));
  }
}

/// Fan Inbox tab and creator Messages tab.
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authProvider).user?.id;
    return Scaffold(
      appBar: tabAppBar(context, 'Messages'),
      body: asyncBody(
        ref.watch(conversationsProvider),
        () => ref.invalidate(conversationsProvider),
        (conversations) => conversations.isEmpty
            ? const StateView(
                icon: Icons.chat_bubble_outline,
                title: 'No messages yet',
                message: 'Your conversations will appear here.',
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(conversationsProvider.future),
                child: Builder(
                  builder: (context) {
                    final gutter = math.max(
                      16.0,
                      (MediaQuery.sizeOf(context).width - 640) / 2,
                    );
                    return ListView.separated(
                      // Clears the floating tab bar.
                      padding: EdgeInsets.fromLTRB(
                        gutter,
                        8,
                        gutter,
                        24 + MediaQuery.paddingOf(context).bottom,
                      ),
                      itemCount: conversations.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => Entrance(
                        key: ValueKey(conversations[i]['id']),
                        index: i,
                        child: _ConversationTile(conversations[i], me: me),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

/// "14:05" today, "Tue" this week, "21 Oct" before that.
String _shortTime(BuildContext context, DateTime t) {
  final days = DateUtils.dateOnly(
    DateTime.now(),
  ).difference(DateUtils.dateOnly(t)).inDays;
  if (days == 0) {
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(t));
  }
  return days < 7 ? DateFormat.E().format(t) : DateFormat.MMMd().format(t);
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile(this.conversation, {required this.me});
  final _Json conversation;
  final String? me;

  @override
  Widget build(BuildContext context) {
    final other = conversation['other'] as _Json;
    final last = conversation['lastMessage'] as _Json?;
    final blocked = conversation['blocked'] == true;
    final preview = last == null
        ? ''
        : last['attachment'] != null && (last['text'] as String).isEmpty
        ? '📎 Attachment'
        : last['text'] as String;
    final sent = last == null
        ? null
        : DateTime.tryParse('${last['createdAt']}')?.toLocal();
    // The API has no read receipts yet: the dot marks "they wrote last".
    final awaiting = !blocked && last != null && last['senderId'] != me;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final name = other['displayName'] as String;
    return Pressable(
      child: Material(
        color: scheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(cardRadius)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          onTap: () => context.push('/chat/${conversation['id']}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
            child: Row(
              children: [
                CreatorAvatar(id: other['id'] as String, name: name, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleMedium?.copyWith(
                                fontWeight: awaiting
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          if (sent != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              _shortTime(context, sent),
                              style: text.labelSmall?.copyWith(
                                color: awaiting
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              blocked ? 'Blocked' : preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (awaiting) ...[
                            const SizedBox(width: 10),
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: scheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// IT.md F10.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _text = TextEditingController();
  Timer? _poll;
  bool _sending = false;

  /// Message ids present when the thread first loaded.
  Set<Object?>? _initial;

  @override
  void initState() {
    super.initState();
    // ponytail: polling; move to the API's realtime transport when it exists.
    _poll = Timer.periodic(
      const Duration(seconds: 5),
      (_) => ref.invalidate(threadProvider(widget.id)),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(threadProvider(widget.id));
    ref.invalidate(conversationsProvider);
  }

  Future<void> _send({Map<String, Object?>? attachment}) async {
    final text = _text.text.trim();
    if (text.isEmpty && attachment == null) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(dioProvider)
          .post<void>(
            '/conversations/${widget.id}/messages',
            data: {'text': text, 'attachment': ?attachment},
          );
      _text.clear();
      _refresh();
    } catch (e) {
      if (mounted) _snack(context, apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _attachPaid() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    final price = TextEditingController();
    final kes = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Price for this photo'),
        content: TextField(
          key: const ValueKey('attachment-price'),
          controller: price,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(prefixText: 'KSh '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, int.tryParse(price.text)),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (kes == null) return;
    setState(() => _sending = true);
    try {
      final mediaId = await uploadMedia(
        ref.read(dioProvider),
        ref.read(uploadDioProvider),
        file,
        'image',
      );
      await _send(attachment: {'mediaId': mediaId, 'priceCents': kes * 100});
    } catch (e) {
      if (mounted) _snack(context, apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _setBlocked(String userId, bool block) async {
    final dio = ref.read(dioProvider);
    try {
      block
          ? await dio.post<void>('/users/$userId/block')
          : await dio.delete<void>('/users/$userId/block');
      _refresh();
    } catch (e) {
      if (mounted) _snack(context, apiErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pill = OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(sheetRadius)),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );
    final thread = ref.watch(threadProvider(widget.id));
    final me = ref.watch(authProvider).user?.id;
    final canSell = ref.watch(creatorApprovedProvider);
    final data = thread.valueOrNull;
    final other = data?['other'] as _Json?;
    return Scaffold(
      // The composer floats over the thread and lifts itself above the
      // keyboard; the thread is padded by the composer's height below.
      extendBody: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        titleSpacing: 0,
        title: other == null
            ? const Text('')
            : Row(
                children: [
                  CreatorAvatar(
                    id: other['id'] as String,
                    name: other['displayName'] as String,
                    size: 34,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      other['displayName'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
        actions: [
          if (other != null)
            PopupMenuButton<String>(
              onSelected: (action) => switch (action) {
                'block' => _setBlocked(other['id'] as String, true),
                'unblock' => _setBlocked(other['id'] as String, false),
                'report' => showReportDialog(
                  context,
                  ref,
                  targetType: 'user',
                  targetId: other['id'] as String,
                ),
                _ => null,
              },
              itemBuilder: (_) => [
                if (data?['blockedByMe'] == true)
                  const PopupMenuItem(value: 'unblock', child: Text('Unblock'))
                else
                  const PopupMenuItem(value: 'block', child: Text('Block')),
                const PopupMenuItem(value: 'report', child: Text('Report')),
              ],
            ),
        ],
      ),
      body: Builder(
        builder: (context) => asyncBody(thread, _refresh, (data) {
          final messages = (data['messages'] as List).cast<_Json>();
          // What was there on open shows at once; only messages that arrive
          // afterwards fade in.
          final initial = _initial ??= {for (final m in messages) m['id']};
          final width = MediaQuery.sizeOf(context).width;
          final gutter = math.max(12.0, (width - 720) / 2);
          final bubbleWidth = math.min((width - 2 * gutter) * 0.78, 520.0);
          String sender(int k) => '${messages[k]['senderId']}';
          return ListView.builder(
            reverse: true,
            padding: EdgeInsets.fromLTRB(
              gutter,
              12,
              gutter,
              12 + MediaQuery.paddingOf(context).bottom,
            ),
            itemCount: messages.length,
            // Keeps each bubble's state (and finished entrance) as new
            // messages push it up.
            findChildIndexCallback: (key) {
              final k = messages.indexWhere(
                (m) => m['id'] == (key as ValueKey<Object?>).value,
              );
              return k < 0 ? null : messages.length - 1 - k;
            },
            itemBuilder: (context, i) {
              final k = messages.length - 1 - i;
              final m = messages[k];
              final bubble = _Bubble(
                message: m,
                mine: m['senderId'] == me,
                joinsPrevious: k > 0 && sender(k - 1) == sender(k),
                joinsNext:
                    k < messages.length - 1 && sender(k + 1) == sender(k),
                maxWidth: bubbleWidth,
                onUnlock: () async {
                  await context.push('/checkout/message/${m['id']}');
                  _refresh();
                },
                onReport: () => showReportDialog(
                  context,
                  ref,
                  targetType: 'message',
                  targetId: m['id'] as String,
                ),
              );
              return KeyedSubtree(
                key: ValueKey<Object?>(m['id']),
                child: initial.contains(m['id'])
                    ? bubble
                    : Entrance(child: bubble),
              );
            },
          );
        }),
      ),
      bottomNavigationBar: Glass(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
        child: Builder(
          builder: (context) => Padding(
            padding: EdgeInsets.fromLTRB(
              8,
              8,
              8,
              8 +
                  math.max(
                    MediaQuery.viewInsetsOf(context).bottom,
                    MediaQuery.paddingOf(context).bottom,
                  ),
            ),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: data?['blocked'] == true
                    ? Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.block,
                              size: 18,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'You can no longer message each other.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (canSell)
                            IconButton(
                              tooltip: 'Send a paid photo',
                              onPressed: _sending ? null : _attachPaid,
                              icon: const Icon(
                                Icons.add_photo_alternate_outlined,
                              ),
                            )
                          else
                            const SizedBox(width: 4),
                          Expanded(
                            child: TextField(
                              key: const ValueKey('chat-input'),
                              controller: _text,
                              minLines: 1,
                              maxLines: 4,
                              maxLength: 2000,
                              decoration: InputDecoration(
                                hintText: 'Message',
                                counterText: '',
                                filled: true,
                                fillColor: scheme.surfaceContainerHigh,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                border: pill,
                                enabledBorder: pill,
                                focusedBorder: pill,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton.filled(
                            key: const ValueKey('chat-send'),
                            tooltip: 'Send',
                            onPressed: _sending ? null : () => _send(),
                            icon: const Icon(Icons.arrow_upward_rounded),
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

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.joinsPrevious,
    required this.joinsNext,
    required this.maxWidth,
    required this.onUnlock,
    required this.onReport,
  });
  final _Json message;
  final bool mine;

  /// Same sender directly before / after: the bubbles group into a run.
  final bool joinsPrevious;
  final bool joinsNext;
  final double maxWidth;
  final VoidCallback onUnlock;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final attachment = message['attachment'] as _Json?;
    final text = message['text'] as String;
    final created = DateTime.tryParse('${message['createdAt']}')?.toLocal();
    // Text stays onSurface on both tones; meta is softened but kept >= 4.5:1.
    final fg = scheme.onSurface;
    final meta = scheme.onSurface.withValues(alpha: 0.75);
    // Mine: the sunset as a low glow over the raised surface, not a fill.
    final base = scheme.surfaceContainerHigh;
    final glow = theme.brightness == Brightness.dark ? 0.26 : 0.18;
    const round = Radius.circular(20), joined = Radius.circular(6);
    final sideTop = joinsPrevious ? joined : round;
    final sideBottom = joinsNext ? joined : round;
    final radius = BorderRadiusDirectional.only(
      topStart: mine ? round : sideTop,
      bottomStart: mine ? round : sideBottom,
      topEnd: mine ? sideTop : round,
      bottomEnd: mine ? sideBottom : round,
    );
    final align = mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final details = [
      if (mine && attachment?['priceCents'] != null)
        Text(
          'Sold for ${formatKes(attachment!['priceCents'] as int)}',
          style: textTheme.labelMedium?.copyWith(
            color: meta,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      if (text.isNotEmpty)
        Text(text, style: textTheme.bodyMedium?.copyWith(color: fg)),
      if (created != null) ...[
        const SizedBox(height: 3),
        Text(
          MaterialLocalizations.of(
            context,
          ).formatTimeOfDay(TimeOfDay.fromDateTime(created)),
          style: textTheme.labelSmall?.copyWith(
            color: meta,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ];
    return Padding(
      padding: EdgeInsets.only(top: joinsPrevious ? 2 : 12),
      child: Align(
        alignment: mine
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: GestureDetector(
          onLongPress: mine ? null : onReport,
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            decoration: BoxDecoration(
              color: mine ? null : base,
              gradient: mine
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      // Orange over plum reads as brown, so the warm end
                      // is the accent itself.
                      colors: [
                        for (final c in [
                          scheme.primary,
                          Brand.of(context).glowB,
                        ])
                          Color.alphaBlend(c.withValues(alpha: glow), base),
                      ],
                    )
                  : null,
              borderRadius: radius,
            ),
            child: Column(
              crossAxisAlignment: align,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (attachment != null)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(16)),
                      child: SizedBox(
                        width: 220,
                        height: 260,
                        child: attachment['locked'] == true
                            ? _LockedAttachment(
                                messageId: message['id'] as String,
                                priceCents: attachment['priceCents'] as int,
                                onUnlock: onUnlock,
                              )
                            : MediaView(
                                mediaId: attachment['mediaId'] as String,
                              ),
                      ),
                    ),
                  ),
                if (details.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      14,
                      attachment != null ? 4 : 10,
                      14,
                      10,
                    ),
                    child: Column(
                      crossAxisAlignment: align,
                      mainAxisSize: MainAxisSize.min,
                      children: details,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A paid attachment the viewer hasn't bought: a generic teaser cover (never
/// the real image) under a frosted price pill, like the feed's locked posts.
class _LockedAttachment extends StatelessWidget {
  const _LockedAttachment({
    required this.messageId,
    required this.priceCents,
    required this.onUnlock,
  });
  final String messageId;
  final int priceCents;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    // Same message, same cover, so the thread doesn't reshuffle on rebuild.
    final cover =
        messageId.codeUnits.fold(0, (a, b) => a + b) % lockedCoverCount + 1;
    return Semantics(
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onUnlock,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/covers/$cover.jpg', fit: BoxFit.cover),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Glass(
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                    color: Colors.black.withValues(alpha: 0.35),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_outline,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Unlock for ${formatKes(priceCents)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: Colors.white),
                            ),
                          ),
                        ],
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
  }
}
