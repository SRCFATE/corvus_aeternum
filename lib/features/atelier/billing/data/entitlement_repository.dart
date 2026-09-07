import '../../../../core/rpc_error.dart';
import '../../../../core/supabase_config.dart';
import '../domain/billing_models.dart';

/// Lectura de derechos, banderas, uso y versiones.
///
/// Todo pasa por RPC: las tablas que sostienen esto no conceden lectura
/// directa al cliente, precisamente para que exista un solo camino y esté
/// auditado.
class EntitlementRepository {
  Future<Entitlements> fetchEntitlements() async {
    final raw = await supabase.rpc('get_my_entitlements');
    final map = unwrapRpc(raw);
    return Entitlements.fromMap(map);
  }

  Future<Entitlements> fetchWorkspaceEntitlements(String workspaceId) async {
    final raw = await supabase.rpc(
      'get_workspace_entitlements',
      params: {'p_workspace_id': workspaceId},
    );
    final map = unwrapRpc(raw);
    return Entitlements.fromMap(map);
  }

  Future<Map<String, bool>> fetchFeatureFlags() async {
    final raw = await supabase.rpc('get_feature_flags');
    if (raw is! Map) return const {};
    return raw.map((key, value) => MapEntry('$key', value == true));
  }

  Future<UsageSnapshot> fetchUsage({String? workspaceId}) async {
    final raw = await supabase.rpc(
      'get_atelier_usage',
      params: {'p_workspace_id': workspaceId},
    );
    final map = unwrapRpc(raw);
    return UsageSnapshot.fromMap(map);
  }

  /// El historial completo, con la marca de cuáles se pueden restaurar. Nunca
  /// se ocultan versiones: fuera de la ventana del plan siguen visibles.
  Future<({List<AtelierVersionEntry> versions, bool advanced, int window})>
      fetchVersions(String projectId) async {
    final raw = await supabase.rpc(
      'get_atelier_versions',
      params: {'p_project_id': projectId},
    );
    final map = unwrapRpc(raw);

    return (
      versions: (map['versions'] as List? ?? const [])
          .map((row) =>
              AtelierVersionEntry.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList(),
      advanced: map['advanced'] as bool? ?? false,
      window: (map['window'] as num?)?.toInt() ?? 0,
    );
  }

  Future<String> createSnapshot({
    required String projectId,
    String? label,
    String description = '',
  }) async {
    final raw = await supabase.rpc(
      'atelier_create_snapshot',
      params: {
        'p_project_id': projectId,
        'p_label': label,
        'p_description': description,
      },
    );
    return unwrapRpc(raw)['version_id'] as String;
  }

  Future<int> restoreVersion(String versionId) async {
    final raw = await supabase.rpc(
      'atelier_restore_version',
      params: {'p_version_id': versionId},
    );
    return (unwrapRpc(raw)['nodes_restored'] as num?)?.toInt() ?? 0;
  }

  /// Registra un evento comercial. Nunca lleva contenido creativo: el servidor
  /// además descarta cualquier propiedad fuera de su lista blanca.
  Future<void> recordEvent(
    String event, {
    Map<String, String> properties = const {},
  }) async {
    await supabase.rpc(
      'record_billing_event',
      params: {'p_event': event, 'p_properties': properties},
    );
  }
}
