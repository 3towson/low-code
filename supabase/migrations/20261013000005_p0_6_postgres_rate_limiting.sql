-- Migration ส่วนที่ 10: ระบบ Rate Limiting ใน Postgres สำหรับ Guest และ Authenticated Users (P0-6)
-- รองรับการจำกัดจำนวนคำขอต่อนาที / ต่อวัน ทั้งระดับ IP (Guest) และ User ID (Logged-in)

-- 1) สร้างตาราง rate_limits
create table if not exists public.rate_limits (
  key text not null,
  window_start timestamptz not null default clock_timestamp(),
  count int not null default 1,
  primary key (key)
);

-- Index สำหรับค้นหาหรือ cleanup ข้อมูลเก่า
create index if not exists rate_limits_window_start_idx on public.rate_limits (window_start);

-- ความปลอดภัย: ปิดการเข้าถึงจาก anon / authenticated ตรงๆ เข้าถึงผ่าน security definer RPC เท่านั้น
alter table public.rate_limits enable row level security;
revoke all on public.rate_limits from public, anon, authenticated;
grant all on public.rate_limits to service_role;

-- 2) สร้าง RPC Function: hit_rate_limit(p_key text, p_limit int, p_window_seconds int)
-- คืนค่า true หากยังไม่เกิน limit, คืนค่า false หากเกิน limit แล้ว
create or replace function public.hit_rate_limit(
  p_key text,
  p_limit int,
  p_window_seconds int
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := clock_timestamp();
  v_allowed boolean;
begin
  insert into public.rate_limits (key, window_start, count)
  values (p_key, v_now, 1)
  on conflict (key) do update
  set
    window_start = case
      when v_now - public.rate_limits.window_start >= (p_window_seconds || ' seconds')::interval then v_now
      else public.rate_limits.window_start
    end,
    count = case
      when v_now - public.rate_limits.window_start >= (p_window_seconds || ' seconds')::interval then 1
      when public.rate_limits.count < 1000000 then public.rate_limits.count + 1
      else public.rate_limits.count
    end
  returning (public.rate_limits.count <= p_limit)
  into v_allowed;

  return coalesce(v_allowed, true);
end;
$$;

revoke all on function public.hit_rate_limit(text, int, int) from public, anon;
grant execute on function public.hit_rate_limit(text, int, int) to authenticated, service_role;
