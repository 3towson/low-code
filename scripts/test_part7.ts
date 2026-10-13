// ทดสอบส่วนที่ 7: Edge Function report-customer
// deploy function และตั้ง secrets ก่อน (รัน seed_test.ts แล้ว) จากนั้นรัน:
// deno run --allow-net --allow-read --allow-env scripts/test_part7.ts

import { createClient } from "npm:@supabase/supabase-js@2";
import { hashPhone } from "../supabase/functions/_shared/phone.ts";
import { findTestUsers, loadEnv, serviceClient } from "./_env.ts";

const env = await loadEnv([
  "SUPABASE_URL",
  "SUPABASE_ANON_KEY",
  "SUPABASE_SERVICE_ROLE_KEY",
  "TEST_USER_PASSWORD",
  "PHONE_HASH_SECRET",
]);
const FN_URL = `${env.SUPABASE_URL}/functions/v1/report-customer`;
const PHONE_A = "0800009999";
const PHONE_B = "0800009998";

const results: { name: string; expected: string; actual: string; ok: boolean }[] = [];

function record(name: string, expected: string, actual: string, ok: boolean) {
  results.push({ name, expected, actual, ok });
}

const sb = serviceClient(env);
const users = await findTestUsers(sb);
const shop1Id = users.get("shop1@test.local");
const shop2Id = users.get("shop2@test.local");
if (!shop1Id || !shop2Id) {
  console.log("FAIL  ไม่พบผู้ใช้ทดสอบ shop1/shop2 ให้รัน seed_test.ts ก่อน");
  Deno.exit(1);
}
const hashA = await hashPhone(PHONE_A, env.PHONE_HASH_SECRET);
const hashB = await hashPhone(PHONE_B, env.PHONE_HASH_SECRET);

async function cleanup(): Promise<number> {
  const { error, count } = await sb
    .from("cod_reports")
    .delete({ count: "exact" })
    .in("phone_hash", [hashA, hashB]);
  if (error) throw new Error(`ลบข้อมูลทดสอบล้มเหลว: ${error.message}`);
  return count ?? 0;
}

// ล้างข้อมูลค้างจากการรันครั้งก่อน ไม่งั้นจะติด trigger กันรายงานซ้ำ
await cleanup();

// login เป็น shop1 เพื่อเอา access token
const user = createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const { data: login, error: loginError } = await user.auth.signInWithPassword({
  email: "shop1@test.local",
  password: env.TEST_USER_PASSWORD,
});
if (loginError || !login.session) {
  console.log(`FAIL  login shop1: ${loginError?.message ?? "ไม่มี session"}`);
  Deno.exit(1);
}
const token = login.session.access_token;

type Res = { status: number; body: Record<string, unknown> | null };

async function call(body: unknown, withToken = true): Promise<Res> {
  const headers: Record<string, string> = {
    apikey: env.SUPABASE_ANON_KEY,
    "content-type": "application/json",
  };
  if (withToken) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(FN_URL, { method: "POST", headers, body: JSON.stringify(body) });
  const raw = await res.text();
  let parsed: Record<string, unknown> | null = null;
  try {
    parsed = JSON.parse(raw);
  } catch { /* ไม่ใช่ JSON */ }
  return { status: res.status, body: parsed };
}

// อัปโหลดไฟล์หลักฐานจำลองสำหรับ shop1
const dummyFile = new Uint8Array([0xff, 0xd8, 0xff, 0xe0]);
await sb.storage.from("report-evidences").upload(`${shop1Id}/test_proof.jpg`, dummyFile, {
  contentType: "image/jpeg",
  upsert: true,
});

const valid = {
  customer_name: "  สมชาย ทดสอบ  ",
  phone: PHONE_A,
  platform: "shopee",
  reason: "refused_delivery",
  amount: 350,
  evidence_paths: [`${shop1Id}/test_proof.jpg`],
};

function errorFields(r: Res): string[] {
  const errors = r.body?.errors;
  return Array.isArray(errors) ? errors.map((e) => String((e as { field?: unknown }).field)) : [];
}

function summary(r: Res): string {
  const b = r.body ?? {};
  const parts = [`HTTP ${r.status}`, String(b.status ?? b.error ?? "")];
  const errors = Array.isArray(b.errors) ? (b.errors as { field: string; message: string }[]) : [];
  for (const e of errors) parts.push(`${e.field}: ${e.message}`);
  if (b.message) parts.push(String(b.message));
  return parts.filter(Boolean).join(" ");
}

async function expect400(name: string, body: unknown, field: string) {
  const r = await call(body);
  const fields = errorFields(r);
  record(
    name,
    `400 field=${field}`,
    summary(r),
    r.status === 400 && fields.length === 1 && fields[0] === field,
  );
}

async function fetchRows(hash: string) {
  const { data, error } = await sb.from("cod_reports").select("*").eq("phone_hash", hash);
  if (error) throw new Error(`อ่าน cod_reports ล้มเหลว: ${error.message}`);
  return data as Record<string, unknown>[];
}

// 1) ไม่แนบ token
{
  const r = await call(valid, false);
  record("ไม่แนบ token", "401", summary(r), r.status === 401);
}

// 1.1 - 1.5) P0-5: การตรวจ KYC ใน report-customer (Fail-Closed)
// เกณฑ์ผ่าน: เพิ่มเคสใน test_part7.ts ให้ร้าน unverified, pending และร้านที่ไม่มีแถวใน sellers ได้ 403 ทั้งหมด

// A) unverified ได้ 403 UNVERIFIED_MERCHANT
await sb.from("sellers").update({ verification_status: "unverified" }).eq("id", shop1Id);
{
  const r = await call(valid);
  record(
    "KYC: ร้านค้า unverified ได้ 403 (Fail-closed)",
    "403 UNVERIFIED_MERCHANT",
    summary(r),
    r.status === 403 && r.body?.status === "UNVERIFIED_MERCHANT",
  );
}

// B) pending ได้ 403 UNVERIFIED_MERCHANT
await sb.from("sellers").update({ verification_status: "pending" }).eq("id", shop1Id);
{
  const r = await call(valid);
  record(
    "KYC: ร้านค้า pending ได้ 403 (Fail-closed)",
    "403 UNVERIFIED_MERCHANT",
    summary(r),
    r.status === 403 && r.body?.status === "UNVERIFIED_MERCHANT",
  );
}

// C) rejected ได้ 403 UNVERIFIED_MERCHANT
await sb.from("sellers").update({ verification_status: "rejected" }).eq("id", shop1Id);
{
  const r = await call(valid);
  record(
    "KYC: ร้านค้า rejected ได้ 403 (Fail-closed)",
    "403 UNVERIFIED_MERCHANT",
    summary(r),
    r.status === 403 && r.body?.status === "UNVERIFIED_MERCHANT",
  );
}

// D) suspended ได้ 403 SUSPENDED_MERCHANT (P0-4)
await sb.from("sellers").update({ verification_status: "suspended" }).eq("id", shop1Id);
{
  const r = await call(valid);
  record(
    "KYC: ร้านค้า suspended ได้ 403 SUSPENDED_MERCHANT",
    "403 SUSPENDED_MERCHANT",
    summary(r),
    r.status === 403 && r.body?.status === "SUSPENDED_MERCHANT",
  );
}

// E) ไม่มีแถวใน sellers ได้ 403 UNVERIFIED_MERCHANT (Fail-closed)
const { data: savedSeller } = await sb.from("sellers").select("*").eq("id", shop1Id).single();
await sb.from("sellers").delete().eq("id", shop1Id);
{
  const r = await call(valid);
  record(
    "KYC: ร้านค้าที่ไม่มีแถวใน sellers ได้ 403 (Fail-closed)",
    "403 UNVERIFIED_MERCHANT",
    summary(r),
    r.status === 403 && r.body?.status === "UNVERIFIED_MERCHANT",
  );
}
// คืนค่าแถว sellers เดิม
if (savedSeller) {
  await sb.from("sellers").insert(savedSeller);
}

// ตั้งค่ากลับเป็น approved เพื่อให้ shop1 สามารถทดสอบขั้นตอนถัดไปได้
await sb.from("sellers").update({ verification_status: "approved" }).eq("id", shop1Id);

// 2-5) ตรวจความถูกต้อง
await expect400("phone ผิดรูปแบบ (12345)", { ...valid, phone: "12345" }, "phone");
await expect400('customer_name มีเบอร์โทร', { ...valid, customer_name: "สมชาย 0812345678" }, "customer_name");
await expect400("amount = -5", { ...valid, amount: -5 }, "amount");
await expect400("ไม่มี evidence_path", { ...valid, evidence_paths: [] }, "evidence_path");

// 6) ข้อมูลถูกต้อง แล้วตรวจแถวที่เพิ่มด้วย service role
{
  const r = await call(valid);
  record("ข้อมูลถูกต้อง", "201 CREATED", summary(r), r.status === 201 && r.body?.status === "CREATED");

  const rows = await fetchRows(hashA);
  const row = rows[0];
  const problems: string[] = [];
  if (rows.length !== 1) problems.push(`พบ ${rows.length} แถว`);
  if (row) {
    if (row.phone_hash !== hashA) problems.push("phone_hash ไม่ตรง");
    if (row.reported_by !== shop1Id) problems.push("reported_by ไม่ใช่ shop1");
    // P0-3: customer_name ในฐานข้อมูลต้องเป็น null (หรือ legacy string)
    if (row.customer_name !== null && row.customer_name !== "สมชาย ทดสอบ") problems.push("customer_name ไม่ถูกต้อง");
    const raw = JSON.stringify(row);
    const leaked = [PHONE_A, PHONE_A.slice(1), "66" + PHONE_A.slice(1)].some((p) => raw.includes(p));
    if (leaked) problems.push("พบเบอร์จริงในแถว");
  }
  record(
    "ตรวจแถวที่เพิ่ม (service role)",
    "1 แถว phone_hash ตรง, ไม่มีเบอร์จริง, reported_by=shop1",
    problems.length ? problems.join("; ") : "ถูกต้องทุกข้อ",
    problems.length === 0,
  );
}

// 7) ส่งซ้ำทันที
{
  const r = await call(valid);
  record(
    "ส่งซ้ำทันที",
    "409 DUPLICATE",
    summary(r),
    r.status === 409 && r.body?.status === "DUPLICATE" &&
      r.body?.message === "คุณรายงานเบอร์นี้ไปแล้วในช่วง 7 วันที่ผ่านมา",
  );
  const rows = await fetchRows(hashA);
  record("ส่งซ้ำไม่เพิ่มแถว", "ยังมี 1 แถว", `${rows.length} แถว`, rows.length === 1);
}

// 8) พยายามปลอม reported_by เป็น shop2
{
  const r = await call({ ...valid, phone: PHONE_B, reported_by: shop2Id });
  const rows = await fetchRows(hashB);
  const who = rows.map((x) => (x.reported_by === shop1Id ? "shop1" : x.reported_by === shop2Id ? "shop2" : "อื่น"));
  record(
    "body มี reported_by = shop2",
    "201, แถวมี reported_by=shop1",
    `${summary(r)}, ${rows.length} แถว reported_by=${who.join(",") || "-"}`,
    r.status === 201 && rows.length === 1 && rows[0].reported_by === shop1Id,
  );
}

await user.auth.signOut();

// 9) ลบข้อมูลทดสอบ
{
  await sb.storage.from("report-evidences").remove([`${shop1Id}/test_proof.jpg`]);
  const deleted = await cleanup();
  const left = (await fetchRows(hashA)).length + (await fetchRows(hashB)).length;
  record("ลบข้อมูลเบอร์ทดสอบ", "ลบ 2 แถว เหลือ 0", `ลบ ${deleted} แถว เหลือ ${left}`, deleted === 2 && left === 0);
}

console.log("เคสทดสอบ | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน");
for (const r of results) {
  console.log(`${r.name} | ${r.expected} | ${r.actual} | ${r.ok ? "ผ่าน" : "ไม่ผ่าน"}`);
}
const failed = results.filter((r) => !r.ok).length;
console.log(`\nสรุป: ผ่าน ${results.length - failed}/${results.length}`);
Deno.exit(failed === 0 ? 0 : 1);
