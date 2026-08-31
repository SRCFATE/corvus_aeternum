import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/corvus_design.dart';
import '../../providers/auth_provider.dart';

/// Muestra la advertencia de cierre de sesión. Devuelve `true` solo si el
/// artista confirma; `null` o `false` si la descarta.
Future<bool?> showSignOutConfirmation(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (_) => const SignOutDialog(),
  );
}

/// Pide confirmación y, si el artista acepta, cierra la sesión y lo lleva al
/// inicio de sesión.
///
/// La navegación es explícita a propósito: el `redirect` del router solo se
/// reevalúa al navegar, así que sin este `go` la sesión quedaría cerrada
/// mientras la pantalla del perfil sigue visible.
Future<void> confirmAndSignOut(BuildContext context) async {
  final confirmed = await showSignOutConfirmation(context);

  if (confirmed != true || !context.mounted) return;

  final router = GoRouter.of(context);
  await context.read<AuthProvider>().signOut();
  router.go('/login');
}

@visibleForTesting
class SignOutDialog extends StatelessWidget {
  const SignOutDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(CorvusRadius.sm),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.30)),
            ),
            child: const Icon(Icons.logout_rounded,
                size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: CorvusSpacing.md),
          const Expanded(child: Text('¿Cerrar sesión?')),
        ],
      ),
      content: Text(
        'Tu archivo, tus obras y tu progreso quedan intactos. '
        'Volverás a encontrarlos cuando regreses.',
        style: CorvusType.body,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Permanecer',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Cerrar sesión'),
        ),
      ],
    );
  }
}
