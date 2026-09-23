-- The owner explicitly sends one reviewed edition. Work, comparison and history
-- commit together; none can succeed alone. Existing public status is preserved.
create or replace function public.atelier_commit_publication(
  p_project_id uuid, p_project_updated_at timestamptz, p_expected_nodes jsonb,
  p_publication_snapshot jsonb, p_payload jsonb, p_preparing boolean default false
)
returns jsonb language plpgsql security invoker set search_path = '' as $$
declare
  v_uid uuid := auth.uid(); v_project public.atelier_projects; v_work public.works;
  v_current jsonb; v_expected jsonb; v_snapshot jsonb; v_fingerprint text;
  v_work_id uuid; v_item jsonb; v_node public.atelier_nodes; v_is_public boolean;
begin
  if v_uid is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if jsonb_typeof(p_expected_nodes) is distinct from 'array' or jsonb_typeof(p_publication_snapshot) is distinct from 'array'
     or jsonb_typeof(p_payload) is distinct from 'object' or octet_length(p_payload::text) > 10485760
     or jsonb_typeof(p_payload->'text_body') is distinct from 'string'
     or jsonb_typeof(p_payload->'aeternum_ficha') is distinct from 'object' then
    raise exception 'Invalid edition' using errcode = '22023';
  end if;
  select * into v_project from public.atelier_projects where id = p_project_id and profile_id = v_uid for update;
  if not found then raise exception 'Only the owner can send an edition' using errcode = '42501'; end if;
  if v_project.metadata->>'deleted_at' is not null then raise exception 'Project is in trash' using errcode = '22023'; end if;
  v_fingerprint := md5(jsonb_build_array(p_project_updated_at, p_expected_nodes, p_publication_snapshot, p_payload, p_preparing)::text);
  v_work_id := nullif(v_project.metadata->>'publication_work_id', '')::uuid;
  if v_work_id is not null then
    select * into v_work from public.works where id = v_work_id and profile_id = v_uid for update;
    if not found then raise exception 'Linked work is unavailable' using errcode = '42501'; end if;
    if v_project.metadata->>'publication_request_fingerprint' = v_fingerprint or (p_preparing and v_work.status = 'published') then
      return jsonb_build_object('work_id', v_work.id, 'chapters', jsonb_array_length(p_publication_snapshot), 'is_published', v_work.status = 'published');
    end if;
  elsif not p_preparing then
    raise exception 'Prepare the work first' using errcode = '22023';
  end if;
  if v_project.updated_at is distinct from p_project_updated_at then raise exception 'EDITION_CHANGED' using errcode = 'P0001'; end if;
  -- The parent lock prevents new FK references; row locks freeze existing content
  -- while its revision is checked and the exact accepted snapshot is captured.
  perform id from public.atelier_nodes where project_id = p_project_id order by id for share;
  perform id from public.atelier_relations where project_id = p_project_id order by id for share;
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'updated_at', updated_at) order by id), '[]'::jsonb)
    into v_current from public.atelier_nodes where project_id = p_project_id and metadata->>'deleted_at' is null;
  select coalesce(jsonb_agg(jsonb_build_object('id', (value->>'id')::uuid, 'updated_at', (value->>'updated_at')::timestamptz) order by (value->>'id')::uuid), '[]'::jsonb)
    into v_expected from jsonb_array_elements(p_expected_nodes);
  if v_current is distinct from v_expected then raise exception 'EDITION_CHANGED' using errcode = 'P0001'; end if;
  if jsonb_array_length(p_publication_snapshot) = 0 or (select count(distinct value->>'id') from jsonb_array_elements(p_publication_snapshot)) <> jsonb_array_length(p_publication_snapshot) then
    raise exception 'Empty or duplicate chapters' using errcode = '22023';
  end if;
  for v_item in select value from jsonb_array_elements(p_publication_snapshot) loop
    select * into v_node from public.atelier_nodes where id = (v_item->>'id')::uuid and project_id = p_project_id and metadata->>'deleted_at' is null;
    if not found or v_node.title is distinct from v_item->>'title' or v_node.body is distinct from v_item->>'body'
      or btrim(v_node.title) = '' or btrim(v_node.body) = '' then raise exception 'EDITION_CHANGED' using errcode = 'P0001'; end if;
  end loop;
  for v_item in select value from jsonb_array_elements(coalesce(p_payload->'aeternum_ficha'->'public_references', '[]'::jsonb)) loop
    if not exists(select 1 from public.atelier_nodes where id = (v_item->>'id')::uuid and project_id = p_project_id
      and visibility = 'public' and metadata->>'deleted_at' is null and title = v_item->>'title' and body = v_item->>'body') then
      raise exception 'Private reference in edition' using errcode = '22023';
    end if;
  end loop;
  if v_work_id is null then
    insert into public.works(profile_id, title, description, discipline, subdiscipline, medium, work_type, status, is_public,
      is_complete, is_for_sale, is_mature, year, tags, text_body, language, aeternum_ficha, atelier_project_id, universe, aeternum_status)
    values(v_uid, v_project.title, coalesce(p_payload->>'description', ''), coalesce(p_payload->>'discipline', ''), v_project.type,
      v_project.genre, coalesce(p_payload->>'work_type', 'text'), 'draft', false, false, false, false,
      extract(year from now())::smallint, array(select jsonb_array_elements_text(coalesce(p_payload->'tags', '[]'::jsonb))),
      p_payload->>'text_body', v_project.language, p_payload->'aeternum_ficha', p_project_id, v_project.universe, v_project.status)
      returning * into v_work;
    v_work_id := v_work.id;
  elsif p_preparing then
    update public.works set title = v_project.title, description = coalesce(p_payload->>'description', ''),
      discipline = coalesce(p_payload->>'discipline', ''), subdiscipline = v_project.type, medium = v_project.genre,
      work_type = coalesce(p_payload->>'work_type', 'text'), language = v_project.language,
      tags = array(select jsonb_array_elements_text(coalesce(p_payload->'tags', '[]'::jsonb))),
      text_body = p_payload->>'text_body', aeternum_ficha = p_payload->'aeternum_ficha', atelier_project_id = p_project_id,
      universe = v_project.universe, aeternum_status = v_project.status, updated_at = now()
      where id = v_work_id and profile_id = v_uid returning * into v_work;
  else
    update public.works set text_body = p_payload->>'text_body', aeternum_ficha = p_payload->'aeternum_ficha',
      atelier_project_id = p_project_id, universe = v_project.universe, aeternum_status = v_project.status, updated_at = now()
      where id = v_work_id and profile_id = v_uid returning * into v_work;
  end if;
  if v_work.id is null then raise exception 'Edition not saved' using errcode = '42501'; end if;
  v_is_public := v_work.status = 'published';
  update public.atelier_projects set metadata = metadata || jsonb_build_object(
    'publication_work_id', v_work_id, 'publication_is_public', v_is_public,
    'publication_updated_at', now(), 'publication_snapshot', p_publication_snapshot,
    'publication_request_fingerprint', v_fingerprint), updated_at = now() where id = p_project_id;
  select jsonb_build_object('project', to_jsonb(p),
    'nodes', coalesce((select jsonb_agg(to_jsonb(n) order by position, id) from public.atelier_nodes n where project_id = p_project_id), '[]'::jsonb),
    'relations', coalesce((select jsonb_agg(to_jsonb(r) order by id) from public.atelier_relations r where project_id = p_project_id), '[]'::jsonb))
    into v_snapshot from public.atelier_projects p where id = p_project_id;
  insert into public.atelier_versions(project_id, profile_id, label, description, metadata, snapshot, kind, node_count, size_bytes)
    values(p_project_id, v_uid, case when v_is_public then 'Edición publicada' else 'Borrador de publicación' end,
      'Contenido enviado a la obra vinculada.', jsonb_build_object('publication_work_id', v_work_id), v_snapshot, 'auto',
      jsonb_array_length(v_snapshot->'nodes'), octet_length(v_snapshot::text));
  return jsonb_build_object('work_id', v_work_id, 'chapters', jsonb_array_length(p_publication_snapshot), 'is_published', v_is_public);
end $$;
revoke all on function public.atelier_commit_publication(uuid, timestamptz, jsonb, jsonb, jsonb, boolean) from public, anon;
grant execute on function public.atelier_commit_publication(uuid, timestamptz, jsonb, jsonb, jsonb, boolean) to authenticated;
