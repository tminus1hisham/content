import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: asyncBody(
        ref.watch(conversationsProvider),
        () => ref.invalidate(conversationsProvider),
        (conversations) => conversations.isEmpty
            ? const Center(child: Text('No messages yet'))
            : RefreshIndicator(
                onRefresh: () => ref.refresh(conversationsProvider.future),
                child: ListView(
                  children: [
                    for (final c in conversations) _ConversationTile(c),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile(this.conversation);
  final _Json conversation;

  @override
  Widget build(BuildContext context) {
    final other = conversation['other'] as _Json;
    final last = conversation['lastMessage'] as _Json?;
    final preview = last == null
        ? ''
        : last['attachment'] != null && (last['text'] as String).isEmpty
        ? '📎 Attachment'
        : last['text'] as String;
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        child: Text((other['displayName'] as String)[0]),
      ),
      title: Text(
        other['displayName'] as String,
        style: theme.textTheme.titleMedium,
      ),
      subtitle: Text(
        conversation['blocked'] == true ? 'Blocked' : preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: () => context.push('/chat/${conversation['id']}'),
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
    const pill = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(sheetRadius)),
      borderSide: BorderSide.none,
    );
    final thread = ref.watch(threadProvider(widget.id));
    final me = ref.watch(authProvider).user?.id;
    final canSell = ref.watch(creatorApprovedProvider);
    final data = thread.valueOrNull;
    final other = data?['other'] as _Json?;
    return Scaffold(
      appBar: AppBar(
        title: Text(other?['displayName'] as String? ?? ''),
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
      body: Column(
        children: [
          Expanded(
            child: asyncBody(thread, _refresh, (data) {
              final messages = (data['messages'] as List).cast<_Json>();
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, i) {
                  final m = messages[messages.length - 1 - i];
                  return _Bubble(
                    message: m,
                    mine: m['senderId'] == me,
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
                },
              );
            }),
          ),
          if (data?['blocked'] == true)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('You can no longer message each other.'),
            )
          else
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (canSell)
                      IconButton(
                        tooltip: 'Send a paid photo',
                        onPressed: _sending ? null : _attachPaid,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                      ),
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
                          fillColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
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
                    IconButton.filled(
                      key: const ValueKey('chat-send'),
                      tooltip: 'Send',
                      onPressed: _sending ? null : () => _send(),
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.onUnlock,
    required this.onReport,
  });
  final _Json message;
  final bool mine;
  final VoidCallback onUnlock;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final attachment = message['attachment'] as _Json?;
    final text = message['text'] as String;
    final textTheme = Theme.of(context).textTheme;
    final fg = mine ? scheme.onPrimary : scheme.onSurface;
    final created = DateTime.tryParse('${message['createdAt']}')?.toLocal();
    const big = Radius.circular(20), tail = Radius.circular(6);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: mine ? null : onReport,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.75,
          ),
          decoration: BoxDecoration(
            color: mine ? scheme.primary : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.only(
              topLeft: big,
              topRight: big,
              bottomLeft: mine ? big : tail,
              bottomRight: mine ? tail : big,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (attachment != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 220,
                    height: 260,
                    child: attachment['locked'] == true
                        ? _LockedAttachment(
                            priceCents: attachment['priceCents'] as int,
                            onUnlock: onUnlock,
                          )
                        : MediaView(mediaId: attachment['mediaId'] as String),
                  ),
                ),
                if (mine && attachment['priceCents'] != null)
                  Text(
                    'Sold for ${formatKes(attachment['priceCents'] as int)}',
                    style: textTheme.bodySmall?.copyWith(color: fg),
                  ),
                if (text.isNotEmpty) const SizedBox(height: 6),
              ],
              if (text.isNotEmpty)
                Text(text, style: textTheme.bodyMedium?.copyWith(color: fg)),
              if (created != null) ...[
                const SizedBox(height: 4),
                Text(
                  MaterialLocalizations.of(
                    context,
                  ).formatTimeOfDay(TimeOfDay.fromDateTime(created)),
                  style: textTheme.labelSmall?.copyWith(
                    color: mine ? scheme.onPrimary : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LockedAttachment extends StatelessWidget {
  const _LockedAttachment({required this.priceCents, required this.onUnlock});
  final int priceCents;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.tertiaryContainer,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, color: scheme.onTertiaryContainer),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: onUnlock,
              child: Text('Unlock for ${formatKes(priceCents)}'),
            ),
          ],
        ),
      ),
    );
  }
}
