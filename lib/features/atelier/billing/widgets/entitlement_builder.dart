import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/corvus_design.dart';
import '../../../../providers/entitlement_provider.dart';
import '../services/entitlement_service.dart';
import 'upgrade_prompt.dart';

/// Acceso a los derechos desde la interfaz, sin que ningún widget tenga que
/// saber qué es un plan.
///
/// Es el sustituto de `if (user.isPro)`: el widget pregunta por la FUNCIÓN que
/// necesita —comparar versiones, exportar en PDF— y nunca por el nombre del
/// nivel que la incluye. Así, mover una función de Professional a Free —o al
/// revés— es una fila en `plan_entitlements`, no una búsqueda por el código.
class EntitlementBuilder extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    EntitlementService service,
    EntitlementCheck check,
  ) builder;

  final String featureKey;

  /// Cuántos se llevan usados, para los derechos con tope.
  final int currentCount;

  const EntitlementBuilder({
    super.key,
    required this.featureKey,
    required this.builder,
    this.currentCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EntitlementProvider>();
    final service = provider.service;

    return builder(
      context,
      service,
      service.canUse(featureKey, currentCount: currentCount),
    );
  }
}

/// Una función profesional presentada con honestidad.
///
/// No esconde nada ni interrumpe: el control sigue ahí, con su nombre y su
/// forma, apagado y con un candado pequeño. Al tocarlo se explica en una línea
/// qué lo incluye y se ofrece verlo o seguir trabajando. Ni un popup al entrar,
/// ni una pantalla completa a media escena.
class FeatureGate extends StatelessWidget {
  final String featureKey;
  final Widget child;

  /// Qué se muestra en lugar del control cuando no está incluido. Si es null,
  /// se apaga el propio `child` y se le pone el candado encima.
  final Widget? locked;

  /// Nombre de la función en la voz de Corvus, para el aviso.
  final String title;
  final String? description;

  /// Cuántos se llevan usados, para los derechos con tope.
  final int currentCount;

  /// Desde dónde se pidió, para la analítica del embudo.
  final String surface;

  /// Mientras los derechos no han llegado, no se pinta un candado: sería
  /// mentirle a quien sí paga durante el primer segundo de la sesión.
  final bool optimisticWhileLoading;

  const FeatureGate({
    super.key,
    required this.featureKey,
    required this.child,
    required this.title,
    this.description,
    this.locked,
    this.currentCount = 0,
    this.surface = 'atelier',
    this.optimisticWhileLoading = true,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EntitlementProvider>();

    if (!provider.hydrated && optimisticWhileLoading) return child;

    final check = provider.service.canUse(featureKey, currentCount: currentCount);
    if (check.allowed) return child;

    if (locked != null) return locked!;

    return _LockedControl(
      featureKey: featureKey,
      title: title,
      description: description,
      check: check,
      surface: surface,
      child: child,
    );
  }
}

class _LockedControl extends StatelessWidget {
  final String featureKey;
  final String title;
  final String? description;
  final EntitlementCheck check;
  final String surface;
  final Widget child;

  const _LockedControl({
    required this.featureKey,
    required this.title,
    required this.description,
    required this.check,
    required this.surface,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: upgradeMessageFor(title, check),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => showUpgradePrompt(
            context,
            featureKey: featureKey,
            title: title,
            description: description,
            check: check,
            surface: surface,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // IgnorePointer, no Visibility: el control sigue ocupando su
              // sitio y conservando su forma, así que la pantalla no cambia
              // de composición según el plan.
              Opacity(
                opacity: 0.42,
                child: IgnorePointer(child: child),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 11,
                    color: AppColors.gold.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aviso en línea, del tamaño de una frase, para cuando el control no cabe
/// apagado y hace falta explicar el hueco.
class FeatureNotice extends StatelessWidget {
  final String title;
  final String featureKey;
  final EntitlementCheck check;
  final String surface;

  const FeatureNotice({
    super.key,
    required this.title,
    required this.featureKey,
    required this.check,
    this.surface = 'atelier',
  });

  @override
  Widget build(BuildContext context) {
    return CorvusPanel(
      accent: AppColors.gold,
      padding: const EdgeInsets.symmetric(
        horizontal: CorvusSpacing.lg,
        vertical: CorvusSpacing.md,
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 16,
            color: AppColors.gold.withValues(alpha: 0.8),
          ),
          const SizedBox(width: CorvusSpacing.md),
          Expanded(
            child: Text(
              upgradeMessageFor(title, check),
              style: CorvusType.body,
            ),
          ),
          const SizedBox(width: CorvusSpacing.md),
          TextButton(
            onPressed: () => showUpgradePrompt(
              context,
              featureKey: featureKey,
              title: title,
              check: check,
              surface: surface,
            ),
            child: const Text('Ver planes'),
          ),
        ],
      ),
    );
  }
}
