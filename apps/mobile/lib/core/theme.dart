import 'package:flutter/material.dart';

/// Virello design tokens.
///
/// 2026-09-29 master board palette (dark-first):
/// near-black background, dark surfaces, hot-pink primary accent.
/// Light theme keeps working; the board itself is dark-first.
class VirelloColors {
  // ── Board palette (2026-09-29 master design board) ──
  /// Primary accent — hot pink sampled from the board (#F95177).
  static const pink = Color(0xFFF95177);
  static const pinkDeep = Color(0xFFE63E63);
  static const boardBg = Color(0xFF0B0B0E);
  static const boardSurface = Color(0xFF15151C);
  static const boardField = Color(0xFF1D1D26);
  static const boardBorder = Color(0xFF2B2B36);
  static const boardTextSec = Color(0xFF9CA3AF);

  /// Board accent alias: the old violet name now resolves to board pink,
  /// so all 31 existing usages reskin automatically.
  @Deprecated('Use VirelloColors.pink (2026-09-29 board accent)')
  static const violet = pink;
  @Deprecated('Use VirelloColors.pinkDeep')
  static const violetDeep = pinkDeep;
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

  /// Signature gradient: board pink → deep pink (was violet).
  static const brandGradient = LinearGradient(
    colors: [Color(0xFFF95177), Color(0xFFE63E63)],
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

/// Virello premium theme: board pink primary.
/// Dark theme is board-first: near-black background, dark surfaces.
/// Light theme keeps a clean white page with the pink accent.
class VirelloTheme {
  static const _seed = VirelloColors.pink; // 2026-09-29 board accent

  static ThemeData dark() {
    var scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    );
    // Board look: near-black page, dark cards.
    scheme = scheme.copyWith(
      surface: VirelloColors.boardBg,
      surfaceContainerHighest: VirelloColors.boardSurface,
    );
    return _base(scheme, Brightness.dark);
  }

  static ThemeData light() {
    var scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    );
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
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: b == Brightness.dark
              ? const BorderSide(color: VirelloColors.boardBorder, width: 1)
              : BorderSide.none,
        ),
        color: scheme.surfaceContainerHighest,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  /// Signature gradient for the LET AI GROW button and hero cards —
  /// board pink family.
  static const growGradient = LinearGradient(
    colors: [Color(0xFFF95177), Color(0xFFE63E63), Color(0xFFC2274E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
