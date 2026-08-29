-- Corvus Aeternum / Atelier
-- Apply this file in the Supabase SQL editor, then reload the app.
-- Every table is private by default through RLS and scoped to auth.uid().

create extension if not exists pgcrypto;

create table if not exists public.atelier_projects (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  type text not null default 'Obra',
  status text not null default 'idea',
  genre text not null default '',
  universe text not null default '',
  language text not null default 'es',
  visibility text not null default 'private',
  weekly_word_goal integer not null default 0,
  public_progress_enabled boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.atelier_nodes (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.atelier_projects(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null,
  title text not null,
  body text not null default '',
  status text not null default 'draft',
  canon_status text not null default 'canon',
  visibility text not null default 'private',
  tags text[] not null default '{}'::text[],
  metadata jsonb not null default '{}'::jsonb,
  position integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.atelier_relations (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.atelier_projects(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  source_node_id uuid not null references public.atelier_nodes(id) on delete cascade,
  relation_type text not null,
  target_node_id uuid not null references public.atelier_nodes(id) on delete cascade,
  description text not null default '',
  canon_status text not null default 'canon',
  created_at timestamptz not null default now(),
  constraint atelier_relations_not_self check (source_node_id <> target_node_id)
);

create table if not exists public.atelier_versions (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.atelier_projects(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  label text not null,
  description text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists atelier_projects_profile_idx
  on public.atelier_projects(profile_id, updated_at desc);

create index if not exists atelier_nodes_project_idx
  on public.atelier_nodes(project_id, kind, position);

create index if not exists atelier_nodes_tags_idx
  on public.atelier_nodes using gin(tags);

create index if not exists atelier_nodes_metadata_idx
  on public.atelier_nodes using gin(metadata);

create index if not exists atelier_relations_project_idx
  on public.atelier_relations(project_id);

create index if not exists atelier_versions_project_idx
  on public.atelier_versions(project_id, created_at desc);

alter table public.atelier_projects enable row level security;
alter table public.atelier_nodes enable row level security;
alter table public.atelier_relations enable row level security;
alter table public.atelier_versions enable row level security;

drop policy if exists "atelier_projects_select_own" on public.atelier_projects;
create policy "atelier_projects_select_own"
  on public.atelier_projects for select
  to authenticated
  using ((select auth.uid()) = profile_id);

drop policy if exists "atelier_projects_insert_own" on public.atelier_projects;
create policy "atelier_projects_insert_own"
  on public.atelier_projects for insert
  to authenticated
  with check ((select auth.uid()) = profile_id);

drop policy if exists "atelier_projects_update_own" on public.atelier_projects;
create policy "atelier_projects_update_own"
  on public.atelier_projects for update
  to authenticated
  using ((select auth.uid()) = profile_id)
  with check ((select auth.uid()) = profile_id);

drop policy if exists "atelier_projects_delete_own" on public.atelier_projects;
create policy "atelier_projects_delete_own"
  on public.atelier_projects for delete
  to authenticated
  using ((select auth.uid()) = profile_id);

drop policy if exists "atelier_nodes_select_own" on public.atelier_nodes;
create policy "atelier_nodes_select_own"
  on public.atelier_nodes for select
  to authenticated
  using ((select auth.uid()) = profile_id);

drop policy if exists "atelier_nodes_insert_own" on public.atelier_nodes;
create policy "atelier_nodes_insert_own"
  on public.atelier_nodes for insert
  to authenticated
  with check (
    (select auth.uid()) = profile_id
    and exists (
      select 1 from public.atelier_projects p
      where p.id = project_id and p.profile_id = (select auth.uid())
    )
  );

drop policy if exists "atelier_nodes_update_own" on public.atelier_nodes;
create policy "atelier_nodes_update_own"
  on public.atelier_nodes for update
  to authenticated
  using ((select auth.uid()) = profile_id)
  with check ((select auth.uid()) = profile_id);

drop policy if exists "atelier_nodes_delete_own" on public.atelier_nodes;
create policy "atelier_nodes_delete_own"
  on public.atelier_nodes for delete
  to authenticated
  using ((select auth.uid()) = profile_id);

drop policy if exists "atelier_relations_select_own" on public.atelier_relations;
create policy "atelier_relations_select_own"
  on public.atelier_relations for select
  to authenticated
  using ((select auth.uid()) = profile_id);

drop policy if exists "atelier_relations_insert_own" on public.atelier_relations;
create policy "atelier_relations_insert_own"
  on public.atelier_relations for insert
  to authenticated
  with check (
    (select auth.uid()) = profile_id
    and exists (
      select 1 from public.atelier_projects p
      where p.id = project_id and p.profile_id = (select auth.uid())
    )
  );

drop policy if exists "atelier_relations_delete_own" on public.atelier_relations;
create policy "atelier_relations_delete_own"
  on public.atelier_relations for delete
  to authenticated
  using ((select auth.uid()) = profile_id);

drop policy if exists "atelier_versions_select_own" on public.atelier_versions;
create policy "atelier_versions_select_own"
  on public.atelier_versions for select
  to authenticated
  using ((select auth.uid()) = profile_id);

drop policy if exists "atelier_versions_insert_own" on public.atelier_versions;
create policy "atelier_versions_insert_own"
  on public.atelier_versions for insert
  to authenticated
  with check (
    (select auth.uid()) = profile_id
    and exists (
      select 1 from public.atelier_projects p
      where p.id = project_id and p.profile_id = (select auth.uid())
    )
  );

grant select, insert, update, delete on public.atelier_projects to authenticated;
grant select, insert, update, delete on public.atelier_nodes to authenticated;
grant select, insert, delete on public.atelier_relations to authenticated;
grant select, insert on public.atelier_versions to authenticated;
