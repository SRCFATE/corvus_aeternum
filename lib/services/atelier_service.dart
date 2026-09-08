import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../models/aeternum_ficha.dart';
import '../models/atelier_models.dart';
import '../features/atelier/atelier_publication_text.dart';
import 'work_service.dart';

class AtelierSchemaException implements Exception {
  final String message;
  const AtelierSchemaException(this.message);

  @override
  String toString() => message;
}

class AtelierService {
  final WorkService _workService;

  AtelierService({WorkService? workService})
      : _workService = workService ?? WorkService();

  Future<AtelierWorkspace> loadWorkspace(
    String profileId, {
    String? projectId,
  }) async {
    try {
      final projects = await getProjects(profileId);

      if (projects.isEmpty) return const AtelierWorkspace.empty();

      final activeProject = projectId == null
          ? projects.first
          : projects.firstWhere(
              (project) => project.id == projectId,
              orElse: () => projects.first,
            );

      final results = await Future.wait([
        supabase
            .from('atelier_nodes')
            .select()
            .eq('project_id', activeProject.id)
            .order('position', ascending: true)
            .order('updated_at', ascending: false),
        supabase
            .from('atelier_relations')
            .select()
            .eq('project_id', activeProject.id)
            .order('created_at', ascending: false),
        supabase
            .from('atelier_versions')
            .select()
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
    final projectRows = await supabase
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
    final rows = await supabase
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
      final row = await supabase
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
    final row = await supabase
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
    await supabase
        .from('atelier_projects')
        .delete()
        .eq('id', project.id)
        .eq('profile_id', project.profileId);
  }

  Future<AtelierNode> createNode({
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
    final row = await supabase
        .from('atelier_nodes')
        .insert({
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
        })
        .select()
        .single();
    return AtelierNode.fromMap(row);
  }

  Future<AtelierNode> updateNode(AtelierNode node) async {
    final row = await supabase
        .from('atelier_nodes')
        .update({
          ...node.toUpdateMap(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', node.id)
        .eq('profile_id', node.profileId)
        .select()
        .single();
    return AtelierNode.fromMap(row);
  }

  Future<void> deleteNode(AtelierNode node) async {
    await supabase
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
    final row = await supabase
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
    await supabase
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
    final row = await supabase
        .from('atelier_versions')
        .insert({
          'profile_id': profileId,
          'project_id': projectId,
          'label': label.trim().isEmpty ? 'Version' : label.trim(),
          'description': description.trim(),
          'metadata': metadata,
        })
        .select()
        .single();
    return AtelierVersion.fromMap(row);
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
            studioKinds.contains(node.kind) && node.body.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  String _composeTextBody(List<AtelierNode> publicationNodes) {
    return composeAtelierPublicationText(publicationNodes);
  }

  // Sincroniza el contenido del taller con la obra ya vinculada, sin tocar su
  // estado ni su sello. Es el camino de la publicación por entregas.
  Future<({String workId, int chapters, bool isPublished})?> syncPublishedWork({
    required AtelierProject project,
    required List<AtelierNode> nodes,
    required List<AtelierRelation> relations,
    required List<AtelierVersion> versions,
  }) async {
    final workId = (project.metadata['publication_work_id'] as String?)?.trim();
    if (workId == null || workId.isEmpty) return null;

    final publicationNodes = _publicationNodes(project, nodes);
    final textBody = _composeTextBody(publicationNodes);
    final ficha = AeternumFicha.fromAtelier(
      project: project,
      nodes: nodes,
      relations: relations,
      versions: versions,
    );

    final bool isPublished;
    try {
      final work = await _workService.getWorkById(workId);
      isPublished = work.status == 'published';
    } catch (_) {
      return null; // La obra vinculada ya no existe.
    }

    await _workService.updateWork(workId, {
      'text_body': textBody,
      'aeternum_ficha': ficha.toMap(),
      'atelier_project_id': project.id,
      if (project.universe.trim().isNotEmpty) 'universe': project.universe,
      'aeternum_status': project.status,
    });
    return (
      workId: workId,
      chapters: publicationNodes.length,
      isPublished: isPublished,
    );
  }

  Future<String> preparePublication({
    required AtelierProject project,
    required List<AtelierNode> nodes,
    required List<AtelierRelation> relations,
    required List<AtelierVersion> versions,
  }) async {
    final branch = (project.metadata['atelier_branch'] as String?) ?? 'writing';
    final publicationNodes = _publicationNodes(project, nodes);
    final textBody = _composeTextBody(publicationNodes);
    final ficha = AeternumFicha.fromAtelier(
      project: project,
      nodes: nodes,
      relations: relations,
      versions: versions,
    );

    final synopsis = ((project.metadata['description'] as String?) ??
            (project.metadata['synopsis_short'] as String?))
        ?.trim();
    final payload = {
      'profile_id': project.profileId,
      'title': project.title,
      'description':
          synopsis?.isNotEmpty == true ? synopsis : 'Preparado desde Atelier.',
      'discipline': _publicationDiscipline(branch),
      'subdiscipline': project.type,
      'medium': project.genre,
      'work_type': _publicationWorkType(branch),
      'status': 'draft',
      'is_public': false,
      'is_complete': false,
      'is_for_sale': false,
      'is_mature': false,
      'year': DateTime.now().year,
      'tags': _projectTags(project, nodes),
      'text_body': textBody,
      'language': project.language,
      'aeternum_ficha': ficha.toMap(),
      'atelier_project_id': project.id,
      if (project.universe.trim().isNotEmpty) 'universe': project.universe,
      'aeternum_status': project.status,
    };

    final existingWorkId = project.metadata['publication_work_id'] as String?;
    final workId = existingWorkId != null && existingWorkId.trim().isNotEmpty
        ? await _updatePublicationDraft(existingWorkId.trim(), payload)
        : (await _workService.createWork({
            ...payload,
            'media_urls': <String>[],
          }))
            .id;

    final metadata = {
      ...project.metadata,
      'publication_work_id': workId,
      'publication_prepared_at': DateTime.now().toUtc().toIso8601String(),
    };
    await updateProject(project.copyWith(metadata: metadata));
    return workId;
  }

  Future<String> _updatePublicationDraft(
    String workId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final work = await _workService.updateWork(workId, payload);
      return work.id;
    } catch (_) {
      final work = await _workService.createWork({
        ...payload,
        'media_urls': <String>[],
      });
      return work.id;
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
