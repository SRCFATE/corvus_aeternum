-- Corvus Atelier — cierre de privilegios sobre lo recién creado.
--
-- Supabase aplica `alter default privileges ... grant all on tables to anon,
-- authenticated` en el esquema public. Es decir: cada tabla nueva nace con
-- INSERT, UPDATE, DELETE y TRUNCATE concedidos a la llave publicable, y lo
-- único que la separa de un `delete from billing_subscriptions` es que la RLS
-- no encuentre una política permisiva. Eso es una sola línea de defensa para
-- datos de facturación.
--
-- Este archivo repite para el módulo comercial lo que
-- `close_user_roles_escalation_and_anon_writes` hizo en su día para el resto
-- del archivo: revocar todo y volver a conceder únicamente lo que la app usa.
--
-- Lo mismo con las funciones: el privilegio por defecto de EXECUTE alcanza a
-- `anon`, así que un visitante sin sesión podía invocar `atelier_share_project`
-- o `submit_manuscript`. Devuelven NOT_AUTHENTICATED, pero no deberían ni
-- llegar a ejecutarse.

do $mig$
declare
  t text;
  tablas constant text[] := array[
    'plans', 'billing_products', 'billing_prices', 'billing_customers',
    'billing_subscriptions', 'billing_subscription_items', 'billing_transactions',
    'billing_events', 'entitlement_features', 'plan_entitlements',
    'user_entitlements', 'workspace_entitlements',
    'atelier_workspaces', 'atelier_workspace_roles', 'atelier_workspace_members',
    'atelier_workspace_permissions', 'atelier_invitations', 'atelier_audit_log',
    'atelier_storage_usage', 'atelier_usage', 'atelier_project_collaborators',
    'atelier_comments', 'atelier_automations', 'atelier_automation_runs',
    'atelier_custom_fields', 'atelier_editorial_profiles',
    'atelier_addons', 'atelier_addon_grants', 'atelier_purchases',
    'feature_flags', 'feature_flag_overrides', 'billing_analytics_events',
    'manuscript_submissions', 'editorial_quotes', 'publishing_service_orders'
  ];
begin
  foreach t in array tablas loop
    execute format(
      'revoke all on public.%I from anon, authenticated', t
    );
  end loop;
end $mig$;

-- ─── Catálogo: lectura abierta ──────────────────────────────────────────────
--
-- La pantalla de Planes tiene que poder verse sin sesión: quien evalúa Corvus
-- antes de registrarse merece saber lo que cuesta.

grant select on public.plans to anon, authenticated;
grant select on public.billing_products to anon, authenticated;
grant select on public.billing_prices to anon, authenticated;
grant select on public.entitlement_features to anon, authenticated;
grant select on public.plan_entitlements to anon, authenticated;
grant select on public.atelier_addons to anon, authenticated;
grant select on public.atelier_addon_grants to anon, authenticated;

-- ─── Estado propio: solo lectura ────────────────────────────────────────────

grant select on public.billing_customers to authenticated;
grant select on public.billing_subscriptions to authenticated;
grant select on public.billing_subscription_items to authenticated;
grant select on public.billing_transactions to authenticated;
grant select on public.user_entitlements to authenticated;
grant select on public.atelier_purchases to authenticated;
grant select on public.atelier_storage_usage to authenticated;
grant select on public.atelier_usage to authenticated;
grant select on public.atelier_workspace_roles to authenticated;
grant select on public.atelier_workspace_members to authenticated;
grant select on public.atelier_workspace_permissions to authenticated;
grant select on public.atelier_invitations to authenticated;
grant select on public.atelier_audit_log to authenticated;
grant select on public.atelier_project_collaborators to authenticated;
grant select on public.atelier_automation_runs to authenticated;
grant select on public.manuscript_submissions to authenticated;
grant select on public.editorial_quotes to authenticated;
grant select on public.publishing_service_orders to authenticated;

-- ─── Lo que la app sí escribe ───────────────────────────────────────────────
--
-- Renombrar el espacio (el guardián de columnas impide tocar plan y dueño),
-- comentar, y las tres tablas de trabajo Professional, todas con su política.

grant select, update on public.atelier_workspaces to authenticated;
grant select, insert, update on public.atelier_comments to authenticated;
grant select, insert, update, delete on public.atelier_automations to authenticated;
grant select, insert, update, delete on public.atelier_custom_fields to authenticated;
grant select, insert, update, delete on public.atelier_editorial_profiles to authenticated;

-- Sin concesión alguna, a propósito: billing_events (cargas del proveedor),
-- workspace_entitlements y billing_analytics_events (se leen por RPC o con
-- service_role), feature_flags y feature_flag_overrides (el mapa de lo que aún
-- no se ha lanzado no se enseña).

-- ─── Funciones ──────────────────────────────────────────────────────────────

do $mig$
declare
  f record;
  nombres constant text[] := array[
    'entitlement_is_unlimited', 'entitlement_combine', 'entitlement_add',
    'atelier_user_plan', 'atelier_workspace_plan', 'resolve_entitlements',
    'entitlement_value', 'has_entitlement', 'entitlement_limit',
    'get_my_entitlements', 'get_workspace_entitlements',
    'atelier_workspace_capabilities', 'atelier_has_capability',
    'atelier_is_workspace_member', 'atelier_guard_workspace_columns',
    'atelier_storage_owner', 'atelier_storage_limit', 'atelier_storage_account',
    'atelier_storage_enforce_quota', 'get_atelier_usage',
    'atelier_project_capabilities', 'atelier_can_read_project',
    'atelier_can_write_project', 'atelier_enforce_collaborator_limit',
    'atelier_create_snapshot', 'get_atelier_versions', 'atelier_restore_version',
    'atelier_condition_matches', 'atelier_dispatch_automations',
    'atelier_enforce_custom_fields', 'atelier_enforce_editorial',
    'atelier_apply_purchase', 'atelier_revoke_purchase',
    'is_feature_enabled', 'get_feature_flags', 'record_billing_event',
    'atelier_log', 'atelier_create_workspace', 'atelier_invite_to_workspace',
    'atelier_respond_invitation', 'atelier_set_member_role',
    'atelier_remove_member', 'atelier_upsert_role',
    'atelier_share_project', 'atelier_unshare_project', 'submit_manuscript'
  ];
begin
  for f in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = any (nombres)
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f.sig);
  end loop;
end $mig$;

-- Las cinco que evalúan las políticas RLS: sin EXECUTE para `authenticated`,
-- cada SELECT sobre Atelier fallaría con «permission denied for function».
grant execute on function public.atelier_is_workspace_member(uuid, uuid) to authenticated;
grant execute on function public.atelier_has_capability(uuid, text, uuid) to authenticated;
grant execute on function public.atelier_can_read_project(uuid, uuid) to authenticated;
grant execute on function public.atelier_can_write_project(uuid, uuid) to authenticated;
grant execute on function public.atelier_project_capabilities(uuid, uuid) to authenticated;

-- Las RPC que la app llama por su nombre.
grant execute on function public.get_my_entitlements() to authenticated;
grant execute on function public.get_workspace_entitlements(uuid) to authenticated;
grant execute on function public.get_atelier_usage(uuid) to authenticated;
grant execute on function public.get_atelier_versions(uuid) to authenticated;
grant execute on function public.get_feature_flags() to authenticated;
grant execute on function public.record_billing_event(text, jsonb) to authenticated;
grant execute on function public.atelier_create_snapshot(uuid, text, text, text) to authenticated;
grant execute on function public.atelier_restore_version(uuid) to authenticated;
grant execute on function public.atelier_create_workspace(text, text) to authenticated;
grant execute on function public.atelier_invite_to_workspace(uuid, uuid, text, text, text) to authenticated;
grant execute on function public.atelier_respond_invitation(uuid, boolean) to authenticated;
grant execute on function public.atelier_set_member_role(uuid, uuid, text) to authenticated;
grant execute on function public.atelier_remove_member(uuid, uuid) to authenticated;
grant execute on function public.atelier_upsert_role(uuid, text, text, text[], text) to authenticated;
grant execute on function public.atelier_share_project(uuid, uuid, text) to authenticated;
grant execute on function public.atelier_unshare_project(uuid, uuid) to authenticated;
grant execute on function public.submit_manuscript(uuid, text[], text) to authenticated;
