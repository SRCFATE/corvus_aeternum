import '../../../../models/atelier_models.dart';

/// La obra vista como manuscrito, no como grafo de nodos.
///
/// Los exportadores no deberían saber qué es un `AtelierNode` ni cómo se
/// llaman las ramas creativas. Reciben esto: un título, una autoría, unos
/// capítulos en orden y —si hay producción editorial— las páginas de
/// cortesía. Así añadir un formato nuevo es escribir un generador, no volver
/// a entender el modelo del taller.
class ManuscriptDocument {
  final String title;
  final String author;
  final String synopsis;
  final String genre;
  final String language;
  final List<ManuscriptChapter> chapters;
  final ManuscriptFrontMatter frontMatter;

  const ManuscriptDocument({
    required this.title,
    required this.author,
    required this.synopsis,
    required this.genre,
    required this.language,
    required this.chapters,
    this.frontMatter = const ManuscriptFrontMatter(),
  });

  int get wordCount => chapters.fold(0, (sum, c) => sum + c.wordCount);

  /// Construye el manuscrito desde el taller.
  ///
  /// Solo entran los elementos con contenido: una exportación no debería
  /// llevar capítulos en blanco. El orden es el del taller, que es el que la
  /// autora decidió arrastrando.
  factory ManuscriptDocument.fromWorkspace(
    AtelierWorkspace workspace, {
    String author = '',
    ManuscriptFrontMatter frontMatter = const ManuscriptFrontMatter(),
  }) {
    final project = workspace.activeProject;
    if (project == null) {
      throw StateError('No hay proyecto activo que exportar.');
    }

    final nodes = workspace.nodes
        .where((node) => node.body.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    final synopsis = ((project.metadata['description'] as String?) ??
            (project.metadata['synopsis_short'] as String?) ??
            '')
        .trim();

    return ManuscriptDocument(
      title: project.title.trim().isEmpty ? 'Sin título' : project.title.trim(),
      author: author,
      synopsis: synopsis,
      genre: project.genre.trim(),
      language: project.language.trim().isEmpty ? 'es' : project.language.trim(),
      frontMatter: frontMatter,
      chapters: [
        for (final node in nodes)
          ManuscriptChapter(
            title: node.title.trim().isEmpty ? 'Sin título' : node.title.trim(),
            body: node.body.trim(),
          ),
      ],
    );
  }
}

class ManuscriptChapter {
  final String title;
  final String body;

  const ManuscriptChapter({required this.title, required this.body});

  int get wordCount =>
      body.trim().isEmpty ? 0 : RegExp(r'\S+').allMatches(body).length;

  /// El cuerpo partido en párrafos. Una línea en blanco separa; los saltos
  /// sueltos dentro de un párrafo se respetan como parte del mismo.
  List<String> get paragraphs => body
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
}

/// Las páginas de cortesía de un libro: lo que Professional llama producción
/// editorial. Vienen de `atelier_editorial_profiles` cuando existe; si no,
/// quedan vacías y los exportadores simplemente no las escriben.
class ManuscriptFrontMatter {
  final String copyrightNotice;
  final String dedication;
  final String acknowledgements;
  final String isbn;
  final String publisher;
  final bool includeTableOfContents;

  const ManuscriptFrontMatter({
    this.copyrightNotice = '',
    this.dedication = '',
    this.acknowledgements = '',
    this.isbn = '',
    this.publisher = '',
    this.includeTableOfContents = true,
  });

  bool get isEmpty =>
      copyrightNotice.isEmpty &&
      dedication.isEmpty &&
      acknowledgements.isEmpty &&
      isbn.isEmpty &&
      publisher.isEmpty;

  factory ManuscriptFrontMatter.fromMap(Map<String, dynamic> map) {
    final front = map['front_matter'];
    final frontMap = front is Map
        ? Map<String, dynamic>.from(front)
        : const <String, dynamic>{};

    return ManuscriptFrontMatter(
      copyrightNotice: (map['copyright_notice'] as String? ?? '').trim(),
      dedication: (map['dedication'] as String? ?? '').trim(),
      acknowledgements: (map['acknowledgements'] as String? ?? '').trim(),
      isbn: (map['isbn'] as String? ?? '').trim(),
      publisher: (frontMap['publisher'] as String? ?? '').trim(),
      includeTableOfContents: frontMap['table_of_contents'] as bool? ?? true,
    );
  }
}
