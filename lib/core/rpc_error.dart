/// Error de una RPC de dominio que devolvió `{ok:false, reason_code:...}`.
///
/// Las RPC de Corvus nunca lanzan excepciones de Postgres al cliente para
/// reglas de negocio: devuelven un código estable que aquí se traduce a la voz
/// del archivo.
class CorvusRpcException implements Exception {
  final String reasonCode;
  final Map<String, dynamic> data;

  const CorvusRpcException(this.reasonCode, [this.data = const {}]);

  String get message => corvusReasonMessage(reasonCode);

  @override
  String toString() => message;
}

/// Traduce un `reason_code` del servidor al lenguaje de Corvus.
String corvusReasonMessage(String? code) {
  switch (code) {
    // ── Identidad y @ ────────────────────────────────────────────────────────
    case 'USERNAME_TAKEN':
      return 'Este @ ya está registrado.';
    case 'USERNAME_RESERVED':
      return 'Este @ está reservado por el archivo.';
    case 'USERNAME_INVALID':
      return 'Solo minúsculas, números, punto y guion bajo, sin caracteres especiales seguidos.';
    case 'USERNAME_TOO_SHORT':
      return 'El @ necesita al menos 3 caracteres.';
    case 'USERNAME_TOO_LONG':
      return 'El @ no puede exceder 30 caracteres.';
    case 'USERNAME_SAME':
      return 'Es el mismo @ que ya llevas.';
    case 'USERNAME_COOLDOWN':
      return 'Tu @ ya cambió este año. La siguiente muda espera su fecha.';
    case 'PROFILE_ALREADY_SET':
      return 'Tu perfil ya fue sellado. Usa el cambio de @ para modificarlo.';
    case 'NO_PROFILE':
      return 'Aún no existe un perfil que modificar.';
    case 'PROFILE_NOT_FOUND':
      return 'No se encontró ese perfil.';

    // ── Moderación ───────────────────────────────────────────────────────────
    case 'NOT_AUTHORIZED':
      return 'Este acto requiere autorización curatorial.';
    case 'CANNOT_BAN_SELF':
      return 'No puedes suspender tu propia cuenta.';
    case 'CANNOT_BAN_ADMIN':
      return 'No puedes suspender a otro administrador.';

    // ── Sesión ───────────────────────────────────────────────────────────────
    case 'NOT_AUTHENTICATED':
      return 'El archivo no te reconoce. Inicia sesión.';

    default:
      return 'La operación no pudo completarse.';
  }
}

/// Desempaqueta la respuesta `{ok, ...}` de una RPC; lanza si `ok` es falso.
Map<String, dynamic> unwrapRpc(dynamic raw) {
  final map = Map<String, dynamic>.from(raw as Map);
  if (map['ok'] != true) {
    throw CorvusRpcException(map['reason_code'] as String? ?? 'UNKNOWN', map);
  }
  return map;
}
