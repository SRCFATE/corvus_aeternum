import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Marco visual compartido por las pantallas de acceso (entrar, registrarse y
/// recuperar contraseña). Estaba duplicado entre login y registro.

class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.8, -0.9),
                radius: 1.2,
                colors: [
                  AppColors.primary.withValues(alpha: 0.16),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -140,
          left: -120,
          child: Container(
            width: 360,
            height: 360,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondary.withValues(alpha: 0.08),
            ),
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
    return Container(
      height: 560,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthMiniLogo(),
          const Spacer(flex:2),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 46,
              height: 0.95,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.4,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.48),
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const Spacer(flex: 3,)
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
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AuthMiniLogo extends StatelessWidget {
  const AuthMiniLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.30)),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CORVUS',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.2,
              ),
            ),
            Text(
              'AETERNUM',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                letterSpacing: 3.4,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
