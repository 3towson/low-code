-- Migration: Auto link recent evidence images if not passed by Edge Function
-- ช่วยเชื่อมรูปภาพหลักฐานที่ร้านค้าเพิ่งอัปโหลดเข้ากับ cod_reports อัตโนมัติ

create or replace function public.auto_link_recent_evidence()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_paths text;
begin
  -- หากไม่มี evidence_path ส่งมา ให้ค้นหาไฟล์รูปที่ผู้ใช้เพิ่งอัปโหลดในโฟลเดอร์ของตัวเองในช่วง 5 นาทีล่าสุด
  if new.evidence_path is null or trim(new.evidence_path) = '' then
    select string_agg(o.name, ',' order by o.created_at asc)
    into v_paths
    from (
      select name, created_at
      from storage.objects
      where bucket_id = 'report-evidences'
        and (storage.foldername(name))[1] = new.reported_by::text
        and created_at >= (now() - interval '5 minutes')
      order by created_at desc
      limit 3
    ) o;

    if v_paths is not null and trim(v_paths) <> '' then
      new.evidence_path := v_paths;
    end if;
  end if;

  return new;
end;
$$;

revoke all on function public.auto_link_recent_evidence() from public, anon;
grant execute on function public.auto_link_recent_evidence() to authenticated, service_role;

drop trigger if exists trg_auto_link_recent_evidence on public.cod_reports;
create trigger trg_auto_link_recent_evidence
  before insert on public.cod_reports
  for each row execute function public.auto_link_recent_evidence();
