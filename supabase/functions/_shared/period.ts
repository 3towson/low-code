// แปลงเวลาของรายงานล่าสุดเป็นช่วงเวลาคร่าวๆ ก่อนส่งกลับไปให้แอป
// ห้ามส่งวันที่จริง เพราะคนที่ตรวจเบอร์ตัวเองจะเดาได้ว่าร้านไหนเป็นผู้รายงาน

export type ReportPeriod = "within_30_days" | "1_to_3_months" | "3_to_12_months";

const DAY_MS = 24 * 60 * 60 * 1000;

// lastReportAt คือ last_report_at จาก get_risk_level (null เมื่อไม่มีรายงานที่นับ)
export function reportPeriod(lastReportAt: string | null, now: Date = new Date()): ReportPeriod | null {
  if (!lastReportAt) return null;
  const at = Date.parse(lastReportAt);
  if (Number.isNaN(at)) return null;
  const age = now.getTime() - at;
  if (age <= 30 * DAY_MS) return "within_30_days";
  if (age <= 90 * DAY_MS) return "1_to_3_months";
  // รายงานที่นับอยู่ภายใน 12 เดือนอยู่แล้ว
  return "3_to_12_months";
}
