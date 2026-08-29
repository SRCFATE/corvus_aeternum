import '../models/atelier_models.dart';
import 'atelier_service.dart';

class PlannerService {
  final AtelierService _atelierService;

  PlannerService({AtelierService? atelierService})
      : _atelierService = atelierService ?? AtelierService();

  Future<AtelierPlannerWorkspace> load(String profileId) async {
    try {
      final results = await Future.wait([
        _atelierService.getProjects(profileId),
        _atelierService.getPlannerEntries(profileId),
      ]);
      return AtelierPlannerWorkspace(
        projects: results[0] as List<AtelierProject>,
        entries: results[1] as List<AtelierPlannerEntry>,
      );
    } catch (error) {
      if (_looksLikeMissingSchema(error)) {
        throw const AtelierSchemaException(
          'Faltan las tablas privadas de Atelier.',
        );
      }
      rethrow;
    }
  }

  Future<void> createTask({
    required String profileId,
    required String projectId,
    required String title,
    required String notes,
    required DateTime scheduledFor,
    required String priority,
  }) async {
    await _atelierService.createNode(
      profileId: profileId,
      projectId: projectId,
      kind: 'task',
      title: title,
      body: notes,
      status: 'draft',
      metadata: {
        'scheduled_for': _dateOnly(scheduledFor),
        'priority': priority,
      },
    );
  }

  Future<void> updateTask({
    required AtelierPlannerEntry entry,
    required String title,
    required String notes,
    required DateTime scheduledFor,
    required String priority,
  }) async {
    await _atelierService.updateNode(
      entry.node.copyWith(
        title: title,
        body: notes,
        metadata: {
          ...entry.node.metadata,
          'scheduled_for': _dateOnly(scheduledFor),
          'priority': priority,
        },
      ),
    );
  }

  Future<void> setTaskCompleted(
    AtelierPlannerEntry entry, {
    required bool completed,
  }) async {
    await _atelierService.updateNode(
      entry.node.copyWith(
        status: completed ? 'completed' : 'draft',
        metadata: {
          ...entry.node.metadata,
          'completed_at': completed ? DateTime.now().toIso8601String() : null,
        },
      ),
    );
  }

  Future<void> createJournal({
    required String profileId,
    required String projectId,
    required String title,
    required String body,
    required DateTime journalDate,
    required String mood,
  }) async {
    await _atelierService.createNode(
      profileId: profileId,
      projectId: projectId,
      kind: 'journal',
      title: title,
      body: body,
      metadata: {
        'journal_date': _dateOnly(journalDate),
        'mood': mood,
      },
    );
  }

  Future<void> updateJournal({
    required AtelierPlannerEntry entry,
    required String title,
    required String body,
    required DateTime journalDate,
    required String mood,
  }) async {
    await _atelierService.updateNode(
      entry.node.copyWith(
        title: title,
        body: body,
        metadata: {
          ...entry.node.metadata,
          'journal_date': _dateOnly(journalDate),
          'mood': mood,
        },
      ),
    );
  }

  Future<void> deleteEntry(AtelierPlannerEntry entry) {
    return _atelierService.deleteNode(entry.node);
  }

  String _dateOnly(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  bool _looksLikeMissingSchema(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('pgrst205') ||
        message.contains('schema cache') ||
        message.contains('does not exist') ||
        message.contains('could not find the table');
  }
}
