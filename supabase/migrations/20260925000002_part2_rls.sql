-- ส่วนที่ 2: เปิด RLS และ trigger กันรายงานซ้ำ

-- ---------------------------------------------------------------------------
-- RLS
-- sellers: ผู้ใช้ที่ login เห็นเฉพาะแถวของตัวเอง
-- cod_reports: ไม่มี policy สำหรับ anon และ authenticated
--              (Edge Function ใช้ service role ซึ่งข้าม RLS)
-- ---------------------------------------------------------------------------
alter table public.sellers enable row level security;
alter table public.cod_reports enable row level security;

create policy sellers_select_own
  on public.sellers
  for select
  to authenticated
  using ((select auth.uid()) = id);

-- ---------------------------------------------------------------------------
-- กันรายงานซ้ำ: ร้านเดียวกันรายงานเบอร์เดียวกันได้ไม่เกิน 1 ครั้งใน 7 วัน
-- ---------------------------------------------------------------------------
create or replace function public.prevent_duplicate_report()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- ล็อกตามคู่ (phone_hash, reported_by) กัน insert พร้อมกันหลุดผ่านการตรวจ
  perform pg_advisory_xact_lock(
    hashtextextended(new.phone_hash || ':' || new.reported_by::text, 0)
  );

  if exists (
    select 1
    from public.cod_reports r
    where r.phone_hash = new.phone_hash
      and r.reported_by = new.reported_by
      and r.created_at > now() - interval '7 days'
  ) then
    raise exception 'DUPLICATE_REPORT';
  end if;

  return new;
end;
$$;

revoke all on function public.prevent_duplicate_report() from public, anon, authenticated;

create trigger cod_reports_prevent_duplicate
  before insert on public.cod_reports
  for each row execute function public.prevent_duplicate_report();
