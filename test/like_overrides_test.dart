import 'package:content/features/auth/auth_controller.dart';
import 'package:content/features/content/content_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth extends AuthController {
  @override
  AuthState build() => const AuthState(
    AuthStatus.signedIn,
    AuthUser(id: 'u1', identifier: 'fan@demo.ke', roles: {'fan'}),
  );

  void become(AuthUser? user) => state = AuthState(
    user == null ? AuthStatus.signedOut : AuthStatus.signedIn,
    user,
  );
}

void main() {
  test('like overrides reset when the signed-in account changes', () {
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith(_Auth.new)],
    );
    addTearDown(container.dispose);
    final likes = container.read(likeOverridesProvider.notifier);
    likes.state = {'p1': (likes: 5, liked: true)};

    (container.read(authProvider.notifier) as _Auth).become(
      const AuthUser(id: 'u9', identifier: 'other@demo.ke', roles: {'fan'}),
    );

    expect(container.read(likeOverridesProvider), isEmpty);
  });
}
