-- Run this once in Supabase SQL Editor.
-- Adds a separate last-reported tab state; the existing `status` column remains unchanged.
alter table app_private.study_progress
  add column if not exists tab_visibility text not null default 'Chưa rõ';

drop view if exists app_private.study_presence;
drop function if exists public.touch_study_seen(text, text, text, text);
alter table app_private.study_progress drop column if exists activity_status;

create or replace function public.touch_study_seen(
  p_code text,
  p_device_info text,
  p_tab_visibility text
)
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
         end,
         tab_visibility = case
           when p_tab_visibility in ('Đang xem', 'Mở nền') then p_tab_visibility
           else 'Chưa rõ'
         end
   where access_code = p_code
   returning last_seen_at into seen_at;
  return seen_at;
end;
$$;

revoke all on function public.touch_study_seen(text, text, text) from public;
grant execute on function public.touch_study_seen(text, text, text) to anon, authenticated;

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
  updated_at,
  tab_visibility
from app_private.study_progress;

revoke all on app_private.study_presence from public, anon, authenticated;
