create table if not exists public.arena_challenges (
  id uuid primary key default gen_random_uuid(),
  creator_profile_id uuid not null,
  title text not null check (char_length(trim(title)) between 3 and 120),
  brief text not null default '' check (char_length(brief) <= 4000),
  format text not null default 'challenge' check (format in ('challenge', 'duel')),
  discipline text not null default 'Multidisciplinario',
  theme text not null default '',
  rules text[] not null default '{}',
  prize_description text not null default '',
  status text not null default 'open' check (status in ('draft', 'open', 'voting', 'closed', 'cancelled')),
  visibility text not null default 'public' check (visibility in ('public', 'private')),
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null,
  voting_ends_at timestamptz,
  max_entries smallint not null default 50 check (max_entries between 2 and 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint arena_challenges_creator_profile_id_fkey
    foreign key (creator_profile_id) references public.profiles(id) on delete cascade,
  constraint arena_challenges_dates_check check (ends_at > starts_at),
  constraint arena_challenges_voting_dates_check check (voting_ends_at is null or voting_ends_at >= ends_at)
);

create table if not exists public.arena_entries (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null,
  profile_id uuid not null,
  work_id uuid,
  title text not null check (char_length(trim(title)) between 1 and 160),
  statement text not null default '' check (char_length(statement) <= 3000),
  media_url text,
  status text not null default 'submitted' check (status in ('submitted', 'withdrawn', 'finalist', 'winner')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint arena_entries_challenge_id_fkey
    foreign key (challenge_id) references public.arena_challenges(id) on delete cascade,
  constraint arena_entries_profile_id_fkey
    foreign key (profile_id) references public.profiles(id) on delete cascade,
  constraint arena_entries_work_id_fkey
    foreign key (work_id) references public.works(id) on delete set null,
  constraint arena_entries_challenge_profile_key unique (challenge_id, profile_id)
);

create table if not exists public.arena_votes (
  entry_id uuid not null,
  voter_profile_id uuid not null,
  weight smallint not null default 1 check (weight = 1),
  created_at timestamptz not null default now(),
  constraint arena_votes_pkey primary key (entry_id, voter_profile_id),
  constraint arena_votes_entry_id_fkey
    foreign key (entry_id) references public.arena_entries(id) on delete cascade,
  constraint arena_votes_voter_profile_id_fkey
    foreign key (voter_profile_id) references public.profiles(id) on delete cascade
);

create index if not exists arena_challenges_status_ends_idx
  on public.arena_challenges (status, ends_at desc);
create index if not exists arena_challenges_creator_idx
  on public.arena_challenges (creator_profile_id, created_at desc);
create index if not exists arena_entries_challenge_idx
  on public.arena_entries (challenge_id, created_at);
create index if not exists arena_entries_profile_idx
  on public.arena_entries (profile_id, created_at desc);
create index if not exists arena_votes_voter_idx
  on public.arena_votes (voter_profile_id, created_at desc);

alter table public.arena_challenges enable row level security;
alter table public.arena_entries enable row level security;
alter table public.arena_votes enable row level security;

drop policy if exists "arena challenges are readable" on public.arena_challenges;
create policy "arena challenges are readable"
  on public.arena_challenges for select
  to authenticated
  using (visibility = 'public' or creator_profile_id = auth.uid());

drop policy if exists "profiles create arena challenges" on public.arena_challenges;
create policy "profiles create arena challenges"
  on public.arena_challenges for insert
  to authenticated
  with check (creator_profile_id = auth.uid());

drop policy if exists "creators update arena challenges" on public.arena_challenges;
create policy "creators update arena challenges"
  on public.arena_challenges for update
  to authenticated
  using (creator_profile_id = auth.uid())
  with check (creator_profile_id = auth.uid());

drop policy if exists "creators delete arena challenges" on public.arena_challenges;
create policy "creators delete arena challenges"
  on public.arena_challenges for delete
  to authenticated
  using (creator_profile_id = auth.uid());

drop policy if exists "arena entries are readable" on public.arena_entries;
create policy "arena entries are readable"
  on public.arena_entries for select
  to authenticated
  using (
    profile_id = auth.uid()
    or exists (
      select 1 from public.arena_challenges challenge
      where challenge.id = challenge_id
        and (challenge.visibility = 'public' or challenge.creator_profile_id = auth.uid())
    )
  );

drop policy if exists "profiles submit arena entries" on public.arena_entries;
create policy "profiles submit arena entries"
  on public.arena_entries for insert
  to authenticated
  with check (
    profile_id = auth.uid()
    and exists (
      select 1 from public.arena_challenges challenge
      where challenge.id = challenge_id
        and challenge.status = 'open'
        and now() between challenge.starts_at and challenge.ends_at
        and (challenge.visibility = 'public' or challenge.creator_profile_id = auth.uid())
        and (select count(*) from public.arena_entries current_entry
             where current_entry.challenge_id = challenge.id
               and current_entry.status <> 'withdrawn') < challenge.max_entries
    )
  );

drop policy if exists "profiles update own arena entries" on public.arena_entries;
create policy "profiles update own arena entries"
  on public.arena_entries for update
  to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

drop policy if exists "profiles delete own arena entries" on public.arena_entries;
create policy "profiles delete own arena entries"
  on public.arena_entries for delete
  to authenticated
  using (profile_id = auth.uid());

drop policy if exists "arena votes are readable" on public.arena_votes;
create policy "arena votes are readable"
  on public.arena_votes for select
  to authenticated
  using (true);

drop policy if exists "profiles cast arena votes" on public.arena_votes;
create policy "profiles cast arena votes"
  on public.arena_votes for insert
  to authenticated
  with check (
    voter_profile_id = auth.uid()
    and exists (
      select 1
      from public.arena_entries entry
      join public.arena_challenges challenge on challenge.id = entry.challenge_id
      where entry.id = entry_id
        and entry.profile_id <> auth.uid()
        and challenge.status in ('open', 'voting')
        and now() >= challenge.starts_at
        and now() <= coalesce(challenge.voting_ends_at, challenge.ends_at)
    )
  );

drop policy if exists "profiles remove own arena votes" on public.arena_votes;
create policy "profiles remove own arena votes"
  on public.arena_votes for delete
  to authenticated
  using (voter_profile_id = auth.uid());

grant select, insert, update, delete on public.arena_challenges to authenticated;
grant select, insert, update, delete on public.arena_entries to authenticated;
grant select, insert, delete on public.arena_votes to authenticated;
