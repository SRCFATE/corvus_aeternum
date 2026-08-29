import 'atelier_models.dart';
import 'collection.dart';
import 'work.dart';

class CreativeInsights {
  final List<Work> works;
  final List<AtelierProject> projects;
  final List<Collection> collections;
  final Map<String, int> disciplineCounts;
  final Map<int, int> worksByYear;
  final List<Work> topWorks;
  final List<AtelierProject> recentProjects;
  final int publishedWorks;
  final int completedWorks;
  final int draftWorks;
  final int totalViews;
  final int totalLikes;
  final int totalSaves;
  final int totalComments;
  final int activeProjects;
  final int completedProjects;
  final int archivedProjects;
  final int collectionPieces;

  const CreativeInsights({
    required this.works,
    required this.projects,
    required this.collections,
    required this.disciplineCounts,
    required this.worksByYear,
    required this.topWorks,
    required this.recentProjects,
    required this.publishedWorks,
    required this.completedWorks,
    required this.draftWorks,
    required this.totalViews,
    required this.totalLikes,
    required this.totalSaves,
    required this.totalComments,
    required this.activeProjects,
    required this.completedProjects,
    required this.archivedProjects,
    required this.collectionPieces,
  });

  factory CreativeInsights.fromData({
    required List<Work> works,
    required List<AtelierProject> projects,
    required List<Collection> collections,
  }) {
    final disciplines = <String, int>{};
    final disciplineLabels = <String, String>{};
    final years = <int, int>{};

    for (final work in works) {
      final discipline = work.discipline.trim();
      if (discipline.isNotEmpty) {
        final key = discipline.toLowerCase();
        disciplineLabels.putIfAbsent(key, () => discipline);
        disciplines[key] = (disciplines[key] ?? 0) + 1;
      }
      final year = work.year ?? work.createdAt.year;
      years[year] = (years[year] ?? 0) + 1;
    }

    final orderedDisciplines = disciplines.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    final orderedYears = years.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final rankedWorks = [...works]..sort((a, b) {
        final byScore = _workScore(b).compareTo(_workScore(a));
        return byScore != 0 ? byScore : b.createdAt.compareTo(a.createdAt);
      });
    final orderedProjects = [...projects]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return CreativeInsights(
      works: List.unmodifiable(works),
      projects: List.unmodifiable(projects),
      collections: List.unmodifiable(collections),
      disciplineCounts: Map.unmodifiable({
        for (final entry in orderedDisciplines)
          disciplineLabels[entry.key]!: entry.value,
      }),
      worksByYear: Map.unmodifiable({
        for (final entry in orderedYears) entry.key: entry.value,
      }),
      topWorks: List.unmodifiable(rankedWorks.take(5)),
      recentProjects: List.unmodifiable(orderedProjects.take(6)),
      publishedWorks: works.where((work) => work.status == 'published').length,
      completedWorks: works.where((work) => work.isComplete).length,
      draftWorks: works.where((work) => work.status != 'published').length,
      totalViews: works.fold(0, (sum, work) => sum + work.viewsCount),
      totalLikes: works.fold(0, (sum, work) => sum + work.likesCount),
      totalSaves: works.fold(0, (sum, work) => sum + work.savesCount),
      totalComments: works.fold(0, (sum, work) => sum + work.commentsCount),
      activeProjects: projects.where(isActiveProject).length,
      completedProjects: projects.where(isCompletedProject).length,
      archivedProjects: projects.where(isArchivedProject).length,
      collectionPieces: collections.fold(
          0, (sum, collection) => sum + collection.piecesCount),
    );
  }

  int get totalInteractions => totalLikes + totalSaves + totalComments;

  double get completionRate {
    if (works.isEmpty) return 0;
    return completedWorks / works.length;
  }

  static bool isActiveProject(AtelierProject project) {
    return !isCompletedProject(project) &&
        !isArchivedProject(project) &&
        project.status != 'cancelada' &&
        project.status != 'cancelled';
  }

  static bool isCompletedProject(AtelierProject project) {
    return const {
      'final',
      'lista',
      'lista_para_publicar',
      'publicada',
      'published',
      'completed',
      'edicion_definitiva',
    }.contains(project.status);
  }

  static bool isArchivedProject(AtelierProject project) {
    return project.status == 'archivada' || project.status == 'archived';
  }

  static int projectProgress(AtelierProject project) {
    final explicit = project.metadata['progress'] ??
        project.metadata['progress_percent'] ??
        project.metadata['completion'];
    final parsed = explicit is num
        ? explicit.round()
        : int.tryParse(explicit?.toString() ?? '');
    if (parsed != null) return parsed.clamp(0, 100);

    return switch (project.status) {
      'idea' || 'concepto' => 10,
      'planeacion' || 'planning' => 20,
      'borrador' || 'draft' || 'prototipo' => 32,
      'desarrollo' || 'in_progress' || 'produccion' => 55,
      'revision' || 'edicion' || 'mezcla' || 'pruebas' => 76,
      'final' || 'lista' || 'lista_para_publicar' => 92,
      'publicada' || 'published' || 'completed' || 'edicion_definitiva' => 100,
      'archivada' || 'archived' => 100,
      _ => 25,
    };
  }

  static int _workScore(Work work) {
    return work.viewsCount +
        work.likesCount * 3 +
        work.savesCount * 4 +
        work.commentsCount * 2;
  }
}
