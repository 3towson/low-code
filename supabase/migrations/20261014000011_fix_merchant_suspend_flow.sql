-- Migration ส่วนที่ 16: ปรับปรุงระบบระงับ/ยกเลิกการระงับร้านค้า และสร้าง RPC แสดงรายการร้านค้าตามสถานะ (S1)
-- 1) เพิ่มคอลัมน์ status_before_suspend ในตาราง sellers
-- 2) ปรับปรุง admin_suspend_merchant ให้จำสถานะเดิมไว้ก่อนระงับ
-- 3) ปรับปรุง admin_unsuspend_merchant:
--    - ถ้าเดิมคือ 'approved' ให้คืนกลับเป็น 'approved'
--    - ถ้าเดิมไม่ใช่ 'approved' (เช่น รอ KYC อยู่ หรือ unverified) ให้คืนเป็น 'unverified' ป้องกันการข้ามขั้นตอน KYC
-- 4) สร้าง RPC admin_list_merchants รองรับการกรองสถานะ (pending, suspended, all)

-- 1) เพิ่มคอลัมน์ status_before_suspend
alter table public.sellers add column if not exists status_before_suspend text;

-- 2) ปรับปรุง admin_suspend_merchant
drop function if exists public.admin_suspend_merchant(uuid, text, boolean);

create or replace function public.admin_suspend_merchant(
  p_seller_id uuid,
  p_reason text default 'ละเมิดข้อกำหนดการใช้งาน UGC หรือสร้างรายงานเท็จ',
  p_reject_pending boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := (select auth.uid());
  v_clean_reason text := coalesce(nullif(btrim(p_reason), ''), 'ถูกระงับการใช้งานเนื่องจากละเมิดข้อกำหนด UGC');
  v_rejected_count int := 0;
  v_current_status text;
begin
  if not public.is_admin() then
    raise exception 'UNAUTHORIZED';
  end if;

  select verification_status into v_current_status
  from public.sellers
  where id = p_seller_id;

  if not found then
    raise exception 'SELLER_NOT_FOUND';
  end if;

  update public.sellers
  set
    status_before_suspend = coalesce(nullif(v_current_status, 'suspended'), 'unverified'),
    verification_status = 'suspended',
    rejection_reason = v_clean_reason,
    verified_at = now(),
    verified_by = v_admin
  where id = p_seller_id;

  if p_reject_pending then
    with rejected_rows as (
      update public.cod_reports
      set
        status = 'rejected',
        reviewed_by = v_admin,
        reviewed_at = now(),
        reject_reason = 'ร้านค้าถูกระงับการใช้งาน (Suspended)'
      where reported_by = p_seller_id and status = 'pending'
      returning 1
    )
    select count(*) into v_rejected_count from rejected_rows;
  end if;

  insert into public.admin_audit_logs (admin_id, action, target_type, target_id, details)
  values (
    v_admin,
    'suspend_merchant',
    'seller',
    p_seller_id::text,
    jsonb_build_object(
      'reason', v_clean_reason,
      'status_before_suspend', coalesce(v_current_status, 'unverified'),
      'rejected_pending_reports', v_rejected_count
    )
  );

  return jsonb_build_object(
    'ok', true,
    'status', 'suspended',
    'seller_id', p_seller_id,
    'rejected_pending_reports', v_rejected_count,
    'reason', v_clean_reason
  );
end;
$$;

revoke all on function public.admin_suspend_merchant(uuid, text, boolean) from public, anon;
grant execute on function public.admin_suspend_merchant(uuid, text, boolean) to authenticated, service_role;

-- 3) ปรับปรุง admin_unsuspend_merchant
drop function if exists public.admin_unsuspend_merchant(uuid);

create or replace function public.admin_unsuspend_merchant(
  p_seller_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := (select auth.uid());
  v_status_before text;
  v_new_status text;
begin
  if not public.is_admin() then
    raise exception 'UNAUTHORIZED';
  end if;

  select status_before_suspend into v_status_before
  from public.sellers
  where id = p_seller_id and verification_status = 'suspended';

  if not found then
    if not exists (select 1 from public.sellers where id = p_seller_id) then
      raise exception 'SELLER_NOT_FOUND';
    else
      raise exception 'SELLER_NOT_SUSPENDED';
    end if;
  end if;

  -- คืนสถานะ: ถ้าเดิมเคย approved ให้กลับเป็น approved, ถ้าเดิมไม่ใช่ (เช่น pending/unverified) ให้เป็น unverified เพื่อต้องยื่น KYC ใหม่
  if v_status_before = 'approved' then
    v_new_status := 'approved';
  else
    v_new_status := 'unverified';
  end if;

  update public.sellers
  set
    verification_status = v_new_status,
    rejection_reason = null,
    verified_at = case when v_new_status = 'approved' then now() else null end,
    verified_by = case when v_new_status = 'approved' then v_admin else null end,
    status_before_suspend = null
  where id = p_seller_id and verification_status = 'suspended';

  insert into public.admin_audit_logs (admin_id, action, target_type, target_id, details)
  values (
    v_admin,
    'unsuspend_merchant',
    'seller',
    p_seller_id::text,
    jsonb_build_object(
      'previous_status', 'suspended',
      'restored_status', v_new_status,
      'status_before_suspend', v_status_before
    )
  );

  return jsonb_build_object(
    'ok', true,
    'status', v_new_status,
    'seller_id', p_seller_id
  );
end;
$$;

revoke all on function public.admin_unsuspend_merchant(uuid) from public, anon;
grant execute on function public.admin_unsuspend_merchant(uuid) to authenticated, service_role;

-- 4) สร้าง RPC admin_list_merchants คืนข้อมูลร้านค้าพร้อม verification_status
drop function if exists public.admin_list_merchants(text, int, int);

create or replace function public.admin_list_merchants(
  p_status text default null,
  p_limit int default 50,
  p_offset int default 0
)
returns table (
  id uuid,
  shop_name text,
  shop_url text,
  category text,
  contact_phone text,
  evidence_path text,
  submitted_at timestamptz,
  created_at timestamptz,
  verification_status text,
  rejection_reason text,
  verified_at timestamptz,
  status_before_suspend text
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
    s.id,
    s.shop_name,
    s.shop_url,
    s.category,
    s.contact_phone,
    s.evidence_path,
    s.submitted_at,
    s.created_at,
    s.verification_status,
    s.rejection_reason,
    s.verified_at,
    s.status_before_suspend
  from public.sellers s
  where (p_status is null or p_status = '' or p_status = 'all' or s.verification_status = p_status)
  order by
    case when s.verification_status = 'pending' then 0
         when s.verification_status = 'suspended' then 1
         else 2 end,
    coalesce(s.submitted_at, s.created_at) desc
  limit p_limit
  offset p_offset;
end;
$$;

revoke all on function public.admin_list_merchants(text, int, int) from public, anon;
grant execute on function public.admin_list_merchants(text, int, int) to authenticated, service_role;
