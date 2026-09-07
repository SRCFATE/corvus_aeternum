-- Corvus Atelier — catálogo inicial: planes, derechos, productos y precios.
--
-- Es una siembra idempotente, no una migración de esquema: se puede reaplicar
-- y solo repone lo que falte sin pisar lo que administración haya ajustado
-- después. Por eso los `on conflict` de precios y planes no tocan campos
-- comerciales editables (precio, orden, textos) más allá de la primera vez.
--
-- La filosofía que fija esta siembra: Atelier Free no limita el acto de crear.
-- Ningún derecho de aquí cuenta palabras, capítulos, personajes ni proyectos.
-- Lo que se cobra es infraestructura, colaboración y producción profesional.

-- ─── Planes ─────────────────────────────────────────────────────────────────

insert into public.plans (
  code, name, tagline, description, scope, tier_rank, badge,
  is_recommended, is_public, sort_order, highlights
) values
  (
    'free', 'Atelier Free', '$0 para siempre',
    'Todo lo necesario para escribir, construir mundos y organizar una obra durante años. Sin tarjeta, sin prueba, sin caducidad.',
    'user', 0, 'GRATIS PARA SIEMPRE', false, true, 0,
    '["Proyectos, documentos y mundos ilimitados","Worldbuilding, wiki interna y backlinks","Versionado básico y exportación en Markdown, TXT y JSON","2 GB de archivos","Publicación en Corvus Aeternum"]'::jsonb
  ),
  (
    'professional', 'Atelier Professional', 'Producir, colaborar y publicar',
    'El taller cuando la obra deja de ser privada: historial profundo, colaboración, producción editorial y exportación a los formatos que pide una editorial.',
    'user', 10, 'RECOMENDADO', true, true, 1,
    '["Historial extendido con comparación y restauración","Hasta 10 colaboradores por proyecto","Exportación DOCX, PDF, EPUB y paquete completo","Modo manuscrito y producción editorial","Analíticas de escritura y automatizaciones","25 GB de archivos"]'::jsonb
  ),
  (
    'teams', 'Atelier Teams', 'Trabajar como estudio',
    'Espacios de trabajo compartidos con roles, permisos, auditoría y flujo editorial para estudios, editoriales y equipos creativos.',
    'workspace', 20, 'ESTUDIOS Y EDITORIALES', false, true, 2,
    '["Todo Professional para cada miembro","Workspaces con roles y permisos por capacidad","Registro de auditoría completo","Roles personalizados","100 GB por workspace","Facturación centralizada"]'::jsonb
  )
on conflict (code) do update set
  name = excluded.name,
  tagline = excluded.tagline,
  description = excluded.description,
  scope = excluded.scope,
  tier_rank = excluded.tier_rank,
  highlights = excluded.highlights;

-- ─── Catálogo de derechos ───────────────────────────────────────────────────
--
-- `-1` en un límite significa ilimitado. Se escribe así, y no con null, para
-- que la comparación numérica del resolutor no tenga que tratar un caso
-- especial en cada rama.

insert into public.entitlement_features (
  key, kind, name, description, unit, default_value, aggregation, sort_order
) values
  ('atelier.projects.unlimited', 'boolean', 'Proyectos ilimitados',
   'Crear proyectos, obras y mundos sin tope. Free incluido: el proceso creativo no se limita.',
   '', 'true'::jsonb, 'or', 0),
  ('atelier.worldbuilding', 'boolean', 'Worldbuilding',
   'Mundiarium completo: personajes, lugares, facciones, especies, lore, cronologías y relaciones.',
   '', 'true'::jsonb, 'or', 1),
  ('atelier.version_history.basic', 'boolean', 'Versionado básico',
   'Crear puntos de versión y consultar la línea de tiempo del proyecto.',
   '', 'true'::jsonb, 'or', 10),
  ('atelier.version_history.advanced', 'boolean', 'Historial avanzado',
   'Snapshots restaurables, comparación entre versiones y diff de texto.',
   '', 'false'::jsonb, 'or', 11),
  ('atelier.version_history.max_snapshots', 'limit', 'Versiones restaurables',
   'Cuántos puntos de restauración recientes se pueden restaurar o comparar. Los demás se conservan siempre, solo quedan en lectura.',
   'versiones', '10'::jsonb, 'max', 12),
  ('atelier.backups.advanced', 'boolean', 'Backups avanzados',
   'Copias automáticas del proyecto y recuperación estructurada.',
   '', 'false'::jsonb, 'or', 13),
  ('atelier.collaboration', 'boolean', 'Colaboración',
   'Compartir un proyecto con otras personas, comentar y sugerir.',
   '', 'true'::jsonb, 'or', 20),
  ('atelier.collaborators.max', 'limit', 'Colaboradores por proyecto',
   'Cuántas personas pueden trabajar contigo en un mismo proyecto.',
   'colaboradores', '1'::jsonb, 'max', 21),
  ('atelier.comments', 'boolean', 'Comentarios y sugerencias',
   'Hilos de comentario sobre capítulos, escenas y fichas.',
   '', 'true'::jsonb, 'or', 22),
  ('atelier.tasks.assign', 'boolean', 'Asignación de tareas',
   'Asignar tareas y menciones dentro de un proyecto compartido.',
   '', 'false'::jsonb, 'or', 23),
  ('atelier.storage.max_bytes', 'quota', 'Almacenamiento',
   'Espacio para archivos binarios: portadas, referencias, audio, PDF.',
   'bytes', '2147483648'::jsonb, 'max', 30),
  ('atelier.export.markdown', 'boolean', 'Exportar Markdown',
   'Portabilidad básica: siempre disponible, en todos los planes.',
   '', 'true'::jsonb, 'or', 40),
  ('atelier.export.txt', 'boolean', 'Exportar TXT',
   'Portabilidad básica: siempre disponible, en todos los planes.',
   '', 'true'::jsonb, 'or', 41),
  ('atelier.export.json', 'boolean', 'Exportar JSON',
   'Volcado estructurado del proyecto. Siempre disponible: los datos son del autor.',
   '', 'true'::jsonb, 'or', 42),
  ('atelier.export.docx', 'boolean', 'Exportar DOCX',
   'Manuscrito en formato Word con estilos editoriales.',
   '', 'false'::jsonb, 'or', 43),
  ('atelier.export.pdf', 'boolean', 'Exportar PDF',
   'Maquetación en PDF lista para lectura o envío.',
   '', 'false'::jsonb, 'or', 44),
  ('atelier.export.epub', 'boolean', 'Exportar EPUB',
   'Libro electrónico con front matter, índice y metadatos.',
   '', 'false'::jsonb, 'or', 45),
  ('atelier.export.project_bundle', 'boolean', 'Paquete completo',
   'ZIP con todo el proyecto: texto, fichas, relaciones, versiones y archivos.',
   '', 'false'::jsonb, 'or', 46),
  ('atelier.analytics.advanced', 'boolean', 'Analíticas avanzadas',
   'Palabras por día, sesiones, velocidad, racha y evolución histórica.',
   '', 'false'::jsonb, 'or', 50),
  ('atelier.automation', 'boolean', 'Automatizaciones',
   'Reglas disparador → condición → acción dentro del proyecto.',
   '', 'false'::jsonb, 'or', 60),
  ('atelier.automations.max', 'limit', 'Automatizaciones activas',
   'Cuántas reglas pueden estar encendidas a la vez.',
   'reglas', '0'::jsonb, 'max', 61),
  ('atelier.custom_fields', 'boolean', 'Campos personalizados',
   'Añadir campos propios a fichas, capítulos y elementos.',
   '', 'false'::jsonb, 'or', 62),
  ('atelier.templates.pro', 'boolean', 'Plantillas profesionales',
   'Novela ligera, guion, cómic, manga, novela visual, videojuego, RPG y más.',
   '', 'false'::jsonb, 'or', 63),
  ('atelier.editorial.manuscript', 'boolean', 'Producción editorial',
   'Modo manuscrito, front matter, back matter, metadatos y estilos editoriales.',
   '', 'false'::jsonb, 'or', 64),
  ('atelier.workspace', 'boolean', 'Workspaces',
   'Crear espacios de trabajo compartidos con roles y permisos.',
   '', 'false'::jsonb, 'or', 70),
  ('atelier.workspaces.max', 'limit', 'Workspaces propios',
   'Cuántos espacios de trabajo puede crear la cuenta.',
   'workspaces', '0'::jsonb, 'max', 71),
  ('atelier.workspace.seats.max', 'limit', 'Asientos por workspace',
   'Cuántos miembros activos admite el espacio de trabajo.',
   'asientos', '0'::jsonb, 'max', 72),
  ('atelier.roles.custom', 'boolean', 'Roles personalizados',
   'Definir roles propios combinando capacidades.',
   '', 'false'::jsonb, 'or', 73),
  ('atelier.audit_log', 'boolean', 'Registro de auditoría',
   'Quién cambió qué, cuándo y sobre qué objeto.',
   '', 'false'::jsonb, 'or', 74),
  ('atelier.publishing.submissions', 'boolean', 'Corvus Publishing Bureau',
   'Enviar un manuscrito a evaluación editorial. Los servicios se cotizan y pagan aparte del plan.',
   '', 'true'::jsonb, 'or', 80)
on conflict (key) do update set
  kind = excluded.kind,
  name = excluded.name,
  description = excluded.description,
  unit = excluded.unit,
  default_value = excluded.default_value,
  aggregation = excluded.aggregation,
  sort_order = excluded.sort_order;

-- ─── Derechos por plan ──────────────────────────────────────────────────────

-- Free: crear sin límite. Lo único acotado es infraestructura real.
insert into public.plan_entitlements (plan_code, feature_key, value) values
  ('free', 'atelier.projects.unlimited', 'true'::jsonb),
  ('free', 'atelier.worldbuilding', 'true'::jsonb),
  ('free', 'atelier.version_history.basic', 'true'::jsonb),
  ('free', 'atelier.version_history.advanced', 'false'::jsonb),
  ('free', 'atelier.version_history.max_snapshots', '10'::jsonb),
  ('free', 'atelier.backups.advanced', 'false'::jsonb),
  ('free', 'atelier.collaboration', 'true'::jsonb),
  ('free', 'atelier.collaborators.max', '1'::jsonb),
  ('free', 'atelier.comments', 'true'::jsonb),
  ('free', 'atelier.tasks.assign', 'false'::jsonb),
  ('free', 'atelier.storage.max_bytes', '2147483648'::jsonb),
  ('free', 'atelier.export.markdown', 'true'::jsonb),
  ('free', 'atelier.export.txt', 'true'::jsonb),
  ('free', 'atelier.export.json', 'true'::jsonb),
  ('free', 'atelier.export.docx', 'false'::jsonb),
  ('free', 'atelier.export.pdf', 'false'::jsonb),
  ('free', 'atelier.export.epub', 'false'::jsonb),
  ('free', 'atelier.export.project_bundle', 'false'::jsonb),
  ('free', 'atelier.analytics.advanced', 'false'::jsonb),
  ('free', 'atelier.automation', 'false'::jsonb),
  ('free', 'atelier.automations.max', '0'::jsonb),
  ('free', 'atelier.custom_fields', 'false'::jsonb),
  ('free', 'atelier.templates.pro', 'false'::jsonb),
  ('free', 'atelier.editorial.manuscript', 'false'::jsonb),
  ('free', 'atelier.workspace', 'false'::jsonb),
  ('free', 'atelier.workspaces.max', '0'::jsonb),
  ('free', 'atelier.workspace.seats.max', '0'::jsonb),
  ('free', 'atelier.roles.custom', 'false'::jsonb),
  ('free', 'atelier.audit_log', 'false'::jsonb),
  ('free', 'atelier.publishing.submissions', 'true'::jsonb),

  ('professional', 'atelier.projects.unlimited', 'true'::jsonb),
  ('professional', 'atelier.worldbuilding', 'true'::jsonb),
  ('professional', 'atelier.version_history.basic', 'true'::jsonb),
  ('professional', 'atelier.version_history.advanced', 'true'::jsonb),
  ('professional', 'atelier.version_history.max_snapshots', '-1'::jsonb),
  ('professional', 'atelier.backups.advanced', 'true'::jsonb),
  ('professional', 'atelier.collaboration', 'true'::jsonb),
  ('professional', 'atelier.collaborators.max', '10'::jsonb),
  ('professional', 'atelier.comments', 'true'::jsonb),
  ('professional', 'atelier.tasks.assign', 'true'::jsonb),
  ('professional', 'atelier.storage.max_bytes', '26843545600'::jsonb),
  ('professional', 'atelier.export.markdown', 'true'::jsonb),
  ('professional', 'atelier.export.txt', 'true'::jsonb),
  ('professional', 'atelier.export.json', 'true'::jsonb),
  ('professional', 'atelier.export.docx', 'true'::jsonb),
  ('professional', 'atelier.export.pdf', 'true'::jsonb),
  ('professional', 'atelier.export.epub', 'true'::jsonb),
  ('professional', 'atelier.export.project_bundle', 'true'::jsonb),
  ('professional', 'atelier.analytics.advanced', 'true'::jsonb),
  ('professional', 'atelier.automation', 'true'::jsonb),
  ('professional', 'atelier.automations.max', '25'::jsonb),
  ('professional', 'atelier.custom_fields', 'true'::jsonb),
  ('professional', 'atelier.templates.pro', 'true'::jsonb),
  ('professional', 'atelier.editorial.manuscript', 'true'::jsonb),
  ('professional', 'atelier.workspace', 'false'::jsonb),
  ('professional', 'atelier.workspaces.max', '0'::jsonb),
  ('professional', 'atelier.workspace.seats.max', '0'::jsonb),
  ('professional', 'atelier.roles.custom', 'false'::jsonb),
  ('professional', 'atelier.audit_log', 'false'::jsonb),
  ('professional', 'atelier.publishing.submissions', 'true'::jsonb),

  ('teams', 'atelier.projects.unlimited', 'true'::jsonb),
  ('teams', 'atelier.worldbuilding', 'true'::jsonb),
  ('teams', 'atelier.version_history.basic', 'true'::jsonb),
  ('teams', 'atelier.version_history.advanced', 'true'::jsonb),
  ('teams', 'atelier.version_history.max_snapshots', '-1'::jsonb),
  ('teams', 'atelier.backups.advanced', 'true'::jsonb),
  ('teams', 'atelier.collaboration', 'true'::jsonb),
  ('teams', 'atelier.collaborators.max', '50'::jsonb),
  ('teams', 'atelier.comments', 'true'::jsonb),
  ('teams', 'atelier.tasks.assign', 'true'::jsonb),
  ('teams', 'atelier.storage.max_bytes', '107374182400'::jsonb),
  ('teams', 'atelier.export.markdown', 'true'::jsonb),
  ('teams', 'atelier.export.txt', 'true'::jsonb),
  ('teams', 'atelier.export.json', 'true'::jsonb),
  ('teams', 'atelier.export.docx', 'true'::jsonb),
  ('teams', 'atelier.export.pdf', 'true'::jsonb),
  ('teams', 'atelier.export.epub', 'true'::jsonb),
  ('teams', 'atelier.export.project_bundle', 'true'::jsonb),
  ('teams', 'atelier.analytics.advanced', 'true'::jsonb),
  ('teams', 'atelier.automation', 'true'::jsonb),
  ('teams', 'atelier.automations.max', '100'::jsonb),
  ('teams', 'atelier.custom_fields', 'true'::jsonb),
  ('teams', 'atelier.templates.pro', 'true'::jsonb),
  ('teams', 'atelier.editorial.manuscript', 'true'::jsonb),
  ('teams', 'atelier.workspace', 'true'::jsonb),
  ('teams', 'atelier.workspaces.max', '3'::jsonb),
  ('teams', 'atelier.workspace.seats.max', '25'::jsonb),
  ('teams', 'atelier.roles.custom', 'true'::jsonb),
  ('teams', 'atelier.audit_log', 'true'::jsonb),
  ('teams', 'atelier.publishing.submissions', 'true'::jsonb)
on conflict (plan_code, feature_key) do nothing;

-- ─── Productos y precios ────────────────────────────────────────────────────
--
-- `provider_price_id` queda nulo a propósito: se rellena cuando exista el
-- precio real en Stripe (o Mercado Pago). Mientras tanto la pantalla de Planes
-- ya muestra importes correctos y el checkout responde PRICE_NOT_CONFIGURED
-- en vez de cobrar mal.

insert into public.billing_products (id, kind, plan_code, name, description, sort_order)
values
  ('atelier_professional', 'plan', 'professional', 'Atelier Professional',
   'Suscripción individual al taller profesional.', 1),
  ('atelier_teams', 'plan', 'teams', 'Atelier Teams',
   'Suscripción por workspace para estudios y editoriales.', 2)
on conflict (id) do update set
  name = excluded.name,
  description = excluded.description;

insert into public.billing_prices (
  id, product_id, provider, currency, unit_amount,
  billing_interval, is_default, sort_order, metadata
) values
  ('price_professional_monthly_mxn', 'atelier_professional', 'stripe', 'MXN',
   9900, 'month', true, 0, '{"label":"Mensual"}'::jsonb),
  ('price_professional_yearly_mxn', 'atelier_professional', 'stripe', 'MXN',
   99000, 'year', false, 1, '{"label":"Anual","free_months":2}'::jsonb),
  ('price_teams_monthly_mxn', 'atelier_teams', 'stripe', 'MXN',
   29900, 'month', true, 0, '{"label":"Mensual por workspace"}'::jsonb),
  ('price_teams_yearly_mxn', 'atelier_teams', 'stripe', 'MXN',
   299000, 'year', false, 1, '{"label":"Anual por workspace","free_months":2}'::jsonb)
on conflict (id) do nothing;
