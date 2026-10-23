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
  AccentOption('Sunset', sunsetCoral),
  AccentOption('Purple', Color(0xFF7B1FA2)),
  AccentOption('Teal', Color(0xFF00897B)),
  AccentOption('Amber', Color(0xFFFFB300)),
  AccentOption('Blue', Color(0xFF1E88E5)),
  AccentOption('Emerald', Color(0xFF2E7D32)),
];

const sunsetOrange = Color(0xFFFF9A43);
const sunsetCoral = Color(0xFFEC6A72);
const sunsetPink = Color(0xFFFF65A1);

/// Readable on every stop of the brand gradient (white is not, on orange).
const brandInk = Color(0xFF240C17);

const cardRadius = 20.0;
const controlRadius = 14.0;
const sheetRadius = 28.0;

const _fontFamily = 'Manrope';
const _tabular = [FontFeature.tabularFigures()];

/// The accent as light: CTA gradient and background glows. Sunset is the
/// brand; other accents get a gradient built around their own hue.
@immutable
class Brand extends ThemeExtension<Brand> {
  const Brand({
    required this.gradient,
    required this.glowA,
    required this.glowB,
  });

  factory Brand.forAccent(Color accent) {
    if (accent == sunsetCoral) {
      return const Brand(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [sunsetOrange, sunsetCoral, sunsetPink],
        ),
        glowA: sunsetOrange,
        glowB: sunsetPink,
      );
    }
    final hsl = HSLColor.fromColor(accent);
    Color shift(double hue, double lightness) =>
        hsl.withHue((hsl.hue + hue) % 360).withLightness(lightness).toColor();
    final a = shift(30, 0.66);
    final b = shift(-20, 0.68);
    return Brand(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [a, hsl.withLightness(0.64).toColor(), b],
      ),
      glowA: a,
      glowB: b,
    );
  }

  final LinearGradient gradient;
  final Color glowA;
  final Color glowB;

  static Brand of(BuildContext context) =>
      Theme.of(context).extension<Brand>() ?? Brand.forAccent(sunsetCoral);

  @override
  Brand copyWith({LinearGradient? gradient, Color? glowA, Color? glowB}) =>
      Brand(
        gradient: gradient ?? this.gradient,
        glowA: glowA ?? this.glowA,
        glowB: glowB ?? this.glowB,
      );

  @override
  Brand lerp(Brand? other, double t) => t < 0.5 || other == null ? this : other;
}

/// Manrope ships under the SIL OFL; list it on the licences page.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Manrope',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
}

/// Brand-fixed surfaces: plum-black after dark, cream by day. The accent only
/// changes the tonal roles (primary, secondary, ...).
ColorScheme _scheme(Color accent, Brightness brightness) {
  final seeded = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  if (brightness == Brightness.dark) {
    return seeded.copyWith(
      surface: const Color(0xFF0E0A0D),
      surfaceDim: const Color(0xFF0E0A0D),
      surfaceBright: const Color(0xFF352838),
      surfaceContainerLowest: const Color(0xFF0A070A),
      surfaceContainerLow: const Color(0xFF16101A),
      surfaceContainer: const Color(0xFF1D1521),
      surfaceContainerHigh: const Color(0xFF261C2A),
      surfaceContainerHighest: const Color(0xFF2F2333),
      onSurface: const Color(0xFFF7EEF1),
      onSurfaceVariant: const Color(0xFFB4A3AC),
      outline: const Color(0xFF7D6C75),
      outlineVariant: const Color(0x17FFFFFF),
    );
  }
  return seeded.copyWith(
    surface: const Color(0xFFFFFCF5),
    surfaceDim: const Color(0xFFEDE3DC),
    surfaceBright: const Color(0xFFFFFFFF),
    surfaceContainerLowest: const Color(0xFFFFFFFF),
    surfaceContainerLow: const Color(0xFFFBF4EE),
    surfaceContainer: const Color(0xFFF6EDE7),
    surfaceContainerHigh: const Color(0xFFF1E6E0),
    surfaceContainerHighest: const Color(0xFFEBDFD9),
    onSurface: const Color(0xFF392B32),
    onSurfaceVariant: const Color(0xFF796972),
    outline: const Color(0xFFA8979F),
    outlineVariant: const Color(0x1A392B32),
  );
}

ThemeData buildTheme(Color accent, Brightness brightness) {
  final scheme = _scheme(accent, brightness);
  final typography = Typography.material2021();
  final base =
      (brightness == Brightness.dark ? typography.white : typography.black)
          .apply(
            fontFamily: _fontFamily,
            bodyColor: scheme.onSurface,
            displayColor: scheme.onSurface,
          );
  TextStyle? w(TextStyle? s, FontWeight weight, [double? spacing]) =>
      s?.copyWith(fontWeight: weight, letterSpacing: spacing);
  final textTheme = base.copyWith(
    displayLarge: w(base.displayLarge, FontWeight.w700, -1.5),
    displayMedium: w(base.displayMedium, FontWeight.w700, -1.25),
    displaySmall: w(base.displaySmall, FontWeight.w700, -1),
    headlineLarge: w(base.headlineLarge, FontWeight.w700, -0.75),
    headlineMedium: w(base.headlineMedium, FontWeight.w700, -0.5),
    headlineSmall: w(base.headlineSmall, FontWeight.w700, -0.5),
    titleLarge: w(base.titleLarge, FontWeight.w700, -0.3),
    titleMedium: w(base.titleMedium, FontWeight.w600, -0.1),
    titleSmall: w(base.titleSmall, FontWeight.w600),
    labelLarge: w(base.labelLarge, FontWeight.w600, 0.1),
    labelMedium: w(base.labelMedium, FontWeight.w600, 0.2),
    labelSmall: w(base.labelSmall, FontWeight.w600, 0.3),
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
  final hairline = BorderSide(color: scheme.outlineVariant);
  const fade = FadeForwardsPageTransitionsBuilder();
  const cupertino = CupertinoPageTransitionsBuilder();

  return ThemeData(
    colorScheme: scheme,
    fontFamily: _fontFamily,
    textTheme: textTheme,
    scaffoldBackgroundColor: scheme.surface,
    extensions: [Brand.forAccent(accent)],
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: fade,
        TargetPlatform.fuchsia: fade,
        TargetPlatform.windows: fade,
        TargetPlatform.linux: fade,
        TargetPlatform.iOS: cupertino,
        TargetPlatform.macOS: cupertino,
      },
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(cardRadius)),
        side: hairline,
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
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: controlShape,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
        fontWeight: FontWeight.w500,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      border: inputBorder(hairline),
      enabledBorder: inputBorder(hairline),
      focusedBorder: inputBorder(BorderSide(color: scheme.primary, width: 1.5)),
      errorBorder: inputBorder(BorderSide(color: scheme.error)),
      focusedErrorBorder: inputBorder(
        BorderSide(color: scheme.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.all(16),
    ),
    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      side: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? BorderSide(color: scheme.primary, width: 1.5)
            : hairline,
      ),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16),
      ),
      constraints: const BoxConstraints(minHeight: 52),
      hintStyle: WidgetStatePropertyAll(
        textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
      ),
      textStyle: WidgetStatePropertyAll(textTheme.bodyLarge),
    ),
    filledButtonTheme: FilledButtonThemeData(style: confirmStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: controlSize,
        shape: controlShape,
        textStyle: buttonText,
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
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
        side: WidgetStatePropertyAll(hairline),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primaryContainer
              : scheme.surfaceContainerLow,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimaryContainer
              : null,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: hairline,
      backgroundColor: scheme.surfaceContainerLow,
      selectedColor: scheme.primary,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      labelStyle: textTheme.labelLarge?.copyWith(
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurface,
        ),
      ),
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
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainerHigh,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        side: hairline,
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      subtitleTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      circularTrackColor: Colors.transparent,
    ),
    appBarTheme: AppBarTheme(
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: w(textTheme.titleLarge, FontWeight.w700, -0.3),
    ),
    // The shell lays its own blur behind this, so the bar itself is translucent.
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      elevation: 0,
      backgroundColor: scheme.surface.withValues(alpha: 0.72),
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primary.withValues(alpha: 0.16),
      indicatorShape: const StadiumBorder(),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => textTheme.labelSmall?.copyWith(
          fontSize: 11.5,
          color: states.contains(WidgetState.selected)
              ? scheme.onSurface
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}
