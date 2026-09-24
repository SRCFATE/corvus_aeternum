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
  ///
  /// El acento de la casa tiñe lo que actúa —botones, foco, indicadores— y
  /// nada más. Todo lo que se lee sigue siendo marfil sobre tinta: el color
  /// es identidad, no decoración.
  static ThemeData buildDark({
    required Color accent,
    required Color base,
    required Color surface,
    bool highContrast = false,
  }) {
    final card = Color.lerp(base, surface, 0.5)!;
    final border = highContrast
        ? Colors.white.withValues(alpha: 0.26)
        : Color.lerp(AppColors.border, accent, 0.10)!;
    final primaryText = highContrast ? Colors.white : AppColors.textPrimary;
    final secondaryText =
        highContrast ? const Color(0xFFD4CEC5) : AppColors.textSecondary;

    final textTheme = highContrast
        ? _textTheme.apply(bodyColor: primaryText, displayColor: primaryText)
        : _textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: base,
      canvasColor: base,
      colorScheme: ColorScheme.dark(
        surface: surface,
        surfaceContainerLowest: base,
        surfaceContainerLow: surface,
        surfaceContainer: card,
        surfaceContainerHigh: AppColors.cardElevated,
        surfaceContainerHighest: AppColors.cardElevated,
        primary: accent,
        secondary: AppColors.secondary,
        tertiary: AppColors.gold,
        error: AppColors.error,
        onPrimary: base,
        onSecondary: AppColors.textPrimary,
        onSurface: primaryText,
        onSurfaceVariant: secondaryText,
        onError: AppColors.textPrimary,
        outline: border,
        outlineVariant: border.withValues(alpha: 0.6),
        surfaceTint: Colors.transparent,
      ),
      textTheme: textTheme,
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 22),
      visualDensity: VisualDensity.standard,
      // Sin ondas de tinta: la respuesta al toque es el hundido de
      // `CorvusPressable` y un velo de hover. La onda de Material es la firma
      // visual de Android, no de un archivo.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.white.withValues(alpha: 0.04),
      hoverColor: Colors.white.withValues(alpha: 0.035),
      focusColor: accent.withValues(alpha: 0.12),
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
        foregroundColor: primaryText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: primaryText,
          fontFamily: CorvusType.serif,
          fontSize: 19,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: AppColors.textSecondary),
        actionsIconTheme: const IconThemeData(color: AppColors.textSecondary),
        shape: Border(
          bottom: BorderSide(color: border.withValues(alpha: 0.7), width: 1),
        ),
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
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CorvusRadius.lg),
          side: BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
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
          borderSide: BorderSide(color: accent.withValues(alpha: 0.85), width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CorvusRadius.md),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CorvusRadius.md),
          borderSide: const BorderSide(color: AppColors.error, width: 1.2),
        ),
        labelStyle: TextStyle(color: secondaryText, fontSize: 14),
        floatingLabelStyle: TextStyle(
          color: accent,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        helperStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        errorStyle: const TextStyle(color: AppColors.errorLight, fontSize: 12),
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(44, CorvusControl.minHeight),
          backgroundColor: accent,
          foregroundColor: base,
          disabledBackgroundColor: accent.withValues(alpha: 0.32),
          disabledForegroundColor: base.withValues(alpha: 0.7),
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CorvusRadius.md)),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, CorvusControl.minHeight),
          backgroundColor: accent,
          foregroundColor: base,
          disabledBackgroundColor: accent.withValues(alpha: 0.32),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CorvusRadius.md),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, CorvusControl.minHeight),
          foregroundColor: primaryText,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CorvusRadius.md)),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, CorvusControl.minHeight),
          foregroundColor: accent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CorvusRadius.sm)),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          highlightColor: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: base,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CorvusRadius.lg),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border.withValues(alpha: 0.85),
        thickness: 1,
        space: 0,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: primaryText,
        titleTextStyle: TextStyle(
          color: primaryText,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
        subtitleTextStyle: TextStyle(
          color: secondaryText,
          fontSize: 12.5,
          height: 1.4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CorvusRadius.md),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? accent.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.10),
        ),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.textPrimary
              : AppColors.textMuted,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? accent
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(base),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? accent
              : Colors.white.withValues(alpha: 0.28),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.10),
        thumbColor: AppColors.textPrimary,
        overlayColor: accent.withValues(alpha: 0.12),
        trackHeight: 2,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: Colors.white.withValues(alpha: 0.08),
        circularTrackColor: Colors.transparent,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          Colors.white.withValues(alpha: 0.16),
        ),
        radius: const Radius.circular(CorvusRadius.pill),
        thickness: const WidgetStatePropertyAll(4),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.overlay,
        selectedColor: AppColors.textPrimary,
        secondarySelectedColor: AppColors.textPrimary,
        checkmarkColor: base,
        labelStyle:
            const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        secondaryLabelStyle: TextStyle(color: base, fontSize: 12),
        side: BorderSide(color: border, width: 1),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CorvusRadius.pill)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        showCheckmark: false,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primaryText,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: accent,
        indicatorSize: TabBarIndicatorSize.label,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        labelStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.3),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        dividerColor: border,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.cardElevated,
        contentTextStyle:
            const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        actionTextColor: accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CorvusRadius.md),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CorvusRadius.xl),
          side: BorderSide(color: border, width: 1),
        ),
        titleTextStyle: TextStyle(
          color: primaryText,
          fontFamily: CorvusType.serif,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        contentTextStyle: TextStyle(
          color: secondaryText,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surface,
        dragHandleColor: Colors.white.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(CorvusRadius.xl),
          ),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.cardElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CorvusRadius.md),
          side: BorderSide(color: border, width: 1),
        ),
        textStyle: TextStyle(color: primaryText, fontSize: 13.5),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(AppColors.cardElevated),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CorvusRadius.md),
              side: BorderSide(color: border, width: 1),
            ),
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: primaryText, fontSize: 14),
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(AppColors.cardElevated),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CorvusRadius.md),
              side: BorderSide(color: border, width: 1),
            ),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.cardElevated,
          borderRadius: BorderRadius.circular(CorvusRadius.sm),
          border: Border.all(color: border),
        ),
        textStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        waitDuration: const Duration(milliseconds: 420),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: 0.28),
        selectionHandleColor: accent,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: base,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accent.withValues(alpha: 0.14),
        elevation: 0,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: secondaryText,
          selectedBackgroundColor: AppColors.textPrimary,
          selectedForegroundColor: base,
          side: BorderSide(color: border),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: CorvusType.eyebrow(Colors.white, alpha: 0.4),
        dataTextStyle: TextStyle(color: primaryText, fontSize: 13.5),
        dividerThickness: 1,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        headerHeadlineStyle: CorvusType.headline,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CorvusRadius.xl),
          side: BorderSide(color: border),
        ),
      ),
    );
  }

  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(
      color: AppColors.textPrimary,
      fontFamily: CorvusType.serif,
      fontSize: 56,
      fontWeight: FontWeight.w600,
      letterSpacing: -1.4,
      height: 1.02,
    ),
    displayMedium: TextStyle(
      color: AppColors.textPrimary,
      fontFamily: CorvusType.serif,
      fontSize: 44,
      fontWeight: FontWeight.w600,
      letterSpacing: -1.0,
      height: 1.04,
    ),
    displaySmall: TextStyle(
      color: AppColors.textPrimary,
      fontFamily: CorvusType.serif,
      fontSize: 36,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.8,
      height: 1.08,
    ),
    headlineLarge: TextStyle(
      color: AppColors.textPrimary,
      fontFamily: CorvusType.serif,
      fontSize: 32,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.7,
      height: 1.1,
    ),
    headlineMedium: TextStyle(
      color: AppColors.textPrimary,
      fontFamily: CorvusType.serif,
      fontSize: 28,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
      height: 1.12,
    ),
    headlineSmall: TextStyle(
      color: AppColors.textPrimary,
      fontFamily: CorvusType.serif,
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
      height: 1.16,
    ),
    titleLarge: TextStyle(
      color: AppColors.textPrimary,
      fontFamily: CorvusType.serif,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
      height: 1.2,
    ),
    titleMedium: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.15,
    ),
    titleSmall: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.05,
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
      letterSpacing: 0.3,
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
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
    ),
  );
}
