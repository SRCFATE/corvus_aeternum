import 'package:flutter/material.dart';

abstract final class AppColors {
  // Backgrounds — muy oscuros, sin sesgo azul/púrpura
  static const Color background = Color(0xFF09090C);
  static const Color surface = Color(0xFF100C14);
  static const Color card = Color(0xFF140E18);
  static const Color cardElevated = Color(0xFF1C1420);
  static const Color overlay = Color(0xFF1A1220);

  // Borders
  static const Color border = Color(0xFF2A1A2E);
  static const Color borderFocus = Color(0xFF5A2A3A);

  // Primary — Carmesí (color de acción e identidad)
  static const Color primary = Color(0xFFCC3333);
  static const Color primaryLight = Color(0xFFE04848);
  static const Color primaryDark = Color(0xFF8B1A1A);
  static const Color primaryMuted = Color(0xFF300808);

  // Secondary — Púrpura profundo (secundario/decorativo)
  static const Color secondary = Color(0xFF7B5FBF);
  static const Color secondaryLight = Color(0xFF9B7FDF);
  static const Color secondaryMuted = Color(0xFF2A1A50);

  // Accent — mismo rojo carmesí
  static const Color accent = Color(0xFFCC3333);
  static const Color accentLight = Color(0xFFE04848);
  static const Color accentMuted = Color(0xFF300808);

  // Text
  static const Color textPrimary = Color(0xFFF0EEE6);
  static const Color textSecondary = Color(0xFF8A8090);
  static const Color textMuted = Color(0xFF504858);
  static const Color textDisabled = Color(0xFF342E3C);

  // Semantic
  static const Color success = Color(0xFF2E7D52);
  static const Color successLight = Color(0xFF4CAF7E);
  static const Color error = Color(0xFFC62828);
  static const Color errorLight = Color(0xFFEF5350);
  static const Color warning = Color(0xFFE67E22);

  // Special
  static const Color gold = Color(0xFFC9A84C);
  static const Color silver = Color(0xFF9BA3B0);
  static const Color bronze = Color(0xFFAD7B40);

  // Transparent
  static const Color transparent = Colors.transparent;
}
