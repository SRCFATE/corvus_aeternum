import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/corvus_design.dart';
import '../../../../providers/entitlement_provider.dart';
import '../domain/billing_models.dart';
import '../domain/feature_keys.dart';

/// El distintivo del plan activo.
///
/// Free también tiene el suyo, y no en gris apagado: en un producto que
/// promete ser gratis para siempre, la versión gratuita no puede parecer un
/// estado de espera.
class PlanBadge extends StatelessWidget {
  final SubscriptionState? subscription;
  final bool compact;

  const PlanBadge({super.key, this.subscription, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final state =
        subscription ?? context.watch<EntitlementProvider>().subscription;

    final (label, color) = _appearance(state);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(CorvusRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.needsAttention) ...[
            Icon(Icons.error_outline_rounded, size: compact ? 10 : 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  (String, Color) _appearance(SubscriptionState state) {
    if (state.needsAttention) {
      return ('PAGO PENDIENTE', AppColors.warning);
    }

    switch (state.planCode) {
      case PlanCode.professional:
        return (
          state.isTrialing ? 'PROFESSIONAL · PRUEBA' : 'PROFESSIONAL',
          AppColors.gold,
        );
      case PlanCode.teams:
        return ('TEAMS', AppColors.secondaryLight);
      default:
        return ('FREE', AppColors.textSecondary);
    }
  }
}

/// La promesa escrita, para la pantalla de planes y el centro de facturación.
class FreeForeverNote extends StatelessWidget {
  const FreeForeverNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.all_inclusive_rounded,
          size: 14,
          color: Colors.white.withValues(alpha: 0.38),
        ),
        const SizedBox(width: CorvusSpacing.sm),
        Flexible(
          child: Text(
            'Atelier Free — \$0 para siempre. Sin tarjeta, sin prueba obligatoria.',
            style: CorvusType.muted,
          ),
        ),
      ],
    );
  }
}
