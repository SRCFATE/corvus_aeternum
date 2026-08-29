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

abstract final class CorvusRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double pill = 999;

  static BorderRadius all(double r) => BorderRadius.circular(r);
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
          color: Colors.black.withValues(alpha: 0.28),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get medium => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.38),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
      ];

  static List<BoxShadow> get high => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.50),
          blurRadius: 48,
          offset: const Offset(0, 20),
        ),
      ];

  /// Halo del color de la casa activa. Se usa con moderación: solo en el
  /// elemento que manda en la pantalla.
  static List<BoxShadow> glow(Color accent, {double strength = 1}) => [
        BoxShadow(
          color: accent.withValues(alpha: 0.22 * strength),
          blurRadius: 32 * strength,
          offset: Offset(0, 8 * strength),
        ),
      ];
}

/// Superficies traslúcidas sobre el fondo. Los valores son deliberadamente
/// bajos: el contraste lo aporta el borde, no el relleno.
abstract final class CorvusSurfaces {
  static Color fill(double alpha) => Colors.white.withValues(alpha: alpha);

  static const double fillSubtle = 0.025;
  static const double fillBase = 0.04;
  static const double fillRaised = 0.06;

  static const double borderSubtle = 0.06;
  static const double borderBase = 0.09;
  static const double borderStrong = 0.14;

  /// Gradiente diagonal muy leve: da a las tarjetas grandes la sensación de
  /// estar iluminadas desde arriba a la izquierda.
  static LinearGradient sheen({double strength = 1}) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.045 * strength),
          Colors.white.withValues(alpha: 0.012 * strength),
        ],
      );

  /// Gradiente teñido con el acento de la conspiración activa.
  static LinearGradient accentWash(Color accent, {double strength = 1}) =>
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withValues(alpha: 0.14 * strength),
          accent.withValues(alpha: 0.02 * strength),
        ],
      );
}

/// Tipografía editorial. Los títulos usan tracking negativo —el detalle que
/// más separa una interfaz cara de una genérica— y las etiquetas usan
/// versalitas espaciadas, el lenguaje del archivo.
abstract final class CorvusType {
  static const TextStyle display = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 34,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.0,
    height: 1.05,
  );

  static const TextStyle title = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.15,
  );

  static const TextStyle subtitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 15.5,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  static TextStyle body = TextStyle(
    color: Colors.white.withValues(alpha: 0.62),
    fontSize: 13.5,
    height: 1.6,
    letterSpacing: 0.05,
  );

  static TextStyle muted = TextStyle(
    color: Colors.white.withValues(alpha: 0.38),
    fontSize: 12.5,
    height: 1.5,
  );

  /// Versalita de sección: "LIBRO DE LAS CONSPIRACIONES".
  static TextStyle eyebrow(Color color, {double alpha = 0.70}) => TextStyle(
        color: color.withValues(alpha: alpha),
        fontSize: 10.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.8,
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
        gradient: accent != null
            ? CorvusSurfaces.accentWash(accent!, strength: raised ? 1 : 0.55)
            : CorvusSurfaces.sheen(strength: raised ? 1.2 : 0.8),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: accent != null
              ? accent!.withValues(alpha: raised ? 0.38 : 0.20)
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
              alpha: accent != null ? 0.75 : 0.34,
            ),
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: CorvusSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: CorvusSurfaces.fill(CorvusSurfaces.fillBase),
              borderRadius: BorderRadius.circular(CorvusRadius.pill),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
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
                  (accent ?? Colors.white).withValues(alpha: 0.16),
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
