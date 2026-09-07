import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/corvus_design.dart';

/// El hueco que ocupa lo que todavía no ha llegado.
///
/// Un aro girando en mitad de una pantalla vacía dice "espera" y nada más. Un
/// esqueleto dice además "va a haber una rejilla de obras aquí, con este
/// tamaño y esta forma": la página no salta cuando llegan los datos, y la
/// espera se percibe más corta aunque dure lo mismo.
///
/// El brillo recorre la caja en vez de latir. Un latido de opacidad sobre
/// veinte tarjetas parpadea como un aviso; un barrido diagonal se lee como
/// material y no como error.
class CorvusSkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const CorvusSkeleton({
    super.key,
    this.width,
    required this.height,
    this.borderRadius,
  });

  /// Una línea de texto. El ancho fraccionario evita el efecto "párrafo de
  /// bloques idénticos", que no se parece a ningún texto real.
  const CorvusSkeleton.line({
    super.key,
    this.width,
    this.height = 12,
  }) : borderRadius = null;

  @override
  State<CorvusSkeleton> createState() => _CorvusSkeletonState();
}

class _CorvusSkeletonState extends State<CorvusSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ??
        BorderRadius.circular(widget.height <= 16 ? 4 : CorvusRadius.md);
    final base = CorvusSurfaces.fill(CorvusSurfaces.fillBase);

    final box = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(color: base, borderRadius: radius),
    );

    // Quien pidió menos movimiento recibe la caja quieta: sigue comunicando la
    // forma de lo que viene, que es la mitad del trabajo.
    if (MediaQuery.disableAnimationsOf(context)) return box;

    return ClipRRect(
      borderRadius: radius,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.transparent,
              CorvusSurfaces.fill(0.055),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
            // El barrido entra y sale del todo: de -1.5 a 1.5 en vez de 0 a 1,
            // para que haya pausa entre pasadas.
            transform: _SweepTransform(_controller.value * 3 - 1.5),
          ).createShader(bounds),
          child: box,
        ),
      ),
    );
  }
}

class _SweepTransform extends GradientTransform {
  final double slide;

  const _SweepTransform(this.slide);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * slide, 0, 0);
}

/// La rejilla de obras mientras carga. Reproduce la forma real de
/// `WorkCard`: portada dominante, título y una línea de autoría.
class CorvusSkeletonGrid extends StatelessWidget {
  final int count;
  final int crossAxisCount;
  final double childAspectRatio;
  final double spacing;

  const CorvusSkeletonGrid({
    super.key,
    this.count = 8,
    required this.crossAxisCount,
    this.childAspectRatio = 0.72,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: count,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (_, __) => const _SkeletonCard(),
    );
  }

  /// La misma rejilla como sliver, para las páginas que ya usan
  /// `CustomScrollView` y no pueden meter un `GridView` dentro.
  SliverGrid asSliver() => SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: childAspectRatio,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, __) => const _SkeletonCard(),
          childCount: count,
        ),
      );
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(CorvusRadius.md),
        border: Border.all(
          color: CorvusSurfaces.fill(CorvusSurfaces.borderSubtle),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: CorvusSkeleton(
              height: double.infinity,
              borderRadius: BorderRadius.zero,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(CorvusSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CorvusSkeleton.line(width: 120),
                const SizedBox(height: CorvusSpacing.sm),
                const CorvusSkeleton.line(width: 72, height: 9),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Filas de una lista: avatar, dos líneas. Sirve para artistas, comentarios,
/// notificaciones y foros.
class CorvusSkeletonList extends StatelessWidget {
  final int count;
  final bool hasLeading;

  const CorvusSkeletonList({
    super.key,
    this.count = 6,
    this.hasLeading = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: CorvusSpacing.md),
          child: Row(
            children: [
              if (hasLeading) ...[
                const CorvusSkeleton(
                  width: 44,
                  height: 44,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                const SizedBox(width: CorvusSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Anchos distintos por fila: un bloque de líneas idénticas
                    // se lee como una tabla, no como una lista de gente.
                    CorvusSkeleton.line(width: 140 + (i % 3) * 46),
                    const SizedBox(height: CorvusSpacing.sm),
                    CorvusSkeleton.line(width: 90 + (i % 2) * 40, height: 9),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
