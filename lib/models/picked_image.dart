import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Una imagen elegida por el artista, ya leída a memoria.
///
/// En web el `path` de un [XFile] es una URL blob y `dart:io` no sabe abrirla:
/// cualquier lectura lanza `UnsupportedError`. Corvus se queda con los bytes
/// desde el momento de elegir la imagen, y así los mismos datos sirven para la
/// vista previa y para la subida en móvil, escritorio y navegador.
class PickedImage {
  final Uint8List bytes;

  /// Nombre original del archivo. De aquí sale la extensión al subirlo.
  final String filename;

  const PickedImage({required this.bytes, required this.filename});

  static Future<PickedImage> read(XFile file) async => PickedImage(
        bytes: await file.readAsBytes(),
        filename: file.name,
      );
}
