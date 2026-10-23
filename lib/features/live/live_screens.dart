import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../app/ui.dart';
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

/// Side gutter that centres a [maxWidth] column on wide screens.
double _gutter(BuildContext context, double maxWidth) =>
    math.max(16, (MediaQuery.sizeOf(context).width - maxWidth) / 2);

IconData _accessIcon(_Json s) => switch (s['access']) {
  'ticketed' => Icons.confirmation_number_outlined,
  'subscribers' => Icons.star_outline_rounded,
  _ => Icons.public,
};

String _liveFor(_Json s) {
  final started = DateTime.tryParse(s['startedAt'] as String? ?? '');
  final minutes = started == null
      ? 0
      : DateTime.now().toUtc().difference(started).inMinutes;
  return minutes < 1 ? 'Just started' : 'Live for $minutes min';
}

/// Fan "Live" tab.
class LiveNowScreen extends ConsumerWidget {
  const LiveNowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Clears the frosted tab bar (the shell draws this screen edge to edge).
    final bottom = MediaQuery.paddingOf(context).bottom;
    final gutter = _gutter(context, 640);
    return Scaffold(
      appBar: tabAppBar(context, 'Live now'),
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackground()),
          asyncBody(
            ref.watch(liveNowProvider),
            () => ref.invalidate(liveNowProvider),
            loading: () => const SkeletonList(count: 3, itemHeight: 220),
            (sessions) => RefreshIndicator(
              onRefresh: () => ref.refresh(liveNowProvider.future),
              child: sessions.isEmpty
                  ? CustomScrollView(
                      slivers: [
                        SliverFillRemaining(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: bottom),
                            child: const StateView(
                              icon: Icons.sensors_off_outlined,
                              title: 'Nobody is live right now',
                              message: 'Pull down to check again.',
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        gutter,
                        8,
                        gutter,
                        24 + bottom,
                      ),
                      itemCount: sessions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, i) => Entrance(
                        key: ValueKey(sessions[i]['id']),
                        index: i,
                        child: _LiveCard(session: sessions[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A live session as a lit stage: the host's cover, their ringed avatar and
/// the access terms, then the title.
class _LiveCard extends StatelessWidget {
  const _LiveCard({required this.session});
  final _Json session;

  static const _stageHeight = 156.0;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final creator = s['creator'] as _Json;
    final name = creator['displayName'] as String;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    return Pressable(
      child: Material(
        color: scheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(cardRadius)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          onTap: () => context.push('/live/${s['id']}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: _stageHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CreatorBanner(id: creator['id'] as String),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.18),
                            Colors.black.withValues(alpha: 0),
                            Colors.black.withValues(alpha: 0.28),
                          ],
                        ),
                      ),
                    ),
                    Center(
                      child: CreatorAvatar(
                        id: creator['id'] as String,
                        name: name,
                        size: 68,
                        ring: true,
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Row(
                        children: [
                          const _LiveBadge(),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: _RoomGlass(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _accessIcon(s),
                                      size: 15,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        _accessLabel(s),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: text.labelMedium?.copyWith(
                                          color: Colors.white,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s['title'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: muted,
                          ),
                        ),
                        if (creator['verified'] == true) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified,
                            size: 15,
                            color: scheme.primary,
                            semanticLabel: 'Verified creator',
                          ),
                        ],
                        Text(' · ', style: muted),
                        Flexible(
                          child: Text(
                            _liveFor(s),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: muted?.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "LIVE" in the accent. The dot breathes three times on arrival, then rests:
/// it is a signal, not a loop.
class _LiveBadge extends StatefulWidget {
  const _LiveBadge();

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final _dot = Tween(
    begin: 1.0,
    end: 0.3,
  ).animate(CurvedAnimation(parent: _pulse, curve: easeInOut));
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Out and back is two runs, so three breaths.
    if (!MediaQuery.disableAnimationsOf(context)) {
      _pulse.repeat(reverse: true, count: 6);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _dot,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'LIVE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Frosted chrome laid over video or a cover: dark, so white reads on it in
/// either theme.
class _RoomGlass extends StatelessWidget {
  const _RoomGlass({
    super.key,
    required this.child,
    this.radius = 999,
    this.padding = EdgeInsets.zero,
  });
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Glass(
    borderRadius: BorderRadius.all(Radius.circular(radius)),
    color: Colors.black.withValues(alpha: 0.34),
    border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
    child: Padding(padding: padding, child: child),
  );
}

/// A grouped block of the setup form, under a quiet label.
class _Group extends StatelessWidget {
  const _Group({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ],
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.12),
          borderRadius: const BorderRadius.all(Radius.circular(controlRadius)),
        ),
        child: Icon(icon, size: 20, color: scheme.primary),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
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
    final scheme = Theme.of(context).colorScheme;
    // Clears the frosted tab bar (the shell draws this screen edge to edge).
    final bottom = MediaQuery.paddingOf(context).bottom;
    final gutter = _gutter(context, 560);
    return Scaffold(
      appBar: tabAppBar(context, 'Go live'),
      body: !approved
          ? Padding(
              padding: EdgeInsets.only(bottom: bottom),
              child: StateView(
                icon: Icons.verified_user_outlined,
                title: 'Finish creator setup to go live.',
                action: TextButton(
                  onPressed: () => context.push('/onboarding'),
                  child: const Text('Continue setup'),
                ),
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 24 + bottom),
              children: [
                const _Group(
                  label: 'Before you start',
                  child: Column(
                    children: [
                      _Check(
                        icon: Icons.videocam_outlined,
                        title: 'Camera and microphone',
                        subtitle:
                            'You will be asked for access when the stream starts',
                      ),
                      _Check(
                        icon: Icons.wifi,
                        title: 'Connection',
                        subtitle:
                            'Use Wi-Fi or a strong 4G signal. Quality adapts '
                            'automatically.',
                      ),
                    ],
                  ),
                ),
                _Group(
                  label: 'Stream',
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          key: const ValueKey('live-title'),
                          controller: _title,
                          maxLength: 80,
                          decoration: const InputDecoration(
                            labelText: 'Stream title',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Who can watch?', style: text.titleSmall),
                        const SizedBox(height: 10),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'free', label: Text('Free')),
                            ButtonSegment(
                              value: 'subscribers',
                              label: Text('Subscribers'),
                            ),
                            ButtonSegment(
                              value: 'ticketed',
                              label: Text('Ticket'),
                            ),
                          ],
                          selected: {_access},
                          onSelectionChanged: (s) =>
                              setState(() => _access = s.first),
                        ),
                        if (_access == 'ticketed') ...[
                          const SizedBox(height: 16),
                          TextField(
                            key: const ValueKey('live-price'),
                            controller: _price,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Ticket price',
                              prefixText: 'KSh ',
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Record this stream'),
                          subtitle: const Text(
                            'Only you can see the recording',
                          ),
                          value: _record,
                          onChanged: (v) => setState(() => _record = v),
                        ),
                      ],
                    ),
                  ),
                ),
                _Group(
                  label: 'Safety',
                  // Tints once the creator has confirmed.
                  child: AnimatedContainer(
                    duration: motion(context, shortDuration),
                    curve: easeOut,
                    decoration: BoxDecoration(
                      color: _safety
                          ? scheme.primary.withValues(alpha: 0.08)
                          : null,
                    ),
                    child: CheckboxListTile(
                      key: const ValueKey('live-safety'),
                      contentPadding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _safety,
                      onChanged: (v) => setState(() => _safety = v!),
                      title: const Text(
                        'Everyone on camera is 18+ and has agreed to appear. '
                        'I will follow the content rules.',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Pressable(
                  child: FilledButton.icon(
                    key: const ValueKey('live-start'),
                    style: brandButtonStyle(context),
                    onPressed: _busy ? null : _start,
                    icon: const Icon(Icons.sensors),
                    label: const Text('Go live'),
                  ),
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
                  label: Text(
                    formatKes(amount * 100),
                    style: const TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
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
          content: _Summary(
            rows: [
              (
                'Duration',
                '${Duration(seconds: summary['durationSeconds'] as int).inMinutes} min',
              ),
              ('Tips', formatKes(summary['tipsCents'] as int)),
              ('Tickets sold', '${summary['ticketsSold']}'),
            ],
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
      // Dark like the room it opens into, so entering doesn't flash.
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white70,
            ),
          ),
        ),
      );
    }
    if (_gate != null) return _gateView();
    final connection = _connection;
    Widget scrim(List<double> alphas) => IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [for (final a in alphas) Colors.black.withValues(alpha: a)],
          ),
        ),
      ),
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: connection == null
                ? const SizedBox()
                : connection.video(context),
          ),
          // Shade the edges so the chrome reads over any picture.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 180,
            child: scrim(const [0.5, 0]),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 380,
            child: scrim(const [0, 0.7]),
          ),
          SafeArea(
            child: Column(
              children: [
                _topBar(session!),
                if (_pinned != null) _pinBanner(),
                const Spacer(),
                if (_ended)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _RoomGlass(
                      radius: cardRadius,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Text(
                        'This stream has ended',
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: Colors.white),
                      ),
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
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackground()),
          StateView(
            icon: Icons.lock_outline,
            title: _gate!,
            action: canBuy
                ? Pressable(
                    child: FilledButton(
                      key: const ValueKey('live-buy'),
                      style: brandButtonStyle(context),
                      onPressed: _buyAccess,
                      child: Text(
                        session['access'] == 'ticketed'
                            ? 'Buy ticket · ${formatKes(session['priceCents'] as int)}'
                            : 'Subscribe to watch',
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _topBar(_Json session) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _RoomGlass(
                  padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                  child: Row(
                    children: [
                      const _LiveBadge(),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.visibility_outlined,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_viewers',
                        key: const ValueKey('live-viewers'),
                        style: text.labelLarge?.copyWith(
                          color: Colors.white,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          session['title'] as String,
                          maxLines: 1,
                          style: text.titleSmall?.copyWith(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_host)
                TextButton(
                  key: const ValueKey('live-end'),
                  style: TextButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                    minimumSize: const Size(64, 44),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: _end,
                  child: const Text('End'),
                )
              else
                _RoomGlass(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Report',
                        color: Colors.white,
                        onPressed: () => showReportDialog(
                          context,
                          ref,
                          targetType: 'user',
                          targetId:
                              (session['creator'] as _Json)['id'] as String,
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
                  ),
                ),
            ],
          ),
          if (_host) ...[
            const SizedBox(height: 8),
            _RoomGlass(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                          child: Text(
                            s == 0 ? 'Slow mode off' : 'Slow mode ${s}s',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pinBanner() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
    child: _RoomGlass(
      key: const ValueKey('live-pin'),
      radius: controlRadius,
      padding: EdgeInsets.fromLTRB(12, 10, _host ? 0 : 12, 10),
      child: Row(
        children: [
          const Icon(Icons.push_pin, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _pinned!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ),
          if (_host)
            IconButton(
              tooltip: 'Unpin',
              color: Colors.white,
              iconSize: 16,
              visualDensity: VisualDensity.compact,
              onPressed: () => _connection?.pin(null),
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    ),
  );

  Widget _chat() {
    final brand = Brand.of(context);
    final body = Theme.of(context).textTheme.bodyMedium;
    // Older lines fade out at the top edge instead of being cut off.
    return SizedBox(
      height: 220,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
          stops: [0, 0.18],
        ).createShader(rect),
        child: ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _lines.length,
          // Lines keep their element as new ones push them up, so each fades
          // in once, on arrival.
          findChildIndexCallback: (key) {
            final i = _lines.indexOf((key as ObjectKey).value! as _ChatLine);
            return i < 0 ? null : _lines.length - 1 - i;
          },
          itemBuilder: (context, i) {
            final line = _lines[_lines.length - 1 - i];
            final mine = line.identity == _join?.identity;
            final tip = line.tipCents != null;
            final ink = tip ? brandInk : Colors.white;
            return Align(
              key: ObjectKey(line),
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: GestureDetector(
                  onTap: _host && line.identity != null && !mine
                      ? () => _moderate(line)
                      : null,
                  child: _FadeIn(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tip
                            ? null
                            : Colors.black.withValues(alpha: 0.36),
                        gradient: tip ? brand.gradient : null,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(controlRadius),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${line.name} ',
                                style: TextStyle(
                                  color: tip
                                      ? brandInk
                                      : identityColors(
                                          line.identity ?? line.name,
                                        ).$1,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text: tip
                                    ? 'sent a ${formatKes(line.tipCents!)} tip 🎉'
                                    : line.text,
                                style: TextStyle(
                                  color: ink,
                                  fontWeight: tip ? FontWeight.w600 : null,
                                ),
                              ),
                            ],
                          ),
                          style: body,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _composer() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
    child: _RoomGlass(
      radius: cardRadius,
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('live-chat-input'),
              controller: _input,
              maxLength: 200,
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: _slowMode > 0
                    ? 'Slow mode: ${_slowMode}s'
                    : 'Say something',
                hintStyle: const TextStyle(color: Colors.white54),
                counterText: '',
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(controlRadius),
                  ),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(controlRadius),
                  ),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(
                    Radius.circular(controlRadius),
                  ),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 2),
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
              style: brandButtonStyle(context),
              onPressed: _tip,
              icon: const Icon(Icons.volunteer_activism),
            ),
        ],
      ),
    ),
  );
}

/// Fades a chat line in once. Lines arrive often, so nothing moves.
class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: motion(context, shortDuration),
    curve: easeOut,
    builder: (_, t, child) => Opacity(opacity: t, child: child),
    child: child,
  );
}

/// The end-of-stream numbers, one per row.
class _Summary extends StatelessWidget {
  const _Summary({required this.rows});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.all(Radius.circular(cardRadius)),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, (label, value)) in rows.indexed) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    value,
                    style: text.titleMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
