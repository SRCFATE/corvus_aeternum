import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/corvus_design.dart';

class CorvusSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final BorderRadiusGeometry borderRadius;

  const CorvusSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderRadius =
        const BorderRadius.all(Radius.circular(CorvusRadius.md)),
  });

  @override
  Widget build(BuildContext context) {
    final surface = AnimatedContainer(
      duration: CorvusMotion.fast,
      curve: CorvusMotion.standard,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.card.withValues(alpha: 0.78),
        gradient: color == null ? CorvusSurfaces.sheen(strength: 0.8) : null,
        borderRadius: borderRadius,
        border: Border.all(
          color: CorvusSurfaces.fill(CorvusSurfaces.borderBase),
        ),
        boxShadow: CorvusElevation.low,
      ),
      child: child,
    );

    if (onTap == null) return surface;

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius.resolve(Directionality.of(context)),
        onTap: onTap,
        child: surface,
      ),
    );
  }
}

/// Cabecera de sección: versalita, titular serif y una línea de contexto.
class CorvusSectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const CorvusSectionHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: CorvusType.eyebrow(accent, alpha: 0.85),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: CorvusType.headline.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.44),
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 16),
          trailing!,
        ],
      ],
    );
  }
}

/// Un dato con su etiqueta. El número va en serif: es lo que se lee primero.
class CorvusMetric extends StatelessWidget {
  final String value;
  final String label;

  const CorvusMetric({
    super.key,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return CorvusSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: Colors.white.withValues(alpha: 0.03),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: CorvusType.numeral(AppColors.textPrimary, size: 20),
          ),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            style: CorvusType.eyebrow(Colors.white, alpha: 0.36)
                .copyWith(fontSize: 9.5, letterSpacing: 1.4),
          ),
        ],
      ),
    );
  }
}
