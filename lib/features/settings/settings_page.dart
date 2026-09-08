import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/corvus_design.dart';
import '../../providers/app_preferences_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/conspiration_provider.dart';
import '../../shared/layout/corvus_page.dart';
import '../../shared/widgets/corvus_motion.dart';
import '../../shared/widgets/user_avatar.dart';
import '../auth/sign_out_flow.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final preferences = context.watch<AppPreferencesProvider>();
    final accent = context.watch<ConspirationProvider>().accent;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CorvusPage(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 30),
          children: [
            CorvusReveal(
              child: _SettingsHeader(
                displayName: profile?.displayName ?? 'Tu cuenta',
                username: profile?.username,
                avatarUrl: profile?.avatarUrl,
                accent: accent,
              ),
            ),
            const SizedBox(height: 30),
            const CorvusSectionLabel(label: 'Experiencia de lectura'),
            const SizedBox(height: 12),
            CorvusReveal(
              delay: const Duration(milliseconds: 60),
              child: _SettingsPanel(
                children: [
                  _PreferenceTile(
                    icon: Icons.motion_photos_off_outlined,
                    title: 'Reducir movimiento',
                    subtitle:
                        'Detiene revelados, transiciones y microinteracciones.',
                    value: preferences.reduceMotion,
                    accent: accent,
                    onChanged: preferences.setReduceMotion,
                  ),
                  _PreferenceTile(
                    icon: Icons.format_size_rounded,
                    title: 'Texto ampliado',
                    subtitle:
                        'Aumenta la escala de lectura sin alterar la jerarquía.',
                    value: preferences.largerText,
                    accent: accent,
                    onChanged: preferences.setLargerText,
                  ),
                  _PreferenceTile(
                    icon: Icons.contrast_rounded,
                    title: 'Contraste reforzado',
                    subtitle: 'Aclara texto y bordes sobre las superficies.',
                    value: preferences.highContrast,
                    accent: accent,
                    onChanged: preferences.setHighContrast,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const CorvusSectionLabel(label: 'Identidad y cuenta'),
            const SizedBox(height: 12),
            CorvusReveal(
              delay: const Duration(milliseconds: 110),
              child: _SettingsPanel(
                children: [
                  _SettingsLink(
                    icon: Icons.account_circle_outlined,
                    title: 'Perfil editorial',
                    subtitle: 'Imagen, biografía, enlaces y disciplinas',
                    onTap: () => context.push('/profile/edit'),
                  ),
                  _SettingsLink(
                    icon: Icons.workspace_premium_outlined,
                    title: 'Tu posición en el Índice',
                    subtitle: 'Consulta el ranking y sus círculos',
                    onTap: () => context.go('/ranking'),
                  ),
                  _SettingsLink(
                    icon: Icons.receipt_long_outlined,
                    title: 'Plan y facturación',
                    subtitle: 'Atelier, uso y métodos de pago',
                    onTap: () => context.push('/settings/billing'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const CorvusSectionLabel(label: 'Sesión'),
            const SizedBox(height: 12),
            CorvusReveal(
              delay: const Duration(milliseconds: 160),
              child: _SettingsPanel(
                children: [
                  _SettingsLink(
                    icon: Icons.logout_rounded,
                    title: 'Cerrar sesión',
                    subtitle: 'Salir de esta cuenta en el dispositivo',
                    danger: true,
                    onTap: () => confirmAndSignOut(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 34),
            Center(
              child: Text(
                'CORVUS AETERNUM · EDICIÓN I',
                style: CorvusType.eyebrow(Colors.white, alpha: 0.22),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  final String displayName;
  final String? username;
  final String? avatarUrl;
  final Color accent;

  const _SettingsHeader({
    required this.displayName,
    required this.username,
    required this.avatarUrl,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.14),
            AppColors.card.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(CorvusRadius.lg),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.55)),
            ),
            child: UserAvatar(
              imageUrl: avatarUrl,
              displayName: displayName,
              radius: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PREFERENCIAS PERSONALES',
                    style: CorvusType.eyebrow(accent, alpha: 0.85)),
                const SizedBox(height: 6),
                Text('Configuración', style: CorvusType.title),
                const SizedBox(height: 4),
                Text(
                  username == null ? displayName : '$displayName · @$username',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CorvusType.muted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  final List<Widget> children;

  const _SettingsPanel({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: CorvusSurfaces.sheen(),
        borderRadius: BorderRadius.circular(CorvusRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Divider(
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  const _PreferenceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(CorvusRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              _SettingsIcon(icon: icon, color: accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: CorvusType.subtitle),
                    const SizedBox(height: 3),
                    Text(subtitle, style: CorvusType.muted),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsLink extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  const _SettingsLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.errorLight : AppColors.textSecondary;
    return CorvusPressable(
      onTap: onTap,
      hoverScale: 1,
      hoverLift: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            _SettingsIcon(icon: icon, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: CorvusType.subtitle.copyWith(
                      color: danger ? AppColors.errorLight : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, style: CorvusType.muted),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color, size: 19),
          ],
        ),
      ),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _SettingsIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(CorvusRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Icon(icon, size: 19, color: color),
    );
  }
}
