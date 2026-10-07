-- ส่วนที่ 7: ระบบ Admin Role, หลักฐานการรายงาน (evidence_path), Storage Bucket และการ Approve/Reject

-- 1) ปรับปรุงตาราง cod_reports ให้รองรับสถานะ pending/rejected และเก็บหลักฐาน
alter table public.cod_reports
  drop constraint if exists cod_reports_status_check;

alter table public.cod_reports
  add constraint cod_reports_status_check
  check (status in ('pending', 'active', 'rejected', 'disputed', 'resolved'));

alter table public.cod_reports
  alter column status set default 'pending';

alter table public.cod_reports
  add column if not exists evidence_path text null,
  add column if not exists reviewed_by uuid references auth.users (id) null,
  add column if not exists reviewed_at timestamptz null,
  add column if not exists reject_reason text null;

create index if not exists cod_reports_pending_idx
  on public.cod_reports (status, created_at)
  where status = 'pending';

-- 2) ตาราง admin_users และฟังก์ชัน is_admin()
create table if not exists public.admin_users (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique not null references auth.users (id) on delete cascade,
  role text not null default 'admin',
  created_at timestamptz not null default now()
);

alter table public.admin_users enable row level security;

create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.admin_users where user_id = (select auth.uid())
  ) or coalesce((select auth.jwt() -> 'app_metadata' ->> 'role'), '') = 'admin';
$$;

revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated, service_role;

drop policy if exists admin_users_read on public.admin_users;
create policy admin_users_read
  on public.admin_users
  for select
  to authenticated
  using (public.is_admin());

-- 3) Supabase Storage Bucket 'report-evidences' (Private)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'report-evidences',
  'report-evidences',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update set
  public = false,
  file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']::text[];

drop policy if exists evidence_upload_authenticated on storage.objects;
create policy evidence_upload_authenticated
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'report-evidences'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists evidence_read_owner_or_admin on storage.objects;
create policy evidence_read_owner_or_admin
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'report-evidences'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or public.is_admin()
    )
  );

-- 4) RPC Functions สำหรับ Admin Backoffice
create or replace function public.admin_get_pending_reports(
  p_limit int default 50,
  p_offset int default 0
)
returns table (
  id uuid,
  customer_name text,
  platform text,
  reason text,
  amount numeric,
  other_details text,
  evidence_path text,
  shop_name text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'UNAUTHORIZED';
  end if;

  return query
  select
    r.id,
    r.customer_name,
    r.platform,
    r.reason,
    r.amount,
    r.other_details,
    r.evidence_path,
    s.shop_name,
    r.created_at
  from public.cod_reports r
  join public.sellers s on s.id = r.reported_by
  where r.status = 'pending'
  order by r.created_at asc
  limit p_limit
  offset p_offset;
end;
$$;

revoke all on function public.admin_get_pending_reports(int, int) from public, anon;
grant execute on function public.admin_get_pending_reports(int, int) to authenticated, service_role;

create or replace function public.admin_get_stats()
returns table (
  pending_count bigint,
  approved_today bigint,
  rejected_today bigint
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'UNAUTHORIZED';
  end if;

  return query
  select
    count(*) filter (where status = 'pending') as pending_count,
    count(*) filter (where status = 'active' and reviewed_at >= date_trunc('day', now())) as approved_today,
    count(*) filter (where status = 'rejected' and reviewed_at >= date_trunc('day', now())) as rejected_today
  from public.cod_reports;
end;
$$;

revoke all on function public.admin_get_stats() from public, anon;
grant execute on function public.admin_get_stats() to authenticated, service_role;

create or replace function public.admin_review_report(
  p_report_id uuid,
  p_action text,
  p_reason text default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_new_status text;
begin
  if not public.is_admin() then
    raise exception 'UNAUTHORIZED';
  end if;

  if p_action = 'approve' then
    v_new_status := 'active';
  elsif p_action = 'reject' then
    v_new_status := 'rejected';
  else
    raise exception 'INVALID_ACTION';
  end if;

  update public.cod_reports
  set
    status = v_new_status,
    reviewed_by = (select auth.uid()),
    reviewed_at = now(),
    reject_reason = case when p_action = 'reject' then p_reason else null end
  where id = p_report_id and status = 'pending';

  return found;
end;
$$;

revoke all on function public.admin_review_report(uuid, text, text) from public, anon;
grant execute on function public.admin_review_report(uuid, text, text) to authenticated, service_role;
