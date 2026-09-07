-- Corvus Atelier — que el panel de uso diga la verdad.
--
-- `get_atelier_usage` devolvía el almacenamiento con precisión y dejaba el
-- resto de contadores a cero, así que el centro de facturación enseñaba
-- «0 / 10 colaboradores» a quien tenía tres. Un número inventado en una
-- pantalla de consumo es peor que no enseñar el número.
--
-- Los recuentos se calculan al vuelo y no con triggers: son consultas
-- pequeñas sobre índices que ya existen, y esta función se llama al abrir una
-- pantalla, no en el camino de cada guardado.

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
  v_counts jsonb;
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

  -- El alcance decide qué proyectos cuentan: los personales de quien pregunta,
  -- o los del espacio de trabajo.
  with alcance as (
    select p.id
    from public.atelier_projects p
    where (p_workspace_id is null
             and p.profile_id = v_uid
             and p.workspace_id is null)
       or (p_workspace_id is not null and p.workspace_id = p_workspace_id)
  )
  select jsonb_build_object(
    'projects', (select count(*) from alcance),
    -- El tope de colaboradores es POR PROYECTO, así que lo que hay que
    -- comparar con el límite es el proyecto más poblado, no la suma.
    'collaborators', coalesce((
      select max(c.total) from (
        select count(*) as total
        from public.atelier_project_collaborators col
        join alcance a on a.id = col.project_id
        where col.status = 'active'
        group by col.project_id
      ) c
    ), 0),
    'automations', coalesce((
      select count(*)
      from public.atelier_automations au
      join alcance a on a.id = au.project_id
      where au.is_enabled
    ), 0),
    'versions', coalesce((
      select count(*)
      from public.atelier_versions v
      join alcance a on a.id = v.project_id
    ), 0),
    'members', case
      when p_workspace_id is null then 0
      else coalesce((
        select count(*) from public.atelier_workspace_members m
        where m.workspace_id = p_workspace_id and m.status = 'active'
      ), 0)
    end
  ) into v_counts;

  return jsonb_build_object(
    'ok', true,
    'scope', v_scope,
    'owner_id', v_owner,
    'storage', jsonb_build_object(
      'bytes_used', coalesce(v_used, 0),
      'objects_count', coalesce(v_objects, 0),
      'bytes_limit', v_limit
    ),
    'counts', v_counts,
    'metrics', coalesce((
      select jsonb_object_agg(m.metric || ':' || m.period, m.value)
      from public.atelier_usage m
      where m.scope = v_scope and m.owner_id = v_owner
    ), '{}'::jsonb)
  );
end;
$fn$;

revoke all on function public.get_atelier_usage(uuid) from public, anon, authenticated;
grant execute on function public.get_atelier_usage(uuid) to authenticated;
