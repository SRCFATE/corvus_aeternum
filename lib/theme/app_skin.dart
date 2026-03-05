import 'package:flutter/material.dart';

@immutable
class AppSkin {
  final String key; // code o id de conspiración
  final String name;

  /// Brand / Accent
  final Color primary;
  final Color secondary;
  final Color tertiary;

  /// Surfaces
  final Color surface;
  final Color surfaceContainerHighest;

  /// Text/Icons on surfaces
  final Color onSurface;

  /// Text/Icons on primary
  final Color onPrimary;

  /// Outline/borders
  final Color outline;

  /// Optional: para gradients o highlights
  final Color glow;

  final double glowIntensity;

  final double uiRounding;

  final String motionProfile;

  const AppSkin({
    required this.key,
    required this.name,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.surface,
    required this.surfaceContainerHighest,
    required this.onSurface,
    required this.onPrimary,
    required this.outline,
    required this.glow,
    this.glowIntensity = 0.35,
    this.uiRounding = 18,
    this.motionProfile = 'soft',
  });

  /// Skin base por defecto (sin conspiración / guest)
  static const AppSkin base = AppSkin(
    key: 'base',
    name: 'Base',
    primary: Color(0xFFE7E2D7),
    secondary: Color(0xFF9AE6FF),
    tertiary: Color(0xFFC9B7FF),
    surface: Color(0xFF0B0B0E),
    surfaceContainerHighest: Color(0xFF14141A),
    onSurface: Color(0xFFF2F2F2),
    onPrimary: Color(0xFF0B0B0E),
    outline: Color(0x33FFFFFF),
    glow: Color(0x66E7E2D7),
    glowIntensity: 0.35,
    uiRounding: 18,
    motionProfile: 'soft',
  );

  AppSkin copyWith({
    String? key,
    String? name,
    Color? primary,
    Color? secondary,
    Color? tertiary,
    Color? surface,
    Color? surfaceContainerHighest,
    Color? onSurface,
    Color? onPrimary,
    Color? outline,
    Color? glow,
    double? glowIntensity,
    double? uiRounding,
    String? motionProfile,
  }) {
    return AppSkin(
      key: key ?? this.key,
      name: name ?? this.name,
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      tertiary: tertiary ?? this.tertiary,
      surface: surface ?? this.surface,
      surfaceContainerHighest: surfaceContainerHighest ?? this.surfaceContainerHighest,
      onSurface: onSurface ?? this.onSurface,
      onPrimary: onPrimary ?? this.onPrimary,
      outline: outline ?? this.outline,
      glow: glow ?? this.glow,
      glowIntensity: glowIntensity ?? this.glowIntensity,
      uiRounding: uiRounding ?? this.uiRounding,
    );
  }
}