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

    // ── Recuperación de contraseña ───────────────────────────────────────────
    case 'RECOVERY_CODE_INVALID':
      return 'Ese código no es correcto. Revísalo o pide uno nuevo.';
    case 'RECOVERY_CODE_EXPIRED':
      return 'El código caducó. Solicita uno nuevo.';
    case 'RECOVERY_TOO_MANY_ATTEMPTS':
      return 'Demasiados intentos con este código. Pide uno nuevo.';
    case 'RECOVERY_RATE_LIMIT':
      return 'Ya pediste varios códigos. Espera una hora antes de intentarlo de nuevo.';
    case 'PASSWORD_TOO_SHORT':
      return 'La contraseña necesita al menos 6 caracteres.';
    case 'EMAIL_NOT_CONFIGURED':
      return 'El envío de correos aún no está configurado. Falta la clave del '
          'proveedor en el servidor.';
    case 'RECOVERY_ISSUE_FAILED':
      return 'No pudimos generar el código. Inténtalo de nuevo en un momento.';
    case 'EMAIL_SEND_FAILED':
      return 'No se pudo enviar el correo. Inténtalo de nuevo en un momento.';
    case 'EMAIL_DOMAIN_NOT_VERIFIED':
      return 'El servidor de correo aún está en modo de pruebas y solo puede '
          'escribir a la dirección del administrador.';
    case 'EMAIL_INVALID':
      return 'Ese correo no parece válido.';

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
