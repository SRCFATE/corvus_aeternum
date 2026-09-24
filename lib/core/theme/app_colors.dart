import 'package:flutter/material.dart';

/// La paleta de Corvus.
///
/// Tinta, carbón y pergamino. Un archivo se lee sobre negro cálido, no sobre
/// el gris azulado de un panel de control: la temperatura acerca las
/// superficies a una edición impresa y hace que el marfil del texto parezca
/// papel y no pantalla. Los escalones entre fondo, superficie y tarjeta son
/// deliberadamente cortos —la profundidad la ponen las líneas finas y la
/// sombra, no el gris más claro—, y el carmesí se reserva para lo que manda.
abstract final class AppColors {
  // Fondo y superficies, de la más profunda a la más elevada.
  static const Color background = Color(0xFF0A0908);
  static const Color surface = Color(0xFF110F0D);
  static const Color card = Color(0xFF171412);
  static const Color cardElevated = Color(0xFF1F1B17);
  static const Color overlay = Color(0xFF1A1613);

  // Líneas. Finas y cálidas; el contraste viene del borde, no del relleno.
  static const Color border = Color(0xFF2E2620);
  static const Color borderFocus = Color(0xFF6E3B37);

  // Primario — carmesí de tinta. Acción, identidad y nada más.
  static const Color primary = Color(0xFFB2413E);
  static const Color primaryLight = Color(0xFFD25C57);
  static const Color primaryDark = Color(0xFF6E2522);
  static const Color primaryMuted = Color(0xFF2C1110);

  // Secundario — ocre de encuadernación. Decorativo, nunca de acción.
  static const Color secondary = Color(0xFF9A7A54);
  static const Color secondaryLight = Color(0xFFC4A16E);
  static const Color secondaryMuted = Color(0xFF2C2218);

  // Acento — el mismo carmesí.
  static const Color accent = primary;
  static const Color accentLight = primaryLight;
  static const Color accentMuted = primaryMuted;

  // Texto. Marfil, no blanco: el blanco puro sobre negro vibra en pantallas
  // OLED y cansa a la tercera página.
  static const Color textPrimary = Color(0xFFF1EBE0);
  static const Color textSecondary = Color(0xFFA89E91);
  static const Color textMuted = Color(0xFF6F665C);
  static const Color textDisabled = Color(0xFF453E38);

  // Semánticos, apagados a la misma temperatura que el resto.
  static const Color success = Color(0xFF3A7D5A);
  static const Color successLight = Color(0xFF5FB088);
  static const Color error = Color(0xFFB83B3B);
  static const Color errorLight = Color(0xFFE05F5F);
  static const Color warning = Color(0xFFD08A3C);

  // Metales, para insignias y posiciones.
  static const Color gold = Color(0xFFCFAE66);
  static const Color silver = Color(0xFFB5B1A8);
  static const Color bronze = Color(0xFFB07A50);

  // Transparent
  static const Color transparent = Colors.transparent;
}
