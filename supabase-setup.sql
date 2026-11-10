-- Paste this once into Supabase Dashboard > SQL Editor and run it.
-- The six-digit code is a simple access code for low-sensitivity study progress.

create schema if not exists app_private;
revoke all on schema app_private from public, anon, authenticated;
grant usage on schema public to anon, authenticated;

create table if not exists app_private.study_progress (
  access_code text primary key check (access_code ~ '^[0-9]{6}$'),
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default pg_catalog.now(),
  last_seen_at timestamptz,
  device_info text not null default 'Chưa rõ'
);
alter table app_private.study_progress add column if not exists last_seen_at timestamptz;
alter table app_private.study_progress add column if not exists device_info text not null default 'Chưa rõ';
alter table app_private.study_progress add column if not exists tab_visibility text not null default 'Chưa rõ';
alter table app_private.study_progress enable row level security;
revoke all on table app_private.study_progress from public, anon, authenticated;

create or replace function public.create_study_code()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  candidate text;
begin
  for attempt in 1..100 loop
    candidate := pg_catalog.lpad((pg_catalog.floor(pg_catalog.random() * 1000000))::bigint::text, 6, '0');
    insert into app_private.study_progress(access_code, payload)
      values (candidate, '{}'::jsonb)
      on conflict (access_code) do nothing;
    if found then
      return candidate;
    end if;
  end loop;
  raise exception 'Could not allocate a unique study code';
end;
$$;

create or replace function public.get_study_data(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  if p_code is null or p_code !~ '^[0-9]{6}$' then return null; end if;
  select pg_catalog.jsonb_build_object('payload', payload, 'updated_at', updated_at)
    into result
    from app_private.study_progress
    where access_code = p_code;
  return result;
end;
$$;

create or replace function public.save_study_data(p_code text, p_payload jsonb)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_code is null or p_code !~ '^[0-9]{6}$' or p_payload is null
     or pg_catalog.jsonb_typeof(p_payload) <> 'object'
     or pg_catalog.octet_length(p_payload::text) > 500000 then
    return false;
  end if;
  update app_private.study_progress
     set payload = p_payload, updated_at = pg_catalog.clock_timestamp()
   where access_code = p_code;
  return found;
end;
$$;

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

revoke all on function public.create_study_code() from public;
revoke all on function public.get_study_data(text) from public;
revoke all on function public.save_study_data(text, jsonb) from public;
revoke all on function public.touch_study_seen(text) from public;
grant execute on function public.create_study_code() to anon, authenticated;
grant execute on function public.get_study_data(text) to anon, authenticated;
grant execute on function public.save_study_data(text, jsonb) to anon, authenticated;
grant execute on function public.touch_study_seen(text) to anon, authenticated;

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

create or replace function public.touch_study_seen(p_code text, p_device_info text, p_tab_visibility text)
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
