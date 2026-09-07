import 'dart:typed_data';

/// Descarga en plataformas nativas: todavía no. Elegir carpeta exigiría
/// `path_provider` y un selector, así que aquí se devuelve `false` y la
/// pantalla ofrece copiar al portapapeles cuando el formato es texto.
///
/// Para DOCX, PDF, EPUB y el paquete completo —que son binarios— eso no basta,
/// y por eso la hoja de exportación lo dice en vez de fingir que funcionó.
Future<bool> downloadExport({
  required String filename,
  required Uint8List bytes,
  required String mimeType,
}) async {
  return false;
}
