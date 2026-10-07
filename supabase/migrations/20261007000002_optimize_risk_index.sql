-- ส่วนที่ 5: ปรับปรุงประสิทธิภาพ Index และเพิ่ม Constraint ตาราง cod_reports

-- 1) Partial Index สำหรับ get_risk_level ที่ค้นหาเฉพาะรายงานสถานะ 'active'
create index if not exists cod_reports_active_risk_idx
  on public.cod_reports (phone_hash, created_at)
  where status = 'active';

-- 2) Check Constraint สำหรับจำกัดความยาว other_details ไม่เกิน 500 ตัวอักษร
alter table public.cod_reports
  drop constraint if exists cod_reports_other_details_length_check;

alter table public.cod_reports
  add constraint cod_reports_other_details_length_check
  check (other_details is null or length(other_details) <= 500);
