-- Import only into a new, private, caller-owned project. RLS remains active.
-- No original identifiers, publication links, memberships or automations are reused.
create or replace function public.atelier_remap_import_json(p_value jsonb, p_ids jsonb, p_depth integer default 0)
returns jsonb language plpgsql immutable security invoker set search_path = '' as $$
declare v_result jsonb; v_key text; v_item jsonb; v_text text; v_old text; v_new text;
begin
  if p_depth < 0 or p_depth > 80 then raise exception 'Import nesting limit exceeded' using errcode = '22023'; end if;
  case jsonb_typeof(p_value)
    when 'object' then
      v_result := '{}'::jsonb;
      for v_key, v_item in select key, value from jsonb_each(p_value) loop
        v_result := v_result || jsonb_build_object(coalesce(p_ids->>v_key, v_key), public.atelier_remap_import_json(v_item, p_ids, p_depth + 1));
      end loop;
    when 'array' then
      select coalesce(jsonb_agg(public.atelier_remap_import_json(value, p_ids, p_depth + 1)), '[]'::jsonb) into v_result from jsonb_array_elements(p_value);
    when 'string' then
      v_text := p_value #>> '{}';
      if p_ids ? v_text then return to_jsonb(p_ids->>v_text); end if;
      if position('corvus-node:' in v_text) > 0 then
        for v_old, v_new in select key, value from jsonb_each_text(p_ids) loop
          v_text := replace(v_text, 'corvus-node:' || v_old, 'corvus-node:' || v_new);
        end loop;
      end if;
      v_result := to_jsonb(v_text);
    else v_result := p_value;
  end case;
  return v_result;
end $$;

create or replace function public.atelier_import_project(p_payload jsonb, p_request_id uuid)
returns uuid language plpgsql security invoker set search_path = '' as $$
declare
  v_owner uuid := auth.uid();
  v_project jsonb; v_nodes jsonb; v_relations jsonb; v_versions jsonb;
  v_ids jsonb := '{}'::jsonb; v_item jsonb; v_snap jsonb; v_meta jsonb; v_id text; v_snapshot_project jsonb;
  v_existing public.atelier_projects; v_fingerprint text;
begin
  if v_owner is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if p_request_id is null or jsonb_typeof(p_payload) is distinct from 'object'
     or octet_length(p_payload::text) > 10485760 then
    raise exception 'Invalid import payload' using errcode = '22023';
  end if;
  v_project := p_payload->'project'; v_nodes := p_payload->'nodes';
  v_relations := p_payload->'relations'; v_versions := p_payload->'versions';
  if jsonb_typeof(v_project) is distinct from 'object'
     or jsonb_typeof(v_project->'title') is distinct from 'string'
     or length(btrim(v_project->>'title')) = 0
     or jsonb_typeof(v_nodes) is distinct from 'array'
     or jsonb_typeof(v_relations) is distinct from 'array'
     or jsonb_typeof(v_versions) is distinct from 'array' then
    raise exception 'Missing project sections' using errcode = '22023';
  end if;
  if jsonb_array_length(v_nodes) > 2000 or jsonb_array_length(v_relations) > 10000 or jsonb_array_length(v_versions) > 1000 then
    raise exception 'Import item limit exceeded' using errcode = '22023';
  end if;
  v_fingerprint := md5(p_payload::text);
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  select * into v_existing from public.atelier_projects where id = p_request_id;
  if found then
    if v_existing.profile_id = v_owner and v_existing.metadata->>'import_fingerprint' = v_fingerprint then return p_request_id; end if;
    raise exception 'Import request already used' using errcode = '22023';
  end if;

  -- Validate current identifiers and endpoints before making any writes.
  for v_item in select value from jsonb_array_elements(v_nodes) loop
    v_id := v_item->>'id';
    if jsonb_typeof(v_item) <> 'object' or v_id is null or v_id !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' or v_ids ? v_id
       or jsonb_typeof(v_item->'title') is distinct from 'string'
       or jsonb_typeof(v_item->'body') is distinct from 'string'
       or jsonb_typeof(v_item->'kind') is distinct from 'string' then
      raise exception 'Invalid or duplicate node' using errcode = '22023';
    end if;
    v_ids := v_ids || jsonb_build_object(v_id, gen_random_uuid()::text);
  end loop;
  for v_item in select value from jsonb_array_elements(v_relations) loop
    if not (v_ids ? (v_item->>'source_node_id')) or not (v_ids ? (v_item->>'target_node_id'))
       or (v_item->>'source_node_id') is null or (v_item->>'target_node_id') is null
       or v_item->>'source_node_id' = v_item->>'target_node_id'
       or jsonb_typeof(v_item->'relation_type') is distinct from 'string' then
      raise exception 'Invalid relation endpoint' using errcode = '22023';
    end if;
  end loop;
  -- Also map historical nodes that were deleted after a snapshot was taken.
  for v_item in select value from jsonb_array_elements(v_versions) loop
    if jsonb_typeof(v_item) is distinct from 'object' or jsonb_typeof(v_item->'label') is distinct from 'string' then
      raise exception 'Invalid version' using errcode = '22023';
    end if;
    v_snap := coalesce(v_item->'snapshot'->'nodes', v_item->'metadata'->'snapshot_nodes', '[]'::jsonb);
    if jsonb_typeof(v_snap) is distinct from 'array' then raise exception 'Invalid snapshot' using errcode = '22023'; end if;
    for v_id in select value->>'id' from jsonb_array_elements(v_snap) loop
      if v_id is null or v_id !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then raise exception 'Invalid historical node' using errcode = '22023'; end if;
      if not (v_ids ? v_id) then v_ids := v_ids || jsonb_build_object(v_id, gen_random_uuid()::text); end if;
    end loop;
  end loop;
  -- Relations and version identifiers may also be referenced in metadata.
  for v_id in
    select value->>'id' from jsonb_array_elements(v_relations)
    union select value->>'id' from jsonb_array_elements(v_versions)
    union select r.value->>'id' from jsonb_array_elements(v_versions) v,
      lateral jsonb_array_elements(coalesce(v.value->'snapshot'->'relations', v.value->'metadata'->'snapshot_relations', '[]'::jsonb)) r
  loop
    if v_id is not null then
      if v_ids ? v_id then raise exception 'Ambiguous import identifier' using errcode = '22023'; end if;
      v_ids := v_ids || jsonb_build_object(v_id, gen_random_uuid()::text);
    end if;
  end loop;
  if coalesce(v_project->>'id', '') <> '' then
    if v_ids ? (v_project->>'id') then raise exception 'Ambiguous project identifier' using errcode = '22023'; end if;
    v_ids := v_ids || jsonb_build_object(v_project->>'id', p_request_id::text);
  end if;
  v_project := public.atelier_remap_import_json(v_project, v_ids);
  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) into v_meta
    from jsonb_each(coalesce(v_project->'metadata', '{}'::jsonb))
    where key not like 'publication\_%' escape '\' and key not in ('deleted_at', 'workspace_id', 'import_fingerprint');
  v_meta := v_meta || jsonb_build_object('import_fingerprint', v_fingerprint, 'imported_at', now());
  insert into public.atelier_projects(id, profile_id, title, type, status, genre, universe, language, visibility, weekly_word_goal, public_progress_enabled, metadata)
    values(p_request_id, v_owner, v_project->>'title', coalesce(v_project->>'type', 'Obra'), coalesce(v_project->>'status', 'idea'),
      coalesce(v_project->>'genre', ''), coalesce(v_project->>'universe', ''), coalesce(v_project->>'language', 'es'), 'private',
      greatest(0, coalesce((v_project->>'weekly_word_goal')::integer, 0)), false, v_meta);
  for v_item in select value from jsonb_array_elements(public.atelier_remap_import_json(v_nodes, v_ids)) loop
    insert into public.atelier_nodes(id, project_id, profile_id, kind, title, body, status, canon_status, visibility, tags, metadata, position)
      values((v_item->>'id')::uuid, p_request_id, v_owner, v_item->>'kind', v_item->>'title', v_item->>'body',
        coalesce(v_item->>'status', 'draft'), coalesce(v_item->>'canon_status', 'canon'), 'private',
        array(select jsonb_array_elements_text(coalesce(v_item->'tags', '[]'::jsonb))),
        coalesce(v_item->'metadata', '{}'::jsonb), coalesce((v_item->>'position')::integer, 0));
  end loop;
  for v_item in select value from jsonb_array_elements(public.atelier_remap_import_json(v_relations, v_ids)) loop
    insert into public.atelier_relations(id, project_id, profile_id, source_node_id, target_node_id, relation_type, description, canon_status)
      values(coalesce((v_item->>'id')::uuid, gen_random_uuid()), p_request_id, v_owner, (v_item->>'source_node_id')::uuid, (v_item->>'target_node_id')::uuid,
        v_item->>'relation_type', coalesce(v_item->>'description', ''), coalesce(v_item->>'canon_status', 'canon'));
  end loop;
  for v_item in select value from jsonb_array_elements(public.atelier_remap_import_json(v_versions, v_ids)) loop
    v_meta := coalesce(v_item->'metadata', '{}'::jsonb);
    v_snap := coalesce(v_item->'snapshot', jsonb_build_object('nodes', coalesce(v_meta->'snapshot_nodes', '[]'::jsonb),
      'relations', coalesce(v_meta->'snapshot_relations', '[]'::jsonb), 'project', coalesce(v_meta->'snapshot_project', v_project)));
    -- Snapshot identity/visibility must not reinstate foreign owners or publication links.
    select coalesce(jsonb_agg(value || jsonb_build_object('profile_id', v_owner, 'project_id', p_request_id, 'visibility', 'private')), '[]'::jsonb)
      into v_nodes from jsonb_array_elements(v_snap->'nodes');
    v_snapshot_project := coalesce(v_snap->'project', v_project);
    select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) into v_meta
      from jsonb_each(coalesce(v_snapshot_project->'metadata', '{}'::jsonb))
      where key not like 'publication\_%' escape '\' and key not in ('workspace_id', 'import_fingerprint');
    v_snapshot_project := (v_snapshot_project - 'workspace_id') || jsonb_build_object('id', p_request_id, 'profile_id', v_owner,
      'visibility', 'private', 'public_progress_enabled', false, 'metadata', v_meta);
    v_snap := v_snap || jsonb_build_object('nodes', v_nodes, 'project', v_snapshot_project);
    select coalesce(jsonb_agg(value || jsonb_build_object('profile_id', v_owner, 'project_id', p_request_id)), '[]'::jsonb)
      into v_relations from jsonb_array_elements(coalesce(v_snap->'relations', '[]'::jsonb));
    v_snap := v_snap || jsonb_build_object('relations', v_relations);
    v_meta := coalesce(v_item->'metadata', '{}'::jsonb);
    v_meta := (v_meta - 'snapshot_nodes' - 'snapshot_relations' - 'snapshot_project') ||
      jsonb_build_object('imported_at', now(), 'imported_created_at', v_item->>'created_at', 'imported_author_name', v_item->>'author_name');
    insert into public.atelier_versions(id, project_id, profile_id, label, description, metadata, snapshot, kind, node_count, size_bytes, created_at)
      values(coalesce((v_item->>'id')::uuid, gen_random_uuid()), p_request_id, v_owner, v_item->>'label', coalesce(v_item->>'description', ''), v_meta, v_snap, 'import',
        jsonb_array_length(v_nodes), octet_length(v_snap::text), coalesce((v_item->>'created_at')::timestamptz, now()));
  end loop;
  return p_request_id;
end $$;

revoke all on function public.atelier_remap_import_json(jsonb, jsonb, integer) from public, anon;
revoke all on function public.atelier_import_project(jsonb, uuid) from public, anon;
grant execute on function public.atelier_remap_import_json(jsonb, jsonb, integer) to authenticated;
grant execute on function public.atelier_import_project(jsonb, uuid) to authenticated;
