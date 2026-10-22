import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'fake_backend.dart';

const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
const accessTokenKey = 'auth.accessToken';

/// Dio for the `/api/v1` REST API. Without `--dart-define=API_BASE_URL=...`
/// requests are answered by [FakeBackendInterceptor].
final dioProvider = Provider<Dio>((ref) {
  const storage = FlutterSecureStorage();
  final dio = Dio(
    BaseOptions(
      baseUrl:
          '${_apiBaseUrl.isEmpty ? 'https://fake.local' : _apiBaseUrl.replaceFirst(RegExp(r'/+$'), '')}/api/v1',
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.read(key: accessTokenKey);
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
    ),
  );
  if (_apiBaseUrl.isEmpty) dio.interceptors.add(FakeBackendInterceptor());
  ref.onDispose(dio.close);
  return dio;
});
