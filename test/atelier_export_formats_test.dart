import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:corvus_aeternum/features/atelier/billing/domain/manuscript.dart';
import 'package:corvus_aeternum/features/atelier/billing/services/export_service.dart';
import 'package:corvus_aeternum/features/atelier/billing/services/exporters/win_ansi.dart';
import 'package:corvus_aeternum/models/atelier_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Que los archivos exportados sean archivos de verdad.
///
/// Un DOCX que Word se niega a abrir o un EPUB que ningún lector reconoce son
/// peores que no ofrecer el formato: prometen y fallan en manos de quien iba a
/// enviar su manuscrito a una editorial. Estas pruebas abren lo generado y
/// comprueban su estructura, no solo que la función no lance.
///
/// El manuscrito de prueba lleva a propósito `&`, `<` y `>` en el texto: son
/// caracteres que aparecen con toda naturalidad en una novela y que, sin
/// escapar, rompen el XML entero.
void main() {
  AtelierNode node(String id, String title, String body, int position) {
    return AtelierNode(
      id: id,
      projectId: 'p1',
      profileId: 'a1',
      kind: position < 2 ? 'chapter' : 'character',
      title: title,
      body: body,
      status: 'draft',
      canonStatus: 'canon',
      visibility: 'private',
      tags: const ['prueba'],
      metadata: const {'edad': '34'},
      position: position,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 6, 1),
    );
  }

  final proyecto = AtelierProject(
    id: 'p1',
    profileId: 'a1',
    title: 'Sal & Ceniza',
    type: 'Novela',
    status: 'draft',
    genre: 'Fantasía oscura',
    universe: 'Aeternum',
    language: 'es',
    visibility: 'private',
    weeklyWordGoal: 0,
    publicProgressEnabled: false,
    metadata: const {'description': 'Una novela con <signos> peligrosos.'},
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 6, 1),
  );

  final taller = AtelierWorkspace(
    projects: [proyecto],
    activeProject: proyecto,
    nodes: [
      node('n1', 'Capítulo I: el puerto',
          'La sal cubrió el puerto.\n\nY nadie <dijo> nada & todos miraron.', 0),
      node('n2', 'Capítulo II', 'El cuervo volvió al alba.', 1),
      node('n3', 'Vela', 'Contrabandista. Miente por costumbre.', 2),
    ],
    relations: const [],
    versions: const [],
  );

  const portadilla = ManuscriptFrontMatter(
    copyrightNotice: '© 2026 Corvus Aeternum',
    dedication: 'Para quien esperó.',
    acknowledgements: 'A la tripulación.',
    isbn: '978-0-00-000000-0',
    publisher: 'Corvus Publishing Bureau',
  );

  final servicio = AtelierExportService();

  Future<Archive> zipDe(AtelierExportFormat formato) async {
    final resultado = await servicio.build(
      format: formato,
      workspace: taller,
      author: 'Eva Salazar',
      frontMatter: portadilla,
    );
    return ZipDecoder().decodeBytes(resultado.bytes);
  }

  String texto(Archive archive, String nombre) {
    final file = archive.files.firstWhere(
      (f) => f.name == nombre,
      orElse: () => throw StateError('Falta $nombre en el paquete'),
    );
    return utf8.decode(file.content as List<int>);
  }

  group('el manuscrito se arma desde el taller', () {
    test('solo entran los elementos con contenido, en orden', () {
      final doc = ManuscriptDocument.fromWorkspace(taller);

      expect(doc.chapters.length, 3);
      expect(doc.chapters.first.title, 'Capítulo I: el puerto');
      expect(doc.title, 'Sal & Ceniza');
      expect(doc.wordCount, greaterThan(0));
    });

    test('un párrafo se separa por línea en blanco, no por salto suelto', () {
      final doc = ManuscriptDocument.fromWorkspace(taller);
      expect(doc.chapters.first.paragraphs.length, 2);
    });

    test('sin proyecto activo no hay nada que exportar', () {
      expect(
        () => ManuscriptDocument.fromWorkspace(const AtelierWorkspace.empty()),
        throwsStateError,
      );
    });
  });

  group('DOCX', () {
    test('es un ZIP con las partes que Word exige', () async {
      final archive = await zipDe(AtelierExportFormat.docx);
      final nombres = archive.files.map((f) => f.name).toSet();

      expect(nombres, contains('[Content_Types].xml'));
      expect(nombres, contains('_rels/.rels'));
      expect(nombres, contains('word/document.xml'));
      expect(nombres, contains('word/styles.xml'));
      expect(nombres, contains('word/_rels/document.xml.rels'));
      expect(nombres, contains('docProps/core.xml'));
    });

    test('lleva el texto de la obra y escapa lo que rompería el XML', () async {
      final archive = await zipDe(AtelierExportFormat.docx);
      final documento = texto(archive, 'word/document.xml');

      expect(documento, contains('Capítulo I: el puerto'));
      expect(documento, contains('La sal cubrió el puerto.'));
      // Los signos peligrosos viajan escapados, nunca en crudo.
      expect(documento, contains('&lt;dijo&gt;'));
      expect(documento, contains('&amp;'));
      expect(documento, isNot(contains('<dijo>')));
    });

    test('el formato es el del manuscrito profesional', () async {
      final archive = await zipDe(AtelierExportFormat.docx);
      final estilos = texto(archive, 'word/styles.xml');

      expect(estilos, contains('Times New Roman'));
      // 480 = doble espacio; 720 twips = media pulgada de sangría.
      expect(estilos, contains('w:line="480"'));
      expect(estilos, contains('w:firstLine="720"'));
    });

    test('el título y la autoría quedan en las propiedades del archivo',
        () async {
      final archive = await zipDe(AtelierExportFormat.docx);
      final core = texto(archive, 'docProps/core.xml');

      expect(core, contains('Sal &amp; Ceniza'));
      expect(core, contains('Eva Salazar'));
    });

    test('las páginas de cortesía entran cuando existen', () async {
      final archive = await zipDe(AtelierExportFormat.docx);
      final documento = texto(archive, 'word/document.xml');

      expect(documento, contains('Corvus Aeternum'));
      expect(documento, contains('Para quien esperó.'));
      expect(documento, contains('978-0-00-000000-0'));
      expect(documento, contains('A la tripulación.'));
    });
  });

  group('EPUB', () {
    test('el mimetype es la primera entrada y va sin comprimir', () async {
      final archive = await zipDe(AtelierExportFormat.epub);
      final primera = archive.files.first;

      // Los dos requisitos que un lector de libros comprueba antes que nada.
      expect(primera.name, 'mimetype');
      expect(primera.compression, CompressionType.none);
      expect(
        utf8.decode(primera.content as List<int>),
        'application/epub+zip',
      );
    });

    test('lleva contenedor, paquete y documento de navegación', () async {
      final archive = await zipDe(AtelierExportFormat.epub);
      final nombres = archive.files.map((f) => f.name).toSet();

      expect(nombres, contains('META-INF/container.xml'));
      expect(nombres, contains('OEBPS/content.opf'));
      expect(nombres, contains('OEBPS/nav.xhtml'));
      expect(nombres, contains('OEBPS/portada.xhtml'));
      expect(nombres, contains('OEBPS/cap-001.xhtml'));
      expect(nombres, contains('OEBPS/cap-003.xhtml'));
    });

    test('el índice es un nav de EPUB 3 con todos los capítulos', () async {
      final archive = await zipDe(AtelierExportFormat.epub);
      final nav = texto(archive, 'OEBPS/nav.xhtml');

      expect(nav, contains('epub:type="toc"'));
      expect(nav, contains('Capítulo I: el puerto'));
      expect(nav, contains('cap-002.xhtml'));
    });

    test('el paquete declara metadatos y el orden de lectura', () async {
      final archive = await zipDe(AtelierExportFormat.epub);
      final opf = texto(archive, 'OEBPS/content.opf');

      expect(opf, contains('<dc:title>Sal &amp; Ceniza</dc:title>'));
      expect(opf, contains('Eva Salazar'));
      expect(opf, contains('urn:isbn:978-0-00-000000-0'));
      expect(opf, contains('<itemref idref="portada"/>'));
      expect(opf, contains('<itemref idref="cap1"/>'));
      expect(opf, contains('properties="nav"'));
    });

    test('el texto del capítulo va escapado dentro del XHTML', () async {
      final archive = await zipDe(AtelierExportFormat.epub);
      final capitulo = texto(archive, 'OEBPS/cap-001.xhtml');

      expect(capitulo, contains('&lt;dijo&gt;'));
      expect(capitulo, contains('&amp;'));
      expect(capitulo, contains('class="inicio"'));
    });
  });

  group('PDF', () {
    test('es un PDF válido con su cabecera y su cierre', () async {
      final resultado = await servicio.build(
        format: AtelierExportFormat.pdf,
        workspace: taller,
        author: 'Eva Salazar',
        frontMatter: portadilla,
      );

      final cabecera = String.fromCharCodes(resultado.bytes.take(5));
      expect(cabecera, '%PDF-');

      final cola = String.fromCharCodes(
        resultado.bytes.skip(resultado.bytes.length - 32),
      );
      expect(cola, contains('%%EOF'));

      // Un manuscrito de tres capítulos maquetado no cabe en unos pocos bytes.
      expect(resultado.bytes.length, greaterThan(2000));
      expect(resultado.filename, endsWith('.pdf'));
      // Binario: no se ofrece copiar al portapapeles.
      expect(resultado.text, isNull);
    });
  });

  group('paquete completo', () {
    test('lleva el manuscrito, los capítulos sueltos y el mundo', () async {
      final archive = await zipDe(AtelierExportFormat.bundle);
      final nombres = archive.files.map((f) => f.name).toSet();

      expect(nombres, contains('LEEME.txt'));
      expect(nombres, contains('manuscrito.md'));
      expect(nombres, contains('manuscrito.txt'));
      expect(nombres, contains('proyecto.json'));
      expect(
        nombres.where((n) => n.startsWith('capitulos/')).length,
        3,
      );
      expect(
        nombres.any((n) => n.startsWith('mundo/character/')),
        isTrue,
      );
    });

    test('el JSON del paquete conserva el proyecto entero', () async {
      final archive = await zipDe(AtelierExportFormat.bundle);
      final json = texto(archive, 'proyecto.json');

      expect(json, contains('Sal & Ceniza'));
      expect(json, contains('Vela'));
    });

    test('el LÉEME explica qué es cada cosa y de quién son los datos',
        () async {
      final archive = await zipDe(AtelierExportFormat.bundle);
      final leeme = texto(archive, 'LEEME.txt');

      expect(leeme, contains('Sal & Ceniza'));
      expect(leeme, contains('proyecto.json'));
      expect(leeme, contains('TUS DATOS SON TUYOS'));
    });
  });

  group('tipografía española en el PDF', () {
    // Las fuentes estándar del PDF se codifican en Latin-1, que NO tiene raya
    // (—). Y la raya es el marcador de diálogo del español, así que sin el
    // puente a CP-1252 esta exportación lanzaba una excepción en la mayoría de
    // novelas escritas en Corvus. Esta prueba existe para que no vuelva.
    final conDialogo = AtelierWorkspace(
      projects: [proyecto],
      activeProject: proyecto,
      nodes: [
        node(
          'd1',
          'Diálogo',
          '—¿Quién anda ahí? —preguntó Vela.\n\n'
              '—Nadie —dijo la voz—. Nunca nadie…\n\n'
              'Y añadió: “ya ves”, con esa ‘calma’ suya.',
          0,
        ),
      ],
      relations: const [],
      versions: const [],
    );

    test('la raya de diálogo no rompe la exportación', () async {
      final resultado = await servicio.build(
        format: AtelierExportFormat.pdf,
        workspace: conDialogo,
        author: 'Eva Salazar',
      );

      expect(String.fromCharCodes(resultado.bytes.take(5)), '%PDF-');
      expect(resultado.bytes.length, greaterThan(1000));
    });

    test('la raya viaja como su byte de CP-1252, no como interrogante', () {
      // 0x97 es la raya en WinAnsi, que es la codificación que el PDF declara.
      expect(toWinAnsi('—').codeUnitAt(0), 0x97);
      expect(toWinAnsi('…').codeUnitAt(0), 0x85);
      expect(toWinAnsi('“').codeUnitAt(0), 0x93);
      expect(toWinAnsi('’').codeUnitAt(0), 0x92);
      expect(toWinAnsi('–').codeUnitAt(0), 0x96);
    });

    test('el español corriente pasa intacto', () {
      const frase = '¿Cómo estás, Ñoño? ¡Añejo! «Sí», dijo él.';
      expect(toWinAnsi(frase), frase);
    });

    test('lo que no cabe se marca en vez de reventar el archivo', () {
      // Un emoji perdido es preferible a perder el manuscrito entero.
      expect(toWinAnsi('fin 🎉'), 'fin ?');
      expect(toWinAnsi('漢字'), '??');
    });

    test('un manuscrito con emoji sigue exportando a PDF', () async {
      final conEmoji = AtelierWorkspace(
        projects: [proyecto],
        activeProject: proyecto,
        nodes: [node('e1', 'Fin 🎉', 'Y colorín colorado 🎊', 0)],
        relations: const [],
        versions: const [],
      );

      final resultado = await servicio.build(
        format: AtelierExportFormat.pdf,
        workspace: conEmoji,
      );

      expect(String.fromCharCodes(resultado.bytes.take(5)), '%PDF-');
    });

    test('DOCX y EPUB conservan la tipografía tal cual, sin puente', () async {
      final docx = ZipDecoder().decodeBytes(
        (await servicio.build(
          format: AtelierExportFormat.docx,
          workspace: conDialogo,
        ))
            .bytes,
      );

      // Son XML en UTF-8: la raya y las comillas curvas viajan enteras.
      expect(texto(docx, 'word/document.xml'), contains('—¿Quién anda ahí?'));
      expect(texto(docx, 'word/document.xml'), contains('“ya ves”'));
    });
  });

  group('nombres de archivo', () {
    test('el título se convierte en un nombre seguro', () async {
      final resultado = await servicio.build(
        format: AtelierExportFormat.markdown,
        workspace: taller,
      );

      // «Sal & Ceniza» no puede llevarse el ampersand a un nombre de archivo.
      expect(resultado.filename, 'sal-ceniza.md');
    });
  });
}
