// ทดสอบส่วนที่ 3: function get_risk_level และสิทธิ์การเรียก
// รัน seed_test.ts และ supabase db push ก่อน แล้วรัน:
// deno run --allow-net --allow-read --allow-env scripts/test_part3.ts

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import { loadEnv, serviceClient, TEST_REPORTS } from "./_env.ts";

const env = await loadEnv([
  "SUPABASE_URL",
  "SUPABASE_ANON_KEY",
  "SUPABASE_SERVICE_ROLE_KEY",
  "TEST_USER_PASSWORD",
]);
const sb = serviceClient(env);

const EXPECTED: Record<string, string> = {
  TEST_HASH_A: "green",
  TEST_HASH_B: "yellow",
  TEST_HASH_C: "yellow",
  TEST_HASH_D: "red",
  TEST_HASH_E: "yellow",
  TEST_HASH_F: "green",
  TEST_HASH_G: "yellow",
  TEST_HASH_H: "yellow",
};

type RiskRow = { level: string; counted_reports: number; last_report_at: string | null };

const results: { name: string; expected: string; actual: string; ok: boolean }[] = [];

function record(name: string, expected: string, actual: string, ok: boolean) {
  results.push({ name, expected, actual, ok });
}

function anonClient(): SupabaseClient {
  return createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

// rpc ที่ "ต้องถูกปฏิเสธ"
async function expectRpcDenied(name: string, client: SupabaseClient) {
  const { data, error } = await client.rpc("get_risk_level", { p_phone_hash: "TEST_HASH_D" });
  const expected = "ถูกปฏิเสธ";
  if (error) record(name, expected, `ถูกปฏิเสธ (${error.code})`, true);
  else record(name, expected, `เรียกสำเร็จ ได้ ${JSON.stringify(data)}`, false);
}

// 1) ระดับความเสี่ยงผ่าน service role
for (const [hash, level] of Object.entries(EXPECTED)) {
  const name = `${hash} (${TEST_REPORTS[hash].length} รายงานใน seed)`;
  const { data, error } = await sb
    .rpc("get_risk_level", { p_phone_hash: hash })
    .single<RiskRow>();
  if (error) {
    record(name, level, `error: ${error.code} ${error.message}`, false);
    continue;
  }
  const actual = `${data.level} (นับ ${data.counted_reports}, ล่าสุด ${
    data.last_report_at ? data.last_report_at.slice(0, 10) : "-"
  })`;
  record(name, level, actual, data.level === level);
}

// 2) anon key
await expectRpcDenied("anon เรียก rpc get_risk_level", anonClient());

// 3) login เป็น shop1
{
  const user = anonClient();
  const { error: loginError } = await user.auth.signInWithPassword({
    email: "shop1@test.local",
    password: env.TEST_USER_PASSWORD,
  });
  if (loginError) {
    record("shop1 เรียก rpc get_risk_level", "ถูกปฏิเสธ", `login ล้มเหลว: ${loginError.message}`, false);
  } else {
    await expectRpcDenied("shop1 เรียก rpc get_risk_level", user);
    await user.auth.signOut();
  }
}

console.log("เคสทดสอบ | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน");
for (const r of results) {
  console.log(`${r.name} | ${r.expected} | ${r.actual} | ${r.ok ? "ผ่าน" : "ไม่ผ่าน"}`);
}
const failed = results.filter((r) => !r.ok).length;
console.log(`\nสรุป: ผ่าน ${results.length - failed}/${results.length}`);
Deno.exit(failed === 0 ? 0 : 1);
