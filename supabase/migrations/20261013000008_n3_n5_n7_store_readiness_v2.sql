-- Migration ส่วนที่ 13: แก้ไขช่องโหว่และความพร้อมสำหรับ Store Readiness Review v2 (N3, N5, N7)
-- 1) [N3] ปิดสิทธิ์ไม่ให้ผู้ใช้ทั่วไป (authenticated) เรียก hit_rate_limit ได้เอง ป้องกันการโจมตี Denial-of-Service / Block ผู้ใช้อื่น
revoke execute on function public.hit_rate_limit(text, int, int) from authenticated;
grant execute on function public.hit_rate_limit(text, int, int) to service_role;

-- 2) [N5] Data Minimization (PDPA): เคลียร์ customer_name เดิมที่ค้างอยู่ใน cod_reports ให้เป็น NULL
update public.cod_reports set customer_name = null where customer_name is not null;

-- 3) [N7] RPC Function: ยกเลิกการระงับร้านค้า (Unsuspend Merchant)
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
  where id = p_seller_id;

  if not found then
    raise exception 'SELLER_NOT_FOUND';
  end if;

  return jsonb_build_object(
    'ok', true,
    'status', 'approved',
    'seller_id', p_seller_id
  );
end;
$$;

revoke all on function public.admin_unsuspend_merchant(uuid) from public, anon;
grant execute on function public.admin_unsuspend_merchant(uuid) to authenticated, service_role;

-- 4) [N7] ปรับปรุง admin_suspend_merchant ให้ปฏิเสธ (reject) รายงานที่รอตรวจ (pending) ของร้านที่ถูกระงับโดยอัตโนมัติ
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
  v_rejected_count int := 0;
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

  if p_reject_pending then
    with rejected_rows as (
      update public.cod_reports
      set
        status = 'rejected',
        reviewed_by = v_admin,
        reviewed_at = now(),
        review_notes = 'ร้านค้าถูกระงับการใช้งาน (Suspended)'
      where reported_by = p_seller_id and status = 'pending'
      returning 1
    )
    select count(*) into v_rejected_count from rejected_rows;
  end if;

  return jsonb_build_object(
    'ok', true,
    'status', 'suspended',
    'seller_id', p_seller_id,
    'rejected_pending_reports', v_rejected_count,
    'reason', coalesce(nullif(btrim(p_reason), ''), 'ถูกระงับการใช้งานเนื่องจากละเมิดข้อกำหนด UGC')
  );
end;
$$;

revoke all on function public.admin_suspend_merchant(uuid, text, boolean) from public, anon;
grant execute on function public.admin_suspend_merchant(uuid, text, boolean) to authenticated, service_role;

-- 5) [N8] ปรับปรุง submit_merchant_kyc ให้ตรวจสอบการมีอยู่ของไฟล์ใน storage.objects และป้องกัน path traversal (..)
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

  if v_current_status = 'approved' then
    raise exception 'ALREADY_APPROVED';
  end if;
  if v_current_status = 'suspended' then
    raise exception 'MERCHANT_SUSPENDED';
  end if;
  if v_current_status = 'pending' then
    raise exception 'ALREADY_PENDING';
  end if;

  -- 1) Validate shop_url
  if length(v_url) = 0 or length(v_url) > 300 or not (v_url ~* '^https?://') then
    raise exception 'INVALID_SHOP_URL';
  end if;

  -- 2) Validate category
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

  -- 3) Validate contact_phone
  if not (v_phone ~ '^0[0-9]{8,9}$') then
    raise exception 'INVALID_PHONE';
  end if;

  -- 4) Validate evidence_paths
  if length(v_paths) = 0 then
    raise exception 'NO_EVIDENCE';
  end if;

  v_path_array := string_to_array(v_paths, ',');
  if array_length(v_path_array, 1) is null or array_length(v_path_array, 1) < 1 or array_length(v_path_array, 1) > 3 then
    raise exception 'INVALID_EVIDENCE_COUNT';
  end if;

  foreach v_p in array v_path_array loop
    v_p := btrim(v_p);
    -- N8: ห้ามมี path traversal (..) และต้องขึ้นต้นด้วย {v_uid}/
    if length(v_p) = 0 or length(v_p) > 255 or not (v_p like (v_uid::text || '/%')) or v_p like '%..%' then
      raise exception 'INVALID_EVIDENCE_PATH';
    end if;

    -- N8: ตรวจสอบว่าไฟล์หลักฐานมีอยู่จริงใน bucket merchant-evidences
    if not exists (
      select 1 from storage.objects
      where bucket_id = 'merchant-evidences' and name = v_p
    ) then
      raise exception 'EVIDENCE_FILE_NOT_FOUND';
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

