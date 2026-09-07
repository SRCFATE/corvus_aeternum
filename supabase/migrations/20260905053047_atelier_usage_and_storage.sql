-- Corvus Atelier — uso medido y cuota de almacenamiento.
--
-- La cuota es la única frontera dura del producto, porque es la única que
-- cuesta dinero real cada mes. Y aun así no destruye nada: pasarse de cuota
-- impide SUBIR archivos nuevos, jamás borra los que ya están ni cierra el
-- acceso a ellos. Alguien que cancela Professional con 15 GB guardados
-- conserva sus 15 GB, puede leerlos, descargarlos y borrar lo que sobre.
--
-- El recuento no se calcula al vuelo: se lleva en `atelier_storage_usage` con
-- triggers sobre storage.objects, porque contar bytes de un bucket entero en
-- cada subida sería una consulta creciente en el camino crítico.

-- El taller es privado. A diferencia de `works` o `avatars`, aquí viven
-- manuscritos sin publicar: el bucket no es público y se sirve con URL
-- firmada.
insert into storage.buckets (id, name, public, file_size_limit)
values ('atelier', 'atelier', false, 209715200)
on conflict (id) do nothing;

create table if not exists public.atelier_storage_usage (
  scope text not null check (scope in ('user', 'workspace')),
  owner_id uuid not null,
  bytes_used bigint not null default 0 check (bytes_used >= 0),
  objects_count integer not null default 0 check (objects_count >= 0),
  updated_at timestamptz not null default now(),
  primary key (scope, owner_id)
);

-- Contadores genéricos: palabras escritas, exportaciones emitidas, invitaciones
-- enviadas. `period` permite llevar tanto el total histórico como el mes en
-- curso sin inventar una tabla por métrica.
create table if not exists public.atelier_usage (
  id uuid primary key default gen_random_uuid(),
  scope text not null check (scope in ('user', 'workspace')),
  owner_id uuid not null,
  metric text not null,
  period text not null default 'total',
  value bigint not null default 0,
  updated_at timestamptz not null default now(),
  unique (scope, owner_id, metric, period)
);

create index if not exists atelier_usage_owner_idx
  on public.atelier_usage (scope, owner_id, metric);

-- ─── Rutas del bucket ───────────────────────────────────────────────────────
--
-- Convención: `u/{profile_id}/{project_id}/archivo` para el taller personal y
-- `w/{workspace_id}/{project_id}/archivo` para el de un estudio. El primer
-- segmento decide a qué bolsa de cuota se carga el archivo.

create or replace function public.atelier_storage_owner(p_name text)
returns table (scope text, owner_id uuid)
language plpgsql
immutable
set search_path = ''
as $fn$
declare
  parts text[] := string_to_array(p_name, '/');
begin
  if array_length(parts, 1) is null or array_length(parts, 1) < 2 then
    return;
  end if;

  begin
    if parts[1] = 'u' then
      scope := 'user'; owner_id := parts[2]::uuid; return next;
    elsif parts[1] = 'w' then
      scope := 'workspace'; owner_id := parts[2]::uuid; return next;
    end if;
  exception when invalid_text_representation then
    return;
  end;
end;
$fn$;

-- Cuánto espacio concede el plan de esa bolsa. -1 significa ilimitado.
create or replace function public.atelier_storage_limit(
  p_scope text,
  p_owner_id uuid
)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_owner uuid;
begin
  if p_scope = 'workspace' then
    select w.owner_id into v_owner
    from public.atelier_workspaces w where w.id = p_owner_id;
    if v_owner is null then return 0; end if;
    return public.entitlement_limit(
      v_owner, 'atelier.storage.max_bytes', p_owner_id
    );
  end if;

  return public.entitlement_limit(p_owner_id, 'atelier.storage.max_bytes', null);
end;
$fn$;

-- ─── Contabilidad ───────────────────────────────────────────────────────────

create or replace function public.atelier_storage_account()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_scope text;
  v_owner uuid;
  v_delta bigint := 0;
  v_objects integer := 0;
begin
  if tg_op = 'DELETE' then
    select s.scope, s.owner_id into v_scope, v_owner
    from public.atelier_storage_owner(old.name) s;
    v_delta := -coalesce((old.metadata->>'size')::bigint, 0);
    v_objects := -1;
  elsif tg_op = 'UPDATE' then
    select s.scope, s.owner_id into v_scope, v_owner
    from public.atelier_storage_owner(new.name) s;
    -- Una subida reanudable escribe la fila primero y el tamaño después.
    v_delta := coalesce((new.metadata->>'size')::bigint, 0)
             - coalesce((old.metadata->>'size')::bigint, 0);
    v_objects := 0;
  else
    select s.scope, s.owner_id into v_scope, v_owner
    from public.atelier_storage_owner(new.name) s;
    v_delta := coalesce((new.metadata->>'size')::bigint, 0);
    v_objects := 1;
  end if;

  if v_scope is null then
    return coalesce(new, old);
  end if;

  insert into public.atelier_storage_usage (scope, owner_id, bytes_used, objects_count)
  values (v_scope, v_owner, greatest(v_delta, 0), greatest(v_objects, 0))
  on conflict (scope, owner_id) do update set
    bytes_used = greatest(public.atelier_storage_usage.bytes_used + v_delta, 0),
    objects_count = greatest(public.atelier_storage_usage.objects_count + v_objects, 0),
    updated_at = now();

  return coalesce(new, old);
end;
$fn$;

-- La puerta. Se cierra solo para lo que entra, nunca para lo que ya está.
create or replace function public.atelier_storage_enforce_quota()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_scope text;
  v_owner uuid;
  v_limit bigint;
  v_used bigint;
  v_incoming bigint := coalesce((new.metadata->>'size')::bigint, 0);
begin
  select s.scope, s.owner_id into v_scope, v_owner
  from public.atelier_storage_owner(new.name) s;

  -- Una ruta que no sigue la convención no pertenece a ninguna bolsa: la
  -- rechazamos en vez de dejar archivos sin dueño acumulándose sin control.
  if v_scope is null then
    raise exception 'Ruta de Atelier inválida: usa u/{perfil}/... o w/{workspace}/...'
      using errcode = '22023';
  end if;

  v_limit := public.atelier_storage_limit(v_scope, v_owner);
  if v_limit = -1 then return new; end if;

  select coalesce(u.bytes_used, 0) into v_used
  from public.atelier_storage_usage u
  where u.scope = v_scope and u.owner_id = v_owner;

  if coalesce(v_used, 0) + v_incoming > v_limit then
    raise exception 'ATELIER_STORAGE_QUOTA_EXCEEDED'
      using errcode = '53100',
            detail = format('usados=%s entrante=%s limite=%s',
                            coalesce(v_used, 0), v_incoming, v_limit),
            hint = 'Libera espacio, compra almacenamiento adicional o sube de plan. Ningún archivo se elimina por estar sobre cuota.';
  end if;

  return new;
end;
$fn$;

drop trigger if exists atelier_storage_quota on storage.objects;
create trigger atelier_storage_quota
  before insert on storage.objects
  for each row
  when (new.bucket_id = 'atelier')
  execute function public.atelier_storage_enforce_quota();

drop trigger if exists atelier_storage_account_ins on storage.objects;
create trigger atelier_storage_account_ins
  after insert or update on storage.objects
  for each row
  when (new.bucket_id = 'atelier')
  execute function public.atelier_storage_account();

drop trigger if exists atelier_storage_account_del on storage.objects;
create trigger atelier_storage_account_del
  after delete on storage.objects
  for each row
  when (old.bucket_id = 'atelier')
  execute function public.atelier_storage_account();

-- ─── Acceso al bucket ───────────────────────────────────────────────────────

drop policy if exists "atelier_bucket_read" on storage.objects;
create policy "atelier_bucket_read" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'atelier'
    and (
      ((storage.foldername(name))[1] = 'u'
        and (storage.foldername(name))[2] = (select auth.uid())::text)
      or ((storage.foldername(name))[1] = 'w'
        and public.atelier_is_workspace_member(
              nullif((storage.foldername(name))[2], '')::uuid))
    )
  );

drop policy if exists "atelier_bucket_write" on storage.objects;
create policy "atelier_bucket_write" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'atelier'
    and (
      ((storage.foldername(name))[1] = 'u'
        and (storage.foldername(name))[2] = (select auth.uid())::text)
      or ((storage.foldername(name))[1] = 'w'
        and public.atelier_has_capability(
              nullif((storage.foldername(name))[2], '')::uuid, 'project.write'))
    )
  );

drop policy if exists "atelier_bucket_update" on storage.objects;
create policy "atelier_bucket_update" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'atelier'
    and (
      ((storage.foldername(name))[1] = 'u'
        and (storage.foldername(name))[2] = (select auth.uid())::text)
      or ((storage.foldername(name))[1] = 'w'
        and public.atelier_has_capability(
              nullif((storage.foldername(name))[2], '')::uuid, 'project.write'))
    )
  );

-- Borrar SIEMPRE se puede: es la vía de salida de quien se pasó de cuota.
drop policy if exists "atelier_bucket_delete" on storage.objects;
create policy "atelier_bucket_delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'atelier'
    and (
      ((storage.foldername(name))[1] = 'u'
        and (storage.foldername(name))[2] = (select auth.uid())::text)
      or ((storage.foldername(name))[1] = 'w'
        and public.atelier_has_capability(
              nullif((storage.foldername(name))[2], '')::uuid, 'project.write'))
    )
  );

-- ─── Lectura de uso ─────────────────────────────────────────────────────────

create or replace function public.get_atelier_usage(p_workspace_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_scope text := case when p_workspace_id is null then 'user' else 'workspace' end;
  v_owner uuid := coalesce(p_workspace_id, v_uid);
  v_used bigint := 0;
  v_objects integer := 0;
  v_limit bigint;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHENTICATED');
  end if;

  if p_workspace_id is not null
     and not public.atelier_is_workspace_member(p_workspace_id, v_uid) then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHORIZED');
  end if;

  select coalesce(u.bytes_used, 0), coalesce(u.objects_count, 0)
    into v_used, v_objects
  from public.atelier_storage_usage u
  where u.scope = v_scope and u.owner_id = v_owner;

  v_limit := public.atelier_storage_limit(v_scope, v_owner);

  return jsonb_build_object(
    'ok', true,
    'scope', v_scope,
    'owner_id', v_owner,
    'storage', jsonb_build_object(
      'bytes_used', coalesce(v_used, 0),
      'objects_count', coalesce(v_objects, 0),
      'bytes_limit', v_limit
    ),
    'metrics', coalesce((
      select jsonb_object_agg(m.metric || ':' || m.period, m.value)
      from public.atelier_usage m
      where m.scope = v_scope and m.owner_id = v_owner
    ), '{}'::jsonb)
  );
end;
$fn$;

-- ─── RLS ────────────────────────────────────────────────────────────────────

alter table public.atelier_storage_usage enable row level security;
alter table public.atelier_usage enable row level security;

drop policy if exists "atelier_storage_usage_select_own" on public.atelier_storage_usage;
create policy "atelier_storage_usage_select_own" on public.atelier_storage_usage
  for select to authenticated
  using (
    (scope = 'user' and owner_id = (select auth.uid()))
    or (scope = 'workspace' and public.atelier_is_workspace_member(owner_id))
  );

drop policy if exists "atelier_usage_select_own" on public.atelier_usage;
create policy "atelier_usage_select_own" on public.atelier_usage
  for select to authenticated
  using (
    (scope = 'user' and owner_id = (select auth.uid()))
    or (scope = 'workspace' and public.atelier_is_workspace_member(owner_id))
  );

grant select on public.atelier_storage_usage to authenticated;
grant select on public.atelier_usage to authenticated;

revoke all on function public.atelier_storage_limit(text, uuid) from public;
revoke all on function public.get_atelier_usage(uuid) from public;
grant execute on function public.get_atelier_usage(uuid) to authenticated;
