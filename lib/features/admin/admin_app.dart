import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../app/theme_controller.dart';
import '../../core/api_client.dart';
import 'admin_screens.dart';
import 'fake_admin.dart';

typedef Json = Map<String, dynamic>;

class AdminState {
  const AdminState({this.loading = false, this.staff});
  final bool loading;
  final Json? staff;

  bool can(String permission) =>
      (staff?['permissions'] as List?)?.contains(permission) ?? false;
}

/// Staff session (IT.md ADM1): password + MFA, signed out after
/// [idleTimeout] without interaction.
class AdminAuth extends Notifier<AdminState> {
  static const idleTimeout = Duration(minutes: 15);
  Timer? _idle;

  @override
  AdminState build() {
    ref.listen(sessionExpiredProvider, (_, _) => _signedOut());
    ref.onDispose(() => _idle?.cancel());
    _restore();
    return const AdminState(loading: true);
  }

  Future<void> _restore() async {
    if (await secureStorage.read(key: accessTokenKey) == null) {
      state = const AdminState();
      return;
    }
    try {
      final me = await ref.read(dioProvider).get<Json>('/admin/me');
      state = AdminState(staff: me.data);
      touch();
    } on DioException {
      state = const AdminState();
    }
  }

  Future<void> login(String email, String password, String mfaCode) async {
    final session =
        (await ref
                .read(dioProvider)
                .post<Json>(
                  '/admin/auth/login',
                  data: {
                    'email': email,
                    'password': password,
                    'mfaCode': mfaCode,
                  },
                ))
            .data!;
    await saveTokens(session);
    state = AdminState(staff: session['staff'] as Json);
    touch();
  }

  /// Restarts the idle timer; called on every pointer event.
  void touch() {
    _idle?.cancel();
    if (state.staff != null) _idle = Timer(idleTimeout, logout);
  }

  Future<void> logout() async {
    await clearTokens();
    _signedOut();
  }

  void _signedOut() {
    _idle?.cancel();
    state = const AdminState();
  }
}

final adminAuthProvider = NotifierProvider<AdminAuth, AdminState>(
  AdminAuth.new,
);

class _Section {
  const _Section(this.path, this.label, this.icon, this.permission, this.page);
  final String path;
  final String label;
  final IconData icon;
  final String? permission;
  final Widget Function() page;
}

final _sections = [
  _Section(
    '/',
    'Dashboard',
    Icons.dashboard_outlined,
    null,
    AdminDashboard.new,
  ),
  _Section(
    '/creators',
    'Creators',
    Icons.verified_user_outlined,
    Perm.creatorReview,
    CreatorReviewScreen.new,
  ),
  _Section(
    '/moderation',
    'Moderation',
    Icons.shield_outlined,
    Perm.moderationRead,
    ModerationScreen.new,
  ),
  _Section(
    '/finance',
    'Payouts',
    Icons.payments_outlined,
    Perm.payoutApprove,
    FinanceScreen.new,
  ),
  _Section(
    '/contracts',
    'Contracts',
    Icons.description_outlined,
    Perm.contracts,
    ContractsScreen.new,
  ),
  _Section('/config', 'Settings', Icons.tune, null, ConfigScreen.new),
  _Section('/audit', 'Audit log', Icons.history, Perm.audit, AuditScreen.new),
  _Section(
    '/staff',
    'Staff',
    Icons.badge_outlined,
    Perm.roles,
    StaffScreen.new,
  ),
];

final adminRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(adminAuthProvider, (_, _) => refresh.value++);
  final router = GoRouter(
    refreshListenable: refresh,
    redirect: (_, state) {
      final auth = ref.read(adminAuthProvider);
      final location = state.matchedLocation;
      if (auth.loading) return null;
      if (auth.staff == null) return location == '/login' ? null : '/login';
      if (location == '/login') return '/';
      // Deny by default: hidden sections are also refused by the API.
      final section = _sections.where((s) => s.path == location).firstOrNull;
      if (section?.permission != null && !auth.can(section!.permission!)) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const AdminLoginScreen()),
      ShellRoute(
        builder: (context, state, child) =>
            _AdminShell(location: state.matchedLocation, child: child),
        routes: [
          for (final s in _sections)
            GoRoute(path: s.path, builder: (_, _) => s.page()),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeControllerProvider);
    final accent = accents[theme.accentIndex].color;
    final auth = ref.watch(adminAuthProvider);
    return Listener(
      onPointerDown: (_) => ref.read(adminAuthProvider.notifier).touch(),
      child: MaterialApp.router(
        title: 'Content Admin',
        theme: buildTheme(accent, Brightness.light),
        darkTheme: buildTheme(accent, Brightness.dark),
        themeMode: theme.themeMode,
        routerConfig: ref.watch(adminRouterProvider),
        builder: (context, child) => auth.loading
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : child!,
      ),
    );
  }
}

class _AdminShell extends ConsumerWidget {
  const _AdminShell({required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(adminAuthProvider);
    final visible = [
      for (final s in _sections)
        if (s.permission == null || auth.can(s.permission!)) s,
    ];
    final index = visible.indexWhere((s) => s.path == location);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(
        title: Text(visible[index < 0 ? 0 : index].label),
        actions: [
          Center(
            child: Text(
              '${auth.staff?['name']} · ${auth.staff?['role']}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => ref.read(adminAuthProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            extended: wide,
            labelType: wide ? null : NavigationRailLabelType.none,
            selectedIndex: index < 0 ? 0 : index,
            onDestinationSelected: (i) => context.go(visible[i].path),
            destinations: [
              for (final s in visible)
                NavigationRailDestination(
                  icon: Icon(s.icon),
                  label: Text(s.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
