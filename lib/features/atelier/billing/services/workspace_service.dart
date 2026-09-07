import '../../../../core/rpc_error.dart';
import '../../../../core/supabase_config.dart';
import '../domain/billing_models.dart';

class WorkspaceMember {
  final String id;
  final String profileId;
  final String roleKey;
  final String status;
  final String displayName;
  final String username;
  final String? avatarUrl;
  final DateTime joinedAt;

  const WorkspaceMember({
    required this.id,
    required this.profileId,
    required this.roleKey,
    required this.status,
    required this.displayName,
    required this.username,
    this.avatarUrl,
    required this.joinedAt,
  });

  factory WorkspaceMember.fromMap(Map<String, dynamic> map) {
    final profile = Map<String, dynamic>.from(
      map['profiles'] as Map? ?? const {},
    );

    return WorkspaceMember(
      id: map['id'] as String,
      profileId: map['profile_id'] as String,
      roleKey: map['role_key'] as String? ?? 'viewer',
      status: map['status'] as String? ?? 'active',
      displayName: profile['display_name'] as String? ?? '',
      username: profile['username'] as String? ?? '',
      avatarUrl: profile['avatar_url'] as String?,
      joinedAt:
          DateTime.tryParse(map['joined_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class WorkspaceRole {
  final String key;
  final String name;
  final String description;
  final List<String> capabilities;
  final bool isSystem;
  final int rank;

  const WorkspaceRole({
    required this.key,
    required this.name,
    required this.description,
    required this.capabilities,
    required this.isSystem,
    required this.rank,
  });

  factory WorkspaceRole.fromMap(Map<String, dynamic> map) {
    return WorkspaceRole(
      key: map['key'] as String,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      capabilities: List<String>.from(map['capabilities'] as List? ?? const []),
      isSystem: map['is_system'] as bool? ?? false,
      rank: (map['rank'] as num?)?.toInt() ?? 0,
    );
  }
}

class WorkspaceInvitation {
  final String id;
  final String? workspaceId;
  final String? projectId;
  final String roleKey;
  final String status;
  final String message;
  final DateTime expiresAt;
  final String workspaceName;

  const WorkspaceInvitation({
    required this.id,
    this.workspaceId,
    this.projectId,
    required this.roleKey,
    required this.status,
    required this.message,
    required this.expiresAt,
    required this.workspaceName,
  });

  bool get isPending => status == 'pending' && expiresAt.isAfter(DateTime.now());

  factory WorkspaceInvitation.fromMap(Map<String, dynamic> map) {
    final workspace = Map<String, dynamic>.from(
      map['atelier_workspaces'] as Map? ?? const {},
    );

    return WorkspaceInvitation(
      id: map['id'] as String,
      workspaceId: map['workspace_id'] as String?,
      projectId: map['project_id'] as String?,
      roleKey: map['role_key'] as String? ?? 'viewer',
      status: map['status'] as String? ?? 'pending',
      message: map['message'] as String? ?? '',
      expiresAt: DateTime.tryParse(map['expires_at'] as String? ?? '') ??
          DateTime.now(),
      workspaceName: workspace['name'] as String? ?? 'Un espacio de trabajo',
    );
  }
}

/// Espacios de trabajo, gente y permisos.
///
/// Todo lo que cambia quién puede qué pasa por RPC: el servidor comprueba la
/// capacidad, respeta el tope del plan y deja rastro en la auditoría. Desde
/// aquí solo se piden cosas y se leen respuestas.
class WorkspaceService {
  Future<String> createWorkspace(String name, {String? slug}) async {
    final raw = await supabase.rpc(
      'atelier_create_workspace',
      params: {'p_name': name, 'p_slug': slug},
    );
    return unwrapRpc(raw)['workspace_id'] as String;
  }

  Future<Entitlements> workspaceEntitlements(String workspaceId) async {
    final raw = await supabase.rpc(
      'get_workspace_entitlements',
      params: {'p_workspace_id': workspaceId},
    );
    return Entitlements.fromMap(unwrapRpc(raw));
  }

  Future<List<WorkspaceMember>> members(String workspaceId) async {
    final rows = await supabase
        .from('atelier_workspace_members')
        .select('*, profiles!inner(username, display_name, avatar_url)')
        .eq('workspace_id', workspaceId)
        .eq('status', 'active')
        .order('joined_at');

    return (rows as List)
        .map((row) =>
            WorkspaceMember.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<WorkspaceRole>> roles(String workspaceId) async {
    final rows = await supabase
        .from('atelier_workspace_roles')
        .select()
        .or('workspace_id.is.null,workspace_id.eq.$workspaceId')
        .order('rank', ascending: false);

    return (rows as List)
        .map((row) =>
            WorkspaceRole.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<WorkspaceInvitation>> pendingInvitations() async {
    final rows = await supabase
        .from('atelier_invitations')
        .select('*, atelier_workspaces(name)')
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) =>
            WorkspaceInvitation.fromMap(Map<String, dynamic>.from(row as Map)))
        .where((invitation) => invitation.isPending)
        .toList();
  }

  Future<String> invite({
    required String workspaceId,
    String? profileId,
    String? email,
    String roleKey = 'writer',
    String message = '',
  }) async {
    final raw = await supabase.rpc('atelier_invite_to_workspace', params: {
      'p_workspace_id': workspaceId,
      'p_profile_id': profileId,
      'p_email': email,
      'p_role_key': roleKey,
      'p_message': message,
    });
    return unwrapRpc(raw)['invitation_id'] as String;
  }

  Future<bool> respondInvitation(String invitationId, {required bool accept}) async {
    final raw = await supabase.rpc('atelier_respond_invitation', params: {
      'p_invitation_id': invitationId,
      'p_accept': accept,
    });
    return unwrapRpc(raw)['accepted'] as bool? ?? false;
  }

  Future<void> setMemberRole({
    required String workspaceId,
    required String profileId,
    required String roleKey,
  }) async {
    final raw = await supabase.rpc('atelier_set_member_role', params: {
      'p_workspace_id': workspaceId,
      'p_profile_id': profileId,
      'p_role_key': roleKey,
    });
    unwrapRpc(raw);
  }

  /// Retirar a alguien no borra lo que escribió: sus capítulos, fichas y
  /// comentarios siguen siendo del proyecto. Solo pierde el acceso.
  Future<void> removeMember({
    required String workspaceId,
    required String profileId,
  }) async {
    final raw = await supabase.rpc('atelier_remove_member', params: {
      'p_workspace_id': workspaceId,
      'p_profile_id': profileId,
    });
    unwrapRpc(raw);
  }

  Future<void> upsertRole({
    required String workspaceId,
    required String key,
    required String name,
    required List<String> capabilities,
    String description = '',
  }) async {
    final raw = await supabase.rpc('atelier_upsert_role', params: {
      'p_workspace_id': workspaceId,
      'p_key': key,
      'p_name': name,
      'p_capabilities': capabilities,
      'p_description': description,
    });
    unwrapRpc(raw);
  }

  // ─── Colaboración sobre un proyecto suelto ────────────────────────────────

  Future<void> shareProject({
    required String projectId,
    required String profileId,
    String roleKey = 'reviewer',
  }) async {
    final raw = await supabase.rpc('atelier_share_project', params: {
      'p_project_id': projectId,
      'p_profile_id': profileId,
      'p_role_key': roleKey,
    });
    unwrapRpc(raw);
  }

  Future<void> unshareProject({
    required String projectId,
    required String profileId,
  }) async {
    final raw = await supabase.rpc('atelier_unshare_project', params: {
      'p_project_id': projectId,
      'p_profile_id': profileId,
    });
    unwrapRpc(raw);
  }

  Future<List<WorkspaceMember>> collaborators(String projectId) async {
    final rows = await supabase
        .from('atelier_project_collaborators')
        .select('*, profiles!inner(username, display_name, avatar_url)')
        .eq('project_id', projectId)
        .eq('status', 'active')
        .order('created_at');

    return (rows as List).map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      // La tabla de colaboradores no tiene joined_at; se usa el alta.
      map['joined_at'] = map['created_at'];
      return WorkspaceMember.fromMap(map);
    }).toList();
  }
}
