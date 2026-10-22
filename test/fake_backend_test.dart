import 'package:content/core/fake_backend.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final dio = Dio(BaseOptions(baseUrl: 'https://fake.local/api/v1'))
    ..interceptors.add(FakeBackendInterceptor(latency: Duration.zero));

  test('GET /health returns 200 ok', () async {
    final response = await dio.get<Object?>('/health');
    expect(response.statusCode, 200);
    expect(response.data, {'status': 'ok'});
  });

  test('unknown path returns 404 NOT_FOUND', () async {
    final error = await dio
        .get<Object?>('/nope')
        .then<DioException?>(
          (_) => null,
          onError: (Object e) => e as DioException,
        );
    expect(error?.response?.statusCode, 404);
    expect((error?.response?.data as Map)['code'], 'NOT_FOUND');
  });

  test('path params are matched by segment', () async {
    fakeRoutes['GET /things/{id}'] = (_, params) => (200, {'id': params['id']});
    addTearDown(() => fakeRoutes.remove('GET /things/{id}'));
    expect((await dio.get<Object?>('/things/42')).data, {'id': '42'});
    expect(dio.get<Object?>('/things/42/extra'), throwsA(isA<DioException>()));
  });
}
