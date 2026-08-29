import 'package:corvus_aeternum/models/atelier_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AtelierPlannerEntry', () {
    test('parses task scheduling and project context', () {
      final entry = AtelierPlannerEntry.fromMap(
        _entryMap(
          id: 'task',
          kind: 'task',
          status: 'draft',
          metadata: const {
            'scheduled_for': '2026-08-14',
            'priority': 'high',
          },
        ),
      );

      expect(entry.isTask, isTrue);
      expect(entry.projectTitle, 'Distrito 404');
      expect(entry.priority, 'high');
      expect(entry.isScheduledOn(DateTime(2026, 8, 14)), isTrue);
      expect(entry.isOverdueAt(DateTime(2026, 8, 16)), isTrue);
    });

    test('does not mark completed tasks as overdue', () {
      final entry = AtelierPlannerEntry.fromMap(
        _entryMap(
          id: 'done',
          kind: 'task',
          status: 'completed',
          metadata: const {'scheduled_for': '2026-08-14'},
        ),
      );

      expect(entry.isCompleted, isTrue);
      expect(entry.isOverdueAt(DateTime(2026, 8, 16)), isFalse);
    });

    test('orders tasks by completion and date and journals newest first', () {
      final workspace = AtelierPlannerWorkspace(
        projects: const [],
        entries: [
          AtelierPlannerEntry.fromMap(
            _entryMap(
              id: 'later',
              kind: 'task',
              status: 'draft',
              metadata: const {'scheduled_for': '2026-08-20'},
            ),
          ),
          AtelierPlannerEntry.fromMap(
            _entryMap(
              id: 'done',
              kind: 'task',
              status: 'completed',
              metadata: const {'scheduled_for': '2026-08-10'},
            ),
          ),
          AtelierPlannerEntry.fromMap(
            _entryMap(
              id: 'first',
              kind: 'task',
              status: 'draft',
              metadata: const {'scheduled_for': '2026-08-18'},
            ),
          ),
          AtelierPlannerEntry.fromMap(
            _entryMap(
              id: 'journal-old',
              kind: 'journal',
              metadata: const {'journal_date': '2026-08-12'},
            ),
          ),
          AtelierPlannerEntry.fromMap(
            _entryMap(
              id: 'journal-new',
              kind: 'journal',
              metadata: const {'journal_date': '2026-08-15'},
            ),
          ),
        ],
      );

      expect(
        workspace.tasks.map((entry) => entry.node.id),
        ['first', 'later', 'done'],
      );
      expect(
        workspace.journals.map((entry) => entry.node.id),
        ['journal-new', 'journal-old'],
      );
    });
  });
}

Map<String, dynamic> _entryMap({
  required String id,
  required String kind,
  String status = 'draft',
  Map<String, dynamic> metadata = const {},
}) {
  return {
    'id': id,
    'project_id': 'project',
    'profile_id': 'profile',
    'kind': kind,
    'title': 'Registro $id',
    'body': 'Contenido',
    'status': status,
    'metadata': metadata,
    'created_at': '2026-08-01T00:00:00.000Z',
    'updated_at': '2026-08-01T00:00:00.000Z',
    'atelier_projects': {
      'title': 'Distrito 404',
      'type': 'Novela',
    },
  };
}
