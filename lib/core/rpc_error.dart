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
    case 'RECOVERY_CLIENT_UNAUTHORIZED':
      return 'No pudimos iniciar la recuperación desde esta app.';
    case 'EMAIL_SEND_FAILED':
      return 'No se pudo enviar el correo. Inténtalo de nuevo en un momento.';
    case 'EMAIL_DOMAIN_NOT_VERIFIED':
      return 'El servidor de correo aún está en modo de pruebas y solo puede '
          'escribir a la dirección del administrador.';
    case 'EMAIL_INVALID':
      return 'Ese correo no parece válido.';

    // ── Atelier: límites del plan ────────────────────────────────────────────
    //
    // Ninguno de estos mensajes amenaza con borrar nada, porque el sistema
    // nunca lo hace: un límite alcanzado pausa lo nuevo y deja intacto lo que
    // ya existe. Redactarlos de otra forma sería mentir sobre el producto.
    case 'ATELIER_STORAGE_QUOTA_EXCEEDED':
      return 'No queda espacio para archivos nuevos. Todo lo que ya subiste '
          'sigue guardado y accesible: libera espacio, amplía el '
          'almacenamiento o sube de plan para volver a cargar.';
    case 'ATELIER_COLLABORATOR_LIMIT_REACHED':
      return 'Has alcanzado el número de colaboradores de tu plan. Retira a '
          'alguien del proyecto o amplía el plan; nadie pierde su trabajo.';
    case 'ATELIER_COLLABORATION_NOT_INCLUDED':
      return 'Compartir este proyecto no está incluido en tu plan actual.';
    case 'ATELIER_HISTORY_NOT_INCLUDED':
      return 'Restaurar y comparar versiones está incluido en Atelier '
          'Professional. Tus versiones se conservan igualmente.';
    case 'ATELIER_VERSION_OUT_OF_WINDOW':
      return 'Esa versión queda fuera de las que tu plan permite restaurar. '
          'Sigue guardada y puedes exportarla.';
    case 'ATELIER_VERSION_WITHOUT_SNAPSHOT':
      return 'Esa versión se creó como marca de tiempo, sin copia del '
          'contenido, así que no hay a qué volver.';
    case 'ATELIER_VERSION_NOT_FOUND':
      return 'No se encontró esa versión.';
    case 'ATELIER_CUSTOM_FIELDS_NOT_INCLUDED':
      return 'Los campos personalizados están incluidos en Atelier '
          'Professional. Los que ya creaste siguen guardados.';
    case 'ATELIER_EDITORIAL_NOT_INCLUDED':
      return 'La producción editorial está incluida en Atelier Professional.';
    case 'ATELIER_SUBMISSIONS_NOT_INCLUDED':
      return 'El envío a Corvus Publishing Bureau no está disponible para tu '
          'cuenta ahora mismo.';
    case 'ATELIER_PROJECT_NOT_FOUND':
      return 'Ese proyecto ya no existe en el taller.';

    // ── Atelier: espacios de trabajo ─────────────────────────────────────────
    case 'ATELIER_WORKSPACE_NOT_INCLUDED':
      return 'Los espacios de trabajo forman parte de Atelier Teams.';
    case 'ATELIER_WORKSPACE_LIMIT_REACHED':
      return 'Ya tienes todos los espacios de trabajo que incluye tu plan.';
    case 'ATELIER_WORKSPACE_SLUG_INVALID':
      return 'Ese nombre no sirve para identificar un espacio. Usa al menos '
          'tres letras o números.';
    case 'ATELIER_SEAT_LIMIT_REACHED':
      return 'No quedan asientos libres en el espacio. Amplía el plan o retira '
          'a alguien antes de invitar.';
    case 'ATELIER_ALREADY_MEMBER':
      return 'Esa persona ya forma parte del espacio.';
    case 'ATELIER_NOT_A_MEMBER':
      return 'Esa persona no forma parte del espacio.';
    case 'ATELIER_NOT_A_COLLABORATOR':
      return 'Esa persona no colabora en este proyecto.';
    case 'ATELIER_ROLE_UNKNOWN':
      return 'Ese rol no existe en este espacio.';
    case 'ATELIER_CAPABILITY_UNKNOWN':
      return 'Ese permiso no existe. Un permiso inventado nunca se comprobaría.';
    case 'ATELIER_CAPABILITY_RESERVED':
      return 'La facturación no se delega con un rol: la gestiona quien paga.';
    case 'ATELIER_CUSTOM_ROLES_NOT_INCLUDED':
      return 'Los roles personalizados forman parte de Atelier Teams.';
    case 'ATELIER_CANNOT_DEMOTE_OWNER':
      return 'El espacio no puede quedarse sin propietario.';
    case 'ATELIER_CANNOT_REMOVE_OWNER':
      return 'No se puede retirar a quien es propietario del espacio.';
    case 'ATELIER_INVITE_NO_RECIPIENT':
      return 'Indica a quién invitas: un perfil o un correo.';
    case 'ATELIER_INVITE_NOT_FOUND':
      return 'Esa invitación ya no existe.';
    case 'ATELIER_INVITE_ALREADY_ANSWERED':
      return 'Esa invitación ya fue respondida.';
    case 'ATELIER_INVITE_EXPIRED':
      return 'La invitación caducó. Pide una nueva.';
    case 'BUREAU_SUBMISSION_IN_PROGRESS':
      return 'Ese proyecto ya tiene un envío en curso en el Bureau.';

    // ── Facturación ──────────────────────────────────────────────────────────
    case 'BILLING_NOT_AVAILABLE':
      return 'El cobro todavía no está abierto para tu cuenta. Atelier '
          'funciona igual mientras tanto.';
    case 'BILLING_PROVIDER_NOT_CONFIGURED':
    case 'BILLING_PRICE_NOT_CONFIGURED':
      return 'El cobro aún no está configurado en el servidor. Escríbenos y lo '
          'resolvemos.';
    case 'BILLING_PRICE_REQUIRED':
      return 'Falta elegir el plan que quieres contratar.';
    case 'BILLING_PRICE_NOT_AVAILABLE':
      return 'Ese plan ya no está disponible.';
    case 'BILLING_PROVIDER_MISMATCH':
      return 'Ese precio pertenece a otro proveedor de pago.';
    case 'BILLING_WORKSPACE_REQUIRED':
      return 'Atelier Teams se contrata para un espacio de trabajo. Crea el '
          'espacio primero.';
    case 'BILLING_PLAN_IS_PERSONAL':
      return 'Ese plan es individual y no se contrata para un espacio.';
    case 'BILLING_NO_CUSTOMER':
      return 'Todavía no hay un expediente de pago para esta cuenta.';
    case 'BILLING_NO_ACTIVE_SUBSCRIPTION':
      return 'No hay ninguna suscripción activa que gestionar.';
    case 'BILLING_SUBSCRIPTION_NOT_FOUND':
      return 'El proveedor de pago no reconoce esa suscripción.';
    case 'BILLING_ACTION_UNKNOWN':
      return 'Esa operación de facturación no existe.';
    case 'BILLING_CHECKOUT_FAILED':
    case 'BILLING_PORTAL_FAILED':
    case 'BILLING_ACTION_FAILED':
    case 'BILLING_PROVIDER_ERROR':
    case 'BILLING_SYNC_FAILED':
    case 'BILLING_REQUEST_FAILED':
    case 'BILLING_UNEXPECTED_RESPONSE':
      return 'No pudimos hablar con el proveedor de pago. Inténtalo de nuevo '
          'en un momento; no se cobró nada.';

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
