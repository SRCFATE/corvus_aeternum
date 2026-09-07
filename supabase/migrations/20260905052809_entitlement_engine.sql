-- Corvus Atelier — el motor de derechos.
--
-- Una sola pregunta se hace en todo el producto: "¿este titular tiene este
-- derecho, y hasta cuánto?". Se responde aquí, en la base, y Flutter solo
-- consume el resultado. Esa es la razón de que no exista ni un `if (isPro)`
-- disperso: la decisión vive en un sitio y se puede auditar.
--
-- Orden de resolución, de menos a más autoridad:
--   1. el valor por defecto del feature (lo que vale sin plan alguno);
--   2. el plan vigente del titular;
--   3. los derechos sueltos: add-ons comprados, cortesías, promociones.
--
-- `-1` en un límite significa ilimitado y gana a cualquier número.

-- ─── Utilidades de valor ────────────────────────────────────────────────────

create or replace function public.entitlement_is_unlimited(p_value jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $fn$
  select p_value is not null
    and jsonb_typeof(p_value) = 'number'
    and (p_value)::text::numeric = -1;
$fn$;

-- Combina dos valores del mismo derecho según cómo se agrega ese derecho.
create or replace function public.entitlement_combine(
  p_a jsonb,
  p_b jsonb,
  p_aggregation text
)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $fn$
declare
  a numeric;
  b numeric;
begin
  if p_a is null or jsonb_typeof(p_a) = 'null' then return p_b; end if;
  if p_b is null or jsonb_typeof(p_b) = 'null' then return p_a; end if;

  if p_aggregation = 'last' then
    return p_b;
  end if;

  if p_aggregation = 'or' then
    return to_jsonb(
      coalesce((p_a)::text::boolean, false) or coalesce((p_b)::text::boolean, false)
    );
  end if;

  if jsonb_typeof(p_a) <> 'number' or jsonb_typeof(p_b) <> 'number' then
    -- Derechos de texto: el último declarado manda.
    return p_b;
  end if;

  a := (p_a)::text::numeric;
  b := (p_b)::text::numeric;

  if p_aggregation = 'max' then
    -- Ilimitado gana a cualquier cifra.
    if a = -1 or b = -1 then return to_jsonb(-1); end if;
    return to_jsonb(greatest(a, b));
  end if;

  -- 'min': ilimitado es el techo, así que pierde frente a un número concreto.
  if a = -1 then return to_jsonb(b); end if;
  if b = -1 then return to_jsonb(a); end if;
  return to_jsonb(least(a, b));
end;
$fn$;

-- Suma de add-ons: lo ilimitado absorbe cualquier añadido.
create or replace function public.entitlement_add(p_a jsonb, p_b jsonb)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $fn$
begin
  if p_a is null or jsonb_typeof(p_a) <> 'number' then return p_b; end if;
  if p_b is null or jsonb_typeof(p_b) <> 'number' then return p_a; end if;
  if (p_a)::text::numeric = -1 or (p_b)::text::numeric = -1 then
    return to_jsonb(-1);
  end if;
  return to_jsonb((p_a)::text::numeric + (p_b)::text::numeric);
end;
$fn$;

-- ─── Plan vigente ───────────────────────────────────────────────────────────
--
-- `past_due` conserva el acceso a propósito: un cobro rechazado es un problema
-- de tarjeta, no una razón para cerrarle el taller a alguien a media escena.
-- La app lo muestra y pide arreglarlo; el archivo no castiga.

create or replace function public.atelier_user_plan(p_user_id uuid)
returns table (
  plan_code text,
  status text,
  subscription_id uuid,
  current_period_end timestamptz,
  cancel_at_period_end boolean
)
language sql
stable
security definer
set search_path = ''
as $fn$
  select
    coalesce(s.plan_code, 'free'),
    coalesce(s.status, 'free'),
    s.id,
    s.current_period_end,
    coalesce(s.cancel_at_period_end, false)
  from (select 1) as anchor
  left join lateral (
    select b.*
    from public.billing_subscriptions b
    where b.user_id = p_user_id
      and b.workspace_id is null
      and b.status in ('trialing', 'active', 'past_due')
    order by b.created_at desc
    limit 1
  ) s on true;
$fn$;

create or replace function public.atelier_workspace_plan(p_workspace_id uuid)
returns table (
  plan_code text,
  status text,
  subscription_id uuid,
  current_period_end timestamptz,
  cancel_at_period_end boolean
)
language sql
stable
security definer
set search_path = ''
as $fn$
  select
    coalesce(s.plan_code, w.plan_code, 'free'),
    coalesce(s.status, 'free'),
    s.id,
    s.current_period_end,
    coalesce(s.cancel_at_period_end, false)
  from public.atelier_workspaces w
  left join lateral (
    select b.*
    from public.billing_subscriptions b
    where b.workspace_id = w.id
      and b.status in ('trialing', 'active', 'past_due')
    order by b.created_at desc
    limit 1
  ) s on true
  where w.id = p_workspace_id;
$fn$;

-- ─── Resolución completa ────────────────────────────────────────────────────

create or replace function public.resolve_entitlements(
  p_user_id uuid,
  p_workspace_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_features jsonb := '{}'::jsonb;
  v_plan text;
  v_status text;
  v_sub_id uuid;
  v_period_end timestamptz;
  v_cancel boolean;
  v_ws_plan text;
  v_ws_status text;
  v_ws_period_end timestamptz;
  v_ws_cancel boolean;
  r record;
  v_value jsonb;
begin
  if p_user_id is null then
    return jsonb_build_object(
      'plan', jsonb_build_object('code', 'free', 'status', 'free'),
      'features', '{}'::jsonb,
      'resolved_at', to_jsonb(now())
    );
  end if;

  select plan_code, status, subscription_id, current_period_end, cancel_at_period_end
    into v_plan, v_status, v_sub_id, v_period_end, v_cancel
    from public.atelier_user_plan(p_user_id);

  if p_workspace_id is not null then
    select plan_code, status, current_period_end, cancel_at_period_end
      into v_ws_plan, v_ws_status, v_ws_period_end, v_ws_cancel
      from public.atelier_workspace_plan(p_workspace_id);
  end if;

  -- 1 y 2: base del catálogo, luego el plan (o los dos planes, si se pregunta
  -- dentro de un workspace: nadie pierde derechos por entrar en un estudio).
  for r in
    select f.key, f.default_value, f.aggregation,
           pu.value as user_plan_value,
           pw.value as workspace_plan_value
    from public.entitlement_features f
    left join public.plan_entitlements pu
      on pu.feature_key = f.key and pu.plan_code = v_plan
    left join public.plan_entitlements pw
      on pw.feature_key = f.key
     and pw.plan_code = coalesce(v_ws_plan, '~ninguno~')
    where f.is_active
  loop
    v_value := r.default_value;
    v_value := public.entitlement_combine(v_value, r.user_plan_value, r.aggregation);
    v_value := public.entitlement_combine(v_value, r.workspace_plan_value, r.aggregation);
    v_features := v_features || jsonb_build_object(r.key, v_value);
  end loop;

  -- 3: derechos sueltos vivos. Primero los 'set' (compiten con el plan),
  -- después los 'add' (se suman sobre lo ya resuelto).
  for r in
    select e.feature_key, e.value, e.mode, f.aggregation
    from public.user_entitlements e
    join public.entitlement_features f on f.key = e.feature_key
    where e.user_id = p_user_id
      and f.is_active
      and e.starts_at <= now()
      and (e.expires_at is null or e.expires_at > now())
    union all
    select e.feature_key, e.value, e.mode, f.aggregation
    from public.workspace_entitlements e
    join public.entitlement_features f on f.key = e.feature_key
    where p_workspace_id is not null
      and e.workspace_id = p_workspace_id
      and f.is_active
      and e.starts_at <= now()
      and (e.expires_at is null or e.expires_at > now())
    order by 3 desc
  loop
    v_value := v_features -> r.feature_key;
    if r.mode = 'add' then
      v_features := v_features || jsonb_build_object(
        r.feature_key, public.entitlement_add(v_value, r.value)
      );
    else
      v_features := v_features || jsonb_build_object(
        r.feature_key, public.entitlement_combine(v_value, r.value, r.aggregation)
      );
    end if;
  end loop;

  return jsonb_build_object(
    'plan', jsonb_build_object(
      'code', v_plan,
      'status', v_status,
      'subscription_id', v_sub_id,
      'current_period_end', v_period_end,
      'cancel_at_period_end', v_cancel
    ),
    'workspace', case
      when p_workspace_id is null then null
      else jsonb_build_object(
        'id', p_workspace_id,
        'plan_code', v_ws_plan,
        'status', v_ws_status,
        'current_period_end', v_ws_period_end,
        'cancel_at_period_end', v_ws_cancel
      )
    end,
    'features', v_features,
    'resolved_at', to_jsonb(now())
  );
end;
$fn$;

-- ─── Atajos para triggers y políticas ───────────────────────────────────────
--
-- Resolver el mapa entero para comprobar un solo derecho sería caro dentro de
-- un trigger. Estas dos funciones responden por un feature suelto.

create or replace function public.entitlement_value(
  p_user_id uuid,
  p_feature_key text,
  p_workspace_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_agg text;
  v_value jsonb;
  v_user_plan text;
  v_ws_plan text;
  r record;
begin
  select f.aggregation, f.default_value into v_agg, v_value
  from public.entitlement_features f
  where f.key = p_feature_key and f.is_active;

  if not found then return null; end if;

  select plan_code into v_user_plan from public.atelier_user_plan(p_user_id);
  if p_workspace_id is not null then
    select plan_code into v_ws_plan from public.atelier_workspace_plan(p_workspace_id);
  end if;

  v_value := public.entitlement_combine(
    v_value,
    (select pe.value from public.plan_entitlements pe
      where pe.plan_code = v_user_plan and pe.feature_key = p_feature_key),
    v_agg
  );

  if v_ws_plan is not null then
    v_value := public.entitlement_combine(
      v_value,
      (select pe.value from public.plan_entitlements pe
        where pe.plan_code = v_ws_plan and pe.feature_key = p_feature_key),
      v_agg
    );
  end if;

  for r in
    select e.value, e.mode
    from public.user_entitlements e
    where e.user_id = p_user_id
      and e.feature_key = p_feature_key
      and e.starts_at <= now()
      and (e.expires_at is null or e.expires_at > now())
    union all
    select e.value, e.mode
    from public.workspace_entitlements e
    where p_workspace_id is not null
      and e.workspace_id = p_workspace_id
      and e.feature_key = p_feature_key
      and e.starts_at <= now()
      and (e.expires_at is null or e.expires_at > now())
    order by 2 desc
  loop
    if r.mode = 'add' then
      v_value := public.entitlement_add(v_value, r.value);
    else
      v_value := public.entitlement_combine(v_value, r.value, v_agg);
    end if;
  end loop;

  return v_value;
end;
$fn$;

-- Un derecho booleano se lee como sí/no; uno numérico responde "sí" cuando
-- concede algo: 5 colaboradores es tener colaboración, 0 no lo es.
create or replace function public.has_entitlement(
  p_user_id uuid,
  p_feature_key text,
  p_workspace_id uuid default null
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v jsonb := public.entitlement_value(p_user_id, p_feature_key, p_workspace_id);
begin
  if v is null then return false; end if;
  if jsonb_typeof(v) = 'boolean' then return (v)::text::boolean; end if;
  if jsonb_typeof(v) = 'number' then
    return (v)::text::numeric <> 0;
  end if;
  return false;
end;
$fn$;

-- Devuelve el tope como bigint. -1 significa ilimitado; quien la llame debe
-- tratarlo, y por eso no se traduce aquí a un número enorme.
create or replace function public.entitlement_limit(
  p_user_id uuid,
  p_feature_key text,
  p_workspace_id uuid default null
)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v jsonb := public.entitlement_value(p_user_id, p_feature_key, p_workspace_id);
begin
  if v is null or jsonb_typeof(v) <> 'number' then return 0; end if;
  return (v)::text::numeric::bigint;
end;
$fn$;

-- ─── RPC del cliente ────────────────────────────────────────────────────────

create or replace function public.get_my_entitlements()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_result jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHENTICATED');
  end if;

  v_result := public.resolve_entitlements(v_uid, null);

  return v_result || jsonb_build_object(
    'ok', true,
    'workspaces', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', w.id,
        'slug', w.slug,
        'name', w.name,
        'plan_code', wp.plan_code,
        'status', w.status,
        'role_key', m.role_key,
        'is_owner', w.owner_id = v_uid,
        'is_billing_owner', w.billing_owner_id = v_uid,
        'capabilities', to_jsonb(public.atelier_workspace_capabilities(w.id, v_uid))
      ) order by w.created_at)
      from public.atelier_workspace_members m
      join public.atelier_workspaces w on w.id = m.workspace_id
      cross join lateral public.atelier_workspace_plan(w.id) wp
      where m.profile_id = v_uid and m.status = 'active'
    ), '[]'::jsonb)
  );
end;
$fn$;

create or replace function public.get_workspace_entitlements(p_workspace_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHENTICATED');
  end if;

  if not public.atelier_is_workspace_member(p_workspace_id, v_uid) then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHORIZED');
  end if;

  return public.resolve_entitlements(v_uid, p_workspace_id)
    || jsonb_build_object(
      'ok', true,
      'capabilities',
        to_jsonb(public.atelier_workspace_capabilities(p_workspace_id, v_uid))
    );
end;
$fn$;

revoke all on function public.resolve_entitlements(uuid, uuid) from public;
revoke all on function public.entitlement_value(uuid, text, uuid) from public;
revoke all on function public.has_entitlement(uuid, text, uuid) from public;
revoke all on function public.entitlement_limit(uuid, text, uuid) from public;
revoke all on function public.atelier_user_plan(uuid) from public;
revoke all on function public.atelier_workspace_plan(uuid) from public;
revoke all on function public.get_my_entitlements() from public;
revoke all on function public.get_workspace_entitlements(uuid) from public;

grant execute on function public.get_my_entitlements() to authenticated;
grant execute on function public.get_workspace_entitlements(uuid) to authenticated;
