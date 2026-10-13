-- Migration ส่วนที่ 9: รองรับข้อกำหนด UGC และการระงับร้านค้าที่กระทำผิด (Apple 1.2 / Google Play UGC - P0-4)

-- 1) ขยาย constraint สถานะร้านค้า ให้รองรับ 'suspended'
alter table public.sellers
  drop constraint if exists sellers_verification_status_check;

alter table public.sellers
  add constraint sellers_verification_status_check
  check (verification_status in ('unverified', 'pending', 'approved', 'rejected', 'suspended'));

-- 2) RPC Function: Admin ระงับสิทธิ์ร้านค้า (Suspend Merchant)
create or replace function public.admin_suspend_merchant(
  p_seller_id uuid,
  p_reason text default 'ละเมิดข้อกำหนดการใช้งาน UGC หรือสร้างรายงานเท็จ'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := (select auth.uid());
begin
  if not public.is_admin() then
    raise exception 'UNAUTHORIZED';
  end if;

  update public.sellers
  set
    verification_status = 'suspended',
    rejection_reason = coalesce(nullif(btrim(p_reason), ''), 'ถูกระงับการใช้งานเนื่องจากละเมิดข้อกำหนด UGC'),
    verified_at = now(),
    verified_by = v_admin
  where id = p_seller_id;

  if not found then
    raise exception 'SELLER_NOT_FOUND';
  end if;

  return jsonb_build_object(
    'ok', true,
    'status', 'suspended',
    'seller_id', p_seller_id,
    'reason', coalesce(nullif(btrim(p_reason), ''), 'ถูกระงับการใช้งานเนื่องจากละเมิดข้อกำหนด UGC')
  );
end;
$$;

revoke all on function public.admin_suspend_merchant(uuid, text) from public, anon;
grant execute on function public.admin_suspend_merchant(uuid, text) to authenticated, service_role;

-- 3) อัปเดต admin_get_pending_reports ให้คืน seller_id (reported_by) เพื่อให้แอดมินสามารถระงับร้านค้าที่รายงานเท็จได้ทันที
drop function if exists public.admin_get_pending_reports(int, int);

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
  created_at timestamptz,
  seller_id uuid
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
    r.created_at,
    r.reported_by as seller_id
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
