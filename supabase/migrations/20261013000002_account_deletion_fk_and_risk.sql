-- ส่วนที่ 9: รองรับการลบบัญชีผู้ใช้ (Account Deletion) ตามเกณฑ์ App Store / Google Play
-- ปรับ Foreign Key ให้เป็น on delete set null และปรับ get_risk_level ให้รองรับรายงานไร้เจ้าของ

-- 1) ปรับ foreign key ของ cod_reports.reported_by เป็น nullable และ on delete set null
alter table public.cod_reports
  drop constraint if exists cod_reports_reported_by_fkey;

alter table public.cod_reports
  alter column reported_by drop not null;

alter table public.cod_reports
  add constraint cod_reports_reported_by_fkey
  foreign key (reported_by)
  references public.sellers (id)
  on delete set null;

-- 2) ปรับ foreign key ของ cod_reports.reviewed_by เป็น on delete set null
alter table public.cod_reports
  drop constraint if exists cod_reports_reviewed_by_fkey;

alter table public.cod_reports
  add constraint cod_reports_reviewed_by_fkey
  foreign key (reviewed_by)
  references auth.users (id)
  on delete set null;

-- 3) ปรับ foreign key ของ sellers.verified_by เป็น on delete set null
alter table public.sellers
  drop constraint if exists sellers_verified_by_fkey;

alter table public.sellers
  add constraint sellers_verified_by_fkey
  foreign key (verified_by)
  references auth.users (id)
  on delete set null;

-- 4) ปรับปรุงฟังก์ชัน get_risk_level:
--    ใช้ left join กับ sellers เพื่อไม่ให้รายงานที่ไม่มีเจ้าของ (reported_by is null) หลุดจากการคำนวณ
--    รายงานที่ไม่มีเจ้าของจะไม่เข้าเกณฑ์แดง (is_red = false) แต่นับรวมใน counted_reports และจัดเป็นระดับ yellow
create or replace function public.get_risk_level(p_phone_hash text)
returns table (level text, counted_reports int, last_report_at timestamptz)
language sql
stable
set search_path = ''
as $$
  with counted as (
    select
      r.reported_by,
      r.created_at,
      (
        r.created_at >= now() - interval '90 days'
        and s.created_at is not null
        and r.created_at - s.created_at >= interval '7 days'
      ) as is_red
    from public.cod_reports r
    left join public.sellers s on s.id = r.reported_by
    where r.phone_hash = p_phone_hash
      and r.status = 'active'
      and r.created_at >= now() - interval '12 months'
  )
  select
    case
      when count(distinct c.reported_by) filter (where c.is_red and c.reported_by is not null) >= 2 then 'red'
      when count(*) >= 1 then 'yellow'
      else 'green'
    end,
    count(*)::int,
    max(c.created_at)
  from counted c;
$$;

revoke all on function public.get_risk_level(text) from public, anon, authenticated;
grant execute on function public.get_risk_level(text) to service_role;

-- 5) ปรับปรุงฟังก์ชัน admin_get_pending_reports ให้ใช้ left join ป้องกันกรณีร้านค้าลบบัญชีก่อนแอดมินตรวจ
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
    coalesce(s.shop_name, 'บัญชีถูกลบแล้ว') as shop_name,
    r.created_at
  from public.cod_reports r
  left join public.sellers s on s.id = r.reported_by
  where r.status = 'pending'
  order by r.created_at asc
  limit p_limit
  offset p_offset;
end;
$$;

revoke all on function public.admin_get_pending_reports(int, int) from public, anon;
grant execute on function public.admin_get_pending_reports(int, int) to authenticated, service_role;
