import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../domain/manuscript.dart';
import 'xml_text.dart';

/// Genera un DOCX de verdad, no un HTML renombrado.
///
/// Un `.docx` es un ZIP con OOXML dentro. Se escriben las cinco partes que
/// Word exige —tipos de contenido, relaciones, documento, estilos y
/// propiedades— y el resultado abre en Word, LibreOffice y Google Docs.
///
/// El formato es el del manuscrito profesional, que no es una elección
/// estética: Times New Roman de 12, doble espacio, márgenes de una pulgada y
/// sangría de primera línea es lo que una editorial espera recibir, y lo que
/// permite estimar páginas de un vistazo.
class DocxExporter {
  static const _twipsPulgada = 1440;

  Uint8List build(ManuscriptDocument doc) {
    final archive = Archive()
      ..addFile(_file('[Content_Types].xml', _contentTypes()))
      ..addFile(_file('_rels/.rels', _packageRels()))
      ..addFile(_file('docProps/core.xml', _coreProperties(doc)))
      ..addFile(_file('word/_rels/document.xml.rels', _documentRels()))
      ..addFile(_file('word/styles.xml', _styles()))
      ..addFile(_file('word/document.xml', _document(doc)));

    return ZipEncoder().encodeBytes(archive);
  }

  ArchiveFile _file(String name, String content) {
    final bytes = utf8.encode(content);
    return ArchiveFile(name, bytes.length, bytes);
  }

  String _contentTypes() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
</Types>''';

  String _packageRels() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
</Relationships>''';

  String _documentRels() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';

  String _coreProperties(ManuscriptDocument doc) {
    final ahora = DateTime.now().toUtc().toIso8601String();
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties
  xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:dcterms="http://purl.org/dc/terms/"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>${escapeXml(doc.title)}</dc:title>
  <dc:creator>${escapeXml(doc.author)}</dc:creator>
  <cp:lastModifiedBy>Corvus Atelier</cp:lastModifiedBy>
  <dc:description>${escapeXml(doc.synopsis)}</dc:description>
  <dc:language>${escapeXml(doc.language)}</dc:language>
  <dcterms:created xsi:type="dcterms:W3CDTF">$ahora</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">$ahora</dcterms:modified>
</cp:coreProperties>''';
  }

  /// Doble espacio es `w:line="480"` (240 twips = una línea sencilla).
  String _styles() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman"/>
        <w:sz w:val="24"/>
        <w:szCs w:val="24"/>
      </w:rPr>
    </w:rPrDefault>
    <w:pPrDefault>
      <w:pPr><w:spacing w:line="480" w:lineRule="auto" w:after="0"/></w:pPr>
    </w:pPrDefault>
  </w:docDefaults>
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:pPr>
      <w:spacing w:line="480" w:lineRule="auto" w:after="0"/>
      <w:ind w:firstLine="720"/>
    </w:pPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Sinsangria">
    <w:name w:val="Sin sangria"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr><w:ind w:firstLine="0"/></w:pPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Titulo">
    <w:name w:val="Title"/>
    <w:pPr>
      <w:jc w:val="center"/>
      <w:spacing w:line="480" w:lineRule="auto" w:before="2400" w:after="480"/>
    </w:pPr>
    <w:rPr><w:b/><w:sz w:val="36"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Capitulo">
    <w:name w:val="heading 1"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr>
      <w:jc w:val="center"/>
      <w:ind w:firstLine="0"/>
      <w:spacing w:line="480" w:lineRule="auto" w:before="1440" w:after="480"/>
      <w:outlineLvl w:val="0"/>
    </w:pPr>
    <w:rPr><w:b/><w:sz w:val="28"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Cortesia">
    <w:name w:val="Cortesia"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr><w:jc w:val="center"/><w:ind w:firstLine="0"/></w:pPr>
    <w:rPr><w:i/></w:rPr>
  </w:style>
</w:styles>''';

  String _document(ManuscriptDocument doc) {
    final buffer = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<w:document xmlns:w="http://schemas.openxmlformats.org/'
          'wordprocessingml/2006/main"><w:body>');

    // Portadilla.
    buffer.write(_parrafo(doc.title, estilo: 'Titulo'));
    if (doc.author.isNotEmpty) {
      buffer.write(_parrafo(doc.author, estilo: 'Cortesia'));
    }
    if (doc.genre.isNotEmpty) {
      buffer.write(_parrafo(doc.genre, estilo: 'Cortesia'));
    }
    buffer.write(_parrafo(
      '${doc.wordCount} palabras',
      estilo: 'Cortesia',
    ));

    // Páginas de cortesía, solo si producción editorial las llenó.
    final front = doc.frontMatter;
    if (!front.isEmpty) {
      if (front.copyrightNotice.isNotEmpty) {
        buffer.write(_saltoDePagina());
        for (final linea in front.copyrightNotice.split('\n')) {
          buffer.write(_parrafo(linea, estilo: 'Sinsangria'));
        }
        if (front.isbn.isNotEmpty) {
          buffer.write(_parrafo('ISBN: ${front.isbn}', estilo: 'Sinsangria'));
        }
        if (front.publisher.isNotEmpty) {
          buffer.write(_parrafo(front.publisher, estilo: 'Sinsangria'));
        }
      }
      if (front.dedication.isNotEmpty) {
        buffer.write(_saltoDePagina());
        buffer.write(_parrafo(front.dedication, estilo: 'Cortesia'));
      }
    }

    for (final capitulo in doc.chapters) {
      buffer.write(_saltoDePagina());
      buffer.write(_parrafo(capitulo.title, estilo: 'Capitulo'));

      final parrafos = capitulo.paragraphs;
      for (var i = 0; i < parrafos.length; i++) {
        // El primer párrafo de un capítulo no lleva sangría: es la convención
        // tipográfica, y saltársela delata un manuscrito hecho a mano.
        buffer.write(_parrafo(
          parrafos[i],
          estilo: i == 0 ? 'Sinsangria' : 'Normal',
        ));
      }
    }

    if (doc.frontMatter.acknowledgements.isNotEmpty) {
      buffer.write(_saltoDePagina());
      buffer.write(_parrafo('Agradecimientos', estilo: 'Capitulo'));
      buffer.write(
        _parrafo(doc.frontMatter.acknowledgements, estilo: 'Sinsangria'),
      );
    }

    buffer
      ..write(_seccion())
      ..write('</w:body></w:document>');

    return buffer.toString();
  }

  String _parrafo(String texto, {required String estilo}) {
    // Los saltos de línea sueltos dentro de un párrafo se conservan: en
    // poesía y en diálogo teatral son parte del texto, no un descuido.
    final lineas = texto.split('\n');
    final runs = StringBuffer();

    for (var i = 0; i < lineas.length; i++) {
      if (i > 0) runs.write('<w:br/>');
      runs.write(
        '<w:t xml:space="preserve">${escapeXml(lineas[i])}</w:t>',
      );
    }

    return '<w:p><w:pPr><w:pStyle w:val="$estilo"/></w:pPr>'
        '<w:r>$runs</w:r></w:p>';
  }

  String _saltoDePagina() =>
      '<w:p><w:r><w:br w:type="page"/></w:r></w:p>';

  String _seccion() => '<w:sectPr>'
      '<w:pgSz w:w="12240" w:h="15840"/>'
      '<w:pgMar w:top="$_twipsPulgada" w:right="$_twipsPulgada" '
      'w:bottom="$_twipsPulgada" w:left="$_twipsPulgada" '
      'w:header="720" w:footer="720" w:gutter="0"/>'
      '</w:sectPr>';
}
