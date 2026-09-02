import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Testigo local del visitante, para poder deduplicar las lecturas de quien no
/// ha iniciado sesión.
///
/// No identifica a nadie: es un número aleatorio que vive solo en este
/// navegador o dispositivo, no viaja a ningún tercero y desaparece si el
/// visitante limpia los datos del sitio. Sirve para que recargar una obra diez
/// veces no cuente como diez lecturas, no para reconocer a la persona.
class VisitorToken {
  static const _clave = 'corvus_visitor_id';

  static String? _enMemoria;

  static Future<String> read() async {
    final cacheado = _enMemoria;
    if (cacheado != null) return cacheado;

    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString(_clave);

    if (token == null) {
      token = _generar();
      await prefs.setString(_clave, token);
    }

    _enMemoria = token;

    return token;
  }

  static String _generar() {
    final random = Random.secure();

    return List<int>.generate(16, (_) => random.nextInt(256))
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
