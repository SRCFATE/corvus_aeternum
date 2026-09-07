import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/billing_models.dart';

/// La memoria local de los derechos.
///
/// Existe por una razón concreta: Atelier tiene que dejar escribir sin
/// conexión. Perder la red no puede cerrar el taller, así que los derechos que
/// ya se conocían siguen valiendo mientras dure la caché. Lo que sí exige
/// servidor son las funciones de servidor —cobrar, invitar, restaurar—, y esas
/// fallan por su cuenta con un mensaje claro.
///
/// La caché nunca CONCEDE nada: es una copia de lo que el servidor dijo la
/// última vez. La verdad sigue estando en Postgres, y cada comprobación que
/// mueve dinero o datos ajenos se repite allí.
class EntitlementCache {
  static const _entitlementsKey = 'atelier.entitlements.v1';
  static const _flagsKey = 'atelier.flags.v1';
  static const _userKey = 'atelier.entitlements.user';
  static const _stampKey = 'atelier.entitlements.stamp';

  /// Cuánto se confía en una copia local antes de volver a preguntar. Un día
  /// es el equilibrio entre no molestar al servidor en cada arranque y no
  /// arrastrar un plan caducado durante una semana.
  static const maxAge = Duration(hours: 24);

  Future<void> save({
    required String userId,
    required Entitlements entitlements,
    required Map<String, bool> flags,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, userId);
      await prefs.setString(
        _entitlementsKey,
        jsonEncode(entitlements.toMap()),
      );
      await prefs.setString(_flagsKey, jsonEncode(flags));
      await prefs.setString(_stampKey, DateTime.now().toIso8601String());
    } catch (error) {
      // Guardar es una comodidad. Si el almacenamiento del dispositivo falla,
      // la app sigue funcionando contra el servidor.
      debugPrint('ENTITLEMENT CACHE SAVE ERROR: $error');
    }
  }

  Future<({Entitlements entitlements, Map<String, bool> flags})?> read(
    String userId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Una caché de otra cuenta es peor que no tener caché.
      if (prefs.getString(_userKey) != userId) return null;

      final raw = prefs.getString(_entitlementsKey);
      if (raw == null) return null;

      final stamp = DateTime.tryParse(prefs.getString(_stampKey) ?? '');
      if (stamp == null || DateTime.now().difference(stamp) > maxAge) {
        return null;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      final flagsRaw = prefs.getString(_flagsKey);
      final flags = <String, bool>{};
      if (flagsRaw != null) {
        final decodedFlags = jsonDecode(flagsRaw);
        if (decodedFlags is Map) {
          decodedFlags.forEach((key, value) {
            flags['$key'] = value == true;
          });
        }
      }

      return (
        entitlements: Entitlements.fromMap(Map<String, dynamic>.from(decoded)),
        flags: flags,
      );
    } catch (error) {
      debugPrint('ENTITLEMENT CACHE READ ERROR: $error');
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_entitlementsKey);
      await prefs.remove(_flagsKey);
      await prefs.remove(_userKey);
      await prefs.remove(_stampKey);
    } catch (error) {
      debugPrint('ENTITLEMENT CACHE CLEAR ERROR: $error');
    }
  }
}
