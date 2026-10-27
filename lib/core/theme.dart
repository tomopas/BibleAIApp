import 'package:flutter/material.dart';

class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.primary,
    required this.secondary,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.heroStart,
    required this.heroEnd,
    required this.isDark,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color primary;
  final Color secondary;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final Color heroStart;
  final Color heroEnd;
  final bool isDark;

  static const parchment = AppPalette(
    background: Color(0xFFF7F2E8),
    surface: Color(0xFFFFFDF8),
    surfaceAlt: Color(0xFFEFE7D8),
    primary: Color(0xFF8C3B2E),
    secondary: Color(0xFF5A6B4F),
    textPrimary: Color(0xFF2B2621),
    textSecondary: Color(0xFF746A5E),
    divider: Color(0xFFE3D8C6),
    heroStart: Color(0xFF7A3126),
    heroEnd: Color(0xFFB56A4A),
    isDark: false,
  );

  static const white = AppPalette(
    background: Color(0xFFF5F6F4),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEDEFEC),
    primary: Color(0xFF2F4A5A),
    secondary: Color(0xFF8A5A3B),
    textPrimary: Color(0xFF1D252A),
    textSecondary: Color(0xFF66727A),
    divider: Color(0xFFE1E5E3),
    heroStart: Color(0xFF263C49),
    heroEnd: Color(0xFF5D7C8B),
    isDark: false,
  );

  static const night = AppPalette(
    background: Color(0xFF0E1418),
    surface: Color(0xFF161E23),
    surfaceAlt: Color(0xFF1E282E),
    primary: Color(0xFFD9A46C),
    secondary: Color(0xFF8FB3A0),
    textPrimary: Color(0xFFECE6DA),
    textSecondary: Color(0xFF9BA6AC),
    divider: Color(0xFF26333A),
    heroStart: Color(0xFF2A2118),
    heroEnd: Color(0xFF5E4530),
    isDark: true,
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? primary,
    Color? secondary,
    Color? textPrimary,
    Color? textSecondary,
    Color? divider,
    Color? heroStart,
    Color? heroEnd,
    bool? isDark,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      divider: divider ?? this.divider,
      heroStart: heroStart ?? this.heroStart,
      heroEnd: heroEnd ?? this.heroEnd,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      heroStart: Color.lerp(heroStart, other.heroStart, t)!,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

class AppTheme {
  static const highlightColors = <int>[
    0xFFF6E27A,
    0xFFBFE3B4,
    0xFFB9D9F2,
    0xFFF4C2D7,
    0xFFF7C98B,
    0xFFD9C7F0,
  ];

  static ThemeData build(ThemeMode mode, String style) {
    final dark = style == 'night' || mode == ThemeMode.dark;
    final base = style == 'white' ? AppPalette.white : AppPalette.parchment;
    final palette = dark
        ? (style == 'night' ? AppPalette.night : darken(base))
        : base;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: palette.primary,
          brightness: dark ? Brightness.dark : Brightness.light,
        ).copyWith(
          primary: palette.primary,
          secondary: palette.secondary,
          surface: palette.surface,
          onSurface: palette.textPrimary,
          error: const Color(0xFFB3261E),
        );

    final textTheme = TextTheme(
      displayLarge: TextStyle(fontFamily: 'Lora', color: palette.textPrimary),
      displayMedium: TextStyle(fontFamily: 'Lora', color: palette.textPrimary),
      headlineLarge: TextStyle(
        fontFamily: 'Lora',
        color: palette.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Lora',
        color: palette.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Lora',
        color: palette.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Lora',
        color: palette.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: palette.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        color: palette.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(color: palette.textPrimary),
      bodyMedium: TextStyle(color: palette.textPrimary),
      bodySmall: TextStyle(color: palette.textSecondary),
      labelLarge: TextStyle(color: palette.textPrimary),
      labelMedium: TextStyle(color: palette.textSecondary),
      labelSmall: TextStyle(color: palette.textSecondary),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      textTheme: textTheme,
      extensions: [palette],
      dividerColor: palette.divider,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Lora',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: palette.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.divider.withValues(alpha: 0.75)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: palette.primary.withValues(alpha: 0.14),
        height: 70,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: palette.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 23,
            color: selected ? palette.primary : palette.textSecondary,
          );
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        modalBackgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        showDragHandle: true,
        dragHandleColor: palette.divider,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.textPrimary,
        contentTextStyle: TextStyle(color: palette.background),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceAlt.withValues(alpha: 0.55),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.primary, width: 1.4),
        ),
        hintStyle: TextStyle(color: palette.textSecondary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceAlt.withValues(alpha: 0.6),
        selectedColor: palette.primary.withValues(alpha: 0.16),
        side: BorderSide(color: palette.divider),
        labelStyle: TextStyle(color: palette.textPrimary, fontSize: 12.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.primary,
          side: BorderSide(color: palette.divider),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: palette.primary),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.primary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.surface;
          return palette.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.primary;
          return palette.divider;
        }),
      ),
    );
  }

  static AppPalette darken(AppPalette base) {
    return AppPalette(
      background: const Color(0xFF121619),
      surface: const Color(0xFF1A2024),
      surfaceAlt: const Color(0xFF232B30),
      primary: base == AppPalette.white
          ? const Color(0xFF9FC3D6)
          : const Color(0xFFD9A46C),
      secondary: const Color(0xFF8FB3A0),
      textPrimary: const Color(0xFFE9E4D9),
      textSecondary: const Color(0xFF9DA7AC),
      divider: const Color(0xFF2B3539),
      heroStart: const Color(0xFF2A2118),
      heroEnd: const Color(0xFF5A4130),
      isDark: true,
    );
  }

  static TextStyle scripture(
    BuildContext context, {
    required double fontSize,
    required double lineHeight,
    String family = 'serif',
  }) {
    final palette = context.palette;
    return TextStyle(
      fontFamily: family == 'serif' ? 'Lora' : null,
      fontSize: fontSize,
      height: lineHeight,
      letterSpacing: 0.05,
      color: palette.textPrimary,
      fontWeight: FontWeight.w400,
    );
  }
}

extension PaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.parchment;
}
