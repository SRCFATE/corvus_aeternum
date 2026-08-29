import 'dart:convert';

class AtelierWorkspace {
  final List<AtelierProject> projects;
  final AtelierProject? activeProject;
  final List<AtelierNode> nodes;
  final List<AtelierRelation> relations;
  final List<AtelierVersion> versions;

  const AtelierWorkspace({
    required this.projects,
    required this.activeProject,
    required this.nodes,
    required this.relations,
    required this.versions,
  });

  const AtelierWorkspace.empty()
      : projects = const [],
        activeProject = null,
        nodes = const [],
        relations = const [],
        versions = const [];
}

class AtelierProject {
  final String id;
  final String profileId;
  final String title;
  final String type;
  final String status;
  final String genre;
  final String universe;
  final String language;
  final String visibility;
  final int weeklyWordGoal;
  final bool publicProgressEnabled;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AtelierProject({
    required this.id,
    required this.profileId,
    required this.title,
    required this.type,
    required this.status,
    required this.genre,
    required this.universe,
    required this.language,
    required this.visibility,
    required this.weeklyWordGoal,
    required this.publicProgressEnabled,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AtelierProject.fromMap(Map<String, dynamic> map) {
    return AtelierProject(
      id: map['id'] as String,
      profileId: map['profile_id'] as String,
      title: map['title'] as String? ?? 'Obra sin titulo',
      type: map['type'] as String? ?? 'Novela',
      status: map['status'] as String? ?? 'idea',
      genre: map['genre'] as String? ?? '',
      universe: map['universe'] as String? ?? '',
      language: map['language'] as String? ?? 'es',
      visibility: map['visibility'] as String? ?? 'private',
      weeklyWordGoal: map['weekly_word_goal'] as int? ?? 0,
      publicProgressEnabled: map['public_progress_enabled'] as bool? ?? false,
      metadata: _jsonMap(map['metadata']),
      createdAt: _date(map['created_at']),
      updatedAt: _date(map['updated_at']),
    );
  }

  AtelierProject copyWith({
    String? title,
    String? type,
    String? status,
    String? genre,
    String? universe,
    String? language,
    String? visibility,
    int? weeklyWordGoal,
    bool? publicProgressEnabled,
    Map<String, dynamic>? metadata,
  }) {
    return AtelierProject(
      id: id,
      profileId: profileId,
      title: title ?? this.title,
      type: type ?? this.type,
      status: status ?? this.status,
      genre: genre ?? this.genre,
      universe: universe ?? this.universe,
      language: language ?? this.language,
      visibility: visibility ?? this.visibility,
      weeklyWordGoal: weeklyWordGoal ?? this.weeklyWordGoal,
      publicProgressEnabled:
          publicProgressEnabled ?? this.publicProgressEnabled,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toUpdateMap() => {
        'title': title.trim(),
        'type': type.trim(),
        'status': status,
        'genre': genre.trim(),
        'universe': universe.trim(),
        'language': language.trim().isEmpty ? 'es' : language.trim(),
        'visibility': visibility,
        'weekly_word_goal': weeklyWordGoal,
        'public_progress_enabled': publicProgressEnabled,
        'metadata': metadata,
      };

  Map<String, dynamic> toExportMap({
    required List<AtelierNode> nodes,
    required List<AtelierRelation> relations,
    required List<AtelierVersion> versions,
  }) {
    return {
      'project': toUpdateMap()..['id'] = id,
      'nodes': nodes.map((node) => node.toExportMap()).toList(),
      'relations': relations.map((relation) => relation.toExportMap()).toList(),
      'versions': versions.map((version) => version.toExportMap()).toList(),
    };
  }
}

class AtelierNode {
  final String id;
  final String projectId;
  final String profileId;
  final String kind;
  final String title;
  final String body;
  final String status;
  final String canonStatus;
  final String visibility;
  final List<String> tags;
  final Map<String, dynamic> metadata;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AtelierNode({
    required this.id,
    required this.projectId,
    required this.profileId,
    required this.kind,
    required this.title,
    required this.body,
    required this.status,
    required this.canonStatus,
    required this.visibility,
    required this.tags,
    required this.metadata,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AtelierNode.fromMap(Map<String, dynamic> map) {
    return AtelierNode(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      profileId: map['profile_id'] as String,
      kind: map['kind'] as String? ?? 'note',
      title: map['title'] as String? ?? 'Sin titulo',
      body: map['body'] as String? ?? '',
      status: map['status'] as String? ?? 'draft',
      canonStatus: map['canon_status'] as String? ?? 'canon',
      visibility: map['visibility'] as String? ?? 'private',
      tags: List<String>.from(map['tags'] as List? ?? const []),
      metadata: _jsonMap(map['metadata']),
      position: map['position'] as int? ?? 0,
      createdAt: _date(map['created_at']),
      updatedAt: _date(map['updated_at']),
    );
  }

  int get wordCount {
    final text = body.trim();
    if (text.isEmpty) return 0;
    return RegExp(r'\S+').allMatches(text).length;
  }

  List<String> get wikilinks {
    return RegExp(r'\[\[([^\]]+)\]\]')
        .allMatches(body)
        .map((match) => match.group(1)!.trim())
        .where((title) => title.isNotEmpty)
        .toSet()
        .toList();
  }

  AtelierNode copyWith({
    String? kind,
    String? title,
    String? body,
    String? status,
    String? canonStatus,
    String? visibility,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    int? position,
  }) {
    return AtelierNode(
      id: id,
      projectId: projectId,
      profileId: profileId,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      body: body ?? this.body,
      status: status ?? this.status,
      canonStatus: canonStatus ?? this.canonStatus,
      visibility: visibility ?? this.visibility,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
      position: position ?? this.position,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toUpdateMap() => {
        'kind': kind,
        'title': title.trim(),
        'body': body,
        'status': status,
        'canon_status': canonStatus,
        'visibility': visibility,
        'tags': tags,
        'metadata': metadata,
        'position': position,
      };

  Map<String, dynamic> toExportMap() => {
        ...toUpdateMap(),
        'id': id,
        'project_id': projectId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class AtelierRelation {
  final String id;
  final String projectId;
  final String profileId;
  final String sourceNodeId;
  final String relationType;
  final String targetNodeId;
  final String description;
  final String canonStatus;
  final DateTime createdAt;

  const AtelierRelation({
    required this.id,
    required this.projectId,
    required this.profileId,
    required this.sourceNodeId,
    required this.relationType,
    required this.targetNodeId,
    required this.description,
    required this.canonStatus,
    required this.createdAt,
  });

  factory AtelierRelation.fromMap(Map<String, dynamic> map) {
    return AtelierRelation(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      profileId: map['profile_id'] as String,
      sourceNodeId: map['source_node_id'] as String,
      relationType: map['relation_type'] as String? ?? 'menciona',
      targetNodeId: map['target_node_id'] as String,
      description: map['description'] as String? ?? '',
      canonStatus: map['canon_status'] as String? ?? 'canon',
      createdAt: _date(map['created_at']),
    );
  }

  Map<String, dynamic> toExportMap() => {
        'id': id,
        'project_id': projectId,
        'source_node_id': sourceNodeId,
        'relation_type': relationType,
        'target_node_id': targetNodeId,
        'description': description,
        'canon_status': canonStatus,
        'created_at': createdAt.toIso8601String(),
      };
}

class AtelierVersion {
  final String id;
  final String projectId;
  final String profileId;
  final String label;
  final String description;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const AtelierVersion({
    required this.id,
    required this.projectId,
    required this.profileId,
    required this.label,
    required this.description,
    required this.metadata,
    required this.createdAt,
  });

  factory AtelierVersion.fromMap(Map<String, dynamic> map) {
    return AtelierVersion(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      profileId: map['profile_id'] as String,
      label: map['label'] as String? ?? 'Version',
      description: map['description'] as String? ?? '',
      metadata: _jsonMap(map['metadata']),
      createdAt: _date(map['created_at']),
    );
  }

  Map<String, dynamic> toExportMap() => {
        'id': id,
        'project_id': projectId,
        'label': label,
        'description': description,
        'metadata': metadata,
        'created_at': createdAt.toIso8601String(),
      };
}

class AtelierReviewIssue {
  final String category;
  final String title;
  final String detail;
  final String severity;

  const AtelierReviewIssue({
    required this.category,
    required this.title,
    required this.detail,
    required this.severity,
  });
}

class AtelierChecklistItem {
  final String label;
  final bool done;
  final bool required;

  const AtelierChecklistItem({
    required this.label,
    required this.done,
    this.required = true,
  });
}

class AtelierPlannerEntry {
  final AtelierNode node;
  final String projectTitle;
  final String projectType;

  const AtelierPlannerEntry({
    required this.node,
    required this.projectTitle,
    required this.projectType,
  });

  factory AtelierPlannerEntry.fromMap(Map<String, dynamic> map) {
    final project = _jsonMap(map['atelier_projects']);
    return AtelierPlannerEntry(
      node: AtelierNode.fromMap(map),
      projectTitle: project['title'] as String? ?? 'Proyecto',
      projectType: project['type'] as String? ?? 'Obra',
    );
  }

  bool get isTask => node.kind == 'task';
  bool get isJournal => node.kind == 'journal';
  bool get isCompleted => node.status == 'completed';

  String get priority {
    final value = node.metadata['priority'] as String?;
    return value == null || value.isEmpty ? 'normal' : value;
  }

  String get mood {
    final value = node.metadata['mood'] as String?;
    return value == null || value.isEmpty ? 'neutral' : value;
  }

  DateTime? get scheduledFor => _metadataDate('scheduled_for');

  DateTime get journalDate => _metadataDate('journal_date') ?? node.createdAt;

  bool isOverdueAt(DateTime now) {
    final date = scheduledFor;
    if (date == null || isCompleted) return false;
    final today = DateTime(now.year, now.month, now.day);
    final scheduled = DateTime(date.year, date.month, date.day);
    return scheduled.isBefore(today);
  }

  bool isScheduledOn(DateTime date) {
    final scheduled = scheduledFor;
    return scheduled != null &&
        scheduled.year == date.year &&
        scheduled.month == date.month &&
        scheduled.day == date.day;
  }

  DateTime? _metadataDate(String key) {
    final value = node.metadata[key];
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }
}

class AtelierPlannerWorkspace {
  final List<AtelierProject> projects;
  final List<AtelierPlannerEntry> entries;

  const AtelierPlannerWorkspace({
    required this.projects,
    required this.entries,
  });

  List<AtelierPlannerEntry> get tasks =>
      entries.where((entry) => entry.isTask).toList()
        ..sort((a, b) {
          if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
          final aDate = a.scheduledFor;
          final bDate = b.scheduledFor;
          if (aDate == null && bDate == null) {
            return b.node.createdAt.compareTo(a.node.createdAt);
          }
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return aDate.compareTo(bDate);
        });

  List<AtelierPlannerEntry> get journals =>
      entries.where((entry) => entry.isJournal).toList()
        ..sort((a, b) => b.journalDate.compareTo(a.journalDate));
}

Map<String, dynamic> _jsonMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String && value.isNotEmpty) {
    final decoded = jsonDecode(value);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  }
  return <String, dynamic>{};
}

DateTime _date(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}
