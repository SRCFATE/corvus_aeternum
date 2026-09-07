import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../../../../models/atelier_models.dart';
import '../../domain/manuscript.dart';
import 'xml_text.dart';

/// El paquete completo del proyecto.
///
/// La idea es que quien descargue esto tenga su obra entera y utilizable
/// aunque Corvus desaparezca mañana: el manuscrito en formatos que abre
/// cualquiera, un archivo por capítulo para trabajarlos sueltos, y el volcado
/// estructurado con fichas, relaciones y versiones para poder reimportarlo.
///
/// Por eso lleva un LÉEME: un ZIP sin explicación es un montón de archivos.
class BundleExporter {
  Uint8List build({
    required ManuscriptDocument doc,
    required AtelierWorkspace workspace,
    required String markdown,
    required String plainText,
    required String json,
  }) {
    final archive = Archive()
      ..addFile(_texto('LEEME.txt', _leeme(doc)))
      ..addFile(_texto('manuscrito.md', markdown))
      ..addFile(_texto('manuscrito.txt', plainText))
      ..addFile(_texto('proyecto.json', json));

    for (var i = 0; i < doc.chapters.length; i++) {
      final capitulo = doc.chapters[i];
      final numero = (i + 1).toString().padLeft(3, '0');
      final nombre = slugify(capitulo.title, fallback: 'capitulo');

      archive.addFile(_texto(
        'capitulos/$numero-$nombre.md',
        '# ${capitulo.title}\n\n${capitulo.body}\n',
      ));
    }

    // Las fichas del mundo van aparte: son consulta, no lectura seguida.
    final fichas = workspace.nodes
        .where((node) => !_esNarrativo(node.kind) && node.body.trim().isNotEmpty)
        .toList();

    for (final ficha in fichas) {
      final nombre = slugify(ficha.title, fallback: 'ficha');
      archive.addFile(_texto(
        'mundo/${ficha.kind}/$nombre.md',
        _fichaMarkdown(ficha),
      ));
    }

    return ZipEncoder().encodeBytes(archive);
  }

  bool _esNarrativo(String kind) => const {
        'chapter',
        'scene',
        'fragment',
        'page',
        'panel',
        'act',
      }.contains(kind);

  String _fichaMarkdown(AtelierNode node) {
    final buffer = StringBuffer()
      ..writeln('# ${node.title}')
      ..writeln()
      ..writeln('- Tipo: ${node.kind}')
      ..writeln('- Estado: ${node.status}')
      ..writeln('- Canon: ${node.canonStatus}');

    if (node.tags.isNotEmpty) {
      buffer.writeln('- Etiquetas: ${node.tags.join(', ')}');
    }

    for (final entrada in node.metadata.entries) {
      final valor = entrada.value;
      if (valor == null || '$valor'.trim().isEmpty) continue;
      buffer.writeln('- ${entrada.key}: $valor');
    }

    buffer
      ..writeln()
      ..writeln(node.body.trim());

    return buffer.toString();
  }

  String _leeme(ManuscriptDocument doc) => '''CORVUS ATELIER — ${doc.title}

Exportado el ${DateTime.now().toLocal().toString().split('.').first}.
${doc.wordCount} palabras en ${doc.chapters.length} capítulos.

QUÉ HAY AQUÍ

  manuscrito.md     La obra completa en Markdown, con sus encabezados.
  manuscrito.txt    La misma obra en texto plano, sin marcas.
  proyecto.json     Volcado estructurado: proyecto, elementos, relaciones y
                    versiones. Es el archivo que permite reimportarlo todo.
  capitulos/        Un archivo por capítulo, numerados en orden.
  mundo/            Las fichas de worldbuilding, agrupadas por tipo.

TUS DATOS SON TUYOS

Este paquete existe para que puedas llevarte tu obra cuando quieras y usarla
donde quieras, con o sin suscripción. Nada de lo que hay aquí depende de que
sigas en Corvus.
''';

  ArchiveFile _texto(String nombre, String contenido) {
    final bytes = utf8.encode(contenido);
    return ArchiveFile(nombre, bytes.length, bytes);
  }
}
