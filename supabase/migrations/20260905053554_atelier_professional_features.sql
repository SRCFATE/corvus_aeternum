-- Corvus Atelier — capacidades Professional.
--
-- Historial profundo, automatizaciones, campos propios y producción editorial.
-- Todas comparten una regla: al perder el plan, la función se DETIENE, nunca
-- destruye. Una automatización de alguien que vuelve a Free deja de dispararse
-- pero sigue guardada, con sus condiciones y su historial, esperando el día en
-- que vuelva. Lo mismo con los campos personalizados y los snapshots.

-- ─── Historial ──────────────────────────────────────────────────────────────
--
-- `atelier_versions` ya existía como línea de tiempo con etiquetas. Se le
-- añade el contenido, que es lo que convierte una marca en un punto de
-- restauración. Las columnas son nuevas y nulables: ninguna versión anterior
-- se ve afectada.

alter table public.atelier_versions
  add column if not exists snapshot jsonb,
  add column if not exists kind text not null default 'manual',
  add column if not exists word_count integer not null default 0,
  add column if not exists node_count integer not null default 0,
  add column if not exists size_bytes integer not null default 0;

do $mig$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'atelier_versions_kind_check'
  ) then
    alter table public.atelier_versions
      add constraint atelier_versions_kind_check
      check (kind in ('manual', 'auto', 'restore', 'import'));
  end if;
end $mig$;

-- Un punto de restauración se toma siempre, en todos los planes: capturar es
-- barato y borrar historial sería exactamente lo que este producto promete no
-- hacer. Lo que distingue a Professional es poder VOLVER a él.
create or replace function public.atelier_create_snapshot(
  p_project_id uuid,
  p_label text default null,
  p_description text default '',
  p_kind text default 'manual'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_snapshot jsonb;
  v_words integer := 0;
  v_nodes integer := 0;
  v_id uuid;
  v_label text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHENTICATED');
  end if;

  if not public.atelier_can_write_project(p_project_id, v_uid) then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHORIZED');
  end if;

  select
    jsonb_build_object(
      'project', to_jsonb(p.*),
      'nodes', coalesce((
        select jsonb_agg(to_jsonb(n.*) order by n.position, n.created_at)
        from public.atelier_nodes n where n.project_id = p.id
      ), '[]'::jsonb),
      'relations', coalesce((
        select jsonb_agg(to_jsonb(r.*) order by r.created_at)
        from public.atelier_relations r where r.project_id = p.id
      ), '[]'::jsonb)
    )
  into v_snapshot
  from public.atelier_projects p
  where p.id = p_project_id;

  if v_snapshot is null then
    return jsonb_build_object('ok', false, 'reason_code', 'ATELIER_PROJECT_NOT_FOUND');
  end if;

  select count(*), coalesce(sum(
    array_length(regexp_split_to_array(trim(coalesce(n.body, '')), '\s+'), 1)
  ), 0)
  into v_nodes, v_words
  from public.atelier_nodes n
  where n.project_id = p_project_id and trim(coalesce(n.body, '')) <> '';

  v_label := nullif(trim(coalesce(p_label, '')), '');
  if v_label is null then
    select 'v' || (count(*) + 1)::text into v_label
    from public.atelier_versions where project_id = p_project_id;
  end if;

  insert into public.atelier_versions (
    project_id, profile_id, label, description, metadata,
    snapshot, kind, word_count, node_count, size_bytes
  ) values (
    p_project_id, v_uid, v_label, coalesce(p_description, ''),
    jsonb_build_object('word_count', v_words, 'node_count', v_nodes),
    v_snapshot, coalesce(p_kind, 'manual'), v_words, v_nodes,
    length(v_snapshot::text)
  )
  returning id into v_id;

  return jsonb_build_object(
    'ok', true, 'version_id', v_id, 'label', v_label,
    'word_count', v_words, 'node_count', v_nodes
  );
end;
$fn$;

-- Las versiones se listan enteras siempre. Lo que cambia con el plan es el
-- indicador `restorable`: fuera de la ventana del plan la versión se ve, se
-- conserva y se puede exportar, pero no se restaura ni se compara.
create or replace function public.get_atelier_versions(p_project_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_workspace uuid;
  v_window bigint;
  v_advanced boolean;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHENTICATED');
  end if;

  if not public.atelier_can_read_project(p_project_id, v_uid) then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHORIZED');
  end if;

  select p.profile_id, p.workspace_id into v_owner, v_workspace
  from public.atelier_projects p where p.id = p_project_id;

  v_window := public.entitlement_limit(
    v_owner, 'atelier.version_history.max_snapshots', v_workspace
  );
  v_advanced := public.has_entitlement(
    v_owner, 'atelier.version_history.advanced', v_workspace
  );

  return jsonb_build_object(
    'ok', true,
    'advanced', v_advanced,
    'window', v_window,
    'versions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', v.id,
        'label', v.label,
        'description', v.description,
        'kind', v.kind,
        'word_count', v.word_count,
        'node_count', v.node_count,
        'has_snapshot', v.snapshot is not null,
        'restorable', v_advanced
          and v.snapshot is not null
          and (v_window = -1 or v.rn <= v_window),
        'created_at', v.created_at
      ) order by v.created_at desc)
      from (
        select av.*, row_number() over (order by av.created_at desc) as rn
        from public.atelier_versions av
        where av.project_id = p_project_id
      ) v
    ), '[]'::jsonb)
  );
end;
$fn$;

-- Restaurar NO borra: primero deja un punto de la situación actual, y luego
-- reescribe. Un "deshacer" que destruye lo que había no es un deshacer.
create or replace function public.atelier_restore_version(p_version_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_project uuid;
  v_owner uuid;
  v_workspace uuid;
  v_snapshot jsonb;
  v_window bigint;
  v_rank bigint;
  v_restored integer := 0;
  n jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHENTICATED');
  end if;

  select v.project_id, v.snapshot into v_project, v_snapshot
  from public.atelier_versions v where v.id = p_version_id;

  if v_project is null then
    return jsonb_build_object('ok', false, 'reason_code', 'ATELIER_VERSION_NOT_FOUND');
  end if;

  if not public.atelier_can_write_project(v_project, v_uid) then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHORIZED');
  end if;

  if v_snapshot is null then
    return jsonb_build_object('ok', false, 'reason_code', 'ATELIER_VERSION_WITHOUT_SNAPSHOT');
  end if;

  select p.profile_id, p.workspace_id into v_owner, v_workspace
  from public.atelier_projects p where p.id = v_project;

  if not public.has_entitlement(
       v_owner, 'atelier.version_history.advanced', v_workspace) then
    return jsonb_build_object('ok', false, 'reason_code', 'ATELIER_HISTORY_NOT_INCLUDED');
  end if;

  v_window := public.entitlement_limit(
    v_owner, 'atelier.version_history.max_snapshots', v_workspace
  );

  if v_window <> -1 then
    select rn into v_rank from (
      select av.id, row_number() over (order by av.created_at desc) as rn
      from public.atelier_versions av where av.project_id = v_project
    ) t where t.id = p_version_id;

    if v_rank > v_window then
      return jsonb_build_object('ok', false, 'reason_code', 'ATELIER_VERSION_OUT_OF_WINDOW');
    end if;
  end if;

  -- Red de seguridad antes de tocar nada.
  perform public.atelier_create_snapshot(
    v_project, null, 'Antes de restaurar una versión anterior.', 'restore'
  );

  for n in select * from jsonb_array_elements(v_snapshot->'nodes')
  loop
    update public.atelier_nodes set
      title = coalesce(n->>'title', title),
      body = coalesce(n->>'body', body),
      status = coalesce(n->>'status', status),
      canon_status = coalesce(n->>'canon_status', canon_status),
      metadata = coalesce(n->'metadata', metadata),
      position = coalesce((n->>'position')::integer, position),
      updated_at = now()
    where id = (n->>'id')::uuid and project_id = v_project;

    if found then v_restored := v_restored + 1; end if;
  end loop;

  insert into public.atelier_audit_log (
    workspace_id, project_id, actor_id, action, object_type, object_id, metadata
  ) values (
    v_workspace, v_project, v_uid, 'version.restore', 'atelier_version',
    p_version_id::text, jsonb_build_object('nodes_restored', v_restored)
  );

  return jsonb_build_object('ok', true, 'nodes_restored', v_restored);
end;
$fn$;

-- ─── Automatizaciones ───────────────────────────────────────────────────────

create table if not exists public.atelier_automations (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.atelier_projects(id) on delete cascade,
  workspace_id uuid references public.atelier_workspaces(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  description text not null default '',
  trigger_event text not null,
  conditions jsonb not null default '[]'::jsonb,
  actions jsonb not null default '[]'::jsonb,
  is_enabled boolean not null default true,
  run_count integer not null default 0,
  last_run_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint atelier_automations_trigger_check check (
    trigger_event in ('node.created', 'node.updated', 'node.status_changed')
  )
);

create index if not exists atelier_automations_project_idx
  on public.atelier_automations (project_id, trigger_event, is_enabled);

create table if not exists public.atelier_automation_runs (
  id bigserial primary key,
  automation_id uuid not null
    references public.atelier_automations(id) on delete cascade,
  node_id uuid references public.atelier_nodes(id) on delete set null,
  status text not null check (status in ('applied', 'skipped', 'failed')),
  detail text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists atelier_automation_runs_automation_idx
  on public.atelier_automation_runs (automation_id, created_at desc);

-- Evalúa una condición suelta contra el nodo que disparó la regla.
create or replace function public.atelier_condition_matches(
  p_node public.atelier_nodes,
  p_condition jsonb
)
returns boolean
language plpgsql
immutable
set search_path = ''
as $fn$
declare
  v_field text := p_condition->>'field';
  v_op text := coalesce(p_condition->>'op', 'eq');
  v_value text := p_condition->>'value';
  v_actual text;
begin
  if v_field = 'tags' then
    if v_op = 'contains' then
      return v_value = any (p_node.tags);
    end if;
    return false;
  end if;

  v_actual := case v_field
    when 'kind' then p_node.kind
    when 'status' then p_node.status
    when 'canon_status' then p_node.canon_status
    when 'visibility' then p_node.visibility
    when 'title' then p_node.title
    else null
  end;

  if v_actual is null then return false; end if;

  return case v_op
    when 'eq' then v_actual = v_value
    when 'neq' then v_actual <> v_value
    when 'contains' then position(lower(v_value) in lower(v_actual)) > 0
    when 'in' then v_actual = any (
      select jsonb_array_elements_text(p_condition->'values')
    )
    else false
  end;
end;
$fn$;

-- El motor. Se dispara desde un trigger sobre `atelier_nodes` y respeta tres
-- cosas: el derecho del dueño (si lo pierde, las reglas quedan en pausa), el
-- tope de reglas activas del plan, y la profundidad del trigger para que una
-- acción no vuelva a disparar la misma regla en cascada.
create or replace function public.atelier_dispatch_automations()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_event text;
  v_owner uuid;
  v_workspace uuid;
  v_limit bigint;
  v_applied integer := 0;
  a record;
  act jsonb;
  cond jsonb;
  v_ok boolean;
begin
  -- Una acción escribe en atelier_nodes y volvería a entrar aquí.
  if pg_trigger_depth() > 1 then return new; end if;

  if tg_op = 'INSERT' then
    v_event := 'node.created';
  elsif old.status is distinct from new.status then
    v_event := 'node.status_changed';
  else
    v_event := 'node.updated';
  end if;

  select p.profile_id, p.workspace_id into v_owner, v_workspace
  from public.atelier_projects p where p.id = new.project_id;

  if v_owner is null then return new; end if;

  if not public.has_entitlement(v_owner, 'atelier.automation', v_workspace) then
    return new;
  end if;

  v_limit := public.entitlement_limit(v_owner, 'atelier.automations.max', v_workspace);

  for a in
    select * from public.atelier_automations au
    where au.project_id = new.project_id
      and au.is_enabled
      and au.trigger_event = v_event
    order by au.created_at
    limit case when v_limit = -1 then null else greatest(v_limit, 0) end
  loop
    v_ok := true;
    for cond in select * from jsonb_array_elements(a.conditions)
    loop
      if not public.atelier_condition_matches(new, cond) then
        v_ok := false;
        exit;
      end if;
    end loop;

    if not v_ok then
      insert into public.atelier_automation_runs (automation_id, node_id, status, detail)
      values (a.id, new.id, 'skipped', 'Las condiciones no se cumplieron.');
      continue;
    end if;

    for act in select * from jsonb_array_elements(a.actions)
    loop
      case act->>'type'
        when 'set_status' then
          new.status := coalesce(act->>'value', new.status);
        when 'add_tag' then
          if not (act->>'value' = any (new.tags)) then
            new.tags := new.tags || array[act->>'value'];
          end if;
        when 'set_metadata' then
          new.metadata := new.metadata
            || jsonb_build_object(act->>'key', act->'value');
        when 'create_task' then
          insert into public.atelier_nodes (
            project_id, profile_id, kind, title, body, status, metadata
          ) values (
            new.project_id, v_owner, 'task',
            coalesce(act->>'value', 'Tarea automática'),
            format('Generada por la automatización «%s» sobre «%s».', a.name, new.title),
            'draft',
            jsonb_build_object('automation_id', a.id, 'source_node_id', new.id)
          );
        else
          null;
      end case;
    end loop;

    update public.atelier_automations
      set run_count = run_count + 1, last_run_at = now()
      where id = a.id;

    insert into public.atelier_automation_runs (automation_id, node_id, status, detail)
    values (a.id, new.id, 'applied', v_event);

    v_applied := v_applied + 1;
  end loop;

  return new;
end;
$fn$;

drop trigger if exists atelier_nodes_automations on public.atelier_nodes;
create trigger atelier_nodes_automations
  before insert or update on public.atelier_nodes
  for each row execute function public.atelier_dispatch_automations();

-- ─── Campos personalizados ──────────────────────────────────────────────────

create table if not exists public.atelier_custom_fields (
  id uuid primary key default gen_random_uuid(),
  scope text not null default 'project' check (scope in ('project', 'workspace')),
  project_id uuid references public.atelier_projects(id) on delete cascade,
  workspace_id uuid references public.atelier_workspaces(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  key text not null,
  label text not null,
  field_type text not null default 'text'
    check (field_type in ('text', 'longtext', 'number', 'date', 'select', 'multiselect', 'boolean', 'url')),
  options jsonb not null default '[]'::jsonb,
  applies_to text[] not null default '{}'::text[],
  is_required boolean not null default false,
  sort_order smallint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint atelier_custom_fields_has_owner
    check (project_id is not null or workspace_id is not null),
  constraint atelier_custom_fields_key_shape check (key ~ '^[a-z][a-z0-9_]{0,40}$')
);

create unique index if not exists atelier_custom_fields_project_key_idx
  on public.atelier_custom_fields (project_id, key) where project_id is not null;

create unique index if not exists atelier_custom_fields_workspace_key_idx
  on public.atelier_custom_fields (workspace_id, key) where workspace_id is not null;

-- Crear un campo exige el derecho; los valores ya guardados viven en
-- `atelier_nodes.metadata` y no dependen de nada: si el plan baja, el campo
-- deja de poder crearse o editarse, pero lo escrito sigue ahí y se exporta.
create or replace function public.atelier_enforce_custom_fields()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_owner uuid;
  v_workspace uuid;
begin
  if new.project_id is not null then
    select p.profile_id, p.workspace_id into v_owner, v_workspace
    from public.atelier_projects p where p.id = new.project_id;
  else
    select w.owner_id, w.id into v_owner, v_workspace
    from public.atelier_workspaces w where w.id = new.workspace_id;
  end if;

  if v_owner is null then
    raise exception 'ATELIER_PROJECT_NOT_FOUND' using errcode = '23503';
  end if;

  if not public.has_entitlement(v_owner, 'atelier.custom_fields', v_workspace) then
    raise exception 'ATELIER_CUSTOM_FIELDS_NOT_INCLUDED' using errcode = '42501';
  end if;

  return new;
end;
$fn$;

drop trigger if exists atelier_custom_fields_guard on public.atelier_custom_fields;
create trigger atelier_custom_fields_guard
  before insert or update on public.atelier_custom_fields
  for each row execute function public.atelier_enforce_custom_fields();

-- ─── Producción editorial ───────────────────────────────────────────────────

create table if not exists public.atelier_editorial_profiles (
  project_id uuid primary key
    references public.atelier_projects(id) on delete cascade,
  manuscript_mode boolean not null default false,
  front_matter jsonb not null default '{}'::jsonb,
  back_matter jsonb not null default '{}'::jsonb,
  publication_metadata jsonb not null default '{}'::jsonb,
  isbn text,
  copyright_notice text not null default '',
  dedication text not null default '',
  acknowledgements text not null default '',
  editorial_notes text not null default '',
  style_settings jsonb not null default '{}'::jsonb,
  bureau_status text not null default 'none'
    check (bureau_status in ('none', 'draft', 'submitted', 'in_review', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.atelier_enforce_editorial()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_owner uuid;
  v_workspace uuid;
begin
  select p.profile_id, p.workspace_id into v_owner, v_workspace
  from public.atelier_projects p where p.id = new.project_id;

  if v_owner is null then
    raise exception 'ATELIER_PROJECT_NOT_FOUND' using errcode = '23503';
  end if;

  if not public.has_entitlement(v_owner, 'atelier.editorial.manuscript', v_workspace) then
    raise exception 'ATELIER_EDITORIAL_NOT_INCLUDED' using errcode = '42501';
  end if;

  return new;
end;
$fn$;

drop trigger if exists atelier_editorial_guard on public.atelier_editorial_profiles;
create trigger atelier_editorial_guard
  before insert or update on public.atelier_editorial_profiles
  for each row execute function public.atelier_enforce_editorial();

-- ─── RLS ────────────────────────────────────────────────────────────────────

alter table public.atelier_automations enable row level security;
alter table public.atelier_automation_runs enable row level security;
alter table public.atelier_custom_fields enable row level security;
alter table public.atelier_editorial_profiles enable row level security;

drop policy if exists "atelier_automations_select" on public.atelier_automations;
create policy "atelier_automations_select" on public.atelier_automations
  for select to authenticated
  using (public.atelier_can_read_project(project_id));

drop policy if exists "atelier_automations_write" on public.atelier_automations;
create policy "atelier_automations_write" on public.atelier_automations
  for all to authenticated
  using ('automation.manage' = any (public.atelier_project_capabilities(project_id)))
  with check (
    profile_id = (select auth.uid())
    and 'automation.manage' = any (public.atelier_project_capabilities(project_id))
  );

drop policy if exists "atelier_automation_runs_select" on public.atelier_automation_runs;
create policy "atelier_automation_runs_select" on public.atelier_automation_runs
  for select to authenticated
  using (
    exists (
      select 1 from public.atelier_automations a
      where a.id = automation_id and public.atelier_can_read_project(a.project_id)
    )
  );

drop policy if exists "atelier_custom_fields_select" on public.atelier_custom_fields;
create policy "atelier_custom_fields_select" on public.atelier_custom_fields
  for select to authenticated
  using (
    (project_id is not null and public.atelier_can_read_project(project_id))
    or (workspace_id is not null and public.atelier_is_workspace_member(workspace_id))
  );

drop policy if exists "atelier_custom_fields_write" on public.atelier_custom_fields;
create policy "atelier_custom_fields_write" on public.atelier_custom_fields
  for all to authenticated
  using (
    (project_id is not null and public.atelier_can_write_project(project_id))
    or (workspace_id is not null
        and public.atelier_has_capability(workspace_id, 'settings.manage'))
  )
  with check (
    profile_id = (select auth.uid())
    and (
      (project_id is not null and public.atelier_can_write_project(project_id))
      or (workspace_id is not null
          and public.atelier_has_capability(workspace_id, 'settings.manage'))
    )
  );

drop policy if exists "atelier_editorial_select" on public.atelier_editorial_profiles;
create policy "atelier_editorial_select" on public.atelier_editorial_profiles
  for select to authenticated
  using (public.atelier_can_read_project(project_id));

drop policy if exists "atelier_editorial_write" on public.atelier_editorial_profiles;
create policy "atelier_editorial_write" on public.atelier_editorial_profiles
  for all to authenticated
  using (public.atelier_can_write_project(project_id))
  with check (public.atelier_can_write_project(project_id));

do $mig$
declare
  t text;
begin
  foreach t in array array[
    'atelier_automations', 'atelier_custom_fields', 'atelier_editorial_profiles'
  ] loop
    execute format('drop trigger if exists %I on public.%I', t || '_set_updated_at', t);
    execute format(
      'create trigger %I before update on public.%I
         for each row execute function public.set_updated_at()',
      t || '_set_updated_at', t
    );
  end loop;
end $mig$;

grant select, insert, update, delete on public.atelier_automations to authenticated;
grant select on public.atelier_automation_runs to authenticated;
grant select, insert, update, delete on public.atelier_custom_fields to authenticated;
grant select, insert, update, delete on public.atelier_editorial_profiles to authenticated;

revoke all on function public.atelier_create_snapshot(uuid, text, text, text) from public;
revoke all on function public.get_atelier_versions(uuid) from public;
revoke all on function public.atelier_restore_version(uuid) from public;
grant execute on function public.atelier_create_snapshot(uuid, text, text, text) to authenticated;
grant execute on function public.get_atelier_versions(uuid) to authenticated;
grant execute on function public.atelier_restore_version(uuid) to authenticated;
