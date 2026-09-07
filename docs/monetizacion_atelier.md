# Monetización de Corvus Atelier

Documento de entrega. Describe lo construido, lo que falta configurar a mano y
lo que queda pendiente.

La idea que ordena todo el sistema: **Atelier Free no limita el acto de crear**.
No hay tope de palabras, capítulos, personajes, mundos, notas ni proyectos en
ningún plan. Lo que se cobra es infraestructura con coste real —almacenamiento,
colaboración, historial profundo, producción editorial— y ninguna baja de plan
borra jamás contenido.

---

## 1. Arquitectura en una frase

**La decisión de qué puede hacer alguien vive en Postgres. Flutter la consume y
la cachea, nunca la toma.**

De ahí salen tres consecuencias que conviene no revertir:

- No existe ni un `if (user.isPro)` en la aplicación. Se pregunta por la
  función (`atelier.export.pdf`), nunca por el nivel. Mover una función de
  Professional a Free es una fila en `plan_entitlements`, no un cambio de
  código y un despliegue.
- Todo lo que mueve dinero o datos ajenos se vuelve a comprobar en el servidor:
  triggers de cuota sobre `storage.objects`, trigger de tope de colaboradores,
  políticas RLS por capacidad y RPC `security definer`.
- Precios, límites, features, add-ons y planes son datos editables desde
  administración. No hay ni una cifra comercial cableada en Dart salvo la tabla
  de comparación de la pantalla de Planes, que es material de marketing y no
  concede nada.

---

## 2. Archivos creados

### Migraciones SQL (`supabase/migrations/`, 4 363 líneas)

| Versión | Nombre | Qué introduce |
|---|---|---|
| `20260905052322` | `billing_foundation` | `plans`, `billing_products`, `billing_prices`, `billing_customers`, `billing_subscriptions`, `billing_subscription_items`, `billing_transactions`, `billing_events`, `entitlement_features`, `plan_entitlements`, `user_entitlements`, `workspace_entitlements` + RLS |
| `20260905052504` | `billing_catalog_seed` | Los tres planes, 30 features, 90 asignaciones plan→derecho, 2 productos y 4 precios |
| `20260905052711` | `atelier_workspaces` | `atelier_workspaces`, `_roles`, `_members`, `_permissions`, `atelier_invitations`, `atelier_audit_log`, resolución de capacidades, guardián de columnas |
| `20260905052809` | `entitlement_engine` | `resolve_entitlements`, `entitlement_value`, `has_entitlement`, `entitlement_limit`, `get_my_entitlements`, `get_workspace_entitlements` |
| `20260905053047` | `atelier_usage_and_storage` | Bucket privado `atelier`, `atelier_storage_usage`, `atelier_usage`, triggers de cuota y contabilidad, `get_atelier_usage` |
| `20260905053246` | `atelier_collaboration` | `atelier_project_collaborators`, `atelier_comments`, capacidades por proyecto, tope de colaboradores, RLS compartida |
| `20260905053554` | `atelier_professional_features` | Snapshots restaurables, `atelier_automations` + motor, `atelier_custom_fields`, `atelier_editorial_profiles` |
| `20260905053827` | `addons_flags_analytics` | `atelier_addons`, `atelier_addon_grants`, `atelier_purchases`, `feature_flags`, `feature_flag_overrides`, `billing_analytics_events` |
| `20260905054049` | `atelier_workspace_rpcs` | Crear espacio, invitar, responder, cambiar rol, retirar, roles propios, compartir proyecto |
| `20260905054155` | `publishing_bureau_scaffold` | `manuscript_submissions`, `editorial_quotes`, `publishing_service_orders`, `submit_manuscript` |
| `20260905060000` | `harden_billing_grants` | **Cierre de privilegios.** Ver §9 |
| `20260905070000` | `atelier_real_usage_counts` | `get_atelier_usage` devuelve recuentos reales de proyectos, colaboradores, automatizaciones, versiones y miembros |

Todas están aplicadas al proyecto `qqmzeapepoxadspupmuz` y registradas con esas
mismas versiones, de modo que `supabase migration list` las reconoce.

### Edge Functions (`supabase/functions/`)

```
_shared/http.ts                  respuestas {ok, reason_code}, CORS, URL de retorno segura
_shared/supabase.ts              cliente service_role y identificación del llamante
_shared/apply.ts                 traduce el estado del proveedor al de Corvus
_shared/providers/types.ts       la interfaz BillingProvider
_shared/providers/stripe.ts      Stripe por HTTP + verificación HMAC del webhook
_shared/providers/mercadopago.ts plaza reservada con la forma correcta
_shared/providers/index.ts       registro y proveedor por defecto
billing-checkout/index.ts        abre el cobro de un plan
billing-portal/index.ts          abre el portal del cliente
billing-manage/index.ts          cancelar · reactivar · cambiar de plan · resincronizar
billing-webhook/index.ts         avisos del proveedor, idempotentes
```

### Flutter (`lib/features/atelier/billing/`, 4 895 líneas)

```
domain/feature_keys.dart          llaves de derechos, capacidades, banderas y eventos
domain/billing_models.dart        Plan, PlanPrice, Entitlements, UsageSnapshot…
data/billing_repository.dart      catálogo + acciones contra las Edge Functions
data/entitlement_repository.dart  RPC de derechos, uso y versiones
data/entitlement_cache.dart       copia local con caducidad de 24 h
services/entitlement_service.dart hasEntitlement · getLimit · canUse · getUsage · checkQuota
services/billing_service.dart     checkout · portal · cancelar · reactivar · cambiar
services/usage_service.dart       subida con cuota, URL firmada, formato de bytes
services/workspace_service.dart   espacios, miembros, roles, invitaciones
services/export_service.dart      registro modular de formatos de exportación
services/exporters/docx_exporter  OOXML: manuscrito con formato editorial
services/exporters/epub_exporter  EPUB 3 con índice, portada y metadatos
services/exporters/pdf_exporter   maquetación con numeración y encabezado
services/exporters/bundle_exporter ZIP con manuscrito, capítulos y fichas
services/exporters/win_ansi.dart  puente tipográfico del PDF (ver §12)
services/exporters/xml_text.dart  escapado XML y nombres de archivo seguros
services/export_download*.dart    descarga real en web, portapapeles en el resto
data/editorial_repository.dart    páginas de cortesía del proyecto
domain/manuscript.dart            la obra vista como libro, no como grafo
presentation/plans_page.dart      la pantalla de Planes
presentation/billing_center_page  Settings › Facturación
presentation/export_sheet.dart    la hoja de exportación con sus puertas
presentation/workspaces_page.dart espacios, invitaciones pendientes, alta
presentation/workspace_detail_page administración de un estudio
widgets/entitlement_builder.dart  EntitlementBuilder · FeatureGate · FeatureNotice
widgets/upgrade_prompt.dart       el upsell contextual
widgets/plan_badge.dart           PlanBadge · FreeForeverNote
widgets/usage_indicator.dart      UsageIndicator · StorageIndicator
widgets/billing_status_card.dart  BillingStatusCard
widgets/billing_format.dart       fechas e importes en español
lib/providers/entitlement_provider.dart   el estado, la caché y los refrescos
```

### Pruebas

```
test/atelier_entitlements_test.dart     20 pruebas de evaluación de derechos
test/atelier_downgrade_test.dart        11 pruebas de «bajar de plan no borra nada»
test/atelier_billing_models_test.dart   12 pruebas de precios, formato y caché
test/atelier_export_formats_test.dart   24 pruebas de que los archivos exportados
                                        son archivos válidos de verdad
supabase/tests/monetizacion.sql         27 comprobaciones en el servidor
```

## 3. Archivos modificados

| Archivo | Cambio |
|---|---|
| `lib/main.dart` | `EntitlementProvider` en el árbol; carga al entrar y limpia la caché al salir |
| `lib/core/router/app_router.dart` | Rutas `/plans` (pública), `/settings/billing`, `/workspaces` y `/workspaces/:id` |
| `lib/core/rpc_error.dart` | ~45 `reason_code` nuevos traducidos a la voz de Corvus |
| `lib/features/atelier/atelier_page.dart` | `PlanBadge` en la barra, panel «Plan y espacio», hoja de exportación en vez del volcado JSON |
| `lib/features/home/home_shell.dart` | Entradas «Plan y facturación» y «Espacios de trabajo» en el menú Más |
| `test/public_routes_test.dart` | Fija que `/plans` es pública y que `/settings/billing` y `/workspaces` piden sesión |
| `pubspec.yaml` | `url_launcher` (checkout y portal), `web` (descarga), `archive` (DOCX, EPUB y ZIP), `pdf` (maquetación) |
| `supabase/config.toml` | Las cuatro funciones nuevas con `verify_jwt = false` |
| `test/atelier_page_test.dart` | `EntitlementProvider` en el montaje de la pantalla |

---

## 4. Variables de entorno (secretos de Supabase)

```bash
supabase secrets set STRIPE_SECRET_KEY=sk_live_...
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_...
supabase secrets set BILLING_PROVIDER=stripe
supabase secrets set BILLING_APP_URL=https://app.corvusaeternum.com
supabase secrets set BILLING_ALLOWED_ORIGINS=https://app.corvusaeternum.com
```

| Secreto | Para qué | Si falta |
|---|---|---|
| `STRIPE_SECRET_KEY` | Hablar con Stripe | `BILLING_PROVIDER_NOT_CONFIGURED` (503), la app lo dice y sigue funcionando |
| `STRIPE_WEBHOOK_SECRET` | Verificar la firma del aviso | El webhook responde 401 a todo |
| `BILLING_PROVIDER` | Elegir proveedor sin desplegar | Por defecto `stripe` |
| `BILLING_APP_URL` | Destino de vuelta tras el cobro | Por defecto `https://app.corvusaeternum.com` |
| `BILLING_ALLOWED_ORIGINS` | Lista blanca de destinos de retorno | Se ignoran los `success_url`/`return_url` del cliente y se usan los de `BILLING_APP_URL` |

`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` y `SUPABASE_ANON_KEY` los inyecta
Supabase automáticamente.

---

## 5. Configuración manual en Supabase

1. **Las funciones ya están desplegadas y verificadas.** Las cuatro responden
   con el contrato de Corvus:

   | Función | Sin credenciales responde |
   |---|---|
   | `billing-checkout` | `401 {"ok":false,"reason_code":"NOT_AUTHENTICATED"}` |
   | `billing-portal` | `401 {"ok":false,"reason_code":"NOT_AUTHENTICATED"}` |
   | `billing-manage` | `401 {"ok":false,"reason_code":"NOT_AUTHENTICATED"}` |
   | `billing-webhook` | `401 {"ok":false,"reason_code":"WEBHOOK_SIGNATURE_INVALID"}` |

   Las cuatro llevan `verify_jwt = false` en `config.toml`: identifican al
   llamante dentro de la función (`callerOf`) para poder devolver
   `{ok:false, reason_code}` en vez de un 401 opaco que Flutter no sabría
   traducir. El webhook no recibe JWT alguno: su autenticidad está en la firma
   HMAC.

   El repositorio sigue siendo la fuente canónica. Para redesplegar tras
   cualquier cambio:

   ```bash
   supabase functions deploy billing-checkout
   supabase functions deploy billing-portal
   supabase functions deploy billing-manage
   supabase functions deploy billing-webhook
   ```

2. **Encender el cobro cuando esté listo.** Todas las banderas nacen apagadas,
   de modo que hoy Atelier funciona exactamente igual que antes y nadie ve la
   pantalla de pago:

   ```sql
   -- Sólo para un puñado de cuentas primero
   insert into public.feature_flag_overrides (flag_key, profile_id, is_enabled)
   values ('billing', '<uuid del perfil>', true);

   -- O por porcentaje, estable por persona
   update public.feature_flags
     set is_enabled = true, rollout_percentage = 10
   where key in ('billing', 'professional');
   ```

3. **El bucket `atelier`** ya está creado, privado y con tope de 200 MB por
   archivo. Es privado a propósito: ahí viven manuscritos sin publicar, y se
   sirven con URL firmada.

## 6. Configuración manual en Stripe

1. Crear en Stripe dos productos y cuatro precios recurrentes en MXN:
   Professional 99/mes y 990/año, Teams 299/mes y 2 990/año.
2. Copiar cada `price_...` a la fila correspondiente:

   ```sql
   update public.billing_prices set provider_price_id = 'price_...'
   where id = 'price_professional_monthly_mxn';
   -- y así con las otras tres
   ```

   Hasta que ese campo esté relleno, el checkout responde
   `BILLING_PRICE_NOT_CONFIGURED` en lugar de cobrar mal.
3. Webhook apuntando a
   `https://qqmzeapepoxadspupmuz.supabase.co/functions/v1/billing-webhook`
   con los eventos `checkout.session.completed`,
   `customer.subscription.created|updated|deleted`,
   `invoice.paid`, `invoice.payment_failed`.
4. Activar el *Customer Portal* en Stripe (el botón «Gestionar facturación» lo
   abre; sin él, Stripe devuelve error).

**Mercado Pago** tiene su plaza reservada en `_shared/providers/mercadopago.ts`
con la forma correcta. Implementar sus métodos contra la API de Preapproval y
cambiar `BILLING_PROVIDER` no exige tocar el esquema, las RPC ni Flutter.

---

## 7. Flujo completo de suscripción

```
Alguien pulsa un candado en Atelier
  → showUpgradePrompt (contextual, dos botones, sin cuenta atrás)
  → /plans?feature=atelier.export.pdf
  → BillingService.startCheckout(priceId)
      → Edge billing-checkout
          · comprueba la bandera `billing` para esa cuenta
          · lee precio, producto y plan de la BASE (nunca del cuerpo)
          · para un plan de workspace exige `billing.manage`
          · crea o recupera el cliente en el proveedor
          · abre la sesión con metadata corvus_user_id / plan_code / price_id
      → redirección al checkout de Stripe
  → el artista paga
  → Stripe → billing-webhook
      · verifica la firma HMAC y la ventana de 5 minutos
      · inserta en billing_events (único por provider_event_id = idempotencia)
      · applySubscription: resuelve titular y plan, cierra la anterior si la
        hubiera, hace upsert de la suscripción, refleja el plan del workspace
      · applyTransaction: guarda la factura
  → vuelta a /settings/billing?checkout=ok
  → EntitlementProvider.refreshAfterCheckout() reintenta hasta 3 veces
  → los derechos nuevos ya están activos en toda la aplicación
```

Cancelar, reactivar y cambiar de plan pasan por `billing-manage`, que **le pide
el cambio al proveedor y guarda lo que el proveedor devuelve**. Corvus nunca
decide por su cuenta que alguien está activo: tener dos verdades sobre el
mismo cobro es cómo se acaba cobrando distinto de lo que la app enseña.

La cancelación es siempre al final del periodo. Quien ya pagó el mes lo usa
entero.

---

## 8. Esquema de derechos

Resolución, de menos a más autoridad:

1. `entitlement_features.default_value` — lo que vale sin plan alguno.
2. `plan_entitlements` del plan vigente (y del plan del workspace, si se
   pregunta dentro de uno: nadie pierde derechos por entrar en un estudio).
3. `user_entitlements` / `workspace_entitlements` vivos — add-ons comprados,
   cortesías, promociones. `mode='add'` suma; `mode='set'` compite y gana el
   mejor según `aggregation`.

`-1` significa ilimitado y gana a cualquier cifra.

| Derecho | Free | Professional | Teams |
|---|---|---|---|
| `atelier.projects.unlimited` | ✓ | ✓ | ✓ |
| `atelier.worldbuilding` | ✓ | ✓ | ✓ |
| `atelier.version_history.basic` | ✓ | ✓ | ✓ |
| `atelier.version_history.advanced` | — | ✓ | ✓ |
| `atelier.version_history.max_snapshots` | 10 | ∞ | ∞ |
| `atelier.backups.advanced` | — | ✓ | ✓ |
| `atelier.collaboration` | ✓ | ✓ | ✓ |
| `atelier.collaborators.max` | 1 | 10 | 50 |
| `atelier.comments` | ✓ | ✓ | ✓ |
| `atelier.tasks.assign` | — | ✓ | ✓ |
| `atelier.storage.max_bytes` | 2 GB | 25 GB | 100 GB |
| `atelier.export.markdown` / `.txt` / `.json` | ✓ | ✓ | ✓ |
| `atelier.export.docx` / `.pdf` / `.epub` / `.project_bundle` | — | ✓ | ✓ |
| `atelier.analytics.advanced` | — | ✓ | ✓ |
| `atelier.automation` | — | ✓ | ✓ |
| `atelier.automations.max` | 0 | 25 | 100 |
| `atelier.custom_fields` | — | ✓ | ✓ |
| `atelier.templates.pro` | — | ✓ | ✓ |
| `atelier.editorial.manuscript` | — | ✓ | ✓ |
| `atelier.workspace` | — | — | ✓ |
| `atelier.workspaces.max` | 0 | 0 | 3 |
| `atelier.workspace.seats.max` | 0 | 0 | 25 |
| `atelier.roles.custom` | — | — | ✓ |
| `atelier.audit_log` | — | — | ✓ |
| `atelier.publishing.submissions` | ✓ | ✓ | ✓ |

Las seis filas en negrita del producto —proyectos, worldbuilding, versionado
básico y las tres exportaciones de portabilidad— están además blindadas en
`EntitlementService.protectedFeatures` y hay una prueba que falla si alguien
intenta ponerles precio.

### Capacidades (workspaces y proyectos compartidos)

`project.read` · `project.write` · `project.create` · `project.delete` ·
`member.invite` · `member.remove` · `member.manage` · `role.manage` ·
`billing.manage` · `export.create` · `comment.create` · `comment.resolve` ·
`task.assign` · `automation.manage` · `template.manage` · `settings.manage` ·
`workspace.manage` · `audit.read`

Roles del sistema: `owner`, `admin`, `editor`, `writer`, `reviewer`, `viewer`.
Un rol es un atajo con nombre para un conjunto de capacidades, y Teams puede
definir los suyos. `billing.manage` no se delega con un rol personalizado: el
dinero lo mueve quien lo paga.

---

## 9. Un agujero encontrado y cerrado

Supabase aplica `alter default privileges … grant all on tables to anon,
authenticated` en el esquema `public`. Es decir: **cada tabla nueva nace con
INSERT, UPDATE, DELETE y TRUNCATE concedidos a la llave publicable**, y lo único
que la separa de un `delete from billing_subscriptions` es que la RLS no
encuentre una política permisiva. Una sola línea de defensa para datos de
facturación.

Lo mismo con `EXECUTE` sobre funciones: `atelier_share_project` y
`submit_manuscript` eran invocables por un visitante sin sesión.

`20260905060000_harden_billing_grants` revoca todo sobre las 35 tablas nuevas y
las 46 funciones nuevas, y vuelve a conceder únicamente lo que la aplicación
usa. Es el mismo movimiento que la migración
`close_user_roles_escalation_and_anon_writes` hizo en su día para el resto del
archivo.

---

## 10. Pruebas realizadas

**Flutter — 194 pruebas, todas en verde** (124 previas + 70 nuevas).

- Evaluación de derechos en los tres planes, límites, ilimitado, distinción
  entre «no incluido» y «tope alcanzado».
- Cuota de almacenamiento y sus avisos escalonados en 80 % / 95 % / 100 %.
- La lista blindada: escribir, construir mundos y exportar siguen abiertos en
  Free.
- **Downgrade no destructivo**: el taller entero antes y después, el texto
  palabra por palabra, la exportación completa sin suscripción, quedar por
  encima de cuota, y reactivar.
- Aritmética de precios y ahorro anual, formato de bytes, dinero y fechas.
- Ida y vuelta de la caché de derechos.
- **Los archivos exportados se abren y se inspeccionan**, no basta con que la
  función no lance: el DOCX lleva las seis partes que Word exige y su formato
  de manuscrito; el EPUB tiene el `mimetype` primero y sin comprimir, con su
  `nav` de EPUB 3; el PDF empieza por `%PDF-` y cierra con `%%EOF`; el paquete
  trae el LÉEME, los capítulos sueltos y las fichas del mundo. Y el texto con
  `&`, `<` y `>` viaja escapado en todos ellos.

**Servidor — 27 comprobaciones, todas en verde** (`supabase/tests/monetizacion.sql`,
ejecutado sobre el proyecto real y revertido íntegramente):

resolución por plan · add-on que suma · cortesía que compite · derecho caducado ·
contabilidad de subida · liberación al borrar · ruta sin dueño rechazada ·
Free rechaza 3 GB sobre 2 GB · tope de colaboradores · creación de espacio ·
capacidad del propietario · denegación explícita que gana al rol · permiso
inventado rechazado · `billing.manage` no delegable · aviso duplicado
rechazado · cancelada vuelve a Free · `past_due` NO cierra el acceso ·
**expirar no borra ningún nodo** · los proyectos siguen ahí · catálogo público
visible · `anon` no alcanza suscripciones, pagos ni RPC · banderas no legibles
desde la tabla · nadie se regala un plan · nadie se concede un derecho.

**Despliegue** — las cuatro Edge Functions están vivas y probadas con petición
real (tabla en §5). El RPC de uso se verificó con un ensayo revertido que creó
un colaborador, una automatización y una versión, y devolvió las cifras
correctas; de paso ejercitó `atelier_create_snapshot` de extremo a extremo.

`flutter analyze`: sin incidencias. `flutter build web`: correcto.

---

## 11. Riesgos y pendientes

**Alto**

- *El webhook nunca se ha ejecutado con una firma válida de Stripe.* Está
  desplegado y rechaza correctamente lo no firmado, pero sin
  `STRIPE_WEBHOOK_SECRET` la ruta de verificación no puede probarse. Antes de
  abrir la bandera `billing` a nadie, un ensayo con
  `stripe listen --forward-to https://qqmzeapepoxadspupmuz.supabase.co/functions/v1/billing-webhook`
  y un `stripe trigger checkout.session.completed`.

**Medio**

- *La descarga de exportaciones sólo funciona en web.* En móvil y escritorio,
  Markdown, TXT y JSON caen en copiar al portapapeles, y los cuatro formatos
  binarios avisan de que por ahora solo se descargan desde la web en lugar de
  fingir que funcionaron. Resolverlo pide `path_provider` y un selector de
  carpeta.
- *El PDF usa las fuentes estándar, sin incrustar tipografía.* Cubre el español
  entero (ver §12) y mantiene el archivo ligero, pero un manuscrito con griego,
  cirílico o CJK verá interrogantes. La salida es incrustar un TTF Unicode en
  `assets/` y pasarlo al tema del exportador: una línea, más el peso del
  archivo.
- *Los add-ons no tienen checkout propio.* El modelo, la aplicación de derechos
  (`atelier_apply_purchase`) y la revocación están hechos y probados, pero
  falta crear sus productos en Stripe y la pantalla de compra.
- *La administración de workspaces cubre lo esencial, no todo.* Crear espacio,
  invitar, aceptar, cambiar papel y retirar están completos en `/workspaces`.
  Queda fuera el editor visual de roles personalizados (`atelier_upsert_role`
  existe y está probada, pero se invoca por SQL) y la vista del registro de
  auditoría, que se lee de `atelier_audit_log`.

**Bajo**

- `atelier_versions` guarda ahora una copia completa del proyecto en cada
  snapshot. Es texto y comprime bien, pero conviene vigilar el tamaño de la
  tabla en proyectos muy largos y, llegado el caso, mover la copia a Storage.
- El motor de automatizaciones se dispara `before insert or update` sobre
  `atelier_nodes` y se protege de cascadas con `pg_trigger_depth()`. Sirve para
  reglas simples; un flujo con muchas acciones encadenadas pedirá una cola.
- La analítica se escribe con una lista blanca de eventos y de propiedades. Si
  se añade un evento nuevo en Dart hay que añadirlo también a
  `record_billing_event`, o el servidor lo rechaza en silencio.

---

## 12. Un segundo fallo encontrado: la raya de diálogo rompía el PDF

Vale la pena dejarlo escrito porque no se deduce de ninguna documentación y
habría llegado a producción.

Las fuentes estándar de un PDF declaran `WinAnsiEncoding` (CP-1252), pero
`dart_pdf` codifica las cadenas con `latin1.encode`. Las dos tablas coinciden
salvo en el rango `0x80–0x9F`, que es justo donde CP-1252 guarda los caracteres
tipográficos. Y `latin1.encode` **no degrada: lanza**.

La consecuencia práctica: cualquier manuscrito con una raya —U+2014, el
marcador de diálogo del español—

```
—¿Quién anda ahí? —preguntó Vela.
```

habría reventado la exportación a PDF con una excepción. Es decir, casi
cualquier novela en español escrita en Corvus.

`services/exporters/win_ansi.dart` traduce cada carácter a su byte de CP-1252
antes de entregárselo al motor, de modo que el visor —al que ya se le dijo que
lea WinAnsi— pinta la raya de verdad. Sin fuentes incrustadas y sin perder
tipografía. Lo que no cabe ni así —un emoji, un ideograma— se marca con `?` en
vez de tumbar el archivo entero: perder un carácter exótico es preferible a
perder el manuscrito.

DOCX, EPUB y el paquete no pasan por este puente: son XML en UTF-8 y conservan
la tipografía tal cual. Las pruebas fijan las dos cosas.
