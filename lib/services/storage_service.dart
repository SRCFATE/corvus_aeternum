import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../models/picked_image.dart';

class StorageService {
  static const String _worksBucket = 'works';
  static const String _avatarsBucket = 'avatars';
  static const String _bannersBucket = 'banners';

  /// Extensiones que Corvus sabe nombrar. Si llega otra, el `contentType`
  /// queda nulo y lo deduce el cliente de Storage a partir de la ruta.
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
  Future<String> uploadWorkImage(PickedImage image, String userId) {
    final ext = _extensionOf(image);
    final filename = '${userId}_${DateTime.now().millisecondsSinceEpoch}$ext';

    return _uploadBytes(_worksBucket, 'images/$filename', image, ext);
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

  String _extensionOf(PickedImage image) {
    final ext = p.extension(image.filename).toLowerCase();

    return ext.isEmpty ? '.jpg' : ext;
  }
}
