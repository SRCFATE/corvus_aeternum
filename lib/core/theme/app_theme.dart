import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'corvus_design.dart';
import '../../shared/widgets/corvus_motion.dart';

abstract final class AppTheme {
  /// Tema base estático (fallback cuando no hay conspiración cargada).
  static ThemeData get dark => buildDark(
        accent: AppColors.accent,
        base: AppColors.background,
        surface: AppColors.surface,
      );

  /// Construye el tema con la paleta 70/20/10 de la conspiración activa.
  static ThemeData buildDark({
    required Color accent,
    required Color base,
    required Color surface,
  }) {
    final card = Color.lerp(base, surface, 0.5)!;
    final border = Color.lerp(surface, accent, 0.12)!;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: base,
      colorScheme: ColorScheme.dark(
        surface: surface,
        primary: accent,
        secondary: AppColors.secondary,
        error: AppColors.error,
        onPrimary: base,
        onSecondary: AppColors.textPrimary,
        onSurface: AppColors.textPrimary,
        onError: AppColors.textPrimary,
        outline: border,
      ),
      textTheme: _textTheme,
      visualDensity: VisualDensity.standard,
      // Una sola transición para todas las rutas apiladas y todas las
      // plataformas. Por defecto, Flutter da a cada sistema la suya —el
      // deslizamiento lateral de iOS, el ascenso de Android, nada en web—, y
      // Corvus es la misma aplicación en los tres sitios.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CorvusPageTransitionsBuilder(),
          TargetPlatform.iOS: CorvusPageTransitionsBuilder(),
          TargetPlatform.macOS: CorvusPageTransitionsBuilder(),
          TargetPlatform.windows: CorvusPageTransitionsBuilder(),
          TargetPlatform.linux: CorvusPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CorvusPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: base,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        iconTheme: const IconThemeData(color: AppColors.textSecondary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle:
            const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CorvusRadius.lg),
          side: BorderSide(color: border, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CorvusRadius.md),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CorvusRadius.md),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CorvusRadius.md),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CorvusRadius.md),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CorvusRadius.md),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        labelStyle:
            const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        errorStyle: const TextStyle(color: AppColors.errorLight, fontSize: 12),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: base,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CorvusRadius.md)),
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: accent),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CorvusRadius.md)),
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 0.5,
        space: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.overlay,
        labelStyle:
            const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        side: const BorderSide(color: AppColors.border, width: 0.5),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CorvusRadius.pill)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: accent,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: accent,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        dividerColor: AppColors.border,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.cardElevated,
        contentTextStyle:
            const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CorvusRadius.md)),
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CorvusRadius.xl),
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        contentTextStyle:
            const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      ),
    );
  }

  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 57,
      fontWeight: FontWeight.w900,
      letterSpacing: -1.6,
      height: 1.02,
    ),
    displayMedium: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 45,
      fontWeight: FontWeight.w900,
      letterSpacing: -1.2,
      height: 1.04,
    ),
    displaySmall: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 36,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.9,
    ),
    headlineLarge: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 32,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.8,
    ),
    headlineMedium: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 28,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
    ),
    headlineSmall: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 24,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
    ),
    titleLarge: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 20,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
    ),
    titleMedium: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
    titleSmall: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
    bodyLarge: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 15.5,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.05,
      height: 1.6,
    ),
    bodyMedium: TextStyle(
      color: AppColors.textSecondary,
      fontSize: 13.5,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.05,
      height: 1.55,
    ),
    bodySmall: TextStyle(
      color: AppColors.textMuted,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
    ),
    labelLarge: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
    labelMedium: TextStyle(
      color: AppColors.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
    labelSmall: TextStyle(
      color: AppColors.textMuted,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
  );
}
