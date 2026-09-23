import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum ReaderPalette { dark, sepia, contrast }

class ReaderPreferences {
  final double fontSize;
  final double lineHeight;
  final double width;
  final bool serif;
  final ReaderPalette palette;
  const ReaderPreferences(
      {this.fontSize = 18,
      this.lineHeight = 1.9,
      this.width = 800,
      this.serif = true,
      this.palette = ReaderPalette.dark});

  factory ReaderPreferences.fromMap(Map<String, dynamic> map) =>
      ReaderPreferences(
        fontSize: (map['fontSize'] is num
                ? (map['fontSize'] as num).toDouble()
                : 18.0)
            .clamp(14, 30),
        lineHeight: (map['lineHeight'] is num
                ? (map['lineHeight'] as num).toDouble()
                : 1.9)
            .clamp(1.3, 2.5),
        width: (map['width'] is num ? (map['width'] as num).toDouble() : 800.0)
            .clamp(650, 1000),
        serif: map['serif'] != false,
        palette: ReaderPalette.values
                .where((value) => value.name == map['palette'])
                .firstOrNull ??
            ReaderPalette.dark,
      );

  ReaderPreferences copyWith(
          {double? fontSize,
          double? lineHeight,
          double? width,
          bool? serif,
          ReaderPalette? palette}) =>
      ReaderPreferences(
          fontSize: fontSize ?? this.fontSize,
          lineHeight: lineHeight ?? this.lineHeight,
          width: width ?? this.width,
          serif: serif ?? this.serif,
          palette: palette ?? this.palette);

  Map<String, dynamic> toMap() => {
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'width': width,
        'serif': serif,
        'palette': palette.name
      };
  Color get background => switch (palette) {
        ReaderPalette.dark => AppColors.background,
        ReaderPalette.sepia => const Color(0xFFF1E6CD),
        ReaderPalette.contrast => Colors.black
      };
  Color get foreground => switch (palette) {
        ReaderPalette.dark => AppColors.textPrimary,
        ReaderPalette.sepia => const Color(0xFF33291F),
        ReaderPalette.contrast => Colors.white
      };
}
