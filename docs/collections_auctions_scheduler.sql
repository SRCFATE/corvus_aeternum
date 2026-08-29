-- Follow-up for databases that already applied collections_auctions_schema.sql
-- before automatic auction scheduling was enabled.

create extension if not exists pg_cron with schema pg_catalog;

create unique index if not exists auctions_one_active_work_idx
  on public.auctions(work_id)
  where work_id is not null and status in ('upcoming', 'live');

drop policy if exists auctions_insert_own_work on public.auctions;
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

revoke execute on function public.sync_auction_statuses() from public, anon;
grant execute on function public.sync_auction_statuses() to authenticated;

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
