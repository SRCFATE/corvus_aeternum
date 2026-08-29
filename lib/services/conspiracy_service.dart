import '../core/supabase_config.dart';
import '../models/conspiracy_membership.dart';
import '../models/conspiration.dart';

/// Servicio del Sistema de Conspiraciones v5.
/// Todas las transiciones son server-authoritative vía RPC: el cliente
/// solicita, nunca declara.
class ConspiracyService {
  Future<List<Conspiration>> getCatalog() async {
    final data = await supabase
        .from('conspirations')
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return (data as List)
        .map((e) => Conspiration.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<EffectiveMemberships?> getEffectiveMemberships() async {
    final data = await supabase.rpc('get_effective_memberships');
    final map = Map<String, dynamic>.from(data as Map);
    if (map['ok'] != true) return null;
    return EffectiveMemberships.fromMap(map);
  }

  /// Ritos que esperan respuesta del usuario en sesión. RLS solo devuelve las
  /// invitaciones en las que participa.
  Future<List<ConspiracyInvitation>> pendingInvitations() async {
    final data = await supabase
        .from('conspiracy_invitations')
        .select(
          'id, conspiracy_id, inviter_id, note, status, created_at, expires_at, '
          'conspirations(name, accent_hex), '
          'inviter:profiles!conspiracy_invitations_inviter_id_fkey('
          'username, display_name, avatar_url)',
        )
        .eq('invitee_id', supabase.auth.currentUser?.id ?? '')
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => ConspiracyInvitation.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// ¿El usuario en sesión pertenece a esta casa por conquista? Determina si
  /// puede oficiar los ritos que ella habilita.
  Future<bool> hasUnlocked(String conspiracyCode) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return false;
    final data = await supabase
        .from('conspiracy_unlocks')
        .select('conspiracy_id, conspirations!inner(code)')
        .eq('user_id', uid)
        .eq('conspirations.code', conspiracyCode)
        .maybeSingle();
    return data != null;
  }

  Future<EffectiveMemberships?> getProfileEmblems(String profileId) async {
    final data = await supabase.rpc(
      'get_profile_conspiracy_emblems',
      params: {'p_profile_id': profileId},
    );
    final map = Map<String, dynamic>.from(data as Map);
    if (map['ok'] != true) return null;
    return EffectiveMemberships.fromMap(map);
  }

  Future<ConspiracyActionResult> choosePrimary(String conspiracyId) async {
    final data = await supabase.rpc('choose_conspiracy_manually', params: {
      'target_conspiracy_id': conspiracyId,
    });
    return ConspiracyActionResult.fromMap(Map<String, dynamic>.from(data));
  }

  Future<ConspiracyActionResult> setSecondaries(List<String> ids) async {
    final data = await supabase.rpc('set_secondary_affiliations', params: {
      'targets': ids,
    });
    return ConspiracyActionResult.fromMap(Map<String, dynamic>.from(data));
  }

  Future<MoltEligibility> getMoltEligibility() async {
    final data = await supabase.rpc('get_molt_eligibility');
    return MoltEligibility.fromMap(Map<String, dynamic>.from(data));
  }

  Future<List<ConspiracyProgress>> refreshProgress() async {
    final data = await supabase.rpc('refresh_my_conspiracy_progress');
    final map = Map<String, dynamic>.from(data as Map);
    if (map['ok'] != true) return const [];
    return ((map['progress'] as List?) ?? const [])
        .map((entry) => ConspiracyProgress.fromMap(
              Map<String, dynamic>.from(entry as Map),
            ))
        .toList();
  }

  Future<List<ConspiracyProgress>> recordPresence() async {
    final data = await supabase.rpc('record_conspiracy_presence');
    final map = Map<String, dynamic>.from(data as Map);
    if (map['ok'] != true) return const [];
    return ((map['progress'] as List?) ?? const [])
        .map((entry) => ConspiracyProgress.fromMap(
              Map<String, dynamic>.from(entry as Map),
            ))
        .toList();
  }

  Future<bool> recordDirectDiscovery(String profileId) async {
    final data = await supabase.rpc('record_conspiracy_signal', params: {
      'p_signal_key': 'direct_profile_discovery',
      'p_target_profile_id': profileId,
    });
    final map = Map<String, dynamic>.from(data as Map);
    return map['ok'] == true;
  }

  Future<ConspiracyActionResult> inviteToBloodPact({
    required String inviteeId,
    String? evidenceWorkId,
    String note = '',
  }) async {
    final data = await supabase.rpc('create_blood_pact_invitation', params: {
      'p_invitee_id': inviteeId,
      'p_evidence_work_id': evidenceWorkId,
      'p_note': note,
    });
    return ConspiracyActionResult.fromMap(Map<String, dynamic>.from(data));
  }

  Future<ConspiracyActionResult> respondToBloodPactInvitation({
    required String invitationId,
    required bool accept,
  }) async {
    final data = await supabase.rpc('respond_blood_pact_invitation', params: {
      'p_invitation_id': invitationId,
      'p_accept': accept,
    });
    return ConspiracyActionResult.fromMap(Map<String, dynamic>.from(data));
  }

  Future<ConspiracyActionResult> endorseFirstCrow({
    required String candidateId,
    required String evidenceWorkId,
    required String note,
  }) async {
    final data = await supabase.rpc('endorse_first_crow', params: {
      'p_candidate_id': candidateId,
      'p_evidence_work_id': evidenceWorkId,
      'p_note': note,
    });
    return ConspiracyActionResult.fromMap(Map<String, dynamic>.from(data));
  }

  Future<ConspiracyActionResult> grantCuratedHouse({
    required String userId,
    required String conspiracyId,
    required String reason,
  }) async {
    final data = await supabase.rpc('grant_curated_conspiracy', params: {
      'p_target_user_id': userId,
      'p_target_conspiracy_id': conspiracyId,
      'p_reason': reason,
    });
    return ConspiracyActionResult.fromMap(Map<String, dynamic>.from(data));
  }

  Future<ConspiracyActionResult> performMolt(
    String conspiracyId, {
    bool keepPreviousAsSecondary = false,
  }) async {
    final data = await supabase.rpc('perform_molt', params: {
      'target_conspiracy_id': conspiracyId,
      'keep_previous_as_secondary': keepPreviousAsSecondary,
    });
    return ConspiracyActionResult.fromMap(Map<String, dynamic>.from(data));
  }

  /// Reason codes → voz narrativa de Corvus (guía §15.4).
  static String messageFor(String? code) {
    switch (code) {
      case 'MOLT_ALREADY_USED':
        return 'La temporada ya guarda una pluma caída con tu nombre.';
      case 'MOLT_SEASON_CLOSED':
        return 'La Muda duerme hasta el próximo corte.';
      case 'MOLT_TARGET_INVALID':
        return 'Esa casa no puede recibirte en esta Muda.';
      case 'SECONDARY_LIMIT':
        return 'Solo dos casas pueden acompañar a tu conspiración primaria.';
      case 'SECONDARY_EQUALS_PRIMARY':
        return 'Tu casa primaria ya camina contigo.';
      case 'PRIMARY_ALREADY_SET':
        return 'Tu conspiración primaria ya fue sellada. La Muda es el único camino.';
      case 'NO_PRIMARY':
        return 'Primero debes pertenecer a una casa.';
      case 'HOUSE_NOT_ELIGIBLE':
        return 'Esta casa no se elige: se conquista o se otorga.';
      case 'RECOMMENDATION_EXPIRED':
        return 'El susurro se extinguió; el cielo volverá a hablar.';
      case 'NOT_AUTHENTICATED':
        return 'El archivo no te reconoce. Inicia sesión.';
      case 'ANNUAL_INVITE_USED':
        return 'Tu invitación anual del Pacto ya fue pronunciada.';
      case 'INVITATION_PENDING':
        return 'Esa invitación sigue esperando una respuesta.';
      case 'INVITATION_EXPIRED':
        return 'La invitación perdió su pulso antes de ser aceptada.';
      case 'CANDIDATE_NOT_ELIGIBLE':
      case 'CANDIDATE_NOT_CONTINUOUS':
        return 'La trayectoria aún no reúne toda la evidencia requerida.';
      case 'SEAT_LIMIT_REACHED':
        return 'No quedan lugares disponibles en este registro.';
      case 'NOT_AUTHORIZED':
        return 'Este acto requiere autorización curatorial.';
      default:
        return 'El ritual no pudo completarse.';
    }
  }
}
