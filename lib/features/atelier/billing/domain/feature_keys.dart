/// Las llaves de los derechos de Atelier, escritas una sola vez.
///
/// El valor de cada constante coincide con `entitlement_features.key` en la
/// base. Se escriben aquí para que una errata sea un error de compilación y no
/// una función que se abre por descuido: `AtelierFeature.exportPdf` no compila
/// mal, `'atelier.export.pfd'` sí se ejecuta mal.
///
/// Que un derecho exista en esta lista NO significa que Flutter decida sobre
/// él. La decisión vive en Postgres; esto es solo el nombre por el que se
/// pregunta.
abstract final class AtelierFeature {
  static const projectsUnlimited = 'atelier.projects.unlimited';
  static const worldbuilding = 'atelier.worldbuilding';

  static const versionHistoryBasic = 'atelier.version_history.basic';
  static const versionHistoryAdvanced = 'atelier.version_history.advanced';
  static const versionHistoryMaxSnapshots =
      'atelier.version_history.max_snapshots';
  static const backupsAdvanced = 'atelier.backups.advanced';

  static const collaboration = 'atelier.collaboration';
  static const collaboratorsMax = 'atelier.collaborators.max';
  static const comments = 'atelier.comments';
  static const tasksAssign = 'atelier.tasks.assign';

  static const storageMaxBytes = 'atelier.storage.max_bytes';

  static const exportMarkdown = 'atelier.export.markdown';
  static const exportTxt = 'atelier.export.txt';
  static const exportJson = 'atelier.export.json';
  static const exportDocx = 'atelier.export.docx';
  static const exportPdf = 'atelier.export.pdf';
  static const exportEpub = 'atelier.export.epub';
  static const exportProjectBundle = 'atelier.export.project_bundle';

  static const analyticsAdvanced = 'atelier.analytics.advanced';
  static const automation = 'atelier.automation';
  static const automationsMax = 'atelier.automations.max';
  static const customFields = 'atelier.custom_fields';
  static const templatesPro = 'atelier.templates.pro';
  static const editorialManuscript = 'atelier.editorial.manuscript';

  static const workspace = 'atelier.workspace';
  static const workspacesMax = 'atelier.workspaces.max';
  static const workspaceSeatsMax = 'atelier.workspace.seats.max';
  static const rolesCustom = 'atelier.roles.custom';
  static const auditLog = 'atelier.audit_log';

  static const publishingSubmissions = 'atelier.publishing.submissions';
}

/// Capacidades dentro de un workspace o de un proyecto compartido.
///
/// Los permisos NO se leen del nombre del rol: un rol es un atajo con nombre
/// para un puñado de estas capacidades, y por eso Teams puede definir roles
/// propios sin que la app cambie.
abstract final class AtelierCapability {
  static const projectRead = 'project.read';
  static const projectWrite = 'project.write';
  static const projectCreate = 'project.create';
  static const projectDelete = 'project.delete';
  static const memberInvite = 'member.invite';
  static const memberRemove = 'member.remove';
  static const memberManage = 'member.manage';
  static const roleManage = 'role.manage';
  static const billingManage = 'billing.manage';
  static const exportCreate = 'export.create';
  static const commentCreate = 'comment.create';
  static const commentResolve = 'comment.resolve';
  static const taskAssign = 'task.assign';
  static const automationManage = 'automation.manage';
  static const templateManage = 'template.manage';
  static const settingsManage = 'settings.manage';
  static const workspaceManage = 'workspace.manage';
  static const auditRead = 'audit.read';
}

/// Banderas de despliegue gradual. Distintas de los derechos: un derecho dice
/// qué has contratado, una bandera dice si esa parte del producto ya está
/// encendida en Corvus.
abstract final class AtelierFlag {
  static const billing = 'billing';
  static const professional = 'professional';
  static const teams = 'teams';
  static const addons = 'addons';
  static const advancedExports = 'advanced_exports';
  static const automation = 'automation';
  static const teamWorkspaces = 'team_workspaces';
  static const publisherSubmission = 'publisher_submission';
}

/// Eventos de analítica comercial. La lista blanca del servidor rechaza
/// cualquier otro nombre, así que estas constantes son la lista completa.
abstract final class BillingEvent {
  static const planViewed = 'plan_viewed';
  static const planCompared = 'plan_compared';
  static const upgradeClicked = 'upgrade_clicked';
  static const checkoutStarted = 'checkout_started';
  static const checkoutCompleted = 'checkout_completed';
  static const subscriptionStarted = 'subscription_started';
  static const subscriptionCanceled = 'subscription_canceled';
  static const subscriptionReactivated = 'subscription_reactivated';
  static const upgradeCompleted = 'upgrade_completed';
  static const downgradeCompleted = 'downgrade_completed';
  static const featureGateSeen = 'feature_gate_seen';
  static const storageLimitReached = 'storage_limit_reached';
  static const collaboratorLimitReached = 'collaborator_limit_reached';
  static const addonPurchased = 'addon_purchased';
  static const billingCenterViewed = 'billing_center_viewed';
}

/// Códigos de plan. Existen tres hoy; la arquitectura admite más sin tocar
/// código, así que nada debe comparar contra estas constantes para decidir si
/// una función está disponible: para eso están los derechos.
abstract final class PlanCode {
  static const free = 'free';
  static const professional = 'professional';
  static const teams = 'teams';
}
