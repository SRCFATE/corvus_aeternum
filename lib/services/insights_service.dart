import '../models/atelier_models.dart';
import '../models/collection.dart';
import '../models/creative_insights.dart';
import '../models/work.dart';
import 'atelier_service.dart';
import 'collection_service.dart';
import 'work_service.dart';

class InsightsService {
  final WorkService _workService;
  final AtelierService _atelierService;
  final CollectionService _collectionService;

  InsightsService({
    WorkService? workService,
    AtelierService? atelierService,
    CollectionService? collectionService,
  })  : _workService = workService ?? WorkService(),
        _atelierService = atelierService ?? AtelierService(),
        _collectionService = collectionService ?? CollectionService();

  Future<CreativeInsights> load(String profileId) async {
    final results = await Future.wait([
      _workService.getOwnWorks(profileId),
      _loadProjects(profileId),
      _collectionService.getUserCollections(profileId),
    ]);

    return CreativeInsights.fromData(
      works: results[0] as List<Work>,
      projects: results[1] as List<AtelierProject>,
      collections: results[2] as List<Collection>,
    );
  }

  Future<List<AtelierProject>> _loadProjects(String profileId) async {
    try {
      final workspace = await _atelierService.loadWorkspace(profileId);
      return workspace.projects;
    } on AtelierSchemaException {
      return const [];
    }
  }
}
