-- Migration: P1 Fixes - KYC Input Validation, Auto-link trigger removal, Admin checks
-- 1) ลบ trigger auto_link_recent_evidence ตาม P1-4 (Edge Function บังคับแนบ path แล้ว ป้องกันการผูกรูปผิดรายงาน)
drop trigger if exists trg_auto_link_recent_evidence on public.cod_reports;
drop function if exists public.auto_link_recent_evidence();

-- 2) อัปเดต submit_merchant_kyc พร้อม Input Validation เข้มงวด และห้ามยื่นใหม่ตอน approved (P1-3)
create or replace function public.submit_merchant_kyc(
  p_shop_url text,
  p_category text,
  p_contact_phone text,
  p_evidence_paths text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_current_status text;
  v_url text := btrim(coalesce(p_shop_url, ''));
  v_category text := btrim(coalesce(p_category, ''));
  v_phone text := btrim(coalesce(p_contact_phone, ''));
  v_paths text := btrim(coalesce(p_evidence_paths, ''));
  v_path_array text[];
  v_p text;
begin
  if v_uid is null then
    raise exception 'UNAUTHORIZED';
  end if;

  select verification_status into v_current_status
  from public.sellers
  where id = v_uid;

  if not found then
    raise exception 'SELLER_NOT_FOUND';
  end if;

  -- P1-3: ห้ามยื่นใหม่ตอน approved หรือ pending หรือ suspended
  if v_current_status = 'approved' then
    raise exception 'ALREADY_APPROVED';
  end if;
  if v_current_status = 'suspended' then
    raise exception 'MERCHANT_SUSPENDED';
  end if;
  if v_current_status = 'pending' then
    raise exception 'ALREADY_PENDING';
  end if;

  -- 1) Validate shop_url: ไม่ว่าง, <= 300 ตัวอักษร, ขึ้นต้นด้วย http:// หรือ https://
  if length(v_url) = 0 or length(v_url) > 300 or not (v_url ~* '^https?://') then
    raise exception 'INVALID_SHOP_URL';
  end if;

  -- 2) Validate category: อยู่ในหมวดหมู่ที่กำหนด
  if v_category not in (
    'เสื้อผ้าและแฟชั่น',
    'เครื่องสำอางและความงาม',
    'อิเล็กทรอนิกส์และอุปกรณ์เสริม',
    'อาหาร ขนม และเครื่องดื่ม',
    'ของใช้ในบ้านและตกแต่ง',
    'สินค้าแม่และเด็ก',
    'สุขภาพและอาหารเสริม',
    'สินค้าอื่นๆ'
  ) then
    raise exception 'INVALID_CATEGORY';
  end if;

  -- 3) Validate contact_phone: ตรงตามรูปแบบเบอร์โทรไทย ^0[0-9]{8,9}$
  if not (v_phone ~ '^0[0-9]{8,9}$') then
    raise exception 'INVALID_PHONE';
  end if;

  -- 4) Validate evidence_paths: 1–3 path ทุก path ขึ้นต้นด้วย {auth.uid()}/
  if length(v_paths) = 0 then
    raise exception 'NO_EVIDENCE';
  end if;

  v_path_array := string_to_array(v_paths, ',');
  if array_length(v_path_array, 1) is null or array_length(v_path_array, 1) < 1 or array_length(v_path_array, 1) > 3 then
    raise exception 'INVALID_EVIDENCE_COUNT';
  end if;

  foreach v_p in array v_path_array loop
    v_p := btrim(v_p);
    if length(v_p) = 0 or length(v_p) > 255 or not (v_p like (v_uid::text || '/%')) then
      raise exception 'INVALID_EVIDENCE_PATH';
    end if;
  end loop;

  update public.sellers
  set
    shop_url = v_url,
    category = v_category,
    contact_phone = v_phone,
    evidence_path = v_paths,
    verification_status = 'pending',
    rejection_reason = null,
    submitted_at = now()
  where id = v_uid;

  return jsonb_build_object('ok', true, 'status', 'pending');
end;
$$;

revoke all on function public.submit_merchant_kyc(text, text, text, text) from public, anon;
grant execute on function public.submit_merchant_kyc(text, text, text, text) to authenticated, service_role;

-- 3) อัปเดต admin_approve_merchant และ admin_reject_merchant ให้อนุมัติ/ปฏิเสธเฉพาะแถวที่เป็น pending (P1-3)
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

  return jsonb_build_object('ok', true, 'status', 'approved');
end;
$$;

revoke all on function public.admin_approve_merchant(uuid) from public, anon;
grant execute on function public.admin_approve_merchant(uuid) to authenticated, service_role;

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
begin
  if not public.is_admin() then
    raise exception 'UNAUTHORIZED';
  end if;

  update public.sellers
  set
    verification_status = 'rejected',
    rejection_reason = coalesce(nullif(btrim(p_reason), ''), 'หลักฐานไม่ผ่านเกณฑ์การตรวจสอบ'),
    verified_at = now(),
    verified_by = v_admin
  where id = p_seller_id
    and verification_status = 'pending';

  if not found then
    raise exception 'SELLER_NOT_FOUND_OR_NOT_PENDING';
  end if;

  return jsonb_build_object('ok', true, 'status', 'rejected');
end;
$$;

revoke all on function public.admin_reject_merchant(uuid, text) from public, anon;
grant execute on function public.admin_reject_merchant(uuid, text) to authenticated, service_role;
