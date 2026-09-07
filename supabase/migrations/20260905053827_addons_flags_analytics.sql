-- Corvus Atelier — add-ons, banderas de función y analítica de negocio.
--
-- Tres piezas que comparten un propósito: poder mover el producto sin
-- desplegar. Un add-on nuevo es una fila. Encender Teams para diez cuentas
-- concretas es una fila. Y la analítica mide el embudo comercial sin tocar
-- jamás el contenido creativo: aquí no entra ni una palabra de un manuscrito.

-- ─── Add-ons ────────────────────────────────────────────────────────────────
--
-- Un add-on es una regla de traducción: "comprar esto concede tanto de aquel
-- derecho". Al activarse se materializa como fila en `user_entitlements` o
-- `workspace_entitlements`, así que el resolutor no necesita saber que los
-- add-ons existen.

create table if not exists public.atelier_addons (
  key text primary key,
  name text not null,
  description text not null default '',
  kind text not null default 'entitlement'
    check (kind in ('entitlement', 'seat', 'service')),
  feature_key text references public.entitlement_features(key) on delete restrict,
  value_delta jsonb,
  mode text not null default 'add' check (mode in ('add', 'set')),
  scope text not null default 'user' check (scope in ('user', 'workspace')),
  is_stackable boolean not null default true,
  max_quantity smallint,
  is_active boolean not null default true,
  sort_order smallint not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.atelier_purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  workspace_id uuid references public.atelier_workspaces(id) on delete cascade,
  product_id text references public.billing_products(id) on delete set null,
  addon_key text references public.atelier_addons(key) on delete restrict,
  quantity integer not null default 1 check (quantity > 0),
  status text not null default 'pending'
    check (status in ('pending', 'active', 'expired', 'refunded', 'canceled')),
  provider text not null default 'manual'
    check (provider in ('stripe', 'mercadopago', 'manual')),
  provider_reference text,
  transaction_id uuid references public.billing_transactions(id) on delete set null,
  entitlement_id uuid references public.user_entitlements(id) on delete set null,
  workspace_entitlement_id uuid
    references public.workspace_entitlements(id) on delete set null,
  starts_at timestamptz not null default now(),
  expires_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists atelier_purchases_user_idx
  on public.atelier_purchases (user_id, status);

create unique index if not exists atelier_purchases_provider_ref_idx
  on public.atelier_purchases (provider, provider_reference)
  where provider_reference is not null;

insert into public.atelier_addons (
  key, name, description, kind, feature_key, value_delta, mode, scope,
  is_stackable, max_quantity, sort_order
) values
  ('additional_storage', 'Almacenamiento adicional',
   'Añade 50 GB al espacio disponible. Se acumula con el del plan.',
   'entitlement', 'atelier.storage.max_bytes', '53687091200'::jsonb, 'add',
   'user', true, 20, 0),
  ('additional_collaborators', 'Colaboradores adicionales',
   'Añade 5 asientos de colaboración por proyecto.',
   'entitlement', 'atelier.collaborators.max', '5'::jsonb, 'add',
   'user', true, 10, 1),
  ('professional_templates_pack', 'Pack de plantillas profesionales',
   'Desbloquea las plantillas especializadas sin cambiar de plan.',
   'entitlement', 'atelier.templates.pro', 'true'::jsonb, 'set',
   'user', false, 1, 2),
  ('publisher_export_pack', 'Pack de exportación editorial',
   'Habilita DOCX, PDF y EPUB para quien solo necesita entregar.',
   'entitlement', 'atelier.export.docx', 'true'::jsonb, 'set',
   'user', false, 1, 3),
  ('advanced_backup', 'Backups avanzados',
   'Copias automáticas y recuperación estructurada del proyecto.',
   'entitlement', 'atelier.backups.advanced', 'true'::jsonb, 'set',
   'user', false, 1, 4),
  ('team_seats', 'Asientos de equipo',
   'Amplía en 10 los miembros activos del workspace.',
   'seat', 'atelier.workspace.seats.max', '10'::jsonb, 'add',
   'workspace', true, 20, 5)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  feature_key = excluded.feature_key,
  value_delta = excluded.value_delta,
  mode = excluded.mode,
  scope = excluded.scope;

-- Un add-on puede conceder varios derechos a la vez; `publisher_export_pack`
-- necesita PDF y EPUB además del DOCX. Esta tabla es la lista completa de lo
-- que concede cada uno, incluida la concesión principal declarada en su fila:
-- así el aplicador recorre una sola relación y no tiene que combinar dos
-- orígenes distintos.
create table if not exists public.atelier_addon_grants (
  addon_key text not null references public.atelier_addons(key) on delete cascade,
  feature_key text not null
    references public.entitlement_features(key) on delete cascade,
  value_delta jsonb not null,
  mode text not null default 'set' check (mode in ('add', 'set')),
  primary key (addon_key, feature_key)
);

insert into public.atelier_addon_grants (addon_key, feature_key, value_delta, mode)
select a.key, a.feature_key, a.value_delta, a.mode
from public.atelier_addons a
where a.feature_key is not null and a.value_delta is not null
on conflict (addon_key, feature_key) do nothing;

insert into public.atelier_addon_grants (addon_key, feature_key, value_delta, mode)
values
  ('publisher_export_pack', 'atelier.export.pdf', 'true'::jsonb, 'set'),
  ('publisher_export_pack', 'atelier.export.epub', 'true'::jsonb, 'set'),
  ('publisher_export_pack', 'atelier.export.project_bundle', 'true'::jsonb, 'set'),
  ('publisher_export_pack', 'atelier.editorial.manuscript', 'true'::jsonb, 'set')
on conflict (addon_key, feature_key) do nothing;

-- Materializa una compra en derechos. Es idempotente por compra: llamarla dos
-- veces con el mismo `p_purchase_id` no duplica el add-on.
create or replace function public.atelier_apply_purchase(p_purchase_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  p record;
  a record;
  g record;
  v_value jsonb;
  v_granted integer := 0;
begin
  select * into p from public.atelier_purchases where id = p_purchase_id;
  if not found then
    return jsonb_build_object('ok', false, 'reason_code', 'PURCHASE_NOT_FOUND');
  end if;

  if p.addon_key is null then
    return jsonb_build_object('ok', false, 'reason_code', 'PURCHASE_WITHOUT_ADDON');
  end if;

  select * into a from public.atelier_addons where key = p.addon_key;
  if not found or not a.is_active then
    return jsonb_build_object('ok', false, 'reason_code', 'ADDON_NOT_AVAILABLE');
  end if;

  -- Ya materializada: no se vuelve a conceder.
  if exists (
    select 1 from public.user_entitlements
    where source = 'addon' and source_ref = p_purchase_id::text
    union all
    select 1 from public.workspace_entitlements
    where source = 'addon' and source_ref = p_purchase_id::text
  ) then
    return jsonb_build_object('ok', true, 'already_applied', true);
  end if;

  for g in
    select ag.feature_key, ag.value_delta, ag.mode
    from public.atelier_addon_grants ag
    where ag.addon_key = a.key
  loop
    -- Solo lo que suma se multiplica por la cantidad comprada.
    if g.mode = 'add' and jsonb_typeof(g.value_delta) = 'number' then
      v_value := to_jsonb((g.value_delta)::text::numeric * p.quantity);
    else
      v_value := g.value_delta;
    end if;

    if a.scope = 'workspace' and p.workspace_id is not null then
      insert into public.workspace_entitlements (
        workspace_id, feature_key, value, mode, source, source_ref, expires_at, note
      ) values (
        p.workspace_id, g.feature_key, v_value, g.mode, 'addon',
        p_purchase_id::text, p.expires_at, a.name
      );
    else
      insert into public.user_entitlements (
        user_id, feature_key, value, mode, source, source_ref, expires_at, note
      ) values (
        p.user_id, g.feature_key, v_value, g.mode, 'addon',
        p_purchase_id::text, p.expires_at, a.name
      );
    end if;

    v_granted := v_granted + 1;
  end loop;

  update public.atelier_purchases
    set status = 'active', updated_at = now()
    where id = p_purchase_id;

  return jsonb_build_object('ok', true, 'granted', v_granted);
end;
$fn$;

-- Revocar un add-on retira el derecho, nunca el contenido. Alguien que deja de
-- pagar los 50 GB extra conserva sus archivos: solo deja de poder subir más.
create or replace function public.atelier_revoke_purchase(p_purchase_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_count integer := 0;
begin
  with revoked as (
    update public.user_entitlements
      set expires_at = now()
      where source = 'addon' and source_ref = p_purchase_id::text
        and (expires_at is null or expires_at > now())
      returning 1
  )
  select count(*) into v_count from revoked;

  update public.workspace_entitlements
    set expires_at = now()
    where source = 'addon' and source_ref = p_purchase_id::text
      and (expires_at is null or expires_at > now());

  update public.atelier_purchases
    set status = 'canceled', updated_at = now()
    where id = p_purchase_id;

  return jsonb_build_object('ok', true, 'revoked', v_count);
end;
$fn$;

-- ─── Banderas de función ────────────────────────────────────────────────────

create table if not exists public.feature_flags (
  key text primary key,
  name text not null,
  description text not null default '',
  is_enabled boolean not null default false,
  rollout_percentage smallint not null default 0
    check (rollout_percentage between 0 and 100),
  environments text[] not null default '{}'::text[],
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.feature_flag_overrides (
  id uuid primary key default gen_random_uuid(),
  flag_key text not null references public.feature_flags(key) on delete cascade,
  profile_id uuid references public.profiles(id) on delete cascade,
  workspace_id uuid references public.atelier_workspaces(id) on delete cascade,
  is_enabled boolean not null,
  note text not null default '',
  created_at timestamptz not null default now(),
  constraint feature_flag_overrides_has_target
    check (profile_id is not null or workspace_id is not null)
);

create unique index if not exists feature_flag_overrides_profile_idx
  on public.feature_flag_overrides (flag_key, profile_id) where profile_id is not null;

create unique index if not exists feature_flag_overrides_workspace_idx
  on public.feature_flag_overrides (flag_key, workspace_id) where workspace_id is not null;

insert into public.feature_flags (key, name, description, is_enabled, rollout_percentage)
values
  ('billing', 'Facturación', 'Muestra planes, checkout y centro de facturación.', false, 0),
  ('professional', 'Atelier Professional', 'Ofrece el plan Professional.', false, 0),
  ('teams', 'Atelier Teams', 'Ofrece workspaces y el plan Teams.', false, 0),
  ('addons', 'Add-ons', 'Permite comprar extras sin cambiar de plan.', false, 0),
  ('advanced_exports', 'Exportaciones avanzadas', 'DOCX, PDF, EPUB y paquete completo.', false, 0),
  ('automation', 'Automatizaciones', 'Reglas disparador → condición → acción.', false, 0),
  ('team_workspaces', 'Workspaces de equipo', 'Alta de espacios compartidos.', false, 0),
  ('publisher_submission', 'Corvus Publishing Bureau', 'Envío de manuscritos a evaluación.', false, 0)
on conflict (key) do nothing;

-- El reparto por porcentaje es estable por persona: el mismo perfil cae
-- siempre del mismo lado de la bandera, así que nadie ve una función
-- aparecer y desaparecer entre sesiones.
create or replace function public.is_feature_enabled(
  p_key text,
  p_profile_id uuid default auth.uid()
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  f record;
  v_override boolean;
begin
  select * into f from public.feature_flags where key = p_key;
  if not found then return false; end if;

  if p_profile_id is not null then
    select o.is_enabled into v_override
    from public.feature_flag_overrides o
    where o.flag_key = p_key and o.profile_id = p_profile_id;

    if found then return v_override; end if;
  end if;

  if not f.is_enabled then return false; end if;
  if f.rollout_percentage >= 100 then return true; end if;
  if f.rollout_percentage <= 0 then return false; end if;
  if p_profile_id is null then return false; end if;

  return (abs(hashtext(p_key || ':' || p_profile_id::text)) % 100)
         < f.rollout_percentage;
end;
$fn$;

create or replace function public.get_feature_flags()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $fn$
  select coalesce(
    jsonb_object_agg(f.key, public.is_feature_enabled(f.key, auth.uid())),
    '{}'::jsonb
  )
  from public.feature_flags f;
$fn$;

-- ─── Analítica de negocio ───────────────────────────────────────────────────

create table if not exists public.billing_analytics_events (
  id bigserial primary key,
  profile_id uuid references public.profiles(id) on delete set null,
  workspace_id uuid references public.atelier_workspaces(id) on delete set null,
  event text not null,
  plan_code text,
  feature_key text,
  properties jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

create index if not exists billing_analytics_events_event_idx
  on public.billing_analytics_events (event, occurred_at desc);

create index if not exists billing_analytics_events_profile_idx
  on public.billing_analytics_events (profile_id, occurred_at desc);

-- La privacidad no se confía al cliente: el servidor descarta cualquier
-- propiedad fuera de la lista blanca y recorta lo que llegue. Si mañana
-- alguien envía por error el cuerpo de un capítulo, no se guarda.
create or replace function public.record_billing_event(
  p_event text,
  p_properties jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_allowed constant text[] := array[
    'plan_viewed', 'upgrade_clicked', 'checkout_started', 'checkout_completed',
    'subscription_started', 'subscription_canceled', 'subscription_reactivated',
    'upgrade_completed', 'downgrade_completed', 'feature_gate_seen',
    'storage_limit_reached', 'addon_purchased', 'billing_center_viewed',
    'plan_compared', 'collaborator_limit_reached'
  ];
  v_keys constant text[] := array[
    'plan_code', 'feature_key', 'price_id', 'interval', 'source',
    'surface', 'from_plan', 'to_plan', 'addon_key', 'quantity',
    'percent_used', 'workspace_id'
  ];
  v_props jsonb := '{}'::jsonb;
  k text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHENTICATED');
  end if;

  if not (p_event = any (v_allowed)) then
    return jsonb_build_object('ok', false, 'reason_code', 'EVENT_NOT_ALLOWED');
  end if;

  foreach k in array v_keys loop
    if p_properties ? k then
      v_props := v_props || jsonb_build_object(
        k, left(coalesce(p_properties->>k, ''), 120)
      );
    end if;
  end loop;

  insert into public.billing_analytics_events (
    profile_id, workspace_id, event, plan_code, feature_key, properties
  ) values (
    v_uid,
    nullif(v_props->>'workspace_id', '')::uuid,
    p_event,
    nullif(v_props->>'plan_code', ''),
    nullif(v_props->>'feature_key', ''),
    v_props
  );

  return jsonb_build_object('ok', true);
end;
$fn$;

-- ─── RLS ────────────────────────────────────────────────────────────────────

alter table public.atelier_addons enable row level security;
alter table public.atelier_addon_grants enable row level security;
alter table public.atelier_purchases enable row level security;
alter table public.feature_flags enable row level security;
alter table public.feature_flag_overrides enable row level security;
alter table public.billing_analytics_events enable row level security;

drop policy if exists "atelier_addons_read_public" on public.atelier_addons;
create policy "atelier_addons_read_public" on public.atelier_addons
  for select to anon, authenticated using (is_active);

drop policy if exists "atelier_addon_grants_read_public" on public.atelier_addon_grants;
create policy "atelier_addon_grants_read_public" on public.atelier_addon_grants
  for select to anon, authenticated using (true);

drop policy if exists "atelier_purchases_select_own" on public.atelier_purchases;
create policy "atelier_purchases_select_own" on public.atelier_purchases
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or (workspace_id is not null
        and public.atelier_has_capability(workspace_id, 'billing.manage'))
  );

-- feature_flags y sus excepciones se leen a través de get_feature_flags():
-- exponer la tabla revelaría el mapa de lo que aún no se ha lanzado.
-- billing_analytics_events es deny-all: se escribe por RPC y se lee en
-- administración con service_role.

grant select on public.atelier_addons to anon, authenticated;
grant select on public.atelier_addon_grants to anon, authenticated;
grant select on public.atelier_purchases to authenticated;

do $mig$
declare
  t text;
begin
  foreach t in array array['atelier_addons', 'atelier_purchases', 'feature_flags'] loop
    execute format('drop trigger if exists %I on public.%I', t || '_set_updated_at', t);
    execute format(
      'create trigger %I before update on public.%I
         for each row execute function public.set_updated_at()',
      t || '_set_updated_at', t
    );
  end loop;
end $mig$;

revoke all on function public.atelier_apply_purchase(uuid) from public;
revoke all on function public.atelier_revoke_purchase(uuid) from public;
revoke all on function public.is_feature_enabled(text, uuid) from public;
revoke all on function public.get_feature_flags() from public;
revoke all on function public.record_billing_event(text, jsonb) from public;
grant execute on function public.get_feature_flags() to authenticated;
grant execute on function public.record_billing_event(text, jsonb) to authenticated;
