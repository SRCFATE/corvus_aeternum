import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/navigation_coordinator.dart';

class CorvusCrumb {
  final String label;
  final String? location;
  const CorvusCrumb(this.label, [this.location]);
}

/// A visible, keyboard-accessible path. Labels never derive from record IDs.
class CorvusBreadcrumbs extends StatelessWidget {
  final List<CorvusCrumb> items;
  final Future<void> Function(String)? onNavigate;
  const CorvusBreadcrumbs({super.key, required this.items, this.onNavigate});

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: 'Ruta de navegación',
        child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const ExcludeSemantics(
                  child: Icon(Icons.chevron_right, size: 16)),
            if (items[i].location case final String location)
              TextButton(
                  onPressed: () async {
                    if (!await AppNavigationCoordinator.instance
                            .canNavigate() ||
                        !context.mounted) {
                      return;
                    }
                    if (onNavigate != null) {
                      await onNavigate!(location);
                    } else {
                      context.go(location);
                    }
                  },
                  child: Text(items[i].label))
            else
              Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Text(items[i].label,
                      style: Theme.of(context).textTheme.labelLarge)),
          ],
        ]),
      );
}

/// Shared frame for deep routes; the page retains its own descriptive title.
class CorvusRouteFrame extends StatelessWidget {
  final List<CorvusCrumb> items;
  final Widget child;
  final bool confirmExit;
  const CorvusRouteFrame(
      {super.key,
      required this.items,
      required this.child,
      this.confirmExit = false});
  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(children: [
          SafeArea(
              bottom: false,
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: CorvusBreadcrumbs(
                          items: items,
                          onNavigate: (location) async {
                            if (confirmExit) {
                              final leave = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                        title: const Text(
                                            '¿Salir de esta edición?'),
                                        content: const Text(
                                            'Los cambios que no hayas guardado en este formulario se perderán.'),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text(
                                                  'Seguir editando')),
                                          FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text(
                                                  'Salir sin guardar')),
                                        ],
                                      ));
                              if (leave != true || !context.mounted) return;
                            }
                            if (context.mounted) context.go(location);
                          })))),
          Expanded(
              child: MediaQuery.removePadding(
                  context: context, removeTop: true, child: child)),
        ]),
      );
}
