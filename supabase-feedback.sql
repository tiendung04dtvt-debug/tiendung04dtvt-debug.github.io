-- Create a private inbox for anonymous learner feedback.
-- Run once in Supabase Dashboard > SQL Editor.

create schema if not exists app_private;

create table if not exists app_private.site_feedback (
  id bigint generated always as identity primary key,
  category text not null check (category in ('Lỗi', 'Góp ý')),
  message text not null check (pg_catalog.char_length(message) between 10 and 3000),
  page text,
  created_at timestamptz not null default pg_catalog.now()
);

alter table app_private.site_feedback enable row level security;
revoke all on table app_private.site_feedback from public, anon, authenticated;
revoke all on schema app_private from public, anon, authenticated;

create or replace function public.submit_site_feedback(
  p_category text,
  p_message text,
  p_page text default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  clean_message text := pg_catalog.btrim(coalesce(p_message, ''));
begin
  if p_category is null
     or p_category not in ('Lỗi', 'Góp ý')
     or pg_catalog.char_length(clean_message) < 10
     or pg_catalog.char_length(clean_message) > 3000 then
    return false;
  end if;

  insert into app_private.site_feedback(category, message, page)
  values (p_category, clean_message, pg_catalog.left(coalesce(p_page, ''), 200));

  return true;
end;
$$;

revoke all on function public.submit_site_feedback(text, text, text) from public;
grant execute on function public.submit_site_feedback(text, text, text) to anon, authenticated;
