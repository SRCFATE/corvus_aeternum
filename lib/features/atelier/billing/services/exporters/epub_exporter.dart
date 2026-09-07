import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../domain/manuscript.dart';
import 'xml_text.dart';

/// Genera un EPUB 3 válido.
///
/// Dos detalles del formato que no se pueden saltar, y que son la razón de que
/// esto no sea «un ZIP con HTML dentro»:
///
///   1. `mimetype` tiene que ser la PRIMERA entrada del ZIP y estar guardada
///      SIN comprimir. Un lector de libros identifica el archivo leyendo esos
///      bytes en una posición fija; comprimirlo lo hace ilegible.
///   2. EPUB 3 exige un documento de navegación (`nav.xhtml`) con
///      `epub:type="toc"`. Sin él, el índice del lector queda vacío.
class EpubExporter {
  Uint8List build(ManuscriptDocument doc) {
    final uuid = _identificador(doc);
    final capitulos = <_Capitulo>[
      for (var i = 0; i < doc.chapters.length; i++)
        _Capitulo(
          indice: i + 1,
          archivo: 'cap-${(i + 1).toString().padLeft(3, '0')}.xhtml',
          capitulo: doc.chapters[i],
        ),
    ];

    final archive = Archive();

    // El mimetype va primero y sin comprimir. No es superstición: es la única
    // forma de que un lector reconozca el archivo.
    final mimetype = ArchiveFile.string('mimetype', 'application/epub+zip')
      ..compression = CompressionType.none;
    archive.addFile(mimetype);

    archive
      ..addFile(_file('META-INF/container.xml', _container()))
      ..addFile(_file('OEBPS/style.css', _css()))
      ..addFile(_file('OEBPS/content.opf', _opf(doc, capitulos, uuid)))
      ..addFile(_file('OEBPS/nav.xhtml', _nav(doc, capitulos)))
      ..addFile(_file('OEBPS/portada.xhtml', _portada(doc)));

    if (!doc.frontMatter.isEmpty) {
      archive.addFile(_file('OEBPS/cortesia.xhtml', _cortesia(doc)));
    }

    for (final entrada in capitulos) {
      archive.addFile(
        _file('OEBPS/${entrada.archivo}', _capitulo(doc, entrada)),
      );
    }

    return ZipEncoder().encodeBytes(archive);
  }

  ArchiveFile _file(String name, String content) {
    final bytes = utf8.encode(content);
    return ArchiveFile(name, bytes.length, bytes);
  }

  /// Un libro necesita un identificador estable. Se deriva del título y de la
  /// autoría para que reexportar la misma obra no cree un libro «distinto» en
  /// la biblioteca de quien lo lee.
  String _identificador(ManuscriptDocument doc) {
    final semilla = '${doc.title}|${doc.author}'.hashCode.toUnsigned(32);
    return 'urn:uuid:corvus-${semilla.toRadixString(16).padLeft(8, '0')}'
        '-${doc.chapters.length.toString().padLeft(4, '0')}';
  }

  String _container() => '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';

  String _css() => '''@charset "utf-8";

body {
  margin: 0 5%;
  line-height: 1.5;
  text-align: justify;
  hyphens: auto;
}

h1 {
  text-align: center;
  page-break-before: always;
  margin: 3em 0 1.5em;
  font-size: 1.3em;
  font-weight: bold;
}

p { margin: 0; text-indent: 1.5em; }

/* Primer parrafo de un capitulo: sin sangria, como manda la tipografia. */
p.inicio { text-indent: 0; }

p.cortesia { text-align: center; text-indent: 0; font-style: italic; margin: 1em 0; }

.portada { text-align: center; margin-top: 25%; }
.portada h1 { page-break-before: auto; margin: 0 0 0.5em; font-size: 2em; }
.portada .autoria { font-size: 1.1em; margin-bottom: 2em; }
.portada .dato { color: #555; font-size: 0.9em; }''';

  String _opf(
    ManuscriptDocument doc,
    List<_Capitulo> capitulos,
    String uuid,
  ) {
    final manifest = StringBuffer()
      ..write('<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>')
      ..write('<item id="css" href="style.css" media-type="text/css"/>')
      ..write('<item id="portada" href="portada.xhtml" media-type="application/xhtml+xml"/>');

    final spine = StringBuffer()..write('<itemref idref="portada"/>');

    if (!doc.frontMatter.isEmpty) {
      manifest.write(
        '<item id="cortesia" href="cortesia.xhtml" media-type="application/xhtml+xml"/>',
      );
      spine.write('<itemref idref="cortesia"/>');
    }

    spine.write('<itemref idref="nav"/>');

    for (final entrada in capitulos) {
      manifest.write(
        '<item id="cap${entrada.indice}" href="${entrada.archivo}" '
        'media-type="application/xhtml+xml"/>',
      );
      spine.write('<itemref idref="cap${entrada.indice}"/>');
    }

    return '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="libro-id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="libro-id">$uuid</dc:identifier>
    <dc:title>${escapeXml(doc.title)}</dc:title>
    <dc:language>${escapeXml(doc.language)}</dc:language>
    <dc:creator>${escapeXml(doc.author.isEmpty ? 'Autoría reservada' : doc.author)}</dc:creator>
    ${doc.synopsis.isEmpty ? '' : '<dc:description>${escapeXml(doc.synopsis)}</dc:description>'}
    ${doc.genre.isEmpty ? '' : '<dc:subject>${escapeXml(doc.genre)}</dc:subject>'}
    ${doc.frontMatter.publisher.isEmpty ? '' : '<dc:publisher>${escapeXml(doc.frontMatter.publisher)}</dc:publisher>'}
    ${doc.frontMatter.isbn.isEmpty ? '' : '<dc:identifier>urn:isbn:${escapeXml(doc.frontMatter.isbn)}</dc:identifier>'}
    <meta property="dcterms:modified">${DateTime.now().toUtc().toIso8601String().split('.').first}Z</meta>
  </metadata>
  <manifest>$manifest</manifest>
  <spine>$spine</spine>
</package>''';
  }

  String _nav(ManuscriptDocument doc, List<_Capitulo> capitulos) {
    final items = capitulos
        .map((e) =>
            '<li><a href="${e.archivo}">${escapeXml(e.capitulo.title)}</a></li>')
        .join();

    return _xhtml(
      doc,
      'Índice',
      '''<nav epub:type="toc" id="toc">
  <h1>Índice</h1>
  <ol>$items</ol>
</nav>''',
      conEpubNamespace: true,
    );
  }

  String _portada(ManuscriptDocument doc) {
    final cuerpo = StringBuffer()
      ..write('<div class="portada">')
      ..write('<h1>${escapeXml(doc.title)}</h1>');

    if (doc.author.isNotEmpty) {
      cuerpo.write('<p class="autoria">${escapeXml(doc.author)}</p>');
    }
    if (doc.genre.isNotEmpty) {
      cuerpo.write('<p class="dato">${escapeXml(doc.genre)}</p>');
    }
    cuerpo
      ..write('<p class="dato">${doc.wordCount} palabras</p>')
      ..write('</div>');

    return _xhtml(doc, doc.title, cuerpo.toString());
  }

  String _cortesia(ManuscriptDocument doc) {
    final front = doc.frontMatter;
    final cuerpo = StringBuffer();

    if (front.copyrightNotice.isNotEmpty) {
      for (final linea in front.copyrightNotice.split('\n')) {
        cuerpo.write('<p class="cortesia">${escapeXml(linea)}</p>');
      }
    }
    if (front.isbn.isNotEmpty) {
      cuerpo.write('<p class="cortesia">ISBN: ${escapeXml(front.isbn)}</p>');
    }
    if (front.dedication.isNotEmpty) {
      cuerpo.write('<p class="cortesia">${escapeXml(front.dedication)}</p>');
    }

    return _xhtml(doc, 'Créditos', cuerpo.toString());
  }

  String _capitulo(ManuscriptDocument doc, _Capitulo entrada) {
    final cuerpo = StringBuffer()
      ..write('<h1>${escapeXml(entrada.capitulo.title)}</h1>');

    final parrafos = entrada.capitulo.paragraphs;
    for (var i = 0; i < parrafos.length; i++) {
      final clase = i == 0 ? ' class="inicio"' : '';
      final texto = escapeXml(parrafos[i]).replaceAll('\n', '<br/>');
      cuerpo.write('<p$clase>$texto</p>');
    }

    return _xhtml(doc, entrada.capitulo.title, cuerpo.toString());
  }

  String _xhtml(
    ManuscriptDocument doc,
    String titulo,
    String cuerpo, {
    bool conEpubNamespace = false,
  }) {
    final epubNs = conEpubNamespace
        ? ' xmlns:epub="http://www.idpf.org/2007/ops"'
        : '';

    return '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml"$epubNs xml:lang="${escapeXml(doc.language)}">
<head>
  <meta charset="utf-8"/>
  <title>${escapeXml(titulo)}</title>
  <link rel="stylesheet" type="text/css" href="style.css"/>
</head>
<body>
$cuerpo
</body>
</html>''';
  }
}

class _Capitulo {
  final int indice;
  final String archivo;
  final ManuscriptChapter capitulo;

  const _Capitulo({
    required this.indice,
    required this.archivo,
    required this.capitulo,
  });
}
