import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

/// What the API's token endpoint returns for one viewer or host.
class LiveJoin {
  const LiveJoin({
    required this.sessionId,
    required this.url,
    required this.token,
    required this.identity,
    required this.name,
    required this.canPublish,
    required this.creatorIdentity,
  });
  final String sessionId;
  final String url;
  final String token;
  final String identity;
  final String name;
  final bool canPublish;
  final String creatorIdentity;
}

sealed class LiveEvent {}

class ChatEvent extends LiveEvent {
  ChatEvent(this.identity, this.name, this.text);
  final String identity;
  final String name;
  final String text;
}

/// Only trusted when sent by the server (no sender participant).
class TipEvent extends LiveEvent {
  TipEvent(this.name, this.amountCents);
  final String name;
  final int amountCents;
}

/// Only trusted from the creator's identity.
class PinEvent extends LiveEvent {
  PinEvent(this.text);
  final String? text;
}

class ModerationEvent extends LiveEvent {
  ModerationEvent({this.slowModeSeconds, this.muted, this.removed});
  final int? slowModeSeconds;
  final String? muted;
  final String? removed;
}

class ViewersEvent extends LiveEvent {
  ViewersEvent(this.count);
  final int count;
}

class VideoChangedEvent extends LiveEvent {}

class EndedEvent extends LiveEvent {}

/// Turns a room data message into an event, dropping anything whose sender
/// is not allowed to send it. A null [senderIdentity] means the API server
/// sent it; viewers cannot forge that.
LiveEvent? parseLiveData({
  required String? topic,
  required List<int> data,
  required String? senderIdentity,
  required String? senderName,
  required String creatorIdentity,
  Set<String> muted = const {},
}) {
  final Map<String, dynamic> json;
  try {
    json = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
  } on FormatException {
    return null;
  }
  final fromServer = senderIdentity == null;
  final fromCreator = senderIdentity == creatorIdentity;
  return switch (topic) {
    'chat' when !fromServer && !muted.contains(senderIdentity) => ChatEvent(
      senderIdentity,
      senderName ?? '',
      '${json['text']}',
    ),
    'tip' when fromServer && json['amountCents'] is int => TipEvent(
      '${json['name']}',
      json['amountCents'] as int,
    ),
    'pin' when fromCreator => PinEvent(json['text'] as String?),
    'moderation' when fromServer || fromCreator => ModerationEvent(
      slowModeSeconds: json['slowModeSeconds'] as int?,
      muted: json['muted'] as String?,
      removed: json['removed'] as String?,
    ),
    _ => null,
  };
}

/// The room transport. [LiveKitConnection] in real use; [DemoConnection]
/// when no LiveKit server is configured (and in tests).
abstract class LiveConnection {
  final _events = StreamController<LiveEvent>.broadcast();
  Stream<LiveEvent> get events => _events.stream;
  void emit(LiveEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  Future<void> connect();
  Future<void> sendChat(String text);

  /// Host only: pin a message, or clear the pin with null.
  Future<void> pin(String? text);

  /// Host only: tells viewers' apps about slow mode, mutes and removals. The
  /// API enforces the same actions server side.
  Future<void> moderate(ModerationEvent event);
  Future<void> setCamera(bool on);
  Future<void> setMicrophone(bool on);
  Future<void> flipCamera();

  /// Called after this user's tip payment succeeds. LiveKit: the server
  /// announces it, so nothing to do here.
  void tipPaid(String name, int amountCents) {}
  Widget video(BuildContext context);

  @mustCallSuper
  Future<void> dispose() => _events.close();
}

final liveConnectionFactoryProvider =
    Provider<LiveConnection Function(LiveJoin)>(
      (ref) =>
          (join) =>
              join.url.isEmpty ? DemoConnection(join) : LiveKitConnection(join),
    );

class LiveKitConnection extends LiveConnection {
  LiveKitConnection(this.join);
  final LiveJoin join;
  final _room = Room();
  EventsListener<RoomEvent>? _listener;
  final _muted = <String>{};
  var _front = true;

  @override
  Future<void> connect() async {
    final listener = _listener = _room.createListener();
    listener
      ..on<DataReceivedEvent>(_onData)
      ..on<ParticipantConnectedEvent>((_) => _viewers())
      ..on<ParticipantDisconnectedEvent>((_) => _viewers())
      ..on<TrackSubscribedEvent>((_) => emit(VideoChangedEvent()))
      ..on<TrackUnsubscribedEvent>((_) => emit(VideoChangedEvent()))
      ..on<LocalTrackPublishedEvent>((_) => emit(VideoChangedEvent()))
      ..on<RoomDisconnectedEvent>((_) => emit(EndedEvent()));
    await _room.connect(join.url, join.token);
    if (join.canPublish) {
      await _room.localParticipant?.setCameraEnabled(true);
      await _room.localParticipant?.setMicrophoneEnabled(true);
    }
    _viewers();
    emit(VideoChangedEvent());
  }

  void _viewers() => emit(ViewersEvent(_room.remoteParticipants.length));

  void _onData(DataReceivedEvent e) {
    final event = parseLiveData(
      topic: e.topic,
      data: e.data,
      senderIdentity: e.participant?.identity,
      senderName: e.participant?.name,
      creatorIdentity: join.creatorIdentity,
      muted: _muted,
    );
    if (event is ModerationEvent) {
      if (event.muted != null) _muted.add(event.muted!);
      if (event.removed == join.identity) unawaited(_room.disconnect());
    }
    if (event != null) emit(event);
  }

  Future<void> _send(String topic, Map<String, Object?> json) => _room
      .localParticipant!
      .publishData(utf8.encode(jsonEncode(json)), reliable: true, topic: topic);

  @override
  Future<void> sendChat(String text) async {
    await _send('chat', {'text': text});
    emit(ChatEvent(join.identity, join.name, text)); // LiveKit doesn't echo
  }

  @override
  Future<void> pin(String? text) async {
    await _send('pin', {'text': text});
    emit(PinEvent(text));
  }

  @override
  Future<void> moderate(ModerationEvent event) async {
    await _send('moderation', {
      'slowModeSeconds': event.slowModeSeconds,
      'muted': event.muted,
      'removed': event.removed,
    });
    if (event.muted != null) _muted.add(event.muted!);
    emit(event);
  }

  @override
  Future<void> setCamera(bool on) async =>
      _room.localParticipant?.setCameraEnabled(on);

  @override
  Future<void> setMicrophone(bool on) async =>
      _room.localParticipant?.setMicrophoneEnabled(on);

  @override
  Future<void> flipCamera() async {
    final track =
        _room.localParticipant?.videoTrackPublications.firstOrNull?.track;
    _front = !_front;
    await track?.setCameraPosition(
      _front ? CameraPosition.front : CameraPosition.back,
    );
  }

  @override
  Widget video(BuildContext context) {
    final VideoTrack? track = join.canPublish
        ? _room.localParticipant?.videoTrackPublications.firstOrNull?.track
        : _room.remoteParticipants.values
              .where((p) => p.identity == join.creatorIdentity)
              .firstOrNull
              ?.videoTrackPublications
              .firstOrNull
              ?.track;
    return track == null
        ? const _NoVideo('Waiting for video…')
        : VideoTrackRenderer(track, fit: VideoViewFit.cover);
  }

  @override
  Future<void> dispose() async {
    await _listener?.dispose();
    await _room.disconnect();
    await _room.dispose();
    await super.dispose();
  }
}

/// Runs the room UI without a LiveKit server: no real video, chat stays on
/// this device, and a few sample viewers chat so the screen can be tried.
class DemoConnection extends LiveConnection {
  DemoConnection(this.join, {this.sampleChat = true});
  final LiveJoin join;
  final bool sampleChat;
  Timer? _timer;
  final _muted = <String>{};

  static const _sample = [
    ('v1', 'Wanjiku', 'Hello from Nakuru! 👋'),
    ('v2', 'Brian', 'This is fire 🔥'),
    ('v3', 'Akinyi', 'Can you do a shout-out?'),
    ('v2', 'Brian', 'Joined late, what did I miss?'),
  ];

  @override
  Future<void> connect() async {
    emit(ViewersEvent(3));
    if (!sampleChat) return;
    var i = 0;
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      final (identity, name, text) = _sample[i++ % _sample.length];
      if (!_muted.contains(identity)) emit(ChatEvent(identity, name, text));
    });
  }

  @override
  Future<void> sendChat(String text) async =>
      emit(ChatEvent(join.identity, join.name, text));

  @override
  Future<void> pin(String? text) async => emit(PinEvent(text));

  @override
  Future<void> moderate(ModerationEvent event) async {
    if (event.muted != null) _muted.add(event.muted!);
    if (event.removed != null) _muted.add(event.removed!);
    emit(event);
  }

  @override
  void tipPaid(String name, int amountCents) =>
      emit(TipEvent(name, amountCents));

  @override
  Future<void> setCamera(bool on) async {}

  @override
  Future<void> setMicrophone(bool on) async {}

  @override
  Future<void> flipCamera() async {}

  @override
  Widget video(BuildContext context) =>
      const _NoVideo("Video isn't available in this demo.");

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    await super.dispose();
  }
}

class _NoVideo extends StatelessWidget {
  const _NoVideo(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2A0F1F), Color(0xFF0D0D12)],
      ),
    ),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    ),
  );
}
