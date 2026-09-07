import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/corvus_design.dart';
import '../../../../providers/entitlement_provider.dart';
import '../domain/feature_keys.dart';
import '../services/entitlement_service.dart';

/// Una línea sobria que explica de dónde viene el límite. Sin urgencia, sin
/// cuenta atrás, sin exclamaciones.
String upgradeMessageFor(String title, EntitlementCheck check) {
  switch (check.reason) {
    case GateReason.limitReached:
      return '$title: has usado ${check.used} de ${check.limit}.';
    case GateReason.quotaExceeded:
      return 'No queda espacio para archivos nuevos. Nada de lo guardado se borra.';
    case GateReason.notIncluded:
    case GateReason.allowed:
      final plan = EntitlementService.planForFeature(check.featureKey) ==
              PlanCode.teams
          ? 'Atelier Teams'
          : 'Atelier Professional';
      return '$title está incluido en $plan.';
  }
}

/// El upsell contextual de Corvus.
///
/// Aparece **solo** cuando alguien intenta usar algo que su plan no incluye, y
/// nunca por su cuenta. Dos botones y ninguna cuenta atrás: «Ver Professional»
/// y «Ahora no». El segundo es un botón de verdad, con el mismo peso visual
/// que el primero, porque «ahora no» es una respuesta legítima y esconderla
/// sería el tipo de truco que este producto no usa.
Future<void> showUpgradePrompt(
  BuildContext context, {
  required String featureKey,
  required String title,
  required EntitlementCheck check,
  String? description,
  String surface = 'atelier',
}) async {
  final entitlements = context.read<EntitlementProvider>();

  unawaited(entitlements.track(
    BillingEvent.featureGateSeen,
    properties: {'feature_key': featureKey, 'surface': surface},
  ));

  final planCode = EntitlementService.planForFeature(featureKey);

  final wantsPlans = await showDialog<bool>(
    context: context,
    builder: (context) => _UpgradeDialog(
      title: title,
      description: description,
      check: check,
      planCode: planCode,
    ),
  );

  if (wantsPlans != true || !context.mounted) return;

  unawaited(entitlements.track(
    BillingEvent.upgradeClicked,
    properties: {
      'feature_key': featureKey,
      'plan_code': planCode,
      'surface': surface,
    },
  ));

  context.push('/plans?feature=$featureKey');
}

class _UpgradeDialog extends StatelessWidget {
  final String title;
  final String? description;
  final EntitlementCheck check;
  final String planCode;

  const _UpgradeDialog({
    required this.title,
    required this.description,
    required this.check,
    required this.planCode,
  });

  @override
  Widget build(BuildContext context) {
    final planName =
        planCode == PlanCode.teams ? 'Atelier Teams' : 'Atelier Professional';

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CorvusRadius.xl),
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.22)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(CorvusSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                planName.toUpperCase(),
                style: CorvusType.eyebrow(AppColors.gold),
              ),
              const SizedBox(height: CorvusSpacing.md),
              Text(title, style: CorvusType.title),
              const SizedBox(height: CorvusSpacing.md),
              Text(
                description ?? upgradeMessageFor(title, check),
                style: CorvusType.body,
              ),
              if (check.reason == GateReason.limitReached) ...[
                const SizedBox(height: CorvusSpacing.md),
                _LimitLine(check: check),
              ],
              const SizedBox(height: CorvusSpacing.xl),
              // Tu obra no se toca: lo que ya existe sigue existiendo.
              Container(
                padding: const EdgeInsets.all(CorvusSpacing.md),
                decoration: BoxDecoration(
                  color: CorvusSurfaces.fill(CorvusSurfaces.fillSubtle),
                  borderRadius: BorderRadius.circular(CorvusRadius.md),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 15,
                      color: Colors.white.withValues(alpha: 0.32),
                    ),
                    const SizedBox(width: CorvusSpacing.sm),
                    Expanded(
                      child: Text(
                        'Escribir, construir mundos y exportar tu obra seguirá '
                        'siendo gratis siempre.',
                        style: CorvusType.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: CorvusSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: AppColors.textSecondary,
                      ),
                      child: const Text('Ahora no'),
                    ),
                  ),
                  const SizedBox(width: CorvusSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Ver ${planName.split(' ').last}'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LimitLine extends StatelessWidget {
  final EntitlementCheck check;

  const _LimitLine({required this.check});

  @override
  Widget build(BuildContext context) {
    final fraction =
        check.limit <= 0 ? 1.0 : (check.used / check.limit).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(CorvusRadius.pill),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 5,
            backgroundColor: CorvusSurfaces.fill(CorvusSurfaces.fillBase),
            valueColor: const AlwaysStoppedAnimation(AppColors.gold),
          ),
        ),
        const SizedBox(height: CorvusSpacing.sm),
        Text('${check.used} de ${check.limit} en uso', style: CorvusType.muted),
      ],
    );
  }
}
