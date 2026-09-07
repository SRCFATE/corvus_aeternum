import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/corvus_design.dart';

/// El botón de Corvus.
///
/// Tres cosas que antes no hacía y que son la diferencia entre un control que
/// obedece y uno que responde:
///
/// 1. **Se hunde al pulsarlo.** En un teléfono no hay cursor, así que sin esto
///    el único indicio de que el toque ha entrado llega cuando responde la
///    red. Doscientos milisegundos sin señal se sienten como un botón roto, y
///    la reacción natural es volver a pulsar.
/// 2. **La rueda de espera no encoge el botón.** Antes el contenido pasaba de
///    un texto a un aro de veinte píxeles y la fila entera se recolocaba; el
///    botón conserva su tamaño y solo cambia lo que lleva dentro.
/// 3. **El cambio a espera se funde**, en vez de saltar.
class CorvusButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool outlined;
  final IconData? icon;
  final double? width;

  const CorvusButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.outlined = false,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = !isLoading && onPressed != null;

    final Widget child = AnimatedSwitcher(
      duration: CorvusMotion.fast,
      switchInCurve: CorvusMotion.standard,
      switchOutCurve: CorvusMotion.standard,
      child: isLoading
          ? SizedBox(
              key: const ValueKey('cargando'),
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: outlined ? AppColors.primary : AppColors.background,
              ),
            )
          : Row(
              key: const ValueKey('etiqueta'),
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: CorvusSpacing.sm),
                ],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
    );

    // El hueco mínimo evita que la fila salte al entrar en espera: el aro mide
    // menos que el texto que sustituye.
    final Widget sized = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 20),
      child: Center(child: child),
    );

    final Widget button = SizedBox(
      width: width,
      child: outlined
          ? OutlinedButton(onPressed: enabled ? onPressed : null, child: sized)
          : ElevatedButton(onPressed: enabled ? onPressed : null, child: sized),
    );

    // Mientras carga no se hunde: el gesto ya se registró y repetir la
    // animación sugeriría que hace falta pulsar otra vez.
    if (!enabled) return button;

    return _PressScale(child: button);
  }
}

/// Añade el hundido a un botón que ya sabe responder por sí mismo.
///
/// Usa `Listener` y no `GestureDetector` a propósito: `Listener` observa los
/// punteros sin entrar en la arena de gestos, así que el toque sigue llegando
/// entero al botón de Material que hay debajo. Con un `GestureDetector`
/// encima, el `onTap` se dispararía dos veces —el del envoltorio y el del
/// botón— y en un formulario eso es un envío duplicado.
class _PressScale extends StatefulWidget {
  final Widget child;

  const _PressScale({required this.child});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);

    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed && !still ? 0.97 : 1,
        duration:
            _pressed ? const Duration(milliseconds: 90) : CorvusMotion.fast,
        curve: CorvusMotion.standard,
        child: widget.child,
      ),
    );
  }
}

class CorvusIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final String? tooltip;
  final double size;

  const CorvusIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.tooltip,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: size, color: color ?? AppColors.textSecondary),
      onPressed: onPressed,
      tooltip: tooltip,
      splashRadius: 20,
    );
  }
}
