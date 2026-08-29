-- Corvus Aeternum / Collections and auctions
-- Idempotent migration for Supabase PostgreSQL.

create extension if not exists pgcrypto;
create extension if not exists pg_cron with schema pg_catalog;

-- Collections ----------------------------------------------------------------

alter table public.collections
  add column if not exists collection_type text not null default 'curated';

create table if not exists public.collection_likes (
  collection_id uuid not null references public.collections(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (collection_id, profile_id)
);

create table if not exists public.collection_views (
  collection_id uuid not null references public.collections(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  viewed_at timestamptz not null default now(),
  primary key (collection_id, profile_id)
);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'collections_type_check'
      and conrelid = 'public.collections'::regclass
  ) then
    alter table public.collections
      add constraint collections_type_check
      check (collection_type in (
        'curated', 'personal', 'inspiration', 'exhibition', 'series'
      ));
  end if;
end
$$;

create index if not exists collections_profile_updated_idx
  on public.collections(profile_id, updated_at desc);
create index if not exists collections_public_updated_idx
  on public.collections(updated_at desc) where is_public;
create index if not exists collections_featured_idx
  on public.collections(updated_at desc) where is_public and is_featured;
create index if not exists collection_items_work_idx
  on public.collection_items(work_id);
create index if not exists collection_likes_profile_idx
  on public.collection_likes(profile_id, created_at desc);
create index if not exists collection_views_profile_idx
  on public.collection_views(profile_id, viewed_at desc);

alter table public.collections enable row level security;
alter table public.collection_items enable row level security;
alter table public.collection_likes enable row level security;
alter table public.collection_views enable row level security;

create or replace function public.update_pieces_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update public.collections
    set pieces_count = pieces_count + 1
    where id = new.collection_id;
    return new;
  end if;

  update public.collections
  set pieces_count = greatest(0, pieces_count - 1)
  where id = old.collection_id;
  return old;
end;
$$;

create or replace function public.update_collections_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.profile_id is not null then
      update public.profiles
      set collections_count = collections_count + 1
      where id = new.profile_id;
    end if;
    return new;
  end if;

  if old.profile_id is not null then
    update public.profiles
    set collections_count = greatest(0, collections_count - 1)
    where id = old.profile_id;
  end if;
  return old;
end;
$$;

create or replace function public.update_collection_likes_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update public.collections
    set likes_count = likes_count + 1
    where id = new.collection_id;
    return new;
  end if;

  update public.collections
  set likes_count = greatest(0, likes_count - 1)
  where id = old.collection_id;
  return old;
end;
$$;

create or replace function public.update_collection_views_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.collections
  set views_count = views_count + 1
  where id = new.collection_id;
  return new;
end;
$$;

drop trigger if exists collection_likes_count on public.collection_likes;
create trigger collection_likes_count
after insert or delete on public.collection_likes
for each row execute function public.update_collection_likes_count();

drop trigger if exists collection_views_count on public.collection_views;
create trigger collection_views_count
after insert on public.collection_views
for each row execute function public.update_collection_views_count();

create or replace function public.reorder_collection_items(
  p_collection_id uuid,
  p_work_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_item_count integer;
  v_distinct_count integer;
begin
  if v_user_id is null then
    raise exception 'Debes iniciar sesión para ordenar una colección.';
  end if;

  if not exists (
    select 1
    from public.collections c
    where c.id = p_collection_id
      and c.profile_id = v_user_id
  ) then
    raise exception 'No tienes permiso para editar esta colección.';
  end if;

  select count(*) into v_item_count
  from public.collection_items ci
  where ci.collection_id = p_collection_id;

  select count(distinct work_id) into v_distinct_count
  from unnest(coalesce(p_work_ids, '{}'::uuid[])) as work_ids(work_id);

  if cardinality(coalesce(p_work_ids, '{}'::uuid[])) <> v_item_count
      or v_distinct_count <> v_item_count
      or exists (
        select 1
        from unnest(coalesce(p_work_ids, '{}'::uuid[])) as requested(work_id)
        left join public.collection_items ci
          on ci.collection_id = p_collection_id
         and ci.work_id = requested.work_id
        where ci.work_id is null
      ) then
    raise exception 'El orden recibido no coincide con las piezas de la colección.';
  end if;

  update public.collection_items ci
  set position = (ordered.ordinality - 1)::integer
  from unnest(p_work_ids) with ordinality as ordered(work_id, ordinality)
  where ci.collection_id = p_collection_id
    and ci.work_id = ordered.work_id;
end;
$$;

-- Auctions -------------------------------------------------------------------

alter table public.auctions
  add column if not exists seller_profile_id uuid,
  add column if not exists original_ends_at timestamptz,
  add column if not exists winner_id uuid,
  add column if not exists reserve_met boolean not null default false,
  add column if not exists settlement_status text not null default 'not_started',
  add column if not exists lot_type text not null default 'digital',
  add column if not exists condition text not null default '',
  add column if not exists edition_label text not null default '',
  add column if not exists shipping_notes text not null default '',
  add column if not exists certificate_id text not null default '',
  add column if not exists anti_snipe_minutes smallint not null default 2,
  add column if not exists extension_minutes smallint not null default 5;

update public.auctions a
set seller_profile_id = ar.profile_id
from public.artists ar
where a.seller_profile_id is null
  and a.artist_id = ar.id;

update public.auctions
set original_ends_at = ends_at
where original_ends_at is null;

alter table public.auctions
  alter column seller_profile_id set not null,
  alter column starts_at set not null,
  alter column ends_at set not null,
  alter column original_ends_at set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'auctions_seller_profile_id_fkey'
      and conrelid = 'public.auctions'::regclass
  ) then
    alter table public.auctions
      add constraint auctions_seller_profile_id_fkey
      foreign key (seller_profile_id) references public.profiles(id)
      on delete cascade;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'auctions_winner_id_fkey'
      and conrelid = 'public.auctions'::regclass
  ) then
    alter table public.auctions
      add constraint auctions_winner_id_fkey
      foreign key (winner_id) references public.profiles(id)
      on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'auctions_amounts_check'
      and conrelid = 'public.auctions'::regclass
  ) then
    alter table public.auctions
      add constraint auctions_amounts_check check (
        starting_bid > 0
        and bid_increment > 0
        and (reserve_price is null or reserve_price >= starting_bid)
        and (current_bid is null or current_bid >= starting_bid)
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'auctions_schedule_check'
      and conrelid = 'public.auctions'::regclass
  ) then
    alter table public.auctions
      add constraint auctions_schedule_check check (starts_at < ends_at);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'auctions_currency_check'
      and conrelid = 'public.auctions'::regclass
  ) then
    alter table public.auctions
      add constraint auctions_currency_check
      check (currency in ('MXN', 'USD', 'EUR'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'auctions_lot_type_check'
      and conrelid = 'public.auctions'::regclass
  ) then
    alter table public.auctions
      add constraint auctions_lot_type_check
      check (lot_type in ('digital', 'physical', 'hybrid', 'service'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'auctions_settlement_status_check'
      and conrelid = 'public.auctions'::regclass
  ) then
    alter table public.auctions
      add constraint auctions_settlement_status_check check (
        settlement_status in (
          'not_started', 'awaiting_payment', 'paid', 'delivered',
          'completed', 'no_sale', 'cancelled'
        )
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'auctions_extension_window_check'
      and conrelid = 'public.auctions'::regclass
  ) then
    alter table public.auctions
      add constraint auctions_extension_window_check check (
        anti_snipe_minutes between 0 and 30
        and extension_minutes between 0 and 60
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'auction_bids_amount_check'
      and conrelid = 'public.auction_bids'::regclass
  ) then
    alter table public.auction_bids
      add constraint auction_bids_amount_check check (amount > 0);
  end if;
end
$$;

create index if not exists auctions_seller_created_idx
  on public.auctions(seller_profile_id, created_at desc);
create index if not exists auctions_work_idx
  on public.auctions(work_id);
create unique index if not exists auctions_one_active_work_idx
  on public.auctions(work_id)
  where work_id is not null and status in ('upcoming', 'live');
create index if not exists auctions_current_bidder_idx
  on public.auctions(current_bidder);
create index if not exists auctions_winner_idx
  on public.auctions(winner_id);
create index if not exists auctions_live_ends_idx
  on public.auctions(ends_at) where status = 'live';
create index if not exists auctions_upcoming_starts_idx
  on public.auctions(starts_at) where status = 'upcoming';
create index if not exists auction_bids_auction_amount_idx
  on public.auction_bids(auction_id, amount desc, created_at desc);
create index if not exists auction_bids_bidder_idx
  on public.auction_bids(bidder_id, created_at desc);
create index if not exists auction_watchers_profile_idx
  on public.auction_watchers(profile_id, created_at desc);

alter table public.auctions enable row level security;
alter table public.auction_bids enable row level security;
alter table public.auction_watchers enable row level security;

drop trigger if exists auction_bid_handler on public.auction_bids;
drop trigger if exists auction_outbid_notify on public.auction_bids;
drop function if exists public.handle_new_bid();
drop function if exists public.notify_outbid();

create or replace function public.update_watchers_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update public.auctions
    set watchers_count = watchers_count + 1
    where id = new.auction_id;
    return new;
  end if;

  update public.auctions
  set watchers_count = greatest(0, watchers_count - 1)
  where id = old.auction_id;
  return old;
end;
$$;

create or replace function public.place_auction_bid(
  p_auction_id uuid,
  p_amount numeric
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_auction public.auctions%rowtype;
  v_minimum numeric;
  v_previous_bidder uuid;
  v_bid_id uuid;
  v_now timestamptz := clock_timestamp();
  v_new_end timestamptz;
begin
  if v_user_id is null then
    raise exception 'Debes iniciar sesión para pujar.';
  end if;

  select * into v_auction
  from public.auctions
  where id = p_auction_id
  for update;

  if not found then
    raise exception 'La subasta no existe.';
  end if;
  if v_auction.seller_profile_id = v_user_id then
    raise exception 'No puedes pujar por tu propio lote.';
  end if;
  if v_auction.status in ('ended', 'cancelled') then
    raise exception 'La subasta ya no acepta pujas.';
  end if;
  if v_auction.starts_at > v_now then
    raise exception 'La subasta todavía no comienza.';
  end if;
  if v_auction.ends_at <= v_now then
    raise exception 'La subasta ya finalizó.';
  end if;

  v_minimum := case
    when v_auction.current_bid is null then v_auction.starting_bid
    else v_auction.current_bid + v_auction.bid_increment
  end;

  if p_amount is null or p_amount < v_minimum then
    raise exception 'La puja mínima es % %.', v_minimum, v_auction.currency;
  end if;

  v_previous_bidder := v_auction.current_bidder;
  v_new_end := v_auction.ends_at;

  if v_auction.anti_snipe_minutes > 0
      and v_auction.extension_minutes > 0
      and v_auction.ends_at - v_now
        <= make_interval(mins => v_auction.anti_snipe_minutes) then
    v_new_end := v_auction.ends_at
      + make_interval(mins => v_auction.extension_minutes);
  end if;

  update public.auction_bids
  set is_winning = false
  where auction_id = p_auction_id
    and is_winning;

  insert into public.auction_bids (
    auction_id, bidder_id, amount, is_winning
  ) values (
    p_auction_id, v_user_id, p_amount, true
  ) returning id into v_bid_id;

  update public.auctions
  set current_bid = p_amount,
      current_bidder = v_user_id,
      bids_count = bids_count + 1,
      reserve_met = reserve_price is null or p_amount >= reserve_price,
      status = 'live',
      ends_at = v_new_end,
      updated_at = v_now
  where id = p_auction_id;

  if v_previous_bidder is not null and v_previous_bidder <> v_user_id then
    insert into public.notifications (
      profile_id, kind, title, body, actor_id, entity_type, entity_id
    ) values (
      v_previous_bidder,
      'outbid',
      'Superaron tu puja',
      'Hay una nueva puja por ' || v_auction.lot_title || '.',
      v_user_id,
      'auction',
      p_auction_id
    );
  end if;

  insert into public.notifications (
    profile_id, kind, title, body, actor_id, entity_type, entity_id
  ) values (
    v_auction.seller_profile_id,
    'bid',
    'Nueva puja en tu lote',
    'La puja actual por ' || v_auction.lot_title || ' es '
      || p_amount || ' ' || v_auction.currency || '.',
    v_user_id,
    'auction',
    p_auction_id
  );

  return v_bid_id;
end;
$$;

create or replace function public.update_auction_details(
  p_auction_id uuid,
  p_lot_title text,
  p_description text,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_starting_bid numeric,
  p_bid_increment numeric,
  p_reserve_price numeric,
  p_currency text,
  p_lot_type text,
  p_condition text,
  p_edition_label text,
  p_shipping_notes text,
  p_certificate_id text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_auction public.auctions%rowtype;
begin
  if v_user_id is null then
    raise exception 'Debes iniciar sesión para editar una subasta.';
  end if;
  if nullif(btrim(p_lot_title), '') is null then
    raise exception 'El título del lote es obligatorio.';
  end if;
  if p_starts_at >= p_ends_at then
    raise exception 'La fecha de cierre debe ser posterior al inicio.';
  end if;
  if p_starting_bid <= 0 or p_bid_increment <= 0 then
    raise exception 'Los importes deben ser mayores que cero.';
  end if;
  if p_reserve_price is not null and p_reserve_price < p_starting_bid then
    raise exception 'La reserva no puede ser menor que la puja inicial.';
  end if;
  if p_currency not in ('MXN', 'USD', 'EUR') then
    raise exception 'La moneda no es válida.';
  end if;
  if p_lot_type not in ('digital', 'physical', 'hybrid', 'service') then
    raise exception 'El tipo de lote no es válido.';
  end if;

  select * into v_auction
  from public.auctions
  where id = p_auction_id
  for update;

  if not found then
    raise exception 'La subasta no existe.';
  end if;
  if v_auction.seller_profile_id <> v_user_id then
    raise exception 'No tienes permiso para editar esta subasta.';
  end if;
  if v_auction.status in ('ended', 'cancelled') then
    raise exception 'Una subasta cerrada no se puede editar.';
  end if;
  if v_auction.bids_count > 0 and (
    v_auction.starts_at is distinct from p_starts_at
    or v_auction.ends_at is distinct from p_ends_at
    or v_auction.starting_bid is distinct from p_starting_bid
    or v_auction.bid_increment is distinct from p_bid_increment
    or v_auction.reserve_price is distinct from p_reserve_price
    or v_auction.currency is distinct from p_currency
  ) then
    raise exception 'El precio y el calendario quedan bloqueados al recibir la primera puja.';
  end if;

  update public.auctions
  set lot_title = btrim(p_lot_title),
      description = btrim(coalesce(p_description, '')),
      starts_at = case when bids_count = 0 then p_starts_at else starts_at end,
      ends_at = case when bids_count = 0 then p_ends_at else ends_at end,
      original_ends_at = case
        when bids_count = 0 then p_ends_at
        else original_ends_at
      end,
      starting_bid = case
        when bids_count = 0 then p_starting_bid
        else starting_bid
      end,
      bid_increment = case
        when bids_count = 0 then p_bid_increment
        else bid_increment
      end,
      reserve_price = case
        when bids_count = 0 then p_reserve_price
        else reserve_price
      end,
      currency = case when bids_count = 0 then p_currency else currency end,
      lot_type = p_lot_type,
      condition = btrim(coalesce(p_condition, '')),
      edition_label = btrim(coalesce(p_edition_label, '')),
      shipping_notes = btrim(coalesce(p_shipping_notes, '')),
      certificate_id = btrim(coalesce(p_certificate_id, '')),
      status = case
        when bids_count > 0 then status
        when p_starts_at > clock_timestamp() then 'upcoming'
        else 'live'
      end,
      updated_at = clock_timestamp()
  where id = p_auction_id;

  return p_auction_id;
end;
$$;

create or replace function public.cancel_auction(p_auction_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_auction public.auctions%rowtype;
begin
  if v_user_id is null then
    raise exception 'Debes iniciar sesión para cancelar una subasta.';
  end if;

  select * into v_auction
  from public.auctions
  where id = p_auction_id
  for update;

  if not found then
    raise exception 'La subasta no existe.';
  end if;
  if v_auction.seller_profile_id <> v_user_id then
    raise exception 'No tienes permiso para cancelar esta subasta.';
  end if;
  if v_auction.bids_count > 0 then
    raise exception 'No puedes cancelar una subasta que ya recibió pujas.';
  end if;
  if v_auction.status in ('ended', 'cancelled') then
    raise exception 'La subasta ya está cerrada.';
  end if;

  update public.auctions
  set status = 'cancelled',
      settlement_status = 'cancelled',
      updated_at = clock_timestamp()
  where id = p_auction_id;
end;
$$;

create or replace function public.sync_auction_statuses()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_auction public.auctions%rowtype;
  v_reserve_met boolean;
  v_winner_id uuid;
  v_processed integer := 0;
begin
  update public.auctions
  set status = 'live', updated_at = clock_timestamp()
  where status = 'upcoming'
    and starts_at <= clock_timestamp()
    and ends_at > clock_timestamp();

  for v_auction in
    select *
    from public.auctions
    where status in ('upcoming', 'live')
      and ends_at <= clock_timestamp()
    for update skip locked
  loop
    v_reserve_met := v_auction.current_bid is not null
      and (
        v_auction.reserve_price is null
        or v_auction.current_bid >= v_auction.reserve_price
      );
    v_winner_id := case
      when v_reserve_met then v_auction.current_bidder
      else null
    end;

    update public.auctions
    set status = 'ended',
        reserve_met = v_reserve_met,
        winner_id = v_winner_id,
        settlement_status = case
          when v_winner_id is null then 'no_sale'
          else 'awaiting_payment'
        end,
        updated_at = clock_timestamp()
    where id = v_auction.id;

    if v_winner_id is not null then
      insert into public.notifications (
        profile_id, kind, title, body, actor_id, entity_type, entity_id
      ) values (
        v_winner_id,
        'auction_won',
        'Ganaste una subasta',
        'Tu puja por ' || v_auction.lot_title || ' resultó ganadora.',
        v_auction.seller_profile_id,
        'auction',
        v_auction.id
      );
    end if;

    insert into public.notifications (
      profile_id, kind, title, body, actor_id, entity_type, entity_id
    ) values (
      v_auction.seller_profile_id,
      'auction_end',
      'Tu subasta finalizó',
      case
        when v_winner_id is null
          then v_auction.lot_title || ' cerró sin adjudicación.'
        else v_auction.lot_title || ' fue adjudicada.'
      end,
      v_winner_id,
      'auction',
      v_auction.id
    );

    v_processed := v_processed + 1;
  end loop;

  return v_processed;
end;
$$;

-- Policies and least-privilege Data API grants -------------------------------

do $$
declare
  policy_record record;
begin
  for policy_record in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'collections', 'collection_items', 'collection_likes',
        'collection_views', 'auctions', 'auction_bids', 'auction_watchers'
      )
  loop
    execute format(
      'drop policy %I on %I.%I',
      policy_record.policyname,
      policy_record.schemaname,
      policy_record.tablename
    );
  end loop;
end
$$;

create policy collections_read_access
on public.collections for select to anon, authenticated
using (
  is_public or profile_id = (select auth.uid())
);

create policy collections_insert_own
on public.collections for insert to authenticated
with check (
  profile_id = (select auth.uid())
  and pieces_count = 0
  and likes_count = 0
  and views_count = 0
  and not is_featured
  and not is_editorial
);

create policy collections_update_own
on public.collections for update to authenticated
using (profile_id = (select auth.uid()))
with check (profile_id = (select auth.uid()));

create policy collections_delete_own
on public.collections for delete to authenticated
using (profile_id = (select auth.uid()));

create policy collection_items_read_access
on public.collection_items for select to anon, authenticated
using (
  exists (
    select 1 from public.collections c
    where c.id = collection_id
      and (c.is_public or c.profile_id = (select auth.uid()))
  )
);

create policy collection_items_insert_own
on public.collection_items for insert to authenticated
with check (
  added_by = (select auth.uid())
  and exists (
    select 1 from public.collections c
    where c.id = collection_id
      and c.profile_id = (select auth.uid())
  )
  and exists (
    select 1 from public.works w
    where w.id = work_id
      and (w.is_public or w.profile_id = (select auth.uid()))
  )
);

create policy collection_items_update_own
on public.collection_items for update to authenticated
using (
  exists (
    select 1 from public.collections c
    where c.id = collection_id
      and c.profile_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1 from public.collections c
    where c.id = collection_id
      and c.profile_id = (select auth.uid())
  )
);

create policy collection_items_delete_own
on public.collection_items for delete to authenticated
using (
  exists (
    select 1 from public.collections c
    where c.id = collection_id
      and c.profile_id = (select auth.uid())
  )
);

create policy collection_likes_read_own
on public.collection_likes for select to authenticated
using (profile_id = (select auth.uid()));

create policy collection_likes_insert_own
on public.collection_likes for insert to authenticated
with check (
  profile_id = (select auth.uid())
  and exists (
    select 1 from public.collections c
    where c.id = collection_id
      and (c.is_public or c.profile_id = (select auth.uid()))
  )
);

create policy collection_likes_delete_own
on public.collection_likes for delete to authenticated
using (profile_id = (select auth.uid()));

create policy collection_views_read_own
on public.collection_views for select to authenticated
using (profile_id = (select auth.uid()));

create policy collection_views_insert_own
on public.collection_views for insert to authenticated
with check (
  profile_id = (select auth.uid())
  and exists (
    select 1 from public.collections c
    where c.id = collection_id
      and (c.is_public or c.profile_id = (select auth.uid()))
  )
);

create policy auctions_read_all
on public.auctions for select to anon, authenticated
using (true);

create policy auctions_insert_own_work
on public.auctions for insert to authenticated
with check (
  seller_profile_id = (select auth.uid())
  and exists (
    select 1 from public.works w
    where w.id = work_id
      and w.profile_id = (select auth.uid())
      and w.is_public
      and w.status = 'published'
      and w.artist_id is not distinct from auctions.artist_id
  )
  and status = case
    when starts_at > clock_timestamp() then 'upcoming'
    else 'live'
  end
  and ends_at > clock_timestamp()
  and current_bid is null
  and current_bidder is null
  and winner_id is null
  and bids_count = 0
  and watchers_count = 0
  and not reserve_met
  and settlement_status = 'not_started'
  and not is_featured
  and original_ends_at = ends_at
);

create policy auctions_delete_empty_own
on public.auctions for delete to authenticated
using (
  seller_profile_id = (select auth.uid())
  and bids_count = 0
);

create policy auction_bids_read_all
on public.auction_bids for select to anon, authenticated
using (true);

create policy auction_watchers_read_own
on public.auction_watchers for select to authenticated
using (profile_id = (select auth.uid()));

create policy auction_watchers_insert_own
on public.auction_watchers for insert to authenticated
with check (
  profile_id = (select auth.uid())
  and exists (
    select 1 from public.auctions a
    where a.id = auction_id
  )
);

create policy auction_watchers_delete_own
on public.auction_watchers for delete to authenticated
using (profile_id = (select auth.uid()));

revoke all privileges on table public.collections from public, anon, authenticated;
revoke all privileges on table public.collection_items from public, anon, authenticated;
revoke all privileges on table public.collection_likes from public, anon, authenticated;
revoke all privileges on table public.collection_views from public, anon, authenticated;
revoke all privileges on table public.auctions from public, anon, authenticated;
revoke all privileges on table public.auction_bids from public, anon, authenticated;
revoke all privileges on table public.auction_watchers from public, anon, authenticated;

grant select on table public.collections to anon, authenticated;
grant insert (
  profile_id, curator_name, title, description, cover_url, tags,
  is_public, collection_type
) on table public.collections to authenticated;
grant update (
  title, description, cover_url, tags, is_public, collection_type, updated_at
) on table public.collections to authenticated;
grant delete on table public.collections to authenticated;

grant select on table public.collection_items to anon, authenticated;
grant insert (
  collection_id, work_id, position, note, added_by
) on table public.collection_items to authenticated;
grant update (position, note) on table public.collection_items to authenticated;
grant delete on table public.collection_items to authenticated;

grant select, insert, delete on table public.collection_likes to authenticated;
grant select, insert on table public.collection_views to authenticated;

grant select on table public.auctions to anon, authenticated;
grant insert (
  work_id, artist_id, seller_profile_id, artist_name, lot_title, description,
  cover_url, status, starts_at, ends_at, original_ends_at, reserve_price,
  starting_bid, bid_increment, currency, lot_type, condition, edition_label,
  shipping_notes, certificate_id, anti_snipe_minutes, extension_minutes
) on table public.auctions to authenticated;
grant delete on table public.auctions to authenticated;

grant select on table public.auction_bids to anon, authenticated;
grant select, insert, delete on table public.auction_watchers to authenticated;

grant all privileges on table public.collections to service_role;
grant all privileges on table public.collection_items to service_role;
grant all privileges on table public.collection_likes to service_role;
grant all privileges on table public.collection_views to service_role;
grant all privileges on table public.auctions to service_role;
grant all privileges on table public.auction_bids to service_role;
grant all privileges on table public.auction_watchers to service_role;

revoke execute on function public.update_pieces_count() from public, anon, authenticated;
revoke execute on function public.update_collections_count() from public, anon, authenticated;
revoke execute on function public.update_collection_likes_count() from public, anon, authenticated;
revoke execute on function public.update_collection_views_count() from public, anon, authenticated;
revoke execute on function public.update_watchers_count() from public, anon, authenticated;
revoke execute on function public.reorder_collection_items(uuid, uuid[]) from public, anon;
revoke execute on function public.place_auction_bid(uuid, numeric) from public, anon;
revoke execute on function public.update_auction_details(
  uuid, text, text, timestamptz, timestamptz, numeric, numeric, numeric,
  text, text, text, text, text, text
) from public, anon;
revoke execute on function public.cancel_auction(uuid) from public, anon;
revoke execute on function public.sync_auction_statuses() from public, anon;

grant execute on function public.reorder_collection_items(uuid, uuid[])
  to authenticated;
grant execute on function public.place_auction_bid(uuid, numeric)
  to authenticated;
grant execute on function public.update_auction_details(
  uuid, text, text, timestamptz, timestamptz, numeric, numeric, numeric,
  text, text, text, text, text, text
) to authenticated;
grant execute on function public.cancel_auction(uuid) to authenticated;
grant execute on function public.sync_auction_statuses() to authenticated;

do $$
begin
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) and not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'auctions'
  ) then
    alter publication supabase_realtime add table public.auctions;
  end if;
end
$$;

do $$
declare
  existing_job_id bigint;
begin
  select jobid into existing_job_id
  from cron.job
  where jobname = 'corvus-sync-auction-statuses';

  if existing_job_id is not null then
    perform cron.unschedule(existing_job_id);
  end if;

  perform cron.schedule(
    'corvus-sync-auction-statuses',
    '* * * * *',
    'select public.sync_auction_statuses();'
  );
end
$$;
