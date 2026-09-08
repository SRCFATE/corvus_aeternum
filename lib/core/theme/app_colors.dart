import 'package:flutter/material.dart';

abstract final class AppColors {
  // Tinta, carbón y pergamino. La temperatura cálida evita el aspecto de
  // dashboard tecnológico y acerca las superficies a una edición impresa.
  static const Color background = Color(0xFF0B0908);
  static const Color surface = Color(0xFF12100E);
  static const Color card = Color(0xFF181411);
  static const Color cardElevated = Color(0xFF211A16);
  static const Color overlay = Color(0xFF1B1613);

  // Borders
  static const Color border = Color(0xFF342820);
  static const Color borderFocus = Color(0xFF7A433D);

  // Primary — Carmesí (color de acción e identidad)
  static const Color primary = Color(0xFFB8403E);
  static const Color primaryLight = Color(0xFFD75A54);
  static const Color primaryDark = Color(0xFF762421);
  static const Color primaryMuted = Color(0xFF32100F);

  // Secondary — Púrpura profundo (secundario/decorativo)
  static const Color secondary = Color(0xFF9A744C);
  static const Color secondaryLight = Color(0xFFC19A66);
  static const Color secondaryMuted = Color(0xFF302417);

  // Accent — mismo rojo carmesí
  static const Color accent = Color(0xFFB8403E);
  static const Color accentLight = Color(0xFFD75A54);
  static const Color accentMuted = Color(0xFF32100F);

  // Text
  static const Color textPrimary = Color(0xFFF3EDE2);
  static const Color textSecondary = Color(0xFFAAA093);
  static const Color textMuted = Color(0xFF746A60);
  static const Color textDisabled = Color(0xFF49413A);

  // Semantic
  static const Color success = Color(0xFF2E7D52);
  static const Color successLight = Color(0xFF4CAF7E);
  static const Color error = Color(0xFFC62828);
  static const Color errorLight = Color(0xFFEF5350);
  static const Color warning = Color(0xFFE67E22);

  // Special
  static const Color gold = Color(0xFFD0AC62);
  static const Color silver = Color(0xFFB7B3AA);
  static const Color bronze = Color(0xFFB47B4E);

  // Transparent
  static const Color transparent = Colors.transparent;
}
