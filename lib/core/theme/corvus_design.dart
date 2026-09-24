import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tokens de diseño de Corvus.
///
/// Un archivo premium se reconoce menos por sus colores que por su
/// consistencia: un único ritmo de espaciado, radios que se repiten, sombras
/// que insinúan profundidad sin gritar y una sola curva de movimiento.
abstract final class CorvusSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double section = 48;
}

/// Radios contenidos. Una esquina muy redonda se lee como juguete o como
/// aplicación de consumo; la editorial prefiere el ángulo apenas suavizado,
/// y reserva las curvas amplias para las capas que flotan: diálogos, hojas.
abstract final class CorvusRadius {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;
  static const double pill = 999;

  static BorderRadius all(double r) => BorderRadius.circular(r);
}

abstract final class CorvusControl {
  static const double minHeight = 44;
  static const double manuscriptWidth = 780;
}

abstract final class CorvusMotion {
  /// Micro-interacciones: hover, foco, cambio de color.
  static const Duration fast = Duration(milliseconds: 160);

  /// Transiciones de contenido: aparición de paneles y tarjetas.
  static const Duration medium = Duration(milliseconds: 260);

  /// Movimiento ceremonial: rituales, sellos, revelaciones.
  static const Duration slow = Duration(milliseconds: 420);

  /// Salida suave y decidida; es la curva por defecto de toda la app.
  static const Curve standard = Curves.easeOutCubic;

  /// Entrada con un punto de reposo, para elementos que "aterrizan".
  static const Curve entrance = Curves.easeOutQuart;
}

/// Elevación por capas. En un fondo casi negro la profundidad se construye con
/// sombra difusa y un borde superior claro, no con gris más claro.
abstract final class CorvusElevation {
  static List<BoxShadow> get low => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.30),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get medium => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.42),
          blurRadius: 30,
          offset: const Offset(0, 12),
        ),
      ];

  static List<BoxShadow> get high => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.55),
          blurRadius: 56,
          offset: const Offset(0, 24),
        ),
      ];

  /// Halo del color de la casa activa. Se usa con moderación: solo en el
  /// elemento que manda en la pantalla.
  static List<BoxShadow> glow(Color accent, {double strength = 1}) => [
        BoxShadow(
          color: accent.withValues(alpha: 0.18 * strength),
          blurRadius: 32 * strength,
          offset: Offset(0, 8 * strength),
        ),
      ];
}

/// Superficies traslúcidas sobre el fondo. Los valores son deliberadamente
/// bajos: el contraste lo aporta el borde, no el relleno.
abstract final class CorvusSurfaces {
  static Color fill(double alpha) => Colors.white.withValues(alpha: alpha);

  static const double fillSubtle = 0.02;
  static const double fillBase = 0.035;
  static const double fillRaised = 0.055;

  static const double borderSubtle = 0.055;
  static const double borderBase = 0.085;
  static const double borderStrong = 0.13;

  /// Línea de un píxel, cálida. El divisor de Corvus: nunca gris puro.
  static Color hairline([double alpha = 1]) =>
      AppColors.border.withValues(alpha: alpha);

  /// Gradiente diagonal muy leve: da a las tarjetas grandes la sensación de
  /// estar iluminadas desde arriba a la izquierda.
  static LinearGradient sheen({double strength = 1}) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.04 * strength),
          Colors.white.withValues(alpha: 0.008 * strength),
        ],
      );

  /// Gradiente teñido con el acento de la conspiración activa.
  static LinearGradient accentWash(Color accent, {double strength = 1}) =>
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withValues(alpha: 0.12 * strength),
          accent.withValues(alpha: 0.015 * strength),
        ],
      );

  /// Viñeta de página: oscurece apenas los bordes para que el contenido
  /// parezca iluminado desde el centro, como una mesa de lectura.
  static RadialGradient vignette({double strength = 1}) => RadialGradient(
        center: const Alignment(0, -0.6),
        radius: 1.4,
        colors: [
          Colors.white.withValues(alpha: 0.03 * strength),
          Colors.transparent,
        ],
      );
}

/// Tipografía editorial.
///
/// Dos voces y nada más: una serif —Lora, la misma que lee el manuscrito— para
/// todo lo que titula, y la sans del sistema para todo lo que opera. Los
/// titulares llevan peso medio y tracking negativo: el detalle que más separa
/// una interfaz cara de una genérica. Las etiquetas usan versalitas
/// espaciadas, el lenguaje del archivo.
abstract final class CorvusType {
  /// La familia serif de Corvus. Se declara aquí para que ninguna pantalla
  /// vuelva a escribir `'serif'` a mano y reciba Times en un navegador.
  static const String serif = 'CorvusLiterary';

  static const TextStyle displayLarge = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: serif,
    fontSize: 46,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.0,
    height: 1.04,
  );

  static const TextStyle display = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: serif,
    fontSize: 34,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.7,
    height: 1.08,
  );

  static const TextStyle headline = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: serif,
    fontSize: 27,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    height: 1.12,
  );

  static const TextStyle title = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: serif,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.18,
  );

  /// Cita o subtítulo en cursiva serif: la voz del archivo cuando habla bajo.
  static const TextStyle quote = TextStyle(
    color: AppColors.textSecondary,
    fontFamily: serif,
    fontSize: 16,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle subtitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 15.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.15,
  );

  static TextStyle body = TextStyle(
    color: Colors.white.withValues(alpha: 0.64),
    fontSize: 13.5,
    height: 1.6,
    letterSpacing: 0.05,
  );

  static TextStyle muted = TextStyle(
    color: Colors.white.withValues(alpha: 0.40),
    fontSize: 12.5,
    height: 1.5,
  );

  /// Versalita de sección: "LIBRO DE LAS CONSPIRACIONES".
  static TextStyle eyebrow(Color color, {double alpha = 0.72}) => TextStyle(
        color: color.withValues(alpha: alpha),
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.0,
      );

  /// Numeral editorial: posiciones, capítulos, folios.
  static TextStyle numeral(Color color, {double size = 24}) => TextStyle(
        color: color,
        fontFamily: serif,
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

/// Contenedor premium reutilizable: relleno traslúcido, borde fino, radio
/// consistente y —opcionalmente— brillo del acento activo.
class CorvusPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;
  final bool raised;
  final double radius;
  final VoidCallback? onTap;

  const CorvusPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(CorvusSpacing.lg),
    this.accent,
    this.raised = false,
    this.radius = CorvusRadius.lg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final panel = AnimatedContainer(
      duration: CorvusMotion.fast,
      curve: CorvusMotion.standard,
      padding: padding,
      decoration: BoxDecoration(
        color: raised ? AppColors.card : AppColors.surface.withValues(alpha: 0.6),
        gradient: accent != null
            ? CorvusSurfaces.accentWash(accent!, strength: raised ? 1 : 0.55)
            : CorvusSurfaces.sheen(strength: raised ? 1.1 : 0.7),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: accent != null
              ? accent!.withValues(alpha: raised ? 0.36 : 0.20)
              : CorvusSurfaces.fill(
                  raised
                      ? CorvusSurfaces.borderStrong
                      : CorvusSurfaces.borderBase,
                ),
        ),
        boxShadow: raised ? CorvusElevation.medium : null,
      ),
      child: child,
    );

    if (onTap == null) return panel;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: panel),
    );
  }
}

/// Etiqueta de sección con regla degradada. Estructura las páginas largas sin
/// el peso visual de un divisor sólido.
class CorvusSectionLabel extends StatelessWidget {
  final String label;
  final int? count;
  final Color? accent;

  const CorvusSectionLabel({
    super.key,
    required this.label,
    this.count,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Flexible: en columnas estrechas la etiqueta debe ceder antes que
        // desbordar la fila.
        Flexible(
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CorvusType.eyebrow(
              accent ?? Colors.white,
              alpha: accent != null ? 0.75 : 0.36,
            ),
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: CorvusSpacing.sm),
          Text(
            '$count',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.38),
              fontFamily: CorvusType.serif,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
        const SizedBox(width: CorvusSpacing.md),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (accent ?? Colors.white).withValues(alpha: 0.14),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// La regla editorial: una línea fina con un punto de acento en el extremo.
/// Separa bloques de lectura sin el peso de un divisor sólido.
class CorvusRule extends StatelessWidget {
  final Color? accent;
  final double indent;

  const CorvusRule({super.key, this.accent, this.indent = 0});

  @override
  Widget build(BuildContext context) {
    final tone = accent ?? Colors.white;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: indent),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 1,
            color: tone.withValues(alpha: 0.45),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
        ],
      ),
    );
  }
}
