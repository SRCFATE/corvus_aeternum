import 'package:flutter/material.dart';

class Conspiration {
  final String id;
  final String code;
  final String name;
  final String accentHex;
  final String glowHex;
  final double glowIntensity;
  final String motionProfile;
  final double uiRounding;
  final bool isActive;
  final String? baseHex;
  final String? surfaceHex;
  final String? textPrimaryHex;
  final String? textSecondaryHex;
  final String? borderHex;
  final String? focusHex;
  final String? overlayHex;
  final int? number;
  final String? symbol;
  final String? tier;
  final String? lore;
  final String? mechanicGeneral;
  final String? mechanicPassive;
  final String? mechanicActive;
  final String? exclusiveAccess;
  final bool isDefault;
  final String rarity; // root / free / unlockable / legendary
  final String? registryNumber;
  final String selectionPolicy;
  final bool competitionEligible;

  const Conspiration({
    required this.id,
    required this.code,
    required this.name,
    required this.accentHex,
    required this.glowHex,
    required this.glowIntensity,
    required this.motionProfile,
    required this.uiRounding,
    required this.isActive,
    this.baseHex,
    this.surfaceHex,
    this.textPrimaryHex,
    this.textSecondaryHex,
    this.borderHex,
    this.focusHex,
    this.overlayHex,
    this.number,
    this.symbol,
    this.tier,
    this.lore,
    this.mechanicGeneral,
    this.mechanicPassive,
    this.mechanicActive,
    this.exclusiveAccess,
    required this.isDefault,
    this.rarity = 'free',
    this.registryNumber,
    this.selectionPolicy = 'manual',
    this.competitionEligible = true,
  });

  factory Conspiration.fromMap(Map<String, dynamic> map) {
    return Conspiration(
      id: map['id'] as String,
      code: map['code'] as String,
      name: map['name'] as String,
      accentHex: map['accent_hex'] as String? ?? '#7F77DD',
      glowHex: map['glow_hex'] as String? ?? '#7F77DD',
      glowIntensity: (map['glow_intensity'] as num?)?.toDouble() ?? 0.35,
      motionProfile: map['motion_profile'] as String? ?? 'default',
      uiRounding: (map['ui_rounding'] as num?)?.toDouble() ?? 16,
      isActive: map['is_active'] as bool? ?? true,
      baseHex: map['base_hex'] as String?,
      surfaceHex: map['surface_hex'] as String?,
      textPrimaryHex: map['text_primary_hex'] as String?,
      textSecondaryHex: map['text_secondary_hex'] as String?,
      borderHex: map['border_hex'] as String?,
      focusHex: map['focus_hex'] as String?,
      overlayHex: map['overlay_hex'] as String?,
      number: map['number'] as int?,
      symbol: map['symbol'] as String?,
      tier: map['tier'] as String?,
      lore: map['lore'] as String?,
      mechanicGeneral: map['mechanic_general'] as String?,
      mechanicPassive: map['mechanic_passive'] as String?,
      mechanicActive: map['mechanic_active'] as String?,
      exclusiveAccess: map['exclusive_access'] as String?,
      isDefault: map['is_default'] as bool? ?? false,
      rarity: map['rarity'] as String? ?? 'free',
      registryNumber: map['registry_number']?.toString(),
      selectionPolicy: map['selection_policy'] as String? ?? 'manual',
      competitionEligible: map['competition_eligible'] as bool? ?? true,
    );
  }

  /// "Conspiración del Velo Ceniza" → "Velo Ceniza"
  String get shortName {
    return name
        .replaceFirst(
            RegExp(r'^Conspiración (del|de la|de las|de los|de)\s+'), '')
        .replaceFirst(RegExp(r'^Conspiración\s+'), '');
  }

  Color get accentColor => _hexToColor(accentHex);
  Color get glowColor => _hexToColor(glowHex);

  static Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}
