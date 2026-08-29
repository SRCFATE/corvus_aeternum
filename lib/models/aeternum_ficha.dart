import 'atelier_models.dart';

class AeternumFicha {
  final int version;
  final String source;
  final String title;
  final String subtitle;
  final String internalName;
  final String description;
  final String discipline;
  final String subdiscipline;
  final String genre;
  final String subgenre;
  final String style;
  final String language;
  final List<String> secondaryLanguages;
  final String status;
  final String visibility;
  final String universe;
  final String branch;
  final String aestheticTone;
  final String atmosphere;
  final String palette;
  final List<String> symbols;
  final List<String> references;
  final List<String> inspirations;
  final String productionFormat;
  final String duration;
  final String dimensions;
  final String tools;
  final String software;
  final String hardware;
  final String materials;
  final String currentVersion;
  final String startedAt;
  final String finishedAt;
  final List<String> credits;
  final List<String> collaborators;
  final String rightsHolder;
  final String license;
  final String monetization;
  final String pricePlan;
  final String publicationPlan;
  final String certificateId;
  final String sourceProjectId;
  final String rootWorkId;
  final List<String> relatedCharacters;
  final List<String> relatedPlaces;
  final List<String> relatedEvents;
  final List<String> relatedFactions;
  final List<String> linkedNodes;
  final Map<String, dynamic> raw;

  const AeternumFicha({
    this.version = 1,
    this.source = '',
    this.title = '',
    this.subtitle = '',
    this.internalName = '',
    this.description = '',
    this.discipline = '',
    this.subdiscipline = '',
    this.genre = '',
    this.subgenre = '',
    this.style = '',
    this.language = '',
    this.secondaryLanguages = const [],
    this.status = '',
    this.visibility = '',
    this.universe = '',
    this.branch = '',
    this.aestheticTone = '',
    this.atmosphere = '',
    this.palette = '',
    this.symbols = const [],
    this.references = const [],
    this.inspirations = const [],
    this.productionFormat = '',
    this.duration = '',
    this.dimensions = '',
    this.tools = '',
    this.software = '',
    this.hardware = '',
    this.materials = '',
    this.currentVersion = '',
    this.startedAt = '',
    this.finishedAt = '',
    this.credits = const [],
    this.collaborators = const [],
    this.rightsHolder = '',
    this.license = '',
    this.monetization = '',
    this.pricePlan = '',
    this.publicationPlan = '',
    this.certificateId = '',
    this.sourceProjectId = '',
    this.rootWorkId = '',
    this.relatedCharacters = const [],
    this.relatedPlaces = const [],
    this.relatedEvents = const [],
    this.relatedFactions = const [],
    this.linkedNodes = const [],
    this.raw = const {},
  });

  factory AeternumFicha.fromSource(
    dynamic value, {
    Map<String, dynamic>? workMap,
  }) {
    final fallback = workMap == null
        ? const AeternumFicha()
        : AeternumFicha.fromWorkMap(workMap);
    final map = _jsonMap(value);
    if (map.isEmpty) return fallback;

    String text(List<String> keys, [String fallbackValue = '']) {
      for (final key in keys) {
        final raw = map[key];
        if (raw is String && raw.trim().isNotEmpty) return raw.trim();
        if (raw != null && raw is! List && raw is! Map) {
          final value = '$raw'.trim();
          if (value.isNotEmpty) return value;
        }
      }
      return fallbackValue;
    }

    List<String> list(List<String> keys,
        [List<String> fallbackValue = const []]) {
      for (final key in keys) {
        final parsed = _stringList(map[key]);
        if (parsed.isNotEmpty) return parsed;
      }
      return fallbackValue;
    }

    return AeternumFicha(
      version:
          int.tryParse(text(['version', 'aeternum_card_version'], '1')) ?? 1,
      source: text(['source'], fallback.source),
      title: text(['title'], fallback.title),
      subtitle: text(['subtitle'], fallback.subtitle),
      internalName:
          text(['internal_name', 'internalName'], fallback.internalName),
      description: text(
        ['description', 'synopsis_short', 'synopsis_long'],
        fallback.description,
      ),
      discipline: text(['discipline'], fallback.discipline),
      subdiscipline: text(['subdiscipline'], fallback.subdiscipline),
      genre: text(['genre', 'main_genre'], fallback.genre),
      subgenre: text(['subgenre'], fallback.subgenre),
      style: text(
          ['style', 'visual_technique', 'comic_art_style'], fallback.style),
      language: text(['language'], fallback.language),
      secondaryLanguages:
          list(['secondary_languages'], fallback.secondaryLanguages),
      status: text(['status'], fallback.status),
      visibility:
          text(['visibility', 'publication_visibility'], fallback.visibility),
      universe: text(['universe', 'linked_universe'], fallback.universe),
      branch: text(['branch', 'atelier_branch'], fallback.branch),
      aestheticTone: text(['aesthetic_tone', 'tone'], fallback.aestheticTone),
      atmosphere: text(['atmosphere'], fallback.atmosphere),
      palette: text(
          ['palette', 'visual_palette', 'fashion_colors'], fallback.palette),
      symbols: list(['symbols'], fallback.symbols),
      references: list(['references'], fallback.references),
      inspirations: list(['inspirations'], fallback.inspirations),
      productionFormat: text(
        [
          'production_format',
          'format_primary',
          'format_secondary',
          'video_format',
          'comic_format',
          'visual_scope',
        ],
        fallback.productionFormat,
      ),
      duration: text(
        ['duration', 'music_duration', 'video_duration', 'stage_duration'],
        fallback.duration,
      ),
      dimensions: text(
        ['dimensions', 'visual_dimensions', 'space_dimensions'],
        fallback.dimensions,
      ),
      tools: text(['tools', 'tools_used'], fallback.tools),
      software:
          text(['software', 'software_used', 'game_engine'], fallback.software),
      hardware: text(['hardware', 'hardware_used'], fallback.hardware),
      materials: text(
        [
          'materials',
          'visual_materials',
          'fashion_materials',
          'space_materials'
        ],
        fallback.materials,
      ),
      currentVersion: text(
        ['current_version', 'game_build'],
        fallback.currentVersion,
      ),
      startedAt: text(['started_at'], fallback.startedAt),
      finishedAt: text(['finished_at'], fallback.finishedAt),
      credits: list(['credits'], fallback.credits),
      collaborators: list(['collaborators'], fallback.collaborators),
      rightsHolder: text(['rights_holder'], fallback.rightsHolder),
      license: text(['license'], fallback.license),
      monetization: text(['monetization'], fallback.monetization),
      pricePlan: text(
        ['price_plan', 'fashion_price', 'price'],
        fallback.pricePlan,
      ),
      publicationPlan: text(['publication_plan'], fallback.publicationPlan),
      certificateId: text(['certificate_id'], fallback.certificateId),
      sourceProjectId: text(['source_project_id', 'atelier_project_id'],
          fallback.sourceProjectId),
      rootWorkId: text(['root_work_id'], fallback.rootWorkId),
      relatedCharacters:
          list(['related_characters'], fallback.relatedCharacters),
      relatedPlaces: list(['related_places'], fallback.relatedPlaces),
      relatedEvents: list(['related_events'], fallback.relatedEvents),
      relatedFactions: list(['related_factions'], fallback.relatedFactions),
      linkedNodes: list(['linked_nodes'], fallback.linkedNodes),
      raw: {...fallback.raw, ...map},
    );
  }

  factory AeternumFicha.fromWorkMap(Map<String, dynamic> map) {
    final title = _text(map['title']);
    final discipline = _text(map['discipline']);
    final medium = _text(map['medium']);
    final technique = _text(map['technique']);
    final musicGenre = _text(map['music_genre']);
    final price = map['price'];

    return AeternumFicha(
      source: 'work',
      title: title,
      description: _text(map['description']),
      discipline: discipline,
      subdiscipline: _text(map['subdiscipline']),
      genre: musicGenre.isNotEmpty ? musicGenre : medium,
      style: technique,
      language: _text(map['language']),
      status: _text(map['status']),
      visibility: map['is_public'] == true ? 'public' : 'private',
      duration: _text(map['duration']),
      dimensions: _text(map['dimensions']),
      monetization: map['is_for_sale'] == true ? 'sale' : 'none',
      pricePlan: price == null ? '' : '$price ${_text(map['currency'])}',
      raw: map,
    );
  }

  factory AeternumFicha.fromAtelier({
    required AtelierProject project,
    required List<AtelierNode> nodes,
    required List<AtelierRelation> relations,
    required List<AtelierVersion> versions,
  }) {
    final metadata = project.metadata;
    final branch = _text(metadata['atelier_branch']);
    final linkedNodeTitles = nodes
        .where((node) => node.body.trim().isNotEmpty || node.tags.isNotEmpty)
        .map((node) => node.title.trim())
        .where((title) => title.isNotEmpty)
        .take(16)
        .toList();

    List<String> nodeTitles(Set<String> kinds) {
      return nodes
          .where((node) => kinds.contains(node.kind))
          .map((node) => node.title.trim())
          .where((title) => title.isNotEmpty)
          .take(10)
          .toList();
    }

    return AeternumFicha.fromSource(
      {
        ...metadata,
        'source': 'atelier',
        'title': project.title,
        'discipline': _text(metadata['discipline'], branch),
        'subdiscipline': _text(metadata['subdiscipline'], project.type),
        'genre': _text(metadata['main_genre'], project.genre),
        'language': project.language,
        'status': project.status,
        'visibility': project.visibility,
        'universe': project.universe,
        'branch': branch,
        'source_project_id': project.id,
        'linked_nodes': linkedNodeTitles,
        'related_characters': nodeTitles({'character'}),
        'related_places': nodeTitles({'place', 'map', 'location'}),
        'related_events': nodeTitles({'event'}),
        'related_factions': nodeTitles({'faction', 'organization'}),
        'relations_count': relations.length,
        'versions_count': versions.length,
        'last_version_label': versions.isEmpty ? '' : versions.first.label,
      },
    );
  }

  bool get hasPublicData {
    return [
          subtitle,
          internalName,
          description,
          discipline,
          subdiscipline,
          genre,
          subgenre,
          style,
          language,
          status,
          universe,
          aestheticTone,
          atmosphere,
          palette,
          productionFormat,
          duration,
          dimensions,
          tools,
          software,
          hardware,
          materials,
          currentVersion,
          startedAt,
          finishedAt,
          rightsHolder,
          license,
          monetization,
          pricePlan,
          publicationPlan,
          certificateId,
        ].any((value) => value.trim().isNotEmpty) ||
        [
          secondaryLanguages,
          symbols,
          references,
          inspirations,
          credits,
          collaborators,
          relatedCharacters,
          relatedPlaces,
          relatedEvents,
          relatedFactions,
          linkedNodes,
        ].any((value) => value.isNotEmpty);
  }

  Map<String, dynamic> toMap() {
    return _withoutEmpty({
      'version': version,
      'source': source,
      'title': title,
      'subtitle': subtitle,
      'internal_name': internalName,
      'description': description,
      'discipline': discipline,
      'subdiscipline': subdiscipline,
      'genre': genre,
      'subgenre': subgenre,
      'style': style,
      'language': language,
      'secondary_languages': secondaryLanguages,
      'status': status,
      'visibility': visibility,
      'universe': universe,
      'branch': branch,
      'aesthetic_tone': aestheticTone,
      'atmosphere': atmosphere,
      'palette': palette,
      'symbols': symbols,
      'references': references,
      'inspirations': inspirations,
      'production_format': productionFormat,
      'duration': duration,
      'dimensions': dimensions,
      'tools': tools,
      'software': software,
      'hardware': hardware,
      'materials': materials,
      'current_version': currentVersion,
      'started_at': startedAt,
      'finished_at': finishedAt,
      'credits': credits,
      'collaborators': collaborators,
      'rights_holder': rightsHolder,
      'license': license,
      'monetization': monetization,
      'price_plan': pricePlan,
      'publication_plan': publicationPlan,
      'certificate_id': certificateId,
      'source_project_id': sourceProjectId,
      'root_work_id': rootWorkId,
      'related_characters': relatedCharacters,
      'related_places': relatedPlaces,
      'related_events': relatedEvents,
      'related_factions': relatedFactions,
      'linked_nodes': linkedNodes,
    });
  }
}

Map<String, dynamic> _jsonMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

String _text(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }
  final text = '$value'.trim();
  return text.isEmpty ? fallback : text;
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value.map(_text).where((item) => item.isNotEmpty).toSet().toList();
  }
  if (value is String && value.trim().isNotEmpty) {
    return value
        .split(RegExp(r'[,;\n]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }
  return const [];
}

Map<String, dynamic> _withoutEmpty(Map<String, dynamic> value) {
  return Map.fromEntries(
    value.entries.where((entry) {
      final value = entry.value;
      if (value == null) return false;
      if (value is String) return value.trim().isNotEmpty;
      if (value is List) return value.isNotEmpty;
      if (value is Map) return value.isNotEmpty;
      return true;
    }),
  );
}
