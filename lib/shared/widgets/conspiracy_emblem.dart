import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'corvus_crow_animations.dart';

/// Sigilo vectorial compartido por el Libro, los perfiles y las insignias.
/// La forma exterior comunica la rareza; el centro identifica a cada Casa.
class ConspiracyEmblem extends StatelessWidget {
  final String code;
  final String? symbol;
  final String label;
  final String rarity;
  final Color accent;
  final double size;
  final bool glowing;

  const ConspiracyEmblem({
    super.key,
    required this.code,
    required this.symbol,
    required this.label,
    required this.rarity,
    required this.accent,
    this.size = 48,
    this.glowing = true,
  });

  @override
  Widget build(BuildContext context) {
    final sigilSize = size * 0.54;
    final visibleAccent = _visibleAccent(
      accent,
      Theme.of(context).brightness,
    );
    return Tooltip(
      message: 'Emblema de $label',
      child: Semantics(
        image: true,
        label: 'Emblema de $label',
        child: RepaintBoundary(
          child: SizedBox.square(
            dimension: size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: glowing
                    ? [
                        BoxShadow(
                          color: visibleAccent.withValues(alpha: 0.20),
                          blurRadius: size * 0.30,
                          spreadRadius: -size * 0.08,
                        ),
                      ]
                    : null,
              ),
              child: CustomPaint(
                painter: _EmblemFramePainter(
                  accent: visibleAccent,
                  rarity: rarity,
                  code: code,
                ),
                child: Center(
                  child: symbol == 'cuervo'
                      ? CrowGlyph(
                          size: sigilSize * 1.08,
                          color: visibleAccent,
                          flap: 0.34,
                        )
                      : SizedBox.square(
                          dimension: sigilSize,
                          child: CustomPaint(
                            painter: _SigilPainter(
                              symbol: symbol,
                              accent: visibleAccent,
                            ),
                          ),
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

Color _visibleAccent(Color color, Brightness brightness) {
  final luminance = color.computeLuminance();
  if (brightness == Brightness.dark && luminance < 0.12) {
    return Color.lerp(color, Colors.white, 0.42)!;
  }
  if (brightness == Brightness.light && luminance > 0.72) {
    return Color.lerp(color, Colors.black, 0.30)!;
  }
  return color;
}

class _EmblemFramePainter extends CustomPainter {
  final Color accent;
  final String rarity;
  final String code;

  const _EmblemFramePainter({
    required this.accent,
    required this.rarity,
    required this.code,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final frame = _octagon(rect.deflate(size.width * 0.035));
    final fill = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.28, -0.34),
        radius: 1.15,
        colors: [
          accent.withValues(alpha: 0.24),
          accent.withValues(alpha: 0.07),
          const Color(0xFF0A090D),
        ],
        stops: const [0, 0.55, 1],
      ).createShader(rect);
    canvas.drawPath(frame, fill);

    final outer = Paint()
      ..color = accent.withValues(
        alpha: rarity == 'legendary' ? 0.82 : 0.52,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = rarity == 'legendary' ? 1.6 : 1.05;
    canvas.drawPath(frame, outer);

    final innerRect = rect.deflate(size.width * 0.16);
    canvas.drawOval(
      innerRect,
      Paint()
        ..color = accent.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.75,
    );

    final mark = Paint()
      ..color = accent.withValues(alpha: 0.86)
      ..strokeWidth = math.max(1, size.width * 0.026)
      ..strokeCap = StrokeCap.round;
    final center = rect.center;
    final edge = size.width * 0.095;
    final markLength = size.width * 0.105;

    void verticalMark(double x, double start, double end) {
      canvas.drawLine(Offset(x, start), Offset(x, end), mark);
    }

    if (rarity == 'root') {
      canvas.drawCircle(
        Offset(center.dx, size.height - edge),
        size.width * 0.032,
        Paint()..color = accent,
      );
      canvas.drawLine(
        Offset(center.dx - markLength, edge),
        Offset(center.dx + markLength, edge),
        mark,
      );
    } else if (rarity == 'unlockable') {
      verticalMark(center.dx - markLength * 0.55, edge, edge + markLength);
      verticalMark(center.dx + markLength * 0.55, edge, edge + markLength);
    } else if (rarity == 'legendary') {
      final ray = size.width * 0.08;
      for (var i = 0; i < 4; i++) {
        final angle = -math.pi / 2 + i * math.pi / 2;
        final start = Offset(
          center.dx + math.cos(angle) * size.width * 0.40,
          center.dy + math.sin(angle) * size.height * 0.40,
        );
        final end = Offset(
          center.dx + math.cos(angle) * (size.width * 0.40 + ray),
          center.dy + math.sin(angle) * (size.height * 0.40 + ray),
        );
        canvas.drawLine(start, end, mark);
      }
    } else {
      canvas.drawLine(
        Offset(center.dx - markLength * 0.55, edge),
        Offset(center.dx + markLength * 0.55, edge),
        mark,
      );
    }

    // Una micro-marca estable evita que dos Casas con motivos cercanos se
    // perciban como el mismo sello al reducirlos en el perfil.
    final signature =
        code.codeUnits.fold<int>(0, (sum, unit) => sum + unit) % 3;
    for (var i = 0; i <= signature; i++) {
      canvas.drawCircle(
        Offset(
          size.width * 0.22 + i * size.width * 0.08,
          size.height * 0.82,
        ),
        math.max(0.7, size.width * 0.012),
        Paint()..color = accent.withValues(alpha: 0.66),
      );
    }
  }

  Path _octagon(Rect rect) {
    final cut = rect.width * 0.18;
    return Path()
      ..moveTo(rect.left + cut, rect.top)
      ..lineTo(rect.right - cut, rect.top)
      ..lineTo(rect.right, rect.top + cut)
      ..lineTo(rect.right, rect.bottom - cut)
      ..lineTo(rect.right - cut, rect.bottom)
      ..lineTo(rect.left + cut, rect.bottom)
      ..lineTo(rect.left, rect.bottom - cut)
      ..lineTo(rect.left, rect.top + cut)
      ..close();
  }

  @override
  bool shouldRepaint(_EmblemFramePainter oldDelegate) =>
      oldDelegate.accent != accent ||
      oldDelegate.rarity != rarity ||
      oldDelegate.code != code;
}

class _SigilPainter extends CustomPainter {
  final String? symbol;
  final Color accent;

  const _SigilPainter({required this.symbol, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = accent.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.35, size.width * 0.072)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fine = Paint()
      ..color = accent.withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.9, size.width * 0.042)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = accent.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    Offset p(double x, double y) => Offset(size.width * x, size.height * y);

    switch (symbol) {
      case 'mascara':
        final mask = Path()
          ..moveTo(p(0.10, 0.42).dx, p(0.10, 0.42).dy)
          ..quadraticBezierTo(p(0.50, 0.18).dx, p(0.50, 0.18).dy,
              p(0.90, 0.42).dx, p(0.90, 0.42).dy)
          ..quadraticBezierTo(p(0.78, 0.78).dx, p(0.78, 0.78).dy,
              p(0.50, 0.66).dx, p(0.50, 0.66).dy)
          ..quadraticBezierTo(p(0.22, 0.78).dx, p(0.22, 0.78).dy,
              p(0.10, 0.42).dx, p(0.10, 0.42).dy)
          ..close();
        canvas.drawPath(mask, fill);
        canvas.drawPath(mask, stroke);
        canvas.drawArc(
            Rect.fromCenter(
                center: p(0.31, 0.47),
                width: size.width * 0.22,
                height: size.height * 0.12),
            0,
            math.pi,
            false,
            fine);
        canvas.drawArc(
            Rect.fromCenter(
                center: p(0.69, 0.47),
                width: size.width * 0.22,
                height: size.height * 0.12),
            0,
            math.pi,
            false,
            fine);
      case 'vela':
        final flame = Path()
          ..moveTo(p(0.50, 0.08).dx, p(0.50, 0.08).dy)
          ..cubicTo(p(0.72, 0.28).dx, p(0.72, 0.28).dy, p(0.66, 0.43).dx,
              p(0.66, 0.43).dy, p(0.50, 0.47).dx, p(0.50, 0.47).dy)
          ..cubicTo(p(0.34, 0.42).dx, p(0.34, 0.42).dy, p(0.31, 0.28).dx,
              p(0.31, 0.28).dy, p(0.50, 0.08).dx, p(0.50, 0.08).dy)
          ..close();
        canvas.drawPath(flame, fill);
        canvas.drawPath(flame, stroke);
        canvas.drawLine(p(0.50, 0.47), p(0.50, 0.57), fine);
        canvas.drawRect(Rect.fromPoints(p(0.30, 0.56), p(0.70, 0.90)), stroke);
        canvas.drawLine(p(0.30, 0.68), p(0.70, 0.64), fine);
      case 'puerta':
        final door = Path()
          ..moveTo(p(0.23, 0.88).dx, p(0.23, 0.88).dy)
          ..lineTo(p(0.23, 0.43).dx, p(0.23, 0.43).dy)
          ..quadraticBezierTo(p(0.50, 0.10).dx, p(0.50, 0.10).dy,
              p(0.77, 0.43).dx, p(0.77, 0.43).dy)
          ..lineTo(p(0.77, 0.88).dx, p(0.77, 0.88).dy);
        canvas.drawPath(door, stroke);
        canvas.drawLine(p(0.50, 0.20), p(0.50, 0.88), fine);
        canvas.drawCircle(
            p(0.59, 0.58), size.width * 0.035, Paint()..color = accent);
      case 'gota':
        final drop = Path()
          ..moveTo(p(0.50, 0.08).dx, p(0.50, 0.08).dy)
          ..cubicTo(p(0.35, 0.32).dx, p(0.35, 0.32).dy, p(0.20, 0.51).dx,
              p(0.20, 0.51).dy, p(0.25, 0.69).dx, p(0.25, 0.69).dy)
          ..cubicTo(p(0.33, 0.96).dx, p(0.33, 0.96).dy, p(0.67, 0.96).dx,
              p(0.67, 0.96).dy, p(0.75, 0.69).dx, p(0.75, 0.69).dy)
          ..cubicTo(p(0.80, 0.51).dx, p(0.80, 0.51).dy, p(0.65, 0.32).dx,
              p(0.65, 0.32).dy, p(0.50, 0.08).dx, p(0.50, 0.08).dy)
          ..close();
        canvas.drawPath(drop, fill);
        canvas.drawPath(drop, stroke);
        canvas.drawLine(p(0.36, 0.68), p(0.49, 0.81), fine);
      case 'fragmento':
        final shard = Path()
          ..moveTo(p(0.48, 0.08).dx, p(0.48, 0.08).dy)
          ..lineTo(p(0.86, 0.32).dx, p(0.86, 0.32).dy)
          ..lineTo(p(0.75, 0.84).dx, p(0.75, 0.84).dy)
          ..lineTo(p(0.29, 0.92).dx, p(0.29, 0.92).dy)
          ..lineTo(p(0.12, 0.43).dx, p(0.12, 0.43).dy)
          ..close();
        canvas.drawPath(shard, fill);
        canvas.drawPath(shard, stroke);
        canvas.drawPath(
            Path()
              ..moveTo(p(0.48, 0.08).dx, p(0.48, 0.08).dy)
              ..lineTo(p(0.43, 0.48).dx, p(0.43, 0.48).dy)
              ..lineTo(p(0.75, 0.84).dx, p(0.75, 0.84).dy),
            fine);
        canvas.drawLine(p(0.43, 0.48), p(0.12, 0.43), fine);
        canvas.drawLine(p(0.43, 0.48), p(0.86, 0.32), fine);
      case 'pluma':
        final feather = Path()
          ..moveTo(p(0.19, 0.86).dx, p(0.19, 0.86).dy)
          ..cubicTo(p(0.36, 0.62).dx, p(0.36, 0.62).dy, p(0.45, 0.22).dx,
              p(0.45, 0.22).dy, p(0.84, 0.11).dx, p(0.84, 0.11).dy)
          ..cubicTo(p(0.91, 0.47).dx, p(0.91, 0.47).dy, p(0.62, 0.77).dx,
              p(0.62, 0.77).dy, p(0.19, 0.86).dx, p(0.19, 0.86).dy);
        canvas.drawPath(feather, stroke);
        canvas.drawLine(p(0.20, 0.87), p(0.76, 0.22), fine);
        canvas.drawLine(p(0.36, 0.66), p(0.31, 0.45), fine);
        canvas.drawLine(p(0.49, 0.50), p(0.73, 0.48), fine);
        canvas.drawLine(p(0.61, 0.36), p(0.48, 0.25), fine);
      case 'media_luna':
        final moon = Path()
          ..moveTo(p(0.67, 0.12).dx, p(0.67, 0.12).dy)
          ..cubicTo(p(0.31, 0.19).dx, p(0.31, 0.19).dy, p(0.22, 0.67).dx,
              p(0.22, 0.67).dy, p(0.58, 0.85).dx, p(0.58, 0.85).dy)
          ..cubicTo(p(0.40, 0.59).dx, p(0.40, 0.59).dy, p(0.48, 0.31).dx,
              p(0.48, 0.31).dy, p(0.67, 0.12).dx, p(0.67, 0.12).dy)
          ..close();
        canvas.drawPath(moon, fill);
        canvas.drawPath(moon, stroke);
        canvas.drawLine(p(0.70, 0.22), p(0.59, 0.44), fine);
        canvas.drawLine(p(0.59, 0.44), p(0.75, 0.70), fine);
      case 'raiz':
        canvas.drawPath(
            Path()
              ..moveTo(p(0.50, 0.12).dx, p(0.50, 0.12).dy)
              ..lineTo(p(0.50, 0.58).dx, p(0.50, 0.58).dy)
              ..lineTo(p(0.19, 0.88).dx, p(0.19, 0.88).dy),
            stroke);
        canvas.drawLine(p(0.50, 0.58), p(0.82, 0.88), stroke);
        canvas.drawLine(p(0.50, 0.67), p(0.48, 0.92), fine);
        canvas.drawLine(p(0.35, 0.73), p(0.28, 0.60), fine);
        canvas.drawLine(p(0.65, 0.73), p(0.72, 0.60), fine);
        canvas.drawArc(
            Rect.fromCenter(
                center: p(0.50, 0.30),
                width: size.width * 0.58,
                height: size.height * 0.35),
            math.pi,
            math.pi,
            false,
            stroke);
      case 'cristal':
        final crystal = Path()
          ..moveTo(p(0.50, 0.06).dx, p(0.50, 0.06).dy)
          ..lineTo(p(0.84, 0.35).dx, p(0.84, 0.35).dy)
          ..lineTo(p(0.66, 0.91).dx, p(0.66, 0.91).dy)
          ..lineTo(p(0.34, 0.91).dx, p(0.34, 0.91).dy)
          ..lineTo(p(0.16, 0.35).dx, p(0.16, 0.35).dy)
          ..close();
        canvas.drawPath(crystal, fill);
        canvas.drawPath(crystal, stroke);
        canvas.drawLine(p(0.16, 0.35), p(0.84, 0.35), fine);
        canvas.drawLine(p(0.50, 0.06), p(0.34, 0.91), fine);
        canvas.drawLine(p(0.50, 0.06), p(0.66, 0.91), fine);
      case 'espiral':
        final spiral = Path();
        for (var i = 0; i <= 38; i++) {
          final t = i / 38 * math.pi * 3.6;
          final radius = size.width * (0.035 + 0.026 * t);
          final point = Offset(
            size.width * 0.50 + math.cos(t) * radius,
            size.height * 0.50 + math.sin(t) * radius,
          );
          if (i == 0) {
            spiral.moveTo(point.dx, point.dy);
          } else {
            spiral.lineTo(point.dx, point.dy);
          }
        }
        canvas.drawPath(spiral, stroke);
        canvas.drawLine(p(0.18, 0.72), p(0.08, 0.80), fine);
      case 'torre':
        final tower = Path()
          ..moveTo(p(0.32, 0.88).dx, p(0.32, 0.88).dy)
          ..lineTo(p(0.39, 0.35).dx, p(0.39, 0.35).dy)
          ..lineTo(p(0.61, 0.35).dx, p(0.61, 0.35).dy)
          ..lineTo(p(0.68, 0.88).dx, p(0.68, 0.88).dy)
          ..close();
        canvas.drawPath(tower, fill);
        canvas.drawPath(tower, stroke);
        canvas.drawLine(p(0.30, 0.35), p(0.70, 0.35), stroke);
        canvas.drawPath(
            Path()
              ..moveTo(p(0.35, 0.34).dx, p(0.35, 0.34).dy)
              ..lineTo(p(0.50, 0.16).dx, p(0.50, 0.16).dy)
              ..lineTo(p(0.65, 0.34).dx, p(0.65, 0.34).dy),
            fine);
        canvas.drawCircle(p(0.50, 0.25), size.width * 0.045,
            Paint()..color = const Color(0xFF0A090D));
        canvas.drawLine(p(0.39, 0.56), p(0.61, 0.56), fine);
      case 'pliegue':
        final fold = Path()
          ..moveTo(p(0.15, 0.24).dx, p(0.15, 0.24).dy)
          ..lineTo(p(0.66, 0.12).dx, p(0.66, 0.12).dy)
          ..lineTo(p(0.86, 0.38).dx, p(0.86, 0.38).dy)
          ..lineTo(p(0.70, 0.88).dx, p(0.70, 0.88).dy)
          ..lineTo(p(0.18, 0.73).dx, p(0.18, 0.73).dy)
          ..close();
        canvas.drawPath(fold, fill);
        canvas.drawPath(fold, stroke);
        canvas.drawPath(
            Path()
              ..moveTo(p(0.15, 0.24).dx, p(0.15, 0.24).dy)
              ..lineTo(p(0.56, 0.45).dx, p(0.56, 0.45).dy)
              ..lineTo(p(0.86, 0.38).dx, p(0.86, 0.38).dy),
            fine);
        canvas.drawLine(p(0.56, 0.45), p(0.70, 0.88), fine);
      case 'campana':
        final bell = Path()
          ..moveTo(p(0.20, 0.72).dx, p(0.20, 0.72).dy)
          ..quadraticBezierTo(p(0.32, 0.62).dx, p(0.32, 0.62).dy,
              p(0.33, 0.36).dx, p(0.33, 0.36).dy)
          ..quadraticBezierTo(p(0.50, 0.18).dx, p(0.50, 0.18).dy,
              p(0.67, 0.36).dx, p(0.67, 0.36).dy)
          ..quadraticBezierTo(p(0.68, 0.62).dx, p(0.68, 0.62).dy,
              p(0.80, 0.72).dx, p(0.80, 0.72).dy)
          ..close();
        canvas.drawPath(bell, fill);
        canvas.drawPath(bell, stroke);
        canvas.drawCircle(
            p(0.50, 0.80), size.width * 0.055, Paint()..color = accent);
        canvas.drawArc(
            Rect.fromCenter(
                center: p(0.50, 0.47),
                width: size.width * 0.88,
                height: size.height * 0.82),
            -0.8,
            1.6,
            false,
            fine);
      case 'espada_cruzada':
        void sword(Offset start, Offset end, double direction) {
          canvas.drawLine(start, end, stroke);
          final midpoint = Offset.lerp(start, end, 0.72)!;
          final normal = Offset(-direction, direction) * size.width * 0.10;
          canvas.drawLine(midpoint - normal, midpoint + normal, fine);
        }
        sword(p(0.20, 0.16), p(0.80, 0.84), 0.70);
        sword(p(0.80, 0.16), p(0.20, 0.84), -0.70);
        canvas.drawCircle(p(0.50, 0.50), size.width * 0.07, fill);
      case 'reloj':
        final clockRect = Rect.fromCenter(
            center: p(0.50, 0.52),
            width: size.width * 0.70,
            height: size.height * 0.70);
        canvas.drawArc(
            clockRect, -math.pi * 0.42, math.pi * 1.65, false, stroke);
        canvas.drawLine(p(0.50, 0.52), p(0.50, 0.27), stroke);
        canvas.drawLine(p(0.50, 0.52), p(0.67, 0.64), stroke);
        canvas.drawLine(p(0.38, 0.10), p(0.62, 0.10), fine);
        canvas.drawLine(p(0.50, 0.10), p(0.50, 0.18), fine);
      case 'profundidad':
        for (var i = 0; i < 3; i++) {
          final y = 0.30 + i * 0.18;
          final wave = Path()
            ..moveTo(p(0.10, y).dx, p(0.10, y).dy)
            ..cubicTo(
                p(0.28, y - 0.13).dx,
                p(0.28, y - 0.13).dy,
                p(0.40, y + 0.13).dx,
                p(0.40, y + 0.13).dy,
                p(0.56, y).dx,
                p(0.56, y).dy)
            ..cubicTo(
                p(0.71, y - 0.12).dx,
                p(0.71, y - 0.12).dy,
                p(0.82, y + 0.07).dx,
                p(0.82, y + 0.07).dy,
                p(0.91, y).dx,
                p(0.91, y).dy);
          canvas.drawPath(wave, i == 2 ? stroke : fine);
        }
        canvas.drawLine(p(0.50, 0.72), p(0.50, 0.91), fine);
        canvas.drawLine(p(0.43, 0.84), p(0.50, 0.91), fine);
        canvas.drawLine(p(0.57, 0.84), p(0.50, 0.91), fine);
      case 'sello':
        final seal = Path()
          ..moveTo(p(0.50, 0.08).dx, p(0.50, 0.08).dy)
          ..lineTo(p(0.82, 0.26).dx, p(0.82, 0.26).dy)
          ..lineTo(p(0.82, 0.66).dx, p(0.82, 0.66).dy)
          ..lineTo(p(0.50, 0.90).dx, p(0.50, 0.90).dy)
          ..lineTo(p(0.18, 0.66).dx, p(0.18, 0.66).dy)
          ..lineTo(p(0.18, 0.26).dx, p(0.18, 0.26).dy)
          ..close();
        canvas.drawPath(seal, fill);
        canvas.drawPath(seal, stroke);
        canvas.drawLine(p(0.32, 0.38), p(0.68, 0.38), fine);
        canvas.drawLine(p(0.32, 0.53), p(0.60, 0.53), fine);
        canvas.drawLine(p(0.32, 0.68), p(0.52, 0.68), fine);
        canvas.drawLine(p(0.27, 0.24), p(0.73, 0.73), stroke);
      case 'ojo_abierto':
        final eye = Path()
          ..moveTo(p(0.08, 0.50).dx, p(0.08, 0.50).dy)
          ..quadraticBezierTo(p(0.50, 0.10).dx, p(0.50, 0.10).dy,
              p(0.92, 0.50).dx, p(0.92, 0.50).dy)
          ..quadraticBezierTo(p(0.50, 0.90).dx, p(0.50, 0.90).dy,
              p(0.08, 0.50).dx, p(0.08, 0.50).dy)
          ..close();
        canvas.drawPath(eye, stroke);
        canvas.drawCircle(p(0.50, 0.50), size.width * 0.15, fill);
        canvas.drawCircle(
            p(0.50, 0.50), size.width * 0.07, Paint()..color = accent);
        canvas.drawLine(p(0.50, 0.02), p(0.50, 0.14), fine);
      case 'vacio':
        canvas.drawArc(
            Rect.fromCenter(
                center: p(0.50, 0.50),
                width: size.width * 0.72,
                height: size.height * 0.72),
            0.18,
            math.pi * 1.55,
            false,
            stroke);
        canvas.drawArc(
            Rect.fromCenter(
                center: p(0.50, 0.50),
                width: size.width * 0.42,
                height: size.height * 0.42),
            math.pi,
            math.pi * 1.35,
            false,
            fine);
        canvas.drawCircle(p(0.50, 0.50), size.width * 0.045,
            Paint()..color = const Color(0xFF0A090D));
      case 'corona':
        final crown = Path()
          ..moveTo(p(0.14, 0.30).dx, p(0.14, 0.30).dy)
          ..lineTo(p(0.31, 0.53).dx, p(0.31, 0.53).dy)
          ..lineTo(p(0.50, 0.18).dx, p(0.50, 0.18).dy)
          ..lineTo(p(0.69, 0.53).dx, p(0.69, 0.53).dy)
          ..lineTo(p(0.86, 0.30).dx, p(0.86, 0.30).dy)
          ..lineTo(p(0.77, 0.78).dx, p(0.77, 0.78).dy)
          ..lineTo(p(0.23, 0.78).dx, p(0.23, 0.78).dy)
          ..close();
        canvas.drawPath(crown, fill);
        canvas.drawPath(crown, stroke);
        canvas.drawLine(p(0.23, 0.66), p(0.77, 0.66), fine);
        canvas.drawCircle(
            p(0.50, 0.18), size.width * 0.045, Paint()..color = accent);
      case 'disco':
        canvas.drawCircle(p(0.43, 0.50), size.width * 0.31,
            Paint()..color = accent.withValues(alpha: 0.32));
        canvas.drawCircle(p(0.43, 0.50), size.width * 0.31, stroke);
        canvas.drawCircle(p(0.58, 0.43), size.width * 0.29,
            Paint()..color = const Color(0xFF0A090D));
        canvas.drawArc(
            Rect.fromCircle(center: p(0.43, 0.50), radius: size.width * 0.40),
            -0.72,
            1.45,
            false,
            fine);
      default:
        final unknown = Path()
          ..moveTo(p(0.50, 0.08).dx, p(0.50, 0.08).dy)
          ..lineTo(p(0.88, 0.50).dx, p(0.88, 0.50).dy)
          ..lineTo(p(0.50, 0.92).dx, p(0.50, 0.92).dy)
          ..lineTo(p(0.12, 0.50).dx, p(0.12, 0.50).dy)
          ..close();
        canvas.drawPath(unknown, stroke);
        canvas.drawCircle(p(0.50, 0.50), size.width * 0.07, fill);
    }
  }

  @override
  bool shouldRepaint(_SigilPainter oldDelegate) =>
      oldDelegate.symbol != symbol || oldDelegate.accent != accent;
}
