-- Corvus Atelier — colaboración sobre un proyecto.
--
-- Hasta ahora un proyecto era estrictamente de una persona: todas las
-- políticas de Atelier comparan `profile_id` con `auth.uid()`. Aquí se
-- **añaden** políticas, no se sustituyen: PostgreSQL une con OR las políticas
-- de un mismo comando, así que el camino del dueño sigue exactamente igual de
-- corto y el del colaborador se suma al lado.
--
-- Los roles de colaboración son los mismos del sistema que usan los
-- workspaces. Una sola tabla de capacidades para los dos casos: invitar a una
-- persona a un proyecto y darle un asiento en un estudio son la misma idea a
-- distinta escala.

create table if not exists public.atelier_project_collaborators (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.atelier_projects(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role_key text not null default 'viewer',
  status text not null default 'active'
    check (status in ('invited', 'active', 'revoked')),
  invited_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (project_id, profile_id)
);

create index if not exists atelier_project_collaborators_profile_idx
  on public.atelier_project_collaborators (profile_id, status);

create table if not exists public.atelier_comments (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.atelier_projects(id) on delete cascade,
  node_id uuid references public.atelier_nodes(id) on delete cascade,
  parent_id uuid references public.atelier_comments(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (length(body) between 1 and 8000),
  kind text not null default 'comment' check (kind in ('comment', 'suggestion')),
  anchor jsonb not null default '{}'::jsonb,
  status text not null default 'open'
    check (status in ('open', 'resolved', 'deleted')),
  mentions uuid[] not null default '{}'::uuid[],
  resolved_by uuid references public.profiles(id) on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists atelier_comments_project_idx
  on public.atelier_comments (project_id, created_at desc);

create index if not exists atelier_comments_node_idx
  on public.atelier_comments (node_id, created_at);

-- ─── Capacidades sobre un proyecto ──────────────────────────────────────────

create or replace function public.atelier_project_capabilities(
  p_project_id uuid,
  p_profile_id uuid default auth.uid()
)
returns text[]
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_owner uuid;
  v_workspace uuid;
  v_role text;
  v_caps text[];
begin
  select p.profile_id, p.workspace_id into v_owner, v_workspace
  from public.atelier_projects p where p.id = p_project_id;

  if v_owner is null then return '{}'::text[]; end if;

  -- El autor manda sobre su obra sin depender de rol ni de plan.
  if v_owner = p_profile_id then
    return array[
      'project.read', 'project.write', 'project.delete', 'export.create',
      'comment.create', 'comment.resolve', 'task.assign',
      'automation.manage', 'template.manage', 'member.invite', 'member.remove'
    ];
  end if;

  if v_workspace is not null then
    v_caps := public.atelier_workspace_capabilities(v_workspace, p_profile_id);
    if array_length(v_caps, 1) is not null then return v_caps; end if;
  end if;

  select c.role_key into v_role
  from public.atelier_project_collaborators c
  where c.project_id = p_project_id
    and c.profile_id = p_profile_id
    and c.status = 'active';

  if v_role is null then return '{}'::text[]; end if;

  select r.capabilities into v_caps
  from public.atelier_workspace_roles r
  where r.workspace_id is null and r.key = v_role;

  return coalesce(v_caps, '{}'::text[]);
end;
$fn$;

create or replace function public.atelier_can_read_project(
  p_project_id uuid,
  p_profile_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $fn$
  select 'project.read' = any (
    public.atelier_project_capabilities(p_project_id, p_profile_id)
  );
$fn$;

create or replace function public.atelier_can_write_project(
  p_project_id uuid,
  p_profile_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $fn$
  select 'project.write' = any (
    public.atelier_project_capabilities(p_project_id, p_profile_id)
  );
$fn$;

-- ─── El límite de colaboradores, en el servidor ─────────────────────────────
--
-- Comprobarlo solo en Flutter sería decorativo: cualquiera con la llave
-- publicable podría insertar la fila 11 con una petición directa.

create or replace function public.atelier_enforce_collaborator_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_owner uuid;
  v_workspace uuid;
  v_limit bigint;
  v_count integer;
begin
  if new.status <> 'active' then return new; end if;

  select p.profile_id, p.workspace_id into v_owner, v_workspace
  from public.atelier_projects p where p.id = new.project_id;

  if v_owner is null then
    raise exception 'ATELIER_PROJECT_NOT_FOUND' using errcode = '23503';
  end if;

  if not public.has_entitlement(v_owner, 'atelier.collaboration', v_workspace) then
    raise exception 'ATELIER_COLLABORATION_NOT_INCLUDED' using errcode = '42501';
  end if;

  v_limit := public.entitlement_limit(
    v_owner, 'atelier.collaborators.max', v_workspace
  );

  if v_limit = -1 then return new; end if;

  select count(*) into v_count
  from public.atelier_project_collaborators c
  where c.project_id = new.project_id
    and c.status = 'active'
    and c.id is distinct from new.id;

  if v_count + 1 > v_limit then
    raise exception 'ATELIER_COLLABORATOR_LIMIT_REACHED'
      using errcode = '53100',
            detail = format('activos=%s limite=%s', v_count, v_limit),
            hint = 'Sube de plan o retira a alguien del proyecto. Nadie pierde su trabajo por esto.';
  end if;

  return new;
end;
$fn$;

drop trigger if exists atelier_collaborator_limit on public.atelier_project_collaborators;
create trigger atelier_collaborator_limit
  before insert or update on public.atelier_project_collaborators
  for each row execute function public.atelier_enforce_collaborator_limit();

-- ─── Políticas añadidas al Atelier existente ────────────────────────────────

alter table public.atelier_project_collaborators enable row level security;
alter table public.atelier_comments enable row level security;

drop policy if exists "atelier_projects_select_shared" on public.atelier_projects;
create policy "atelier_projects_select_shared" on public.atelier_projects
  for select to authenticated
  using (public.atelier_can_read_project(id));

drop policy if exists "atelier_projects_update_shared" on public.atelier_projects;
create policy "atelier_projects_update_shared" on public.atelier_projects
  for update to authenticated
  using (public.atelier_can_write_project(id))
  with check (public.atelier_can_write_project(id));

drop policy if exists "atelier_nodes_select_shared" on public.atelier_nodes;
create policy "atelier_nodes_select_shared" on public.atelier_nodes
  for select to authenticated
  using (public.atelier_can_read_project(project_id));

drop policy if exists "atelier_nodes_insert_shared" on public.atelier_nodes;
create policy "atelier_nodes_insert_shared" on public.atelier_nodes
  for insert to authenticated
  with check (
    profile_id = (select auth.uid())
    and public.atelier_can_write_project(project_id)
  );

drop policy if exists "atelier_nodes_update_shared" on public.atelier_nodes;
create policy "atelier_nodes_update_shared" on public.atelier_nodes
  for update to authenticated
  using (public.atelier_can_write_project(project_id))
  with check (public.atelier_can_write_project(project_id));

drop policy if exists "atelier_relations_select_shared" on public.atelier_relations;
create policy "atelier_relations_select_shared" on public.atelier_relations
  for select to authenticated
  using (public.atelier_can_read_project(project_id));

drop policy if exists "atelier_relations_insert_shared" on public.atelier_relations;
create policy "atelier_relations_insert_shared" on public.atelier_relations
  for insert to authenticated
  with check (
    profile_id = (select auth.uid())
    and public.atelier_can_write_project(project_id)
  );

drop policy if exists "atelier_versions_select_shared" on public.atelier_versions;
create policy "atelier_versions_select_shared" on public.atelier_versions
  for select to authenticated
  using (public.atelier_can_read_project(project_id));

drop policy if exists "atelier_versions_insert_shared" on public.atelier_versions;
create policy "atelier_versions_insert_shared" on public.atelier_versions
  for insert to authenticated
  with check (
    profile_id = (select auth.uid())
    and public.atelier_can_write_project(project_id)
  );

-- Colaboradores: se leen desde el proyecto; alta y baja pasan por RPC para
-- que el límite del plan y la auditoría no dependan del cliente.
drop policy if exists "atelier_project_collaborators_select"
  on public.atelier_project_collaborators;
create policy "atelier_project_collaborators_select"
  on public.atelier_project_collaborators
  for select to authenticated
  using (
    profile_id = (select auth.uid())
    or public.atelier_can_read_project(project_id)
  );

drop policy if exists "atelier_comments_select" on public.atelier_comments;
create policy "atelier_comments_select" on public.atelier_comments
  for select to authenticated
  using (status <> 'deleted' and public.atelier_can_read_project(project_id));

drop policy if exists "atelier_comments_insert" on public.atelier_comments;
create policy "atelier_comments_insert" on public.atelier_comments
  for insert to authenticated
  with check (
    profile_id = (select auth.uid())
    and 'comment.create' = any (public.atelier_project_capabilities(project_id))
  );

-- Editar el propio comentario es rutina. Resolver hilos ajenos exige
-- capacidad, y por eso va aparte.
drop policy if exists "atelier_comments_update_own" on public.atelier_comments;
create policy "atelier_comments_update_own" on public.atelier_comments
  for update to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

drop policy if exists "atelier_comments_update_resolver" on public.atelier_comments;
create policy "atelier_comments_update_resolver" on public.atelier_comments
  for update to authenticated
  using ('comment.resolve' = any (public.atelier_project_capabilities(project_id)))
  with check ('comment.resolve' = any (public.atelier_project_capabilities(project_id)));

do $mig$
declare
  t text;
begin
  foreach t in array array['atelier_project_collaborators', 'atelier_comments'] loop
    execute format('drop trigger if exists %I on public.%I', t || '_set_updated_at', t);
    execute format(
      'create trigger %I before update on public.%I
         for each row execute function public.set_updated_at()',
      t || '_set_updated_at', t
    );
  end loop;
end $mig$;

grant select on public.atelier_project_collaborators to authenticated;
grant select, insert, update on public.atelier_comments to authenticated;

revoke all on function public.atelier_project_capabilities(uuid, uuid) from public;
revoke all on function public.atelier_can_read_project(uuid, uuid) from public;
revoke all on function public.atelier_can_write_project(uuid, uuid) from public;
grant execute on function public.atelier_project_capabilities(uuid, uuid) to authenticated;
grant execute on function public.atelier_can_read_project(uuid, uuid) to authenticated;
grant execute on function public.atelier_can_write_project(uuid, uuid) to authenticated;
