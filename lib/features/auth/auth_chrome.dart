import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/corvus_design.dart';
import '../../shared/widgets/corvus_brand.dart';

/// Marco visual compartido por las pantallas de acceso (entrar, registrarse y
/// recuperar contraseña). Estaba duplicado entre login y registro.

class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Stack(
      children: [
        // Una sola fuente de luz, arriba a la derecha, del color de la casa.
        // Un segundo círculo de otro color abajo convertía la pantalla en un
        // fondo de aplicación de consumo; una lámpara basta.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.85, -1.0),
                radius: 1.25,
                colors: [
                  accent.withValues(alpha: 0.13),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: CorvusSurfaces.vignette()),
          ),
        ),
      ],
    );
  }
}

class AuthBrandPanel extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthBrandPanel({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      height: 560,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.55),
        gradient: CorvusSurfaces.sheen(strength: 0.9),
        borderRadius: BorderRadius.circular(CorvusRadius.xl),
        border: Border.all(
          color: CorvusSurfaces.fill(CorvusSurfaces.borderBase),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthMiniLogo(),
          const Spacer(flex: 2),
          Text(
            'ARCHIVO VIVO · DESDE 2026',
            style: CorvusType.eyebrow(accent),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: CorvusType.displayLarge.copyWith(fontSize: 50, height: 1.0),
          ),
          const SizedBox(height: 20),
          CorvusRule(accent: accent),
          const SizedBox(height: 20),
          Text(
            subtitle,
            style: CorvusType.quote.copyWith(
              fontSize: 17,
              color: Colors.white.withValues(alpha: 0.56),
            ),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

class AuthGlassCard extends StatelessWidget {
  final Widget child;

  const AuthGlassCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(CorvusRadius.xl),
        border: Border.all(
          color: CorvusSurfaces.fill(CorvusSurfaces.borderBase),
        ),
        boxShadow: CorvusElevation.high,
      ),
      child: child,
    );
  }
}

class AuthMiniLogo extends StatelessWidget {
  const AuthMiniLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        CorvusBrandMark(size: 44),
        SizedBox(width: 14),
        CorvusWordmark(stacked: true, scale: 1.15),
      ],
    );
  }
}

/// Titular de las tarjetas de acceso: serif, con su línea de contexto.
class AuthHeading extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthHeading({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: CorvusType.display.copyWith(fontSize: 32)),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 15,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}
