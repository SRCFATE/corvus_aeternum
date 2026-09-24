import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/corvus_design.dart';

/// La marca de Corvus, en una sola pieza reutilizable.
///
/// Antes cada pantalla dibujaba la suya: un destello de Material dentro de un
/// cuadrado rojo en la barra, otro distinto en el acceso. Una marca que cambia
/// de forma según la puerta por la que entras no es una marca. Ésta es un
/// monograma serif dentro de un marco fino —el sello de un archivo, no el
/// icono de una aplicación— y el nombre en la misma serif de los titulares.
class CorvusBrandMark extends StatelessWidget {
  final double size;
  final Color? accent;

  const CorvusBrandMark({super.key, this.size = 30, this.accent});

  @override
  Widget build(BuildContext context) {
    final tone = accent ?? Theme.of(context).colorScheme.primary;
    final radius = size * 0.28;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tone.withValues(alpha: 0.22),
            tone.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: tone.withValues(alpha: 0.42), width: 1),
        boxShadow: [
          BoxShadow(
            color: tone.withValues(alpha: 0.14),
            blurRadius: size * 0.6,
            offset: Offset(0, size * 0.18),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'C',
          style: TextStyle(
            color: Color.lerp(tone, AppColors.textPrimary, 0.35),
            fontFamily: CorvusType.serif,
            fontSize: size * 0.60,
            fontWeight: FontWeight.w600,
            height: 1,
            // El sello lleva la cursiva: es la firma, no la firma impresa.
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

/// El nombre. En horizontal para las barras; apilado para las portadas.
class CorvusWordmark extends StatelessWidget {
  final bool compact;
  final bool stacked;
  final double scale;

  const CorvusWordmark({
    super.key,
    this.compact = false,
    this.stacked = false,
    this.scale = 1,
  });

  @override
  Widget build(BuildContext context) {
    final name = Text(
      'Corvus',
      style: TextStyle(
        color: AppColors.textPrimary,
        fontFamily: CorvusType.serif,
        fontSize: 17 * scale,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3 * scale,
        height: 1,
      ),
    );

    if (compact) return name;

    final surname = Text(
      'AETERNUM',
      style: TextStyle(
        color: AppColors.textMuted,
        fontSize: 8.5 * scale,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.6 * scale,
        height: 1,
      ),
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          name,
          SizedBox(height: 5 * scale),
          surname,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        name,
        SizedBox(width: 7 * scale),
        surname,
      ],
    );
  }
}

/// Marca y nombre juntos, como aparecen en las barras.
class CorvusBrand extends StatelessWidget {
  final bool compact;
  final bool showName;
  final double markSize;

  const CorvusBrand({
    super.key,
    this.compact = false,
    this.showName = true,
    this.markSize = 30,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CorvusBrandMark(size: markSize),
        if (showName) ...[
          const SizedBox(width: 10),
          CorvusWordmark(compact: compact),
        ],
      ],
    );
  }
}
