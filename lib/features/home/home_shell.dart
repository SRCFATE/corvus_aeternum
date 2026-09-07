import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/corvus_breakpoints.dart';
import '../../core/theme/corvus_design.dart';
import '../../core/router/navigation_coordinator.dart';
import '../../models/work.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/conspiration_provider.dart';
import '../../services/work_service.dart';
import '../../services/profile_service.dart';
import '../../shared/widgets/user_avatar.dart';
import '../../shared/widgets/corvus_motion.dart';
import '../work/upload_wizard_sheet.dart';

class HomeShell extends StatefulWidget {
  final Widget child;

  const HomeShell({
    super.key,
    required this.child,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  /// El cajón vive en el Scaffold del shell, y las páginas de dentro traen el
  /// suyo propio. Sin una llave explícita, `Scaffold.of` encontraría el de la
  /// página —que no tiene cajón— y el botón no haría nada.
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _tabs = [
    '/feed', // 0 — Explorar
    '/discover', // 1 — Descubrir
    '/collections', // 2 — Colecciones
    '/profile', // 3 — Perfil (no aparece en desktop nav)
    '/auctions', // 4 — Subastas
    '/artists', // 5 — Artistas
    '/atelier', // 6 - Atelier
    '/mundiarium', // 7 - Mundiarium
    '/archive', // 8 - Archivo Aeternum
    '/certificates', // 9 - Certificados Aeternum
    '/insights', // 10 - Estadisticas creativas
    '/planner', // 11 - Calendario y diario
    '/arena', // 12 - Desafios y duelos
    '/glossary', // 13 - Glosario creativo
    '/conspiracies', // 14 - Libro de las Conspiraciones
    '/forums', // 15 - Comunidades privadas de autores
    '/settings/billing', // 16 - Plan de Atelier y facturación
    '/workspaces', // 17 - Espacios de trabajo de Atelier Teams
  ];

  int _locationToIndex(String location) {
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i])) return i;
    }
    return 0;
  }

  Future<bool> _closeOpenWorkspace(BuildContext context) async {
    final coordinator = AppNavigationCoordinator.instance;
    final navigator = shellNavigatorKey.currentState;
    final hasExitGuard = coordinator.hasExitGuard;
    final canNavigate = await coordinator.canNavigate();
    if (!canNavigate || !context.mounted) return false;

    if (!hasExitGuard && navigator != null && navigator.canPop()) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('¿Deseas cambiar de página?'),
          content: const Text(
            'La pantalla abierta se cerrará. Verifica que hayas guardado tus cambios antes de continuar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Permanecer aquí'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Salir y cambiar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return false;
    }

    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted) return false;

    if (navigator != null && navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
      await WidgetsBinding.instance.endOfFrame;
    }
    return context.mounted;
  }

  Future<void> _goTo(BuildContext context, String location) async {
    if (!await _closeOpenWorkspace(context) || !context.mounted) return;
    context.go(location);
  }

  Future<void> _pushTo(BuildContext context, String location) async {
    if (!await _closeOpenWorkspace(context) || !context.mounted) return;
    context.push(location);
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _locationToIndex(location);
    final layout = CorvusLayout.of(context);
    final isDesktop = layout.hasFullNavigation;

    void goToTab(int i) => _goTo(context, _tabs[i]);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      // El cajón solo existe en táctil. En escritorio, la barra superior ya
      // muestra todos los destinos y un cajón sería una segunda respuesta a la
      // misma pregunta.
      drawer: isDesktop
          ? null
          : _CorvusMobileDrawer(
              selectedIndex: selectedIndex,
              onTabSelected: goToTab,
              onNotifications: () => _pushTo(context, '/notifications'),
              onAdmin: () => _pushTo(context, '/admin'),
            ),
      bottomNavigationBar: isDesktop
          ? null
          : _CorvusBottomNav(
              selectedIndex: selectedIndex,
              onTabSelected: goToTab,
            ),
      body: Column(
        children: [
          if (isDesktop)
            _CorvusDesktopBar(
              selectedIndex: selectedIndex,
              onTabSelected: goToTab,
              onUpload: () => showUploadWizard(context),
              onNotifications: () => _pushTo(context, '/notifications'),
              onAdmin: () => _pushTo(context, '/admin'),
            )
          else
            _CorvusMobileBar(
              selectedIndex: selectedIndex,
              onTabSelected: goToTab,
              onUpload: () => showUploadWizard(context),
              onNotifications: () => _pushTo(context, '/notifications'),
              onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          Expanded(
            child: CorvusPageTransition(
              pageKey: location,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MOBILE BAR
// ─────────────────────────────────────────────────────────────

/// Los cinco destinos que llegan al pulgar. Son los mismos cinco primeros de
/// escritorio: quien aprende Corvus en el teléfono no tiene que reaprenderlo
/// en el portátil. El resto vive en el cajón.
const _mobileNavItems = [
  _MobileNavItem(
    index: 1,
    label: 'Descubrir',
    icon: Icons.explore_outlined,
    activeIcon: Icons.explore_rounded,
  ),
  _MobileNavItem(
    index: 0,
    label: 'Explorar',
    icon: Icons.grid_view_outlined,
    activeIcon: Icons.grid_view_rounded,
  ),
  _MobileNavItem(
    index: 6,
    label: 'Atelier',
    icon: Icons.auto_stories_outlined,
    activeIcon: Icons.auto_stories_rounded,
  ),
  _MobileNavItem(
    index: 5,
    label: 'Ranking',
    icon: Icons.military_tech_outlined,
    activeIcon: Icons.military_tech_rounded,
  ),
  _MobileNavItem(
    index: 2,
    label: 'Colecciones',
    icon: Icons.collections_bookmark_outlined,
    activeIcon: Icons.collections_bookmark_rounded,
  ),
];

/// La cabecera táctil: identidad, buscar, crear, avisos y el cajón.
///
/// Los destinos ya no están aquí. Estaban arriba, donde el pulgar no llega sin
/// recolocar la mano, y ocupaban dos filas de una pantalla que se mide en
/// filas. Ahora esta barra solo lleva acciones, y la navegación bajó.
class _CorvusMobileBar extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onTabSelected;
  final VoidCallback onUpload;
  final VoidCallback onNotifications;
  final VoidCallback onOpenMenu;

  const _CorvusMobileBar({
    required this.selectedIndex,
    required this.onTabSelected,
    required this.onUpload,
    required this.onNotifications,
    required this.onOpenMenu,
  });

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final topPad = MediaQuery.of(context).padding.top;
    final tight = MediaQuery.sizeOf(context).width < 380;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.90),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, topPad + 10, 12, 10),
            child: Row(
              children: [
                _CircleIconButton(
                  icon: Icons.menu_rounded,
                  onTap: onOpenMenu,
                  tooltip: 'Menú',
                ),
                const SizedBox(width: 10),
                _BrandLogo(onTap: () => onTabSelected(1), compact: true),
                const Spacer(),
                // En pantallas muy estrechas el pastillón "Crear" empuja al
                // avatar fuera de la fila. Ahí se reduce a su icono, que es lo
                // que ya reconoce quien ha usado la app una vez.
                if (tight)
                  _CircleIconButton(
                    icon: Icons.add_rounded,
                    onTap: onUpload,
                    tooltip: 'Crear obra',
                    highlighted: true,
                  )
                else
                  _PrimaryPillButton(label: 'Crear', onTap: onUpload),
                const SizedBox(width: 8),
                _CircleIconButton(
                  icon: Icons.search_rounded,
                  onTap: () => showGlobalSearch(context),
                  tooltip: 'Buscar',
                ),
                const SizedBox(width: 8),
                _CircleIconButton(
                  icon: Icons.notifications_none_rounded,
                  onTap: onNotifications,
                  tooltip: 'Avisos',
                ),
                if (profile != null) ...[
                  const SizedBox(width: 8),
                  CorvusPressable(
                    onTap: () => onTabSelected(3),
                    hoverScale: 1.06,
                    hoverLift: 0,
                    child: UserAvatar(
                      imageUrl: profile.avatarUrl,
                      displayName: profile.displayName,
                      radius: 16,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La navegación táctil, al alcance del pulgar.
///
/// La pastilla del destino activo se desplaza en vez de aparecer y
/// desaparecer: el movimiento cuenta de dónde vienes, y en una barra de cinco
/// casillas eso es la diferencia entre orientarse y adivinar.
class _CorvusBottomNav extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onTabSelected;

  const _CorvusBottomNav({
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<ConspirationProvider>().accent;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.92),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                top: 8,
                // La barra de gestos del sistema ya deja su hueco; sin ella
                // hace falta uno propio o los iconos quedan pegados al borde.
                bottom: bottomPad > 0 ? 4 : 8,
              ),
              child: Row(
                children: [
                  for (final item in _mobileNavItems)
                    Expanded(
                      child: _BottomNavTile(
                        item: item,
                        selected: selectedIndex == item.index,
                        accent: accent,
                        onTap: () => onTabSelected(item.index),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavTile extends StatelessWidget {
  final _MobileNavItem item;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _BottomNavTile({
    required this.item,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? accent : AppColors.textMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: CorvusPressable(
        onTap: onTap,
        haptics: true,
        hoverScale: 1.0,
        hoverLift: 0,
        pressedScale: 0.9,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: CorvusMotion.medium,
                curve: CorvusMotion.standard,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(CorvusRadius.pill),
                ),
                child: Icon(
                  selected ? item.activeIcon : item.icon,
                  color: color,
                  size: 21,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: CorvusMotion.fast,
                curve: CorvusMotion.standard,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  letterSpacing: 0.1,
                ),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Todo lo demás, en un cajón.
///
/// Es el equivalente táctil del menú "Más" de escritorio y se alimenta de la
/// misma lista, `_moreGroups`: añadir un destino secundario allí lo hace
/// aparecer en los dos sitios, que es la única forma de que no se separen.
class _CorvusMobileDrawer extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onTabSelected;
  final VoidCallback onNotifications;
  final VoidCallback onAdmin;

  const _CorvusMobileDrawer({
    required this.selectedIndex,
    required this.onTabSelected,
    required this.onNotifications,
    required this.onAdmin,
  });

  void _select(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final accent = context.watch<ConspirationProvider>().accent;

    return Drawer(
      backgroundColor: AppColors.background,
      width: (MediaQuery.sizeOf(context).width * 0.86).clamp(280.0, 360.0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(CorvusRadius.xl),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CorvusSpacing.lg,
                CorvusSpacing.lg,
                CorvusSpacing.lg,
                CorvusSpacing.md,
              ),
              child: profile == null
                  ? _DrawerVisitorHeader(
                      accent: accent,
                      onTap: () => _select(
                        context,
                        () => GoRouter.of(context).go('/login'),
                      ),
                    )
                  : CorvusPressable(
                      onTap: () => _select(context, () => onTabSelected(3)),
                      hoverScale: 1.0,
                      hoverLift: 0,
                      child: Row(
                        children: [
                          UserAvatar(
                            imageUrl: profile.avatarUrl,
                            displayName: profile.displayName,
                            radius: 22,
                          ),
                          const SizedBox(width: CorvusSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: CorvusType.subtitle,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '@${profile.username}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: CorvusType.muted,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: CorvusSpacing.md,
                  vertical: CorvusSpacing.md,
                ),
                children: [
                  // Los cinco de la barra inferior también viven aquí: quien
                  // abre el cajón buscando "Descubrir" no debería encontrar un
                  // hueco donde espera un destino.
                  for (final item in _mobileNavItems)
                    _DrawerTile(
                      label: item.label,
                      icon: item.icon,
                      accent: accent,
                      selected: selectedIndex == item.index,
                      onTap: () => _select(
                        context,
                        () => onTabSelected(item.index),
                      ),
                    ),
                  _DrawerTile(
                    label: 'Subastas',
                    icon: Icons.gavel_rounded,
                    accent: accent,
                    selected: selectedIndex == 4,
                    onTap: () => _select(context, () => onTabSelected(4)),
                  ),
                  for (final group in _moreGroups) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        CorvusSpacing.md,
                        CorvusSpacing.lg,
                        CorvusSpacing.md,
                        CorvusSpacing.sm,
                      ),
                      child: Text(
                        group.title.toUpperCase(),
                        style: CorvusType.eyebrow(Colors.white, alpha: 0.34),
                      ),
                    ),
                    for (final entry in group.entries)
                      _DrawerTile(
                        label: entry.label,
                        icon: entry.icon,
                        accent: accent,
                        selected: selectedIndex == entry.index,
                        onTap: () => _select(
                          context,
                          () => onTabSelected(entry.index),
                        ),
                      ),
                  ],
                  if (profile?.isAdmin == true) ...[
                    const SizedBox(height: CorvusSpacing.lg),
                    _DrawerTile(
                      label: 'Panel de administración',
                      icon: Icons.shield_outlined,
                      accent: accent,
                      selected: false,
                      onTap: () => _select(context, onAdmin),
                    ),
                  ],
                  const SizedBox(height: CorvusSpacing.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerVisitorHeader extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;

  const _DrawerVisitorHeader({required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CorvusPressable(
      onTap: onTap,
      hoverScale: 1.01,
      hoverLift: 1,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(CorvusSpacing.lg),
        decoration: BoxDecoration(
          gradient: CorvusSurfaces.accentWash(accent, strength: 0.7),
          borderRadius: BorderRadius.circular(CorvusRadius.lg),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('EL ARCHIVO TE ESPERA', style: CorvusType.eyebrow(accent)),
            const SizedBox(height: CorvusSpacing.sm),
            Text('Entra o crea tu cuenta', style: CorvusType.subtitle),
            const SizedBox(height: CorvusSpacing.xs),
            Text(
              'Para publicar, guardar y seguir a otros artistas.',
              style: CorvusType.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.label,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: CorvusPressable(
        onTap: onTap,
        haptics: true,
        hoverScale: 1.0,
        hoverLift: 0,
        pressedScale: 0.985,
        child: AnimatedContainer(
          duration: CorvusMotion.fast,
          curve: CorvusMotion.standard,
          padding: const EdgeInsets.symmetric(
            horizontal: CorvusSpacing.md,
            vertical: 13,
          ),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(CorvusRadius.md),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: selected ? accent : AppColors.textSecondary,
              ),
              const SizedBox(width: CorvusSpacing.md),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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

// ─────────────────────────────────────────────────────────────
// DESKTOP BAR
// ─────────────────────────────────────────────────────────────

class _MobileNavItem {
  final int index;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _MobileNavItem({
    required this.index,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

class _CorvusDesktopBar extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onTabSelected;
  final VoidCallback onUpload;
  final VoidCallback onNotifications;
  final VoidCallback onAdmin;

  const _CorvusDesktopBar({
    required this.selectedIndex,
    required this.onTabSelected,
    required this.onUpload,
    required this.onNotifications,
    required this.onAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final topPad = MediaQuery.of(context).padding.top;
    final isAdmin = profile?.isAdmin == true;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.90),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, topPad + 10, 18, 10),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1600),
                child: SizedBox(
                  height: 46,
                  child: Row(
                    children: [
                      _BrandLogo(onTap: () => onTabSelected(0)),
                      const SizedBox(width: 36),
                      Expanded(
                        child: Center(
                          child: _DesktopNav(
                            selectedIndex: selectedIndex,
                            onTabSelected: onTabSelected,
                          ),
                        ),
                      ),
                      const SizedBox(width: 36),
                      Row(
                        children: [
                          _CircleIconButton(
                            icon: Icons.search_rounded,
                            onTap: () => showGlobalSearch(context),
                          ),
                          const SizedBox(width: 8),
                          _CircleIconButton(
                            icon: Icons.notifications_none_rounded,
                            onTap: onNotifications,
                          ),
                          const SizedBox(width: 8),
                          if (isAdmin) ...[
                            _CircleIconButton(
                              icon: Icons.shield_outlined,
                              onTap: onAdmin,
                              highlighted: true,
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (profile != null) ...[
                            GestureDetector(
                              onTap: () => onTabSelected(3),
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.24),
                                  ),
                                ),
                                child: Center(
                                  child: UserAvatar(
                                    imageUrl: profile.avatarUrl,
                                    displayName: profile.displayName,
                                    radius: 15,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          _PrimaryPillButton(
                            label: 'Crear obra',
                            onTap: onUpload,
                            large: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// NAVIGATION
// ─────────────────────────────────────────────────────────────

class _DesktopNav extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onTabSelected;

  const _DesktopNav({
    required this.selectedIndex,
    required this.onTabSelected,
  });

  // Seis destinos principales más el menú secundario. Arena y Foros bajaron a
  // "Más"; "Artistas" pasó a "Ranking" porque Corvus no es solo literario.
  static const _items = [
    _NavItem(index: 1, label: 'Descubrir'),
    _NavItem(index: 0, label: 'Explorar'),
    _NavItem(index: 6, label: 'Atelier'),
    _NavItem(index: 5, label: 'Ranking'),
    _NavItem(index: 2, label: 'Colecciones'),
    _NavItem(index: 4, label: 'Subastas'),
  ];

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ..._items.map((item) {
            final selected = selectedIndex == item.index;
            return _HoverNavLink(
              label: item.label,
              selected: selected,
              onTap: () => onTabSelected(item.index),
            );
          }),
          _SpacesMenuButton(
            selectedIndex: selectedIndex,
            onTabSelected: onTabSelected,
            compact: false,
          ),
        ],
      ),
    );
  }
}

/// Un destino dentro del menú "Más".
class _MoreEntry {
  final int index;
  final String label;
  final String hint;
  final IconData icon;

  const _MoreEntry({
    required this.index,
    required this.label,
    required this.hint,
    required this.icon,
  });
}

class _MoreGroup {
  final String title;
  final List<_MoreEntry> entries;

  const _MoreGroup({required this.title, required this.entries});
}

const _moreGroups = <_MoreGroup>[
  _MoreGroup(
    title: 'Comunidad',
    entries: [
      _MoreEntry(
        index: 15,
        label: 'Foros de autores',
        hint: 'Círculos privados de conversación',
        icon: Icons.forum_outlined,
      ),
      _MoreEntry(
        index: 7,
        label: 'Mundiarium',
        hint: 'Universos, mapas y linajes',
        icon: Icons.public_rounded,
      ),
      _MoreEntry(
        index: 12,
        label: 'Arena Corvus',
        hint: 'Desafíos y duelos creativos',
        icon: Icons.emoji_events_outlined,
      ),
      _MoreEntry(
        index: 17,
        label: 'Espacios de trabajo',
        hint: 'Estudios, editoriales y equipos',
        icon: Icons.workspaces_outlined,
      ),
    ],
  ),
  _MoreGroup(
    title: 'Trayectoria',
    entries: [
      _MoreEntry(
        index: 14,
        label: 'Libro de las Conspiraciones',
        hint: 'Tus casas, progreso y Mudas',
        icon: Icons.workspaces_outline,
      ),
      _MoreEntry(
        index: 9,
        label: 'Certificados',
        hint: 'Autoría sellada y procedencia',
        icon: Icons.verified_outlined,
      ),
      _MoreEntry(
        index: 10,
        label: 'Pulso creativo',
        hint: 'Ritmo, alcance y evolución',
        icon: Icons.insights_outlined,
      ),
      _MoreEntry(
        index: 16,
        label: 'Plan y facturación',
        hint: 'Tu plan de Atelier, uso y pagos',
        icon: Icons.workspace_premium_outlined,
      ),
    ],
  ),
  _MoreGroup(
    title: 'Archivo y organización',
    entries: [
      _MoreEntry(
        index: 8,
        label: 'Archivo Aeternum',
        hint: 'Tu obra registrada y preservada',
        icon: Icons.account_tree_outlined,
      ),
      _MoreEntry(
        index: 11,
        label: 'Calendario y diario',
        hint: 'Planeación y bitácora',
        icon: Icons.calendar_month_outlined,
      ),
      _MoreEntry(
        index: 13,
        label: 'Glosario',
        hint: 'Códice de términos del archivo',
        icon: Icons.menu_book_outlined,
      ),
    ],
  ),
];

/// Índices que viven dentro del menú "Más".
final Set<int> _moreIndices = {
  for (final g in _moreGroups)
    for (final e in g.entries) e.index,
};

class _SpacesMenuButton extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final bool compact;

  const _SpacesMenuButton({
    required this.selectedIndex,
    required this.onTabSelected,
    this.compact = true,
  });

  /// Abre el panel anclado bajo el botón.
  ///
  /// No se usa PopupMenuButton a propósito: su menú está limitado a 280 px de
  /// ancho (`_kMenuMaxWidth`) y mide el contenido por ancho intrínseco, lo que
  /// colapsaba este panel de tres columnas hasta desbordar cada fila.
  Future<void> _open(BuildContext context, Color accent) async {
    final button = context.findRenderObject() as RenderBox?;
    final overlay =
        Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) return;

    final anchor = button.localToGlobal(
      button.size.bottomLeft(const Offset(0, 10)),
      ancestor: overlay,
    );

    final selection = await showGeneralDialog<int>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Más',
      barrierColor: Colors.black.withValues(alpha: 0.28),
      transitionDuration: CorvusMotion.medium,
      pageBuilder: (dialogContext, animation, _) {
        return _MoreMenuOverlay(
          anchor: anchor,
          overlaySize: overlay.size,
          accent: accent,
          selectedIndex: selectedIndex,
          animation: animation,
          onSelect: (i) => Navigator.of(dialogContext).pop(i),
        );
      },
    );

    if (selection != null) onTabSelected(selection);
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<ConspirationProvider>().accent;
    final selected = _moreIndices.contains(selectedIndex);

    return Semantics(
      button: true,
      label: 'Más',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _open(context, accent),
          behavior: HitTestBehavior.opaque,
          child: compact
          ? AnimatedContainer(
              duration: CorvusMotion.fast,
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.18)
                    : CorvusSurfaces.fill(CorvusSurfaces.fillRaised),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? accent.withValues(alpha: 0.42)
                      : CorvusSurfaces.fill(CorvusSurfaces.borderBase),
                ),
              ),
              child: Icon(
                Icons.grid_view_rounded,
                size: 18,
                color: selected ? accent : AppColors.textSecondary,
              ),
            )
              : _HoverNavLink(
                  label: 'Más',
                  selected: selected,
                  trailing: Icons.expand_more_rounded,
                  onTap: null,
                ),
        ),
      ),
    );
  }
}

/// Capa que posiciona el panel bajo el botón y lo anima al aparecer.
class _MoreMenuOverlay extends StatelessWidget {
  final Offset anchor;
  final Size overlaySize;
  final Color accent;
  final int selectedIndex;
  final Animation<double> animation;
  final ValueChanged<int> onSelect;

  const _MoreMenuOverlay({
    required this.anchor,
    required this.overlaySize,
    required this.accent,
    required this.selectedIndex,
    required this.animation,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    const margin = 16.0;
    final maxWidth = overlaySize.width - margin * 2;
    final panelWidth = (overlaySize.width >= 980 ? 720.0 : 320.0)
        .clamp(240.0, maxWidth > 0 ? maxWidth : 240.0);

    // Se ancla al botón pero nunca sale de la pantalla por el borde derecho.
    final left =
        (anchor.dx - 12).clamp(margin, (overlaySize.width - panelWidth - margin)
            .clamp(margin, double.infinity));

    final curved =
        CurvedAnimation(parent: animation, curve: CorvusMotion.entrance);

    return Stack(
      children: [
        Positioned(
          left: left,
          top: anchor.dy,
          width: panelWidth,
          child: FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.03),
                end: Offset.zero,
              ).animate(curved),
              child: Material(
                type: MaterialType.transparency,
                child: _MoreMenuPanel(
                  accent: accent,
                  selectedIndex: selectedIndex,
                  onSelect: onSelect,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Panel agrupado del menú "Más": tres familias de destinos con jerarquía
/// visible, en vez de una lista plana de siete elementos.
class _MoreMenuPanel extends StatelessWidget {
  final Color accent;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _MoreMenuPanel({
    required this.accent,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // El ancho lo impone el overlay que lo posiciona; aquí solo se decide si
    // hay sitio para las tres columnas o hay que apilarlas.
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 560;

      return ClipRRect(
      borderRadius: BorderRadius.circular(CorvusRadius.xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(CorvusRadius.xl),
            border: Border.all(
              color: CorvusSurfaces.fill(CorvusSurfaces.borderBase),
            ),
            boxShadow: CorvusElevation.high,
          ),
          child: Stack(
            children: [
              // Halo del acento de la casa activa en la esquina superior.
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.75, -1.4),
                        radius: 1.3,
                        colors: [
                          accent.withValues(alpha: 0.14),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(CorvusSpacing.lg),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < _moreGroups.length; i++) ...[
                            Expanded(child: _buildGroup(_moreGroups[i])),
                            if (i < _moreGroups.length - 1)
                              const SizedBox(width: CorvusSpacing.md),
                          ],
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < _moreGroups.length; i++) ...[
                            _buildGroup(_moreGroups[i]),
                            if (i < _moreGroups.length - 1)
                              const SizedBox(height: CorvusSpacing.lg),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
      );
    });
  }

  Widget _buildGroup(_MoreGroup group) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              CorvusSpacing.md, CorvusSpacing.xs, CorvusSpacing.md, 0),
          child: CorvusSectionLabel(label: group.title, accent: accent),
        ),
        const SizedBox(height: CorvusSpacing.sm),
        ...group.entries.map(
          (e) => _MoreMenuTile(
            entry: e,
            accent: accent,
            selected: selectedIndex == e.index,
            onTap: () => onSelect(e.index),
          ),
        ),
      ],
    );
  }
}

class _MoreMenuTile extends StatefulWidget {
  final _MoreEntry entry;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const _MoreMenuTile({
    required this.entry,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_MoreMenuTile> createState() => _MoreMenuTileState();
}

class _MoreMenuTileState extends State<_MoreMenuTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _hovered;
    final accent = widget.accent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: CorvusMotion.fast,
          curve: CorvusMotion.standard,
          padding: const EdgeInsets.symmetric(
              horizontal: CorvusSpacing.md, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? accent.withValues(alpha: widget.selected ? 0.12 : 0.07)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(CorvusRadius.md),
            border: Border.all(
              color: widget.selected
                  ? accent.withValues(alpha: 0.34)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: CorvusMotion.fast,
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: active ? 0.16 : 0.08),
                  borderRadius: BorderRadius.circular(CorvusRadius.sm),
                  border: Border.all(
                    color: accent.withValues(alpha: active ? 0.36 : 0.16),
                  ),
                ),
                child: Icon(widget.entry.icon,
                    size: 16,
                    color: accent.withValues(alpha: active ? 1 : 0.75)),
              ),
              const SizedBox(width: CorvusSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.entry.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active
                            ? AppColors.textPrimary
                            : Colors.white.withValues(alpha: 0.78),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.entry.hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.34),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Se revela en hover pero no reserva ancho: en columnas
              // estrechas cada píxel cuenta.
              if (active)
                Icon(Icons.arrow_forward_rounded,
                    size: 13, color: accent.withValues(alpha: 0.75)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final int index;
  final String label;
  const _NavItem({required this.index, required this.label});
}

class _HoverNavLink extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? trailing;

  const _HoverNavLink({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  @override
  State<_HoverNavLink> createState() => _HoverNavLinkState();
}

class _HoverNavLinkState extends State<_HoverNavLink> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<ConspirationProvider>().accent;
    final active = widget.selected || hovered;

    // Sin onTap el enlace es solo la etiqueta de un contenedor que ya escucha
    // el toque (el menú "Más"): envolverlo en un GestureDetector opaco
    // absorbería el gesto y el menú nunca abriría.
    final label = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: CorvusMotion.fast,
                    curve: CorvusMotion.standard,
                    style: TextStyle(
                      color: widget.selected
                          ? Colors.white
                          : hovered
                              ? Colors.white.withValues(alpha: 0.88)
                              : AppColors.textMuted,
                      fontSize: 13.5,
                      fontWeight:
                          widget.selected ? FontWeight.w800 : FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                    child: Text(widget.label),
                  ),
                  if (widget.trailing != null) ...[
                    const SizedBox(width: 3),
                    Icon(widget.trailing,
                        size: 15,
                        color: active
                            ? Colors.white.withValues(alpha: 0.80)
                            : AppColors.textMuted),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              // Subrayado del acento: marca el destino activo sin recuadros.
              AnimatedContainer(
                duration: CorvusMotion.medium,
                curve: CorvusMotion.standard,
                height: 2,
                width: widget.selected ? 18 : (hovered ? 10 : 0),
                decoration: BoxDecoration(
                  color: widget.selected
                      ? accent
                      : accent.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(CorvusRadius.pill),
                  boxShadow: widget.selected
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.55),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
            ],
          ),
        );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: widget.onTap == null
          ? label
          : GestureDetector(
              onTap: widget.onTap,
              behavior: HitTestBehavior.opaque,
              child: label,
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────

class _BrandLogo extends StatelessWidget {
  final VoidCallback onTap;
  final bool compact;

  const _BrandLogo({required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 28 : 30,
              height: compact ? 28 : 30,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primary,
                size: compact ? 15 : 16,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              compact ? 'Corvus' : 'Corvus Aeternum',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Los botones redondos de la barra: buscar, avisos, menú, admin.
///
/// Llevan `tooltip` porque son solo un icono. Un icono sin nombre es una
/// adivinanza para quien llega por primera vez y, en escritorio, un muro para
/// quien navega con lector de pantalla.
class _CircleIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;
  final String? tooltip;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.highlighted = false,
    this.tooltip,
  });

  @override
  State<_CircleIconButton> createState() => _CircleIconButtonState();
}

class _CircleIconButtonState extends State<_CircleIconButton> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.highlighted
        ? AppColors.primary.withValues(alpha: hovered ? 0.26 : 0.18)
        : Colors.white.withValues(alpha: hovered ? 0.08 : 0.045);

    Widget button = MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: CorvusPressable(
        onTap: widget.onTap,
        haptics: true,
        hoverScale: 1.0,
        hoverLift: 0,
        pressedScale: 0.92,
        child: AnimatedContainer(
          duration: CorvusMotion.fast,
          curve: CorvusMotion.standard,
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hovered
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.07),
              width: 1,
            ),
          ),
          child: Icon(
            widget.icon,
            color: widget.highlighted
                ? AppColors.primary
                : AppColors.textSecondary,
            size: 19,
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 420),
        child: Semantics(button: true, label: widget.tooltip, child: button),
      );
    }

    return button;
  }
}

/// El botón de crear. Es la acción principal de toda la aplicación, así que es
/// el único elemento de la barra que se pinta con el acento sólido.
class _PrimaryPillButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool large;

  const _PrimaryPillButton({
    required this.label,
    required this.onTap,
    this.large = false,
  });

  @override
  State<_PrimaryPillButton> createState() => _PrimaryPillButtonState();
}

class _PrimaryPillButtonState extends State<_PrimaryPillButton> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: CorvusPressable(
        onTap: widget.onTap,
        haptics: true,
        hoverScale: 1.035,
        hoverLift: 1,
        pressedScale: 0.955,
        child: AnimatedContainer(
          duration: CorvusMotion.fast,
          curve: CorvusMotion.standard,
          padding: EdgeInsets.symmetric(
            horizontal: widget.large ? 20 : 15,
            vertical: widget.large ? 13 : 9,
          ),
          decoration: BoxDecoration(
            color: hovered
                ? AppColors.primary.withValues(alpha: 0.95)
                : AppColors.primary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: hovered
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [],
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              color: AppColors.background,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// GLOBAL SEARCH OVERLAY
// ─────────────────────────────────────────────────────────────

void showGlobalSearch(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'search',
    barrierColor: Colors.black.withValues(alpha: 0.65),
    transitionDuration: const Duration(milliseconds: 220),
    transitionBuilder: (_, anim, __, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -0.04), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      );
    },
    pageBuilder: (ctx, _, __) => _GlobalSearchOverlay(
      onClose: () => Navigator.of(ctx).pop(),
      onNavigate: (route) {
        Navigator.of(ctx).pop();
        ctx.push(route);
      },
    ),
  );
}

class _GlobalSearchOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final ValueChanged<String> onNavigate;

  const _GlobalSearchOverlay({required this.onClose, required this.onNavigate});

  @override
  State<_GlobalSearchOverlay> createState() => _GlobalSearchOverlayState();
}

class _GlobalSearchOverlayState extends State<_GlobalSearchOverlay> {
  final _workService = WorkService();
  final _profileService = ProfileService();
  final _controller = TextEditingController();
  final _focus = FocusNode();

  List<Work> _works = [];
  List<UserProfile> _artists = [];
  bool _loading = false;
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _works = [];
        _artists = [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), _search);
  }

  Future<void> _search() async {
    if (_query.trim().isEmpty) return;
    setState(() => _loading = true);
    final results = await Future.wait([
      _workService.getDiscoverWorks(query: _query.trim(), limit: 5),
      _profileService.getArtists(query: _query.trim(), limit: 5),
    ]);
    if (mounted) {
      setState(() {
        _works = results[0] as List<Work>;
        _artists = results[1] as List<UserProfile>;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasResults = _works.isNotEmpty || _artists.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            MediaQuery.of(context).padding.top + 70,
            24,
            24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 660),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search input
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.40)),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          blurRadius: 24,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Icon(Icons.search_rounded,
                          color: AppColors.primary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focus,
                          onChanged: _onChanged,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Buscar obras, artistas...',
                            hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.30),
                                fontSize: 16),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.primary)),
                        )
                      else
                        GestureDetector(
                          onTap: widget.onClose,
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                                border: Border(
                                    left: BorderSide(
                                        color: Colors.white
                                            .withValues(alpha: 0.07)))),
                            child: Icon(Icons.close_rounded,
                                size: 18,
                                color: Colors.white.withValues(alpha: 0.38)),
                          ),
                        ),
                    ],
                  ),
                ),

                // Results panel
                if (_query.isNotEmpty && hasResults) ...[
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.07)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 8))
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_artists.isNotEmpty) ...[
                            _SectionLabel(label: 'Artistas'),
                            ..._artists.map((a) => _ArtistResult(
                                  artist: a,
                                  onTap: () => widget
                                      .onNavigate('/profile/${a.username}'),
                                )),
                          ],
                          if (_works.isNotEmpty && _artists.isNotEmpty)
                            const Divider(height: 1, color: Colors.white10),
                          if (_works.isNotEmpty) ...[
                            _SectionLabel(label: 'Obras'),
                            ..._works.map((w) => _WorkResult(
                                  work: w,
                                  onTap: () =>
                                      widget.onNavigate('/work/${w.id}'),
                                )),
                          ],
                        ],
                      ),
                    ),
                  ),
                ] else if (_query.isNotEmpty && !_loading) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.07)),
                    ),
                    child: Center(
                      child: Text('Sin resultados para "$_query"',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.38),
                              fontSize: 14)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ), // Align
    ); // Material
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
            color: Colors.white.withValues(alpha: 0.30),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2),
      ),
    );
  }
}

class _ArtistResult extends StatefulWidget {
  final UserProfile artist;
  final VoidCallback onTap;
  const _ArtistResult({required this.artist, required this.onTap});
  @override
  State<_ArtistResult> createState() => _ArtistResultState();
}

class _ArtistResultState extends State<_ArtistResult> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.artist;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          color: _hovered
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.overlay,
              backgroundImage: (a.avatarUrl != null && a.avatarUrl!.isNotEmpty)
                  ? NetworkImage(a.avatarUrl!)
                  : null,
              child: (a.avatarUrl == null || a.avatarUrl!.isEmpty)
                  ? Text(
                      (a.displayName.isNotEmpty
                              ? a.displayName[0]
                              : a.username[0])
                          .toUpperCase(),
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(a.displayName.isNotEmpty ? a.displayName : a.username,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  Text('@${a.username}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.38),
                          fontSize: 12)),
                ])),
            if (a.isArtistVerified)
              Icon(Icons.verified_rounded, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: Colors.white.withValues(alpha: 0.20)),
          ]),
        ),
      ),
    );
  }
}

class _WorkResult extends StatefulWidget {
  final Work work;
  final VoidCallback onTap;
  const _WorkResult({required this.work, required this.onTap});
  @override
  State<_WorkResult> createState() => _WorkResultState();
}

class _WorkResultState extends State<_WorkResult> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final w = widget.work;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          color: _hovered
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 40,
                height: 40,
                child: w.hasImage
                    ? CachedNetworkImage(
                        imageUrl: w.displayImage,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Container(color: AppColors.overlay))
                    : Container(
                        color: AppColors.overlay,
                        child: const Icon(Icons.image_outlined,
                            color: AppColors.textMuted, size: 18)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(w.title,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(w.authorDisplayName ?? w.authorUsername ?? '',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.38),
                          fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ])),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: Colors.white.withValues(alpha: 0.20)),
          ]),
        ),
      ),
    );
  }
}
