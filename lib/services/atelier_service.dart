import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:collection/collection.dart';

import '../core/supabase_config.dart';
import '../core/rpc_error.dart';
import '../models/aeternum_ficha.dart';
import '../models/atelier_models.dart';
import '../features/atelier/atelier_publication_text.dart';

class AtelierSchemaException implements Exception {
  final String message;
  const AtelierSchemaException(this.message);

  @override
  String toString() => message;
}

class AtelierConflictException implements Exception {
  final AtelierNode? remote;
  const AtelierConflictException({this.remote});
  @override
  String toString() =>
      'Este elemento cambió en otra sesión. Conserva tu borrador y vuelve a abrir el proyecto para comparar los cambios.';
}

class AtelierPublicationException implements Exception {
  final String message;
  const AtelierPublicationException(this.message);
  @override
  String toString() => message;
}

class AtelierService {
  final SupabaseClient? _injectedClient;
  SupabaseClient get client => _injectedClient ?? supabase;

  AtelierService({SupabaseClient? client}) : _injectedClient = client;

  Future<String> importProject(
      Map<String, dynamic> payload, String requestId) async {
    return await client.rpc('atelier_import_project', params: {
      'p_payload': payload,
      'p_request_id': requestId,
    }) as String;
  }

  Future<AtelierWorkspace> loadWorkspace(
    String profileId, {
    String? projectId,
  }) async {
    try {
      final projects = await getProjects(profileId);

      // Un enlace a un proyecto compartido se consulta bajo las mismas RLS.
      if (projectId != null &&
          !projects.any((project) => project.id == projectId)) {
        final shared = await client
            .from('atelier_projects')
            .select()
            .eq('id', projectId)
            .maybeSingle();
        if (shared != null) projects.add(AtelierProject.fromMap(shared));
      }

      final available = projects
          .where((project) => project.metadata['deleted_at'] == null)
          .toList();
      if (available.isEmpty) {
        return AtelierWorkspace(
            projects: projects,
            activeProject: null,
            nodes: const [],
            relations: const [],
            versions: const []);
      }

      final activeProject = projectId == null
          ? available.first
          : available.firstWhere(
              (project) => project.id == projectId,
              orElse: () => available.first,
            );

      final results = await Future.wait([
        client
            .from('atelier_nodes')
            .select()
            .eq('project_id', activeProject.id)
            .order('position', ascending: true)
            .order('updated_at', ascending: false),
        client
            .from('atelier_relations')
            .select()
            .eq('project_id', activeProject.id)
            .order('created_at', ascending: false),
        client
            .from('atelier_versions')
            .select('*,profiles!atelier_versions_profile_id_fkey(display_name)')
            .eq('project_id', activeProject.id)
            .order('created_at', ascending: false),
      ]);

      return AtelierWorkspace(
        projects: projects,
        activeProject: activeProject,
        nodes: (results[0] as List)
            .map((row) => AtelierNode.fromMap(row as Map<String, dynamic>))
            .toList(),
        relations: (results[1] as List)
            .map((row) => AtelierRelation.fromMap(row as Map<String, dynamic>))
            .toList(),
        versions: (results[2] as List)
            .map((row) => AtelierVersion.fromMap(row as Map<String, dynamic>))
            .toList(),
      );
    } catch (error) {
      if (_looksLikeMissingSchema(error)) {
        throw const AtelierSchemaException(
          'Faltan las tablas de Atelier. Aplica docs/atelier_schema.sql en Supabase.',
        );
      }
      rethrow;
    }
  }

  Future<List<AtelierProject>> getProjects(String profileId) async {
    final projectRows = await client
        .from('atelier_projects')
        .select()
        .eq('profile_id', profileId)
        .order('updated_at', ascending: false);
    return (projectRows as List)
        .map((row) => AtelierProject.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<AtelierPlannerEntry>> getPlannerEntries(
    String profileId,
  ) async {
    final rows = await client
        .from('atelier_nodes')
        .select(
          '*, atelier_projects!atelier_nodes_project_id_fkey(title, type)',
        )
        .eq('profile_id', profileId)
        .inFilter('kind', const ['task', 'journal']).order('created_at',
            ascending: false);
    return (rows as List)
        .map(
          (row) => AtelierPlannerEntry.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .where((entry) => entry.node.metadata['deleted_at'] == null)
        .toList();
  }

  Future<AtelierProject> createProject({
    required String profileId,
    required String title,
    String type = 'Novela',
    String status = 'idea',
    String genre = '',
    String universe = '',
    String language = 'es',
    String visibility = 'private',
    int weeklyWordGoal = 0,
    bool publicProgressEnabled = false,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      final row = await client
          .from('atelier_projects')
          .insert({
            'profile_id': profileId,
            'title': title.trim().isEmpty ? 'Obra sin titulo' : title.trim(),
            'type': type.trim().isEmpty ? 'Obra' : type.trim(),
            'status': status,
            'genre': genre.trim(),
            'universe': universe.trim(),
            'language': language.trim().isEmpty ? 'es' : language.trim(),
            'visibility': visibility,
            'weekly_word_goal': weeklyWordGoal,
            'public_progress_enabled': publicProgressEnabled,
            'metadata': metadata,
          })
          .select()
          .single();
      return AtelierProject.fromMap(row);
    } catch (error) {
      if (_looksLikeMissingSchema(error)) {
        throw const AtelierSchemaException(
          'Faltan las tablas de Atelier. Aplica docs/atelier_schema.sql en Supabase.',
        );
      }
      rethrow;
    }
  }

  Future<AtelierProject> updateProject(AtelierProject project) async {
    final row = await client
        .from('atelier_projects')
        .update({
          ...project.toUpdateMap(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', project.id)
        .eq('profile_id', project.profileId)
        .select()
        .single();
    return AtelierProject.fromMap(row);
  }

  Future<void> deleteProject(AtelierProject project) async {
    await client
        .from('atelier_projects')
        .delete()
        .eq('id', project.id)
        .eq('profile_id', project.profileId);
  }

  Future<AtelierNode> createNode({
    String? nodeId,
    required String profileId,
    required String projectId,
    required String kind,
    required String title,
    String body = '',
    String status = 'draft',
    String canonStatus = 'canon',
    String visibility = 'private',
    List<String> tags = const [],
    Map<String, dynamic> metadata = const {},
    int position = 0,
  }) async {
    final payload = {
      if (nodeId != null) 'id': nodeId,
      'profile_id': profileId,
      'project_id': projectId,
      'kind': kind,
      'title': title.trim().isEmpty ? 'Sin titulo' : title.trim(),
      'body': body,
      'status': status,
      'canon_status': canonStatus,
      'visibility': visibility,
      'tags': tags,
      'metadata': metadata,
      'position': position,
    };
    try {
      final row =
          await client.from('atelier_nodes').insert(payload).select().single();
      return AtelierNode.fromMap(row);
    } on PostgrestException catch (error) {
      if (error.code != '23505' || nodeId == null) rethrow;
      final row = await client
          .from('atelier_nodes')
          .select()
          .eq('id', nodeId)
          .eq('project_id', projectId)
          .eq('profile_id', profileId)
          .maybeSingle();
      if (row == null) rethrow;
      final existing = AtelierNode.fromMap(row);
      // A duplicate acknowledgement is safe only if the first write is intact.
      // Position may change independently when chapters are reordered.
      final expected = Map<String, dynamic>.of(payload)..remove('position');
      final actual = {for (final key in expected.keys) key: row[key]};
      if (!const DeepCollectionEquality().equals(expected, actual)) {
        throw AtelierConflictException(remote: existing);
      }
      return existing;
    }
  }

  Future<AtelierNode> updateNode(AtelierNode node) async {
    final row = await client
        .from('atelier_nodes')
        .update({
          ...node.toUpdateMap(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', node.id)
        .eq('profile_id', node.profileId)
        .eq('updated_at', node.updatedAt.toUtc().toIso8601String())
        .select()
        .maybeSingle();
    if (row == null) throw const AtelierConflictException();
    return AtelierNode.fromMap(row);
  }

  Future<void> deleteNode(AtelierNode node) async {
    await client
        .from('atelier_nodes')
        .delete()
        .eq('id', node.id)
        .eq('profile_id', node.profileId);
  }

  Future<AtelierRelation> createRelation({
    required String profileId,
    required String projectId,
    required String sourceNodeId,
    required String relationType,
    required String targetNodeId,
    String description = '',
    String canonStatus = 'canon',
  }) async {
    final row = await client
        .from('atelier_relations')
        .insert({
          'profile_id': profileId,
          'project_id': projectId,
          'source_node_id': sourceNodeId,
          'relation_type':
              relationType.trim().isEmpty ? 'menciona' : relationType.trim(),
          'target_node_id': targetNodeId,
          'description': description.trim(),
          'canon_status': canonStatus,
        })
        .select()
        .single();
    return AtelierRelation.fromMap(row);
  }

  Future<void> deleteRelation(AtelierRelation relation) async {
    await client
        .from('atelier_relations')
        .delete()
        .eq('id', relation.id)
        .eq('profile_id', relation.profileId);
  }

  Future<AtelierVersion> createVersion({
    required String profileId,
    required String projectId,
    required String label,
    required String description,
    required Map<String, dynamic> metadata,
  }) async {
    final result =
        unwrapRpc(await client.rpc('atelier_create_snapshot', params: {
      'p_project_id': projectId,
      'p_label': label,
      'p_description': description,
      'p_kind': metadata['automatic'] == true ? 'auto' : 'manual',
    }));
    final row = await client
        .from('atelier_versions')
        .select('*,profiles!atelier_versions_profile_id_fkey(display_name)')
        .eq('id', result['version_id'] as String)
        .single();
    return AtelierVersion.fromMap(row);
  }

  Future<void> restoreVersion(AtelierVersion version) async {
    unwrapRpc(await client
        .rpc('atelier_restore_version', params: {'p_version_id': version.id}));
  }

  // Nodos del taller ordenados que entran en la publicación (solo con contenido).
  List<AtelierNode> _publicationNodes(
    AtelierProject project,
    List<AtelierNode> nodes,
  ) {
    final branch = (project.metadata['atelier_branch'] as String?) ?? 'writing';
    final studioKinds = _studioKindsForBranch(branch);
    return nodes
        .where((node) =>
            studioKinds.contains(node.kind) &&
            node.metadata['deleted_at'] == null &&
            node.body.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  String _composeTextBody(List<AtelierNode> publicationNodes) {
    return composeAtelierPublicationText(publicationNodes);
  }

  Future<({String workId, int chapters, bool isPublished})?> syncPublishedWork({
    required AtelierProject project,
    required List<AtelierNode> nodes,
    required List<AtelierRelation> relations,
    required List<AtelierVersion> versions,
  }) async {
    final workId = (project.metadata['publication_work_id'] as String?)?.trim();
    if (workId == null || workId.isEmpty) return null;
    return _commitPublication(
        project: project,
        nodes: nodes,
        relations: relations,
        versions: versions,
        preparing: false);
  }

  Future<String> preparePublication({
    required AtelierProject project,
    required List<AtelierNode> nodes,
    required List<AtelierRelation> relations,
    required List<AtelierVersion> versions,
  }) async =>
      (await _commitPublication(
              project: project,
              nodes: nodes,
              relations: relations,
              versions: versions,
              preparing: true))
          .workId;

  Future<({String workId, int chapters, bool isPublished})> _commitPublication({
    required AtelierProject project,
    required List<AtelierNode> nodes,
    required List<AtelierRelation> relations,
    required List<AtelierVersion> versions,
    required bool preparing,
  }) async {
    final currentNodes =
        nodes.where((node) => node.metadata['deleted_at'] == null).toList();
    final publicationNodes = _publicationNodes(project, currentNodes);
    final branch = project.metadata['atelier_branch'] as String? ?? 'writing';
    final ficha = AeternumFicha.fromAtelier(
        project: project,
        nodes: currentNodes,
        relations: relations,
        versions: versions);
    final synopsis = ((project.metadata['description'] as String?) ??
            (project.metadata['synopsis_short'] as String?))
        ?.trim();
    try {
      final result = await client.rpc('atelier_commit_publication', params: {
        'p_project_id': project.id,
        'p_project_updated_at': project.updatedAt.toUtc().toIso8601String(),
        'p_expected_nodes': currentNodes
            .map((node) => {
                  'id': node.id,
                  'updated_at': node.updatedAt.toUtc().toIso8601String(),
                })
            .toList(),
        'p_publication_snapshot': publicationNodes
            .map((node) => {
                  'id': node.id,
                  'title': node.title,
                  'body': node.body,
                })
            .toList(),
        'p_payload': {
          'description': synopsis?.isNotEmpty == true
              ? synopsis
              : 'Preparado desde Atelier.',
          'discipline': _publicationDiscipline(branch),
          'work_type': _publicationWorkType(branch),
          'tags': _projectTags(project, publicationNodes),
          'text_body': _composeTextBody(publicationNodes),
          'aeternum_ficha': ficha.toMap(),
        },
        'p_preparing': preparing,
      });
      final data = Map<String, dynamic>.from(result as Map);
      return (
        workId: data['work_id'] as String,
        chapters: data['chapters'] as int,
        isPublished: data['is_published'] as bool
      );
    } on PostgrestException catch (error) {
      if (error.message.contains('EDITION_CHANGED')) {
        throw const AtelierPublicationException(
            'El proyecto cambió desde la revisión. Vuelve a abrir la comparación antes de enviar la edición.');
      }
      if (error.code == '42501') {
        throw const AtelierPublicationException(
            'Solo la persona propietaria puede enviar esta edición a la obra vinculada.');
      }
      rethrow;
    }
  }

  String exportJson(AtelierWorkspace workspace) {
    final project = workspace.activeProject;
    if (project == null) return '{}';
    return const JsonEncoder.withIndent('  ').convert(
      project.toExportMap(
        nodes: workspace.nodes,
        relations: workspace.relations,
        versions: workspace.versions,
      ),
    );
  }

  List<String> _projectTags(AtelierProject project, List<AtelierNode> nodes) {
    final tags = <String>{};
    if (project.genre.trim().isNotEmpty) tags.add(project.genre.trim());
    if (project.universe.trim().isNotEmpty) tags.add(project.universe.trim());
    for (final node in nodes) {
      tags.addAll(node.tags);
    }
    return tags.take(12).toList();
  }

  List<String> _studioKindsForBranch(String branch) {
    return switch (branch) {
      'visual' => ['sketch', 'moodboard', 'palette', 'technical_sheet'],
      'music' => ['track', 'lyric', 'demo', 'mix'],
      'video' => ['script', 'scene', 'storyboard', 'shot'],
      'comic' => ['chapter', 'page', 'panel', 'dialogue'],
      'photo' => ['photo_session', 'photo', 'lighting', 'selection'],
      'fashion' => ['garment', 'collection', 'material', 'sample'],
      'game' => ['gdd', 'mechanic', 'level', 'mission'],
      'stage' => ['act', 'scene', 'rehearsal', 'prop'],
      'space' => ['zone', 'plan', 'material', 'furniture'],
      'world' => ['universe', 'place', 'faction', 'event'],
      _ => ['chapter', 'scene', 'fragment'],
    };
  }

  String _publicationDiscipline(String branch) {
    return switch (branch) {
      'visual' => 'Arte visual',
      'music' => 'Musica',
      'video' => 'Cine',
      'comic' => 'Comic',
      'photo' => 'Fotografia',
      'fashion' => 'Moda',
      'game' => 'Videojuegos',
      'stage' => 'Performance',
      'space' => 'Arquitectura',
      'world' => 'WorldBuilding',
      _ => 'Literatura',
    };
  }

  String _publicationWorkType(String branch) {
    return switch (branch) {
      'visual' || 'photo' || 'fashion' || 'space' => 'image',
      'music' => 'audio',
      'video' => 'video',
      _ => 'text',
    };
  }

  bool _looksLikeMissingSchema(Object error) {
    if (error is PostgrestException) {
      final code = error.code ?? '';
      final message = error.message.toLowerCase();
      return code == 'PGRST205' ||
          message.contains('schema cache') ||
          message.contains('does not exist') ||
          message.contains('could not find the table');
    }
    final message = error.toString().toLowerCase();
    return message.contains('pgrst205') ||
        message.contains('schema cache') ||
        message.contains('does not exist') ||
        message.contains('could not find the table');
  }
}
