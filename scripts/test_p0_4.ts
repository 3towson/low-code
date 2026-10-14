// ทดสอบความสมบูรณ์ของข้อ P0-4: UGC Merchant Suspension & Contact Channel
// เกณฑ์ผ่าน:
// 1. sellers constraint รองรับสถานะ 'suspended'
// 2. admin_suspend_merchant เปลี่ยนสถานะร้านค้าเป็น 'suspended' พร้อมบันทึกเหตุผล
// 3. report-customer ปฏิเสธร้านที่ถูกระงับ (suspended) ด้วย HTTP 403 SUSPENDED_MERCHANT
// 4. report-customer ปฏิเสธร้านที่ยังไม่ผ่าน KYC (unverified/pending/rejected) ด้วย HTTP 403 UNVERIFIED_MERCHANT (fail-closed)
//
// รัน: deno run --allow-net --allow-read --allow-env scripts/test_p0_4.ts

import { createClient } from "npm:@supabase/supabase-js@2";
import { hashPhone } from "../supabase/functions/_shared/phone.ts";
import { loadEnv, serviceClient } from "./_env.ts";

const env = await loadEnv([
  "SUPABASE_URL",
  "SUPABASE_ANON_KEY",
  "SUPABASE_SERVICE_ROLE_KEY",
  "TEST_USER_PASSWORD",
  "PHONE_HASH_SECRET",
]);
const sb = serviceClient(env);
const FN_URL = `${env.SUPABASE_URL}/functions/v1/report-customer`;

const results: { name: string; expected: string; actual: string; ok: boolean }[] = [];
function record(name: string, expected: string, actual: string, ok: boolean) {
  results.push({ name, expected, actual, ok });
}

const TEST_EMAIL = `p04_test_${Date.now()}@test.local`;
const TEST_PHONE = "0877770001";
const phoneHash = await hashPhone(TEST_PHONE, env.PHONE_HASH_SECRET);

console.log(`\n=== เริ่มการทดสอบ P0-4: UGC Merchant Suspension & Contact Channel ===\n`);

let testUid: string | null = null;
let userClient: any = null;
let accessToken: string | null = null;

try {
  // 1) สร้างผู้ใช้ร้านค้าทดสอบ
  const { data: created, error: createError } = await sb.auth.admin.createUser({
    email: TEST_EMAIL,
    password: env.TEST_USER_PASSWORD,
    email_confirm: true,
    user_metadata: { shop_name: "ร้านทดสอบ P0-4 UGC" },
  });

  if (createError || !created.user) {
    throw new Error(`สร้างผู้ใช้ไม่สำเร็จ: ${createError?.message}`);
  }
  testUid = created.user.id;
  record("1. สร้างบัญชีร้านค้าทดสอบ", "สร้างสำเร็จ", "สร้างสำเร็จ", true);

  // 2) เข้าสู่ระบบเพื่อเอา access token
  userClient = createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: login, error: loginErr } = await userClient.auth.signInWithPassword({
    email: TEST_EMAIL,
    password: env.TEST_USER_PASSWORD,
  });
  if (loginErr || !login.session) {
    throw new Error(`login ร้านค้าทดสอบล้มเหลว: ${loginErr?.message}`);
  }
  accessToken = login.session.access_token;

  // 3) อัปโหลดไฟล์หลักฐานจำลองในโฟลเดอร์ของร้าน
  const dummyFile = new Uint8Array([0xff, 0xd8, 0xff, 0xe0]);
  const evidencePath = `${testUid}/proof_p04.jpg`;
  await sb.storage.from("report-evidences").upload(evidencePath, dummyFile, {
    contentType: "image/jpeg",
    upsert: true,
  });

  const payload = {
    customer_name: "ลูกค้าทดสอบ",
    phone: TEST_PHONE,
    platform: "shopee",
    reason: "refused_delivery",
    amount: 500,
    evidence_paths: [evidencePath],
  };

  async function callReportCustomer(): Promise<{ status: number; body: any }> {
    const res = await fetch(FN_URL, {
      method: "POST",
      headers: {
        apikey: env.SUPABASE_ANON_KEY,
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });
    let body = null;
    try {
      body = await res.json();
    } catch (_) {}
    return { status: res.status, body };
  }

  // 4) ทดสอบเมื่อร้านค้ายังเป็น unverified (สถานะเริ่มต้น) -> ต้องได้ HTTP 403 UNVERIFIED_MERCHANT (Fail-closed)
  const resUnverified = await callReportCustomer();
  const unverifiedOk =
    resUnverified.status === 403 &&
    resUnverified.body?.status === "UNVERIFIED_MERCHANT";
  record(
    "2. ร้านค้า unverified ส่งรายงานไม่ได้ (Fail-closed)",
    "HTTP 403 UNVERIFIED_MERCHANT",
    `HTTP ${resUnverified.status} ${resUnverified.body?.status}`,
    unverifiedOk,
  );

  // 5) อนุมัติร้านค้าชั่วคราว
  await sb.from("sellers").update({ verification_status: "approved" }).eq("id", testUid);

  // 6) ทดสอบระงับร้านค้าผ่าน RPC admin_suspend_merchant
  const { data: suspendRes, error: suspendErr } = await sb.rpc("admin_suspend_merchant", {
    p_seller_id: testUid,
    p_reason: "ละเมิดข้อกำหนด UGC ส่งรายงานข้อมูลเท็จ",
  });
  const suspendOk = !suspendErr && suspendRes?.ok === true && suspendRes?.status === "suspended";
  record(
    "3. เรียก admin_suspend_merchant ระงับร้านค้า",
    "ok=true, status=suspended",
    suspendOk ? "ok=true, status=suspended" : `error: ${suspendErr?.message}`,
    suspendOk,
  );

  // ตรวจสอบข้อมูลในตาราง sellers ว่า verification_status เป็น 'suspended'
  const { data: sellerRow } = await sb.from("sellers").select("*").eq("id", testUid).single();
  const dbSuspendedOk =
    sellerRow?.verification_status === "suspended" &&
    sellerRow?.rejection_reason === "ละเมิดข้อกำหนด UGC ส่งรายงานข้อมูลเท็จ";
  record(
    "4. ตาราง sellers บันทึกสถานะ suspended และเหตุผล",
    "status=suspended พร้อมเหตุผลระงับ",
    `status=${sellerRow?.verification_status}, reason=${sellerRow?.rejection_reason}`,
    dbSuspendedOk,
  );

  // 7) ทดสอบร้านที่ถูกระงับ (suspended) ส่งรายงาน -> ต้องได้ HTTP 403 SUSPENDED_MERCHANT
  const resSuspended = await callReportCustomer();
  const suspendedBlockedOk =
    resSuspended.status === 403 &&
    resSuspended.body?.status === "SUSPENDED_MERCHANT" &&
    typeof resSuspended.body?.error === "string" &&
    resSuspended.body?.error.includes("codriskshield.support@gmail.com");
  record(
    "5. ร้านค้า suspended ส่งรายงานไม่ได้ และได้รับคำแนะนำติดต่อ codriskshield.support@gmail.com",
    "HTTP 403 SUSPENDED_MERCHANT พร้อมช่องทางติดต่อ",
    `HTTP ${resSuspended.status} ${resSuspended.body?.status}: ${resSuspended.body?.error}`,
    suspendedBlockedOk,
  );

  // 8) ทดสอบปลดระงับและอนุมัติร้านค้า -> สามารถส่งรายงานได้ปกติ (HTTP 201 CREATED)
  await sb.from("sellers").update({ verification_status: "approved" }).eq("id", testUid);
  const resApproved = await callReportCustomer();
  const approvedOk =
    resApproved.status === 201 && resApproved.body?.status === "CREATED";
  record(
    "6. ร้านค้าที่ approved ส่งรายงานได้สำเร็จ",
    "HTTP 201 CREATED",
    `HTTP ${resApproved.status} ${resApproved.body?.status}`,
    approvedOk,
  );
} finally {
  // Cleanup ข้อมูลทดสอบ
  if (testUid) {
    try {
      await sb.from("cod_reports").delete().eq("phone_hash", phoneHash);
      await sb.storage.from("report-evidences").remove([`${testUid}/proof_p04.jpg`]);
      await sb.from("sellers").delete().eq("id", testUid);
      await sb.auth.admin.deleteUser(testUid);
    } catch (_) {}
  }
}

console.log("\nเคสทดสอบ | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน");
for (const r of results) {
  console.log(`${r.name} | ${r.expected} | ${r.actual} | ${r.ok ? "ผ่าน" : "ไม่ผ่าน"}`);
}
const failed = results.filter((r) => !r.ok).length;
console.log(`\nสรุป: ผ่าน ${results.length - failed}/${results.length}`);
Deno.exit(failed === 0 ? 0 : 1);
