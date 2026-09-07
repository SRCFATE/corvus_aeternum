import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/corvus_design.dart';
import '../../../../providers/entitlement_provider.dart';
import '../domain/billing_models.dart';
import '../domain/feature_keys.dart';
import 'billing_format.dart';
import 'plan_badge.dart';

/// El estado de la cuenta en una tarjeta: qué plan, en qué situación y qué se
/// puede hacer al respecto.
///
/// El caso `past_due` está redactado a propósito sin amenaza: un cobro
/// rechazado casi siempre es una tarjeta caducada, y quien está a mitad de un
/// capítulo no merece que se le hable como a un moroso.
class BillingStatusCard extends StatelessWidget {
  final VoidCallback? onManage;
  final VoidCallback? onReactivate;
  final bool showActions;

  const BillingStatusCard({
    super.key,
    this.onManage,
    this.onReactivate,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EntitlementProvider>();
    final subscription = provider.subscription;

    return CorvusPanel(
      accent: subscription.needsAttention
          ? AppColors.warning
          : subscription.isFree
              ? null
              : AppColors.gold,
      raised: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'TU PLAN',
                  style: CorvusType.eyebrow(Colors.white, alpha: 0.34),
                ),
              ),
              PlanBadge(subscription: subscription),
            ],
          ),
          const SizedBox(height: CorvusSpacing.md),
          Text(_planName(subscription.planCode), style: CorvusType.title),
          const SizedBox(height: CorvusSpacing.sm),
          Text(_statusLine(subscription), style: CorvusType.body),
          if (provider.stale) ...[
            const SizedBox(height: CorvusSpacing.sm),
            Text(
              'Mostrando la última información conocida. Se actualizará al '
              'recuperar la conexión.',
              style: CorvusType.muted,
            ),
          ],
          if (showActions) ...[
            const SizedBox(height: CorvusSpacing.lg),
            Wrap(
              spacing: CorvusSpacing.sm,
              runSpacing: CorvusSpacing.sm,
              children: [
                if (subscription.isFree)
                  FilledButton(
                    onPressed: () => context.push('/plans'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.background,
                    ),
                    child: const Text('Ver planes'),
                  )
                else ...[
                  if (subscription.willEnd && onReactivate != null)
                    FilledButton(
                      onPressed: onReactivate,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.background,
                      ),
                      child: const Text('Reactivar'),
                    ),
                  OutlinedButton(
                    onPressed: onManage ??
                        () => context.push('/settings/billing'),
                    child: const Text('Gestionar facturación'),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _planName(String code) => switch (code) {
        PlanCode.professional => 'Atelier Professional',
        PlanCode.teams => 'Atelier Teams',
        _ => 'Atelier Free',
      };

  String _statusLine(SubscriptionState subscription) {
    final end = subscription.currentPeriodEnd;

    if (subscription.needsAttention) {
      return 'Hay un cobro pendiente. Tu taller sigue abierto y tu obra intacta; '
          'actualiza el método de pago cuando puedas.';
    }

    if (subscription.willEnd && end != null) {
      return 'Activo hasta el ${formatBillingDate(end)}. Después vuelves a Free '
          'y todo tu contenido se conserva.';
    }

    if (subscription.isTrialing && end != null) {
      return 'Prueba activa hasta el ${formatBillingDate(end)}.';
    }

    if (subscription.isFree) {
      return 'Proyectos, mundos y documentos ilimitados. Gratis para siempre.';
    }

    if (end != null) {
      return 'Se renueva el ${formatBillingDate(end)}.';
    }

    return 'Suscripción activa.';
  }
}
