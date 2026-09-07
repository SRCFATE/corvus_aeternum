import 'package:flutter/widgets.dart';

/// Los anchos en los que Corvus cambia de forma.
///
/// Antes de este archivo había veintitrés umbrales distintos repartidos por la
/// app —`width < 700` aquí, `width >= 720` allá—, lo que hacía que dos páginas
/// vecinas cambiaran de diseño en momentos distintos al arrastrar la ventana.
/// Cuatro clases bastan, y son las mismas que usa Material 3.
abstract final class CorvusBreakpoints {
  /// Teléfono en vertical. Una sola columna, navegación inferior.
  static const double compact = 600;

  /// Teléfono en horizontal y tableta estrecha.
  static const double medium = 905;

  /// Escritorio. Aquí aparece la barra superior completa.
  static const double expanded = 1240;

  /// Monitor grande: el contenido deja de crecer y empieza a respirar.
  static const double large = 1640;

  /// Ancho a partir del cual cabe la barra superior completa —seis destinos,
  /// buscador, avisos y el botón de crear— sin que nada se apriete.
  ///
  /// Es una pregunta distinta de la de las clases de ventana: aquélla decide
  /// cuántas columnas caben, ésta decide si la navegación puede ser una fila
  /// horizontal o tiene que bajar al pulgar. Una ventana de escritorio
  /// estrecha, de 900 px, sigue mereciendo la barra entera.
  static const double fullNavigation = 720;
}

enum CorvusWindowSize {
  compact,
  medium,
  expanded,
  large;

  bool get isCompact => this == CorvusWindowSize.compact;
  bool get isMedium => this == CorvusWindowSize.medium;

  /// Teléfono y tableta estrecha comparten navegación táctil.
  bool get isHandheld => index <= CorvusWindowSize.medium.index;

  /// A partir de aquí hay sitio para la barra de navegación completa.
  bool get isDesktop => index >= CorvusWindowSize.expanded.index;
}

/// Cómo se comporta el diseño a este ancho. Se lee con
/// `CorvusLayout.of(context)` y se usa en vez de comparar píxeles a mano.
class CorvusLayout {
  final CorvusWindowSize size;
  final double width;

  const CorvusLayout._(this.size, this.width);

  factory CorvusLayout.of(BuildContext context) =>
      CorvusLayout.forWidth(MediaQuery.sizeOf(context).width);

  factory CorvusLayout.forWidth(double width) {
    final CorvusWindowSize size;
    if (width < CorvusBreakpoints.compact) {
      size = CorvusWindowSize.compact;
    } else if (width < CorvusBreakpoints.medium) {
      size = CorvusWindowSize.medium;
    } else if (width < CorvusBreakpoints.large) {
      size = CorvusWindowSize.expanded;
    } else {
      size = CorvusWindowSize.large;
    }
    return CorvusLayout._(size, width);
  }

  bool get isCompact => size.isCompact;
  bool get isHandheld => size.isHandheld;
  bool get isDesktop => size.isDesktop;

  /// Si cabe la barra superior con todos sus destinos. Por debajo, la
  /// navegación baja a una barra inferior y un cajón.
  bool get hasFullNavigation => width >= CorvusBreakpoints.fullNavigation;

  /// El margen lateral de una página. En un teléfono, cuarenta píxeles a cada
  /// lado se comen un tercio de la pantalla; en un monitor, dieciséis dejan el
  /// texto pegado al borde.
  double get pageGutter => switch (size) {
        CorvusWindowSize.compact => 16,
        CorvusWindowSize.medium => 24,
        CorvusWindowSize.expanded => 40,
        CorvusWindowSize.large => 56,
      };

  /// Separación entre bloques de una misma página.
  double get sectionGap => switch (size) {
        CorvusWindowSize.compact => 28,
        CorvusWindowSize.medium => 36,
        _ => 48,
      };

  /// Columnas de una rejilla de obra. El criterio es el ancho de la tarjeta,
  /// no la clase de ventana: una tarjeta de obra por debajo de ~190 px deja de
  /// leerse.
  int gridColumns({double target = 240, int min = 2, int max = 6}) {
    final usable = width - pageGutter * 2;
    final columns = (usable / target).floor();

    return columns.clamp(min, max);
  }

  /// Escala tipográfica del titular principal. Un display de 34 px pensado
  /// para escritorio desborda en un teléfono de 360 px de ancho.
  double get displayScale => switch (size) {
        CorvusWindowSize.compact => 0.78,
        CorvusWindowSize.medium => 0.9,
        _ => 1.0,
      };
}
