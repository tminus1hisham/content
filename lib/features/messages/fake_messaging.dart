import 'package:dio/dio.dart';

import '../../core/fake_backend.dart';
import '../auth/fake_auth.dart';
import '../content/fake_content.dart';
import '../onboarding/fake_onboarding.dart';

/// In-memory conversations, blocks and reports (IT.md §9.11–9.12). Paid
/// attachments are bought through M6 checkout (`type: message`).
const urgentReasons = {'minor', 'non_consensual'};

class _Message {
  _Message(
    this.id,
    this.conversationId,
    this.senderId,
    this.text, {
    this.mediaId,
    this.priceCents,
  });
  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final String? mediaId;
  final int? priceCents;
  final createdAt = DateTime.now().toUtc();
}

class FakeMessagingDb {
  final _conversations = <String, List<String>>{}; // id -> participant ids
  final _messages = <_Message>[];
  final _unlocked = <String>{}; // 'userId|messageId'
  final _blocks = <String>{}; // 'blocker|blocked'
  final reports = <Map<String, Object?>>[];
  var _seq = 0;

  FakeMessagingDb() {
    reset();
  }

  void reset() {
    _conversations.clear();
    _messages.clear();
    _unlocked.clear();
    _blocks.clear();
    reports.clear();
    _seq = 0;
    _conversations['conv1'] = ['u1', 'u2'];
    _messages
      ..add(_Message('msg1', 'conv1', 'u2', 'Thanks for following! 💃'))
      ..add(
        _Message(
          'msg2',
          'conv1',
          'u2',
          'A little something just for you',
          mediaId: 'msg-media-1',
          priceCents: 10000,
        ),
      );
    reports.add({
      'caseId': 'CASE-1000',
      'reporterId': 'u1',
      'targetType': 'post',
      'targetId': 'p4',
      'reason': 'non_consensual',
      'details': 'I think the person shown did not agree to this.',
      'priority': 'urgent',
      'status': 'open',
      'createdAt': '2026-10-21T08:00:00Z',
    });
    fakeContentDb.media['msg-media-1'] = FakeMedia(
      'msg-media-1',
      'u2',
      'image',
      asset: 'assets/demo/5.jpg',
    );
  }

  bool _blocked(String a, String b) =>
      _blocks.contains('$a|$b') || _blocks.contains('$b|$a');

  /// Lets the content fake serve attachment media to buyers.
  bool canViewMedia(String mediaId, String userId) => _messages.any(
    (m) =>
        m.mediaId == mediaId &&
        _conversations[m.conversationId]!.contains(userId) &&
        (m.senderId == userId || _unlocked.contains('$userId|${m.id}')),
  );

  /// For checkout to price a locked attachment on the "server".
  ({String creatorId, int priceCents})? paidMessage(String id, String buyer) {
    final m = _messages.where((m) => m.id == id).firstOrNull;
    if (m == null ||
        m.priceCents == null ||
        m.senderId == buyer ||
        !_conversations[m.conversationId]!.contains(buyer)) {
      return null;
    }
    return (creatorId: m.senderId, priceCents: m.priceCents!);
  }

  void unlock(String userId, String messageId) =>
      _unlocked.add('$userId|$messageId');

  Map<String, Object?> _person(String id) {
    final profile = fakeContentDb.creatorProfile(id);
    // Fans' emails and phone numbers are never shown to creators.
    return profile == null
        ? {'id': id, 'displayName': 'Fan ${id.toUpperCase()}', 'handle': null}
        : {
            'id': id,
            'displayName': profile['displayName'],
            'handle': profile['handle'],
          };
  }

  Map<String, Object?> _messageJson(_Message m, String viewerId) {
    final locked =
        m.priceCents != null &&
        m.senderId != viewerId &&
        !_unlocked.contains('$viewerId|${m.id}');
    return {
      'id': m.id,
      'senderId': m.senderId,
      'text': m.text,
      'createdAt': m.createdAt.toIso8601String(),
      if (m.mediaId != null)
        'attachment': {
          // The media id is withheld until unlocked (FR-DIS-003).
          'mediaId': locked ? null : m.mediaId,
          'priceCents': m.priceCents,
          'locked': locked,
        },
    };
  }

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

  Map<String, FakeHandler> get routes => {
    'GET /conversations': (req, _) => _signedIn(req, (userId) {
      final mine = _conversations.entries.where(
        (e) => e.value.contains(userId),
      );
      return (
        200,
        [
          for (final e in mine)
            {
              'id': e.key,
              'other': _person(e.value.firstWhere((p) => p != userId)),
              'blocked': _blocked(e.value[0], e.value[1]),
              'lastMessage': _messages
                  .where((m) => m.conversationId == e.key)
                  .map((m) => _messageJson(m, userId))
                  .lastOrNull,
            },
        ],
      );
    }),
    'POST /conversations': (req, _) => _signedIn(req, (userId) {
      final other = (req.data as Map)['userId'] as String?;
      if (other == null || other == userId) {
        return _error(400, 'INVALID_RECIPIENT', 'Choose who to message');
      }
      // Fans may start chats with creators, not with other fans.
      if (fakeContentDb.creatorProfile(other) == null &&
          fakeContentDb.creatorProfile(userId) == null) {
        return _error(403, 'NOT_ALLOWED', 'You can only message creators');
      }
      if (_blocked(userId, other)) {
        return _error(403, 'BLOCKED', 'You cannot message this account');
      }
      final existing = _conversations.entries.where(
        (e) => e.value.contains(userId) && e.value.contains(other),
      );
      final id = existing.isEmpty ? 'conv${++_seq + 1}' : existing.first.key;
      _conversations.putIfAbsent(id, () => [userId, other]);
      return (200, {'id': id, 'other': _person(other)});
    }),
    'GET /conversations/{id}/messages': (req, params) =>
        _signedIn(req, (userId) {
          final people = _conversations[params['id']];
          if (people == null || !people.contains(userId)) return _notFound;
          return (
            200,
            {
              'other': _person(people.firstWhere((p) => p != userId)),
              'blocked': _blocked(people[0], people[1]),
              'blockedByMe': _blocks.contains(
                '$userId|${people.firstWhere((p) => p != userId)}',
              ),
              'messages': [
                for (final m in _messages.where(
                  (m) => m.conversationId == params['id'],
                ))
                  _messageJson(m, userId),
              ],
            },
          );
        }),
    'POST /conversations/{id}/messages': (req, params) => _signedIn(req, (
      userId,
    ) {
      final people = _conversations[params['id']];
      if (people == null || !people.contains(userId)) return _notFound;
      if (_blocked(people[0], people[1])) {
        return _error(403, 'BLOCKED', 'You cannot message this account');
      }
      final body = req.data as Map;
      final text = (body['text'] as String? ?? '').trim();
      final attachment = body['attachment'] as Map?;
      if (text.isEmpty && attachment == null) {
        return _error(400, 'EMPTY_MESSAGE', 'Write a message');
      }
      if (text.length > 2000) {
        return _error(400, 'TOO_LONG', 'Keep messages under 2000 characters');
      }
      int? price;
      String? mediaId;
      if (attachment != null) {
        mediaId = attachment['mediaId'] as String?;
        price = attachment['priceCents'] as int?;
        if (!fakeOnboardingDb.isApproved(userId)) {
          return _error(
            403,
            'CREATOR_NOT_APPROVED',
            'Only approved creators can sell in messages',
          );
        }
        if (fakeContentDb.media[mediaId]?.ownerId != userId) {
          return _error(400, 'MEDIA_REQUIRED', 'Attach your own media');
        }
        if (price == null || price < minPriceCents || price > maxPriceCents) {
          return _error(
            400,
            'PRICE_OUT_OF_RANGE',
            'Price must be between KSh 10 and KSh 50,000',
          );
        }
      }
      final m = _Message(
        'msg${++_seq + 100}',
        params['id']!,
        userId,
        text,
        mediaId: mediaId,
        priceCents: price,
      );
      _messages.add(m);
      return (201, _messageJson(m, userId));
    }),
    'GET /users/me/blocks': (req, _) => _signedIn(
      req,
      (userId) => (
        200,
        [
          for (final b in _blocks.where((b) => b.startsWith('$userId|')))
            _person(b.split('|')[1]),
        ],
      ),
    ),
    'POST /users/{id}/block': (req, params) => _signedIn(req, (userId) {
      _blocks.add('$userId|${params['id']}');
      return (204, null);
    }),
    'DELETE /users/{id}/block': (req, params) => _signedIn(req, (userId) {
      _blocks.remove('$userId|${params['id']}');
      return (204, null);
    }),
    'POST /reports': (req, _) => _signedIn(req, (userId) {
      final body = req.data as Map;
      const types = {'user', 'post', 'message'};
      if (!types.contains(body['targetType']) ||
          body['targetId'] == null ||
          body['reason'] == null) {
        return _error(400, 'INVALID_REPORT', 'Choose a reason');
      }
      final report = {
        'caseId': 'CASE-${1001 + reports.length}',
        'reporterId': userId,
        'targetType': body['targetType'],
        'targetId': body['targetId'],
        'reason': body['reason'],
        'details': body['details'],
        'priority': urgentReasons.contains(body['reason'])
            ? 'urgent'
            : 'normal',
        'status': 'open',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      };
      reports.add(report);
      return (
        201,
        {
          'caseId': report['caseId'],
          'priority': report['priority'],
          'status': 'open',
        },
      );
    }),
  };
}

final fakeMessagingDb = FakeMessagingDb();
