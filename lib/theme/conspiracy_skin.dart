import 'package:flutter/material.dart';

/// 🖱 Intensidad visual general
enum InteractionIntensity { soft, medium, sharp }

/// ✨ Tipo de glow aplicado a botones / highlights
enum GlowType { none, subtle, soft, strong }

/// 🌫 Perfil de movimiento (sensación de transiciones)
enum MotionProfile { slow, soft, crisp, immediate, fluid }

/// Perfil visual completo de una Conspiración
class ConspiracySkin {
  final String code;
  final String name;

  /// 🎨 Identidad
  final Color accent;

  /// ✨ Glow
  final GlowType glow;
  final double glowOpacity; // 0..1
  final Color glowColor;    // permite glow distinto al accent

  /// 🖱 Interacción
  final InteractionIntensity interaction;

  /// 🔵 Redondeo base
  final double borderRadius;

  /// 🌫 Animación base
  final MotionProfile motion;
  final int animationDurationMs;

  const ConspiracySkin({
    required this.code,
    required this.name,
    required this.accent,
    required this.glow,
    required this.glowOpacity,
    required this.glowColor,
    required this.interaction,
    required this.borderRadius,
    required this.motion,
    required this.animationDurationMs,
  });

  static const fallback = ConspiracySkin(
    code: 'DEFAULT',
    name: 'Neutral',
    accent: Color(0xFFA8AFBC),
    glow: GlowType.subtle,
    glowOpacity: 0.15,
    glowColor: Color(0xFFA8AFBC),
    interaction: InteractionIntensity.medium,
    borderRadius: 14,
    motion: MotionProfile.soft,
    animationDurationMs: 220,
  );

  static const defaultSkin = fallback;

  /// Helper para Duration en widgets
  Duration get duration => Duration(milliseconds: animationDurationMs);
}
