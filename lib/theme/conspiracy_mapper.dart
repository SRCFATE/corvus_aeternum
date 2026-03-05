import 'package:flutter/material.dart';
import 'app_skin.dart';

Color _hexToColor(String hex, {Color fallback = const Color(0xFFFFFFFF)}) {
  final raw = hex.trim().replaceAll('#', '');
  if (raw.isEmpty) return fallback;

  final normalized = raw.length == 6 ? 'FF$raw' : raw; // RGB -> ARGB
  if (normalized.length != 8) return fallback;

  final value = int.tryParse(normalized, radix: 16);
  if (value == null) return fallback;

  return Color(value);
}

String _str(Map<String, dynamic> row, String key, String fallback) {
  final v = row[key];
  if (v == null) return fallback;
  final s = v.toString().trim();
  return s.isEmpty ? fallback : s;
}

double _dbl(Map<String, dynamic> row, String key, double fallback) {
  final v = row[key];
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  final parsed = double.tryParse(v.toString());
  return parsed ?? fallback;
}

double _rounding(Map<String, dynamic> row, String key, double fallback) {
  final v = row[key];
  if (v == null) return fallback;
  if (v is num) return v.toDouble();

  // por si guardas "lg", "md", etc.
  final s = v.toString().trim().toLowerCase();
  switch (s) {
    case 'xs':
      return 10;
    case 'sm':
      return 14;
    case 'md':
      return 18;
    case 'lg':
      return 22;
    case 'xl':
      return 28;
    default:
      final parsed = double.tryParse(s);
      return parsed ?? fallback;
  }
}

String _motion(Map<String, dynamic> row, String key, String fallback) {
  final v = row[key];
  if (v == null) return fallback;
  final s = v.toString().trim().toLowerCase();
  return s.isEmpty ? fallback : s;
}

AppSkin skinFromRow(Map<String, dynamic> row) {
  // base
  final base = AppSkin.base;

  // key visual (code si existe, si no id)
  final key = _str(row, 'code', _str(row, 'id', 'unknown'));
  final name = _str(row, 'name', key);

  // ✅ tus columnas reales
  final accent = _hexToColor(_str(row, 'accent_hex', ''), fallback: base.primary);
  final glow = _hexToColor(_str(row, 'glow_hex', ''), fallback: base.glow);

  final glowIntensity = _dbl(row, 'glow_intensity', base.glowIntensity);
  final uiRounding = _rounding(row, 'ui_rounding', base.uiRounding);
  final motionProfile = _motion(row, 'motion_profile', base.motionProfile);

  // ✅ estrategia simple: solo cambia lo que tienes (accent + glow + params)
  // lo demás se queda como base para no inventar columnas que no tienes.
  return base.copyWith(
    key: key,
    name: name,

    primary: accent,

    // si quieres que el acento también pinte secondary/tertiary, descomenta:
    // secondary: accent,
    // tertiary: accent,

    glow: glow,
    glowIntensity: glowIntensity,
    uiRounding: uiRounding,
    motionProfile: motionProfile,
  );
}