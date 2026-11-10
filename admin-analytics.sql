-- Chạy đoạn này trong Supabase Dashboard > SQL Editor để kích hoạt tính năng lấy báo cáo phân tích tự động
create or replace function public.get_all_study_progress()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  return (
    select pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'access_code', access_code,
        'updated_at', updated_at,
        'last_seen_at', last_seen_at,
        'device_info', device_info,
        'payload', payload
      ) order by updated_at desc
    )
    from app_private.study_progress
  );
end;
$$;

revoke all on function public.get_all_study_progress() from public;
grant execute on function public.get_all_study_progress() to anon, authenticated;
