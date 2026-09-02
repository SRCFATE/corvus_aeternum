-- El trigger heredaba el search_path de quien insertara. Al llamarlo desde
-- record_work_view, que fija search_path vacío por seguridad, dejaba de
-- encontrar `works`. Se fija el suyo y se cualifica la tabla.
create or replace function public.update_views_count()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  update public.works
     set views_count = views_count + 1
   where id = new.work_id;

  return new;
end;
$$;
