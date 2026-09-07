-- Pruebas del sistema de monetización de Corvus Atelier.
--
-- Se ejecuta entero sobre el proyecto y **no deja nada**: la última línea lanza
-- una excepción a propósito, así que toda la transacción se revierte. El
-- informe se lee en el mensaje de esa excepción.
--
--   psql "$DATABASE_URL" -f supabase/tests/monetizacion.sql
--
-- O pegándolo en el editor SQL de Supabase. Comprueba la mitad que de verdad
-- protege el negocio: la que vive en el servidor y que un cliente adulterado
-- no puede saltarse. Las pruebas de evaluación en cliente están en
-- `test/atelier_entitlements_test.dart` y `test/atelier_downgrade_test.dart`.
--
-- Necesita al menos una cuenta en `auth.users` y, para la prueba de
-- colaboradores, dos cuentas y un proyecto de Atelier.

do $prueba$
declare
  v_autora uuid;
  v_colega uuid;
  v_proyecto uuid;
  v_nodos_antes integer;
  v_nodos_despues integer;
  v_workspace uuid;
  v_sub uuid;
  v_r jsonb;
  v_bytes bigint;
  v_texto text;
  v_ok boolean;
  v_n integer;
  r text := '';
  pasa constant text := ' [OK] ';
  falla constant text := ' [FALLO] ';
begin
  select id into v_autora from auth.users order by created_at limit 1;
  select id into v_colega from auth.users order by created_at desc limit 1;

  if v_autora is null then
    raise exception 'La prueba necesita al menos una cuenta en auth.users.';
  end if;

  -- ─── Resolución de derechos por plan ──────────────────────────────────────

  v_r := public.resolve_entitlements(v_autora, null);
  r := r || case when v_r->'plan'->>'code' = 'free'
                 and (v_r->'features'->>'atelier.storage.max_bytes') = '2147483648'
                 and (v_r->'features'->>'atelier.export.pdf') = 'false'
                 and (v_r->'features'->>'atelier.projects.unlimited') = 'true'
            then pasa else falla end || 'sin suscripcion resuelve Free' || E'\n';

  insert into public.billing_subscriptions (
    user_id, plan_code, status, provider, provider_subscription_id, current_period_end
  ) values (
    v_autora, 'professional', 'active', 'manual', 'test_sub_pro', now() + interval '30 days'
  ) returning id into v_sub;

  v_r := public.resolve_entitlements(v_autora, null);
  r := r || case when v_r->'plan'->>'code' = 'professional'
                 and (v_r->'features'->>'atelier.export.pdf') = 'true'
                 and (v_r->'features'->>'atelier.collaborators.max') = '10'
                 and (v_r->'features'->>'atelier.version_history.max_snapshots') = '-1'
            then pasa else falla end || 'suscripcion activa concede Professional' || E'\n';

  -- ─── Add-ons y concesiones ────────────────────────────────────────────────

  insert into public.user_entitlements (user_id, feature_key, value, mode, source)
  values (v_autora, 'atelier.storage.max_bytes', '53687091200'::jsonb, 'add', 'addon');
  v_bytes := public.entitlement_limit(v_autora, 'atelier.storage.max_bytes', null);
  r := r || case when v_bytes = 80530636800 then pasa else falla end
       || 'add-on de 50 GB se suma al plan (= ' || v_bytes || ')' || E'\n';

  insert into public.user_entitlements (user_id, feature_key, value, mode, source)
  values (v_autora, 'atelier.collaborators.max', '-1'::jsonb, 'set', 'grant');
  r := r || case when public.entitlement_limit(v_autora, 'atelier.collaborators.max', null) = -1
            then pasa else falla end || 'cortesia ilimitada gana al tope del plan' || E'\n';

  insert into public.user_entitlements (
    user_id, feature_key, value, mode, source, starts_at, expires_at
  ) values (
    v_autora, 'atelier.audit_log', 'true'::jsonb, 'set', 'promo',
    now() - interval '10 days', now() - interval '1 day'
  );
  r := r || case when not public.has_entitlement(v_autora, 'atelier.audit_log', null)
            then pasa else falla end || 'derecho caducado deja de conceder' || E'\n';

  -- ─── Cuota de almacenamiento ──────────────────────────────────────────────

  insert into storage.objects (bucket_id, name, metadata)
  values ('atelier', 'u/' || v_autora || '/p/uno.bin', jsonb_build_object('size', 1073741824));
  select bytes_used into v_bytes from public.atelier_storage_usage
  where scope = 'user' and owner_id = v_autora;
  r := r || case when v_bytes = 1073741824 then pasa else falla end
       || 'la subida se contabiliza en su bolsa' || E'\n';

  -- Supabase protege storage.objects contra borrados directos; la API del
  -- Storage levanta este mismo flag, así que el trigger de contabilidad se
  -- comporta igual en producción.
  perform set_config('storage.allow_delete_query', 'true', true);
  delete from storage.objects
  where bucket_id = 'atelier' and name = 'u/' || v_autora || '/p/uno.bin';
  select coalesce(bytes_used, 0) into v_bytes from public.atelier_storage_usage
  where scope = 'user' and owner_id = v_autora;
  r := r || case when v_bytes = 0 then pasa else falla end
       || 'borrar devuelve el espacio' || E'\n';
  perform set_config('storage.allow_delete_query', 'false', true);

  begin
    insert into storage.objects (bucket_id, name, metadata)
    values ('atelier', 'suelto.bin', jsonb_build_object('size', 10));
    v_ok := false;
  exception when others then v_ok := true;
  end;
  r := r || case when v_ok then pasa else falla end || 'ruta sin dueno rechazada' || E'\n';

  update public.billing_subscriptions set plan_code = 'free' where id = v_sub;
  delete from public.user_entitlements
  where user_id = v_autora and feature_key = 'atelier.storage.max_bytes';
  begin
    insert into storage.objects (bucket_id, name, metadata)
    values ('atelier', 'u/' || v_autora || '/p/enorme.bin',
            jsonb_build_object('size', 3221225472));
    v_ok := false;
  exception when sqlstate '53100' then v_ok := true;
  end;
  r := r || case when v_ok then pasa else falla end
       || 'Free rechaza 3 GB sobre una cuota de 2 GB' || E'\n';
  update public.billing_subscriptions set plan_code = 'professional' where id = v_sub;

  -- ─── Colaboradores ────────────────────────────────────────────────────────

  select id into v_proyecto from public.atelier_projects where profile_id = v_autora limit 1;
  if v_proyecto is not null and v_colega is distinct from v_autora then
    delete from public.user_entitlements
    where user_id = v_autora and feature_key = 'atelier.collaborators.max';
    update public.billing_subscriptions set plan_code = 'free' where id = v_sub;
    begin
      insert into public.atelier_project_collaborators
        (project_id, profile_id, role_key, status)
      values (v_proyecto, v_colega, 'reviewer', 'active');
      v_ok := true;
    exception when others then v_ok := false; v_texto := sqlerrm;
    end;
    r := r || case when v_ok then pasa else falla end
         || 'Free admite su colaborador' || coalesce(' (' || v_texto || ')', '') || E'\n';
    update public.billing_subscriptions set plan_code = 'professional' where id = v_sub;
  else
    r := r || ' [OMITIDO] colaboradores (falta proyecto o segunda cuenta)' || E'\n';
  end if;

  -- ─── Workspaces y capacidades ─────────────────────────────────────────────

  update public.billing_subscriptions set plan_code = 'teams' where id = v_sub;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_autora, 'role', 'authenticated')::text, true);

  v_r := public.atelier_create_workspace('Editorial de prueba', 'prueba-editorial');
  v_workspace := (v_r->>'workspace_id')::uuid;
  r := r || case when v_r->>'ok' = 'true' then pasa else falla end
       || 'Teams crea espacio (' || coalesce(v_r->>'reason_code', 'ok') || ')' || E'\n';

  if v_workspace is not null then
    r := r || case when public.atelier_has_capability(v_workspace, 'billing.manage', v_autora)
              then pasa else falla end
         || 'el propietario administra su facturacion' || E'\n';

    insert into public.atelier_workspace_permissions
      (workspace_id, profile_id, capability, effect)
    values (v_workspace, v_autora, 'export.create', 'deny');
    r := r || case when not public.atelier_has_capability(v_workspace, 'export.create', v_autora)
              then pasa else falla end
         || 'una denegacion explicita gana al rol' || E'\n';

    v_r := public.atelier_upsert_role(
      v_workspace, 'lector_beta', 'Lector beta',
      array['project.read', 'permiso.inventado']
    );
    r := r || case when v_r->>'reason_code' = 'ATELIER_CAPABILITY_UNKNOWN'
              then pasa else falla end || 'permiso inventado rechazado' || E'\n';

    v_r := public.atelier_upsert_role(
      v_workspace, 'tesorero', 'Tesorero', array['billing.manage']
    );
    r := r || case when v_r->>'reason_code' = 'ATELIER_CAPABILITY_RESERVED'
              then pasa else falla end || 'billing.manage no se delega' || E'\n';
  end if;

  -- ─── Idempotencia del webhook ─────────────────────────────────────────────

  insert into public.billing_events (provider, provider_event_id, event_type, payload)
  values ('stripe', 'evt_prueba_1', 'customer.subscription.updated', '{}'::jsonb);
  begin
    insert into public.billing_events (provider, provider_event_id, event_type, payload)
    values ('stripe', 'evt_prueba_1', 'customer.subscription.updated', '{}'::jsonb);
    v_ok := false;
  exception when unique_violation then v_ok := true;
  end;
  r := r || case when v_ok then pasa else falla end || 'aviso duplicado rechazado' || E'\n';

  -- ─── Estados de suscripción ───────────────────────────────────────────────

  update public.billing_subscriptions set status = 'canceled', ended_at = now() where id = v_sub;
  v_r := public.resolve_entitlements(v_autora, null);
  r := r || case when v_r->'plan'->>'code' = 'free' then pasa else falla end
       || 'cancelada devuelve a Free' || E'\n';

  update public.billing_subscriptions set status = 'past_due' where id = v_sub;
  v_r := public.resolve_entitlements(v_autora, null);
  r := r || case when v_r->'plan'->>'code' = 'teams' then pasa else falla end
       || 'past_due NO cierra el acceso' || E'\n';

  -- ─── La prueba que más importa ────────────────────────────────────────────

  select count(*) into v_nodos_antes from public.atelier_nodes;
  update public.billing_subscriptions set status = 'expired', ended_at = now() where id = v_sub;
  select count(*) into v_nodos_despues from public.atelier_nodes;
  r := r || case when v_nodos_antes = v_nodos_despues and v_nodos_antes > 0
            then pasa else falla end
       || 'expirar no borra ningun nodo (' || v_nodos_antes || ' -> ' || v_nodos_despues || ')' || E'\n';

  select count(*) into v_n from public.atelier_projects;
  r := r || case when v_n > 0 then pasa else falla end || 'los proyectos siguen ahi' || E'\n';

  -- ─── RLS y privilegios ────────────────────────────────────────────────────

  set local role anon;
  begin select count(*) into v_n from public.plans; v_ok := v_n > 0;
  exception when others then v_ok := false; end;
  r := r || case when v_ok then pasa else falla end || 'el catalogo se ve sin sesion' || E'\n';

  begin select count(*) into v_n from public.billing_subscriptions; v_ok := false;
  exception when insufficient_privilege then v_ok := true; end;
  r := r || case when v_ok then pasa else falla end || 'anon no alcanza las suscripciones' || E'\n';

  begin select count(*) into v_n from public.billing_transactions; v_ok := false;
  exception when insufficient_privilege then v_ok := true; end;
  r := r || case when v_ok then pasa else falla end || 'anon no alcanza los pagos' || E'\n';

  begin perform public.atelier_create_workspace('Espacio pirata'); v_ok := false;
  exception when insufficient_privilege then v_ok := true; end;
  r := r || case when v_ok then pasa else falla end || 'anon no invoca las RPC de Atelier' || E'\n';

  reset role;

  set local role authenticated;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_autora, 'role', 'authenticated')::text, true);

  begin select count(*) into v_n from public.feature_flags; v_ok := false;
  exception when insufficient_privilege then v_ok := true; end;
  r := r || case when v_ok then pasa else falla end || 'las banderas no se leen de la tabla' || E'\n';

  begin
    update public.billing_subscriptions set plan_code = 'teams' where id = v_sub;
    get diagnostics v_n = row_count;
    v_ok := v_n = 0;
  exception when insufficient_privilege then v_ok := true;
  end;
  r := r || case when v_ok then pasa else falla end || 'nadie se regala un plan' || E'\n';

  begin
    insert into public.user_entitlements (user_id, feature_key, value)
    values (v_autora, 'atelier.export.pdf', 'true'::jsonb);
    v_ok := false;
  exception when insufficient_privilege then v_ok := true;
  end;
  r := r || case when v_ok then pasa else falla end || 'nadie se concede un derecho' || E'\n';

  reset role;

  raise exception E'\n=== PRUEBAS DE MONETIZACION ===\n%===============================', r;
end
$prueba$;
