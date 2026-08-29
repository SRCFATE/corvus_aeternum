enum LanguageSuggestionKind { spelling, repetition, typography, style }

class LanguageSuggestion {
  final String id;
  final LanguageSuggestionKind kind;
  final int offset;
  final int length;
  final String found;
  final String message;
  final List<String> replacements;

  const LanguageSuggestion({
    required this.id,
    required this.kind,
    required this.offset,
    required this.length,
    required this.found,
    required this.message,
    required this.replacements,
  });

  String get label => switch (kind) {
        LanguageSuggestionKind.spelling => 'Ortografia',
        LanguageSuggestionKind.repetition => 'Repeticion',
        LanguageSuggestionKind.typography => 'Tipografia',
        LanguageSuggestionKind.style => 'Estilo',
      };
}

class ThesaurusEntry {
  final String word;
  final String definition;
  final List<String> synonyms;
  final List<String> antonyms;
  final String register;

  const ThesaurusEntry({
    required this.word,
    required this.definition,
    required this.synonyms,
    this.antonyms = const [],
    this.register = 'General',
  });
}

class SpanishLanguageService {
  static const _accented = <String, String>{
    'ademas': 'adem\u00e1s',
    'algun': 'alg\u00fan',
    'arbol': '\u00e1rbol',
    'capitulo': 'cap\u00edtulo',
    'corazon': 'coraz\u00f3n',
    'dialogo': 'di\u00e1logo',
    'dificil': 'dif\u00edcil',
    'faccion': 'facci\u00f3n',
    'facil': 'f\u00e1cil',
    'ficcion': 'ficci\u00f3n',
    'habia': 'hab\u00eda',
    'jamas': 'jam\u00e1s',
    'lapiz': 'l\u00e1piz',
    'linea': 'l\u00ednea',
    'musica': 'm\u00fasica',
    'nacion': 'naci\u00f3n',
    'pagina': 'p\u00e1gina',
    'publicacion': 'publicaci\u00f3n',
    'rapido': 'r\u00e1pido',
    'rebelion': 'rebeli\u00f3n',
    'revision': 'revisi\u00f3n',
    'tambien': 'tambi\u00e9n',
    'tecnica': 't\u00e9cnica',
    'todavia': 'todav\u00eda',
    'unico': '\u00fanico',
    'version': 'versi\u00f3n',
  };

  static const entries = <ThesaurusEntry>[
    ThesaurusEntry(
        word: 'alegre',
        definition: 'Que expresa o produce alegria.',
        synonyms: ['feliz', 'jovial', 'gozoso', 'radiante'],
        antonyms: ['triste', 'apenado']),
    ThesaurusEntry(
        word: 'andar',
        definition: 'Desplazarse dando pasos.',
        synonyms: ['caminar', 'avanzar', 'recorrer', 'transitar']),
    ThesaurusEntry(
        word: 'antiguo',
        definition: 'Que existe desde hace mucho tiempo.',
        synonyms: ['ancestral', 'remoto', 'arcaico', 'veterano'],
        antonyms: ['nuevo', 'reciente']),
    ThesaurusEntry(
        word: 'bello',
        definition: 'Que produce admiracion o placer estetico.',
        synonyms: ['hermoso', 'precioso', 'armonioso', 'sublime'],
        antonyms: ['feo', 'desagradable']),
    ThesaurusEntry(
        word: 'brillar',
        definition: 'Emitir o reflejar luz.',
        synonyms: ['relucir', 'fulgurar', 'resplandecer', 'destellar']),
    ThesaurusEntry(
        word: 'camino',
        definition: 'Via o curso que conduce a un destino.',
        synonyms: ['senda', 'ruta', 'trayecto', 'derrotero']),
    ThesaurusEntry(
        word: 'cambiar',
        definition: 'Hacer que algo pase a ser diferente.',
        synonyms: ['transformar', 'alterar', 'modificar', 'mutar']),
    ThesaurusEntry(
        word: 'casa',
        definition: 'Lugar destinado a ser habitado.',
        synonyms: ['hogar', 'vivienda', 'morada', 'residencia']),
    ThesaurusEntry(
        word: 'decir',
        definition: 'Expresar una idea mediante palabras.',
        synonyms: ['afirmar', 'declarar', 'mencionar', 'manifestar']),
    ThesaurusEntry(
        word: 'desafio',
        definition: 'Situacion dificil que exige capacidad o esfuerzo.',
        synonyms: ['reto', 'prueba', 'empresa', 'contienda']),
    ThesaurusEntry(
        word: 'dolor',
        definition: 'Sensacion penosa fisica o emocional.',
        synonyms: ['pena', 'afliccion', 'sufrimiento', 'pesar'],
        antonyms: ['alivio', 'bienestar']),
    ThesaurusEntry(
        word: 'enorme',
        definition: 'De tamano o intensidad extraordinarios.',
        synonyms: ['inmenso', 'colosal', 'vasto', 'descomunal'],
        antonyms: ['diminuto', 'reducido']),
    ThesaurusEntry(
        word: 'escuro',
        definition: 'Variante literaria poco usada de oscuro.',
        synonyms: ['oscuro', 'sombrio', 'tenebroso', 'opaco'],
        register: 'Literario'),
    ThesaurusEntry(
        word: 'fuerte',
        definition: 'Que posee resistencia, intensidad o vigor.',
        synonyms: ['robusto', 'vigoroso', 'intenso', 'solido'],
        antonyms: ['debil', 'fragil']),
    ThesaurusEntry(
        word: 'grande',
        definition: 'Que supera lo comun en tamano o importancia.',
        synonyms: ['amplio', 'vasto', 'notable', 'mayusculo'],
        antonyms: ['pequeno', 'menor']),
    ThesaurusEntry(
        word: 'hablar',
        definition: 'Comunicarse por medio de palabras.',
        synonyms: ['conversar', 'dialogar', 'expresar', 'pronunciar']),
    ThesaurusEntry(
        word: 'historia',
        definition: 'Relato de acontecimientos reales o imaginarios.',
        synonyms: ['relato', 'narracion', 'cronica', 'trama']),
    ThesaurusEntry(
        word: 'idea',
        definition: 'Representacion mental o propuesta creativa.',
        synonyms: ['concepto', 'nocion', 'ocurrencia', 'planteamiento']),
    ThesaurusEntry(
        word: 'lento',
        definition: 'Que se mueve o sucede con poca rapidez.',
        synonyms: ['pausado', 'moroso', 'calmo', 'gradual'],
        antonyms: ['rapido', 'veloz']),
    ThesaurusEntry(
        word: 'luz',
        definition: 'Agente que hace visibles los objetos.',
        synonyms: ['claridad', 'resplandor', 'fulgor', 'lumbre'],
        antonyms: ['oscuridad', 'sombra']),
    ThesaurusEntry(
        word: 'miedo',
        definition: 'Inquietud ante un peligro real o imaginado.',
        synonyms: ['temor', 'pavor', 'recelo', 'aprension'],
        antonyms: ['valor', 'serenidad']),
    ThesaurusEntry(
        word: 'mirar',
        definition: 'Dirigir la vista hacia algo.',
        synonyms: ['observar', 'contemplar', 'examinar', 'atisbar']),
    ThesaurusEntry(
        word: 'misterio',
        definition: 'Hecho cuya naturaleza no puede explicarse.',
        synonyms: ['enigma', 'secreto', 'incognita', 'arcano']),
    ThesaurusEntry(
        word: 'oscuro',
        definition: 'Que carece de luz o resulta dificil de comprender.',
        synonyms: ['sombrio', 'tenebroso', 'opaco', 'hermetico'],
        antonyms: ['claro', 'luminoso']),
    ThesaurusEntry(
        word: 'pensar',
        definition: 'Formar o relacionar ideas en la mente.',
        synonyms: ['reflexionar', 'considerar', 'meditar', 'imaginar']),
    ThesaurusEntry(
        word: 'pequeno',
        definition: 'De tamano inferior a lo habitual.',
        synonyms: ['diminuto', 'breve', 'reducido', 'menudo'],
        antonyms: ['grande', 'inmenso']),
    ThesaurusEntry(
        word: 'rapido',
        definition: 'Que se mueve o sucede con gran velocidad.',
        synonyms: ['veloz', 'agil', 'raudo', 'fulminante'],
        antonyms: ['lento', 'pausado']),
    ThesaurusEntry(
        word: 'recordar',
        definition: 'Traer algo pasado a la memoria.',
        synonyms: ['evocar', 'rememorar', 'remembrar', 'reconstruir']),
    ThesaurusEntry(
        word: 'silencio',
        definition: 'Ausencia de sonido o de palabras.',
        synonyms: ['quietud', 'mutismo', 'calma', 'sigilo']),
    ThesaurusEntry(
        word: 'triste',
        definition: 'Que siente o comunica pena.',
        synonyms: ['apenado', 'melancolico', 'afligido', 'sombrio'],
        antonyms: ['alegre', 'jovial']),
    ThesaurusEntry(
        word: 'ver',
        definition: 'Percibir algo por medio de la vista.',
        synonyms: ['observar', 'contemplar', 'advertir', 'distinguir']),
  ];

  List<ThesaurusEntry> searchThesaurus(String query) {
    final normalized = _normalize(query.trim());
    if (normalized.isEmpty) return entries.take(8).toList();
    final matches = entries.where((entry) {
      if (_normalize(entry.word).contains(normalized)) return true;
      return entry.synonyms
          .any((word) => _normalize(word).contains(normalized));
    }).toList();
    matches.sort((a, b) {
      final aExact = _normalize(a.word) == normalized ? 0 : 1;
      final bExact = _normalize(b.word) == normalized ? 0 : 1;
      return aExact != bExact
          ? aExact.compareTo(bExact)
          : a.word.compareTo(b.word);
    });
    return matches;
  }

  List<LanguageSuggestion> analyze(String text) {
    if (text.trim().isEmpty) return const [];
    final suggestions = <LanguageSuggestion>[];
    var sequence = 0;

    void add(
        {required LanguageSuggestionKind kind,
        required int offset,
        required int length,
        required String found,
        required String message,
        required List<String> replacements}) {
      suggestions.add(LanguageSuggestion(
        id: '${kind.name}-${sequence++}-$offset',
        kind: kind,
        offset: offset,
        length: length,
        found: found,
        message: message,
        replacements: replacements,
      ));
    }

    for (final match in RegExp(r' {2,}').allMatches(text)) {
      add(
          kind: LanguageSuggestionKind.typography,
          offset: match.start,
          length: match.end - match.start,
          found: match.group(0)!,
          message: 'Hay espacios consecutivos.',
          replacements: const [' ']);
    }
    for (final match in RegExp(r'\s+([,.;:!?])').allMatches(text)) {
      add(
          kind: LanguageSuggestionKind.typography,
          offset: match.start,
          length: match.end - match.start,
          found: match.group(0)!,
          message: 'No se deja espacio antes de este signo.',
          replacements: [match.group(1)!]);
    }
    for (final match
        in RegExp(r'([,.;:!?])([A-Za-zÁÉÍÓÚÜÑáéíóúüñ])').allMatches(text)) {
      final found = match.group(0)!;
      add(
          kind: LanguageSuggestionKind.typography,
          offset: match.start,
          length: found.length,
          found: found,
          message: 'Conviene dejar un espacio despues del signo.',
          replacements: ['${match.group(1)} ${match.group(2)}']);
    }

    final wordPattern = RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+');
    RegExpMatch? previous;
    for (final match in wordPattern.allMatches(text)) {
      final found = match.group(0)!;
      final normalized = _normalize(found);
      final previousMatch = previous;
      if (previousMatch != null &&
          _normalize(previousMatch.group(0)!) == normalized &&
          normalized.length > 2) {
        add(
            kind: LanguageSuggestionKind.repetition,
            offset: previousMatch.end,
            length: match.end - previousMatch.end,
            found: text.substring(previousMatch.end, match.end),
            message: 'La palabra "$found" aparece dos veces seguidas.',
            replacements: const ['']);
      }
      previous = match;

      final corrected = _accented[normalized];
      if (corrected != null && found.toLowerCase() != corrected) {
        add(
            kind: LanguageSuggestionKind.spelling,
            offset: match.start,
            length: found.length,
            found: found,
            message: 'Falta una tilde en "$found".',
            replacements: [_matchCase(found, corrected)]);
      }
    }

    for (final entry in const <String, String>{
      'a traves': 'a trav\u00e9s',
      'al rededor': 'alrededor',
      'depronto': 'de pronto',
      'enmedio': 'en medio',
      'osea': 'o sea',
      'porfavor': 'por favor',
      'sobretodo': 'sobre todo',
    }.entries) {
      for (final match in RegExp('\\b${entry.key}\\b', caseSensitive: false)
          .allMatches(text)) {
        add(
            kind: LanguageSuggestionKind.spelling,
            offset: match.start,
            length: match.end - match.start,
            found: match.group(0)!,
            message: 'Revisa la escritura de esta expresion.',
            replacements: [entry.value]);
      }
    }

    suggestions.sort((a, b) => a.offset.compareTo(b.offset));
    return suggestions;
  }

  String apply(String text, LanguageSuggestion suggestion, String replacement) {
    if (suggestion.offset < 0 ||
        suggestion.offset + suggestion.length > text.length) {
      return text;
    }
    return text.replaceRange(
        suggestion.offset, suggestion.offset + suggestion.length, replacement);
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[áàäâ]'), 'a')
      .replaceAll(RegExp('[éèëê]'), 'e')
      .replaceAll(RegExp('[íìïî]'), 'i')
      .replaceAll(RegExp('[óòöô]'), 'o')
      .replaceAll(RegExp('[úùüû]'), 'u');

  static String _matchCase(String source, String replacement) {
    if (source.isEmpty || replacement.isEmpty) return replacement;
    if (source.toUpperCase() == source) return replacement.toUpperCase();
    if (source[0].toUpperCase() == source[0]) {
      return replacement[0].toUpperCase() + replacement.substring(1);
    }
    return replacement;
  }
}
