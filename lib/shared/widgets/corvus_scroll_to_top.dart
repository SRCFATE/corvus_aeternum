import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/corvus_breakpoints.dart';
import '../../core/theme/corvus_design.dart';
import 'corvus_motion.dart';

/// Volver arriba.
///
/// Corvus tiene páginas largas por diseño —el archivo vivo, el registro de las
/// casas, un foro— y en un teléfono el gesto de subir cuarenta pantallas a
/// dedo es lo bastante caro como para que la gente prefiera recargar. El botón
/// aparece cuando ya hay algo que deshacer y desaparece en cuanto deja de
/// hacer falta, de modo que nunca tapa contenido en la primera pantalla.
///
/// Envuelve el scroll en vez de vivir en el `Scaffold`: así la página no tiene
/// que exponer su `ScrollController` ni renunciar a su propio botón flotante.
class CorvusScrollToTop extends StatefulWidget {
  final Widget child;

  /// El controlador del scroll que hay debajo. Si la página ya tiene uno, se
  /// pasa; si no, se crea aquí y se entrega con [builder].
  final ScrollController? controller;

  /// Alternativa a [child] para cuando la página no tiene controlador propio:
  /// recibe el que crea este widget y debe pasárselo a su scrollable.
  final Widget Function(BuildContext, ScrollController)? builder;

  /// Píxeles recorridos antes de ofrecer el atajo. Por debajo de una pantalla
  /// completa, volver arriba es un gesto y no un problema.
  final double threshold;

  /// Margen inferior extra, para páginas que ya tienen una barra flotante.
  final double bottomInset;

  const CorvusScrollToTop({
    super.key,
    required this.child,
    this.controller,
    this.threshold = 720,
    this.bottomInset = 0,
  }) : builder = null;

  const CorvusScrollToTop.builder({
    super.key,
    required this.builder,
    this.threshold = 720,
    this.bottomInset = 0,
  })  : child = const SizedBox.shrink(),
        controller = null;

  @override
  State<CorvusScrollToTop> createState() => _CorvusScrollToTopState();
}

class _CorvusScrollToTopState extends State<CorvusScrollToTop> {
  ScrollController? _owned;
  ScrollController? _attached;
  bool _visible = false;

  ScrollController get _controller =>
      widget.controller ?? (_owned ??= ScrollController());

  @override
  void initState() {
    super.initState();
    if (widget.builder != null || widget.controller != null) {
      _attach(_controller);
    }
  }

  @override
  void didUpdateWidget(CorvusScrollToTop old) {
    super.didUpdateWidget(old);
    if (widget.controller != old.controller) {
      _detach();
      if (widget.controller != null) _attach(widget.controller!);
    }
  }

  void _attach(ScrollController controller) {
    _attached = controller..addListener(_onScroll);
  }

  void _detach() {
    _attached?.removeListener(_onScroll);
    _attached = null;
  }

  void _onScroll() {
    final controller = _attached;
    if (controller == null || !controller.hasClients) return;

    final shouldShow = controller.offset > widget.threshold;
    if (shouldShow != _visible) setState(() => _visible = shouldShow);
  }

  /// Si el scroll viene de un descendiente sin controlador compartido, se
  /// escucha por notificación. Es el camino de `CorvusScrollToTop(child: …)`,
  /// que es el que usan las páginas que ya tienen su propio `CustomScrollView`.
  ScrollPosition? _notified;

  bool _onNotification(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }

    // La notificación trae el contexto de su propio `Scrollable`, así que no
    // hace falta rastrear el árbol para saber a quién hay que hacer subir.
    final context = notification.context;
    if (context != null) _notified = Scrollable.maybeOf(context)?.position;

    final shouldShow = notification.metrics.pixels > widget.threshold;
    if (shouldShow != _visible) {
      // Una notificación puede llegar durante el layout, y `setState` ahí
      // dentro es un error en tiempo de ejecución. Se aplaza un fotograma.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && shouldShow != _visible) {
          setState(() => _visible = shouldShow);
        }
      });
    }
    return false;
  }

  Future<void> _goUp() async {
    final controller = _attached;

    if (controller != null && controller.hasClients) {
      await _animate(controller.position);
      return;
    }

    final position = _notified;
    if (position != null && position.hasContentDimensions) {
      await _animate(position);
    }
  }

  Future<void> _animate(ScrollPosition position) {
    if (MediaQuery.disableAnimationsOf(context)) {
      position.jumpTo(position.minScrollExtent);
      return Future.value();
    }

    return position.animateTo(
      position.minScrollExtent,
      // Cuatrocientos milisegundos independientemente de la distancia: subir
      // proporcionalmente al recorrido haría que una página muy larga tardara
      // varios segundos, y nadie espera a que termine.
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _detach();
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = CorvusLayout.of(context);
    final content = widget.builder != null
        ? widget.builder!(context, _controller)
        : widget.child;

    return Stack(
      children: [
        if (widget.builder == null && widget.controller == null)
          NotificationListener<ScrollNotification>(
            onNotification: _onNotification,
            child: content,
          )
        else
          content,
        Positioned(
          right: layout.pageGutter,
          bottom: layout.pageGutter + widget.bottomInset,
          child: _ScrollToTopButton(visible: _visible, onTap: _goUp),
        ),
      ],
    );
  }
}

class _ScrollToTopButton extends StatelessWidget {
  final bool visible;
  final VoidCallback onTap;

  const _ScrollToTopButton({required this.visible, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 0.4),
        duration: CorvusMotion.medium,
        curve: CorvusMotion.standard,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: CorvusMotion.medium,
          curve: CorvusMotion.standard,
          child: CorvusPressable(
            onTap: onTap,
            haptics: true,
            hoverScale: 1.06,
            hoverLift: 3,
            glow: accent,
            borderRadius: BorderRadius.circular(CorvusRadius.pill),
            child: Tooltip(
              message: 'Volver arriba',
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.94),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accent.withValues(alpha: 0.28),
                  ),
                  boxShadow: CorvusElevation.medium,
                ),
                child: Icon(
                  Icons.arrow_upward_rounded,
                  size: 20,
                  color: accent.withValues(alpha: 0.92),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
