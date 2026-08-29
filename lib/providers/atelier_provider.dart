import 'package:flutter/foundation.dart';

import '../models/atelier_models.dart';
import '../services/atelier_service.dart';

class AtelierProvider extends ChangeNotifier {
  final AtelierService _service;

  AtelierProvider({AtelierService? service})
      : _service = service ?? AtelierService();

  bool _loading = false;
  bool _schemaMissing = false;
  String? _error;
  AtelierWorkspace _workspace = const AtelierWorkspace.empty();

  bool get loading => _loading;
  bool get schemaMissing => _schemaMissing;
  String? get error => _error;
  AtelierWorkspace get workspace => _workspace;

  List<AtelierProject> get projects => _workspace.projects;
  AtelierProject? get activeProject => _workspace.activeProject;
  List<AtelierNode> get nodes => _workspace.nodes;
  List<AtelierRelation> get relations => _workspace.relations;
  List<AtelierVersion> get versions => _workspace.versions;

  List<AtelierNode> get chapters => _kind('chapter');
  List<AtelierNode> get scenes => _kind('scene');
  List<AtelierNode> get notes => _kind('note');
  List<AtelierNode> get characters => _kind('character');
  List<AtelierNode> get places => _kind('place');
  List<AtelierNode> get factions => _kind('faction');
  List<AtelierNode> get events => _kind('event');
  List<AtelierNode> get assets => _kind('asset');

  String get activeBranchId {
    final raw = activeProject?.metadata['atelier_branch'] as String?;
    if (raw != null && raw.trim().isNotEmpty) return raw.trim();
    final type = activeProject?.type.toLowerCase() ?? '';
    if (type.contains('cancion') || type.contains('album')) return 'music';
    if (type.contains('ilustr') || type.contains('pintura')) return 'visual';
    if (type.contains('comic') || type.contains('manga')) return 'comic';
    if (type.contains('foto') ||
        type.contains('retr') ||
        type.contains('editorial')) {
      return 'photo';
    }
    if (type.contains('prenda') || type.contains('coleccion')) {
      return 'fashion';
    }
    if (type.contains('juego') || type.contains('rpg')) return 'game';
    if (type.contains('mundo') || type.contains('world')) return 'world';
    return 'writing';
  }

  List<String> get studioKinds => switch (activeBranchId) {
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

  List<AtelierNode> get studioNodes =>
      nodes.where((node) => studioKinds.contains(node.kind)).toList()
        ..sort((a, b) => a.position.compareTo(b.position));

  List<AtelierNode> get worldNodes => nodes
      .where((node) => const {
            'universe',
            'world',
            'character',
            'place',
            'faction',
            'family',
            'organization',
            'religion',
            'culture',
            'language',
            'system',
            'technology',
            'magic',
            'creature',
            'object',
            'event',
            'map',
          }.contains(node.kind))
      .toList();

  int get wordCount {
    return nodes
        .where((node) => node.kind == 'chapter' || node.kind == 'scene')
        .fold<int>(0, (sum, node) => sum + node.wordCount);
  }

  int get linkedNotesCount {
    final linkedIds = relations
        .expand((relation) => [relation.sourceNodeId, relation.targetNodeId])
        .toSet();
    return notes.where((note) => linkedIds.contains(note.id)).length;
  }

  int get projectHealth {
    if (activeProject == null) return 0;
    var score = 52;
    score +=
        studioNodes.where((node) => node.body.trim().isNotEmpty).length * 3;
    score += characters.where((node) => node.body.trim().isNotEmpty).length;
    score +=
        events.where((node) => _metadataText(node, 'date').isNotEmpty).length;
    score += relations.length;
    score -= reviewIssues.length * 5;
    return score.clamp(0, 100);
  }

  List<AtelierReviewIssue> get reviewIssues {
    final issues = <AtelierReviewIssue>[];
    final linkedIds = relations
        .expand((relation) => [relation.sourceNodeId, relation.targetNodeId])
        .toSet();

    final orphanNotes = notes
        .where((note) => !linkedIds.contains(note.id) && note.wikilinks.isEmpty)
        .length;
    if (orphanNotes > 0) {
      issues.add(AtelierReviewIssue(
        category: 'Archivo',
        title: 'Notas huerfanas',
        detail:
            '$orphanNotes notas no tienen relaciones ni enlaces [[internos]].',
        severity: 'media',
      ));
    }

    final emptyStudioItems =
        studioNodes.where((node) => node.body.trim().isEmpty).length;
    if (emptyStudioItems > 0) {
      issues.add(AtelierReviewIssue(
        category: 'Taller',
        title: 'Elementos sin contenido',
        detail:
            '$emptyStudioItems elementos del taller no tienen contenido. Se omitirán al publicar.',
        severity: 'media',
      ));
    }

    final scenesWithoutPurpose =
        scenes.where((scene) => _metadataText(scene, 'purpose').isEmpty).length;
    if (scenesWithoutPurpose > 0) {
      issues.add(AtelierReviewIssue(
        category: 'Narrativa',
        title: 'Escenas sin funcion',
        detail: '$scenesWithoutPurpose escenas no tienen proposito narrativo.',
        severity: 'media',
      ));
    }

    final eventsWithoutDate =
        events.where((event) => _metadataText(event, 'date').isEmpty).length;
    if (eventsWithoutDate > 0) {
      issues.add(AtelierReviewIssue(
        category: 'Cronologia',
        title: 'Eventos sin fecha',
        detail: '$eventsWithoutDate eventos no tienen fecha interna.',
        severity: 'media',
      ));
    }

    final duplicateGroups = <String, int>{};
    for (final node in nodes) {
      final key = node.title.trim().toLowerCase();
      if (key.isNotEmpty) {
        duplicateGroups[key] = (duplicateGroups[key] ?? 0) + 1;
      }
    }
    final duplicates =
        duplicateGroups.values.where((count) => count > 1).length;
    if (duplicates > 0) {
      issues.add(AtelierReviewIssue(
        category: 'Nombres',
        title: 'Titulos duplicados',
        detail: '$duplicates nombres aparecen mas de una vez.',
        severity: 'baja',
      ));
    }

    for (final relation in relations
        .where((relation) => relation.relationType == 'depende de')) {
      final source = nodeById(relation.sourceNodeId);
      final target = nodeById(relation.targetNodeId);
      final sourceDate = _parseNodeDate(source);
      final targetDate = _parseNodeDate(target);
      if (sourceDate != null &&
          targetDate != null &&
          sourceDate.isBefore(targetDate)) {
        issues.add(AtelierReviewIssue(
          category: 'Cronologia',
          title: 'Dependencia temporal rota',
          detail:
              '${source?.title ?? 'Un evento'} ocurre antes de ${target?.title ?? 'su causa'}.',
          severity: 'alta',
        ));
      }
    }

    return issues;
  }

  List<AtelierChecklistItem> get publicationChecklist {
    final project = activeProject;
    if (project == null) return const [];
    final metadata = project.metadata;
    return [
      AtelierChecklistItem(
        label: 'Titulo confirmado',
        done: project.title.trim().isNotEmpty,
      ),
      AtelierChecklistItem(
        label: 'Descripcion',
        done: (metadata['description'] as String?)?.trim().isNotEmpty == true ||
            (metadata['synopsis_short'] as String?)?.trim().isNotEmpty == true,
      ),
      AtelierChecklistItem(
        label: 'Portada cargada',
        done: (metadata['cover_url'] as String?)?.trim().isNotEmpty == true,
        required: false,
      ),
      AtelierChecklistItem(
        label: 'Genero principal',
        done: project.genre.trim().isNotEmpty,
      ),
      AtelierChecklistItem(
        label: 'Clasificacion por edad',
        done: (metadata['age_rating'] as String?)?.trim().isNotEmpty == true,
      ),
      AtelierChecklistItem(
        label: 'Al menos un elemento con contenido',
        done: studioNodes.any((node) => node.body.trim().isNotEmpty),
      ),
      AtelierChecklistItem(
        label: 'Sin alertas altas',
        done: !reviewIssues.any((issue) => issue.severity == 'alta'),
      ),
    ];
  }

  bool get canPreparePublication {
    return publicationChecklist
        .where((item) => item.required)
        .every((item) => item.done);
  }

  Future<void> load(String profileId, {String? projectId}) async {
    _loading = true;
    _schemaMissing = false;
    _error = null;
    notifyListeners();
    try {
      _workspace =
          await _service.loadWorkspace(profileId, projectId: projectId);
    } on AtelierSchemaException catch (error) {
      _workspace = const AtelierWorkspace.empty();
      _schemaMissing = true;
      _error = error.message;
    } catch (error) {
      _error = error.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> selectProject(String profileId, String projectId) async {
    await load(profileId, projectId: projectId);
  }

  Future<void> createProject({
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
    _loading = true;
    notifyListeners();
    try {
      final project = await _service.createProject(
        profileId: profileId,
        title: title,
        type: type,
        status: status,
        genre: genre,
        universe: universe,
        language: language,
        visibility: visibility,
        weeklyWordGoal: weeklyWordGoal,
        publicProgressEnabled: publicProgressEnabled,
        metadata: metadata,
      );
      await load(profileId, projectId: project.id);
    } on AtelierSchemaException catch (error) {
      _schemaMissing = true;
      _error = error.message;
      _loading = false;
      notifyListeners();
    } catch (error) {
      _error = error.toString();
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> updateProject(AtelierProject project) async {
    final updated = await _service.updateProject(project);
    _replaceActiveProject(updated);
  }

  Future<void> deleteActiveProject(String profileId) async {
    final project = activeProject;
    if (project == null) return;
    await _service.deleteProject(project);
    await load(profileId);
  }

  Future<AtelierNode?> createNode({
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
  }) async {
    final node = await _service.createNode(
      profileId: profileId,
      projectId: projectId,
      kind: kind,
      title: title,
      body: body,
      status: status,
      canonStatus: canonStatus,
      visibility: visibility,
      tags: tags,
      metadata: metadata,
      position: nodes.length,
    );
    await load(profileId, projectId: projectId);
    return node;
  }

  Future<void> updateNode(AtelierNode node) async {
    final updated = await _service.updateNode(node);
    final updatedNodes = nodes
        .map((current) => current.id == updated.id ? updated : current)
        .toList();
    _workspace = AtelierWorkspace(
      projects: projects,
      activeProject: activeProject,
      nodes: updatedNodes,
      relations: relations,
      versions: versions,
    );
    notifyListeners();
  }

  Future<void> deleteNode(String profileId, AtelierNode node) async {
    await _service.deleteNode(node);
    await load(profileId, projectId: node.projectId);
  }

  Future<void> createRelation({
    required String profileId,
    required String projectId,
    required String sourceNodeId,
    required String relationType,
    required String targetNodeId,
    String description = '',
  }) async {
    await _service.createRelation(
      profileId: profileId,
      projectId: projectId,
      sourceNodeId: sourceNodeId,
      relationType: relationType,
      targetNodeId: targetNodeId,
      description: description,
    );
    await load(profileId, projectId: projectId);
  }

  Future<void> deleteRelation(
      String profileId, AtelierRelation relation) async {
    await _service.deleteRelation(relation);
    await load(profileId, projectId: relation.projectId);
  }

  Future<void> createVersionSnapshot({
    required String profileId,
    required String projectId,
    required String label,
    required String description,
  }) async {
    await _service.createVersion(
      profileId: profileId,
      projectId: projectId,
      label: label,
      description: description,
      metadata: {
        'word_count': wordCount,
        'nodes_count': nodes.length,
        'studio_nodes_count': studioNodes.length,
        'relations_count': relations.length,
      },
    );
    await load(profileId, projectId: projectId);
  }

  Future<String?> preparePublication() async {
    final project = activeProject;
    if (project == null) return null;
    final workId = await _service.preparePublication(
      project: project,
      nodes: nodes,
      relations: relations,
      versions: versions,
    );
    await load(project.profileId, projectId: project.id);
    return workId;
  }

  /// Publicación por entregas: vuelca los capítulos actuales del taller en la
  /// obra ya vinculada sin alterar su sello. Null si no hay obra vinculada.
  Future<({String workId, int chapters, bool isPublished})?>
      syncPublication() async {
    final project = activeProject;
    if (project == null) return null;
    return _service.syncPublishedWork(
      project: project,
      nodes: nodes,
      relations: relations,
      versions: versions,
    );
  }

  String exportJson() => _service.exportJson(_workspace);

  AtelierNode? nodeById(String? id) {
    if (id == null) return null;
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  List<AtelierRelation> relationsForNode(String nodeId) {
    return relations
        .where((relation) =>
            relation.sourceNodeId == nodeId || relation.targetNodeId == nodeId)
        .toList();
  }

  List<AtelierNode> backlinksFor(AtelierNode node) {
    final relationIds = relationsForNode(node.id)
        .map((relation) => relation.sourceNodeId == node.id
            ? relation.targetNodeId
            : relation.sourceNodeId)
        .toSet();

    final linkTitle = node.title.toLowerCase();
    return nodes.where((candidate) {
      if (candidate.id == node.id) return false;
      if (relationIds.contains(candidate.id)) return true;
      return candidate.wikilinks
          .map((title) => title.toLowerCase())
          .contains(linkTitle);
    }).toList();
  }

  List<AtelierNode> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return nodes.where((node) {
      return node.title.toLowerCase().contains(q) ||
          node.body.toLowerCase().contains(q) ||
          node.tags.any((tag) => tag.toLowerCase().contains(q)) ||
          node.kind.toLowerCase().contains(q);
    }).toList();
  }

  List<AtelierNode> _kind(String kind) {
    return nodes.where((node) => node.kind == kind).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  void _replaceActiveProject(AtelierProject updated) {
    _workspace = AtelierWorkspace(
      projects: projects
          .map((project) => project.id == updated.id ? updated : project)
          .toList(),
      activeProject: updated,
      nodes: nodes,
      relations: relations,
      versions: versions,
    );
    notifyListeners();
  }

  String _metadataText(AtelierNode node, String key) {
    return (node.metadata[key] as String?)?.trim() ?? '';
  }

  DateTime? _parseNodeDate(AtelierNode? node) {
    if (node == null) return null;
    final raw = _metadataText(node, 'date');
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}
