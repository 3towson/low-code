// ทดสอบส่วนที่ 1: constraint ของ cod_reports, แถวใน sellers, จำนวนรายงานทดสอบ
// รัน seed_test.ts ก่อน แล้วรัน:
// deno run --allow-net --allow-read --allow-env scripts/test_part1.ts

import { findTestUsers, loadEnv, serviceClient, TEST_REPORTS, TEST_SHOPS } from "./_env.ts";

const env = await loadEnv(["SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY"]);
const sb = serviceClient(env);

const INVALID_HASH = "TEST_PART1_INVALID";
const results: { name: string; expected: string; actual: string; ok: boolean }[] = [];

function record(name: string, expected: string, actual: string, ok: boolean) {
  results.push({ name, expected, actual, ok });
}

const users = await findTestUsers(sb);
const shop1 = users.get("shop1@test.local");
if (!shop1) {
  console.log("FAIL  ไม่พบ shop1@test.local ให้รัน seed_test.ts ก่อน");
  Deno.exit(1);
}

// 1) insert ค่าผิดต้องถูก check constraint ปฏิเสธ (23514)
const invalidCases: { name: string; patch: Record<string, unknown>; constraint: string }[] = [
  { name: "insert status = 'banned'", patch: { status: "banned" }, constraint: "cod_reports_status_check" },
  { name: "insert platform = 'ebay'", patch: { platform: "ebay" }, constraint: "cod_reports_platform_check" },
  { name: "insert amount = -100", patch: { amount: -100 }, constraint: "cod_reports_amount_check" },
];

for (const c of invalidCases) {
  const { error } = await sb.from("cod_reports").insert({
    phone_hash: INVALID_HASH,
    customer_name: "ทดสอบค่าผิด",
    reported_by: shop1,
    platform: "shopee",
    reason: "refused_delivery",
    amount: 100,
    ...c.patch,
  });
  const expected = `ล้มเหลว (23514 ${c.constraint})`;
  if (!error) {
    record(c.name, expected, "insert สำเร็จ", false);
  } else {
    const hit = error.code === "23514" && error.message.includes(c.constraint);
    record(c.name, expected, `ล้มเหลว (${error.code} ${hit ? c.constraint : error.message})`, hit);
  }
}
// เก็บกวาดเผื่อมีแถวผิดหลุดเข้าไป
await sb.from("cod_reports").delete().eq("phone_hash", INVALID_HASH);

// 2) sellers ครบ 4 ร้าน และ shop_name ไม่ว่าง
{
  const ids = TEST_SHOPS.map((s) => users.get(s.email)).filter((x): x is string => !!x);
  const { data, error } = await sb.from("sellers").select("id, shop_name").in("id", ids);
  if (error) {
    record("sellers ครบ 4 ร้าน shop_name ไม่ว่าง", "4 แถว, shop_name ไม่ว่าง", `error: ${error.message}`, false);
  } else {
    const nonEmpty = data.filter((r) => typeof r.shop_name === "string" && r.shop_name.trim() !== "").length;
    record(
      "sellers ครบ 4 ร้าน shop_name ไม่ว่าง",
      "4 แถว, shop_name ไม่ว่าง 4",
      `${data.length} แถว, shop_name ไม่ว่าง ${nonEmpty}`,
      data.length === 4 && nonEmpty === 4,
    );
  }
}

// 3) จำนวนรายงานต่อ hash
for (const [hash, reports] of Object.entries(TEST_REPORTS)) {
  const { count, error } = await sb
    .from("cod_reports")
    .select("id", { count: "exact", head: true })
    .eq("phone_hash", hash);
  const expected = String(reports.length);
  if (error) {
    record(`จำนวนรายงาน ${hash}`, expected, `error: ${error.message}`, false);
  } else {
    record(`จำนวนรายงาน ${hash}`, expected, String(count), count === reports.length);
  }
}

console.log("เคสทดสอบ | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน");
for (const r of results) {
  console.log(`${r.name} | ${r.expected} | ${r.actual} | ${r.ok ? "ผ่าน" : "ไม่ผ่าน"}`);
}
const failed = results.filter((r) => !r.ok).length;
console.log(`\nสรุป: ผ่าน ${results.length - failed}/${results.length}`);
Deno.exit(failed === 0 ? 0 : 1);
