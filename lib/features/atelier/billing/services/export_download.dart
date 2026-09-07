/// Entrega del archivo exportado.
///
/// En web se descarga de verdad; en el resto de plataformas todavía no hay
/// destino elegible sin añadir más dependencias, así que devuelve `false` y la
/// pantalla ofrece copiar al portapapeles. Copiar no es un consuelo: para
/// Markdown, TXT y JSON es una salida completamente válida.
library;

export 'export_download_io.dart'
    if (dart.library.js_interop) 'export_download_web.dart';
