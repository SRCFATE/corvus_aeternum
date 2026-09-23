import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/corvus_design.dart';

enum CorvusSaveState { unsaved, saving, saved, error }

/// Guardado y publicación son estados independientes, también para el lector
/// de pantalla. El guardado automático no dispara notificaciones.
class CorvusSaveStatus extends StatelessWidget {
  final CorvusSaveState state;
  final DateTime? savedAt;
  final VoidCallback? onRetry;
  const CorvusSaveStatus(
      {super.key, required this.state, this.savedAt, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (state) {
      CorvusSaveState.unsaved => (
          'Sin guardar',
          Icons.edit_outlined,
          AppColors.gold
        ),
      CorvusSaveState.saving => (
          'Guardando…',
          Icons.sync,
          AppColors.textSecondary
        ),
      CorvusSaveState.saved => (
          'Guardado',
          Icons.cloud_done_outlined,
          AppColors.successLight
        ),
      CorvusSaveState.error => (
          'Error de sincronización',
          Icons.cloud_off_outlined,
          AppColors.errorLight
        ),
    };
    final time = savedAt == null
        ? ''
        : ' · ${savedAt!.hour.toString().padLeft(2, '0')}:${savedAt!.minute.toString().padLeft(2, '0')}';
    return Tooltip(
      message: '$label$time',
      child: Semantics(
        label: '$label$time',
        child: Wrap(
          spacing: CorvusSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            Text('$label$time', style: TextStyle(color: color, fontSize: 12)),
            if (state == CorvusSaveState.error && onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
