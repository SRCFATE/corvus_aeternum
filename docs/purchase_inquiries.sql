-- Corvus Aeternum / Purchase inquiries
-- Idempotent migration for Supabase PostgreSQL.

create table if not exists public.purchase_inquiries (
  id uuid primary key default gen_random_uuid(),
  work_id uuid not null references public.works(id) on delete cascade,
  buyer_profile_id uuid not null references public.profiles(id) on delete cascade,
  artist_profile_id uuid not null references public.profiles(id) on delete cascade,
  work_title_snapshot text not null,
  status text not null default 'open',
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint purchase_inquiries_distinct_profiles
    check (buyer_profile_id <> artist_profile_id),
  constraint purchase_inquiries_status_check
    check (status in ('open', 'contacted', 'closed', 'cancelled')),
  constraint purchase_inquiries_title_check
    check (char_length(trim(work_title_snapshot)) between 1 and 200),
  constraint purchase_inquiries_buyer_work_unique
    unique (work_id, buyer_profile_id)
);

create index if not exists purchase_inquiries_artist_unread_idx
  on public.purchase_inquiries(artist_profile_id, created_at desc)
  where not is_read;

alter table public.purchase_inquiries enable row level security;

grant select, insert, update on table public.purchase_inquiries to authenticated;

drop policy if exists "Consultar solicitudes propias"
  on public.purchase_inquiries;
create policy "Consultar solicitudes propias"
on public.purchase_inquiries
for select
to authenticated
using (
  buyer_profile_id = (select auth.uid())
  or artist_profile_id = (select auth.uid())
);

drop policy if exists "Crear consulta de compra"
  on public.purchase_inquiries;
create policy "Crear consulta de compra"
on public.purchase_inquiries
for insert
to authenticated
with check (
  buyer_profile_id = (select auth.uid())
  and artist_profile_id <> (select auth.uid())
  and status = 'open'
  and not is_read
  and exists (
    select 1
    from public.works
    where works.id = purchase_inquiries.work_id
      and works.profile_id = purchase_inquiries.artist_profile_id
      and works.title = purchase_inquiries.work_title_snapshot
      and works.status = 'published'
      and works.is_public
      and works.is_for_sale
  )
);

drop policy if exists "Gestionar consultas recibidas"
  on public.purchase_inquiries;
create policy "Gestionar consultas recibidas"
on public.purchase_inquiries
for update
to authenticated
using (artist_profile_id = (select auth.uid()))
with check (artist_profile_id = (select auth.uid()));
