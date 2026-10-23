import 'package:dio/dio.dart';

import '../../core/fake_backend.dart';
import '../auth/fake_auth.dart';
import '../content/fake_content.dart';
import '../onboarding/fake_onboarding.dart';

/// In-memory live sessions (docs/api-additions.md "Livestreaming"). Tokens
/// come from `--dart-define=LIVEKIT_URL=... --dart-define=LIVEKIT_DEV_TOKEN=...`
/// when set; otherwise the app runs the room in demo mode.
const _livekitUrl = String.fromEnvironment('LIVEKIT_URL');
const _devToken = String.fromEnvironment('LIVEKIT_DEV_TOKEN');

class _Session {
  _Session(
    this.id,
    this.creatorId,
    this.title,
    this.access,
    this.priceCents,
    this.record,
  );
  final String id;
  final String creatorId;
  final String title;
  final String access; // free | subscribers | ticketed
  final int? priceCents;
  final bool record;
  String status = 'live';
  final startedAt = DateTime.now().toUtc();
  DateTime? endedAt;
  int tipsCents = 0;
  final tickets = <String>{};
  final muted = <String>{};
  final removed = <String>{};
  int slowModeSeconds = 0;
}

class FakeLiveDb {
  final _sessions = <String, _Session>{};
  var _seq = 0;

  FakeLiveDb() {
    reset();
  }

  void reset() {
    _sessions.clear();
    _seq = 0;
    _sessions['live1'] = _Session(
      'live1',
      'c10',
      'Morning HIIT, live',
      'free',
      null,
      false,
    );
    _sessions['live2'] = _Session(
      'live2',
      'c11',
      'Studio session: new beats',
      'ticketed',
      20000,
      true,
    );
  }

  ({String creatorId, int priceCents})? ticketFor(String sessionId) {
    final s = _sessions[sessionId];
    if (s == null || s.status != 'live' || s.access != 'ticketed') return null;
    return (creatorId: s.creatorId, priceCents: s.priceCents!);
  }

  String? creatorOf(String sessionId) {
    final s = _sessions[sessionId];
    return s?.status == 'live' ? s!.creatorId : null;
  }

  void grantTicket(String fanId, String sessionId) =>
      _sessions[sessionId]?.tickets.add(fanId);

  void recordTip(String sessionId, int amountCents) =>
      _sessions[sessionId]?.tipsCents += amountCents;

  bool _canWatch(_Session s, String userId) {
    if (s.creatorId == userId) return true;
    if (s.removed.contains(userId)) return false;
    return switch (s.access) {
      'free' => true,
      'subscribers' => fakeContentDb.isSubscribed(userId, s.creatorId),
      'ticketed' => s.tickets.contains(userId),
      _ => false,
    };
  }

  Map<String, Object?> _json(_Session s, String viewerId) => {
    'id': s.id,
    'creator': fakeContentDb.creatorJson(s.creatorId, viewerId),
    'title': s.title,
    'access': s.access,
    'priceCents': s.priceCents,
    'record': s.record,
    'status': s.status,
    'startedAt': s.startedAt.toIso8601String(),
    'slowModeSeconds': s.slowModeSeconds,
    'hasAccess': _canWatch(s, viewerId),
    'removed': s.removed.contains(viewerId),
  };

  (int, Object?) _signedIn(
    RequestOptions req,
    (int, Object?) Function(String userId) handle,
  ) {
    final userId = fakeAuthDb.callerId(req);
    return userId == null ? FakeAuthDb.unauthorized : handle(userId);
  }

  static (int, Object?) _error(int status, String code, String message) =>
      (status, {'code': code, 'message': message});

  static const _notFound = (404, {'code': 'NOT_FOUND', 'message': 'Not found'});

  (int, Object?) _own(
    RequestOptions req,
    String? id,
    (int, Object?) Function(_Session s) handle,
  ) => _signedIn(req, (userId) {
    final s = _sessions[id];
    if (s == null || s.creatorId != userId) return _notFound;
    return handle(s);
  });

  Map<String, FakeHandler> get routes => {
    'GET /live/now': (req, _) => _signedIn(
      req,
      (userId) => (
        200,
        [
          for (final s in _sessions.values.where(
            (s) =>
                s.status == 'live' &&
                fakeContentDb.creatorProfile(s.creatorId) != null,
          ))
            _json(s, userId),
        ],
      ),
    ),
    'GET /live/sessions/{id}': (req, params) => _signedIn(req, (userId) {
      final s = _sessions[params['id']];
      return s == null ? _notFound : (200, _json(s, userId));
    }),
    'POST /live/sessions': (req, _) => _signedIn(req, (userId) {
      if (!fakeOnboardingDb.isApproved(userId)) {
        return _error(
          403,
          'CREATOR_NOT_APPROVED',
          'Finish creator setup before going live',
        );
      }
      final body = req.data as Map;
      final access = body['access'] as String? ?? 'free';
      final price = body['priceCents'] as int?;
      final title = (body['title'] as String? ?? '').trim();
      if (title.isEmpty) {
        return _error(400, 'TITLE_REQUIRED', 'Give your stream a title');
      }
      if (!{'free', 'subscribers', 'ticketed'}.contains(access)) {
        return _error(400, 'INVALID_ACCESS', 'Choose who can watch');
      }
      if (access == 'ticketed' &&
          (price == null || price < minPriceCents || price > maxPriceCents)) {
        return _error(
          400,
          'PRICE_OUT_OF_RANGE',
          'Ticket price must be between KSh 10 and KSh 50,000',
        );
      }
      if (body['safetyConfirmed'] != true) {
        return _error(
          400,
          'SAFETY_CHECK_REQUIRED',
          'Confirm the live safety rules',
        );
      }
      for (final s in _sessions.values.where(
        (s) => s.creatorId == userId && s.status == 'live',
      )) {
        s.status = 'ended';
      }
      final id = 'live${++_seq + 10}';
      _sessions[id] = _Session(
        id,
        userId,
        title,
        access,
        access == 'ticketed' ? price : null,
        body['record'] == true,
      );
      return (201, _json(_sessions[id]!, userId));
    }),
    'POST /live/sessions/{id}/token': (req, params) => _signedIn(req, (userId) {
      final s = _sessions[params['id']];
      if (s == null || s.status != 'live') {
        return _error(410, 'LIVE_ENDED', 'This stream has ended');
      }
      if (s.removed.contains(userId)) {
        return _error(
          403,
          'REMOVED_FROM_LIVE',
          'You were removed from this stream',
        );
      }
      if (!_canWatch(s, userId)) {
        return _error(
          403,
          'LIVE_ACCESS_DENIED',
          s.access == 'ticketed' ? 'Buy a ticket to join' : 'Subscribe to join',
        );
      }
      final profile = fakeContentDb.creatorProfile(userId);
      return (
        200,
        {
          'url': _livekitUrl,
          'token': _devToken,
          'room': 'live-${s.id}',
          'identity': userId,
          'name': profile?['displayName'] ?? 'Fan ${userId.toUpperCase()}',
          'canPublish': s.creatorId == userId,
        },
      );
    }),
    'POST /live/sessions/{id}/end': (req, params) =>
        _own(req, params['id'], (s) {
          s
            ..status = 'ended'
            ..endedAt = DateTime.now().toUtc();
          return (
            200,
            {
              'durationSeconds': s.endedAt!.difference(s.startedAt).inSeconds,
              'tipsCents': s.tipsCents,
              'ticketsSold': s.tickets.length,
              'ticketRevenueCents': s.tickets.length * (s.priceCents ?? 0),
            },
          );
        }),
    // Real system: also updates LiveKit participant permissions via the
    // server SDK, so muted or removed viewers are enforced in the room.
    'POST /live/sessions/{id}/moderation': (req, params) =>
        _own(req, params['id'], (s) {
          final body = req.data as Map;
          final identity = body['identity'] as String?;
          switch (body['action']) {
            case 'mute' when identity != null:
              s.muted.add(identity);
            case 'unmute' when identity != null:
              s.muted.remove(identity);
            case 'remove' when identity != null:
              s.removed.add(identity);
            case 'slow_mode':
              s.slowModeSeconds = body['seconds'] as int? ?? 0;
            default:
              return _error(400, 'INVALID_ACTION', 'Unknown action');
          }
          return (204, null);
        }),
  };
}

final fakeLiveDb = FakeLiveDb();
