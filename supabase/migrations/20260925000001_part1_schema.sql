-- ส่วนที่ 1: ตาราง sellers, cod_reports และ trigger สร้าง seller อัตโนมัติ
-- ยังไม่เปิด RLS และยังไม่มี trigger กันรายงานซ้ำ (ส่วนที่ 2)

-- ---------------------------------------------------------------------------
-- sellers
-- ---------------------------------------------------------------------------
create table public.sellers (
  id uuid primary key references auth.users (id) on delete cascade,
  shop_name text not null,
  created_at timestamptz not null default now()
);

-- สร้างแถวใน sellers เมื่อมีผู้ใช้ใหม่ใน auth.users
-- shop_name อ่านจาก raw_user_meta_data->>'shop_name' ถ้าไม่มีหรือว่างใช้ส่วนหน้าของอีเมล
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.sellers (id, shop_name)
  values (
    new.id,
    coalesce(
      nullif(btrim(new.raw_user_meta_data ->> 'shop_name'), ''),
      split_part(coalesce(new.email, ''), '@', 1),
      'ร้านค้า'
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

revoke all on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- cod_reports
-- ---------------------------------------------------------------------------
create table public.cod_reports (
  id uuid primary key default gen_random_uuid(),
  phone_hash text not null,
  customer_name text not null,
  reported_by uuid not null references public.sellers (id),
  platform text not null,
  reason text not null,
  amount numeric null,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  constraint cod_reports_platform_check
    check (platform in ('shopee', 'lazada', 'facebook', 'line', 'tiktok', 'other')),
  constraint cod_reports_reason_check
    check (reason in ('refused_delivery', 'unreachable', 'fake_address', 'other')),
  constraint cod_reports_status_check
    check (status in ('active', 'disputed', 'resolved')),
  constraint cod_reports_amount_check
    check (amount is null or amount >= 0)
);

create index cod_reports_phone_hash_created_at_idx
  on public.cod_reports (phone_hash, created_at);

-- ---------------------------------------------------------------------------
-- สิทธิ์
-- sellers: authenticated + service_role
-- cod_reports: service_role เท่านั้น (Flutter ต้องผ่าน Edge Function)
-- ---------------------------------------------------------------------------
revoke all on table public.sellers from public, anon, authenticated;
revoke all on table public.cod_reports from public, anon, authenticated;

grant select, insert, update, delete on table public.sellers to authenticated;
grant all on table public.sellers to service_role;
grant all on table public.cod_reports to service_role;
