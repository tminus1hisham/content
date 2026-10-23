import 'package:dio/dio.dart';

import '../../core/fake_backend.dart';

/// In-memory stand-in for the Spring auth endpoints (IT.md §9.2 plus the
/// `/users/me` additions in docs/api-additions.md). The OTP is always
/// [fakeOtp].
const fakeOtp = '123456';

class _User {
  _User(this.id, this.identifier, this.password, this.roles, this.verified);
  final String id;
  final String identifier;
  final String password;
  List<String> roles;
  bool verified;

  Map<String, Object?> toJson() => {
    'id': id,
    'identifier': identifier,
    'roles': roles,
    'verified': verified,
  };
}

class FakeAuthDb {
  final _users = <String, _User>{}; // by identifier
  final _verifications = <String, String>{}; // verificationId -> identifier
  final _access = <String, String>{}; // token -> userId
  final _refresh = <String, String>{}; // token -> userId
  var _seq = 0;

  FakeAuthDb() {
    reset();
  }

  /// token (access or refresh) -> session id, and session id -> details.
  final _sessionOf = <String, String>{};
  final _sessions = <String, Map<String, Object?>>{};
  final _preferences = <String, Map<String, Object?>>{};
  final deletionRequests = <String, DateTime>{};

  void reset() {
    _users.clear();
    _verifications.clear();
    _access.clear();
    _refresh.clear();
    _sessionOf.clear();
    _sessions.clear();
    _preferences.clear();
    deletionRequests.clear();
    _users['fan@demo.ke'] = _User('u1', 'fan@demo.ke', 'password123', [
      'fan',
    ], true);
    _users['creator@demo.ke'] = _User('u2', 'creator@demo.ke', 'password123', [
      'fan',
      'creator',
    ], true);
    // A creator who has not started onboarding yet.
    _users['new@demo.ke'] = _User('u3', 'new@demo.ke', 'password123', [
      'creator',
    ], true);
    // A creator waiting for staff review (admin app demo).
    _users['pending@demo.ke'] = _User('u5', 'pending@demo.ke', 'password123', [
      'creator',
    ], true);
  }

  /// A signed-in session for a seeded user, for tests and demos.
  Map<String, Object?> sessionFor(String identifier) =>
      _session(_users[identifier]!);

  /// Makes every issued access token invalid, as if they had expired.
  void expireAccessTokens() => _access.clear();

  _User? _byId(String id) => _users.values.where((u) => u.id == id).firstOrNull;

  static String? _bearer(RequestOptions request) =>
      (request.headers['Authorization'] as String?)?.replaceFirst(
        'Bearer ',
        '',
      );

  void _endSession(String sid) {
    _sessions.remove(sid);
    final tokens = [
      for (final MapEntry(:key, :value) in _sessionOf.entries)
        if (value == sid) key,
    ];
    for (final token in tokens) {
      _sessionOf.remove(token);
      _access.remove(token);
      _refresh.remove(token);
    }
  }

  Map<String, Object?> _prefs(String userId) => _preferences.putIfAbsent(
    userId,
    () => {
      'discreetNotifications': true,
      'messageAlerts': true,
      'newContentAlerts': true,
    },
  );

  /// The signed-in user's id for a request, or null without a valid token.
  String? callerId(RequestOptions request) {
    final header = request.headers['Authorization'] as String?;
    return _access[header?.replaceFirst('Bearer ', '')];
  }

  _User? _caller(RequestOptions request) {
    final userId = callerId(request);
    return userId == null ? null : _byId(userId);
  }

  Map<String, Object?> _session(
    _User user, {
    String? sessionId,
    String? device,
  }) {
    final access = 'fake-access-${user.id}-${++_seq}';
    final refresh = 'fake-refresh-${user.id}-$_seq';
    _access[access] = user.id;
    _refresh[refresh] = user.id;
    final sid = sessionId ?? 'sess-$_seq';
    _sessions.putIfAbsent(
      sid,
      () => {
        'id': sid,
        'userId': user.id,
        'device': device ?? 'Unknown device',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
    _sessionOf[access] = sid;
    _sessionOf[refresh] = sid;
    return {
      'accessToken': access,
      'refreshToken': refresh,
      'user': user.toJson(),
    };
  }

  static const unauthorized = (
    401,
    {'code': 'UNAUTHORIZED', 'message': 'Sign in again'},
  );

  Map<String, FakeHandler> get routes => {
    'POST /auth/register': (req, _) {
      final body = req.data as Map;
      final identifier = body['identifier'] as String;
      // Same response whether or not the identifier is taken (IT.md A2).
      _users.putIfAbsent(
        identifier,
        () => _User(
          'u-${++_seq}', // can't collide with the seeded u1..u5
          identifier,
          body['password'] as String,
          [],
          false,
        ),
      );
      final verificationId = 'v${++_seq}';
      _verifications[verificationId] = identifier;
      return (201, {'verificationId': verificationId});
    },
    'POST /auth/verify-contact': (req, _) {
      final body = req.data as Map;
      final identifier = _verifications[body['verificationId']];
      if (identifier == null) {
        return (
          410,
          {'code': 'VERIFICATION_EXPIRED', 'message': 'Code expired'},
        );
      }
      if (body['code'] != fakeOtp) {
        return (400, {'code': 'INVALID_CODE', 'message': 'Wrong code'});
      }
      _verifications.remove(body['verificationId']);
      _users[identifier]!.verified = true;
      return (200, {'verified': true});
    },
    'POST /auth/resend-verification': (_, _) => (202, {'status': 'sent'}),
    'POST /auth/login': (req, _) {
      final body = req.data as Map;
      final user = _users[body['identifier']];
      if (user == null || user.password != body['password']) {
        return (
          401,
          {
            'code': 'INVALID_CREDENTIALS',
            'message': 'Wrong email/phone or password',
          },
        );
      }
      if (!user.verified) {
        final verificationId = 'v${++_seq}';
        _verifications[verificationId] = user.identifier;
        return (
          403,
          {
            'code': 'CONTACT_NOT_VERIFIED',
            'message': 'Verify your contact first',
            'verificationId': verificationId,
          },
        );
      }
      return (
        200,
        _session(user, device: req.headers['X-Client-Device'] as String?),
      );
    },
    'POST /auth/refresh': (req, _) {
      final token = (req.data as Map)['refreshToken'];
      final userId = _refresh.remove(token);
      final sid = _sessionOf.remove(token);
      final user = userId == null ? null : _byId(userId);
      return user == null
          ? unauthorized
          : (200, _session(user, sessionId: sid));
    },
    'POST /auth/logout': (req, _) {
      final sid = _sessionOf[(req.data as Map?)?['refreshToken']];
      if (sid != null) _endSession(sid);
      return (204, null);
    },
    'GET /auth/sessions': (req, _) {
      final userId = callerId(req);
      if (userId == null) return unauthorized;
      final current = _sessionOf[_bearer(req)];
      return (
        200,
        [
          for (final s in _sessions.values.where((s) => s['userId'] == userId))
            {...s, 'current': s['id'] == current}..remove('userId'),
        ],
      );
    },
    'DELETE /auth/sessions/{id}': (req, params) {
      final userId = callerId(req);
      if (userId == null) return unauthorized;
      if (_sessions[params['id']]?['userId'] != userId) {
        return (404, {'code': 'NOT_FOUND', 'message': 'No such session'});
      }
      _endSession(params['id']!);
      return (204, null);
    },
    'GET /users/me/preferences': (req, _) {
      final userId = callerId(req);
      if (userId == null) return unauthorized;
      return (200, _prefs(userId));
    },
    'PATCH /users/me/preferences': (req, _) {
      final userId = callerId(req);
      if (userId == null) return unauthorized;
      final prefs = _prefs(userId);
      for (final MapEntry(:key, :value) in (req.data as Map).entries) {
        if (prefs.containsKey(key) && value is bool) {
          prefs[key as String] = value;
        }
      }
      return (200, prefs);
    },
    'POST /users/me/data-export': (req, _) {
      final userId = callerId(req);
      if (userId == null) return unauthorized;
      return (
        202,
        {
          'reference': 'EXP-${userId.toUpperCase()}-${++_seq}',
          'status': 'requested',
        },
      );
    },
    // Closes the account after a 30-day grace period and signs out everywhere.
    'POST /users/me/deletion-request': (req, _) {
      final userId = callerId(req);
      if (userId == null) return unauthorized;
      if ((req.data as Map?)?['confirm'] != 'DELETE') {
        return (
          400,
          {
            'code': 'CONFIRMATION_REQUIRED',
            'message': 'Type DELETE to confirm',
          },
        );
      }
      final effectiveAt = DateTime.now().toUtc().add(const Duration(days: 30));
      deletionRequests[userId] = effectiveAt;
      for (final sid in [
        for (final s in _sessions.values)
          if (s['userId'] == userId) s['id'] as String,
      ]) {
        _endSession(sid);
      }
      return (
        202,
        {'status': 'scheduled', 'effectiveAt': effectiveAt.toIso8601String()},
      );
    },
    'GET /users/me': (req, _) {
      final user = _caller(req);
      return user == null ? unauthorized : (200, user.toJson());
    },
    'PUT /users/me/roles': (req, _) {
      final user = _caller(req);
      if (user == null) return unauthorized;
      final roles = ((req.data as Map)['roles'] as List).cast<String>();
      if (roles.isEmpty || roles.any((r) => r != 'fan' && r != 'creator')) {
        return (
          400,
          {'code': 'INVALID_ROLES', 'message': 'Pick fan or creator'},
        );
      }
      // Creator still has to pass onboarding (M4) before monetising.
      user.roles = roles;
      return (200, user.toJson());
    },
  };
}

final fakeAuthDb = FakeAuthDb();
