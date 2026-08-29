-- Corvus Aeternum: private author-led fan forums
-- Canonical schema source. Applied to Supabase through the migrations listed below.
-- Forum metadata can be discoverable; conversations and replies remain member-only.

-- Migration: create_private_fan_forums
create table if not exists public.fan_forums (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  linked_work_id uuid references public.works(id) on delete set null,
  name text not null check (char_length(trim(name)) between 3 and 80),
  description text not null check (char_length(trim(description)) between 10 and 1200),
  guidelines text not null default '' check (char_length(guidelines) <= 5000),
  join_policy text not null default 'request'
    check (join_policy in ('request', 'invite_only')),
  is_discoverable boolean not null default true,
  status text not null default 'active'
    check (status in ('active', 'archived')),
  accent_hex text not null default '#C92F35'
    check (accent_hex ~ '^#[0-9A-Fa-f]{6}$'),
  members_count integer not null default 1 check (members_count >= 0),
  threads_count integer not null default 0 check (threads_count >= 0),
  last_activity_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists fan_forums_owner_name_key
  on public.fan_forums (owner_id, lower(name));
create index if not exists fan_forums_discover_idx
  on public.fan_forums (status, is_discoverable, last_activity_at desc);
create index if not exists fan_forums_owner_idx
  on public.fan_forums (owner_id, created_at desc);
create index if not exists fan_forums_work_idx
  on public.fan_forums (linked_work_id)
  where linked_work_id is not null;

create table if not exists public.fan_forum_members (
  forum_id uuid not null references public.fan_forums(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member'
    check (role in ('owner', 'moderator', 'member')),
  status text not null default 'pending'
    check (status in ('active', 'pending', 'invited', 'rejected', 'blocked')),
  invited_by uuid references public.profiles(id) on delete set null,
  requested_at timestamptz not null default now(),
  joined_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (forum_id, profile_id),
  check ((status = 'active' and joined_at is not null) or status <> 'active')
);

create index if not exists fan_forum_members_profile_idx
  on public.fan_forum_members (profile_id, status, updated_at desc);
create index if not exists fan_forum_members_forum_idx
  on public.fan_forum_members (forum_id, status, role);

create table if not exists public.fan_forum_threads (
  id uuid primary key default gen_random_uuid(),
  forum_id uuid not null references public.fan_forums(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 3 and 140),
  body text not null check (char_length(trim(body)) between 1 and 12000),
  is_pinned boolean not null default false,
  is_locked boolean not null default false,
  replies_count integer not null default 0 check (replies_count >= 0),
  last_activity_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, forum_id)
);

create index if not exists fan_forum_threads_forum_idx
  on public.fan_forum_threads
  (forum_id, is_pinned desc, last_activity_at desc);
create index if not exists fan_forum_threads_author_idx
  on public.fan_forum_threads (author_id, created_at desc);

create table if not exists public.fan_forum_replies (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null,
  forum_id uuid not null,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 6000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (thread_id, forum_id)
    references public.fan_forum_threads(id, forum_id) on delete cascade
);

create index if not exists fan_forum_replies_thread_idx
  on public.fan_forum_replies (thread_id, created_at);
create index if not exists fan_forum_replies_forum_idx
  on public.fan_forum_replies (forum_id, created_at desc);
create index if not exists fan_forum_replies_author_idx
  on public.fan_forum_replies (author_id, created_at desc);

alter table public.fan_forums enable row level security;
alter table public.fan_forum_members enable row level security;
alter table public.fan_forum_threads enable row level security;
alter table public.fan_forum_replies enable row level security;

grant select, insert, update, delete
  on public.fan_forums,
     public.fan_forum_members,
     public.fan_forum_threads,
     public.fan_forum_replies
  to authenticated;
revoke all
  on public.fan_forums,
     public.fan_forum_members,
     public.fan_forum_threads,
     public.fan_forum_replies
  from anon;

create or replace function private.is_corvus_author()
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select (select auth.uid()) is not null
    and exists (
      select 1
      from public.profiles p
      where p.id = (select auth.uid())
        and not p.is_banned
    )
    and exists (
      select 1
      from public.works w
      where w.profile_id = (select auth.uid())
        and w.status = 'published'
        and w.is_public
    )
$function$;

create or replace function private.can_access_fan_forum(p_forum_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select (select auth.uid()) is not null and exists (
    select 1
    from public.fan_forums f
    where f.id = p_forum_id
      and (
        f.owner_id = (select auth.uid())
        or exists (
          select 1
          from public.fan_forum_members m
          where m.forum_id = f.id
            and m.profile_id = (select auth.uid())
            and m.status = 'active'
        )
      )
  )
$function$;

create or replace function private.can_moderate_fan_forum(p_forum_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select (select auth.uid()) is not null and exists (
    select 1
    from public.fan_forums f
    where f.id = p_forum_id
      and (
        f.owner_id = (select auth.uid())
        or exists (
          select 1
          from public.fan_forum_members m
          where m.forum_id = f.id
            and m.profile_id = (select auth.uid())
            and m.status = 'active'
            and m.role = 'moderator'
        )
      )
  )
$function$;

revoke all on function private.is_corvus_author() from public, anon;
revoke all on function private.can_access_fan_forum(uuid) from public, anon;
revoke all on function private.can_moderate_fan_forum(uuid) from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.is_corvus_author() to authenticated;
grant execute on function private.can_access_fan_forum(uuid) to authenticated;
grant execute on function private.can_moderate_fan_forum(uuid) to authenticated;

drop policy if exists "forum metadata is discoverable" on public.fan_forums;
create policy "forum metadata is discoverable"
on public.fan_forums for select
to authenticated
using (
  owner_id = (select auth.uid())
  or (
    status = 'active'
    and (
      is_discoverable
      or private.can_access_fan_forum(id)
      or exists (
        select 1
        from public.fan_forum_members membership
        where membership.forum_id = id
          and membership.profile_id = (select auth.uid())
      )
    )
  )
);

drop policy if exists "authors create private forums" on public.fan_forums;
create policy "authors create private forums"
on public.fan_forums for insert
to authenticated
with check (
  owner_id = (select auth.uid())
  and private.is_corvus_author()
  and (
    linked_work_id is null
    or exists (
      select 1
      from public.works w
      where w.id = linked_work_id
        and w.profile_id = (select auth.uid())
        and w.status = 'published'
        and w.is_public
    )
  )
);

drop policy if exists "owners update forums" on public.fan_forums;
create policy "owners update forums"
on public.fan_forums for update
to authenticated
using (owner_id = (select auth.uid()))
with check (
  owner_id = (select auth.uid())
  and (
    linked_work_id is null
    or exists (
      select 1
      from public.works w
      where w.id = linked_work_id
        and w.profile_id = (select auth.uid())
        and w.status = 'published'
        and w.is_public
    )
  )
);

drop policy if exists "owners delete forums" on public.fan_forums;
create policy "owners delete forums"
on public.fan_forums for delete
to authenticated
using (owner_id = (select auth.uid()));

drop policy if exists "members read safe membership rows" on public.fan_forum_members;
create policy "members read safe membership rows"
on public.fan_forum_members for select
to authenticated
using (
  profile_id = (select auth.uid())
  or private.can_moderate_fan_forum(forum_id)
  or (
    status = 'active'
    and private.can_access_fan_forum(forum_id)
  )
);

drop policy if exists "fans request forum access" on public.fan_forum_members;
create policy "fans request forum access"
on public.fan_forum_members for insert
to authenticated
with check (
  profile_id = (select auth.uid())
  and role = 'member'
  and status = 'pending'
  and exists (
    select 1
    from public.fan_forums f
    where f.id = forum_id
      and f.status = 'active'
      and f.join_policy = 'request'
  )
);

drop policy if exists "moderators invite fans" on public.fan_forum_members;
create policy "moderators invite fans"
on public.fan_forum_members for insert
to authenticated
with check (
  private.can_moderate_fan_forum(forum_id)
  and role = 'member'
  and status = 'invited'
  and invited_by = (select auth.uid())
);

drop policy if exists "moderators manage memberships" on public.fan_forum_members;
create policy "moderators manage memberships"
on public.fan_forum_members for update
to authenticated
using (
  private.can_moderate_fan_forum(forum_id)
  and role <> 'owner'
)
with check (
  private.can_moderate_fan_forum(forum_id)
  and role in ('member', 'moderator')
  and status in ('active', 'pending', 'invited', 'rejected', 'blocked')
);

drop policy if exists "invited fans accept" on public.fan_forum_members;
create policy "invited fans accept"
on public.fan_forum_members for update
to authenticated
using (
  profile_id = (select auth.uid())
  and role = 'member'
  and status = 'invited'
)
with check (
  profile_id = (select auth.uid())
  and role = 'member'
  and status = 'active'
  and joined_at is not null
);

drop policy if exists "members leave or moderators remove" on public.fan_forum_members;
create policy "members leave or moderators remove"
on public.fan_forum_members for delete
to authenticated
using (
  (
    profile_id = (select auth.uid())
    and role <> 'owner'
  )
  or (
    private.can_moderate_fan_forum(forum_id)
    and role <> 'owner'
  )
);

drop policy if exists "members read forum threads" on public.fan_forum_threads;
create policy "members read forum threads"
on public.fan_forum_threads for select
to authenticated
using (private.can_access_fan_forum(forum_id));

drop policy if exists "members create forum threads" on public.fan_forum_threads;
create policy "members create forum threads"
on public.fan_forum_threads for insert
to authenticated
with check (
  author_id = (select auth.uid())
  and private.can_access_fan_forum(forum_id)
  and exists (
    select 1 from public.fan_forums f
    where f.id = forum_id and f.status = 'active'
  )
);

drop policy if exists "authors and moderators update threads" on public.fan_forum_threads;
create policy "authors and moderators update threads"
on public.fan_forum_threads for update
to authenticated
using (
  author_id = (select auth.uid())
  or private.can_moderate_fan_forum(forum_id)
)
with check (
  private.can_access_fan_forum(forum_id)
  and (
    author_id = (select auth.uid())
    or private.can_moderate_fan_forum(forum_id)
  )
);

drop policy if exists "authors and moderators delete threads" on public.fan_forum_threads;
create policy "authors and moderators delete threads"
on public.fan_forum_threads for delete
to authenticated
using (
  author_id = (select auth.uid())
  or private.can_moderate_fan_forum(forum_id)
);

drop policy if exists "members read forum replies" on public.fan_forum_replies;
create policy "members read forum replies"
on public.fan_forum_replies for select
to authenticated
using (private.can_access_fan_forum(forum_id));

drop policy if exists "members create forum replies" on public.fan_forum_replies;
create policy "members create forum replies"
on public.fan_forum_replies for insert
to authenticated
with check (
  author_id = (select auth.uid())
  and private.can_access_fan_forum(forum_id)
  and exists (
    select 1
    from public.fan_forum_threads t
    where t.id = thread_id
      and t.forum_id = forum_id
      and not t.is_locked
  )
);

drop policy if exists "authors update forum replies" on public.fan_forum_replies;
create policy "authors update forum replies"
on public.fan_forum_replies for update
to authenticated
using (
  author_id = (select auth.uid())
  or private.can_moderate_fan_forum(forum_id)
)
with check (
  private.can_access_fan_forum(forum_id)
  and (
    author_id = (select auth.uid())
    or private.can_moderate_fan_forum(forum_id)
  )
);

drop policy if exists "authors and moderators delete replies" on public.fan_forum_replies;
create policy "authors and moderators delete replies"
on public.fan_forum_replies for delete
to authenticated
using (
  author_id = (select auth.uid())
  or private.can_moderate_fan_forum(forum_id)
);

create or replace function private.seed_fan_forum_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  insert into public.fan_forum_members (
    forum_id, profile_id, role, status, invited_by, joined_at
  )
  values (
    new.id, new.owner_id, 'owner', 'active', new.owner_id, now()
  )
  on conflict (forum_id, profile_id) do nothing;
  return new;
end
$function$;

create or replace function private.refresh_fan_forum_member_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  target_forum_id uuid := coalesce(new.forum_id, old.forum_id);
begin
  update public.fan_forums
  set members_count = (
        select count(*)::integer
        from public.fan_forum_members m
        where m.forum_id = target_forum_id and m.status = 'active'
      ),
      updated_at = now()
  where id = target_forum_id;
  return coalesce(new, old);
end
$function$;

create or replace function private.refresh_fan_forum_thread_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  target_forum_id uuid := coalesce(new.forum_id, old.forum_id);
begin
  update public.fan_forums
  set threads_count = (
        select count(*)::integer
        from public.fan_forum_threads t
        where t.forum_id = target_forum_id
      ),
      last_activity_at = now(),
      updated_at = now()
  where id = target_forum_id;
  return coalesce(new, old);
end
$function$;

create or replace function private.refresh_fan_forum_reply_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  target_thread_id uuid := coalesce(new.thread_id, old.thread_id);
  target_forum_id uuid := coalesce(new.forum_id, old.forum_id);
begin
  update public.fan_forum_threads
  set replies_count = (
        select count(*)::integer
        from public.fan_forum_replies r
        where r.thread_id = target_thread_id
      ),
      last_activity_at = now(),
      updated_at = now()
  where id = target_thread_id;

  update public.fan_forums
  set last_activity_at = now(), updated_at = now()
  where id = target_forum_id;
  return coalesce(new, old);
end
$function$;

create or replace function private.notify_fan_forum_membership()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  forum_owner_id uuid;
  forum_name text;
begin
  select f.owner_id, f.name
  into forum_owner_id, forum_name
  from public.fan_forums f
  where f.id = new.forum_id;

  if tg_op = 'INSERT' and new.status = 'pending' then
    insert into public.notifications (
      profile_id, kind, title, body, actor_id, entity_type, entity_id
    )
    values (
      forum_owner_id,
      'forum_request',
      'Nueva solicitud en ' || forum_name,
      'Un lector quiere entrar a tu foro privado.',
      new.profile_id,
      'fan_forum',
      new.forum_id
    );
  elsif tg_op = 'INSERT' and new.status = 'invited' then
    insert into public.notifications (
      profile_id, kind, title, body, actor_id, entity_type, entity_id
    )
    values (
      new.profile_id,
      'forum_invitation',
      'Invitación a ' || forum_name,
      'El autor te invitó a convivir con su comunidad.',
      new.invited_by,
      'fan_forum',
      new.forum_id
    );
  elsif tg_op = 'UPDATE'
    and old.status is distinct from new.status
    and new.status in ('active', 'rejected', 'blocked')
    and new.profile_id <> forum_owner_id then
    insert into public.notifications (
      profile_id, kind, title, body, actor_id, entity_type, entity_id
    )
    values (
      new.profile_id,
      'forum_membership',
      case
        when new.status = 'active' then 'Acceso concedido a ' || forum_name
        when new.status = 'blocked' then 'Acceso retirado de ' || forum_name
        else 'Solicitud revisada en ' || forum_name
      end,
      case
        when new.status = 'active' then 'Ya puedes participar en la comunidad.'
        when new.status = 'blocked' then 'El equipo de moderación retiró tu acceso.'
        else 'El autor no aprobó la solicitud en esta ocasión.'
      end,
      (select auth.uid()),
      'fan_forum',
      new.forum_id
    );
  end if;
  return new;
end
$function$;

revoke all on function private.seed_fan_forum_owner() from public, anon, authenticated;
revoke all on function private.refresh_fan_forum_member_count() from public, anon, authenticated;
revoke all on function private.refresh_fan_forum_thread_count() from public, anon, authenticated;
revoke all on function private.refresh_fan_forum_reply_count() from public, anon, authenticated;
revoke all on function private.notify_fan_forum_membership() from public, anon, authenticated;

drop trigger if exists seed_fan_forum_owner on public.fan_forums;
create trigger seed_fan_forum_owner
after insert on public.fan_forums
for each row execute function private.seed_fan_forum_owner();

drop trigger if exists refresh_fan_forum_member_count
  on public.fan_forum_members;
create trigger refresh_fan_forum_member_count
after insert or update or delete on public.fan_forum_members
for each row execute function private.refresh_fan_forum_member_count();

drop trigger if exists notify_fan_forum_membership
  on public.fan_forum_members;
create trigger notify_fan_forum_membership
after insert or update of status on public.fan_forum_members
for each row execute function private.notify_fan_forum_membership();

drop trigger if exists refresh_fan_forum_thread_count
  on public.fan_forum_threads;
create trigger refresh_fan_forum_thread_count
after insert or delete on public.fan_forum_threads
for each row execute function private.refresh_fan_forum_thread_count();

drop trigger if exists refresh_fan_forum_reply_count
  on public.fan_forum_replies;
create trigger refresh_fan_forum_reply_count
after insert or delete on public.fan_forum_replies
for each row execute function private.refresh_fan_forum_reply_count();

comment on table public.fan_forums is
  'Private author-led fan communities; metadata may be discoverable while content remains member-only.';
comment on table public.fan_forum_members is
  'Forum ownership, moderation, invitations, requests, and active memberships.';
comment on table public.fan_forum_threads is
  'Member-only discussion threads inside private fan forums.';
comment on table public.fan_forum_replies is
  'Member-only replies attached to forum threads.';

-- Migration: fix_fan_forum_policy_recursion
create or replace function private.has_fan_forum_relationship(
  p_forum_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select (select auth.uid()) is not null and exists (
    select 1
    from public.fan_forum_members m
    where m.forum_id = p_forum_id
      and m.profile_id = (select auth.uid())
  )
$function$;

revoke all on function private.has_fan_forum_relationship(uuid)
from public, anon;
grant execute on function private.has_fan_forum_relationship(uuid)
to authenticated;

drop policy if exists "forum metadata is discoverable"
on public.fan_forums;
create policy "forum metadata is discoverable"
on public.fan_forums for select
to authenticated
using (
  owner_id = (select auth.uid())
  or (
    status = 'active'
    and (
      is_discoverable
      or private.can_access_fan_forum(id)
      or private.has_fan_forum_relationship(id)
    )
  )
);

-- Migration: allow_fan_forum_notifications
alter table public.notifications
  drop constraint if exists notifications_kind_check;
alter table public.notifications
  add constraint notifications_kind_check check (
    kind in (
      'like', 'comment', 'comment_reply', 'follow', 'bid', 'outbid',
      'auction_won', 'auction_end', 'verification_approved',
      'verification_rejected', 'work_featured', 'purchase_inquiry',
      'conspiracy_unlocked', 'conspiracy_invitation', 'forum_request',
      'forum_invitation', 'forum_membership', 'system'
    )
  );

alter table public.notifications
  drop constraint if exists notifications_entity_type_check;
alter table public.notifications
  add constraint notifications_entity_type_check check (
    entity_type is null
    or entity_type in (
      'work', 'auction', 'collection', 'profile', 'user',
      'conspiracy', 'fan_forum'
    )
  );

-- Migration: harden_fan_forum_updates_and_resubmission
revoke update
  on public.fan_forums,
     public.fan_forum_members,
     public.fan_forum_threads,
     public.fan_forum_replies
  from authenticated;

grant update (
  linked_work_id, name, description, guidelines, join_policy,
  is_discoverable, status, accent_hex, updated_at
) on public.fan_forums to authenticated;

grant update (
  role, status, invited_by, requested_at, joined_at, updated_at
) on public.fan_forum_members to authenticated;

grant update (
  title, body, is_pinned, is_locked, updated_at
) on public.fan_forum_threads to authenticated;

grant update (body, updated_at)
  on public.fan_forum_replies to authenticated;

create or replace function private.guard_fan_forum_thread_moderation()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if new.forum_id is distinct from old.forum_id
    or new.author_id is distinct from old.author_id
    or new.created_at is distinct from old.created_at then
    raise exception 'IMMUTABLE_FORUM_THREAD_FIELDS'
      using errcode = '42501';
  end if;

  if (
    new.is_pinned is distinct from old.is_pinned
    or new.is_locked is distinct from old.is_locked
  ) and not private.can_moderate_fan_forum(old.forum_id) then
    raise exception 'FORUM_MODERATOR_REQUIRED'
      using errcode = '42501';
  end if;

  return new;
end
$function$;

revoke all on function private.guard_fan_forum_thread_moderation()
  from public, anon, authenticated;

drop trigger if exists guard_fan_forum_thread_moderation
  on public.fan_forum_threads;
create trigger guard_fan_forum_thread_moderation
before update on public.fan_forum_threads
for each row execute function private.guard_fan_forum_thread_moderation();

drop policy if exists "fans resubmit rejected requests"
  on public.fan_forum_members;
create policy "fans resubmit rejected requests"
on public.fan_forum_members for update
to authenticated
using (
  profile_id = (select auth.uid())
  and role = 'member'
  and status = 'rejected'
)
with check (
  profile_id = (select auth.uid())
  and role = 'member'
  and status = 'pending'
  and exists (
    select 1
    from public.fan_forums f
    where f.id = forum_id
      and f.status = 'active'
      and f.join_policy = 'request'
  )
);

create or replace function private.notify_fan_forum_membership()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  forum_owner_id uuid;
  forum_name text;
begin
  select f.owner_id, f.name
  into forum_owner_id, forum_name
  from public.fan_forums f
  where f.id = new.forum_id;

  if (
    (tg_op = 'INSERT' and new.status = 'pending')
    or (
      tg_op = 'UPDATE'
      and old.status is distinct from new.status
      and new.status = 'pending'
    )
  ) then
    insert into public.notifications (
      profile_id, kind, title, body, actor_id, entity_type, entity_id
    )
    values (
      forum_owner_id,
      'forum_request',
      'Nueva solicitud en ' || forum_name,
      'Un lector quiere entrar a tu foro privado.',
      new.profile_id,
      'fan_forum',
      new.forum_id
    );
  elsif tg_op = 'INSERT' and new.status = 'invited' then
    insert into public.notifications (
      profile_id, kind, title, body, actor_id, entity_type, entity_id
    )
    values (
      new.profile_id,
      'forum_invitation',
      'Invitación a ' || forum_name,
      'El autor te invitó a convivir con su comunidad.',
      new.invited_by,
      'fan_forum',
      new.forum_id
    );
  elsif tg_op = 'UPDATE'
    and old.status is distinct from new.status
    and new.status in ('active', 'rejected', 'blocked')
    and new.profile_id <> forum_owner_id
    and not (
      old.status = 'invited'
      and new.status = 'active'
      and (select auth.uid()) = new.profile_id
    ) then
    insert into public.notifications (
      profile_id, kind, title, body, actor_id, entity_type, entity_id
    )
    values (
      new.profile_id,
      'forum_membership',
      case
        when new.status = 'active' then 'Acceso concedido a ' || forum_name
        when new.status = 'blocked' then 'Acceso retirado de ' || forum_name
        else 'Solicitud revisada en ' || forum_name
      end,
      case
        when new.status = 'active' then 'Ya puedes participar en la comunidad.'
        when new.status = 'blocked' then 'El equipo de moderación retiró tu acceso.'
        else 'El autor no aprobó la solicitud en esta ocasión.'
      end,
      (select auth.uid()),
      'fan_forum',
      new.forum_id
    );
  end if;
  return new;
end
$function$;

revoke all on function private.notify_fan_forum_membership()
  from public, anon, authenticated;

-- Migration: optimize_and_guard_fan_forum_memberships
create index if not exists fan_forum_members_invited_by_idx
  on public.fan_forum_members (invited_by)
  where invited_by is not null;

drop index if exists public.fan_forum_replies_thread_idx;
create index if not exists fan_forum_replies_thread_forum_idx
  on public.fan_forum_replies (thread_id, forum_id, created_at);

create or replace function private.guard_fan_forum_membership_update()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if new.forum_id is distinct from old.forum_id
    or new.profile_id is distinct from old.profile_id
    or new.requested_at < old.requested_at then
    raise exception 'IMMUTABLE_FORUM_MEMBERSHIP_FIELDS'
      using errcode = '42501';
  end if;

  if private.can_moderate_fan_forum(old.forum_id) then
    if old.role = 'owner'
      or new.role not in ('member', 'moderator')
      or new.status not in (
        'active', 'pending', 'invited', 'rejected', 'blocked'
      ) then
      raise exception 'INVALID_FORUM_MEMBERSHIP_CHANGE'
        using errcode = '42501';
    end if;
    return new;
  end if;

  if old.profile_id = (select auth.uid())
    and old.role = 'member'
    and new.role = 'member' then
    if old.status = 'invited'
      and new.status = 'active'
      and new.joined_at is not null then
      return new;
    end if;

    if old.status = 'rejected'
      and new.status = 'pending'
      and exists (
        select 1
        from public.fan_forums f
        where f.id = old.forum_id
          and f.status = 'active'
          and f.join_policy = 'request'
      ) then
      return new;
    end if;
  end if;

  raise exception 'INVALID_FORUM_MEMBERSHIP_TRANSITION'
    using errcode = '42501';
end
$function$;

revoke all on function private.guard_fan_forum_membership_update()
  from public, anon, authenticated;

drop trigger if exists guard_fan_forum_membership_update
  on public.fan_forum_members;
create trigger guard_fan_forum_membership_update
before update on public.fan_forum_members
for each row execute function private.guard_fan_forum_membership_update();

drop policy if exists "fans request forum access"
  on public.fan_forum_members;
drop policy if exists "moderators invite fans"
  on public.fan_forum_members;
create policy "forum membership requests and invitations"
on public.fan_forum_members for insert
to authenticated
with check (
  (
    profile_id = (select auth.uid())
    and role = 'member'
    and status = 'pending'
    and exists (
      select 1
      from public.fan_forums f
      where f.id = forum_id
        and f.status = 'active'
        and f.join_policy = 'request'
    )
  )
  or (
    private.can_moderate_fan_forum(forum_id)
    and role = 'member'
    and status = 'invited'
    and invited_by = (select auth.uid())
  )
);

drop policy if exists "moderators manage memberships"
  on public.fan_forum_members;
drop policy if exists "invited fans accept"
  on public.fan_forum_members;
drop policy if exists "fans resubmit rejected requests"
  on public.fan_forum_members;
create policy "valid forum membership transitions"
on public.fan_forum_members for update
to authenticated
using (
  (
    private.can_moderate_fan_forum(forum_id)
    and role <> 'owner'
  )
  or (
    profile_id = (select auth.uid())
    and role = 'member'
    and status in ('invited', 'rejected')
  )
)
with check (
  (
    private.can_moderate_fan_forum(forum_id)
    and role in ('member', 'moderator')
    and status in (
      'active', 'pending', 'invited', 'rejected', 'blocked'
    )
  )
  or (
    profile_id = (select auth.uid())
    and role = 'member'
    and (
      (status = 'active' and joined_at is not null)
      or (
        status = 'pending'
        and exists (
          select 1
          from public.fan_forums f
          where f.id = forum_id
            and f.status = 'active'
            and f.join_policy = 'request'
        )
      )
    )
  )
);

