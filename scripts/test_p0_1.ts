// ทดสอบความสมบูรณ์ของข้อ P0-1: การลบบัญชีผู้ใช้ (Account Deletion)
// เกณฑ์ผ่าน:
// 1. ร้านที่เคยรายงานและเคยมีหลักฐาน ลบบัญชีสำเร็จ
// 2. แถวใน auth.users และ sellers หายไป
// 3. ไฟล์ใน report-evidences และ merchant-evidences หายไป
// 4. รายงานยังคงอยู่ แต่ reported_by กลายเป็น null (on delete set null)
// 5. get_risk_level รันได้ปกติ ไม่ error และนับรายงานไร้เจ้าของเป็นระดับ yellow
//
// รัน: deno run --allow-net --allow-read --allow-env scripts/test_p0_1.ts

import { hashPhone } from "../supabase/functions/_shared/phone.ts";
import { loadEnv, serviceClient } from "./_env.ts";

const env = await loadEnv([
  "SUPABASE_URL",
  "SUPABASE_SERVICE_ROLE_KEY",
  "TEST_USER_PASSWORD",
  "PHONE_HASH_SECRET",
]);
const sb = serviceClient(env);

const results: { name: string; expected: string; actual: string; ok: boolean }[] = [];
function record(name: string, expected: string, actual: string, ok: boolean) {
  results.push({ name, expected, actual, ok });
}

const TEST_EMAIL = `p01_test_${Date.now()}@test.local`;
const TEST_PHONE = "0899990001";
const phoneHash = await hashPhone(TEST_PHONE, env.PHONE_HASH_SECRET);

console.log(`\n=== เริ่มการทดสอบ P0-1: Account Deletion (Email: ${TEST_EMAIL}) ===\n`);

let testUid: string | null = null;

try {
  // 1) สร้างผู้ใช้ทดสอบ
  const { data: created, error: createError } = await sb.auth.admin.createUser({
    email: TEST_EMAIL,
    password: env.TEST_USER_PASSWORD,
    email_confirm: true,
    user_metadata: { shop_name: "ร้านเตรียมลบบัญชี" },
  });

  if (createError || !created.user) {
    throw new Error(`สร้างผู้ใช้ไม่สำเร็จ: ${createError?.message}`);
  }
  testUid = created.user.id;
  record("1. สร้างผู้ใช้สำหรับทดสอบลบบัญชี", "สร้างสำเร็จ", "สร้างสำเร็จ", true);

  // 2) ยืนยันว่า trigger handle_new_user สร้างแถวใน sellers
  const { data: sellerRow, error: sellerErr } = await sb
    .from("sellers")
    .select("id, shop_name")
    .eq("id", testUid)
    .single();

  const sellerCreated = !sellerErr && sellerRow?.id === testUid;
  record(
    "2. sellers row ถูกสร้างอัตโนมัติ",
    "พบ sellers row",
    sellerCreated ? "พบ sellers row" : `ไม่พบ (${sellerErr?.message})`,
    sellerCreated,
  );

  // 3) อัปโหลดไฟล์หลักฐานจำลองใน storage
  const dummyFile = new Uint8Array([0xff, 0xd8, 0xff, 0xe0]); // mock jpeg
  const reportPath = `${testUid}/evidence_test.jpg`;
  const kycPath = `${testUid}/kyc_test.jpg`;

  await sb.storage.from("report-evidences").upload(reportPath, dummyFile, {
    contentType: "image/jpeg",
    upsert: true,
  });
  await sb.storage.from("merchant-evidences").upload(kycPath, dummyFile, {
    contentType: "image/jpeg",
    upsert: true,
  });

  const { data: reportList } = await sb.storage.from("report-evidences").list(testUid);
  const { data: kycList } = await sb.storage.from("merchant-evidences").list(testUid);
  const filesUploaded = (reportList?.length ?? 0) > 0 && (kycList?.length ?? 0) > 0;
  record(
    "3. อัปโหลดไฟล์หลักฐานจำลองเข้าทั้ง 2 buckets",
    "มีไฟล์ในโฟลเดอร์",
    filesUploaded ? "อัปโหลดสำเร็จ" : "อัปโหลดไม่สำเร็จ",
    filesUploaded,
  );

  // 4) สร้างรายงาน cod_reports
  const { data: rep, error: repError } = await sb
    .from("cod_reports")
    .insert({
      phone_hash: phoneHash,
      customer_name: "นายทดสอบ ลบบัญชี",
      reported_by: testUid,
      platform: "shopee",
      reason: "refused_delivery",
      amount: 450,
      status: "active",
      evidence_path: reportPath,
    })
    .select()
    .single();

  const reportCreated = !repError && rep != null;
  record(
    "4. บันทึกรายงาน cod_reports โดยมี reported_by = uid",
    "insert สำเร็จ",
    reportCreated ? "insert สำเร็จ" : `error: ${repError?.message}`,
    reportCreated,
  );

  // 5) ตรวจสอบ get_risk_level ก่อนลบ
  const { data: riskBefore, error: riskErr1 } = await sb
    .rpc("get_risk_level", { p_phone_hash: phoneHash })
    .single<{ level: string; counted_reports: number }>();

  record(
    "5. คำนวณ get_risk_level ก่อนลบบัญชี",
    "ได้ผลลัพธ์ปกติ",
    !riskErr1 && riskBefore != null ? `level: ${riskBefore.level}, count: ${riskBefore.counted_reports}` : `error: ${riskErr1?.message}`,
    !riskErr1 && riskBefore != null,
  );

  // 6) ดำเนินการลบบัญชี (จำลอง Edge Function delete-account logic)
  // 6.1 ลบ storage
  const [repDel, kycDel] = await Promise.all([
    sb.storage.from("report-evidences").remove([reportPath]),
    sb.storage.from("merchant-evidences").remove([kycPath]),
  ]);

  // 6.2 ลบ auth user ด้วย admin
  const { error: delUserErr } = await sb.auth.admin.deleteUser(testUid);
  record(
    "6. ลบผู้ใช้ผ่าน auth.admin.deleteUser(uid)",
    "ลบสำเร็จ ไม่ติด FK",
    !delUserErr ? "ลบสำเร็จ" : `error: ${delUserErr.message}`,
    !delUserErr,
  );

  // 7) ตรวจสอบว่าแถวใน sellers หายไป (cascade delete)
  const { data: sellerAfter } = await sb
    .from("sellers")
    .select("id")
    .eq("id", testUid)
    .maybeSingle();

  record(
    "7. แถวใน sellers หายไปอัตโนมัติ (cascade)",
    "ไม่พบแถวใน sellers",
    sellerAfter == null ? "ไม่พบแถวใน sellers" : "ยังมีแถวเหลืออยู่",
    sellerAfter == null,
  );

  // 8) ตรวจสอบไฟล์ใน Storage หายไป
  const { data: repFilesAfter } = await sb.storage.from("report-evidences").list(testUid);
  const { data: kycFilesAfter } = await sb.storage.from("merchant-evidences").list(testUid);
  const storageEmpty = (repFilesAfter?.length ?? 0) === 0 && (kycFilesAfter?.length ?? 0) === 0;

  record(
    "8. ไฟล์หลักฐานใน Storage หายไปทั้งหมด",
    "ไม่มีไฟล์เหลืออยู่",
    storageEmpty ? "ไม่มีไฟล์เหลืออยู่" : "ยังมีไฟล์ค้าง",
    storageEmpty,
  );

  // 9) ตรวจสอบว่ารายงาน cod_reports ยังคงอยู่ แต่ reported_by กลายเป็น NULL (on delete set null)
  if (rep?.id) {
    const { data: reportAfter, error: reportAfterErr } = await sb
      .from("cod_reports")
      .select("id, reported_by, phone_hash, status")
      .eq("id", rep.id)
      .single();

    const isSetNull = !reportAfterErr && reportAfter != null && reportAfter.reported_by === null;
    record(
      "9. รายงานยังคงอยู่ และ reported_by กลายเป็น NULL (set null)",
      "reported_by = null",
      isSetNull ? "reported_by = null" : `ค่าจริง: ${reportAfter?.reported_by}`,
      isSetNull,
    );
  }

  // 10) ตรวจสอบ get_risk_level หลังลบบัญชีร้านค้า (รายงานไร้เจ้าของต้องไม่ทำให้ error และนับเป็น yellow)
  const { data: riskAfter, error: riskErr2 } = await sb
    .rpc("get_risk_level", { p_phone_hash: phoneHash })
    .single<{ level: string; counted_reports: number }>();

  const riskPassed = !riskErr2 && riskAfter?.level === "yellow" && riskAfter.counted_reports >= 1;
  record(
    "10. get_risk_level หลังลบบัญชีไม่ crash และให้ผลเป็น yellow",
    "level = yellow, count >= 1",
    !riskErr2 && riskAfter != null ? `level: ${riskAfter.level}, count: ${riskAfter.counted_reports}` : `error: ${riskErr2?.message}`,
    riskPassed,
  );

} finally {
  // ล้างข้อมูลทดสอบ
  await sb.from("cod_reports").delete().eq("phone_hash", phoneHash);
  if (testUid) {
    await sb.auth.admin.deleteUser(testUid).catch(() => {});
  }
}

// สรุปผล
console.log("\nเคสทดสอบ | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน");
console.log("-".repeat(70));
for (const r of results) {
  console.log(`${r.name} | ${r.expected} | ${r.actual} | ${r.ok ? "ผ่าน" : "ไม่ผ่าน"}`);
}
const passCount = results.filter((r) => r.ok).length;
console.log(`\nสรุป: ผ่าน ${passCount}/${results.length}\n`);

if (passCount !== results.length) {
  Deno.exit(1);
}
