-- Run once in the existing Supabase project to record recent activity by sync code.
alter table app_private.study_progress
  add column last_seen_at timestamptz;

create or replace function public.touch_study_seen(p_code text)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  seen_at timestamptz;
begin
  if p_code is null or p_code !~ '^[0-9]{6}$' then return null; end if;
  update app_private.study_progress
     set last_seen_at = pg_catalog.clock_timestamp()
   where access_code = p_code
   returning last_seen_at into seen_at;
  return seen_at;
end;
$$;

revoke all on function public.touch_study_seen(text) from public;
grant execute on function public.touch_study_seen(text) to anon, authenticated;
