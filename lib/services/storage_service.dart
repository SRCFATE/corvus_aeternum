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

  Future<String> uploadWorkImage(PickedImage image, String userId) {
    final ext = _extensionOf(image);
    final filename = '${userId}_${DateTime.now().millisecondsSinceEpoch}$ext';

    return _uploadBytes(_worksBucket, 'images/$filename', image, ext);
  }

  Future<String> uploadAvatar(PickedImage image, String userId) {
    final ext = _extensionOf(image);

    return _uploadBytes(_avatarsBucket, '$userId/avatar$ext', image, ext);
  }

  Future<String> uploadBanner(PickedImage image, String userId) {
    final ext = _extensionOf(image);

    return _uploadBytes(_bannersBucket, '$userId/banner$ext', image, ext);
  }

  Future<void> deleteFile(String bucket, String path) async {
    await supabase.storage.from(bucket).remove([path]);
  }

  /// Se sube por bytes y no por archivo: `uploadBinary` es la única vía que
  /// existe en las tres plataformas, porque no toca el sistema de archivos.
  Future<String> _uploadBytes(
    String bucket,
    String path,
    PickedImage image,
    String extension,
  ) async {
    await supabase.storage.from(bucket).uploadBinary(
          path,
          image.bytes,
          fileOptions: FileOptions(contentType: _mimeTypes[extension]),
        );

    return supabase.storage.from(bucket).getPublicUrl(path);
  }

  String _extensionOf(PickedImage image) {
    final ext = p.extension(image.filename).toLowerCase();

    return ext.isEmpty ? '.jpg' : ext;
  }
}
