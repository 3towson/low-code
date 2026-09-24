-- ส่วนที่ 3: function คำนวณระดับความเสี่ยงของเบอร์โทร (จาก phone_hash)
--
-- รายงานที่นับ    : status = 'active' และ created_at อยู่ภายใน 12 เดือน
-- รายงานเกณฑ์แดง : รายงานที่นับ ที่อยู่ภายใน 90 วัน และร้านที่รายงานมีอายุบัญชี
--                  อย่างน้อย 7 วัน ณ วันที่รายงาน (report.created_at - seller.created_at >= 7 วัน)
-- red    : รายงานเกณฑ์แดงจากร้านต่างกันตั้งแต่ 2 ร้านขึ้นไป
-- yellow : มีรายงานที่นับอย่างน้อย 1 รายงาน แต่ไม่ถึงเกณฑ์ red
-- green  : ไม่มีรายงานที่นับ
--
-- last_report_at คือ created_at ล่าสุดของรายงานที่นับ (null ถ้าไม่มี)
-- เรียกได้เฉพาะ service_role (Edge Function)

create or replace function public.get_risk_level(p_phone_hash text)
returns table (level text, counted_reports int, last_report_at timestamptz)
language sql
stable
set search_path = ''
as $$
  with counted as (
    select
      r.reported_by,
      r.created_at,
      (
        r.created_at >= now() - interval '90 days'
        and r.created_at - s.created_at >= interval '7 days'
      ) as is_red
    from public.cod_reports r
    join public.sellers s on s.id = r.reported_by
    where r.phone_hash = p_phone_hash
      and r.status = 'active'
      and r.created_at >= now() - interval '12 months'
  )
  select
    case
      when count(distinct c.reported_by) filter (where c.is_red) >= 2 then 'red'
      when count(*) >= 1 then 'yellow'
      else 'green'
    end,
    count(*)::int,
    max(c.created_at)
  from counted c;
$$;

revoke all on function public.get_risk_level(text) from public, anon, authenticated;
grant execute on function public.get_risk_level(text) to service_role;
