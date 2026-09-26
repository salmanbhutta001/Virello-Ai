import 'package:flutter/material.dart';

/// Virello design tokens — approved 10-screen board (2026-09-26).
/// Light theme: white background, violet primary, dark-navy text.
/// The AI Growth Agent screen is always dark navy.
class VirelloColors {
  static const violet = Color(0xFF7C5CFF);
  static const violetDeep = Color(0xFF6A48F5);
  static const navy = Color(0xFF1C1D33);
  static const ink = Color(0xFF1A1B2E);
  static const muted = Color(0xFF8F8FA8);
  static const mutedDark = Color(0xFF55566E);
  static const chipBg = Color(0xFFF0EFF7);
  static const cardBg = Color(0xFFFFFFFF);
  static const pageBg = Color(0xFFFFFFFF);
  static const divider = Color(0xFFE8E7F5);
  static const success = Color(0xFF3DDC84);
  static const danger = Color(0xFFE05252);
  static const amber = Color(0xFFFFB020);

  /// Signature gradient: Get Started / LET AI GROW / AI orb.
  static const brandGradient = LinearGradient(
    colors: [Color(0xFF7C5CFF), Color(0xFF9D4EDD), Color(0xFF22D3EE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF1C1D33).withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];
}

/// Virello premium theme: violet primary on clean white (light),
/// deep navy dark theme. Trustworthy + futuristic.
class VirelloTheme {
  static const _seed = Color(0xFF7C5CFF); // board violet

  static ThemeData dark() {
    final scheme =
        ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark);
    return _base(scheme, Brightness.dark);
  }

  static ThemeData light() {
    var scheme =
        ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.light);
    // Board look: pure white page background.
    scheme = scheme.copyWith(surface: Colors.white);
    return _base(scheme, Brightness.light);
  }

  static ThemeData _base(ColorScheme scheme, Brightness b) {
    return ThemeData(
      useMaterial3: true,
      // Licensed Aperçu (Colophon) becomes the UI font once its files are
      // dropped into assets/fonts/ + pubspec block uncommented (see
      // assets/fonts/APERCU_README.md). Until then Inter renders — no breakage.
      fontFamily: 'Inter', // switch to 'Apercu' when licensed files are added
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: scheme.surfaceContainerHighest,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  /// Signature gradient for the LET AI GROW button and hero cards.
  static const growGradient = LinearGradient(
    colors: [Color(0xFF6C3DF5), Color(0xFF9D4EDD), Color(0xFF22D3EE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
