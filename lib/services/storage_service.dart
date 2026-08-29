import 'dart:io';
import 'package:path/path.dart' as p;
import '../core/supabase_config.dart';

class StorageService {
  static const String _worksBucket = 'works';
  static const String _avatarsBucket = 'avatars';
  static const String _bannersBucket = 'banners';

  Future<String> uploadWorkImage(File file, String userId) async {
    final ext = p.extension(file.path);
    final filename = '${userId}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final path = 'images/$filename';

    await supabase.storage
        .from(_worksBucket)
        .upload(path, file);

    return supabase.storage.from(_worksBucket).getPublicUrl(path);
  }

  Future<String> uploadAvatar(File file, String userId) async {
    final ext = p.extension(file.path);
    final path = '$userId/avatar$ext';

    await supabase.storage
        .from(_avatarsBucket)
        .upload(path, file);

    return supabase.storage.from(_avatarsBucket).getPublicUrl(path);
  }

  Future<String> uploadBanner(File file, String userId) async {
    final ext = p.extension(file.path);
    final path = '$userId/banner$ext';

    await supabase.storage
        .from(_bannersBucket)
        .upload(path, file);

    return supabase.storage.from(_bannersBucket).getPublicUrl(path);
  }

  Future<void> deleteFile(String bucket, String path) async {
    await supabase.storage.from(bucket).remove([path]);
  }
}
