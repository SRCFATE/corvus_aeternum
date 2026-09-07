import 'dart:convert';
import 'dart:typed_data';

import '../../../../models/atelier_models.dart';
import '../domain/feature_keys.dart';
import '../domain/manuscript.dart';
import 'exporters/bundle_exporter.dart';
import 'exporters/docx_exporter.dart';
import 'exporters/epub_exporter.dart';
import 'exporters/pdf_exporter.dart';
import 'exporters/xml_text.dart';

/// El sistema de exportación de Atelier.
///
/// Modular a propósito: cada formato es una entrada de este registro con su
/// derecho asociado y su generador. Añadir uno nuevo es escribir una función y
/// una fila, sin tocar la pantalla ni la lógica de permisos.
///
/// La regla que ordena la lista: **Markdown, TXT y JSON no se cobran jamás**.
/// Son la garantía de portabilidad —el derecho de cualquiera a llevarse su obra
/// de Corvus— y por eso su `featureKey` apunta a derechos que todos los planes
/// conceden y `EntitlementService.isProtected` los blinda.
enum AtelierExportFormat {
  markdown,
  txt,
  json,
  docx,
  pdf,
  epub,
  bundle,
}

class AtelierExportSpec {
  final AtelierExportFormat format;
  final String label;
  final String description;
  final String extension;
  final String mimeType;
  final String featureKey;

  /// Si el resultado se puede copiar al portapapeles. Un DOCX o un PDF son
  /// binarios: copiarlos no significaría nada.
  final bool isText;

  const AtelierExportSpec({
    required this.format,
    required this.label,
    required this.description,
    required this.extension,
    required this.mimeType,
    required this.featureKey,
    this.isText = false,
  });
}

const atelierExportFormats = <AtelierExportSpec>[
  AtelierExportSpec(
    format: AtelierExportFormat.markdown,
    label: 'Markdown',
    description: 'El manuscrito completo con sus encabezados. Siempre gratis.',
    extension: 'md',
    mimeType: 'text/markdown',
    featureKey: AtelierFeature.exportMarkdown,
    isText: true,
  ),
  AtelierExportSpec(
    format: AtelierExportFormat.txt,
    label: 'Texto plano',
    description: 'Solo el texto, sin marcas. Siempre gratis.',
    extension: 'txt',
    mimeType: 'text/plain',
    featureKey: AtelierFeature.exportTxt,
    isText: true,
  ),
  AtelierExportSpec(
    format: AtelierExportFormat.json,
    label: 'JSON estructurado',
    description:
        'Proyecto, elementos, relaciones y versiones. Siempre gratis: tus datos son tuyos.',
    extension: 'json',
    mimeType: 'application/json',
    featureKey: AtelierFeature.exportJson,
    isText: true,
  ),
  AtelierExportSpec(
    format: AtelierExportFormat.docx,
    label: 'DOCX',
    description:
        'Manuscrito con formato editorial: Times de 12, doble espacio y márgenes de una pulgada.',
    extension: 'docx',
    mimeType:
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    featureKey: AtelierFeature.exportDocx,
  ),
  AtelierExportSpec(
    format: AtelierExportFormat.pdf,
    label: 'PDF',
    description: 'Maquetado, numerado y listo para leer o enviar.',
    extension: 'pdf',
    mimeType: 'application/pdf',
    featureKey: AtelierFeature.exportPdf,
  ),
  AtelierExportSpec(
    format: AtelierExportFormat.epub,
    label: 'EPUB',
    description: 'Libro electrónico con índice, portada y metadatos.',
    extension: 'epub',
    mimeType: 'application/epub+zip',
    featureKey: AtelierFeature.exportEpub,
  ),
  AtelierExportSpec(
    format: AtelierExportFormat.bundle,
    label: 'Paquete completo',
    description:
        'ZIP con el manuscrito, un archivo por capítulo, las fichas del mundo y el volcado JSON.',
    extension: 'zip',
    mimeType: 'application/zip',
    featureKey: AtelierFeature.exportProjectBundle,
  ),
];

class AtelierExportResult {
  final String filename;
  final String mimeType;
  final Uint8List bytes;

  /// El contenido como texto cuando el formato lo permite, para poder copiarlo
  /// donde no hay descarga. Null en los binarios.
  final String? text;

  const AtelierExportResult({
    required this.filename,
    required this.mimeType,
    required this.bytes,
    this.text,
  });
}

class AtelierExportService {
  final _docx = DocxExporter();
  final _epub = EpubExporter();
  final _pdf = PdfExporter();
  final _bundle = BundleExporter();

  static AtelierExportSpec specFor(AtelierExportFormat format) =>
      atelierExportFormats.firstWhere((spec) => spec.format == format);

  /// Genera el archivo. Es asíncrona porque maquetar un PDF lo es; los demás
  /// formatos resuelven en el acto.
  Future<AtelierExportResult> build({
    required AtelierExportFormat format,
    required AtelierWorkspace workspace,
    String author = '',
    ManuscriptFrontMatter frontMatter = const ManuscriptFrontMatter(),
  }) async {
    final project = workspace.activeProject;
    if (project == null) {
      throw StateError('No hay proyecto activo que exportar.');
    }

    final spec = specFor(format);
    final doc = ManuscriptDocument.fromWorkspace(
      workspace,
      author: author,
      frontMatter: frontMatter,
    );

    final filename = '${slugify(project.title)}.${spec.extension}';

    switch (format) {
      case AtelierExportFormat.markdown:
        return _deTexto(filename, spec, _markdown(doc));

      case AtelierExportFormat.txt:
        return _deTexto(filename, spec, _plainText(doc));

      case AtelierExportFormat.json:
        return _deTexto(filename, spec, _json(project, workspace));

      case AtelierExportFormat.docx:
        return AtelierExportResult(
          filename: filename,
          mimeType: spec.mimeType,
          bytes: _docx.build(doc),
        );

      case AtelierExportFormat.epub:
        return AtelierExportResult(
          filename: filename,
          mimeType: spec.mimeType,
          bytes: _epub.build(doc),
        );

      case AtelierExportFormat.pdf:
        return AtelierExportResult(
          filename: filename,
          mimeType: spec.mimeType,
          bytes: await _pdf.build(doc),
        );

      case AtelierExportFormat.bundle:
        return AtelierExportResult(
          filename: filename,
          mimeType: spec.mimeType,
          bytes: _bundle.build(
            doc: doc,
            workspace: workspace,
            markdown: _markdown(doc),
            plainText: _plainText(doc),
            json: _json(project, workspace),
          ),
        );
    }
  }

  AtelierExportResult _deTexto(
    String filename,
    AtelierExportSpec spec,
    String contenido,
  ) {
    return AtelierExportResult(
      filename: filename,
      mimeType: spec.mimeType,
      bytes: Uint8List.fromList(utf8.encode(contenido)),
      text: contenido,
    );
  }

  String _markdown(ManuscriptDocument doc) {
    final buffer = StringBuffer()
      ..writeln('# ${doc.title}')
      ..writeln();

    if (doc.author.isNotEmpty) {
      buffer
        ..writeln('*${doc.author}*')
        ..writeln();
    }
    if (doc.synopsis.isNotEmpty) {
      buffer
        ..writeln('> ${doc.synopsis}')
        ..writeln();
    }
    if (doc.genre.isNotEmpty) {
      buffer
        ..writeln('*${doc.genre}*')
        ..writeln();
    }

    for (final capitulo in doc.chapters) {
      buffer
        ..writeln('## ${capitulo.title}')
        ..writeln()
        ..writeln(capitulo.body)
        ..writeln();
    }

    return buffer.toString();
  }

  String _plainText(ManuscriptDocument doc) {
    final buffer = StringBuffer()
      ..writeln(doc.title.toUpperCase())
      ..writeln();

    if (doc.author.isNotEmpty) {
      buffer
        ..writeln(doc.author)
        ..writeln();
    }

    for (final capitulo in doc.chapters) {
      buffer
        ..writeln(capitulo.title)
        ..writeln()
        // El cuerpo puede llevar wikilinks y marcas: en texto plano estorban.
        ..writeln(_stripMarkup(capitulo.body))
        ..writeln();
    }

    return buffer.toString();
  }

  String _json(AtelierProject project, AtelierWorkspace workspace) {
    return const JsonEncoder.withIndent('  ').convert(
      project.toExportMap(
        nodes: workspace.nodes,
        relations: workspace.relations,
        versions: workspace.versions,
      ),
    );
  }

  String _stripMarkup(String body) {
    return body
        .replaceAllMapped(RegExp(r'\[\[([^\]]+)\]\]'), (m) => m.group(1)!)
        .replaceAll(RegExp(r'[*_`#>]'), '');
  }
}
