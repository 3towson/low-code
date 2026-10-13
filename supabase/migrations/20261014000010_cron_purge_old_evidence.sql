-- Migration ส่วนที่ 15: ตั้งเวลาล้างข้อมูลและหลักฐานหมดอายุตาม PDPA 12 เดือน (R5.1 / S2)
-- รองรับการทำงานทั้งผ่าน pg_cron / pg_net บน Supabase และการเรียกผ่าน Scheduled Edge Function

create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

-- คำสั่งตั้งเวลา Cron Job รันทุกวันเวลา 03:00 น. (UTC+7 คือ 20:00 UTC หรือปรับตามเวลาเครื่อง)
-- กรณีใช้ Supabase Vault ในการเก็บ Edge Function Secret:
-- select cron.schedule(
--   'purge-old-evidence-daily',
--   '0 20 * * *',
--   $$
--   select
--     net.http_post(
--       url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url' limit 1) || '/functions/v1/purge-old-evidence',
--       headers := jsonb_build_object(
--         'Content-Type', 'application/json',
--         'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key' limit 1)
--       ),
--       body := '{}'::jsonb
--     );
--   $$
-- );

-- คำแนะนำ:
-- หากโปรเจกต์ไม่ได้เปิดใช้งาน Supabase Vault หรือ pg_cron ใน Database โดยตรง
-- ให้ตั้งค่าผ่าน Supabase Dashboard -> Edge Functions -> purge-old-evidence -> Scheduled Trigger
-- หรือ Integrations -> Cron ให้เรียก POST /functions/v1/purge-old-evidence ทุกวัน
