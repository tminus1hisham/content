import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
const controlRadius = 14.0;
const sheetRadius = 28.0;

const _fontFamily = 'Manrope';
const _tabular = [FontFeature.tabularFigures()];

/// Manrope ships under the SIL OFL; list it on the licences page.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Manrope',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
}

ThemeData buildTheme(Color accent, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: brightness,
  );
  final typography = Typography.material2021();
  final base =
      (brightness == Brightness.dark ? typography.white : typography.black)
          .apply(fontFamily: _fontFamily);
  TextStyle? w(TextStyle? s, FontWeight weight, [double? spacing]) =>
      s?.copyWith(fontWeight: weight, letterSpacing: spacing);
  final textTheme = base.copyWith(
    displayLarge: w(base.displayLarge, FontWeight.w700, -0.5),
    displayMedium: w(base.displayMedium, FontWeight.w700, -0.5),
    displaySmall: w(base.displaySmall, FontWeight.w700, -0.5),
    headlineLarge: w(base.headlineLarge, FontWeight.w700, -0.25),
    headlineMedium: w(base.headlineMedium, FontWeight.w700, -0.25),
    headlineSmall: w(base.headlineSmall, FontWeight.w700, -0.25),
    titleLarge: w(base.titleLarge, FontWeight.w600),
    titleMedium: w(base.titleMedium, FontWeight.w600),
    titleSmall: w(base.titleSmall, FontWeight.w600),
    labelLarge: w(base.labelLarge, FontWeight.w600),
    labelMedium: w(base.labelMedium, FontWeight.w600),
    labelSmall: w(base.labelSmall, FontWeight.w600),
  );

  const sheetShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(sheetRadius)),
  );
  const controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(controlRadius)),
  );
  const controlSize = Size(64, 52);
  final buttonText = textTheme.labelLarge;
  final confirmStyle = FilledButton.styleFrom(
    minimumSize: controlSize,
    shape: controlShape,
    textStyle: buttonText,
  );
  final cancelStyle = TextButton.styleFrom(
    minimumSize: controlSize,
    shape: controlShape,
    textStyle: buttonText,
  );
  OutlineInputBorder inputBorder(BorderSide side) => OutlineInputBorder(
    borderRadius: const BorderRadius.all(Radius.circular(controlRadius)),
    borderSide: side,
  );

  return ThemeData(
    colorScheme: scheme,
    fontFamily: _fontFamily,
    textTheme: textTheme,
    cardTheme: const CardThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(cardRadius)),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      shape: sheetShape,
      elevation: 0,
      headerBackgroundColor: scheme.primaryContainer,
      headerForegroundColor: scheme.onPrimaryContainer,
      headerHeadlineStyle: w(textTheme.headlineLarge, FontWeight.w700),
      dayShape: const WidgetStatePropertyAll(CircleBorder()),
      todayBorder: BorderSide(color: scheme.primary, width: 1.5),
      yearShape: const WidgetStatePropertyAll(StadiumBorder()),
      dayStyle: textTheme.bodyMedium?.copyWith(fontFeatures: _tabular),
      confirmButtonStyle: confirmStyle,
      cancelButtonStyle: cancelStyle,
      dividerColor: Colors.transparent,
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      shape: sheetShape,
      hourMinuteShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      hourMinuteTextStyle: textTheme.displayMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontFeatures: _tabular,
      ),
      dayPeriodShape: const StadiumBorder(),
      dialBackgroundColor: scheme.surfaceContainerHighest,
      dialHandColor: scheme.primary,
      confirmButtonStyle: confirmStyle,
      cancelButtonStyle: cancelStyle,
    ),
    dialogTheme: DialogThemeData(
      shape: sheetShape,
      backgroundColor: scheme.surfaceContainerHigh,
      titleTextStyle: w(textTheme.headlineSmall, FontWeight.w700),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(sheetRadius)),
      ),
      showDragHandle: true,
      backgroundColor: scheme.surfaceContainerLow,
      dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.4),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: controlShape,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      border: inputBorder(BorderSide.none),
      enabledBorder: inputBorder(BorderSide.none),
      focusedBorder: inputBorder(BorderSide(color: scheme.primary, width: 1.5)),
      errorBorder: inputBorder(BorderSide(color: scheme.error)),
      focusedErrorBorder: inputBorder(
        BorderSide(color: scheme.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.all(16),
    ),
    filledButtonTheme: FilledButtonThemeData(style: confirmStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: controlSize,
        shape: controlShape,
        textStyle: buttonText,
      ),
    ),
    // Inline links (policy, "Type it instead") stay compact; dialog cancel keeps 52.
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 44),
        shape: controlShape,
        textStyle: buttonText,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primaryContainer
              : null,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimaryContainer
              : null,
        ),
      ),
    ),
    chipTheme: const ChipThemeData(
      shape: StadiumBorder(),
      side: BorderSide.none,
    ),
    switchTheme: SwitchThemeData(
      thumbIcon: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? const Icon(Icons.check)
            : null,
      ),
    ),
    checkboxTheme: const CheckboxThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    appBarTheme: AppBarTheme(
      scrolledUnderElevation: 0,
      titleTextStyle: w(textTheme.titleLarge, FontWeight.w700),
    ),
  );
}
