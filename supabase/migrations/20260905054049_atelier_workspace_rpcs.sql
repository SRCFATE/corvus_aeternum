-- Corvus Atelier — los actos que cambian quién puede qué.
--
-- Crear un espacio, invitar, cambiar un rol, compartir un proyecto: todo pasa
-- por aquí y no por un INSERT del cliente. La razón no es ceremonia, es que
-- cada uno de estos actos tiene que comprobar un derecho, respetar un tope y
-- dejar rastro en la auditoría, y las tres cosas juntas no caben en una
-- política RLS.
--
-- Todas devuelven `{ok, reason_code}` como el resto de RPC de Corvus, para que
-- `unwrapRpc()` en Dart las trate igual que a las de identidad o subastas.

create or replace function public.atelier_log(
  p_workspace_id uuid,
  p_project_id uuid,
  p_action text,
  p_object_type text,
  p_object_id text,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language sql
security definer
set search_path = ''
as $fn$
  insert into public.atelier_audit_log (
    workspace_id, project_id, actor_id, action, object_type, object_id, metadata
  ) values (
    p_workspace_id, p_project_id, auth.uid(),
    p_action, p_object_type, p_object_id, coalesce(p_metadata, '{}'::jsonb)
  );
$fn$;

-- ─── Workspaces ─────────────────────────────────────────────────────────────

create or replace function public.atelier_create_workspace(
  p_name text,
  p_slug text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_slug text;
  v_limit bigint;
  v_owned integer;
  v_id uuid;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHENTICATED');
  end if;

  if not public.has_entitlement(v_uid, 'atelier.workspace', null) then
    return jsonb_build_object('ok', false, 'reason_code', 'ATELIER_WORKSPACE_NOT_INCLUDED');
  end if;

  v_limit := public.entitlement_limit(v_uid, 'atelier.workspaces.max', null);
  select count(*) into v_owned
  from public.atelier_workspaces w
  where w.owner_id = v_uid and w.status <> 'archived';

  if v_limit <> -1 and v_owned >= v_limit then
    return jsonb_build_object(
      'ok', false, 'reason_code', 'ATELIER_WORKSPACE_LIMIT_REACHED',
      'limit', v_limit, 'owned', v_owned
    );
  end if;

  v_slug := lower(regexp_replace(
    coalesce(nullif(trim(p_slug), ''), trim(p_name)),
    '[^a-zA-Z0-9._-]+', '-', 'g'
  ));
  v_slug := trim(both '-' from v_slug);

  if length(v_slug) < 3 then
    return jsonb_build_object('ok', false, 'reason_code', 'ATELIER_WORKSPACE_SLUG_INVALID');
  end if;

  v_slug := left(v_slug, 34);

  if exists (select 1 from public.atelier_workspaces where slug = v_slug) then
    v_slug := left(v_slug, 26) || '-' || substr(md5(gen_random_uuid()::text), 1, 6);
  end if;

  insert into public.atelier_workspaces (slug, name, owner_id, billing_owner_id)
  values (v_slug, trim(p_name), v_uid, v_uid)
  returning id into v_id;

  insert into public.atelier_workspace_members (workspace_id, profile_id, role_key)
  values (v_id, v_uid, 'owner');

  perform public.atelier_log(
    v_id, null, 'workspace.create', 'atelier_workspace', v_id::text,
    jsonb_build_object('slug', v_slug)
  );

  return jsonb_build_object('ok', true, 'workspace_id', v_id, 'slug', v_slug);
end;
$fn$;

-- ─── Invitaciones ───────────────────────────────────────────────────────────

create or replace function public.atelier_invite_to_workspace(
  p_workspace_id uuid,
  p_profile_id uuid default null,
  p_email text default null,
  p_role_key text default 'writer',
  p_message text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_seats bigint;
  v_members integer;
  v_id uuid;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHENTICATED');
  end if;

  if not public.atelier_has_capability(p_workspace_id, 'member.invite', v_uid) then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHORIZED');
  end if;

  if p_profile_id is null and nullif(trim(coalesce(p_email, '')), '') is null then
    return jsonb_build_object('ok', false, 'reason_code', 'ATELIER_INVITE_NO_RECIPIENT');
  end if;

  if not exists (
    select 1 from public.atelier_workspace_roles r
    where r.key = p_role_key
      and (r.workspace_id is null or r.workspace_id = p_workspace_id)
  ) then
    return jsonb_build_object('ok', false, 'reason_code', 'ATELIER_ROLE_UNKNOWN');
  end if;

  select w.owner_id into v_owner
  from public.atelier_workspaces w where w.id = p_workspace_id;

  v_seats := public.entitlement_limit(
    v_owner, 'atelier.workspace.seats.max', p_workspace_id
  );

  select count(*) into v_members
  from public.atelier_workspace_members m
  where m.workspace_id = p_workspace_id and m.status = 'active';

  -- Las invitaciones pendientes cuentan: si no, se podrían emitir cien y
  -- rebasar el plan en el momento en que las acepten.
  if v_seats <> -1 then
    select v_members + count(*) into v_members
    from public.atelier_invitations i
    where i.workspace_id = p_workspace_id
      and i.status = 'pending' and i.expires_at > now();

    if v_members >= v_seats then
      return jsonb_build_object(
        'ok', false, 'reason_code', 'ATELIER_SEAT_LIMIT_REACHED',
        'limit', v_seats, 'used', v_members
      );
    end if;
  end if;

  if p_profile_id is not null and exists (
    select 1 from public.atelier_workspace_members m
    where m.workspace_id = p_workspace_id
      and m.profile_id = p_profile_id and m.status = 'active'
  ) then
    return jsonb_build_object('ok', false, 'reason_code', 'ATELIER_ALREADY_MEMBER');
  end if;

  insert into public.atelier_invitations (
    workspace_id, invitee_id, email, role_key, invited_by, message
  ) values (
    p_workspace_id, p_profile_id, lower(nullif(trim(coalesce(p_email, '')), '')),
    p_role_key, v_uid, coalesce(p_message, '')
  )
  returning id into v_id;

  perform public.atelier_log(
    p_workspace_id, null, 'member.invite', 'atelier_invitation', v_id::text,
    jsonb_build_object('role_key', p_role_key)
  );

  return jsonb_build_object('ok', true, 'invitation_id', v_id);
end;
$fn$;

create or replace function public.atelier_respond_invitation(
  p_invitation_id uuid,
  p_accept boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  i record;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHENTICATED');
  end if;

  select * into i from public.atelier_invitations where id = p_invitation_id;
  if not found then
    return jsonb_build_object('ok', false, 'reason_code', 'ATELIER_INVITE_NOT_FOUND');
  end if;

  if i.status <> 'pending' then
    return jsonb_build_object('ok', false, 'reason_code', 'ATELIER_INVITE_ALREADY_ANSWERED');
  end if;

  if i.expires_at <= now() then
    update public.atelier_invitations
      set status = 'expired', responded_at = now() where id = p_invitation_id;
    return jsonb_build_object('ok', false, 'reason_code', 'ATELIER_INVITE_EXPIRED');
  end if;

  -- Una invitación por correo la reclama quien inicia sesión con ese correo.
  if i.invitee_id is distinct from v_uid then
    if i.email is null or lower(i.email) <> lower((
      select u.email from auth.users u where u.id = v_uid
    )) then
      return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHORIZED');
    end if;
  end if;

  update public.atelier_invitations
    set status = case when p_accept then 'accepted' else 'declined' end,
        invitee_id = v_uid,
        responded_at = now()
    where id = p_invitation_id;

  if not p_accept then
    return jsonb_build_object('ok', true, 'accepted', false);
  end if;

  if i.workspace_id is not null then
    insert into public.atelier_workspace_members (
      workspace_id, profile_id, role_key, invited_by
    ) values (i.workspace_id, v_uid, i.role_key, i.invited_by)
    on conflict (workspace_id, profile_id) do update set
      role_key = excluded.role_key, status = 'active', updated_at = now();
  end if;

  if i.project_id is not null then
    insert into public.atelier_project_collaborators (
      project_id, profile_id, role_key, invited_by, status
    ) values (i.project_id, v_uid, i.role_key, i.invited_by, 'active')
    on conflict (project_id, profile_id) do update set
      role_key = excluded.role_key, status = 'active', updated_at = now();
  end if;

  perform public.atelier_log(
    i.workspace_id, i.project_id, 'invitation.accept', 'atelier_invitation',
    p_invitation_id::text, jsonb_build_object('role_key', i.role_key)
  );

  return jsonb_build_object('ok', true, 'accepted', true);
end;
$fn$;

-- ─── Miembros ───────────────────────────────────────────────────────────────

create or replace function public.atelier_set_member_role(
  p_workspace_id uuid,
  p_profile_id uuid,
  p_role_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_before text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHENTICATED');
  end if;

  if not public.atelier_has_capability(p_workspace_id, 'member.manage', v_uid) then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHORIZED');
  end if;

  select w.owner_id into v_owner
  from public.atelier_workspaces w where w.id = p_workspace_id;

  -- El espacio no puede quedarse sin dueño por un cambio de rol.
  if p_profile_id = v_owner and p_role_key <> 'owner' then
    return jsonb_build_object('ok', false, 'reason_code', 'ATELIER_CANNOT_DEMOTE_OWNER');
  end if;

  if not exists (
    select 1 from public.atelier_workspace_roles r
    where r.key = p_role_key
      and (r.workspace_id is null or r.workspace_id = p_workspace_id)
  ) then
    return jsonb_build_object('ok', false, 'reason_code', 'ATELIER_ROLE_UNKNOWN');
  end if;

  select m.role_key into v_before
  from public.atelier_workspace_members m
  where m.workspace_id = p_workspace_id and m.profile_id = p_profile_id;

  if v_before is null then
    return jsonb_build_object('ok', false, 'reason_code', 'ATELIER_NOT_A_MEMBER');
  end if;

  update public.atelier_workspace_members
    set role_key = p_role_key, updated_at = now()
    where workspace_id = p_workspace_id and profile_id = p_profile_id;

  perform public.atelier_log(
    p_workspace_id, null, 'member.role_change', 'profile', p_profile_id::text,
    jsonb_build_object('from', v_before, 'to', p_role_key)
  );

  return jsonb_build_object('ok', true);
end;
$fn$;

-- Retirar a alguien no borra lo que escribió: sus nodos, comentarios y
-- versiones siguen siendo del proyecto. Solo pierde el acceso.
create or replace function public.atelier_remove_member(
  p_workspace_id uuid,
  p_profile_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_owner uuid;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHENTICATED');
  end if;

  if p_profile_id <> v_uid
     and not public.atelier_has_capability(p_workspace_id, 'member.remove', v_uid) then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHORIZED');
  end if;

  select w.owner_id into v_owner
  from public.atelier_workspaces w where w.id = p_workspace_id;

  if p_profile_id = v_owner then
    return jsonb_build_object('ok', false, 'reason_code', 'ATELIER_CANNOT_REMOVE_OWNER');
  end if;

  update public.atelier_workspace_members
    set status = 'left', updated_at = now()
    where workspace_id = p_workspace_id and profile_id = p_profile_id;

  if not found then
    return jsonb_build_object('ok', false, 'reason_code', 'ATELIER_NOT_A_MEMBER');
  end if;

  perform public.atelier_log(
    p_workspace_id, null, 'member.remove', 'profile', p_profile_id::text, '{}'::jsonb
  );

  return jsonb_build_object('ok', true);
end;
$fn$;

-- ─── Roles personalizados ───────────────────────────────────────────────────

create or replace function public.atelier_upsert_role(
  p_workspace_id uuid,
  p_key text,
  p_name text,
  p_capabilities text[],
  p_description text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_known constant text[] := array[
    'project.read', 'project.write', 'project.create', 'project.delete',
    'member.invite', 'member.remove', 'member.manage', 'role.manage',
    'billing.manage', 'export.create', 'comment.create', 'comment.resolve',
    'task.assign', 'automation.manage', 'template.manage', 'settings.manage',
    'workspace.manage', 'audit.read'
  ];
  c text;
  v_id uuid;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHENTICATED');
  end if;

  if not public.atelier_has_capability(p_workspace_id, 'role.manage', v_uid) then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHORIZED');
  end if;

  select w.owner_id into v_owner
  from public.atelier_workspaces w where w.id = p_workspace_id;

  if not public.has_entitlement(v_owner, 'atelier.roles.custom', p_workspace_id) then
    return jsonb_build_object('ok', false, 'reason_code', 'ATELIER_CUSTOM_ROLES_NOT_INCLUDED');
  end if;

  -- Una capacidad inventada sería un permiso que nunca se comprueba: se
  -- rechaza en vez de guardarse como texto muerto.
  foreach c in array coalesce(p_capabilities, '{}'::text[]) loop
    if not (c = any (v_known)) then
      return jsonb_build_object(
        'ok', false, 'reason_code', 'ATELIER_CAPABILITY_UNKNOWN', 'capability', c
      );
    end if;
  end loop;

  -- billing.manage no se reparte con un rol personalizado: el dinero lo
  -- mueve quien lo paga.
  if 'billing.manage' = any (coalesce(p_capabilities, '{}'::text[])) then
    return jsonb_build_object('ok', false, 'reason_code', 'ATELIER_CAPABILITY_RESERVED');
  end if;

  insert into public.atelier_workspace_roles (
    workspace_id, key, name, description, capabilities, is_system, rank
  ) values (
    p_workspace_id, p_key, p_name, coalesce(p_description, ''),
    coalesce(p_capabilities, '{}'::text[]), false, 50
  )
  on conflict (workspace_id, key) where workspace_id is not null
  do update set
    name = excluded.name,
    description = excluded.description,
    capabilities = excluded.capabilities,
    updated_at = now()
  returning id into v_id;

  perform public.atelier_log(
    p_workspace_id, null, 'role.upsert', 'atelier_workspace_role', v_id::text,
    jsonb_build_object('key', p_key)
  );

  return jsonb_build_object('ok', true, 'role_id', v_id);
end;
$fn$;

-- ─── Compartir un proyecto ──────────────────────────────────────────────────

create or replace function public.atelier_share_project(
  p_project_id uuid,
  p_profile_id uuid,
  p_role_key text default 'reviewer'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHENTICATED');
  end if;

  if not ('member.invite' = any (
        public.atelier_project_capabilities(p_project_id, v_uid))) then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHORIZED');
  end if;

  if not exists (
    select 1 from public.atelier_workspace_roles r
    where r.workspace_id is null and r.key = p_role_key
  ) then
    return jsonb_build_object('ok', false, 'reason_code', 'ATELIER_ROLE_UNKNOWN');
  end if;

  -- El trigger de límite decide; aquí solo se traduce su grito a un código.
  begin
    insert into public.atelier_project_collaborators (
      project_id, profile_id, role_key, invited_by, status
    ) values (p_project_id, p_profile_id, p_role_key, v_uid, 'active')
    on conflict (project_id, profile_id) do update set
      role_key = excluded.role_key, status = 'active', updated_at = now()
    returning id into v_id;
  exception
    when sqlstate '53100' then
      return jsonb_build_object('ok', false, 'reason_code', 'ATELIER_COLLABORATOR_LIMIT_REACHED');
    when sqlstate '42501' then
      return jsonb_build_object('ok', false, 'reason_code', 'ATELIER_COLLABORATION_NOT_INCLUDED');
  end;

  perform public.atelier_log(
    null, p_project_id, 'project.share', 'profile', p_profile_id::text,
    jsonb_build_object('role_key', p_role_key)
  );

  return jsonb_build_object('ok', true, 'collaborator_id', v_id);
end;
$fn$;

create or replace function public.atelier_unshare_project(
  p_project_id uuid,
  p_profile_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHENTICATED');
  end if;

  if p_profile_id <> v_uid
     and not ('member.remove' = any (
       public.atelier_project_capabilities(p_project_id, v_uid))) then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHORIZED');
  end if;

  update public.atelier_project_collaborators
    set status = 'revoked', updated_at = now()
    where project_id = p_project_id and profile_id = p_profile_id;

  if not found then
    return jsonb_build_object('ok', false, 'reason_code', 'ATELIER_NOT_A_COLLABORATOR');
  end if;

  perform public.atelier_log(
    null, p_project_id, 'project.unshare', 'profile', p_profile_id::text, '{}'::jsonb
  );

  return jsonb_build_object('ok', true);
end;
$fn$;

revoke all on function public.atelier_log(uuid, uuid, text, text, text, jsonb) from public;
revoke all on function public.atelier_create_workspace(text, text) from public;
revoke all on function public.atelier_invite_to_workspace(uuid, uuid, text, text, text) from public;
revoke all on function public.atelier_respond_invitation(uuid, boolean) from public;
revoke all on function public.atelier_set_member_role(uuid, uuid, text) from public;
revoke all on function public.atelier_remove_member(uuid, uuid) from public;
revoke all on function public.atelier_upsert_role(uuid, text, text, text[], text) from public;
revoke all on function public.atelier_share_project(uuid, uuid, text) from public;
revoke all on function public.atelier_unshare_project(uuid, uuid) from public;

grant execute on function public.atelier_create_workspace(text, text) to authenticated;
grant execute on function public.atelier_invite_to_workspace(uuid, uuid, text, text, text) to authenticated;
grant execute on function public.atelier_respond_invitation(uuid, boolean) to authenticated;
grant execute on function public.atelier_set_member_role(uuid, uuid, text) to authenticated;
grant execute on function public.atelier_remove_member(uuid, uuid) to authenticated;
grant execute on function public.atelier_upsert_role(uuid, text, text, text[], text) to authenticated;
grant execute on function public.atelier_share_project(uuid, uuid, text) to authenticated;
grant execute on function public.atelier_unshare_project(uuid, uuid) to authenticated;
