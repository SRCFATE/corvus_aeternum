import 'package:flutter/material.dart';
import 'app_skin.dart';

class AppTheme {
  static ThemeData build({required AppSkin skin}) {
    final scheme = ColorScheme(
      brightness: Brightness.dark,

      primary: skin.primary,
      onPrimary: skin.onPrimary,

      secondary: skin.secondary,
      onSecondary: skin.onSurface,

      tertiary: skin.tertiary,
      onTertiary: skin.onSurface,

      error: const Color(0xFFFF6B6B),
      onError: const Color(0xFF0B0B0E),

      surface: skin.surface,
      onSurface: skin.onSurface,

      // Material 3 extras (tú pedías NO usar surfaceVariant)
      surfaceContainerHighest: skin.surfaceContainerHighest,
      outline: skin.outline,

      // Estos no los usas mucho pero son requeridos por el constructor
      outlineVariant: skin.outline.withValues(alpha: 0.55),
      shadow: Colors.black,
      scrim: Colors.black,

      // Inversos (opcional)
      inverseSurface: skin.onSurface.withValues(alpha: 0.90),
      onInverseSurface: skin.surface,
      inversePrimary: skin.primary.withValues(alpha: 0.85),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    // Tipografía
    final textTheme = base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    // Botones coherentes con conspiración
    final filledButtonTheme = FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );

    final textButtonTheme = TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.onSurface.withValues(alpha: 0.90),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );

    final outlinedButtonTheme = OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface.withValues(alpha: 0.92),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.45)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );

    // Inputs (Login/Register, búsquedas, etc)
    final inputDecorationTheme = InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.50),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.55)),
      labelStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.72)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.25)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.25)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.90), width: 1.4),
      ),
    );

    // Chips (pills, tags)
    final chipTheme = ChipThemeData(
      backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      selectedColor: scheme.primary.withValues(alpha: 0.20),
      secondarySelectedColor: scheme.primary.withValues(alpha: 0.22),
      labelStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.88), fontWeight: FontWeight.w700),
      secondaryLabelStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.92), fontWeight: FontWeight.w800),
      shape: StadiumBorder(side: BorderSide(color: scheme.outline.withValues(alpha: 0.35))),
    );

    // Cards / Dialogs
    final cardTheme = CardThemeData(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.40),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    );

    final dialogTheme = DialogThemeData(
      backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.75),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontWeight: FontWeight.w900,
        fontSize: 18,
      ),
      contentTextStyle: TextStyle(
        color: scheme.onSurface.withValues(alpha: 0.82),
      ),
    );

    // AppBar / TopBar base
    final appBarTheme = AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontWeight: FontWeight.w900,
        fontSize: 16,
      ),
    );

    // Snackbars
    final snackBarTheme = SnackBarThemeData(
      backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.85),
      contentTextStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.92)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      behavior: SnackBarBehavior.floating,
    );

    return base.copyWith(
      textTheme: textTheme,
      filledButtonTheme: filledButtonTheme,
      textButtonTheme: textButtonTheme,
      outlinedButtonTheme: outlinedButtonTheme,
      inputDecorationTheme: inputDecorationTheme,
      chipTheme: chipTheme,
      cardTheme: cardTheme,
      dialogTheme: dialogTheme,
      appBarTheme: appBarTheme,
      snackBarTheme: snackBarTheme,
      dividerTheme: DividerThemeData(color: scheme.outline.withValues(alpha: 0.35)),
      iconTheme: IconThemeData(color: scheme.onSurface.withValues(alpha: 0.90)),
    );
  }
}