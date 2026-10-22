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

  void reset() {
    _users.clear();
    _verifications.clear();
    _access.clear();
    _refresh.clear();
    _users['fan@demo.ke'] = _User('u1', 'fan@demo.ke', 'password123', [
      'fan',
    ], true);
    _users['creator@demo.ke'] = _User('u2', 'creator@demo.ke', 'password123', [
      'fan',
      'creator',
    ], true);
  }

  /// A signed-in session for a seeded user, for tests and demos.
  Map<String, Object?> sessionFor(String identifier) =>
      _session(_users[identifier]!);

  /// Makes every issued access token invalid, as if they had expired.
  void expireAccessTokens() => _access.clear();

  _User? _byId(String id) => _users.values.where((u) => u.id == id).firstOrNull;

  _User? _caller(RequestOptions request) {
    final header = request.headers['Authorization'] as String?;
    final userId = _access[header?.replaceFirst('Bearer ', '')];
    return userId == null ? null : _byId(userId);
  }

  Map<String, Object?> _session(_User user) {
    final access = 'fake-access-${user.id}-${++_seq}';
    final refresh = 'fake-refresh-${user.id}-$_seq';
    _access[access] = user.id;
    _refresh[refresh] = user.id;
    return {
      'accessToken': access,
      'refreshToken': refresh,
      'user': user.toJson(),
    };
  }

  static const _unauthorized = (
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
          'u${_users.length + 1}',
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
      return (200, _session(user));
    },
    'POST /auth/refresh': (req, _) {
      final userId = _refresh.remove((req.data as Map)['refreshToken']);
      final user = userId == null ? null : _byId(userId);
      return user == null ? _unauthorized : (200, _session(user));
    },
    'POST /auth/logout': (req, _) {
      _refresh.remove((req.data as Map?)?['refreshToken']);
      return (204, null);
    },
    'GET /users/me': (req, _) {
      final user = _caller(req);
      return user == null ? _unauthorized : (200, user.toJson());
    },
    'PUT /users/me/roles': (req, _) {
      final user = _caller(req);
      if (user == null) return _unauthorized;
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
