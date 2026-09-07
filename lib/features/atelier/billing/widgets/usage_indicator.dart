import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/corvus_design.dart';
import '../../../../providers/entitlement_provider.dart';
import '../domain/billing_models.dart';
import '../services/usage_service.dart';

/// Un consumo cualquiera, dicho sin dramatismo: «3 de 10 colaboradores».
///
/// La barra solo se tiñe cuando de verdad queda poco. Un indicador que grita
/// desde el 40 % es una técnica de venta, no información.
class UsageIndicator extends StatelessWidget {
  final String label;
  final int used;
  final int limit;
  final IconData? icon;
  final bool compact;

  const UsageIndicator({
    super.key,
    required this.label,
    required this.used,
    required this.limit,
    this.icon,
    this.compact = false,
  });

  bool get _isUnlimited => limit == kUnlimited;

  double get _fraction {
    if (_isUnlimited || limit <= 0) return 0;
    return (used / limit).clamp(0.0, 1.0);
  }

  Color get _color {
    if (_isUnlimited) return AppColors.textSecondary;
    final percent = _fraction * 100;
    if (percent >= 95) return AppColors.error;
    if (percent >= 80) return AppColors.warning;
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final value = _isUnlimited ? 'Sin límite' : '$used / $limit';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.34)),
              const SizedBox(width: CorvusSpacing.sm),
            ],
            Expanded(child: Text(label, style: CorvusType.muted)),
            Text(
              value,
              style: CorvusType.muted.copyWith(
                color: _color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (!compact && !_isUnlimited) ...[
          const SizedBox(height: CorvusSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(CorvusRadius.pill),
            child: LinearProgressIndicator(
              value: _fraction,
              minHeight: 4,
              backgroundColor: CorvusSurfaces.fill(CorvusSurfaces.fillBase),
              valueColor: AlwaysStoppedAnimation(_color),
            ),
          ),
        ],
      ],
    );
  }
}

/// El almacenamiento, con su aviso escalonado: discreto al 80 %, importante al
/// 95 %, y al 100 % una frase que deja claro lo que NO pasa —no se borra nada—
/// junto a las tres salidas reales.
class StorageIndicator extends StatelessWidget {
  final UsageSnapshot? snapshot;
  final bool compact;
  final VoidCallback? onManageFiles;

  const StorageIndicator({
    super.key,
    this.snapshot,
    this.compact = false,
    this.onManageFiles,
  });

  @override
  Widget build(BuildContext context) {
    final usage = snapshot ?? context.watch<EntitlementProvider>().usage;

    if (usage.isUnlimited) {
      return UsageIndicator(
        label: 'Almacenamiento',
        used: usage.bytesUsed,
        limit: kUnlimited,
        icon: Icons.folder_outlined,
        compact: compact,
      );
    }

    final color = usage.isCritical
        ? AppColors.error
        : usage.isNearLimit
            ? AppColors.warning
            : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.folder_outlined,
              size: 13,
              color: Colors.white.withValues(alpha: 0.34),
            ),
            const SizedBox(width: CorvusSpacing.sm),
            Expanded(child: Text('Almacenamiento', style: CorvusType.muted)),
            Text(
              '${formatBytes(usage.bytesUsed)} / ${formatBytes(usage.bytesLimit)}',
              style: CorvusType.muted.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: CorvusSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(CorvusRadius.pill),
          child: LinearProgressIndicator(
            value: usage.fraction,
            minHeight: 4,
            backgroundColor: CorvusSurfaces.fill(CorvusSurfaces.fillBase),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        if (!compact && usage.isNearLimit) ...[
          const SizedBox(height: CorvusSpacing.md),
          _StorageAdvice(usage: usage, onManageFiles: onManageFiles),
        ],
      ],
    );
  }
}

class _StorageAdvice extends StatelessWidget {
  final UsageSnapshot usage;
  final VoidCallback? onManageFiles;

  const _StorageAdvice({required this.usage, this.onManageFiles});

  @override
  Widget build(BuildContext context) {
    final full = usage.isFull;

    return Container(
      padding: const EdgeInsets.all(CorvusSpacing.md),
      decoration: BoxDecoration(
        color: (full ? AppColors.error : AppColors.warning)
            .withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(CorvusRadius.md),
        border: Border.all(
          color: (full ? AppColors.error : AppColors.warning)
              .withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            full
                ? 'Sin espacio para archivos nuevos. Tus archivos, proyectos y '
                    'textos siguen intactos y accesibles: solo se pausan las '
                    'cargas hasta que liberes sitio o amplíes.'
                : 'Te queda ${formatBytes(usage.bytesRemaining)} de espacio.',
            style: CorvusType.body,
          ),
          const SizedBox(height: CorvusSpacing.md),
          Wrap(
            spacing: CorvusSpacing.sm,
            runSpacing: CorvusSpacing.sm,
            children: [
              if (onManageFiles != null)
                OutlinedButton(
                  onPressed: onManageFiles,
                  child: const Text('Liberar espacio'),
                ),
              FilledButton.tonal(
                onPressed: () => context.push('/plans?feature=atelier.storage.max_bytes'),
                child: const Text('Ampliar almacenamiento'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
