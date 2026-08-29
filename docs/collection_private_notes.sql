-- Private notes for works saved in a collection.
-- Public curatorial copy remains in collection_items.note. Personal notes live
-- here so they are never exposed with a public collection item response.

create table if not exists public.collection_private_notes (
  collection_id uuid not null,
  work_id uuid not null,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (collection_id, work_id),
  foreign key (collection_id, work_id)
    references public.collection_items(collection_id, work_id)
    on delete cascade,
  constraint collection_private_notes_length_check
    check (char_length(note) <= 2000)
);

create index if not exists collection_private_notes_profile_updated_idx
  on public.collection_private_notes(profile_id, updated_at desc);

alter table public.collection_private_notes enable row level security;

drop policy if exists collection_private_notes_select_own
  on public.collection_private_notes;
create policy collection_private_notes_select_own
on public.collection_private_notes for select to authenticated
using (
  profile_id = (select auth.uid())
  and exists (
    select 1
    from public.collections c
    where c.id = collection_private_notes.collection_id
      and c.profile_id = (select auth.uid())
  )
);

drop policy if exists collection_private_notes_insert_own
  on public.collection_private_notes;
create policy collection_private_notes_insert_own
on public.collection_private_notes for insert to authenticated
with check (
  profile_id = (select auth.uid())
  and exists (
    select 1
    from public.collections c
    where c.id = collection_private_notes.collection_id
      and c.profile_id = (select auth.uid())
  )
);

drop policy if exists collection_private_notes_update_own
  on public.collection_private_notes;
create policy collection_private_notes_update_own
on public.collection_private_notes for update to authenticated
using (
  profile_id = (select auth.uid())
  and exists (
    select 1
    from public.collections c
    where c.id = collection_private_notes.collection_id
      and c.profile_id = (select auth.uid())
  )
)
with check (
  profile_id = (select auth.uid())
  and exists (
    select 1
    from public.collections c
    where c.id = collection_private_notes.collection_id
      and c.profile_id = (select auth.uid())
  )
);

drop policy if exists collection_private_notes_delete_own
  on public.collection_private_notes;
create policy collection_private_notes_delete_own
on public.collection_private_notes for delete to authenticated
using (
  profile_id = (select auth.uid())
  and exists (
    select 1
    from public.collections c
    where c.id = collection_private_notes.collection_id
      and c.profile_id = (select auth.uid())
  )
);

revoke all privileges on table public.collection_private_notes
  from public, anon, authenticated;
grant select, insert, update, delete
  on table public.collection_private_notes to authenticated;
grant all privileges on table public.collection_private_notes to service_role;
