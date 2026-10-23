import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'fake_backend.dart';

const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

/// True without `--dart-define=API_BASE_URL=...`: requests are answered by
/// [FakeBackendInterceptor].
const usingFakeBackend = _apiBaseUrl == '';

const accessTokenKey = 'auth.accessToken';
const refreshTokenKey = 'auth.refreshToken';
const secureStorage = FlutterSecureStorage();

Dio _bareDio() {
  final dio = Dio(
    BaseOptions(
      baseUrl:
          '${usingFakeBackend ? 'https://fake.local' : _apiBaseUrl.replaceFirst(RegExp(r'/+$'), '')}/api/v1',
      // Labels the session in Settings > Privacy > Active sessions.
      headers: {
        'X-Client-Device': kIsWeb
            ? 'Web browser'
            : '${defaultTargetPlatform.name} app',
      },
    ),
  );
  if (usingFakeBackend) dio.interceptors.add(FakeBackendInterceptor());
  return dio;
}

/// For storage upload URLs: no API base and no Authorization header, which
/// must never be sent to the storage provider.
final uploadDioProvider = Provider<Dio>((ref) {
  final dio = _bareDio();
  ref.onDispose(dio.close);
  return dio;
});

/// Bumped when the refresh token is rejected; AuthController signs out.
final sessionExpiredProvider = StateProvider<int>((ref) => 0);

/// Dio for the `/api/v1` REST API. Attaches the access token and, on a 401,
/// refreshes once and retries.
final dioProvider = Provider<Dio>((ref) {
  final dio = _bareDio();
  final retry = _bareDio();
  dio.interceptors.insert(
    0,
    QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await secureStorage.read(key: accessTokenKey);
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (error, handler) async {
        final request = error.requestOptions;
        if (error.response?.statusCode != 401 ||
            request.path.startsWith('/auth/') ||
            request.extra['retried'] == true) {
          return handler.next(error);
        }
        final refreshToken = await secureStorage.read(key: refreshTokenKey);
        try {
          if (refreshToken == null) throw error;
          final session = (await retry.post<Map<String, dynamic>>(
            '/auth/refresh',
            data: {'refreshToken': refreshToken},
          )).data!;
          await saveTokens(session);
          request.headers['Authorization'] = 'Bearer ${session['accessToken']}';
          request.extra['retried'] = true;
          handler.resolve(await retry.fetch<Object?>(request));
        } on DioException catch (e) {
          if (e.requestOptions.path == '/auth/refresh' ||
              refreshToken == null) {
            await clearTokens();
            ref.read(sessionExpiredProvider.notifier).state++;
          }
          handler.next(e);
        }
      },
    ),
  );
  ref.onDispose(() {
    dio.close();
    retry.close();
  });
  return dio;
});

Future<void> saveTokens(Map<String, dynamic> session) async {
  await secureStorage.write(
    key: accessTokenKey,
    value: session['accessToken'] as String,
  );
  await secureStorage.write(
    key: refreshTokenKey,
    value: session['refreshToken'] as String,
  );
}

Future<void> clearTokens() async {
  await secureStorage.delete(key: accessTokenKey);
  await secureStorage.delete(key: refreshTokenKey);
}

/// The server's `message` for an API error, else a generic one.
String apiErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) return data['message'];
    if (error.response == null) return 'No connection. Try again.';
  }
  return 'Something went wrong. Try again.';
}

/// The server's error `code` (e.g. `INVALID_CODE`), if any.
String? apiErrorCode(Object error) {
  final data = error is DioException ? error.response?.data : null;
  return data is Map ? data['code'] as String? : null;
}
