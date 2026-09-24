// ทดสอบส่วนที่ 2: RLS ของ sellers/cod_reports และ trigger กันรายงานซ้ำ
// รัน seed_test.ts และ supabase db push ก่อน แล้วรัน:
// deno run --allow-net --allow-read --allow-env scripts/test_part2.ts

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import { findTestUsers, loadEnv, serviceClient } from "./_env.ts";

const env = await loadEnv([
  "SUPABASE_URL",
  "SUPABASE_ANON_KEY",
  "SUPABASE_SERVICE_ROLE_KEY",
  "TEST_USER_PASSWORD",
]);
const sb = serviceClient(env);

const DAY_MS = 24 * 60 * 60 * 1000;
const daysAgo = (d: number) => new Date(Date.now() - d * DAY_MS).toISOString();

const results: { name: string; expected: string; actual: string; ok: boolean }[] = [];

function record(name: string, expected: string, actual: string, ok: boolean) {
  results.push({ name, expected, actual, ok });
}

function anonClient(): SupabaseClient {
  return createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

function report(hash: string, reportedBy: string, extra: Record<string, unknown> = {}) {
  return {
    phone_hash: hash,
    customer_name: "ลูกค้าทดสอบ DUP",
    reported_by: reportedBy,
    platform: "shopee",
    reason: "refused_delivery",
    amount: 500,
    ...extra,
  };
}

async function cleanup(): Promise<number> {
  const { error, count } = await sb
    .from("cod_reports")
    .delete({ count: "exact" })
    .like("phone_hash", "TEST\\_HASH\\_DUP%");
  if (error) throw new Error(`ลบ TEST_HASH_DUP* ล้มเหลว: ${error.message}`);
  return count ?? 0;
}

// select ที่ "ต้องได้ผลว่างหรือถูกปฏิเสธ"
async function expectNoRows(name: string, client: SupabaseClient) {
  const { data, error } = await client.from("cod_reports").select("id").limit(5);
  const expected = "ว่าง หรือ ถูกปฏิเสธ";
  if (error) record(name, expected, `ถูกปฏิเสธ (${error.code})`, true);
  else record(name, expected, `ได้ ${data.length} แถว`, data.length === 0);
}

// insert ที่ "ต้องถูกปฏิเสธ"
async function expectInsertDenied(name: string, client: SupabaseClient, row: Record<string, unknown>) {
  const { error } = await client.from("cod_reports").insert(row);
  const expected = "ถูกปฏิเสธ";
  if (error) record(name, expected, `ถูกปฏิเสธ (${error.code})`, true);
  else record(name, expected, "insert สำเร็จ", false);
}

const users = await findTestUsers(sb);
const shop1 = users.get("shop1@test.local");
const shop2 = users.get("shop2@test.local");
if (!shop1 || !shop2) {
  console.log("FAIL  ไม่พบ shop1/shop2@test.local ให้รัน seed_test.ts ก่อน");
  Deno.exit(1);
}

await cleanup();

try {
  // 1) anon key
  const anon = anonClient();
  await expectNoRows("anon select cod_reports", anon);
  await expectInsertDenied("anon insert cod_reports", anon, report("TEST_HASH_DUP_ANON", shop1));

  // 2) login เป็น shop1
  const user = anonClient();
  const { error: loginError } = await user.auth.signInWithPassword({
    email: "shop1@test.local",
    password: env.TEST_USER_PASSWORD,
  });
  if (loginError) {
    for (const n of ["shop1 select cod_reports", "shop1 insert cod_reports", "shop1 select sellers"]) {
      record(n, "-", `login ล้มเหลว: ${loginError.message}`, false);
    }
  } else {
    await expectNoRows("shop1 select cod_reports", user);
    await expectInsertDenied("shop1 insert cod_reports", user, report("TEST_HASH_DUP_USER", shop1));

    const { data, error } = await user.from("sellers").select("id");
    const expected = "1 แถว เป็นของ shop1";
    if (error) {
      record("shop1 select sellers", expected, `error: ${error.code} ${error.message}`, false);
    } else {
      const onlyOwn = data.length === 1 && data[0].id === shop1;
      const others = data.filter((r) => r.id !== shop1).length;
      record(
        "shop1 select sellers",
        expected,
        `${data.length} แถว (ของ shop1 ${data.length - others}, ร้านอื่น ${others})`,
        onlyOwn,
      );
    }
    await user.auth.signOut();
  }

  // 3) service role: รายงานซ้ำภายใน 7 วัน
  {
    const name = "shop1 รายงาน TEST_HASH_DUP ซ้ำติดกัน";
    const expected = "ครั้งแรกผ่าน, ครั้งที่สอง DUPLICATE_REPORT";
    const first = await sb.from("cod_reports").insert(report("TEST_HASH_DUP", shop1));
    const second = await sb.from("cod_reports").insert(report("TEST_HASH_DUP", shop1));
    const a1 = first.error ? `ครั้งแรก error: ${first.error.message}` : "ครั้งแรกผ่าน";
    const a2 = second.error ? `ครั้งที่สอง ${second.error.message}` : "ครั้งที่สองผ่าน";
    const ok = !first.error && second.error?.message === "DUPLICATE_REPORT";
    record(name, expected, `${a1}, ${a2}`, ok);
  }

  // 4) service role: รายงานเดิมเกิน 7 วัน
  {
    const name = "shop1 TEST_HASH_DUP2 (8 วันก่อน + วันนี้)";
    const expected = "ผ่านทั้งสองครั้ง";
    const old = await sb.from("cod_reports").insert(report("TEST_HASH_DUP2", shop1, { created_at: daysAgo(8) }));
    const today = await sb.from("cod_reports").insert(report("TEST_HASH_DUP2", shop1));
    const a1 = old.error ? `8 วันก่อน error: ${old.error.message}` : "8 วันก่อนผ่าน";
    const a2 = today.error ? `วันนี้ error: ${today.error.message}` : "วันนี้ผ่าน";
    record(name, expected, `${a1}, ${a2}`, !old.error && !today.error);
  }

  // 5) service role: คนละร้าน เบอร์เดียวกัน วันเดียวกัน
  {
    const name = "shop1 และ shop2 รายงาน TEST_HASH_DUP3 วันเดียวกัน";
    const expected = "ผ่านทั้งคู่";
    const r1 = await sb.from("cod_reports").insert(report("TEST_HASH_DUP3", shop1));
    const r2 = await sb.from("cod_reports").insert(report("TEST_HASH_DUP3", shop2));
    const a1 = r1.error ? `shop1 error: ${r1.error.message}` : "shop1 ผ่าน";
    const a2 = r2.error ? `shop2 error: ${r2.error.message}` : "shop2 ผ่าน";
    record(name, expected, `${a1}, ${a2}`, !r1.error && !r2.error);
  }
} finally {
  // 6) เก็บกวาด
  const deleted = await cleanup();
  const { count, error } = await sb
    .from("cod_reports")
    .select("id", { count: "exact", head: true })
    .like("phone_hash", "TEST\\_HASH\\_DUP%");
  record(
    "ลบ TEST_HASH_DUP* หลังทดสอบ",
    "เหลือ 0 แถว",
    error ? `error: ${error.message}` : `ลบ ${deleted} แถว, เหลือ ${count} แถว`,
    !error && count === 0,
  );
}

console.log("เคสทดสอบ | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน");
for (const r of results) {
  console.log(`${r.name} | ${r.expected} | ${r.actual} | ${r.ok ? "ผ่าน" : "ไม่ผ่าน"}`);
}
const failed = results.filter((r) => !r.ok).length;
console.log(`\nสรุป: ผ่าน ${results.length - failed}/${results.length}`);
Deno.exit(failed === 0 ? 0 : 1);
