import 'package:flutter/material.dart';

// Modelos de dominio del Sistema de Conspiraciones v5.
// El cliente solo lee estos estados; toda transición ocurre por RPC.

class ConspiracyProgress {
  final String conspiracyId;
  final String code;
  final String name;
  final double metricValue;
  final double targetValue;
  final int level;
  final String state;
  final Map<String, dynamic> details;
  final DateTime? evaluatedAt;

  const ConspiracyProgress({
    required this.conspiracyId,
    required this.code,
    required this.name,
    required this.metricValue,
    required this.targetValue,
    required this.level,
    required this.state,
    this.details = const {},
    this.evaluatedAt,
  });

  factory ConspiracyProgress.fromMap(Map<String, dynamic> map) {
    double number(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse('$value') ?? 0;
    }

    return ConspiracyProgress(
      conspiracyId: map['conspiracy_id'] as String? ?? '',
      code: map['code'] as String? ?? '',
      name: map['name'] as String? ?? '',
      metricValue: number(map['metric_value']),
      targetValue: number(map['target_value']),
      level: (map['level'] as num?)?.toInt() ?? 0,
      state: map['state'] as String? ?? 'tracking',
      details: map['details'] is Map
          ? Map<String, dynamic>.from(map['details'] as Map)
          : const {},
      evaluatedAt: DateTime.tryParse(map['evaluated_at'] as String? ?? ''),
    );
  }

  double get ratio {
    if (targetValue <= 0) return 0;
    return (metricValue / targetValue).clamp(0, 1).toDouble();
  }

  bool get effectActive => details['effect_active'] == true;
  String get metricLabel => details['metric_label'] as String? ?? 'Progreso';

  String get stateLabel => switch (state) {
        'available' => 'Disponible para elegir',
        'active' => 'Presencia activa',
        'awakened' => 'Raíz despierta',
        'eligible' => 'Requisito cumplido',
        'candidate' => 'Candidatura detectada',
        'unlocked' => 'Conspiración conquistada',
        'hidden' => 'Registro velado',
        'veiled' => 'Bajo observación',
        _ => 'Evidencia en curso',
      };

  String get effectLabel => switch (details['effect_key']) {
        'root_awakened' => 'Raíz despierta',
        'layered_mask' => 'Máscara estratificada',
        'growing_flame' => 'Llama creciente',
        'open_door' => 'Puerta del Umbral',
        'silent_profile' => 'Perfil silente',
        'completed_fragment' => 'Fragmento completo',
        'inked_feather' => 'Pluma entintada',
        'split_moon' => 'Luna hendida',
        'root_branches' => 'Ramificaciones profundas',
        'deep_crystal' => 'Cristal de mirada',
        'reversed_spiral' => 'Espiral inversa',
        'lighthouse_blocks' => 'Bloques del Faro',
        'folded_shadow' => 'Sombra plegada',
        'final_bell' => 'Campana final',
        'blood_pact_channel' => 'Canal del Pacto',
        'stopped_clock' => 'Reloj detenido',
        'abyss_depth' => 'Profundidad del Abismo',
        'practice_seal' => 'Sello de práctica',
        'open_eye' => 'Ojo abierto',
        'absence_mark' => 'Marca de ausencia',
        'imperial_crown' => 'Corona Imperial',
        'eclipse_halo' => 'Halo de Eclipse',
        _ => 'Presencia de la Casa',
      };

  String get metricText {
    String format(double value) => value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    return '${format(metricValue)} / ${format(targetValue)}';
  }
}

class ConspiracySummary {
  final String id;
  final String code;
  final String name;
  final String? registryNumber;
  final String rarity; // root / free / unlockable / legendary
  final String? symbol;
  final String? lore;
  final String accentHex;
  final String glowHex;

  const ConspiracySummary({
    required this.id,
    required this.code,
    required this.name,
    this.registryNumber,
    required this.rarity,
    this.symbol,
    this.lore,
    required this.accentHex,
    required this.glowHex,
  });

  factory ConspiracySummary.fromMap(Map<String, dynamic> map) {
    return ConspiracySummary(
      id: map['id'] as String,
      code: map['code'] as String,
      name: map['name'] as String? ?? '',
      registryNumber: map['registry_number']?.toString(),
      rarity: map['rarity'] as String? ?? 'free',
      symbol: map['symbol'] as String?,
      lore: map['lore'] as String?,
      accentHex: map['accent_hex'] as String? ?? '#CC3333',
      glowHex: map['glow_hex'] as String? ?? '#CC3333',
    );
  }

  Color get accentColor {
    final h = accentHex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  /// "Conspiración del Velo Ceniza" → "Velo Ceniza"
  String get shortName {
    return name
        .replaceFirst(
            RegExp(r'^Conspiración (del|de la|de las|de los|de)\s+'), '')
        .replaceFirst(RegExp(r'^Conspiración\s+'), '');
  }
}

class ConspiracyMembership {
  final ConspiracySummary house;
  final String role; // primary / secondary
  final DateTime? joinedAt;

  const ConspiracyMembership({
    required this.house,
    required this.role,
    this.joinedAt,
  });

  factory ConspiracyMembership.fromMap(Map<String, dynamic> map) {
    return ConspiracyMembership(
      house: ConspiracySummary.fromMap(map),
      role: map['role'] as String? ?? 'secondary',
      joinedAt: map['joined_at'] != null
          ? DateTime.tryParse(map['joined_at'] as String)
          : null,
    );
  }
}

/// Pluma caída: entrada del historial (Mudas y elecciones).
class FallenFeather {
  final String eventType; // molt / first_choice
  final String? fromName;
  final String? toName;
  final DateTime createdAt;

  const FallenFeather({
    required this.eventType,
    this.fromName,
    this.toName,
    required this.createdAt,
  });

  factory FallenFeather.fromMap(Map<String, dynamic> map) {
    return FallenFeather(
      eventType: map['event_type'] as String? ?? '',
      fromName: map['from_name'] as String?,
      toName: map['to_name'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class EffectiveMemberships {
  final ConspiracySummary? root;
  final ConspiracyMembership? primary;
  final List<ConspiracyMembership> secondaries;
  final List<ConspiracySummary> unlocks;
  final List<FallenFeather> history;

  const EffectiveMemberships({
    this.root,
    this.primary,
    this.secondaries = const [],
    this.unlocks = const [],
    this.history = const [],
  });

  factory EffectiveMemberships.fromMap(Map<String, dynamic> map) {
    return EffectiveMemberships(
      root: map['root'] != null
          ? ConspiracySummary.fromMap(Map<String, dynamic>.from(map['root']))
          : null,
      primary: map['primary'] != null
          ? ConspiracyMembership.fromMap(
              Map<String, dynamic>.from(map['primary']))
          : null,
      secondaries: ((map['secondaries'] as List?) ?? [])
          .map(
              (e) => ConspiracyMembership.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      unlocks: ((map['unlocks'] as List?) ?? [])
          .map((e) => ConspiracySummary.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      history: ((map['history'] as List?) ?? [])
          .map((e) => FallenFeather.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  bool get hasPrimary => primary != null;
  bool hasSecondary(String conspiracyId) =>
      secondaries.any((s) => s.house.id == conspiracyId);
}

class ConspiracyActionResult {
  final bool ok;
  final String? reasonCode;
  final EffectiveMemberships? memberships;

  const ConspiracyActionResult({
    required this.ok,
    this.reasonCode,
    this.memberships,
  });

  factory ConspiracyActionResult.fromMap(Map<String, dynamic> map) {
    return ConspiracyActionResult(
      ok: map['ok'] as bool? ?? false,
      reasonCode: map['reason_code'] as String?,
      memberships: map['memberships'] != null
          ? EffectiveMemberships.fromMap(
              Map<String, dynamic>.from(map['memberships']))
          : null,
    );
  }
}

class MoltEligibility {
  final bool eligible;
  final String? reasonCode;
  final String? seasonId;
  final DateTime? seasonEndsAt;

  const MoltEligibility({
    required this.eligible,
    this.reasonCode,
    this.seasonId,
    this.seasonEndsAt,
  });

  factory MoltEligibility.fromMap(Map<String, dynamic> map) {
    return MoltEligibility(
      eligible: map['eligible'] as bool? ?? false,
      reasonCode: map['reason_code'] as String?,
      seasonId: map['season_id'] as String?,
      seasonEndsAt: map['season_ends_at'] != null
          ? DateTime.tryParse(map['season_ends_at'] as String)
          : null,
    );
  }
}

/// Invitación a una casa que se entra por rito, no por elección
/// (hoy: el Pacto de Sangre). Solo la ven el que invita y el invitado.
class ConspiracyInvitation {
  final String id;
  final String conspiracyId;
  final String conspiracyName;
  final String conspiracyAccentHex;
  final String inviterId;
  final String? inviterName;
  final String? inviterUsername;
  final String? inviterAvatarUrl;
  final String note;
  final String status; // pending / accepted / declined / expired
  final DateTime createdAt;
  final DateTime? expiresAt;

  const ConspiracyInvitation({
    required this.id,
    required this.conspiracyId,
    required this.conspiracyName,
    required this.conspiracyAccentHex,
    required this.inviterId,
    this.inviterName,
    this.inviterUsername,
    this.inviterAvatarUrl,
    this.note = '',
    required this.status,
    required this.createdAt,
    this.expiresAt,
  });

  factory ConspiracyInvitation.fromMap(Map<String, dynamic> map) {
    final house = map['conspirations'] as Map<String, dynamic>?;
    final inviter = map['inviter'] as Map<String, dynamic>?;
    return ConspiracyInvitation(
      id: map['id'] as String,
      conspiracyId: map['conspiracy_id'] as String,
      conspiracyName: house?['name'] as String? ?? 'Conspiración',
      conspiracyAccentHex: house?['accent_hex'] as String? ?? '#CC3333',
      inviterId: map['inviter_id'] as String,
      inviterName: inviter?['display_name'] as String?,
      inviterUsername: inviter?['username'] as String?,
      inviterAvatarUrl: inviter?['avatar_url'] as String?,
      note: map['note'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      expiresAt: map['expires_at'] != null
          ? DateTime.tryParse(map['expires_at'] as String)
          : null,
    );
  }

  Color get accentColor {
    final h = conspiracyAccentHex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  String get shortHouseName => conspiracyName
      .replaceFirst(
          RegExp(r'^Conspiración (del|de la|de las|de los|de)\s+'), '')
      .replaceFirst(RegExp(r'^Conspiración\s+'), '');

  String get inviterLabel =>
      inviterName ?? (inviterUsername != null ? '@$inviterUsername' : 'Alguien');

  bool get isPending => status == 'pending';

  /// Días que quedan antes de que la invitación pierda su pulso.
  int? get daysLeft {
    if (expiresAt == null) return null;
    final d = expiresAt!.difference(DateTime.now()).inDays;
    return d < 0 ? 0 : d;
  }
}
