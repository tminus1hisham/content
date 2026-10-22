import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'app/theme_controller.dart';
import 'core/prefs.dart';
import 'features/disguise/disguise_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const App(),
    ),
  );
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeControllerProvider);
    final accent = accents[settings.accentIndex].color;
    final disguise = ref.watch(disguiseProvider);
    return MaterialApp.router(
      // Shown in the recent-apps switcher, so it follows the disguise.
      title: disguise == Disguise.none ? 'Content' : disguise.label,
      theme: buildTheme(accent, Brightness.light),
      darkTheme: buildTheme(accent, Brightness.dark),
      themeMode: settings.themeMode,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
