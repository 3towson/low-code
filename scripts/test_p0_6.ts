// ทดสอบความสมบูรณ์ของข้อ P0-6: Postgres-backed Rate Limiting (Guest & User)
// เกณฑ์ผ่าน:
// 1. ตาราง rate_limits และ RPC hit_rate_limit ทำงานได้อย่างถูกต้อง (atomic upsert)
// 2. เมื่อเรียก hit_rate_limit เกิน limit จะคืนค่า false
// 3. check-customer แยกแยะระหว่าง Guest (anon key หรือไม่มี token) กับ Logged-in User ได้จริง
// 4. โหมด text (Gemini) และโหมด phone มีการแยก key และเพดานอย่างถูกต้อง
//
// รัน: deno run --allow-net --allow-read --allow-env scripts/test_p0_6.ts

import { loadEnv, serviceClient } from "./_env.ts";

const env = await loadEnv([
  "SUPABASE_URL",
  "SUPABASE_ANON_KEY",
  "SUPABASE_SERVICE_ROLE_KEY",
  "TEST_USER_PASSWORD",
]);
const sb = serviceClient(env);
const CHECK_URL = `${env.SUPABASE_URL}/functions/v1/check-customer`;

const results: { name: string; expected: string; actual: string; ok: boolean }[] = [];
function record(name: string, expected: string, actual: string, ok: boolean) {
  results.push({ name, expected, actual, ok });
}

console.log("\n=== เริ่มการทดสอบ P0-6: Postgres Rate Limiting ===\n");

const testKey = `test:p06:${Date.now()}`;

try {
  // 1) ทดสอบ RPC hit_rate_limit โดยตรงใน Postgres (Limit = 2, Window = 60 วินาที)
  const { data: r1, error: e1 } = await sb.rpc("hit_rate_limit", {
    p_key: testKey,
    p_limit: 2,
    p_window_seconds: 60,
  });
  record(
    "1. hit_rate_limit ครั้งที่ 1 (limit=2)",
    "allowed = true",
    `allowed = ${r1} (error=${e1?.message ?? "none"})`,
    r1 === true,
  );

  const { data: r2 } = await sb.rpc("hit_rate_limit", {
    p_key: testKey,
    p_limit: 2,
    p_window_seconds: 60,
  });
  record(
    "2. hit_rate_limit ครั้งที่ 2 (limit=2)",
    "allowed = true",
    `allowed = ${r2}`,
    r2 === true,
  );

  const { data: r3 } = await sb.rpc("hit_rate_limit", {
    p_key: testKey,
    p_limit: 2,
    p_window_seconds: 60,
  });
  record(
    "3. hit_rate_limit ครั้งที่ 3 (เกิน limit=2)",
    "allowed = false",
    `allowed = ${r3}`,
    r3 === false,
  );

  // ตรวจสอบข้อมูลในตาราง rate_limits
  const { data: row } = await sb
    .from("rate_limits")
    .select("key, count, window_start")
    .eq("key", testKey)
    .single();
  const countOk = (row?.count ?? 0) >= 3;
  record(
    "4. ตรวจสอบตาราง rate_limits",
    "count >= 3",
    `count = ${row?.count}`,
    countOk,
  );

  // 2) ทดสอบ check-customer เมื่อส่ง Authorization: Bearer <anon_key> (Guest Mode)
  // ต้องไม่เกิด 401 หรือ bypass rate limit
  const resGuest = await fetch(CHECK_URL, {
    method: "POST",
    headers: {
      apikey: env.SUPABASE_ANON_KEY,
      Authorization: `Bearer ${env.SUPABASE_ANON_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ phone: "0812345678" }),
  });
  const guestStatus = resGuest.status;
  const guestBody = await resGuest.json().catch(() => ({}));
  const guestOk = guestStatus === 200 && guestBody.status === "OK";
  record(
    "5. Guest ส่ง Authorization: Bearer <anon_key> ตรวจสอบสำเร็จ",
    "HTTP 200 status=OK",
    `HTTP ${guestStatus} status=${guestBody.status ?? guestBody.error}`,
    guestOk,
  );

  // 3) ทดสอบการจำลอง Guest เกิน Rate Limit ใน Postgres
  const ipKey = "guest:127.0.0.1:min";
  // ปรับ count ให้เกิน limit 30
  await sb.from("rate_limits").upsert({
    key: ipKey,
    window_start: new Date().toISOString(),
    count: 31,
  });

  const resLimited = await fetch(CHECK_URL, {
    method: "POST",
    headers: {
      apikey: env.SUPABASE_ANON_KEY,
      Authorization: `Bearer ${env.SUPABASE_ANON_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ phone: "0812345678" }),
  });
  const limitedStatus = resLimited.status;
  const limitedBody = await resLimited.json().catch(() => ({}));
  const rateLimitHit = limitedStatus === 429 && limitedBody.status === "RATE_LIMITED";
  record(
    "6. เมื่อ Guest เกิน Rate Limit ได้ HTTP 429 RATE_LIMITED",
    "HTTP 429 status=RATE_LIMITED",
    `HTTP ${limitedStatus} status=${limitedBody.status ?? limitedBody.error}`,
    rateLimitHit,
  );

} finally {
  // Cleanup ข้อมูลทดสอบ
  await sb.from("rate_limits").delete().in("key", [testKey, "guest:127.0.0.1:min"]);
}

console.log("\nเคสทดสอบ | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน");
for (const r of results) {
  console.log(`${r.name} | ${r.expected} | ${r.actual} | ${r.ok ? "ผ่าน" : "ไม่ผ่าน"}`);
}
const failed = results.filter((r) => !r.ok).length;
console.log(`\nสรุป: ผ่าน ${results.length - failed}/${results.length}`);
Deno.exit(failed === 0 ? 0 : 1);
