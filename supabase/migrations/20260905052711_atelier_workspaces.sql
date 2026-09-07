-- Corvus Atelier — workspaces, roles y auditoría (Atelier Teams).
--
-- Un workspace es un estudio: gente distinta con permisos distintos sobre los
-- mismos proyectos. Los permisos NO se leen del nombre del rol —eso ata el
-- producto a seis palabras para siempre— sino de una lista de capacidades.
-- Un rol es un atajo con nombre para un conjunto de capacidades, y por eso
-- Teams puede ofrecer roles personalizados sin tocar una línea de SQL.
--
-- Las funciones de capacidad son SECURITY DEFINER a propósito: si una política
-- de `atelier_workspace_members` consultara `atelier_workspace_members`, la
-- RLS se llamaría a sí misma. Ese error ya se pagó una vez en este archivo
-- (migración fix_fan_forum_policy_recursion) y no se repite.

create table if not exists public.atelier_workspaces (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text not null default '',
  owner_id uuid not null references public.profiles(id) on delete restrict,
  billing_owner_id uuid not null references public.profiles(id) on delete restrict,
  plan_code text not null default 'free' references public.plans(code) on delete restrict,
  avatar_url text,
  status text not null default 'active'
    check (status in ('active', 'suspended', 'archived')),
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint atelier_workspaces_slug_shape
    check (slug ~ '^[a-z0-9][a-z0-9._-]{1,38}[a-z0-9]$')
);

comment on column public.atelier_workspaces.billing_owner_id is
  'Quien paga puede no ser quien manda: se separan para que una editorial pague el espacio de un autor sin adueñarse de su obra.';

-- Un rol con workspace_id nulo es del sistema y lo comparten todos los
-- espacios. Con workspace_id, es un rol personalizado de ese estudio.
create table if not exists public.atelier_workspace_roles (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid references public.atelier_workspaces(id) on delete cascade,
  key text not null,
  name text not null,
  description text not null default '',
  capabilities text[] not null default '{}'::text[],
  is_system boolean not null default false,
  rank smallint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint atelier_workspace_roles_key_shape check (key ~ '^[a-z][a-z0-9_]{1,30}$')
);

create unique index if not exists atelier_workspace_roles_system_key_idx
  on public.atelier_workspace_roles (key) where workspace_id is null;

create unique index if not exists atelier_workspace_roles_scoped_key_idx
  on public.atelier_workspace_roles (workspace_id, key) where workspace_id is not null;

create table if not exists public.atelier_workspace_members (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.atelier_workspaces(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role_key text not null default 'viewer',
  status text not null default 'active'
    check (status in ('active', 'suspended', 'left')),
  seat_kind text not null default 'member'
    check (seat_kind in ('member', 'guest', 'service')),
  invited_by uuid references public.profiles(id) on delete set null,
  joined_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (workspace_id, profile_id)
);

create index if not exists atelier_workspace_members_profile_idx
  on public.atelier_workspace_members (profile_id, status);

-- Excepciones puntuales sobre el rol: dar una capacidad extra a alguien, o
-- quitársela sin degradarlo de rol. `deny` gana siempre sobre `grant`.
create table if not exists public.atelier_workspace_permissions (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.atelier_workspaces(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  capability text not null,
  effect text not null default 'grant' check (effect in ('grant', 'deny')),
  granted_by uuid references public.profiles(id) on delete set null,
  note text not null default '',
  created_at timestamptz not null default now(),
  unique (workspace_id, profile_id, capability)
);

create table if not exists public.atelier_invitations (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid references public.atelier_workspaces(id) on delete cascade,
  project_id uuid references public.atelier_projects(id) on delete cascade,
  email text,
  invitee_id uuid references public.profiles(id) on delete cascade,
  role_key text not null default 'viewer',
  token text not null unique default encode(gen_random_bytes(24), 'hex'),
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'revoked', 'expired')),
  invited_by uuid not null references public.profiles(id) on delete cascade,
  message text not null default '',
  expires_at timestamptz not null default now() + interval '14 days',
  responded_at timestamptz,
  created_at timestamptz not null default now(),
  constraint atelier_invitations_has_target
    check (workspace_id is not null or project_id is not null),
  constraint atelier_invitations_has_recipient
    check (email is not null or invitee_id is not null)
);

create index if not exists atelier_invitations_invitee_idx
  on public.atelier_invitations (invitee_id, status);

create index if not exists atelier_invitations_workspace_idx
  on public.atelier_invitations (workspace_id, status);

create table if not exists public.atelier_audit_log (
  id bigserial primary key,
  workspace_id uuid references public.atelier_workspaces(id) on delete cascade,
  project_id uuid references public.atelier_projects(id) on delete set null,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  object_type text not null,
  object_id text,
  before_state jsonb,
  after_state jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists atelier_audit_log_workspace_idx
  on public.atelier_audit_log (workspace_id, created_at desc);

create index if not exists atelier_audit_log_project_idx
  on public.atelier_audit_log (project_id, created_at desc);

-- ─── Ataduras pendientes del cimiento comercial ─────────────────────────────

do $mig$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'billing_subscriptions_workspace_fkey'
  ) then
    alter table public.billing_subscriptions
      add constraint billing_subscriptions_workspace_fkey
      foreign key (workspace_id) references public.atelier_workspaces(id) on delete cascade;
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'billing_transactions_workspace_fkey'
  ) then
    alter table public.billing_transactions
      add constraint billing_transactions_workspace_fkey
      foreign key (workspace_id) references public.atelier_workspaces(id) on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'workspace_entitlements_workspace_fkey'
  ) then
    alter table public.workspace_entitlements
      add constraint workspace_entitlements_workspace_fkey
      foreign key (workspace_id) references public.atelier_workspaces(id) on delete cascade;
  end if;
end $mig$;

-- Un proyecto puede vivir en un workspace o seguir siendo personal (null).
alter table public.atelier_projects
  add column if not exists workspace_id uuid
    references public.atelier_workspaces(id) on delete set null;

create index if not exists atelier_projects_workspace_idx
  on public.atelier_projects (workspace_id, updated_at desc);

-- ─── Roles del sistema ──────────────────────────────────────────────────────

insert into public.atelier_workspace_roles
  (workspace_id, key, name, description, capabilities, is_system, rank)
values
  (null, 'owner', 'Propietario',
   'Manda sobre el espacio y su facturación.',
   array[
     'project.read','project.write','project.create','project.delete',
     'member.invite','member.remove','member.manage','role.manage',
     'billing.manage','export.create','comment.create','comment.resolve',
     'task.assign','automation.manage','template.manage','settings.manage',
     'workspace.manage','audit.read'
   ], true, 100),
  (null, 'admin', 'Administrador',
   'Gestiona gente, proyectos y ajustes. No toca la facturación.',
   array[
     'project.read','project.write','project.create','project.delete',
     'member.invite','member.remove','member.manage','role.manage',
     'export.create','comment.create','comment.resolve',
     'task.assign','automation.manage','template.manage','settings.manage',
     'audit.read'
   ], true, 80),
  (null, 'editor', 'Editor',
   'Trabaja la obra y coordina a quien escribe.',
   array[
     'project.read','project.write','project.create',
     'export.create','comment.create','comment.resolve',
     'task.assign','template.manage'
   ], true, 60),
  (null, 'writer', 'Autor',
   'Escribe y construye dentro de los proyectos del espacio.',
   array['project.read','project.write','export.create','comment.create'],
   true, 40),
  (null, 'reviewer', 'Revisor',
   'Lee y comenta sin modificar la obra.',
   array['project.read','comment.create','comment.resolve'], true, 20),
  (null, 'viewer', 'Lector',
   'Solo lectura.',
   array['project.read'], true, 10)
on conflict (key) where workspace_id is null do update set
  name = excluded.name,
  description = excluded.description,
  capabilities = excluded.capabilities,
  rank = excluded.rank;

-- ─── Resolución de capacidades ──────────────────────────────────────────────

create or replace function public.atelier_workspace_capabilities(
  p_workspace_id uuid,
  p_profile_id uuid default auth.uid()
)
returns text[]
language sql
stable
security definer
set search_path = ''
as $fn$
  with member as (
    select m.role_key
    from public.atelier_workspace_members m
    where m.workspace_id = p_workspace_id
      and m.profile_id = p_profile_id
      and m.status = 'active'
  ),
  role_caps as (
    -- El rol propio del espacio manda sobre el homónimo del sistema.
    select coalesce(
      (select r.capabilities
         from public.atelier_workspace_roles r, member
        where r.workspace_id = p_workspace_id and r.key = member.role_key),
      (select r.capabilities
         from public.atelier_workspace_roles r, member
        where r.workspace_id is null and r.key = member.role_key),
      '{}'::text[]
    ) as caps
  ),
  granted as (
    select array_agg(p.capability) as caps
    from public.atelier_workspace_permissions p
    where p.workspace_id = p_workspace_id
      and p.profile_id = p_profile_id
      and p.effect = 'grant'
  ),
  denied as (
    select coalesce(array_agg(p.capability), '{}'::text[]) as caps
    from public.atelier_workspace_permissions p
    where p.workspace_id = p_workspace_id
      and p.profile_id = p_profile_id
      and p.effect = 'deny'
  )
  select coalesce(
    array(
      select distinct c
      from role_caps rc
      cross join granted g
      cross join denied d
      cross join lateral unnest(rc.caps || coalesce(g.caps, '{}'::text[])) as c
      where not (c = any (d.caps))
    ),
    '{}'::text[]
  )
  where exists (select 1 from member);
$fn$;

create or replace function public.atelier_has_capability(
  p_workspace_id uuid,
  p_capability text,
  p_profile_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $fn$
  select coalesce(
    p_capability = any (
      public.atelier_workspace_capabilities(p_workspace_id, p_profile_id)
    ),
    false
  );
$fn$;

create or replace function public.atelier_is_workspace_member(
  p_workspace_id uuid,
  p_profile_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $fn$
  select exists (
    select 1 from public.atelier_workspace_members m
    where m.workspace_id = p_workspace_id
      and m.profile_id = p_profile_id
      and m.status = 'active'
  );
$fn$;

-- ─── updated_at ─────────────────────────────────────────────────────────────

do $mig$
declare
  t text;
begin
  foreach t in array array[
    'atelier_workspaces', 'atelier_workspace_roles', 'atelier_workspace_members'
  ] loop
    execute format('drop trigger if exists %I on public.%I', t || '_set_updated_at', t);
    execute format(
      'create trigger %I before update on public.%I
         for each row execute function public.set_updated_at()',
      t || '_set_updated_at', t
    );
  end loop;
end $mig$;

-- ─── RLS ────────────────────────────────────────────────────────────────────
--
-- Todo lo que altera la pertenencia o el poder dentro de un espacio pasa por
-- RPC. El cliente lee su espacio y poco más.

alter table public.atelier_workspaces enable row level security;
alter table public.atelier_workspace_roles enable row level security;
alter table public.atelier_workspace_members enable row level security;
alter table public.atelier_workspace_permissions enable row level security;
alter table public.atelier_invitations enable row level security;
alter table public.atelier_audit_log enable row level security;

drop policy if exists "atelier_workspaces_select_member" on public.atelier_workspaces;
create policy "atelier_workspaces_select_member" on public.atelier_workspaces
  for select to authenticated
  using (public.atelier_is_workspace_member(id));

-- Renombrar el espacio o cambiar su avatar es rutina; se permite en directo a
-- quien tenga settings.manage. Dueño, plan y estado no se tocan aquí: los
-- protege el guardián de columnas de más abajo.
drop policy if exists "atelier_workspaces_update_manager" on public.atelier_workspaces;
create policy "atelier_workspaces_update_manager" on public.atelier_workspaces
  for update to authenticated
  using (public.atelier_has_capability(id, 'settings.manage'))
  with check (public.atelier_has_capability(id, 'settings.manage'));

drop policy if exists "atelier_workspace_roles_select" on public.atelier_workspace_roles;
create policy "atelier_workspace_roles_select" on public.atelier_workspace_roles
  for select to authenticated
  using (workspace_id is null or public.atelier_is_workspace_member(workspace_id));

drop policy if exists "atelier_workspace_members_select" on public.atelier_workspace_members;
create policy "atelier_workspace_members_select" on public.atelier_workspace_members
  for select to authenticated
  using (
    profile_id = (select auth.uid())
    or public.atelier_is_workspace_member(workspace_id)
  );

drop policy if exists "atelier_workspace_permissions_select"
  on public.atelier_workspace_permissions;
create policy "atelier_workspace_permissions_select"
  on public.atelier_workspace_permissions
  for select to authenticated
  using (
    profile_id = (select auth.uid())
    or public.atelier_has_capability(workspace_id, 'member.manage')
  );

drop policy if exists "atelier_invitations_select" on public.atelier_invitations;
create policy "atelier_invitations_select" on public.atelier_invitations
  for select to authenticated
  using (
    invitee_id = (select auth.uid())
    or invited_by = (select auth.uid())
    or (workspace_id is not null
        and public.atelier_has_capability(workspace_id, 'member.invite'))
  );

drop policy if exists "atelier_audit_log_select" on public.atelier_audit_log;
create policy "atelier_audit_log_select" on public.atelier_audit_log
  for select to authenticated
  using (
    (workspace_id is not null and public.atelier_has_capability(workspace_id, 'audit.read'))
    or (workspace_id is null and exists (
      select 1 from public.atelier_projects p
      where p.id = project_id and p.profile_id = (select auth.uid())
    ))
  );

-- Guardián de columnas: replica la idea que ya protege `profiles`. Un miembro
-- con settings.manage puede renombrar el espacio, pero no regalarse el plan
-- Teams ni cambiar de dueño desde el cliente.
create or replace function public.atelier_guard_workspace_columns()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $fn$
begin
  if current_user in ('authenticated', 'anon') then
    if new.owner_id is distinct from old.owner_id
       or new.billing_owner_id is distinct from old.billing_owner_id
       or new.plan_code is distinct from old.plan_code
       or new.status is distinct from old.status
       or new.slug is distinct from old.slug
       or new.created_at is distinct from old.created_at
       or new.id is distinct from old.id then
      raise exception 'Estas columnas del workspace solo cambian desde el servidor'
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$fn$;

drop trigger if exists atelier_workspaces_guard on public.atelier_workspaces;
create trigger atelier_workspaces_guard
  before update on public.atelier_workspaces
  for each row execute function public.atelier_guard_workspace_columns();

grant select on public.atelier_workspaces to authenticated;
grant update on public.atelier_workspaces to authenticated;
grant select on public.atelier_workspace_roles to authenticated;
grant select on public.atelier_workspace_members to authenticated;
grant select on public.atelier_workspace_permissions to authenticated;
grant select on public.atelier_invitations to authenticated;
grant select on public.atelier_audit_log to authenticated;

revoke all on function public.atelier_workspace_capabilities(uuid, uuid) from public;
revoke all on function public.atelier_has_capability(uuid, text, uuid) from public;
revoke all on function public.atelier_is_workspace_member(uuid, uuid) from public;
grant execute on function public.atelier_workspace_capabilities(uuid, uuid) to authenticated;
grant execute on function public.atelier_has_capability(uuid, text, uuid) to authenticated;
grant execute on function public.atelier_is_workspace_member(uuid, uuid) to authenticated;
