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
/// Light theme is a clean white/pink theme — every surface, tab, button,
/// dialog and sheet adapts; text always stays readable via VTheme.
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
      surfaceContainerHigh: VirelloColors.boardField,
    );
    return _base(scheme, Brightness.dark);
  }

  static ThemeData light() {
    var scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    );
    // Light look: white page, soft pink-tinted surfaces, ink text.
    scheme = scheme.copyWith(
      surface: Colors.white,
      surfaceContainerHighest: const Color(0xFFF7F7FA),
      surfaceContainerHigh: const Color(0xFFF0EFF7),
      onSurface: VirelloColors.ink,
      onSurfaceVariant: VirelloColors.mutedDark,
    );
    return _base(scheme, Brightness.light);
  }

  static ThemeData _base(ColorScheme scheme, Brightness b) {
    final dark = b == Brightness.dark;
    final border = dark ? VirelloColors.boardBorder : VirelloColors.divider;
    final textSec = dark ? VirelloColors.boardTextSec : VirelloColors.mutedDark;
    return ThemeData(
      useMaterial3: true,
      // Licensed Aperçu (Colophon) becomes the UI font once its files are
      // dropped into assets/fonts/ + pubspec block uncommented (see
      // assets/fonts/APERCU_README.md). Until then Inter renders — no breakage.
      fontFamily: 'Inter', // switch to 'Apercu' when licensed files are added
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      // Readable default text in both themes.
      textTheme: (dark ? ThemeData.dark() : ThemeData.light())
          .textTheme
          .apply(
            bodyColor: scheme.onSurface,
            displayColor: scheme.onSurface,
            fontFamily: 'Inter',
          ),
      iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: scheme.onSurface),
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
          side: BorderSide(color: border, width: 1),
        ),
        color: scheme.surfaceContainerHighest,
      ),
      // ── Buttons: pink brand in both themes, white text on brand ──
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: VirelloColors.pink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: VirelloColors.pink,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: VirelloColors.pink,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: dark ? Colors.white : VirelloColors.ink,
          side: BorderSide(color: border, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: VirelloColors.pink,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      // ── Tabs: pink indicator + readable labels in both themes ──
      tabBarTheme: TabBarThemeData(
        labelColor: VirelloColors.pink,
        unselectedLabelColor: textSec,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: VirelloColors.pink, width: 2.5),
        ),
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: VirelloColors.pink,
        unselectedItemColor: textSec,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: VirelloColors.pink.withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      // ── Inputs ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        hintStyle: TextStyle(color: textSec, fontSize: 14),
        labelStyle: TextStyle(color: textSec, fontSize: 14),
        prefixIconColor: textSec,
        suffixIconColor: textSec,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border, width: 1),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: VirelloColors.pink, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      // ── Overlays: dialogs, sheets, menus, snackbars ──
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: border, width: 1),
        ),
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: TextStyle(color: scheme.onSurface, fontSize: 14),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? VirelloColors.boardField : VirelloColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        actionTextColor: VirelloColors.pink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: 1),
        ),
        textStyle: TextStyle(color: scheme.onSurface, fontSize: 14),
      ),
      // ── Selection controls ──
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.white
              : textSec,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? VirelloColors.pink
              : (dark ? VirelloColors.boardField : VirelloColors.divider),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? VirelloColors.pink
              : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? VirelloColors.pink
              : textSec,
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: VirelloColors.pink,
        thumbColor: VirelloColors.pink,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: VirelloColors.pink,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        labelStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(color: border, width: 1),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textSec,
        textColor: scheme.onSurface,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark ? VirelloColors.boardField : VirelloColors.ink,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
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

/// Theme-aware color helpers — the 2026-09-29 master board is dark-first,
/// but the app also supports light mode. Use these instead of fixed
/// VirelloColors tokens in shared widgets and reskinned screens so both
/// themes render correctly.
class VTheme {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Card surface: board dark surface in dark mode, white in light.
  static Color card(BuildContext context) =>
      isDark(context) ? VirelloColors.boardSurface : Colors.white;

  /// Chip / fill surface: board field in dark, light chip in light.
  static Color chip(BuildContext context) =>
      isDark(context) ? VirelloColors.boardField : VirelloColors.chipBg;

  /// Hairline borders: board border in dark, light divider in light.
  static Color divider(BuildContext context) =>
      isDark(context) ? VirelloColors.boardBorder : VirelloColors.divider;

  /// Secondary text: board gray in dark, muted-dark in light.
  static Color textSec(BuildContext context) =>
      isDark(context) ? VirelloColors.boardTextSec : VirelloColors.mutedDark;

  /// Primary text: white in dark, ink in light.
  static Color text(BuildContext context) =>
      isDark(context) ? Colors.white : VirelloColors.ink;

  /// Page/window background: near-black in dark, white in light.
  /// Use for full-bleed containers instead of hardcoded boardBg.
  static Color scaffold(BuildContext context) =>
      isDark(context) ? VirelloColors.boardBg : Colors.white;

  /// Text/icons drawn ON brand surfaces (pink buttons, pink gradients,
  /// pink chips): always white in both themes — never mixes with the
  /// page theme.
  static Color onBrand(BuildContext context) => Colors.white;
}
