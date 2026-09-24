// ทดสอบส่วนที่ 6: Edge Function check-customer
// deploy function และตั้ง secrets ก่อน (รัน seed_test.ts และ seed_demo.ts แล้ว) จากนั้นรัน:
// deno run --allow-net --allow-read --allow-env scripts/test_part6.ts

import { createClient } from "npm:@supabase/supabase-js@2";
import { loadEnv, serviceClient } from "./_env.ts";

const env = await loadEnv([
  "SUPABASE_URL",
  "SUPABASE_ANON_KEY",
  "SUPABASE_SERVICE_ROLE_KEY",
  "TEST_USER_PASSWORD",
]);
const FN_URL = `${env.SUPABASE_URL}/functions/v1/check-customer`;
const ALLOWED_KEYS = [
  "status",
  "level",
  "counted_reports",
  "recommendation",
  "customer_name",
  "phone_masked",
  "ai_unavailable",
].sort();

const results: { name: string; expected: string; actual: string; ok: boolean }[] = [];

function record(name: string, expected: string, actual: string, ok: boolean) {
  results.push({ name, expected, actual, ok });
}

// login เป็น shop3 เพื่อเอา access token
const user = createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const { data: login, error: loginError } = await user.auth.signInWithPassword({
  email: "shop3@test.local",
  password: env.TEST_USER_PASSWORD,
});
if (loginError || !login.session) {
  console.log(`FAIL  login shop3: ${loginError?.message ?? "ไม่มี session"}`);
  Deno.exit(1);
}
const token = login.session.access_token;

// อีเมลและชื่อร้านทั้งหมด ใช้ตรวจว่าไม่รั่วออกไปใน response
const sb = serviceClient(env);
const reporterStrings: string[] = [];
{
  const { data, error } = await sb.from("sellers").select("shop_name");
  if (error) {
    console.log(`FAIL  อ่าน sellers: ${error.message}`);
    Deno.exit(1);
  }
  reporterStrings.push(...data.map((s) => s.shop_name as string));
  for (let page = 1; ; page++) {
    const { data: users, error: e } = await sb.auth.admin.listUsers({ page, perPage: 1000 });
    if (e) {
      console.log(`FAIL  listUsers: ${e.message}`);
      Deno.exit(1);
    }
    for (const u of users.users) if (u.email) reporterStrings.push(u.email.toLowerCase());
    if (users.users.length < 1000) break;
  }
}

type Res = { status: number; raw: string; body: Record<string, unknown> | null };

async function call(body: string | null, withToken = true, method = "POST"): Promise<Res> {
  const headers: Record<string, string> = { apikey: env.SUPABASE_ANON_KEY };
  if (withToken) headers.Authorization = `Bearer ${token}`;
  if (body !== null) headers["content-type"] = "application/json";
  const res = await fetch(FN_URL, { method, headers, body: body ?? undefined });
  const raw = await res.text();
  let parsed: Record<string, unknown> | null = null;
  try {
    parsed = JSON.parse(raw);
  } catch { /* ไม่ใช่ JSON */ }
  return { status: res.status, raw, body: parsed };
}

const PHONE_IN_TEXT =
  /(?<![0-9A-Za-z])(?:\+?66|0)[\s\-.()]*[689](?:[\s\-.()]*\d){8}(?![0-9A-Za-z])/;
const EMAIL = /[^\s@"]+@[^\s@"]+\.[^\s@"]+/;
const okResponses: { name: string; res: Res }[] = [];

function summary(r: Res): string {
  if (!r.body) return `HTTP ${r.status}`;
  const b = r.body;
  const parts = [`HTTP ${r.status}`, String(b.status ?? b.error ?? "")];
  if (b.level) parts.push(`level=${b.level}`, `นับ ${b.counted_reports}`, String(b.phone_masked));
  if (b.status === "OK") parts.push(`ai_unavailable=${b.ai_unavailable}`);
  return parts.filter(Boolean).join(" ");
}

async function expectLevel(name: string, body: unknown, level: string) {
  const r = await call(JSON.stringify(body));
  if (r.body?.status === "OK") okResponses.push({ name, res: r });
  record(name, `200 OK level=${level}`, summary(r), r.status === 200 && r.body?.level === level);
}

// 1) CORS preflight
{
  const r = await fetch(FN_URL, {
    method: "OPTIONS",
    headers: {
      Origin: "http://localhost:3000",
      "Access-Control-Request-Method": "POST",
      "Access-Control-Request-Headers": "authorization, content-type",
    },
  });
  await r.body?.cancel();
  const allow = r.headers.get("access-control-allow-origin");
  record("OPTIONS preflight", "200 + Allow-Origin", `HTTP ${r.status} Allow-Origin=${allow}`, r.ok && allow === "*");
}

// 2) ไม่แนบ token
{
  const r = await call(JSON.stringify({ phone: "0800000001" }), false);
  record("ไม่แนบ token", "401", `HTTP ${r.status}`, r.status === 401);
}

// 3-6) ระดับความเสี่ยง
await expectLevel(
  "text มีเบอร์ 0800000003",
  { text: "สั่งเสื้อ 2 ตัว ผู้รับ สมชาย ใจดี โทร 0800000003 ที่อยู่ 12/3 ถ.สุขุมวิท กทม." },
  "red",
);
await expectLevel(
  "text มีเบอร์ 0800000001",
  { text: "ชื่อ: สมหญิง รักดี\nเบอร์: 080 000 0001\nที่อยู่: 45 หมู่ 2 อ.เมือง จ.เชียงใหม่" },
  "green",
);
await expectLevel('{ phone: "080-000-0002" }', { phone: "080-000-0002" }, "yellow");

// 7) เบอร์ไม่ถูกต้อง
{
  const r = await call(JSON.stringify({ phone: "12345" }));
  record(
    '{ phone: "12345" }',
    "400 INVALID_PHONE",
    summary(r),
    r.status === 400 && r.body?.status === "INVALID_PHONE",
  );
}

// 8) text ไม่มีเบอร์
{
  const r = await call(JSON.stringify({ text: "ขอสั่งกระเป๋าสีดำ 1 ใบ ส่งที่บ้านเลขที่ 99 ต.บางพลี" }));
  record(
    "text ไม่มีเบอร์",
    "200 NO_PHONE_DETECTED",
    summary(r),
    r.status === 200 && r.body?.status === "NO_PHONE_DETECTED",
  );
}

// 9) body ว่าง
for (const [name, body] of [["body ว่าง (ไม่มี body)", null], ["body ว่าง ({})", "{}"]] as const) {
  const r = await call(body);
  record(name, "400", summary(r), r.status === 400);
}

// 10) text ยาว 3,000 ตัวอักษร เบอร์อยู่ต้นข้อความ
{
  const head = "ผู้รับ มานี มีนา โทร 0800000003 ";
  const text = (head + "รายละเอียดสินค้า เสื้อยืดสีขาว ไซส์ L จำนวน 1 ตัว ".repeat(100)).slice(0, 3000);
  await expectLevel(`text ยาว ${text.length} ตัวอักษร เบอร์ต้นข้อความ`, { text }, "red");
}

// 11) ตรวจความเป็นส่วนตัวของทุก response ที่เป็น OK
for (const { name, res } of okResponses) {
  const problems: string[] = [];
  const keys = Object.keys(res.body ?? {}).sort();
  if (JSON.stringify(keys) !== JSON.stringify(ALLOWED_KEYS)) {
    problems.push(`ฟิลด์ไม่ตรง: ${keys.join(",")}`);
  }
  if (/[0-9a-f]{64}/i.test(res.raw)) problems.push("พบ hex 64 ตัว");
  if (EMAIL.test(res.raw)) problems.push("พบอีเมล");
  const lower = res.raw.toLowerCase();
  const leaked = reporterStrings.filter((s) => s && lower.includes(s.toLowerCase()));
  if (leaked.length) problems.push(`พบชื่อร้าน/อีเมล ${leaked.length} ค่า`);
  if (PHONE_IN_TEXT.test(res.raw)) problems.push("พบเบอร์ที่ไม่ได้ mask");
  if (!/^0\d{2}-XXX-\d{4}$/.test(String(res.body?.phone_masked))) problems.push("phone_masked ผิดรูปแบบ");
  record(
    `ความเป็นส่วนตัว: ${name}`,
    "ฟิลด์ที่อนุญาตเท่านั้น ไม่มี hash/อีเมล/ชื่อร้าน/เบอร์เต็ม",
    problems.length ? problems.join("; ") : "ผ่านทุกข้อ",
    problems.length === 0,
  );
}

await user.auth.signOut();

console.log("เคสทดสอบ | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน");
for (const r of results) {
  console.log(`${r.name} | ${r.expected} | ${r.actual} | ${r.ok ? "ผ่าน" : "ไม่ผ่าน"}`);
}
const failed = results.filter((r) => !r.ok).length;
console.log(`\nสรุป: ผ่าน ${results.length - failed}/${results.length}`);
Deno.exit(failed === 0 ? 0 : 1);
