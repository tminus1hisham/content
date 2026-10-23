import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/prefs.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/auth_screens.dart';
import '../features/disguise/disguise_controller.dart';
import '../features/disguise/lock_gate.dart';
import '../features/commerce/commerce_screens.dart';
import '../features/content/discover_screens.dart';
import '../features/content/studio_screens.dart';
import '../features/live/live_screens.dart';
import '../features/messages/messages_screens.dart';
import '../features/onboarding/onboarding_screens.dart';
import '../features/profile/profile_screen.dart';
import '../features/settings/appearance_screen.dart';
import '../features/settings/disguise_screen.dart';
import '../features/settings/privacy_screen.dart';
import '../features/settings/security_screen.dart';
import '../features/settings/settings_screen.dart';
import 'ui.dart';

enum UserRole { fan, creator }

const roleKey = 'app.role';

class RoleController extends Notifier<UserRole> {
  /// The stored view, limited to roles the signed-in account actually has.
  @override
  UserRole build() {
    final roles = ref.watch(authProvider).user?.roles ?? const <String>{};
    final stored =
        UserRole.values.asNameMap()[ref
            .watch(sharedPreferencesProvider)
            .get(roleKey)] ??
        UserRole.fan;
    if (roles.isEmpty || roles.contains(stored.name)) return stored;
    return roles.contains('fan') ? UserRole.fan : UserRole.creator;
  }

  Future<void> set(UserRole role) async {
    state = role;
    await ref.read(sharedPreferencesProvider).setString(roleKey, role.name);
  }
}

final roleProvider = NotifierProvider<RoleController, UserRole>(
  RoleController.new,
);

class _Tab {
  const _Tab(this.label, this.path, this.icon, this.selectedIcon);
  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
}

const _profileTab = _Tab(
  'Profile',
  '/profile',
  Icons.person_outline,
  Icons.person,
);

const _fanTabs = [
  _Tab('Discover', '/discover', Icons.explore_outlined, Icons.explore),
  _Tab('Following', '/following', Icons.favorite_outline, Icons.favorite),
  _Tab('Live', '/live', Icons.live_tv_outlined, Icons.live_tv),
  _Tab('Inbox', '/inbox', Icons.mail_outline, Icons.mail),
  _profileTab,
];

const _creatorTabs = [
  _Tab('Home', '/home', Icons.dashboard_outlined, Icons.dashboard),
  _Tab('Studio', '/studio', Icons.video_library_outlined, Icons.video_library),
  _Tab('Go live', '/go-live', Icons.videocam_outlined, Icons.videocam),
  _Tab('Messages', '/messages', Icons.chat_bubble_outline, Icons.chat_bubble),
  _profileTab,
];

/// Tab bodies built so far; other tabs show [PlaceholderScreen].
final _tabScreens = <String, Widget Function()>{
  '/profile': ProfileScreen.new,
  '/home': CreatorHomeScreen.new,
  '/discover': DiscoverScreen.new,
  '/following': FollowingScreen.new,
  '/studio': StudioScreen.new,
  '/inbox': InboxScreen.new,
  '/messages': InboxScreen.new,
  '/live': LiveNowScreen.new,
  '/go-live': GoLiveScreen.new,
};

/// Tabs whose screens pad their own scroll content for the frosted tab bar;
/// the rest are kept above it until they are revamped.
const _edgeToEdge = {'/discover', '/following'};

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
  ref.listen(authProvider, (_, _) => refresh.value++);
  ref.listen(ageGateProvider, (_, _) => refresh.value++);
  final router = GoRouter(
    initialLocation: home,
    refreshListenable: refresh,
    redirect: (_, state) {
      final location = state.matchedLocation;
      final locked = lockRedirect(ref, location, home);
      if (locked != null || location == '/lock' || location == '/decoy') {
        return locked;
      }
      return authRedirect(ref, location, home);
    },
    routes: [
      GoRoute(path: '/lock', builder: (_, _) => const LockScreen()),
      GoRoute(path: '/decoy', builder: (_, _) => const DecoyScreen()),
      GoRoute(path: '/age', builder: (_, _) => const AgeGateScreen()),
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/verify',
        builder: (_, state) => VerifyScreen(args: state.extra as VerifyArgs?),
      ),
      GoRoute(path: '/role', builder: (_, _) => const RoleScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _Shell(shell: shell, tabs: tabs),
        branches: [
          for (final tab in tabs)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: tab.path,
                  builder: (_, _) {
                    final screen =
                        _tabScreens[tab.path]?.call() ??
                        PlaceholderScreen(title: tab.label);
                    return _edgeToEdge.contains(tab.path)
                        ? screen
                        : SafeArea(
                            top: false,
                            left: false,
                            right: false,
                            child: screen,
                          );
                  },
                ),
              ],
            ),
        ],
      ),
      GoRoute(
        path: '/c/:handle',
        builder: (_, state) => CreatorPage(
          handle: state.pathParameters['handle']!,
          heroTag: state.extra is String ? state.extra! as String : null,
        ),
      ),
      GoRoute(
        path: '/p/:id',
        builder: (_, state) =>
            PostDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(path: '/studio/new', builder: (_, _) => const ComposerScreen()),
      GoRoute(
        path: '/checkout/:type/:id',
        builder: (_, state) => CheckoutScreen(
          type: state.pathParameters['type']!,
          itemId: state.pathParameters['id']!,
          amountCents: int.tryParse(state.uri.queryParameters['amount'] ?? ''),
        ),
      ),
      GoRoute(path: '/library', builder: (_, _) => const LibraryScreen()),
      GoRoute(
        path: '/live/:id',
        builder: (_, state) => LiveRoomScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (_, state) => ChatScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/earnings',
        builder: (_, _) => const EarningsScreen(),
        routes: [
          GoRoute(
            path: 'payout',
            builder: (_, _) => const PayoutRequestScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const OnboardingScreen(),
        routes: [
          GoRoute(path: 'identity', builder: (_, _) => const IdentityScreen()),
          GoRoute(
            path: 'profile',
            builder: (_, _) => const CreatorProfileScreen(),
          ),
          GoRoute(path: 'contract', builder: (_, _) => const ContractScreen()),
          GoRoute(path: 'payout', builder: (_, _) => const PayoutSetupScreen()),
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
          GoRoute(path: 'privacy', builder: (_, _) => const PrivacyScreen()),
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
      // Content scrolls under the frosted bar.
      extendBody: true,
      body: shell,
      bottomNavigationBar: Glass(
        color: Colors.transparent,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) {
            if (i != shell.currentIndex) HapticFeedback.selectionClick();
            // A toast from one tab shouldn't float over the next tab's controls.
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            shell.goBranch(i, initialLocation: i == shell.currentIndex);
          },
          destinations: [
            for (final tab in tabs)
              NavigationDestination(
                icon: Icon(tab.icon),
                selectedIcon: Icon(tab.selectedIcon),
                label: tab.label,
              ),
          ],
        ),
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
