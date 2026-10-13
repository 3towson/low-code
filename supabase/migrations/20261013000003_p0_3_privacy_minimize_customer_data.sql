-- Migration: 20261013000003_p0_3_privacy_minimize_customer_data.sql
-- วัตถุประสงค์: แก้ไข P0-3 ตามเกณฑ์ Apple App Store Review Guideline 5.1.1(viii)
-- และหลักการ Data Minimization (PDPA):
-- 1) ปลด NOT NULL บนคอลัมน์ cod_reports.customer_name เพื่อเลิกจัดเก็บชื่อจริงของลูกค้าปลายทาง
-- 2) ปรับปรุงฟังก์ชัน admin_get_pending_reports ให้รองรับ customer_name ที่เป็น NULL ได้อย่างราบรื่น

-- 1) ปลด NOT NULL ของ customer_name
alter table public.cod_reports alter column customer_name drop not null;

comment on column public.cod_reports.customer_name is 
  'P0-3: คอลัมน์นี้เป็น nullable เพื่อไม่เก็บชื่อลูกค้าปลายทาง (บันทึกเฉพาะ phone_hash และตรวจสอบผ่านภาพหลักฐานแทน)';

-- 2) อัปเดตฟังก์ชัน admin_get_pending_reports
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
    coalesce(r.customer_name, '') as customer_name,
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
