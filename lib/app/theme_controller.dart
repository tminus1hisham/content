import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/prefs.dart';
import 'theme.dart';

class ThemeSettings {
  const ThemeSettings({
    this.themeMode = ThemeMode.system,
    this.accentIndex = 0,
  });
  final ThemeMode themeMode;
  final int accentIndex;
}

const themeModeKey = 'theme.mode';
const themeAccentKey = 'theme.accent';

class ThemeController extends Notifier<ThemeSettings> {
  @override
  ThemeSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    // prefs.get (not getInt/getString) so a stored value of the wrong type falls back instead of throwing.
    final mode = ThemeMode.values.asNameMap()[prefs.get(themeModeKey)];
    final accent = prefs.get(themeAccentKey);
    return ThemeSettings(
      themeMode: mode ?? ThemeMode.system,
      accentIndex: accent is int && accent >= 0 && accent < accents.length
          ? accent
          : 0,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = ThemeSettings(themeMode: mode, accentIndex: state.accentIndex);
    await ref
        .read(sharedPreferencesProvider)
        .setString(themeModeKey, mode.name);
  }

  Future<void> setAccent(int index) async {
    state = ThemeSettings(themeMode: state.themeMode, accentIndex: index);
    await ref.read(sharedPreferencesProvider).setInt(themeAccentKey, index);
  }
}

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeSettings>(ThemeController.new);
