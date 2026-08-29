-- Corvus Aeternum / Ficha Aeternum publica
-- Apply after the base works schema exists.
-- The app can run without these columns, but applying this migration preserves
-- the complete card generated from Atelier and direct uploads.

alter table public.works
  add column if not exists aeternum_ficha jsonb not null default '{}'::jsonb,
  add column if not exists atelier_project_id uuid references public.atelier_projects(id) on delete set null,
  add column if not exists root_work_id uuid references public.works(id) on delete set null,
  add column if not exists universe text not null default '',
  add column if not exists aeternum_status text not null default '';

create index if not exists works_aeternum_ficha_idx
  on public.works using gin(aeternum_ficha);

create index if not exists works_atelier_project_idx
  on public.works(atelier_project_id);

create index if not exists works_root_work_idx
  on public.works(root_work_id);

create index if not exists works_universe_idx
  on public.works(universe);
