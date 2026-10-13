-- Migration ส่วนที่ 14: แก้ไขข้อบกพร่อง R1 จาก STORE_READINESS_REVIEW_v3
-- 1) ลบ Overload เดิมของ admin_suspend_merchant เพื่อแก้ปัญหา PGRST203 (Function Overload Ambiguity)
-- 2) สร้าง admin_suspend_merchant ใหม่:
--    - เปลี่ยนคอลัมน์ review_notes เป็น reject_reason ใน cod_reports
--    - บันทึก admin_audit_logs (action 'suspend_merchant', บันทึกจำนวน rejected_pending_reports)
-- 3) ปรับปรุง admin_unsuspend_merchant:
--    - ตรวจสอบ verification_status = 'suspended' ป้องกันร้านค้าข้ามขั้นตอน KYC
--    - บันทึก admin_audit_logs (action 'unsuspend_merchant')

-- 1 & 2) admin_suspend_merchant
drop function if exists public.admin_suspend_merchant(uuid, text);
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
begin
  if not public.is_admin() then
    raise exception 'UNAUTHORIZED';
  end if;

  update public.sellers
  set
    verification_status = 'suspended',
    rejection_reason = v_clean_reason,
    verified_at = now(),
    verified_by = v_admin
  where id = p_seller_id;

  if not found then
    raise exception 'SELLER_NOT_FOUND';
  end if;

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

-- 3) admin_unsuspend_merchant
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
begin
  if not public.is_admin() then
    raise exception 'UNAUTHORIZED';
  end if;

  update public.sellers
  set
    verification_status = 'approved',
    rejection_reason = null,
    verified_at = now(),
    verified_by = v_admin
  where id = p_seller_id and verification_status = 'suspended';

  if not found then
    if not exists (select 1 from public.sellers where id = p_seller_id) then
      raise exception 'SELLER_NOT_FOUND';
    else
      raise exception 'SELLER_NOT_SUSPENDED';
    end if;
  end if;

  insert into public.admin_audit_logs (admin_id, action, target_type, target_id, details)
  values (
    v_admin,
    'unsuspend_merchant',
    'seller',
    p_seller_id::text,
    jsonb_build_object(
      'previous_status', 'suspended',
      'new_status', 'approved'
    )
  );

  return jsonb_build_object(
    'ok', true,
    'status', 'approved',
    'seller_id', p_seller_id
  );
end;
$$;

revoke all on function public.admin_unsuspend_merchant(uuid) from public, anon;
grant execute on function public.admin_unsuspend_merchant(uuid) to authenticated, service_role;
