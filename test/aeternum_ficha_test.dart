import 'package:corvus_aeternum/models/aeternum_ficha.dart';
import 'package:corvus_aeternum/models/atelier_models.dart';
import 'package:corvus_aeternum/models/work.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AeternumFicha', () {
    test('enriches legacy work data with the stored Aeternum record', () {
      final work = Work.fromMap({
        'id': 'work-1',
        'profile_id': 'profile-1',
        'title': 'La ciudad que nunca amaneció',
        'description': 'Una novela de archivo vivo.',
        'discipline': 'Literatura',
        'subdiscipline': 'Novela',
        'medium': 'Digital',
        'status': 'published',
        'is_public': true,
        'created_at': '2026-08-15T00:00:00.000Z',
        'updated_at': '2026-08-15T00:00:00.000Z',
        'aeternum_ficha': {
          'source': 'atelier',
          'genre': 'Cyberpunk',
          'universe': 'Nuevo Anáhuac',
          'symbols': 'Cuervo; Eclipse',
        },
      });

      expect(work.aeternumFicha.title, work.title);
      expect(work.aeternumFicha.source, 'atelier');
      expect(work.aeternumFicha.genre, 'Cyberpunk');
      expect(work.aeternumFicha.universe, 'Nuevo Anáhuac');
      expect(work.aeternumFicha.symbols, ['Cuervo', 'Eclipse']);
    });

    test('builds public relationships from an Atelier project', () {
      final now = DateTime.utc(2026, 8, 15);
      final project = AtelierProject(
        id: 'project-1',
        profileId: 'profile-1',
        title: 'Distrito 404',
        type: 'Novela',
        status: 'in_progress',
        genre: 'Ciencia ficción',
        universe: 'Nuevo Anáhuac',
        language: 'es',
        visibility: 'public',
        weeklyWordGoal: 2500,
        publicProgressEnabled: true,
        metadata: const {
          'discipline': 'Literatura',
          'aesthetic_tone': 'Noir tecnológico',
        },
        createdAt: now,
        updatedAt: now,
      );
      final nodes = [
        AtelierNode(
          id: 'node-1',
          projectId: project.id,
          profileId: project.profileId,
          kind: 'character',
          title: 'Carlos',
          body: 'Protagonista.',
          status: 'draft',
          canonStatus: 'canon',
          visibility: 'private',
          tags: const [],
          metadata: const {},
          position: 0,
          createdAt: now,
          updatedAt: now,
        ),
        AtelierNode(
          id: 'node-2',
          projectId: project.id,
          profileId: project.profileId,
          kind: 'place',
          title: 'Distrito Central',
          body: '',
          status: 'draft',
          canonStatus: 'canon',
          visibility: 'private',
          tags: const ['ciudad'],
          metadata: const {},
          position: 1,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final ficha = AeternumFicha.fromAtelier(
        project: project,
        nodes: nodes,
        relations: const [],
        versions: const [],
      );

      expect(ficha.sourceProjectId, project.id);
      expect(ficha.discipline, 'Literatura');
      expect(ficha.relatedCharacters, ['Carlos']);
      expect(ficha.relatedPlaces, ['Distrito Central']);
      expect(ficha.linkedNodes, ['Carlos', 'Distrito Central']);
    });

    test('omits empty optional values from the JSON payload', () {
      const ficha = AeternumFicha(
        source: 'upload',
        title: 'Nocturno IV',
        discipline: 'Pintura',
      );

      final map = ficha.toMap();

      expect(map['version'], 1);
      expect(map['title'], 'Nocturno IV');
      expect(map.containsKey('subtitle'), isFalse);
      expect(map.containsKey('credits'), isFalse);
    });
  });
}
