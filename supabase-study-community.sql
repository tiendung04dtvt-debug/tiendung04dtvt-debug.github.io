-- Run once in Supabase SQL Editor to enable the anonymous study community list.
-- Only stable display names and activity timestamps are returned; access_code,
-- device_info, progress payload, email, and IP are never returned by this RPC.

create sequence if not exists app_private.study_presence_name_seq;

alter table app_private.study_progress
  add column if not exists public_name text,
  add column if not exists first_seen_at timestamptz;

-- Give existing rows a stable display name. Their original first-login time is
-- unknown, so first_seen_at intentionally stays NULL for these old rows.
with missing_names as (
  select access_code,
         pg_catalog.nextval('app_private.study_presence_name_seq'::regclass) as serial_no
    from app_private.study_progress
   where public_name is null
)
update app_private.study_progress as progress
   set public_name = 'CNTT.CB-A' || missing_names.serial_no::text
  from missing_names
 where progress.access_code = missing_names.access_code;

alter table app_private.study_progress
  alter column public_name set default
    ('CNTT.CB-A' || pg_catalog.nextval('app_private.study_presence_name_seq'::regclass)::text),
  alter column public_name set not null,
  alter column first_seen_at set default pg_catalog.clock_timestamp();

create unique index if not exists study_progress_public_name_uidx
  on app_private.study_progress (public_name);
create index if not exists study_progress_last_seen_idx
  on app_private.study_progress (last_seen_at desc);

create or replace function public.get_study_presence(p_current_code text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  if p_current_code is not null and p_current_code !~ '^[0-9]{6}$' then
    p_current_code := null;
  end if;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'public_name', public_name,
        'first_seen_at', first_seen_at,
        'last_seen_at', last_seen_at,
        'is_online', coalesce(last_seen_at >= pg_catalog.statement_timestamp() - interval '2 minutes', false),
        'is_current', access_code = p_current_code
      )
      order by
        (last_seen_at >= pg_catalog.statement_timestamp() - interval '2 minutes') desc nulls last,
        last_seen_at desc nulls last,
        public_name
    ),
    '[]'::jsonb
  )
    into result
    from app_private.study_progress;

  return result;
end;
$$;

revoke all on function public.get_study_presence(text) from public;
grant execute on function public.get_study_presence(text) to anon, authenticated;

comment on function public.get_study_presence(text) is
  'Returns pseudonymous study display names, approximate online state, and activity timestamps. Never returns access_code or payload.';
