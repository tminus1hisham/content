import 'package:dio/dio.dart';

import '../features/auth/fake_auth.dart';

/// Returns `(statusCode, jsonBody)`. [params] holds `{id}`-style path segments.
typedef FakeHandler =
    (int, Object?) Function(RequestOptions request, Map<String, String> params);

/// Route table keyed by 'METHOD /path' (path relative to the API base, e.g. `/creators/{id}`).
/// Later milestones add their routes here.
final Map<String, FakeHandler> fakeRoutes = {
  'GET /health': (_, _) => (200, {'status': 'ok'}),
  ...fakeAuthDb.routes,
};

/// Answers requests from [fakeRoutes] instead of the network.
/// Simulated network delay; tests set it to zero.
Duration fakeLatency = const Duration(milliseconds: 150);

class FakeBackendInterceptor extends Interceptor {
  FakeBackendInterceptor({Duration? latency})
    : latency = latency ?? fakeLatency;

  final Duration latency;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final basePath = Uri.parse(options.baseUrl).path;
    var path = options.uri.path;
    if (basePath.isNotEmpty && path.startsWith(basePath)) {
      path = path.substring(basePath.length);
    }

    var status = 404;
    Object? body = {
      'code': 'NOT_FOUND',
      'message': 'No fake route for ${options.method} $path',
    };
    for (final MapEntry(:key, :value) in fakeRoutes.entries) {
      final space = key.indexOf(' ');
      if (key.substring(0, space) != options.method) continue;
      final params = _match(key.substring(space + 1), path);
      if (params == null) continue;
      (status, body) = value(options, params);
      break;
    }

    final response = Response<Object?>(
      requestOptions: options,
      statusCode: status,
      data: body,
    );
    if (options.validateStatus(status)) {
      handler.resolve(response, true);
    } else {
      handler.reject(
        DioException.badResponse(
          statusCode: status,
          requestOptions: options,
          response: response,
        ),
        true,
      );
    }
  }

  static Map<String, String>? _match(String pattern, String path) {
    final want = pattern.split('/');
    final got = path.split('/');
    if (want.length != got.length) return null;
    final params = <String, String>{};
    for (var i = 0; i < want.length; i++) {
      final segment = want[i];
      if (segment.startsWith('{') && segment.endsWith('}')) {
        params[segment.substring(1, segment.length - 1)] = got[i];
      } else if (segment != got[i]) {
        return null;
      }
    }
    return params;
  }
}
