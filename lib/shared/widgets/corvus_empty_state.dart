import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/corvus_design.dart';
import 'corvus_crow_animations.dart';

class CorvusEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionText;
  final VoidCallback? onAction;

  const CorvusEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FallingFeather(height: 42),
              const SizedBox(height: 4),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: CorvusSurfaces.fill(CorvusSurfaces.fillSubtle),
                  border: Border.all(
                    color: CorvusSurfaces.fill(CorvusSurfaces.borderBase),
                  ),
                ),
                child: Icon(icon,
                    color: Colors.white.withValues(alpha: 0.26), size: 24),
              ),
              const SizedBox(height: 22),
              Text(
                title,
                textAlign: TextAlign.center,
                style: CorvusType.title.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: 13.5,
                  height: 1.55,
                ),
              ),
              if (actionText != null && onAction != null) ...[
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: onAction,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: accent.withValues(alpha: 0.45)),
                  ),
                  child: Text(actionText!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
