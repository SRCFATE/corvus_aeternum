import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/rpc_error.dart';
import '../../../../core/supabase_config.dart';
import '../data/entitlement_repository.dart';
import '../domain/billing_models.dart';

/// Subida y borrado de archivos del taller, con la cuota delante.
///
/// La comprobación local existe para dar un mensaje decente antes de gastar
/// ancho de banda; la que manda es el trigger de Postgres sobre
/// `storage.objects`, que rechaza la subida aunque el cliente mienta.
class AtelierStorageService {
  static const bucket = 'atelier';

  final EntitlementRepository _entitlements;

  AtelierStorageService({EntitlementRepository? entitlements})
      : _entitlements = entitlements ?? EntitlementRepository();

  /// La convención de rutas que la cuota entiende: el primer segmento dice a
  /// qué bolsa se carga el archivo.
  static String pathFor({
    required String projectId,
    required String filename,
    String? workspaceId,
    String? profileId,
  }) {
    final owner = workspaceId ?? profileId;
    final scope = workspaceId != null ? 'w' : 'u';
    return '$scope/$owner/$projectId/$filename';
  }

  Future<UsageSnapshot> usage({String? workspaceId}) =>
      _entitlements.fetchUsage(workspaceId: workspaceId);

  Future<String> upload({
    required String projectId,
    required String filename,
    required Uint8List bytes,
    String? contentType,
    String? workspaceId,
    String? profileId,
  }) async {
    final path = pathFor(
      projectId: projectId,
      filename: filename,
      workspaceId: workspaceId,
      profileId: profileId ?? supabase.auth.currentUser?.id,
    );

    try {
      await supabase.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );
    } on StorageException catch (error) {
      // El trigger grita con este texto cuando la bolsa está llena. Se traduce
      // aquí para que la interfaz pueda ofrecer liberar espacio o subir de plan
      // en vez de enseñar un error de base de datos.
      if (error.message.contains('ATELIER_STORAGE_QUOTA_EXCEEDED')) {
        throw const CorvusRpcException('ATELIER_STORAGE_QUOTA_EXCEEDED');
      }
      rethrow;
    }

    return path;
  }

  /// El taller es privado: los archivos se sirven con URL firmada y temporal,
  /// nunca con una dirección pública permanente.
  Future<String> signedUrl(String path, {int expiresInSeconds = 3600}) {
    return supabase.storage.from(bucket).createSignedUrl(path, expiresInSeconds);
  }

  /// Borrar siempre se puede, incluso por encima de la cuota: es la vía de
  /// salida de quien se pasó.
  Future<void> remove(String path) async {
    await supabase.storage.from(bucket).remove([path]);
  }

  Future<List<FileObject>> list({
    required String projectId,
    String? workspaceId,
    String? profileId,
  }) {
    final owner = workspaceId ?? profileId ?? supabase.auth.currentUser?.id;
    final scope = workspaceId != null ? 'w' : 'u';

    return supabase.storage.from(bucket).list(path: '$scope/$owner/$projectId');
  }
}

/// Formatea bytes para que «1.3 GB / 2 GB» se lea igual en toda la aplicación.
String formatBytes(int bytes, {int decimals = 1}) {
  if (bytes == kUnlimited) return 'Sin límite';
  if (bytes <= 0) return '0 MB';

  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;

  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }

  // Los enteros se leen mejor sin decimal: «2 GB», no «2.0 GB».
  final rounded = value.toStringAsFixed(unit >= 2 ? decimals : 0);
  final clean = rounded.endsWith('.0')
      ? rounded.substring(0, rounded.length - 2)
      : rounded;

  return '$clean ${units[unit]}';
}
