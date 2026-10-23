import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/money.dart';
import '../content/discover_screens.dart';
import '../messages/messages_screens.dart';
import '../onboarding/onboarding_controller.dart';
import 'live_connection.dart';

typedef _Json = Map<String, dynamic>;

void _snack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

final liveNowProvider = FutureProvider.autoDispose<List<_Json>>(
  (ref) async =>
      ((await ref.read(dioProvider).get<List<dynamic>>('/live/now')).data!)
          .cast<_Json>(),
);

String _accessLabel(_Json s) => switch (s['access']) {
  'ticketed' => 'Ticket ${formatKes(s['priceCents'] as int)}',
  'subscribers' => 'Subscribers',
  _ => 'Free',
};

/// Fan "Live" tab.
class LiveNowScreen extends ConsumerWidget {
  const LiveNowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live now')),
      body: asyncBody(
        ref.watch(liveNowProvider),
        () => ref.invalidate(liveNowProvider),
        (sessions) => RefreshIndicator(
          onRefresh: () => ref.refresh(liveNowProvider.future),
          child: sessions.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Center(child: Text('Nobody is live right now')),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final s in sessions)
                      Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              ((s['creator'] as _Json)['displayName']
                                  as String)[0],
                            ),
                          ),
                          title: Text(s['title'] as String),
                          subtitle: Text(
                            '${(s['creator'] as _Json)['displayName']} · '
                            '${_accessLabel(s)}',
                          ),
                          trailing: const _LiveBadge(),
                          onTap: () => context.push('/live/${s['id']}'),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.red,
      borderRadius: BorderRadius.circular(4),
    ),
    child: const Text(
      'LIVE',
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
  );
}

/// Creator "Go live" tab: setup and safety checks (IT.md §6 creator flow).
class GoLiveScreen extends ConsumerStatefulWidget {
  const GoLiveScreen({super.key});

  @override
  ConsumerState<GoLiveScreen> createState() => _GoLiveScreenState();
}

class _GoLiveScreenState extends ConsumerState<GoLiveScreen> {
  final _title = TextEditingController();
  final _price = TextEditingController();
  String _access = 'free';
  bool _record = false;
  bool _safety = false;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_title.text.trim().isEmpty) {
      return _snack(context, 'Give your stream a title');
    }
    if (!_safety) return _snack(context, 'Confirm the safety rules');
    final kes = int.tryParse(_price.text);
    if (_access == 'ticketed' && (kes == null || kes < 10 || kes > 50000)) {
      return _snack(
        context,
        'Ticket price must be between KSh 10 and KSh 50,000',
      );
    }
    setState(() => _busy = true);
    try {
      final session =
          (await ref
                  .read(dioProvider)
                  .post<_Json>(
                    '/live/sessions',
                    data: {
                      'title': _title.text.trim(),
                      'access': _access,
                      if (_access == 'ticketed') 'priceCents': kes! * 100,
                      'record': _record,
                      'safetyConfirmed': true,
                    },
                  ))
              .data!;
      if (mounted) context.push('/live/${session['id']}');
    } catch (e) {
      if (mounted) _snack(context, apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final approved = ref.watch(creatorApprovedProvider);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Go live')),
      body: !approved
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Finish creator setup to go live.'),
                    TextButton(
                      onPressed: () => context.push('/onboarding'),
                      child: const Text('Continue setup'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.videocam_outlined),
                        title: Text('Camera and microphone'),
                        subtitle: Text(
                          'You will be asked for access when the stream starts',
                        ),
                      ),
                      ListTile(
                        leading: Icon(Icons.wifi),
                        title: Text('Connection'),
                        subtitle: Text(
                          'Use Wi-Fi or a strong 4G signal. Quality adapts '
                          'automatically.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('live-title'),
                  controller: _title,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Stream title'),
                ),
                Text('Who can watch?', style: text.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'free', label: Text('Free')),
                    ButtonSegment(
                      value: 'subscribers',
                      label: Text('Subscribers'),
                    ),
                    ButtonSegment(value: 'ticketed', label: Text('Ticket')),
                  ],
                  selected: {_access},
                  onSelectionChanged: (s) => setState(() => _access = s.first),
                ),
                if (_access == 'ticketed') ...[
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('live-price'),
                    controller: _price,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Ticket price',
                      prefixText: 'KSh ',
                    ),
                  ),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Record this stream'),
                  subtitle: const Text('Only you can see the recording'),
                  value: _record,
                  onChanged: (v) => setState(() => _record = v),
                ),
                CheckboxListTile(
                  key: const ValueKey('live-safety'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _safety,
                  onChanged: (v) => setState(() => _safety = v!),
                  title: const Text(
                    'Everyone on camera is 18+ and has agreed to appear. I will '
                    'follow the content rules.',
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: const ValueKey('live-start'),
                  onPressed: _busy ? null : _start,
                  icon: const Icon(Icons.sensors),
                  label: const Text('Go live'),
                ),
              ],
            ),
    );
  }
}

class _ChatLine {
  _ChatLine(this.identity, this.name, this.text, {this.tipCents});
  final String? identity;
  final String name;
  final String text;
  final int? tipCents;
}

/// The stream itself, for the host and for viewers.
class LiveRoomScreen extends ConsumerStatefulWidget {
  const LiveRoomScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends ConsumerState<LiveRoomScreen> {
  final _input = TextEditingController();
  final _lines = <_ChatLine>[];
  _Json? _session;
  LiveJoin? _join;
  LiveConnection? _connection;
  StreamSubscription<LiveEvent>? _sub;
  String? _gate; // why the viewer cannot join yet
  String? _gateCode;
  String? _pinned;
  int _viewers = 0;
  int _slowMode = 0;
  DateTime? _nextSendAt;
  bool _ended = false;
  bool _mic = true;
  bool _camera = true;

  bool get _host => _join?.canPublish == true;

  @override
  void initState() {
    super.initState();
    _enter();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _connection?.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _enter() async {
    final dio = ref.read(dioProvider);
    try {
      final session = (await dio.get<_Json>(
        '/live/sessions/${widget.id}',
      )).data!;
      setState(() {
        _session = session;
        _slowMode = session['slowModeSeconds'] as int? ?? 0;
      });
      final token = (await dio.post<_Json>(
        '/live/sessions/${widget.id}/token',
      )).data!;
      final join = LiveJoin(
        sessionId: widget.id,
        url: token['url'] as String,
        token: token['token'] as String,
        identity: token['identity'] as String,
        name: token['name'] as String,
        canPublish: token['canPublish'] as bool,
        creatorIdentity: (session['creator'] as _Json)['id'] as String,
      );
      final connection = ref.read(liveConnectionFactoryProvider)(join);
      _sub = connection.events.listen(_onEvent);
      setState(() {
        _join = join;
        _connection = connection;
        _gate = null;
      });
      await connection.connect();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _gateCode = apiErrorCode(e);
        _gate = apiErrorMessage(e);
      });
    }
  }

  void _onEvent(LiveEvent event) {
    if (!mounted) return;
    setState(() {
      switch (event) {
        case ChatEvent(:final identity, :final name, :final text):
          _lines.add(_ChatLine(identity, name, text));
        case TipEvent(:final name, :final amountCents):
          _lines.add(
            _ChatLine(null, name, 'sent a tip', tipCents: amountCents),
          );
        case PinEvent(:final text):
          _pinned = text;
        case ModerationEvent(
          :final slowModeSeconds,
          :final muted,
          :final removed,
        ):
          if (slowModeSeconds != null) _slowMode = slowModeSeconds;
          final gone = muted ?? removed;
          if (gone != null) _lines.removeWhere((l) => l.identity == gone);
          if (removed != null && removed == _join?.identity) {
            _gate = 'You were removed from this stream';
          }
        case ViewersEvent(:final count):
          _viewers = count;
        case VideoChangedEvent():
          break;
        case EndedEvent():
          _ended = true;
      }
      if (_lines.length > 200) _lines.removeRange(0, _lines.length - 200);
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final wait = _nextSendAt?.difference(DateTime.now());
    if (!_host && wait != null && !wait.isNegative) {
      return _snack(context, 'Slow mode: wait ${wait.inSeconds + 1}s');
    }
    _input.clear();
    // ponytail: slow mode is enforced in the app; mute abusive viewers for
    // a server-enforced block.
    if (_slowMode > 0) {
      _nextSendAt = DateTime.now().add(Duration(seconds: _slowMode));
    }
    await _connection?.sendChat(text);
  }

  Future<void> _tip() async {
    final kes = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final amount in const [50, 100, 200, 500, 1000])
                ActionChip(
                  label: Text(formatKes(amount * 100)),
                  onPressed: () => Navigator.pop(context, amount),
                ),
            ],
          ),
        ),
      ),
    );
    if (kes == null || !mounted) return;
    final paid = await context.push<bool>(
      '/checkout/tip/${widget.id}?amount=${kes * 100}',
    );
    if (paid == true) _connection?.tipPaid(_join!.name, kes * 100);
  }

  Future<void> _buyAccess() async {
    final session = _session!;
    final path = session['access'] == 'ticketed'
        ? '/checkout/ticket/${widget.id}'
        : '/checkout/subscription/${(session['creator'] as _Json)['id']}';
    final paid = await context.push<bool>(path);
    if (paid == true) await _enter();
  }

  Future<void> _moderate(_ChatLine line) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.push_pin_outlined),
              title: const Text('Pin message'),
              onTap: () => Navigator.pop(context, 'pin'),
            ),
            ListTile(
              leading: const Icon(Icons.volume_off_outlined),
              title: Text('Mute ${line.name}'),
              onTap: () => Navigator.pop(context, 'mute'),
            ),
            ListTile(
              leading: const Icon(Icons.person_remove_outlined),
              title: Text('Remove ${line.name}'),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;
    if (action == 'pin') return _connection?.pin('${line.name}: ${line.text}');
    try {
      await ref
          .read(dioProvider)
          .post<void>(
            '/live/sessions/${widget.id}/moderation',
            data: {'action': action, 'identity': line.identity},
          );
      await _connection?.moderate(
        action == 'mute'
            ? ModerationEvent(muted: line.identity)
            : ModerationEvent(removed: line.identity),
      );
    } catch (e) {
      if (mounted) _snack(context, apiErrorMessage(e));
    }
  }

  Future<void> _setSlowMode(int seconds) async {
    try {
      await ref
          .read(dioProvider)
          .post<void>(
            '/live/sessions/${widget.id}/moderation',
            data: {'action': 'slow_mode', 'seconds': seconds},
          );
      await _connection?.moderate(ModerationEvent(slowModeSeconds: seconds));
    } catch (e) {
      if (mounted) _snack(context, apiErrorMessage(e));
    }
  }

  Future<void> _end() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End stream?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep streaming'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final summary =
          (await ref
                  .read(dioProvider)
                  .post<_Json>('/live/sessions/${widget.id}/end'))
              .data!;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Stream ended'),
          content: Text(
            'Duration: ${Duration(seconds: summary['durationSeconds'] as int).inMinutes} min\n'
            'Tips: ${formatKes(summary['tipsCents'] as int)}\n'
            'Tickets sold: ${summary['ticketsSold']}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) _snack(context, apiErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null && _gate == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_gate != null) return _gateView();
    final connection = _connection;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: connection == null
                ? const SizedBox()
                : connection.video(context),
          ),
          SafeArea(
            child: Column(
              children: [
                _topBar(session!),
                if (_pinned != null) _pinBanner(),
                const Spacer(),
                if (_ended)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'This stream has ended',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                _chat(),
                if (!_ended) _composer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gateView() {
    final session = _session;
    final canBuy = _gateCode == 'LIVE_ACCESS_DENIED' && session != null;
    return Scaffold(
      appBar: AppBar(title: Text(session?['title'] as String? ?? 'Live')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 12),
              Text(_gate!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              if (canBuy)
                FilledButton(
                  key: const ValueKey('live-buy'),
                  onPressed: _buyAccess,
                  child: Text(
                    session['access'] == 'ticketed'
                        ? 'Buy ticket · ${formatKes(session['priceCents'] as int)}'
                        : 'Subscribe to watch',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(_Json session) {
    const white = TextStyle(color: Colors.white);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          const _LiveBadge(),
          const SizedBox(width: 8),
          const Icon(Icons.visibility, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text('$_viewers', key: const ValueKey('live-viewers'), style: white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              session['title'] as String,
              style: white,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_host) ...[
            IconButton(
              tooltip: _mic ? 'Mute microphone' : 'Unmute microphone',
              color: Colors.white,
              onPressed: () {
                setState(() => _mic = !_mic);
                _connection?.setMicrophone(_mic);
              },
              icon: Icon(_mic ? Icons.mic : Icons.mic_off),
            ),
            IconButton(
              tooltip: _camera ? 'Turn camera off' : 'Turn camera on',
              color: Colors.white,
              onPressed: () {
                setState(() => _camera = !_camera);
                _connection?.setCamera(_camera);
              },
              icon: Icon(_camera ? Icons.videocam : Icons.videocam_off),
            ),
            IconButton(
              tooltip: 'Flip camera',
              color: Colors.white,
              onPressed: () => _connection?.flipCamera(),
              icon: const Icon(Icons.cameraswitch_outlined),
            ),
            PopupMenuButton<int>(
              tooltip: 'Slow mode',
              iconColor: Colors.white,
              icon: const Icon(Icons.timer_outlined),
              onSelected: _setSlowMode,
              itemBuilder: (_) => [
                for (final s in const [0, 10, 30])
                  CheckedPopupMenuItem(
                    value: s,
                    checked: _slowMode == s,
                    child: Text(s == 0 ? 'Slow mode off' : 'Slow mode ${s}s'),
                  ),
              ],
            ),
            TextButton(
              key: const ValueKey('live-end'),
              onPressed: _end,
              child: const Text('End', style: TextStyle(color: Colors.red)),
            ),
          ] else ...[
            IconButton(
              tooltip: 'Report',
              color: Colors.white,
              onPressed: () => showReportDialog(
                context,
                ref,
                targetType: 'user',
                targetId: (session['creator'] as _Json)['id'] as String,
              ),
              icon: const Icon(Icons.flag_outlined),
            ),
            IconButton(
              tooltip: 'Leave',
              color: Colors.white,
              onPressed: () => context.pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pinBanner() => Container(
    key: const ValueKey('live-pin'),
    margin: const EdgeInsets.symmetric(horizontal: 8),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white24,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        const Icon(Icons.push_pin, color: Colors.white, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(_pinned!, style: const TextStyle(color: Colors.white)),
        ),
        if (_host)
          IconButton(
            tooltip: 'Unpin',
            color: Colors.white,
            iconSize: 16,
            onPressed: () => _connection?.pin(null),
            icon: const Icon(Icons.close),
          ),
      ],
    ),
  );

  Widget _chat() => SizedBox(
    height: 220,
    child: ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _lines.length,
      itemBuilder: (context, i) {
        final line = _lines[_lines.length - 1 - i];
        final mine = line.identity == _join?.identity;
        return GestureDetector(
          onTap: _host && line.identity != null && !mine
              ? () => _moderate(line)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${line.name} ',
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: line.tipCents == null
                        ? line.text
                        : 'sent a ${formatKes(line.tipCents!)} tip 🎉',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _composer() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey('live-chat-input'),
            controller: _input,
            maxLength: 200,
            style: const TextStyle(color: Colors.white),
            onSubmitted: (_) => _send(),
            decoration: InputDecoration(
              hintText: _slowMode > 0
                  ? 'Slow mode: ${_slowMode}s'
                  : 'Say something',
              hintStyle: const TextStyle(color: Colors.white54),
              counterText: '',
              filled: true,
              fillColor: Colors.white12,
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('live-chat-send'),
          tooltip: 'Send',
          color: Colors.white,
          onPressed: _send,
          icon: const Icon(Icons.send),
        ),
        if (!_host)
          IconButton.filled(
            key: const ValueKey('live-tip'),
            tooltip: 'Send a tip',
            onPressed: _tip,
            icon: const Icon(Icons.volunteer_activism),
          ),
      ],
    ),
  );
}
