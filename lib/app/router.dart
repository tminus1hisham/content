import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/prefs.dart';
import '../features/disguise/disguise_controller.dart';
import '../features/disguise/lock_gate.dart';
import '../features/profile/profile_screen.dart';
import '../features/settings/appearance_screen.dart';
import '../features/settings/disguise_screen.dart';
import '../features/settings/security_screen.dart';
import '../features/settings/settings_screen.dart';

enum UserRole { fan, creator }

const roleKey = 'app.role';

class RoleController extends Notifier<UserRole> {
  @override
  UserRole build() =>
      UserRole.values.asNameMap()[ref
          .watch(sharedPreferencesProvider)
          .get(roleKey)] ??
      UserRole.fan;

  Future<void> set(UserRole role) async {
    state = role;
    await ref.read(sharedPreferencesProvider).setString(roleKey, role.name);
  }
}

final roleProvider = NotifierProvider<RoleController, UserRole>(
  RoleController.new,
);

class _Tab {
  const _Tab(this.label, this.path, this.icon);
  final String label;
  final String path;
  final IconData icon;
}

const _profileTab = _Tab('Profile', '/profile', Icons.person_outline);

const _fanTabs = [
  _Tab('Discover', '/discover', Icons.explore_outlined),
  _Tab('Following', '/following', Icons.favorite_outline),
  _Tab('Live', '/live', Icons.live_tv_outlined),
  _Tab('Inbox', '/inbox', Icons.mail_outline),
  _profileTab,
];

const _creatorTabs = [
  _Tab('Home', '/home', Icons.dashboard_outlined),
  _Tab('Studio', '/studio', Icons.video_library_outlined),
  _Tab('Go live', '/go-live', Icons.videocam_outlined),
  _Tab('Messages', '/messages', Icons.chat_bubble_outline),
  _profileTab,
];

/// Rebuilt when the role changes, which swaps the bottom-nav shell. Lock and
/// disguise changes only re-run the redirect (see [lockRedirect]).
final routerProvider = Provider<GoRouter>((ref) {
  final tabs = ref.watch(roleProvider) == UserRole.fan
      ? _fanTabs
      : _creatorTabs;
  final home = tabs.first.path;
  final refresh = ValueNotifier(0);
  ref.listen(lockProvider, (_, _) => refresh.value++);
  ref.listen(disguiseProvider, (_, _) => refresh.value++);
  final router = GoRouter(
    initialLocation: home,
    refreshListenable: refresh,
    redirect: (_, state) => lockRedirect(ref, state.matchedLocation, home),
    routes: [
      GoRoute(path: '/lock', builder: (_, _) => const LockScreen()),
      GoRoute(path: '/decoy', builder: (_, _) => const DecoyScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _Shell(shell: shell, tabs: tabs),
        branches: [
          for (final tab in tabs)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: tab.path,
                  builder: (_, _) => tab == _profileTab
                      ? const ProfileScreen()
                      : PlaceholderScreen(title: tab.label),
                ),
              ],
            ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'appearance',
            builder: (_, _) => const AppearanceScreen(),
          ),
          GoRoute(path: 'disguise', builder: (_, _) => const DisguiseScreen()),
          GoRoute(path: 'security', builder: (_, _) => const SecurityScreen()),
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

class _Shell extends StatelessWidget {
  const _Shell({required this.shell, required this.tabs});
  final StatefulNavigationShell shell;
  final List<_Tab> tabs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          for (final tab in tabs)
            NavigationDestination(icon: Icon(tab.icon), label: tab.label),
        ],
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(child: Text('Coming soon')),
    );
  }
}
