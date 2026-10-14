// สคริปต์สำหรับจัดการคำโต้แย้ง (Dispute Withdrawal)
// ใช้ถอนรายงานใน cod_reports ที่มีสถานะ 'active' หรือ 'pending' ให้เป็น 'rejected'
// เมื่อเจ้าของเบอร์โทรยื่นคำร้องขอโต้แย้งหรือใช้สิทธิลบข้อมูล (Right to Erasure / Dispute)
//
// ข้อกำหนดความปลอดภัย:
// - ห้ามพิมพ์หรือบันทึกหมายเลขโทรศัพท์จริงหรือค่าแฮชออกทางหน้าจอหรือบันทึก log เด็ดขาด
// - บันทึกประวัติการถอนรายงานลงตาราง admin_audit_logs โดยระบุเฉพาะจำนวนรายงานที่ถอน
//
// วิธีใช้งาน:
// deno run --allow-net --allow-read --allow-env scripts/withdraw_reports.ts <เบอร์โทรศัพท์>

import { normalizeThaiPhone, hashPhone } from "../supabase/functions/_shared/phone.ts";
import { loadEnv, serviceClient } from "./_env.ts";

const rawPhone = Deno.args[0];
if (!rawPhone) {
  console.error("ข้อผิดพลาด: กรุณาระบุหมายเลขโทรศัพท์เป็น argument เช่น:");
  console.error("  deno run --allow-net --allow-read --allow-env scripts/withdraw_reports.ts 0812345678");
  Deno.exit(1);
}

const normalized = normalizeThaiPhone(rawPhone);
if (!normalized) {
  console.error("ข้อผิดพลาด: รูปแบบหมายเลขโทรศัพท์ไม่ถูกต้อง (ต้องเป็นเบอร์มือถือไทย 10 หลัก)");
  Deno.exit(1);
}

const env = await loadEnv(["SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY", "PHONE_HASH_SECRET"]);
const sb = serviceClient(env);

const phoneHash = await hashPhone(normalized, env.PHONE_HASH_SECRET);

const { data, error: updateError } = await sb
  .from("cod_reports")
  .update({
    status: "rejected",
    reject_reason: "ถอนตามคำโต้แย้งของเจ้าของข้อมูล",
    reviewed_at: new Date().toISOString(),
  })
  .eq("phone_hash", phoneHash)
  .in("status", ["active", "pending"])
  .select("id");

if (updateError) {
  console.error(`เกิดข้อผิดพลาดในการอัปเดตรายงาน: ${updateError.message}`);
  Deno.exit(1);
}

const withdrawnCount = data?.length ?? 0;

// บันทึก audit logs (action: 'withdraw_by_dispute')
const { error: auditError } = await sb.from("admin_audit_logs").insert({
  action: "withdraw_by_dispute",
  target_type: "cod_reports",
  target_id: "dispute",
  details: {
    withdrawn_count: withdrawnCount,
    reason: "ถอนตามคำโต้แย้งของเจ้าของข้อมูล",
  },
});

if (auditError) {
  console.error(`คำเตือน: บันทึก audit log ไม่สำเร็จ: ${auditError.message}`);
}

console.log(`ถอนรายงานเรียบร้อยแล้ว: ${withdrawnCount} รายการ`);
