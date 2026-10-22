import 'package:content/app/theme_controller.dart';
import 'package:content/core/prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test(
    'setting mode and accent persists and a fresh container restores it',
    () async {
      final first = await _container({});
      final controller = first.read(themeControllerProvider.notifier);
      await controller.setThemeMode(ThemeMode.dark);
      await controller.setAccent(2);

      final prefs = first.read(sharedPreferencesProvider);
      expect(prefs.getString('theme.mode'), 'dark');
      expect(prefs.getInt('theme.accent'), 2);

      final fresh = await _container({'theme.mode': 'dark', 'theme.accent': 2});
      final restored = fresh.read(themeControllerProvider);
      expect(restored.themeMode, ThemeMode.dark);
      expect(restored.accentIndex, 2);
    },
  );

  for (final invalid in <Map<String, Object>>[
    {'theme.mode': 'neon', 'theme.accent': 99},
    {'theme.mode': 3, 'theme.accent': 'rose'},
    {'theme.accent': -1},
  ]) {
    test('invalid stored values $invalid fall back to defaults', () async {
      final settings = (await _container(
        invalid,
      )).read(themeControllerProvider);
      expect(settings.themeMode, ThemeMode.system);
      expect(settings.accentIndex, 0);
    });
  }
}
