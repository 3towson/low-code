-- ส่วนที่ 8: ระบบ Merchant KYC & Admin Approval (การยืนยันตัวตนร้านค้า)
-- เพื่อให้การรายงานลูกค้า COD มาจากร้านค้าที่ได้รับการยืนยันตัวตนจริงเท่านั้น

-- 1) เพิ่มคอลัมน์ใน public.sellers
alter table public.sellers
  add column if not exists verification_status text not null default 'unverified',
  add column if not exists shop_url text null,
  add column if not exists category text null,
  add column if not exists contact_phone text null,
  add column if not exists evidence_path text null,
  add column if not exists rejection_reason text null,
  add column if not exists submitted_at timestamptz null,
  add column if not exists verified_at timestamptz null,
  add column if not exists verified_by uuid references auth.users (id) null;

-- constraint สถานะการยืนยันตัวตนร้านค้า
alter table public.sellers
  drop constraint if exists sellers_verification_status_check;

alter table public.sellers
  add constraint sellers_verification_status_check
  check (verification_status in ('unverified', 'pending', 'approved', 'rejected'));

create index if not exists sellers_verification_status_idx
  on public.sellers (verification_status, submitted_at desc)
  where verification_status = 'pending';

-- 2) สร้าง Bucket merchant-evidences สำหรับเก็บหลักฐานยืนยันร้านค้า (Private)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'merchant-evidences',
  'merchant-evidences',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update set
  public = false,
  file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']::text[];

-- Policy: ร้านค้าอัปโหลดเข้าโฟลเดอร์ของตัวเองเท่านั้น
drop policy if exists merchant_evidence_upload_authenticated on storage.objects;
create policy merchant_evidence_upload_authenticated
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'merchant-evidences'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- Policy: เจ้าของร้าน หรือ Admin อ่านได้
drop policy if exists merchant_evidence_read_owner_or_admin on storage.objects;
create policy merchant_evidence_read_owner_or_admin
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'merchant-evidences'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or public.is_admin()
    )
  );

-- 3) RPC Function: ยื่นคำขอยืนยันตัวตนร้านค้า (Submit Merchant KYC)
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
begin
  if v_uid is null then
    raise exception 'UNAUTHORIZED';
  end if;

  update public.sellers
  set
    shop_url = btrim(p_shop_url),
    category = btrim(p_category),
    contact_phone = btrim(p_contact_phone),
    evidence_path = btrim(p_evidence_paths),
    verification_status = 'pending',
    rejection_reason = null,
    submitted_at = now()
  where id = v_uid;

  if not found then
    raise exception 'SELLER_NOT_FOUND';
  end if;

  return jsonb_build_object('ok', true, 'status', 'pending');
end;
$$;

revoke all on function public.submit_merchant_kyc(text, text, text, text) from public, anon;
grant execute on function public.submit_merchant_kyc(text, text, text, text) to authenticated, service_role;

-- 4) RPC Function: อ่านสถานะ KYC ของร้านค้าตนเอง
create or replace function public.get_my_kyc_status()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_seller record;
begin
  if v_uid is null then
    return null;
  end if;

  select id, shop_name, verification_status, shop_url, category, contact_phone,
         evidence_path, rejection_reason, submitted_at, verified_at
  into v_seller
  from public.sellers
  where id = v_uid;

  if not found then
    return null;
  end if;

  return jsonb_build_object(
    'shop_name', v_seller.shop_name,
    'verification_status', v_seller.verification_status,
    'shop_url', v_seller.shop_url,
    'category', v_seller.category,
    'contact_phone', v_seller.contact_phone,
    'evidence_path', v_seller.evidence_path,
    'rejection_reason', v_seller.rejection_reason,
    'submitted_at', v_seller.submitted_at,
    'verified_at', v_seller.verified_at
  );
end;
$$;

revoke all on function public.get_my_kyc_status() from public, anon;
grant execute on function public.get_my_kyc_status() to authenticated, service_role;

-- 5) RPC Function: Admin ดึงรายการร้านค้าที่รอการตรวจสอบ
create or replace function public.admin_get_pending_merchants(
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
    s.id,
    s.shop_name,
    s.shop_url,
    s.category,
    s.contact_phone,
    s.evidence_path,
    s.submitted_at,
    s.created_at
  from public.sellers s
  where s.verification_status = 'pending'
  order by s.submitted_at asc nulls last
  limit p_limit
  offset p_offset;
end;
$$;

revoke all on function public.admin_get_pending_merchants(int, int) from public, anon;
grant execute on function public.admin_get_pending_merchants(int, int) to authenticated, service_role;

-- 6) RPC Function: Admin อนุมัติร้านค้า
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
  where id = p_seller_id;

  if not found then
    raise exception 'SELLER_NOT_FOUND';
  end if;

  return jsonb_build_object('ok', true, 'status', 'approved');
end;
$$;

revoke all on function public.admin_approve_merchant(uuid) from public, anon;
grant execute on function public.admin_approve_merchant(uuid) to authenticated, service_role;

-- 7) RPC Function: Admin ปฏิเสธร้านค้า
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
  where id = p_seller_id;

  if not found then
    raise exception 'SELLER_NOT_FOUND';
  end if;

  return jsonb_build_object('ok', true, 'status', 'rejected');
end;
$$;

revoke all on function public.admin_reject_merchant(uuid, text) from public, anon;
grant execute on function public.admin_reject_merchant(uuid, text) to authenticated, service_role;

-- 8) RPC Function: สถิติ Merchant KYC สำหรับ Admin Dashboard
create or replace function public.admin_get_merchant_stats()
returns table (
  pending_merchants_count bigint,
  approved_merchants_total bigint,
  rejected_merchants_total bigint
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
    count(*) filter (where verification_status = 'pending') as pending_merchants_count,
    count(*) filter (where verification_status = 'approved') as approved_merchants_total,
    count(*) filter (where verification_status = 'rejected') as rejected_merchants_total
  from public.sellers;
end;
$$;

revoke all on function public.admin_get_merchant_stats() from public, anon;
grant execute on function public.admin_get_merchant_stats() to authenticated, service_role;
