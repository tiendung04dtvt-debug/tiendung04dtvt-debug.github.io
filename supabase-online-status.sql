-- Run once in Supabase SQL Editor to enable online/offline presence.
-- Presence is approximate: a code is online if a visible page sent a heartbeat
-- within the last two minutes. Device metadata is coarse browser/OS labeling.

alter table app_private.study_progress
  add column if not exists last_seen_at timestamptz,
  add column if not exists device_info text not null default 'Chưa rõ';

create or replace function public.touch_study_seen(p_code text, p_device_info text)
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
     set last_seen_at = pg_catalog.clock_timestamp(),
         device_info = case
           when p_device_info is null or p_device_info = '' then 'Chưa rõ'
           else pg_catalog.left(p_device_info, 80)
         end
   where access_code = p_code
   returning last_seen_at into seen_at;
  return seen_at;
end;
$$;

revoke all on function public.touch_study_seen(text, text) from public;
grant execute on function public.touch_study_seen(text, text) to anon, authenticated;

create or replace view app_private.study_presence as
select
  access_code,
  case
    when last_seen_at >= pg_catalog.clock_timestamp() - interval '2 minutes'
      then 'Đang online'
    else 'Offline'
  end as status,
  device_info,
  last_seen_at,
  updated_at
from app_private.study_progress;

revoke all on app_private.study_presence from public, anon, authenticated;

comment on view app_private.study_presence is
  'Admin view: approximate online status, coarse device label, and latest heartbeat by study code.';
