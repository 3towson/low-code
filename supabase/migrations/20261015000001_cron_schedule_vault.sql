-- Migration ส่วนที่ 17: ตั้งเวลาล้างข้อมูลและหลักฐานหมดอายุตาม PDPA (P1-4 / P1-5)
-- รันทุกวันเวลา 03:00 น. (UTC+7 คือ 20:00 UTC)
-- อ่าน Edge Function URL และ Service Role Key จาก Supabase Vault โดยไม่ฝัง key ในไฟล์
-- และรันซ้ำได้โดยไม่สร้าง job ซ้ำ (Idempotent)

create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

-- 1) ยกเลิก job เดิมถ้ามีอยู่แล้ว เพื่อให้ migration รันซ้ำได้โดยไม่สร้าง job ซ้ำ
do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'cron' and table_name = 'job'
  ) then
    if exists (select 1 from cron.job where jobname = 'purge-old-evidence-daily') then
      perform cron.unschedule(jobid) from cron.job where jobname = 'purge-old-evidence-daily';
    end if;
  end if;
exception
  when others then
    null;
end;
$$;

-- 2) สร้าง cron schedule ใหม่ที่ดึง URL และ service_role_key จาก vault.decrypted_secrets
do $$
begin
  if exists (
    select 1
    from information_schema.routines
    where routine_schema = 'cron' and routine_name = 'schedule'
  ) then
    perform cron.schedule(
      'purge-old-evidence-daily',
      '0 20 * * *',
      $cron$
      select
        net.http_post(
          url := coalesce((select decrypted_secret from vault.decrypted_secrets where name in ('project_url', 'SUPABASE_URL') limit 1), '') || '/functions/v1/purge-old-evidence',
          headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || coalesce((select decrypted_secret from vault.decrypted_secrets where name in ('service_role_key', 'SUPABASE_SERVICE_ROLE_KEY') limit 1), '')
          ),
          body := '{}'::jsonb
        );
      $cron$
    );
  end if;
exception
  when others then
    null;
end;
$$;
