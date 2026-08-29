import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

// ─── Silueta de cuervo en vuelo ───────────────────────────────────────────────

// Dibuja la silueta clásica de un ave en vuelo: dos alas curvas cuyo ángulo
// varía con [flap] ∈ [-1, 1] (positivo = alas arriba).
void _paintCrow(
  Canvas canvas, {
  required Offset center,
  required double wingspan,
  required double flap,
  required Color color,
  double strokeScale = 1.0,
}) {
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = wingspan * 0.16 * strokeScale
    ..strokeCap = StrokeCap.round;

  final tipDy = -wingspan * 0.62 * flap;
  final path = Path()
    ..moveTo(center.dx - wingspan, center.dy + tipDy)
    ..quadraticBezierTo(
      center.dx - wingspan * 0.42,
      center.dy + wingspan * 0.30,
      center.dx,
      center.dy,
    )
    ..quadraticBezierTo(
      center.dx + wingspan * 0.42,
      center.dy + wingspan * 0.30,
      center.dx + wingspan,
      center.dy + tipDy,
    );

  canvas.drawPath(path, paint);
}

// ─── CrowGlyph ────────────────────────────────────────────────────────────────

/// Silueta estática de cuervo, para emblemas y decoración.
class CrowGlyph extends StatelessWidget {
  final double size;
  final Color color;
  final double flap;

  const CrowGlyph({
    super.key,
    required this.size,
    required this.color,
    this.flap = 0.45,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CrowGlyphPainter(color: color, flap: flap),
      ),
    );
  }
}

class _CrowGlyphPainter extends CustomPainter {
  final Color color;
  final double flap;

  _CrowGlyphPainter({required this.color, required this.flap});

  @override
  void paint(Canvas canvas, Size size) {
    _paintCrow(
      canvas,
      center: Offset(size.width / 2, size.height * 0.58),
      wingspan: size.width * 0.38,
      flap: flap,
      color: color,
    );
  }

  @override
  bool shouldRepaint(_CrowGlyphPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.flap != flap;
}

// ─── CorvusCrowLoader ─────────────────────────────────────────────────────────

/// Indicador de carga de Corvus: un cuervo aleteando con un segundo cuervo de
/// escolta. Sustituye al CircularProgressIndicator en las pantallas clave.
class CorvusCrowLoader extends StatefulWidget {
  final String? label;
  final Color? color;
  final double size;

  const CorvusCrowLoader({
    super.key,
    this.label,
    this.color,
    this.size = 64,
  });

  @override
  State<CorvusCrowLoader> createState() => _CorvusCrowLoaderState();
}

class _CorvusCrowLoaderState extends State<CorvusCrowLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0.35;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, __) => CustomPaint(
              painter: _CrowLoaderPainter(
                progress: _controller.value,
                color: color,
              ),
            ),
          ),
        ),
        if (widget.label != null) ...[
          const SizedBox(height: 16),
          Text(
            widget.label!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ],
    );
  }
}

class _CrowLoaderPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CrowLoaderPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 2 * math.pi;
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Cuervo principal: aleteo doble por ciclo + balanceo vertical.
    final flap = math.sin(t * 2);
    final bob = math.sin(t) * size.height * 0.05;

    // Cuervo de escolta, más pequeño y desfasado.
    _paintCrow(
      canvas,
      center:
          Offset(cx - size.width * 0.26, cy - size.height * 0.22 - bob * 0.6),
      wingspan: size.width * 0.15,
      flap: math.sin(t * 2 + 1.7),
      color: color.withValues(alpha: 0.35),
    );

    _paintCrow(
      canvas,
      center: Offset(cx + size.width * 0.06, cy + bob),
      wingspan: size.width * 0.30,
      flap: flap,
      color: color,
    );
  }

  @override
  bool shouldRepaint(_CrowLoaderPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

// ─── FallingFeather ───────────────────────────────────────────────────────────

/// Una pluma de cuervo que cae balanceándose en bucle. Pensada para estados
/// vacíos y espacios de espera tranquilos.
class FallingFeather extends StatefulWidget {
  final double height;
  final Color? color;

  const FallingFeather({super.key, this.height = 48, this.color});

  @override
  State<FallingFeather> createState() => _FallingFeatherState();
}

class _FallingFeatherState extends State<FallingFeather>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0.42;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Colors.white.withValues(alpha: 0.30);
    return SizedBox(
      width: widget.height * 0.9,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => CustomPaint(
          painter: _FeatherPainter(progress: _controller.value, color: color),
        ),
      ),
    );
  }
}

class _FeatherPainter extends CustomPainter {
  final double progress;
  final Color color;

  _FeatherPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress;

    // Fade de entrada y salida para que el bucle no salte.
    final fade = p < 0.12
        ? p / 0.12
        : p > 0.82
            ? (1 - p) / 0.18
            : 1.0;

    final drop = size.height * (p * 1.15 - 0.15);
    final sway = math.sin(p * math.pi * 3) * size.width * 0.22;
    final tilt = math.sin(p * math.pi * 3 + math.pi / 2) * 0.5;

    canvas.save();
    canvas.translate(size.width / 2 + sway, drop);
    canvas.rotate(tilt);

    final featherH = size.height * 0.52;
    final featherW = featherH * 0.34;
    final faded = color.withValues(alpha: color.a * fade.clamp(0.0, 1.0));

    // Vano (cuerpo de la pluma)
    final vane = Path()
      ..moveTo(0, -featherH / 2)
      ..quadraticBezierTo(
          featherW, -featherH * 0.18, featherW * 0.30, featherH * 0.30)
      ..quadraticBezierTo(featherW * 0.10, featherH * 0.42, 0, featherH * 0.34)
      ..quadraticBezierTo(
          -featherW * 0.10, featherH * 0.42, -featherW * 0.30, featherH * 0.30)
      ..quadraticBezierTo(-featherW, -featherH * 0.18, 0, -featherH / 2)
      ..close();
    canvas.drawPath(
      vane,
      Paint()
        ..color = faded.withValues(alpha: faded.a * 0.45)
        ..style = PaintingStyle.fill,
    );

    // Raquis (el eje central) con cálamo hacia abajo
    canvas.drawLine(
      Offset(0, -featherH / 2),
      Offset(0, featherH * 0.52),
      Paint()
        ..color = faded
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_FeatherPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

// ─── Vuelo de cuervos (celebración) ───────────────────────────────────────────

/// Muestra una bandada breve de cuervos alzando el vuelo. Úsala como
/// celebración al publicar o sellar una obra. Se descarta sola.
Future<void> showCrowFlight(BuildContext context) {
  if (MediaQuery.disableAnimationsOf(context)) return Future.value();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    barrierLabel: 'crow-flight',
    transitionDuration: Duration.zero,
    pageBuilder: (ctx, _, __) => _CrowFlightOverlay(
      onDone: () {
        if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
      },
    ),
  );
}

class _CrowFlightOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const _CrowFlightOverlay({required this.onDone});

  @override
  State<_CrowFlightOverlay> createState() => _CrowFlightOverlayState();
}

class _CrowFlightOverlayState extends State<_CrowFlightOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenCompleteOrCancel(widget.onDone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => CustomPaint(
          size: MediaQuery.sizeOf(context),
          painter: _CrowFlightPainter(progress: _controller.value),
        ),
      ),
    );
  }
}

class _CrowFlightPainter extends CustomPainter {
  final double progress;

  _CrowFlightPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const crowCount = 8;
    final origin = Offset(size.width / 2, size.height * 0.62);

    for (var i = 0; i < crowCount; i++) {
      // Pseudo-aleatoriedad determinista por índice.
      final seed = (i * 37 + 11) % 100 / 100;
      final angle =
          -math.pi * (0.25 + 0.5 * (i / (crowCount - 1))) + (seed - 0.5) * 0.3;
      final distance = size.shortestSide * (0.38 + seed * 0.34);
      final delay = seed * 0.22;

      final local = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (local == 0) continue;

      final eased = Curves.easeOutCubic.transform(local);
      final pos = origin +
          Offset(math.cos(angle), math.sin(angle)) * (distance * eased);

      // Aparece y se desvanece dentro de su propio tramo.
      final opacity = math.sin(local * math.pi).clamp(0.0, 1.0);
      final wingspan = size.shortestSide * (0.020 + seed * 0.016);
      final flap = math.sin(local * math.pi * 6 + i);

      _paintCrow(
        canvas,
        center: pos,
        wingspan: wingspan,
        flap: flap,
        color: Colors.white.withValues(alpha: 0.72 * opacity),
        strokeScale: 0.9,
      );
    }
  }

  @override
  bool shouldRepaint(_CrowFlightPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
