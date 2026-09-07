import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../core/theme/corvus_design.dart';

/// El movimiento de Corvus.
///
/// Una regla por encima de todas: nada de esto se ejecuta si el sistema pide
/// menos movimiento. `MediaQuery.disableAnimationsOf` no es un detalle de
/// accesibilidad opcional —hay gente a la que una animación de entrada le
/// provoca náuseas— y además cubre las pruebas de widget, que de otro modo
/// esperarían para siempre a que se asiente una animación.

/// Transición entre páginas del shell. Funde y sube apenas: lo justo para que
/// el ojo entienda que ha cambiado el contenido y no la aplicación entera.
class CorvusPageTransition extends StatelessWidget {
  final String pageKey;
  final Widget child;

  const CorvusPageTransition({
    super.key,
    required this.pageKey,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    return TweenAnimationBuilder<double>(
      key: ValueKey(pageKey),
      tween: Tween(begin: 0, end: 1),
      duration: CorvusMotion.medium,
      curve: CorvusMotion.standard,
      child: child,
      builder: (context, value, animatedChild) => Opacity(
        // La opacidad corre por delante del desplazamiento: llega antes a
        // opaco que a su sitio, y así el movimiento se percibe como un
        // asentamiento y no como un deslizamiento.
        opacity: Curves.easeOut.transform(value),
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: Transform.scale(
            scale: 0.994 + 0.006 * value,
            child: animatedChild,
          ),
        ),
      ),
    );
  }
}

/// Transición de las rutas que se apilan: obra, colección, perfil ajeno,
/// subasta, capítulo.
///
/// Se declara en el tema y no ruta por ruta. Son más de veinte rutas apiladas;
/// convertirlas una a una a `pageBuilder` habría dejado la transición
/// dependiendo de que nadie olvidara ponerla al añadir la siguiente.
///
/// Es distinta de [CorvusPageTransition] porque el gesto es distinto: cambiar
/// de pestaña es sustituir contenido —funde y nada más—, mientras que abrir
/// una obra es entrar en algo, y eso merece dirección. Entra desde abajo, muy
/// poco, y al volver el fondo se queda quieto: en web, el deslizamiento
/// horizontal de Android se lee como un error de la página.
class CorvusPageTransitionsBuilder extends PageTransitionsBuilder {
  const CorvusPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    final curved = CurvedAnimation(
      parent: animation,
      curve: CorvusMotion.standard,
      reverseCurve: Curves.easeIn,
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.02),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// Aparición con retardo fijo. Sirve para lo que ya está en pantalla al
/// cargar: cabeceras, paneles, la primera pantalla de una lista corta.
class CorvusReveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset beginOffset;

  const CorvusReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = CorvusMotion.slow,
    this.beginOffset = const Offset(0, 14),
  });

  @override
  State<CorvusReveal> createState() => _CorvusRevealState();
}

class _CorvusRevealState extends State<CorvusReveal> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      // Sin retardo no hace falta un temporizador: basta con pintar el primer
      // fotograma oculto y encender en el siguiente.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _visible = true);
      });
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: widget.duration,
      curve: CorvusMotion.standard,
      child: _PixelSlide(
        offset: _visible ? Offset.zero : widget.beginOffset,
        duration: widget.duration,
        curve: CorvusMotion.standard,
        child: widget.child,
      ),
    );
  }
}

/// Desplazamiento animado **en píxeles**.
///
/// Existe porque `AnimatedSlide` mide en fracciones del tamaño del propio
/// widget, y eso convierte "entra catorce píxeles más abajo" en "entra un
/// catorce por ciento de su altura más abajo": inofensivo en una tarjeta,
/// desastroso en un bloque de dos mil píxeles, que se desplazaría casi
/// trescientos. Todos los desplazamientos de este archivo se expresan en
/// píxeles, así que la traslación también.
class _PixelSlide extends StatelessWidget {
  final Offset offset;
  final Duration duration;
  final Curve curve;
  final Widget child;

  const _PixelSlide({
    required this.offset,
    required this.duration,
    required this.curve,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Offset>(
      // Sin `begin`: `TweenAnimationBuilder` lo rellena con el valor actual en
      // cada cambio, que es justo lo que hace falta para animar de donde está
      // a donde va sin llevar la cuenta a mano.
      tween: Tween(end: offset),
      duration: duration,
      curve: curve,
      child: child,
      builder: (context, value, animatedChild) => Transform.translate(
        offset: value,
        child: animatedChild,
      ),
    );
  }
}

/// Aparición al entrar en el encuadre.
///
/// La diferencia con [CorvusReveal] es de honestidad: aquella anima con un
/// temporizador, así que en una lista de cuarenta obras las treinta que están
/// fuera de pantalla ya se han "revelado" antes de que nadie las vea, y al
/// llegar a ellas aparecen sin más. Esta escucha la posición del scroll y solo
/// se enciende cuando su caja cruza el umbral del encuadre. Una vez encendida
/// se desengancha del listener: el efecto es de entrada, no de estado.
class CorvusScrollReveal extends StatefulWidget {
  final Widget child;

  /// Desplazamiento inicial en píxeles, hacia arriba.
  final double offset;

  /// Posición en la lista. Escalona la entrada de una fila de tarjetas sin
  /// que haya que calcular retardos a mano.
  final int index;

  final Duration duration;

  /// Fracción de la altura del encuadre que debe alcanzar el borde superior
  /// del elemento para considerarlo visible. 0.92 lo enciende justo antes de
  /// asomar, que es cuando la animación se percibe como fluida y no como una
  /// carga tardía.
  final double threshold;

  const CorvusScrollReveal({
    super.key,
    required this.child,
    this.offset = 22,
    this.index = 0,
    this.duration = CorvusMotion.slow,
    this.threshold = 0.92,
  });

  @override
  State<CorvusScrollReveal> createState() => _CorvusScrollRevealState();
}

class _CorvusScrollRevealState extends State<CorvusScrollReveal> {
  ScrollPosition? _position;
  Timer? _stagger;
  Timer? _failsafe;
  bool _visible = false;

  /// El escalonado se corta pronto: más allá de la quinta tarjeta, esperar
  /// medio segundo a que aparezca lo que ya estás mirando es un defecto.
  Duration get _delay =>
      Duration(milliseconds: (widget.index.clamp(0, 5)) * 55);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attach());
  }

  void _attach() {
    if (!mounted || _visible) return;

    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _visible = true);
      return;
    }

    final position = Scrollable.maybeOf(context)?.position;

    // Fuera de un scroll —o dentro de uno horizontal— no hay nada que vigilar:
    // se comporta como una aparición normal.
    if (position == null || position.axis != Axis.vertical) {
      _reveal();
      return;
    }

    _position = position..addListener(_check);

    // Red de seguridad. Este widget oculta a su hijo hasta decidir que se ve,
    // así que cualquier fallo suyo se manifiesta como contenido que no
    // aparece —ya pasó una vez, con la búsqueda del encuadre—. Pasado un
    // segundo y medio se enciende pase lo que pase: la peor consecuencia
    // posible de este widget debe ser una animación que no se aprecia, nunca
    // un texto que no está.
    _failsafe = Timer(const Duration(milliseconds: 1500), _reveal);

    _check();
  }

  void _check() {
    if (_visible || !mounted) return;

    final position = _position;
    final box = context.findRenderObject() as RenderBox?;
    if (position == null || box == null || !box.hasSize) return;

    // `RenderAbstractViewport` es la vía pública para preguntar "¿a qué altura
    // del scroll queda esta caja?". El intento anterior buscaba el
    // `RenderObject` del `Scrollable` y lo trataba como `RenderBox`: no
    // siempre lo es, así que la comprobación se caía en silencio y el
    // contenido se quedaba en opacidad cero. Un fallo de animación que
    // esconde contenido es un fallo de contenido.
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null || !position.hasPixels) {
      _reveal();
      return;
    }

    // Distancia entre el borde superior del encuadre y el del elemento.
    final top = viewport.getOffsetToReveal(box, 0).offset - position.pixels;
    if (top < position.viewportDimension * widget.threshold) _reveal();
  }

  void _reveal() {
    _detach();
    if (_delay == Duration.zero) {
      if (mounted) setState(() => _visible = true);
      return;
    }
    _stagger = Timer(_delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  void _detach() {
    _position?.removeListener(_check);
    _position = null;
    _failsafe?.cancel();
    _failsafe = null;
  }

  @override
  void dispose() {
    _detach();
    _stagger?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: widget.duration,
      curve: CorvusMotion.standard,
      child: _PixelSlide(
        offset: _visible ? Offset.zero : Offset(0, widget.offset),
        duration: widget.duration,
        curve: CorvusMotion.entrance,
        child: widget.child,
      ),
    );
  }
}

/// Levanta al pasar por encima. Se conserva por compatibilidad con las
/// pantallas que ya lo usan; lo nuevo debería usar [CorvusPressable], que
/// además responde al dedo.
class CorvusHoverLift extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final double lift;

  const CorvusHoverLift({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 1.012,
    this.lift = 3,
  });

  @override
  Widget build(BuildContext context) {
    return CorvusPressable(
      onTap: onTap,
      hoverScale: scale,
      hoverLift: lift,
      child: child,
    );
  }
}

/// La microinteracción base de Corvus.
///
/// Tres estados sobre el mismo elemento: reposo, cursor encima y dedo o botón
/// apretado. El apretado encoge ligeramente —el gesto que todo el mundo lee
/// como "esto se ha hundido"— y es el que más importa: en un teléfono no hay
/// hover, y sin respuesta al toque la interfaz se siente muerta durante los
/// doscientos milisegundos que tarda en responder la red.
class CorvusPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Escala en reposo con el cursor encima.
  final double hoverScale;

  /// Píxeles que sube con el cursor encima.
  final double hoverLift;

  /// Escala mientras está apretado. Siempre por debajo de 1.
  final double pressedScale;

  /// Halo del acento mientras el cursor está encima. Se pinta detrás, así que
  /// necesita saber el radio del elemento para no desbordarlo.
  final Color? glow;
  final BorderRadius? borderRadius;

  /// Vibración corta al soltar, en táctil. Se apaga en elementos que se pulsan
  /// muchas veces seguidas.
  final bool haptics;

  final MouseCursor cursor;

  const CorvusPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.hoverScale = 1.015,
    this.hoverLift = 2,
    this.pressedScale = 0.975,
    this.glow,
    this.borderRadius,
    this.haptics = false,
    this.cursor = SystemMouseCursors.click,
  });

  @override
  State<CorvusPressable> createState() => _CorvusPressableState();
}

class _CorvusPressableState extends State<CorvusPressable> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _setPressed(bool value) {
    if (!_enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    if (widget.haptics) HapticFeedback.selectionClick();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final hovered = _hovered && _enabled && !still;
    final pressed = _pressed && !still;

    final double scale = pressed
        ? widget.pressedScale
        : hovered
            ? widget.hoverScale
            : 1.0;

    Widget content = AnimatedScale(
      scale: scale,
      // Apretar responde más rápido que soltar el hover: el toque tiene que
      // sentirse inmediato.
      duration: pressed ? const Duration(milliseconds: 90) : CorvusMotion.fast,
      curve: CorvusMotion.standard,
      child: _PixelSlide(
        offset: Offset(0, hovered && !pressed ? -widget.hoverLift : 0),
        duration: CorvusMotion.fast,
        curve: CorvusMotion.standard,
        child: widget.child,
      ),
    );

    if (widget.glow != null) {
      content = AnimatedContainer(
        duration: CorvusMotion.fast,
        curve: CorvusMotion.standard,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: hovered
              ? CorvusElevation.glow(widget.glow!, strength: 0.85)
              : const [],
        ),
        child: content,
      );
    }

    return MouseRegion(
      cursor: _enabled ? widget.cursor : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        // Sin acción no se declara opaco. Un `GestureDetector` opaco con
        // `onTap` nulo se traga el toque de lo que envuelve —ya pasó una vez
        // con el menú "Más", que dejó de abrirse— y aquí envolvemos tarjetas
        // que llevan sus propios botones dentro.
        behavior:
            _enabled ? HitTestBehavior.opaque : HitTestBehavior.deferToChild,
        onTap: _enabled ? _handleTap : null,
        onLongPress: widget.onLongPress,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: content,
      ),
    );
  }
}
