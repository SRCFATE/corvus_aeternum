import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/conspiration_provider.dart';

/// Tarjeta con efecto glassmorphism tintada por la conspiración activa.
///
/// Usa [BackdropFilter] con blur, fondo semi-transparente del color de
/// la conspiración (20 % de la paleta) y borde sutil de acento (10 %).
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final double blurSigma;
  final double backgroundOpacity;
  final double borderOpacity;
  final Color? overrideAccent;
  final Color? overrideBase;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.blurSigma = 14,
    this.backgroundOpacity = 0.12,
    this.borderOpacity = 0.18,
    this.overrideAccent,
    this.overrideBase,
    this.onTap,
    this.width,
    this.height,
    this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<ConspirationProvider>();
    final accent = overrideAccent ?? cp.accent;
    final base = overrideBase ?? cp.surface;
    final radius = borderRadius ?? cp.uiRounding;

    final container = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          width: width,
          height: height,
          constraints: constraints,
          decoration: BoxDecoration(
            color: base.withValues(alpha: backgroundOpacity),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: accent.withValues(alpha: borderOpacity),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: padding != null
              ? Padding(padding: padding!, child: child)
              : child,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: container);
    }
    return container;
  }
}

/// Versión sin blur para superficies sobre fondos sólidos.
class SolidGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final Color? overrideAccent;
  final Color? overrideBase;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const SolidGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.overrideAccent,
    this.overrideBase,
    this.onTap,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<ConspirationProvider>();
    final accent = overrideAccent ?? cp.accent;
    final base = overrideBase ?? cp.card;
    final radius = borderRadius ?? cp.uiRounding;

    final container = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: accent.withValues(alpha: 0.22),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: padding != null
          ? Padding(padding: padding!, child: child)
          : child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: container);
    }
    return container;
  }
}
