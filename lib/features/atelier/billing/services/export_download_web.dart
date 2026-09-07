import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Descarga real en el navegador.
///
/// Se usa un Blob y no una URL `data:`: Chrome bloquea la navegación de nivel
/// superior a `data:`, así que un manuscrito de cierto tamaño no llegaría a
/// descargarse nunca. El objeto se revoca en cuanto se dispara el clic para no
/// dejar el archivo retenido en memoria.
Future<bool> downloadExport({
  required String filename,
  required Uint8List bytes,
  required String mimeType,
}) async {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );

  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename
    ..style.display = 'none';

  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);

  return true;
}
