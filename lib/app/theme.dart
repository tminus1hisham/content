import 'package:flutter/material.dart';

class AccentOption {
  const AccentOption(this.name, this.color);
  final String name;
  final Color color;
}

/// Index 0 is the brand default. Persisted by index, so append new options at the end.
const accents = [
  AccentOption('Rose', Color(0xFFC2185B)),
  AccentOption('Purple', Color(0xFF7B1FA2)),
  AccentOption('Teal', Color(0xFF00897B)),
  AccentOption('Amber', Color(0xFFFFB300)),
  AccentOption('Blue', Color(0xFF1E88E5)),
  AccentOption('Emerald', Color(0xFF2E7D32)),
];

const cardRadius = 16.0;
const controlRadius = 12.0;

ThemeData buildTheme(Color accent, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: scheme,
    cardTheme: const CardThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(cardRadius)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(controlRadius)),
      ),
    ),
  );
}
