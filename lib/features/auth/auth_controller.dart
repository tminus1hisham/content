import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/prefs.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.identifier,
    required this.roles,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    identifier: json['identifier'] as String,
    roles: (json['roles'] as List).cast<String>().toSet(),
  );

  final String id;
  final String identifier;
  final Set<String> roles;

  bool get isCreator => roles.contains('creator');
  bool get isFan => roles.contains('fan');
}

enum AuthStatus { unknown, signedOut, signedIn }

class AuthState {
  const AuthState(this.status, [this.user]);
  final AuthStatus status;
  final AuthUser? user;
}

class AuthController extends Notifier<AuthState> {
  Dio get _dio => ref.read(dioProvider);

  @override
  AuthState build() {
    ref.listen(
      sessionExpiredProvider,
      (_, _) => state = const AuthState(AuthStatus.signedOut),
    );
    _restore();
    return const AuthState(AuthStatus.unknown);
  }

  Future<void> _restore() async {
    if (await secureStorage.read(key: accessTokenKey) == null) {
      state = const AuthState(AuthStatus.signedOut);
      return;
    }
    try {
      final me = await _dio.get<Map<String, dynamic>>('/users/me');
      state = AuthState(AuthStatus.signedIn, AuthUser.fromJson(me.data!));
    } on DioException {
      // Expired session or offline: show sign-in; tokens are kept unless the
      // server rejected the refresh (see dioProvider).
      state = const AuthState(AuthStatus.signedOut);
    }
  }

  /// Returns the verification id for [verify].
  Future<String> register({
    required String identifier,
    required String password,
    required String country,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'identifier': identifier,
        'password': password,
        'country': country,
        'acceptedTerms': true,
      },
    );
    return response.data!['verificationId'] as String;
  }

  Future<void> verify(String verificationId, String code) => _dio.post<void>(
    '/auth/verify-contact',
    data: {'verificationId': verificationId, 'code': code},
  );

  Future<void> resend(String verificationId) => _dio.post<void>(
    '/auth/resend-verification',
    data: {'verificationId': verificationId},
  );

  /// Throws a DioException with code `CONTACT_NOT_VERIFIED` (and a
  /// `verificationId`) when the contact still needs its OTP.
  Future<void> login(String identifier, String password) async {
    final session = (await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'identifier': identifier, 'password': password},
    )).data!;
    await saveTokens(session);
    state = AuthState(
      AuthStatus.signedIn,
      AuthUser.fromJson(session['user'] as Map<String, dynamic>),
    );
  }

  Future<void> setRoles(Set<String> roles) async {
    final me = await _dio.put<Map<String, dynamic>>(
      '/users/me/roles',
      data: {'roles': roles.toList()},
    );
    state = AuthState(AuthStatus.signedIn, AuthUser.fromJson(me.data!));
  }

  Future<void> logout() async {
    final refreshToken = await secureStorage.read(key: refreshTokenKey);
    try {
      await _dio.post<void>(
        '/auth/logout',
        data: {'refreshToken': refreshToken},
      );
    } on DioException {
      // Signing out locally must work offline too.
    }
    await clearTokens();
    state = const AuthState(AuthStatus.signedOut);
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Email (lower-cased) or phone in E.164. Kenyan local numbers such as
/// `0712 345 678` become `+254712345678`. Null when invalid.
String? normalizeIdentifier(String raw) {
  final value = raw.trim();
  if (value.contains('@')) {
    final email = value.toLowerCase();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) ? email : null;
  }
  final phone = value.replaceAll(RegExp(r'[\s\-()]'), '');
  final kenyan = RegExp(r'^(?:0|\+?254)([17]\d{8})$').firstMatch(phone);
  if (kenyan != null) return '+254${kenyan[1]}';
  return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone) ? phone : null;
}

const ageConfirmedKey = 'age.confirmed';

/// Self-declared date of birth gate shown before anything else (IT.md F1).
/// Creators also pass provider ID checks during onboarding.
class AgeGateController extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).get(ageConfirmedKey) == true;

  Future<void> confirm() async {
    state = true;
    await ref.read(sharedPreferencesProvider).setBool(ageConfirmedKey, true);
  }
}

final ageGateProvider = NotifierProvider<AgeGateController, bool>(
  AgeGateController.new,
);

bool isAdult(DateTime birthDate, DateTime now) {
  var age = now.year - birthDate.year;
  if (now.month < birthDate.month ||
      (now.month == birthDate.month && now.day < birthDate.day)) {
    age--;
  }
  return age >= 18;
}

const _signedOutRoutes = {'/welcome', '/login', '/register', '/verify'};
const _entryRoutes = {'/age', '/splash', '/role', ..._signedOutRoutes};

/// Runs after the lock gate: 18+ gate, then sign-in, then role selection.
String? authRedirect(Ref ref, String location, String home) {
  final auth = ref.read(authProvider);
  final String? gate;
  if (!ref.read(ageGateProvider)) {
    gate = '/age';
  } else if (auth.status == AuthStatus.unknown) {
    gate = '/splash';
  } else if (auth.status == AuthStatus.signedOut) {
    if (_signedOutRoutes.contains(location)) return null;
    gate = '/welcome';
  } else if (auth.user!.roles.isEmpty) {
    gate = '/role';
  } else {
    gate = null;
  }
  if (gate != null) return location == gate ? null : gate;
  return _entryRoutes.contains(location) ? home : null;
}
