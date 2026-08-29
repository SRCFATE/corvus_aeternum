import 'package:corvus_aeternum/models/atelier_models.dart';
import 'package:corvus_aeternum/models/collection.dart';
import 'package:corvus_aeternum/models/creative_insights.dart';
import 'package:corvus_aeternum/models/work.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CreativeInsights', () {
    test('aggregates private creative activity without double counting', () {
      final works = [
        _work(
          id: 'one',
          discipline: 'Ilustracion',
          status: 'published',
          complete: true,
          views: 120,
          likes: 10,
          saves: 4,
          comments: 2,
          year: 2025,
        ),
        _work(
          id: 'two',
          discipline: 'ilustracion',
          status: 'draft',
          views: 10,
          likes: 1,
          year: 2026,
        ),
        _work(
          id: 'three',
          discipline: 'Musica',
          status: 'published',
          views: 30,
          likes: 2,
          saves: 20,
          year: 2026,
        ),
      ];
      final projects = [
        _project(id: 'active', status: 'desarrollo'),
        _project(id: 'done', status: 'publicada'),
        _project(id: 'archived', status: 'archivada'),
      ];
      final collections = [
        Collection.fromMap({
          'id': 'collection',
          'profile_id': 'profile',
          'title': 'Archivo visual',
          'pieces_count': 7,
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-01T00:00:00.000Z',
        }),
      ];

      final insights = CreativeInsights.fromData(
        works: works,
        projects: projects,
        collections: collections,
      );

      expect(insights.publishedWorks, 2);
      expect(insights.completedWorks, 1);
      expect(insights.draftWorks, 1);
      expect(insights.totalViews, 160);
      expect(insights.totalLikes, 13);
      expect(insights.totalSaves, 24);
      expect(insights.totalComments, 2);
      expect(insights.activeProjects, 1);
      expect(insights.completedProjects, 1);
      expect(insights.archivedProjects, 1);
      expect(insights.collectionPieces, 7);
      expect(insights.disciplineCounts, {
        'Ilustracion': 2,
        'Musica': 1,
      });
      expect(insights.worksByYear, {2025: 1, 2026: 2});
      expect(insights.topWorks.first.id, 'one');
      expect(insights.completionRate, closeTo(1 / 3, 0.001));
    });

    test('uses explicit progress before the project status estimate', () {
      final explicit = _project(
        id: 'explicit',
        status: 'idea',
        metadata: const {'progress_percent': 68},
      );
      final clamped = _project(
        id: 'clamped',
        status: 'idea',
        metadata: const {'progress': '130'},
      );

      expect(CreativeInsights.projectProgress(explicit), 68);
      expect(CreativeInsights.projectProgress(clamped), 100);
      expect(
        CreativeInsights.projectProgress(
            _project(id: 'review', status: 'revision')),
        76,
      );
    });
  });
}

Work _work({
  required String id,
  required String discipline,
  required String status,
  bool complete = false,
  int views = 0,
  int likes = 0,
  int saves = 0,
  int comments = 0,
  int? year,
}) {
  return Work.fromMap({
    'id': id,
    'profile_id': 'profile',
    'title': 'Obra $id',
    'description': '',
    'discipline': discipline,
    'subdiscipline': '',
    'medium': '',
    'status': status,
    'is_public': status == 'published',
    'is_complete': complete,
    'views_count': views,
    'likes_count': likes,
    'saves_count': saves,
    'comments_count': comments,
    'year': year,
    'created_at': '2026-01-01T00:00:00.000Z',
    'updated_at': '2026-01-01T00:00:00.000Z',
  });
}

AtelierProject _project({
  required String id,
  required String status,
  Map<String, dynamic> metadata = const {},
}) {
  final timestamp = DateTime.utc(2026, 1, 1);
  return AtelierProject(
    id: id,
    profileId: 'profile',
    title: 'Proyecto $id',
    type: 'Obra',
    status: status,
    genre: '',
    universe: '',
    language: 'es',
    visibility: 'private',
    weeklyWordGoal: 0,
    publicProgressEnabled: false,
    metadata: metadata,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
