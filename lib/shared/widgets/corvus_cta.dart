import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/corvus_breakpoints.dart';
import '../../core/theme/corvus_design.dart';
import '../../providers/auth_provider.dart';
import 'corvus_motion.dart';

/// La invitación, repetida donde toca.
///
/// Corvus es abierto para mirar y con sesión para participar, y esa frontera
/// se cruza leyendo: alguien llega por el enlace a una obra, baja, y en algún
/// punto decide quedarse. Si la única puerta está en la barra superior, ese
/// momento pasa sin puerta delante.
///
/// La regla para no volverlo publicidad: **el mensaje depende de quién mira**.
/// A un visitante se le ofrece entrar; a un artista con sesión, publicar; a
/// quien ya publica, lo siguiente. Nunca se le pide a nadie algo que ya hizo.
enum CorvusCtaTone {
  /// Banda ancha con acento. Para el final de una página larga.
  prominent,

  /// Línea discreta, insertada entre bloques de contenido.
  inline,
}

class CorvusCta extends StatelessWidget {
  final CorvusCtaTone tone;

  /// Texto propio de la pantalla. Sin él se usa el que corresponde a la
  /// sesión, que es lo habitual.
  final String? eyebrow;
  final String? title;
  final String? body;
  final String? actionLabel;
  final String? route;
  final VoidCallback? onAction;
  final IconData? icon;

  const CorvusCta({
    super.key,
    this.tone = CorvusCtaTone.prominent,
    this.eyebrow,
    this.title,
    this.body,
    this.actionLabel,
    this.route,
    this.onAction,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final accent = Theme.of(context).colorScheme.primary;
    final layout = CorvusLayout.of(context);
    final copy = _copyFor(auth);

    final action = onAction ??
        () {
          final destination = route ?? copy.route;
          // Un visitante que pulsa desde media página vuelve a media página:
          // el destino se conserva en el parámetro que ya entiende el router.
          if (!auth.isAuthenticated && destination != '/login') {
            context.go('/login?redirect=${Uri.encodeComponent(destination)}');
          } else {
            context.go(destination);
          }
        };

    if (tone == CorvusCtaTone.inline) {
      return _InlineCta(
        label: actionLabel ?? copy.action,
        title: title ?? copy.title,
        accent: accent,
        onTap: action,
      );
    }

    final stacked = layout.isCompact;

    return CorvusScrollReveal(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: stacked ? CorvusSpacing.lg : CorvusSpacing.xl,
          vertical: stacked ? CorvusSpacing.xl : CorvusSpacing.xxl,
        ),
        decoration: BoxDecoration(
          gradient: CorvusSurfaces.accentWash(accent, strength: 0.85),
          borderRadius: BorderRadius.circular(CorvusRadius.xl),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
        ),
        child: Flex(
          direction: stacked ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment:
              stacked ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: stacked ? 0 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (eyebrow ?? copy.eyebrow).toUpperCase(),
                    style: CorvusType.eyebrow(accent),
                  ),
                  const SizedBox(height: CorvusSpacing.md),
                  Text(
                    title ?? copy.title,
                    style: CorvusType.title.copyWith(
                      fontSize: 22 * layout.displayScale + 2,
                    ),
                  ),
                  const SizedBox(height: CorvusSpacing.sm),
                  Text(body ?? copy.body, style: CorvusType.body),
                ],
              ),
            ),
            SizedBox(
              width: stacked ? 0 : CorvusSpacing.xl,
              height: stacked ? CorvusSpacing.lg : 0,
            ),
            _CtaButton(
              label: actionLabel ?? copy.action,
              icon: icon ?? copy.icon,
              accent: accent,
              expand: stacked,
              onTap: action,
            ),
          ],
        ),
      ),
    );
  }

  _CtaCopy _copyFor(AuthProvider auth) {
    if (!auth.isAuthenticated) {
      return const _CtaCopy(
        eyebrow: 'Únete al archivo',
        title: 'Tu obra también merece un registro.',
        body:
            'Crear la cuenta es gratis y te da lo esencial de Atelier: '
            'proyectos ilimitados, worldbuilding y exportación.',
        action: 'Crear mi cuenta',
        route: '/register',
        icon: Icons.auto_awesome_rounded,
      );
    }

    final publishes = (auth.profile?.worksCount ?? 0) > 0;

    if (publishes) {
      return const _CtaCopy(
        eyebrow: 'Sigue el rastro',
        title: 'Lo que escribes hoy es el archivo de mañana.',
        body:
            'Abre Atelier y continúa donde lo dejaste, o publica una pieza '
            'nueva en el archivo vivo.',
        action: 'Ir a Atelier',
        route: '/atelier',
        icon: Icons.auto_stories_rounded,
      );
    }

    return const _CtaCopy(
      eyebrow: 'Primera pieza',
      title: 'El archivo empieza cuando publicas.',
      body:
          'Sube una obra, un texto o una pieza sonora. Queda registrada a tu '
          'nombre, con fecha, y ya no se pierde.',
      action: 'Publicar mi primera obra',
      route: '/upload',
      icon: Icons.add_rounded,
    );
  }
}

class _CtaCopy {
  final String eyebrow;
  final String title;
  final String body;
  final String action;
  final String route;
  final IconData icon;

  const _CtaCopy({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.action,
    required this.route,
    required this.icon,
  });
}

class _CtaButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final bool expand;
  final VoidCallback onTap;

  const _CtaButton({
    required this.label,
    required this.icon,
    required this.accent,
    required this.expand,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CorvusPressable(
      onTap: onTap,
      haptics: true,
      hoverScale: 1.03,
      hoverLift: 2,
      glow: accent,
      borderRadius: BorderRadius.circular(CorvusRadius.pill),
      child: Container(
        width: expand ? double.infinity : null,
        padding: const EdgeInsets.symmetric(
          horizontal: CorvusSpacing.xl,
          vertical: 15,
        ),
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(CorvusRadius.pill),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.background),
            const SizedBox(width: CorvusSpacing.sm),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.background,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La versión de una línea. Va entre secciones, donde una banda entera
/// rompería la lectura.
class _InlineCta extends StatelessWidget {
  final String title;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _InlineCta({
    required this.title,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CorvusScrollReveal(
      child: CorvusPressable(
        onTap: onTap,
        hoverScale: 1.006,
        hoverLift: 1,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: CorvusSpacing.lg,
            vertical: CorvusSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: CorvusSurfaces.fill(CorvusSurfaces.fillSubtle),
            borderRadius: BorderRadius.circular(CorvusRadius.lg),
            border: Border.all(color: accent.withValues(alpha: 0.16)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: CorvusType.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: CorvusSpacing.lg),
              Text(
                label,
                style: TextStyle(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: CorvusSpacing.xs),
              Icon(Icons.arrow_forward_rounded, size: 15, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
