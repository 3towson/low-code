// ทดสอบส่วนที่ 11: End-to-End ผ่าน Edge Functions จริง (check-customer, report-customer)
// deploy function ทั้งสองและตั้ง secrets ก่อน จากนั้นรัน:
// deno run --allow-net --allow-read --allow-env scripts/e2e_test.ts
//
// สร้างผู้ใช้ e2e_x, e2e_y, e2e_z, e2e_w @test.local ใหม่ทุกครั้ง (รหัสผ่านสุ่ม ไม่พิมพ์ออกมา)
// x และ z อายุบัญชี 30 วัน, w เป็นบัญชีใหม่, y เป็นผู้ตรวจ
// เบอร์ P1, P2 สุ่มจาก 0800010000-0800019999 ที่ยังไม่มีรายงานในระบบ
// ลบรายงานและผู้ใช้ e2e ทั้งหมดเมื่อจบ แม้ขั้นตอนใดล้มเหลว

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import { hashPhone, maskPhone } from "../supabase/functions/_shared/phone.ts";
import { loadEnv, serviceClient } from "./_env.ts";

const env = await loadEnv([
  "SUPABASE_URL",
  "SUPABASE_ANON_KEY",
  "SUPABASE_SERVICE_ROLE_KEY",
  "PHONE_HASH_SECRET",
]);
const CHECK_URL = `${env.SUPABASE_URL}/functions/v1/check-customer`;
const REPORT_URL = `${env.SUPABASE_URL}/functions/v1/report-customer`;
const DAY_MS = 24 * 60 * 60 * 1000;

const USERS = [
  { key: "x", email: "e2e_x@test.local", ageDays: 30 },
  { key: "y", email: "e2e_y@test.local", ageDays: 0 },
  { key: "z", email: "e2e_z@test.local", ageDays: 30 },
  { key: "w", email: "e2e_w@test.local", ageDays: 0 },
] as const;
type UserKey = (typeof USERS)[number]["key"];

// ฟิลด์ที่ check-customer ส่งกลับได้ (ห้ามมี hash หรือข้อมูลผู้รายงาน)
const ALLOWED_CHECK_FIELDS = new Set([
  "status",
  "level",
  "counted_reports",
  "recommendation",
  "customer_name",
  "phone_masked",
  "ai_unavailable",
]);

type Row = { step: string; action: string; expected: string; actual: string; ok: boolean };
const results: Row[] = [];
const record = (step: string, action: string, expected: string, actual: string, ok: boolean) =>
  results.push({ step, action, expected, actual, ok });

const sb = serviceClient(env);
const ids = {} as Record<UserKey, string>;
const tokens = {} as Record<UserKey, string>;
const hashes: string[] = [];

// ---------------------------------------------------------------------------
// ผู้ใช้
// ---------------------------------------------------------------------------

async function findE2eUsers(client: SupabaseClient): Promise<Map<string, string>> {
  const wanted = new Set<string>(USERS.map((u) => u.email));
  const found = new Map<string, string>();
  for (let page = 1; ; page++) {
    const { data, error } = await client.auth.admin.listUsers({ page, perPage: 1000 });
    if (error) throw new Error(`listUsers ล้มเหลว: ${error.message}`);
    for (const u of data.users) {
      const email = u.email?.toLowerCase();
      if (email && wanted.has(email)) found.set(email, u.id);
    }
    if (data.users.length < 1000) break;
  }
  return found;
}

/** ลบรายงานของผู้ใช้ e2e และของเบอร์ P1/P2 แล้วลบผู้ใช้ e2e ทั้งหมด (sellers ลบตาม cascade) */
async function cleanup(): Promise<{ reports: number; users: number }> {
  const userIds = [...(await findE2eUsers(sb)).values()];
  let reports = 0;
  if (userIds.length) {
    const { error, count } = await sb
      .from("cod_reports")
      .delete({ count: "exact" })
      .in("reported_by", userIds);
    if (error) throw new Error(`ลบรายงานของผู้ใช้ e2e ล้มเหลว: ${error.message}`);
    reports += count ?? 0;
  }
  if (hashes.length) {
    const { error, count } = await sb
      .from("cod_reports")
      .delete({ count: "exact" })
      .in("phone_hash", hashes);
    if (error) throw new Error(`ลบรายงานของเบอร์ทดสอบล้มเหลว: ${error.message}`);
    reports += count ?? 0;
  }
  for (const id of userIds) {
    const { error } = await sb.auth.admin.deleteUser(id);
    if (error) throw new Error(`ลบผู้ใช้ e2e ล้มเหลว: ${error.message}`);
  }
  return { reports, users: userIds.length };
}

async function setup() {
  const password = `${crypto.randomUUID()}-Aa1!`;
  const problems: string[] = [];

  for (const u of USERS) {
    const { data, error } = await sb.auth.admin.createUser({
      email: u.email,
      password,
      email_confirm: true,
      user_metadata: { shop_name: `ร้าน E2E ${u.key.toUpperCase()}` },
    });
    if (error || !data.user) throw new Error(`สร้าง ${u.email} ล้มเหลว: ${error?.message ?? "ไม่มีข้อมูล"}`);
    ids[u.key] = data.user.id;
    if (!data.user.email_confirmed_at) problems.push(`${u.key} ยังไม่ยืนยันอีเมล`);

    if (u.ageDays > 0) {
      const { data: rows, error: upError } = await sb
        .from("sellers")
        .update({ created_at: new Date(Date.now() - u.ageDays * DAY_MS).toISOString() })
        .eq("id", data.user.id)
        .select("id");
      if (upError || rows?.length !== 1) {
        throw new Error(`แก้ sellers.created_at ของ ${u.key} ล้มเหลว: ${upError?.message ?? "ไม่พบแถว"}`);
      }
    }

    const anon = createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: login, error: loginError } = await anon.auth.signInWithPassword({
      email: u.email,
      password,
    });
    if (loginError || !login.session) {
      throw new Error(`login ${u.key} ล้มเหลว: ${loginError?.message ?? "ไม่มี session"}`);
    }
    tokens[u.key] = login.session.access_token;
  }

  // ตรวจอายุบัญชีจากฐานข้อมูลจริง
  const { data: sellers, error } = await sb
    .from("sellers")
    .select("id, created_at")
    .in("id", Object.values(ids));
  if (error) throw new Error(`อ่าน sellers ล้มเหลว: ${error.message}`);
  const ageOf = (key: UserKey) => {
    const s = sellers?.find((r) => r.id === ids[key]);
    return s ? Math.round((Date.now() - Date.parse(s.created_at)) / DAY_MS) : NaN;
  };
  const ages = USERS.map((u) => `${u.key}=${ageOf(u.key)}`).join(", ");
  const agesOk = USERS.every((u) => ageOf(u.key) === u.ageDays);
  record(
    "0",
    "สร้างผู้ใช้ 4 คน (ยืนยันอีเมล) และตั้งอายุบัญชี",
    "x=30, y=0, z=30, w=0 วัน, login ได้ทุกคน",
    `อายุบัญชี ${ages}${problems.length ? `; ${problems.join("; ")}` : ""}`,
    agesOk && problems.length === 0,
  );
}

// ---------------------------------------------------------------------------
// เบอร์ทดสอบ
// ---------------------------------------------------------------------------

async function pickUnusedPhones(n: number): Promise<string[]> {
  const picked: string[] = [];
  for (let attempt = 0; picked.length < n && attempt < 50; attempt++) {
    const phone = `080001${String(Math.floor(Math.random() * 10000)).padStart(4, "0")}`;
    if (picked.includes(phone)) continue;
    const hash = await hashPhone(phone, env.PHONE_HASH_SECRET);
    const { count, error } = await sb
      .from("cod_reports")
      .select("id", { count: "exact", head: true })
      .eq("phone_hash", hash);
    if (error) throw new Error(`ตรวจเบอร์ในระบบล้มเหลว: ${error.message}`);
    if (count === 0) {
      picked.push(phone);
      hashes.push(hash);
    }
  }
  if (picked.length < n) throw new Error("หาเบอร์ที่ยังไม่มีในระบบไม่ได้");
  return picked;
}

// ---------------------------------------------------------------------------
// เรียก Edge Functions
// ---------------------------------------------------------------------------

type Res = { status: number; body: Record<string, unknown> | null };

async function post(url: string, who: UserKey, body: unknown): Promise<Res> {
  const res = await fetch(url, {
    method: "POST",
    headers: {
      apikey: env.SUPABASE_ANON_KEY,
      Authorization: `Bearer ${tokens[who]}`,
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
  const raw = await res.text();
  let parsed: Record<string, unknown> | null = null;
  try {
    parsed = JSON.parse(raw);
  } catch { /* ไม่ใช่ JSON */ }
  return { status: res.status, body: parsed };
}

async function report(step: string, who: UserKey, phone: string, expectStatus: 201 | 409) {
  const r = await post(REPORT_URL, who, {
    customer_name: `ลูกค้า E2E ${step}`,
    phone,
    platform: "facebook",
    reason: "refused_delivery",
    amount: 250,
  });
  const expectedBody = expectStatus === 201 ? "CREATED" : "DUPLICATE";
  record(
    step,
    `${who.toUpperCase()} รายงาน ${maskPhone(phone)}`,
    `${expectStatus} ${expectedBody}`,
    `${r.status} ${r.body?.status ?? r.body?.error ?? ""}`.trim(),
    r.status === expectStatus && r.body?.status === expectedBody,
  );
}

async function check(
  step: string,
  who: UserKey,
  phone: string,
  level: "green" | "yellow" | "red",
  counted: number,
) {
  const r = await post(CHECK_URL, who, { phone });
  const b = r.body ?? {};
  const extra = Object.keys(b).filter((k) => !ALLOWED_CHECK_FIELDS.has(k));
  const ok = r.status === 200 && b.status === "OK" && b.level === level &&
    b.counted_reports === counted && b.phone_masked === maskPhone(phone) && extra.length === 0;
  const actual = r.status === 200
    ? `200 ${b.level} (${b.counted_reports} รายงาน)${extra.length ? ` ฟิลด์เกิน: ${extra.join(",")}` : ""}`
    : `${r.status} ${b.error ?? b.status ?? ""}`;
  record(step, `${who.toUpperCase()} ตรวจ ${maskPhone(phone)}`, `200 ${level} (${counted} รายงาน)`, actual, ok);
}

// ---------------------------------------------------------------------------
// ลำดับการทดสอบ
// ---------------------------------------------------------------------------

let fatal: string | null = null;
try {
  const leftover = await cleanup();
  if (leftover.users || leftover.reports) {
    console.log(`OK    ล้างของค้างจากรอบก่อน: ผู้ใช้ ${leftover.users} คน, รายงาน ${leftover.reports} แถว`);
  }

  await setup();
  const [P1, P2] = await pickUnusedPhones(2);
  record("0", "สุ่มเบอร์ P1, P2 ที่ยังไม่มีในระบบ", "2 เบอร์ไม่ซ้ำ", `P1=${maskPhone(P1)}, P2=${maskPhone(P2)}`, P1 !== P2);

  // 1
  await check("1", "y", P1, "green", 0);
  // 2
  await report("2", "x", P1, 201);
  await check("2", "y", P1, "yellow", 1);
  // 3
  await report("3", "x", P1, 409);
  // 4
  await report("4", "z", P1, 201);
  await check("4", "y", P1, "red", 2);
  // 5 (W อายุบัญชีไม่ถึง 7 วัน จึงไม่นับเป็นรายงานเกณฑ์แดง)
  await report("5", "x", P2, 201);
  await report("5", "w", P2, 201);
  await check("5", "y", P2, "yellow", 2);
} catch (e) {
  fatal = e instanceof Error ? e.message : String(e);
  record("-", "ขั้นตอนหยุดกลางทาง", "ไม่มี error", fatal, false);
} finally {
  try {
    const { reports, users } = await cleanup();
    const left = await findE2eUsers(sb);
    let leftReports = 0;
    if (hashes.length) {
      const { count } = await sb
        .from("cod_reports")
        .select("id", { count: "exact", head: true })
        .in("phone_hash", hashes);
      leftReports = count ?? 0;
    }
    record(
      "ลบ",
      "ลบรายงานและผู้ใช้ e2e",
      "เหลือผู้ใช้ 0, รายงาน P1/P2 0",
      `ลบรายงาน ${reports} แถว, ผู้ใช้ ${users} คน; เหลือผู้ใช้ ${left.size}, รายงาน ${leftReports}`,
      left.size === 0 && leftReports === 0,
    );
  } catch (e) {
    record("ลบ", "ลบรายงานและผู้ใช้ e2e", "สำเร็จ", e instanceof Error ? e.message : String(e), false);
  }
}

console.log("\nขั้น | การกระทำ | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน");
for (const r of results) {
  console.log(`${r.step} | ${r.action} | ${r.expected} | ${r.actual} | ${r.ok ? "ผ่าน" : "ไม่ผ่าน"}`);
}
const failed = results.filter((r) => !r.ok).length;
console.log(`\nสรุป: ผ่าน ${results.length - failed}/${results.length}`);
Deno.exit(failed === 0 ? 0 : 1);
