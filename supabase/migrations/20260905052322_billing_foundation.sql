-- Corvus Atelier — cimiento comercial.
--
-- Aquí vive lo que se vende, a qué precio, quién lo tiene contratado y qué
-- derechos concede. La regla que ordena todo el archivo: el cliente LEE su
-- facturación y no escribe ni una fila. Estado de suscripción, pagos,
-- identificadores del proveedor y derechos adquiridos se mueven solo desde
-- contextos servidor (Edge Functions con service_role, o RPC security definer).
--
-- Nada de esto está cableado en Dart: precios, límites y features se editan en
-- estas tablas y la app los lee. Cambiar el precio de Professional no debe
-- exigir un deploy.

create extension if not exists pgcrypto;

-- ─── Catálogo comercial ─────────────────────────────────────────────────────

-- Un plan es la promesa (qué eres capaz de hacer). Un producto es la compra
-- (qué pasa por caja). Se separan porque un mismo plan se vende con varios
-- precios —mensual, anual, promocional— y porque hay productos que no son
-- planes: add-ons y servicios editoriales.
create table if not exists public.plans (
  code text primary key,
  name text not null,
  tagline text not null default '',
  description text not null default '',
  scope text not null default 'user' check (scope in ('user', 'workspace')),
  tier_rank smallint not null default 0,
  badge text not null default '',
  is_recommended boolean not null default false,
  is_public boolean not null default true,
  is_active boolean not null default true,
  sort_order smallint not null default 0,
  highlights jsonb not null default '[]'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.plans is
  'Niveles comerciales de Atelier. tier_rank ordena la escalera: un plan mayor nunca concede menos que uno menor.';

create table if not exists public.billing_products (
  id text primary key,
  kind text not null check (kind in ('plan', 'addon', 'service')),
  plan_code text references public.plans(code) on delete restrict,
  addon_key text,
  name text not null,
  description text not null default '',
  is_active boolean not null default true,
  sort_order smallint not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint billing_products_plan_needs_code
    check (kind <> 'plan' or plan_code is not null),
  constraint billing_products_addon_needs_key
    check (kind <> 'addon' or addon_key is not null)
);

-- Los importes se guardan en la unidad mínima de la moneda (centavos) y como
-- entero. Un precio en coma flotante es un redondeo esperando a ocurrir.
create table if not exists public.billing_prices (
  id text primary key,
  product_id text not null references public.billing_products(id) on delete cascade,
  provider text not null default 'stripe'
    check (provider in ('stripe', 'mercadopago', 'manual')),
  provider_price_id text,
  currency text not null default 'MXN',
  unit_amount integer not null check (unit_amount >= 0),
  billing_interval text not null default 'month'
    check (billing_interval in ('month', 'year', 'one_time')),
  interval_count smallint not null default 1 check (interval_count > 0),
  trial_days smallint not null default 0 check (trial_days >= 0),
  is_default boolean not null default false,
  is_active boolean not null default true,
  sort_order smallint not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists billing_prices_provider_ref_idx
  on public.billing_prices (provider, provider_price_id)
  where provider_price_id is not null;

create index if not exists billing_prices_product_idx
  on public.billing_prices (product_id, is_active, sort_order);

-- ─── Estado de facturación ──────────────────────────────────────────────────

create table if not exists public.billing_customers (
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null check (provider in ('stripe', 'mercadopago', 'manual')),
  provider_customer_id text not null,
  email text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, provider),
  unique (provider, provider_customer_id)
);

create table if not exists public.billing_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  workspace_id uuid,
  plan_code text not null references public.plans(code) on delete restrict,
  product_id text references public.billing_products(id) on delete set null,
  price_id text references public.billing_prices(id) on delete set null,
  provider text not null default 'manual'
    check (provider in ('stripe', 'mercadopago', 'manual')),
  provider_subscription_id text,
  status text not null default 'active' check (status in (
    'free', 'trialing', 'active', 'past_due', 'canceled', 'incomplete', 'expired'
  )),
  quantity integer not null default 1 check (quantity > 0),
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean not null default false,
  canceled_at timestamptz,
  trial_start timestamptz,
  trial_end timestamptz,
  ended_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists billing_subscriptions_provider_ref_idx
  on public.billing_subscriptions (provider, provider_subscription_id)
  where provider_subscription_id is not null;

-- Una sola suscripción viva por titular. Los estados terminales conviven sin
-- estorbar: el historial no se borra nunca, solo deja de ser el vigente.
create unique index if not exists billing_subscriptions_live_user_idx
  on public.billing_subscriptions (user_id)
  where workspace_id is null
    and status in ('trialing', 'active', 'past_due', 'incomplete');

create unique index if not exists billing_subscriptions_live_workspace_idx
  on public.billing_subscriptions (workspace_id)
  where workspace_id is not null
    and status in ('trialing', 'active', 'past_due', 'incomplete');

create index if not exists billing_subscriptions_user_idx
  on public.billing_subscriptions (user_id, created_at desc);

create table if not exists public.billing_subscription_items (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null
    references public.billing_subscriptions(id) on delete cascade,
  product_id text not null references public.billing_products(id) on delete restrict,
  price_id text references public.billing_prices(id) on delete set null,
  provider_item_id text,
  quantity integer not null default 1 check (quantity > 0),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (subscription_id, product_id)
);

create table if not exists public.billing_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  workspace_id uuid,
  subscription_id uuid references public.billing_subscriptions(id) on delete set null,
  provider text not null check (provider in ('stripe', 'mercadopago', 'manual')),
  provider_transaction_id text,
  invoice_url text,
  receipt_url text,
  kind text not null default 'subscription'
    check (kind in ('subscription', 'addon', 'service', 'refund', 'adjustment')),
  status text not null
    check (status in ('pending', 'paid', 'failed', 'refunded', 'void')),
  currency text not null default 'MXN',
  amount integer not null default 0,
  description text not null default '',
  period_start timestamptz,
  period_end timestamptz,
  occurred_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create unique index if not exists billing_transactions_provider_ref_idx
  on public.billing_transactions (provider, provider_transaction_id)
  where provider_transaction_id is not null;

create index if not exists billing_transactions_user_idx
  on public.billing_transactions (user_id, occurred_at desc);

-- El registro de webhooks. `provider_event_id` es único: esa unicidad ES la
-- idempotencia. Un reintento del proveedor choca contra el índice y se
-- reconoce como ya procesado en vez de duplicar un cobro o un cambio de plan.
create table if not exists public.billing_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null check (provider in ('stripe', 'mercadopago', 'manual')),
  provider_event_id text not null,
  event_type text not null,
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'received'
    check (status in ('received', 'processed', 'ignored', 'failed')),
  error text,
  user_id uuid references auth.users(id) on delete set null,
  attempts smallint not null default 0,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  unique (provider, provider_event_id)
);

create index if not exists billing_events_status_idx
  on public.billing_events (status, received_at desc);

-- ─── Derechos ───────────────────────────────────────────────────────────────

-- El catálogo de lo que se puede conceder. `kind` dice cómo se lee el valor y
-- `aggregation` cómo se combinan dos fuentes que hablan del mismo derecho.
create table if not exists public.entitlement_features (
  key text primary key,
  kind text not null check (kind in ('boolean', 'limit', 'quota', 'string')),
  name text not null,
  description text not null default '',
  unit text not null default '',
  default_value jsonb not null default 'false'::jsonb,
  aggregation text not null default 'max'
    check (aggregation in ('max', 'min', 'or', 'last')),
  is_active boolean not null default true,
  sort_order smallint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on column public.entitlement_features.default_value is
  'Lo que vale el derecho sin plan alguno. -1 en un limit significa ilimitado.';

create table if not exists public.plan_entitlements (
  plan_code text not null references public.plans(code) on delete cascade,
  feature_key text not null references public.entitlement_features(key) on delete cascade,
  value jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (plan_code, feature_key)
);

-- Derechos que no vienen del plan: add-ons comprados, cortesías del archivo,
-- promociones. `mode='add'` suma sobre el plan (50 GB extra); `mode='set'`
-- compite con el plan y gana el mejor según la agregación del feature.
create table if not exists public.user_entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  feature_key text not null references public.entitlement_features(key) on delete cascade,
  value jsonb not null,
  mode text not null default 'set' check (mode in ('set', 'add')),
  source text not null default 'grant'
    check (source in ('addon', 'grant', 'promo', 'override', 'migration')),
  source_ref text,
  starts_at timestamptz not null default now(),
  expires_at timestamptz,
  granted_by uuid references auth.users(id) on delete set null,
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists user_entitlements_lookup_idx
  on public.user_entitlements (user_id, feature_key);

create table if not exists public.workspace_entitlements (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null,
  feature_key text not null references public.entitlement_features(key) on delete cascade,
  value jsonb not null,
  mode text not null default 'set' check (mode in ('set', 'add')),
  source text not null default 'grant'
    check (source in ('addon', 'grant', 'promo', 'override', 'migration')),
  source_ref text,
  starts_at timestamptz not null default now(),
  expires_at timestamptz,
  granted_by uuid references auth.users(id) on delete set null,
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists workspace_entitlements_lookup_idx
  on public.workspace_entitlements (workspace_id, feature_key);

-- ─── updated_at ─────────────────────────────────────────────────────────────

do $mig$
declare
  t text;
begin
  foreach t in array array[
    'plans', 'billing_products', 'billing_prices', 'billing_customers',
    'billing_subscriptions', 'billing_subscription_items',
    'entitlement_features', 'plan_entitlements',
    'user_entitlements', 'workspace_entitlements'
  ] loop
    execute format(
      'drop trigger if exists %I on public.%I', t || '_set_updated_at', t
    );
    execute format(
      'create trigger %I before update on public.%I
         for each row execute function public.set_updated_at()',
      t || '_set_updated_at', t
    );
  end loop;
end $mig$;

-- ─── RLS ────────────────────────────────────────────────────────────────────
--
-- Catálogo: lectura pública de lo activo (la pantalla de Planes se ve sin
-- sesión). Estado: cada quien ve lo suyo. Escritura: nadie desde el cliente.

alter table public.plans enable row level security;
alter table public.billing_products enable row level security;
alter table public.billing_prices enable row level security;
alter table public.billing_customers enable row level security;
alter table public.billing_subscriptions enable row level security;
alter table public.billing_subscription_items enable row level security;
alter table public.billing_transactions enable row level security;
alter table public.billing_events enable row level security;
alter table public.entitlement_features enable row level security;
alter table public.plan_entitlements enable row level security;
alter table public.user_entitlements enable row level security;
alter table public.workspace_entitlements enable row level security;

drop policy if exists "plans_read_public" on public.plans;
create policy "plans_read_public" on public.plans
  for select to anon, authenticated using (is_active);

drop policy if exists "billing_products_read_public" on public.billing_products;
create policy "billing_products_read_public" on public.billing_products
  for select to anon, authenticated using (is_active);

drop policy if exists "billing_prices_read_public" on public.billing_prices;
create policy "billing_prices_read_public" on public.billing_prices
  for select to anon, authenticated using (is_active);

drop policy if exists "entitlement_features_read_public" on public.entitlement_features;
create policy "entitlement_features_read_public" on public.entitlement_features
  for select to anon, authenticated using (is_active);

drop policy if exists "plan_entitlements_read_public" on public.plan_entitlements;
create policy "plan_entitlements_read_public" on public.plan_entitlements
  for select to anon, authenticated using (true);

drop policy if exists "billing_customers_select_own" on public.billing_customers;
create policy "billing_customers_select_own" on public.billing_customers
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "billing_subscriptions_select_own" on public.billing_subscriptions;
create policy "billing_subscriptions_select_own" on public.billing_subscriptions
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "billing_subscription_items_select_own"
  on public.billing_subscription_items;
create policy "billing_subscription_items_select_own"
  on public.billing_subscription_items
  for select to authenticated using (
    exists (
      select 1 from public.billing_subscriptions s
      where s.id = subscription_id and s.user_id = (select auth.uid())
    )
  );

drop policy if exists "billing_transactions_select_own" on public.billing_transactions;
create policy "billing_transactions_select_own" on public.billing_transactions
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "user_entitlements_select_own" on public.user_entitlements;
create policy "user_entitlements_select_own" on public.user_entitlements
  for select to authenticated using ((select auth.uid()) = user_id);

-- billing_events y workspace_entitlements no exponen política de lectura al
-- cliente: el primero guarda cargas útiles del proveedor, el segundo se lee a
-- través del resolutor. Deny-all deliberado.

-- Grants: solo SELECT, y solo donde hay política. Sin INSERT/UPDATE/DELETE en
-- ninguna tabla de facturación para roles del cliente.
grant select on public.plans to anon, authenticated;
grant select on public.billing_products to anon, authenticated;
grant select on public.billing_prices to anon, authenticated;
grant select on public.entitlement_features to anon, authenticated;
grant select on public.plan_entitlements to anon, authenticated;
grant select on public.billing_customers to authenticated;
grant select on public.billing_subscriptions to authenticated;
grant select on public.billing_subscription_items to authenticated;
grant select on public.billing_transactions to authenticated;
grant select on public.user_entitlements to authenticated;
