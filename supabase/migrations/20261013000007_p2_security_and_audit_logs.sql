-- Migration ส่วนที่ 12: ปรับปรุงความปลอดภัยตาราง sellers และระบบ Admin Audit Logging (P2)

-- 1) จำกัดสิทธิ์ตาราง sellers: revoke insert, update, delete จาก authenticated (P2 Security)
-- ให้ authenticated สามารถ select ได้เท่านั้นผ่าน RLS การเปลี่ยนแปลงข้อมูลทำผ่าน Security Definer RPCs หรือ handle_new_user trigger
revoke insert, update, delete on table public.sellers from authenticated;

-- 2) สร้างตาราง Admin Audit Logs สำหรับบันทึกประวัติการกระทำของผู้ดูแลระบบ
create table if not exists public.admin_audit_logs (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid references auth.users(id) on delete set null,
  action text not null,
  target_type text not null,
  target_id text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- ดัชนีค้นหาตามลำดับเวลา และตามเป้าหมาย (target_type, target_id)
create index if not exists idx_admin_audit_logs_created_at
  on public.admin_audit_logs (created_at desc);

create index if not exists idx_admin_audit_logs_target
  on public.admin_audit_logs (target_type, target_id);

-- เปิดใช้ RLS
alter table public.admin_audit_logs enable row level security;

-- Policy: ผู้ดูแลระบบเท่านั้นที่สามารถอ่านบันทึก Audit Logs ได้
drop policy if exists "Admins can view audit logs" on public.admin_audit_logs;
create policy "Admins can view audit logs"
  on public.admin_audit_logs
  for select
  to authenticated
  using (public.is_admin());

-- ป้องกัน client ไม่ให้ insert/update/delete ตาราง audit log โดยตรง
revoke insert, update, delete on table public.admin_audit_logs from public, anon, authenticated;
grant select on table public.admin_audit_logs to authenticated;
grant all on table public.admin_audit_logs to service_role;

-- 3) อัปเดต admin_review_report ให้บันทึก Audit Log เมื่ออนุมัติหรือปฏิเสธรายงาน
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
  v_admin uuid := (select auth.uid());
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
    reviewed_by = v_admin,
    reviewed_at = now(),
    reject_reason = case when p_action = 'reject' then p_reason else null end
  where id = p_report_id and status = 'pending';

  if found then
    insert into public.admin_audit_logs (admin_id, action, target_type, target_id, details)
    values (
      v_admin,
      case when p_action = 'approve' then 'approve_report' else 'reject_report' end,
      'cod_report',
      p_report_id::text,
      jsonb_build_object(
        'action', p_action,
        'reason', p_reason,
        'new_status', v_new_status
      )
    );
    return true;
  end if;

  return false;
end;
$$;

revoke all on function public.admin_review_report(uuid, text, text) from public, anon;
grant execute on function public.admin_review_report(uuid, text, text) to authenticated, service_role;

-- 4) อัปเดต admin_approve_merchant ให้บันทึก Audit Log เมื่ออนุมัติ KYC ร้านค้า
create or replace function public.admin_approve_merchant(
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
    verified_at = now(),
    verified_by = v_admin,
    rejection_reason = null
  where id = p_seller_id
    and verification_status = 'pending';

  if not found then
    raise exception 'SELLER_NOT_FOUND_OR_NOT_PENDING';
  end if;

  insert into public.admin_audit_logs (admin_id, action, target_type, target_id, details)
  values (
    v_admin,
    'approve_merchant',
    'seller',
    p_seller_id::text,
    jsonb_build_object('action', 'approve_merchant')
  );

  return jsonb_build_object('ok', true, 'status', 'approved');
end;
$$;

revoke all on function public.admin_approve_merchant(uuid) from public, anon;
grant execute on function public.admin_approve_merchant(uuid) to authenticated, service_role;

-- 5) อัปเดต admin_reject_merchant ให้บันทึก Audit Log เมื่อปฏิเสธ KYC ร้านค้า
create or replace function public.admin_reject_merchant(
  p_seller_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := (select auth.uid());
  v_clean_reason text := coalesce(nullif(btrim(p_reason), ''), 'หลักฐานไม่ผ่านเกณฑ์การตรวจสอบ');
begin
  if not public.is_admin() then
    raise exception 'UNAUTHORIZED';
  end if;

  update public.sellers
  set
    verification_status = 'rejected',
    rejection_reason = v_clean_reason,
    verified_at = now(),
    verified_by = v_admin
  where id = p_seller_id
    and verification_status = 'pending';

  if not found then
    raise exception 'SELLER_NOT_FOUND_OR_NOT_PENDING';
  end if;

  insert into public.admin_audit_logs (admin_id, action, target_type, target_id, details)
  values (
    v_admin,
    'reject_merchant',
    'seller',
    p_seller_id::text,
    jsonb_build_object('reason', v_clean_reason)
  );

  return jsonb_build_object('ok', true, 'status', 'rejected', 'reason', v_clean_reason);
end;
$$;

revoke all on function public.admin_reject_merchant(uuid, text) from public, anon;
grant execute on function public.admin_reject_merchant(uuid, text) to authenticated, service_role;

-- 6) อัปเดต admin_suspend_merchant ให้บันทึก Audit Log เมื่อระงับร้านค้า
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
  v_clean_reason text := coalesce(nullif(btrim(p_reason), ''), 'ถูกระงับการใช้งานเนื่องจากละเมิดข้อกำหนด UGC');
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

  insert into public.admin_audit_logs (admin_id, action, target_type, target_id, details)
  values (
    v_admin,
    'suspend_merchant',
    'seller',
    p_seller_id::text,
    jsonb_build_object('reason', v_clean_reason)
  );

  return jsonb_build_object(
    'ok', true,
    'status', 'suspended',
    'seller_id', p_seller_id,
    'reason', v_clean_reason
  );
end;
$$;

revoke all on function public.admin_suspend_merchant(uuid, text) from public, anon;
grant execute on function public.admin_suspend_merchant(uuid, text) to authenticated, service_role;

-- 7) RPC Function: admin_get_audit_logs สำหรับดึงประวัติการทำงานของแอดมิน
create or replace function public.admin_get_audit_logs(
  p_limit int default 50,
  p_offset int default 0
)
returns table (
  id uuid,
  admin_id uuid,
  action text,
  target_type text,
  target_id text,
  details jsonb,
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
    a.id,
    a.admin_id,
    a.action,
    a.target_type,
    a.target_id,
    a.details,
    a.created_at
  from public.admin_audit_logs a
  order by a.created_at desc
  limit least(greatest(p_limit, 1), 100)
  offset greatest(p_offset, 0);
end;
$$;

revoke all on function public.admin_get_audit_logs(int, int) from public, anon;
grant execute on function public.admin_get_audit_logs(int, int) to authenticated, service_role;
