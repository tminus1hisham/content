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
import '../features/content/following_screen.dart';
import '../features/content/home_feed.dart';
import '../features/content/story_viewer.dart';
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
import 'motion.dart';

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

class NavTab {
  const NavTab(this.label, this.path, this.icon, this.selectedIcon);
  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
}

const _profileTab = NavTab(
  'Profile',
  '/profile',
  Icons.person_outline,
  Icons.person,
);

const _fanTabs = [
  NavTab('Discover', '/discover', Icons.explore_outlined, Icons.explore),
  NavTab('Following', '/following', Icons.favorite_outline, Icons.favorite),
  NavTab('Live', '/live', Icons.live_tv_outlined, Icons.live_tv),
  NavTab('Inbox', '/inbox', Icons.mail_outline, Icons.mail),
  _profileTab,
];

const _creatorTabs = [
  NavTab('Home', '/home', Icons.dashboard_outlined, Icons.dashboard),
  NavTab(
    'Studio',
    '/studio',
    Icons.video_library_outlined,
    Icons.video_library,
  ),
  NavTab('Go live', '/go-live', Icons.videocam_outlined, Icons.videocam),
  NavTab('Messages', '/messages', Icons.chat_bubble_outline, Icons.chat_bubble),
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
                  builder: (_, _) =>
                      _tabScreens[tab.path]?.call() ??
                      PlaceholderScreen(title: tab.label),
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
        path: '/search',
        builder: (_, state) => CreatorSearchScreen(
          initialCategory: state.uri.queryParameters['category'],
        ),
      ),
      GoRoute(
        path: '/stories/:creatorId',
        // Transparent, so a drag-to-dismiss reveals the home underneath.
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          opaque: false,
          transitionDuration: motion(context, mediumDuration),
          reverseTransitionDuration: motion(context, mediumDuration),
          child: StoryViewer(creatorId: state.pathParameters['creatorId']!),
          transitionsBuilder: (context, animation, _, child) {
            final t = animation.drive(CurveTween(curve: easeDrawer));
            final fade = FadeTransition(opacity: t, child: child);
            return MediaQuery.disableAnimationsOf(context)
                ? fade
                : ScaleTransition(
                    scale: t.drive(Tween(begin: 0.92, end: 1.0)),
                    child: fade,
                  );
          },
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
      GoRoute(
        path: '/library',
        builder: (_, state) => LibraryScreen(
          initialTab: state.uri.queryParameters['tab'] == 'subscriptions'
              ? 1
              : 0,
        ),
      ),
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

class _Shell extends ConsumerWidget {
  const _Shell({required this.shell, required this.tabs});
  final StatefulNavigationShell shell;
  final List<NavTab> tabs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      // Content scrolls under the floating bar.
      extendBody: true,
      body: shell,
      bottomNavigationBar: AppNavBar(
        tabs: tabs,
        selectedIndex: shell.currentIndex,
        onSelected: (i) {
          if (i != shell.currentIndex) HapticFeedback.selectionClick();
          // Re-tapping the home tab scrolls the feed back to the top.
          if (i == 0 && i == shell.currentIndex) {
            ref.read(homeScrollTopProvider.notifier).state++;
          }
          // A toast from one tab shouldn't float over the next tab's controls.
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          shell.goBranch(i, initialLocation: i == shell.currentIndex);
        },
      ),
    );
  }
}

/// Floating card bar: the selected tab sits in a filled ink circle.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });
  final List<NavTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const radius = BorderRadius.all(Radius.circular(26));
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            // The shadow is lost on a dark page, so the edge carries it there.
            side: scheme.brightness == Brightness.dark
                ? BorderSide(color: scheme.outlineVariant)
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                for (final (i, tab) in tabs.indexed)
                  Expanded(
                    child: _NavItem(
                      tab: tab,
                      selected: i == selectedIndex,
                      onTap: () => onSelected(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });
  final NavTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final duration = motion(context, shortDuration);
    return Semantics(
      button: true,
      selected: selected,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: duration,
                curve: easeOut,
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? scheme.onSurface : Colors.transparent,
                ),
                child: Icon(
                  selected ? tab.selectedIcon : tab.icon,
                  size: selected ? 22 : 24,
                  color: selected ? scheme.surface : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: duration,
                curve: easeOut,
                style: theme.textTheme.labelSmall!.copyWith(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
                // Long labels shrink to fit a narrow phone rather than clip,
                // keeping a gap so neighbours never read as one word.
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(tab.label, maxLines: 1),
                  ),
                ),
              ),
            ],
          ),
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
