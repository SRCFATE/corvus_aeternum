import 'package:flutter/material.dart';

import '../../core/theme/corvus_breakpoints.dart';

/// Los tres anchos de página de Corvus.
///
/// El margen lateral dejó de ser un número fijo. Cuarenta píxeles a cada lado
/// son elegantes en un monitor y una amputación en un teléfono de 360: se
/// comen casi un cuarto del ancho útil, y una rejilla de obras que ya venía
/// apretada se queda sin sitio para la segunda columna. Ahora sale de
/// [CorvusLayout], igual que las columnas de las rejillas, así que el margen y
/// el número de columnas cambian a la vez y por el mismo motivo.
///
/// Quien necesite un margen propio sigue pudiendo pasarlo; lo que ya no hay es
/// un valor de escritorio aplicado a ciegas en todas partes.
class CorvusPage extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const CorvusPage({
    super.key,
    required this.child,
    this.padding,
  });

  static const double maxWidth = 1400;

  @override
  Widget build(BuildContext context) => _Constrained(
        maxWidth: maxWidth,
        padding: padding,
        child: child,
      );
}

/// Páginas de lectura — Perfil, Obra, Colección.
///
/// Más estrechas a propósito: una línea de texto que pasa de unos setenta y
/// cinco caracteres deja de leerse cómodamente, por mucho monitor que haya.
class CorvusReadingPage extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const CorvusReadingPage({
    super.key,
    required this.child,
    this.padding,
  });

  static const double maxWidth = 1000;

  @override
  Widget build(BuildContext context) => _Constrained(
        maxWidth: maxWidth,
        padding: padding,
        // El aire vertical es parte de la lectura; el horizontal lo pone el
        // ancho de ventana.
        extraVertical: 32,
        child: child,
      );
}

/// Páginas de formulario — Publicar obra, Crear colección, Editar perfil.
class CorvusFormPage extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const CorvusFormPage({
    super.key,
    required this.child,
    this.padding,
  });

  static const double maxWidth = 1200;

  @override
  Widget build(BuildContext context) => _Constrained(
        maxWidth: maxWidth,
        padding: padding,
        child: child,
      );
}

class _Constrained extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final double extraVertical;

  const _Constrained({
    required this.child,
    required this.maxWidth,
    this.padding,
    this.extraVertical = 0,
  });

  @override
  Widget build(BuildContext context) {
    final gutter = CorvusLayout.of(context).pageGutter;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ??
              EdgeInsets.symmetric(
                horizontal: gutter,
                vertical: extraVertical,
              ),
          child: child,
        ),
      ),
    );
  }
}
