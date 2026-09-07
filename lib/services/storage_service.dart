import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../models/picked_image.dart';

class StorageService {
  static const String _worksBucket = 'works';
  static const String _avatarsBucket = 'avatars';
  static const String _bannersBucket = 'banners';

  /// Extensiones que Corvus sabe nombrar, y las únicas que acepta.
  ///
  /// La lista no es cosmética: el nombre del archivo lo elige quien sube, y
  /// Storage deduce el `Content-Type` de la ruta cuando no se lo damos. Sin
  /// esta puerta, un `retrato.svg` —o un `retrato.html`— acabaría servido como
  /// documento ejecutable desde un bucket público, o sea XSS alojado en un
  /// dominio nuestro. SVG queda fuera a propósito, aunque sea una imagen.
  static const Map<String, String> _mimeTypes = {
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.gif': 'image/gif',
    '.webp': 'image/webp',
    '.heic': 'image/heic',
    '.heif': 'image/heif',
    '.bmp': 'image/bmp',
  };

  /// Cada obra es una pieza distinta, así que su portada estrena nombre y no
  /// pisa a ninguna anterior.
  ///
  /// Va bajo la carpeta del artista, no bajo `images/`: en Storage la primera
  /// carpeta es la prueba de propiedad, y es lo que mira la política que
  /// impide tocar los archivos de otro.
  Future<String> uploadWorkImage(PickedImage image, String userId) {
    final ext = _extensionOf(image);
    final filename = '${DateTime.now().millisecondsSinceEpoch}$ext';

    return _uploadBytes(_worksBucket, '$userId/$filename', image, ext);
  }

  Future<String> uploadAvatar(PickedImage image, String userId) =>
      _uploadUserAsset(_avatarsBucket, userId, 'avatar', image);

  Future<String> uploadBanner(PickedImage image, String userId) =>
      _uploadUserAsset(_bannersBucket, userId, 'banner', image);

  Future<void> deleteFile(String bucket, String path) async {
    await supabase.storage.from(bucket).remove([path]);
  }

  /// Avatar y banner son recursos mutables del artista: su carpeta guarda una
  /// sola imagen, que se reemplaza en su sitio en vez de fallar por colisión.
  Future<String> _uploadUserAsset(
    String bucket,
    String userId,
    String name,
    PickedImage image,
  ) async {
    final ext = _extensionOf(image);
    final filename = '$name$ext';

    final url = await _uploadBytes(
      bucket,
      '$userId/$filename',
      image,
      ext,
      upsert: true,
    );

    // Cambiar de .jpg a .png estrena ruta y dejaría huérfana la anterior,
    // que ya no referencia nadie.
    await _removeStale(bucket, userId, keep: filename);

    // La ruta es estable, así que sin esto el navegador y la caché de
    // imágenes seguirían sirviendo el avatar anterior.
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Se sube por bytes y no por archivo: `uploadBinary` es la única vía que
  /// existe en las tres plataformas, porque no toca el sistema de archivos.
  Future<String> _uploadBytes(
    String bucket,
    String path,
    PickedImage image,
    String extension, {
    bool upsert = false,
  }) async {
    await supabase.storage.from(bucket).uploadBinary(
          path,
          image.bytes,
          fileOptions: FileOptions(
            contentType: _mimeTypes[extension],
            upsert: upsert,
          ),
        );

    return supabase.storage.from(bucket).getPublicUrl(path);
  }

  /// Deja en la carpeta del artista solo la imagen recién subida.
  Future<void> _removeStale(
    String bucket,
    String folder, {
    required String keep,
  }) async {
    try {
      final objects = await supabase.storage.from(bucket).list(path: folder);
      final stale = objects
          .where((object) => object.name != keep)
          .map((object) => '$folder/${object.name}')
          .toList();

      if (stale.isNotEmpty) {
        await supabase.storage.from(bucket).remove(stale);
      }
    } catch (_) {
      // Limpiar es mantenimiento: la imagen nueva ya quedó subida y es la que
      // referencia el perfil, así que un fallo aquí no debe romper el guardado.
    }
  }

  /// La extensión sale del nombre que trae el archivo, y ese nombre lo escribe
  /// quien sube. Solo se acepta si está en la lista; cualquier otra cosa se
  /// guarda como `.jpg` y con su `Content-Type` declarado, de modo que nada
  /// llegue al bucket pudiendo ejecutarse en un navegador.
  String _extensionOf(PickedImage image) {
    final ext = p.extension(image.filename).toLowerCase();

    return _mimeTypes.containsKey(ext) ? ext : '.jpg';
  }
}
