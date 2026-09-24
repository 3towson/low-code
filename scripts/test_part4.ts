// ทดสอบส่วนที่ 4: ข้อมูลใน cod_reports หลัง seed_demo.ts
// รัน seed_test.ts และ seed_demo.ts ก่อน แล้วรัน:
// deno run --allow-net --allow-read --allow-env scripts/test_part4.ts

import { hashPhone, maskPhone, normalizeThaiPhone } from "../supabase/functions/_shared/phone.ts";
import { loadEnv, serviceClient } from "./_env.ts";
import { DEMO_PHONES } from "./_demo.ts";

const env = await loadEnv(["SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY", "PHONE_HASH_SECRET"]);
const sb = serviceClient(env);

type RiskRow = { level: string; counted_reports: number; last_report_at: string | null };

const results: { name: string; expected: string; actual: string; ok: boolean }[] = [];

function record(name: string, expected: string, actual: string, ok: boolean) {
  results.push({ name, expected, actual, ok });
}

// เบอร์มือถือไทย 10 หลัก ทั้งแบบติดกันและมีตัวคั่น รวม +66/66 และเลขไทย
// ขอบเขตเป็นตัวอักษร/ตัวเลขละติน จึงไม่จับเลขที่อยู่กลาง hex hash หรือ uuid
const PHONE_IN_TEXT =
  /(?<![0-9A-Za-z])(?:\+?66|0)[\s\-.()]*[689](?:[\s\-.()]*\d){8}(?![0-9A-Za-z])/;
const toArabic = (s: string) => s.replace(/[๐-๙]/g, (c) => String(c.charCodeAt(0) - 0x0e50));

// 1) อ่านทุกแถวใน cod_reports
const rows: Record<string, unknown>[] = [];
for (let from = 0; ; from += 1000) {
  const { data, error } = await sb.from("cod_reports").select("*").range(from, from + 999);
  if (error) {
    console.log(`FAIL  อ่าน cod_reports: ${error.message}`);
    Deno.exit(1);
  }
  rows.push(...data);
  if (data.length < 1000) break;
}

// 2) phone_hash ของแถวที่ไม่ใช่ TEST_HASH_ ต้องเป็น hex 64 ตัว
{
  const real = rows.filter((r) => !String(r.phone_hash).startsWith("TEST_HASH_"));
  const bad = real.filter((r) => !/^[0-9a-f]{64}$/.test(String(r.phone_hash)));
  record(
    `phone_hash เป็น hex 64 ตัว (${real.length} แถวที่ไม่ใช่ TEST_HASH_)`,
    "ผิดรูปแบบ 0 แถว",
    `ผิดรูปแบบ ${bad.length} แถว`,
    real.length > 0 && bad.length === 0,
  );
}

// 3) ไม่มีเบอร์โทร 10 หลักในคอลัมน์ใดของทุกแถว
{
  const hits: string[] = [];
  for (const r of rows) {
    for (const [col, value] of Object.entries(r)) {
      if (value == null) continue;
      if (PHONE_IN_TEXT.test(toArabic(String(value)))) hits.push(`${r.id}.${col}`);
    }
  }
  record(
    `ไม่มีเบอร์โทร 10 หลักในทุกคอลัมน์ (${rows.length} แถว)`,
    "พบ 0 ค่า",
    hits.length ? `พบ ${hits.length} ค่า: ${hits.slice(0, 3).join(", ")}` : "พบ 0 ค่า",
    hits.length === 0,
  );
}

// 4) get_risk_level ของเบอร์สาธิต
for (const d of DEMO_PHONES) {
  const normalized = normalizeThaiPhone(d.phone)!;
  const name = `get_risk_level ${maskPhone(normalized)} (${d.reports.length} รายงานใน seed)`;
  const hash = await hashPhone(normalized, env.PHONE_HASH_SECRET);
  const { data, error } = await sb
    .rpc("get_risk_level", { p_phone_hash: hash })
    .single<RiskRow>();
  if (error) {
    record(name, d.expected, `error: ${error.code} ${error.message}`, false);
    continue;
  }
  const actual = `${data.level} (นับ ${data.counted_reports}, ล่าสุด ${
    data.last_report_at ? data.last_report_at.slice(0, 10) : "-"
  })`;
  record(name, d.expected, actual, data.level === d.expected && data.counted_reports === d.reports.length);
}

console.log("เคสทดสอบ | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน");
for (const r of results) {
  console.log(`${r.name} | ${r.expected} | ${r.actual} | ${r.ok ? "ผ่าน" : "ไม่ผ่าน"}`);
}
const failed = results.filter((r) => !r.ok).length;
console.log(`\nสรุป: ผ่าน ${results.length - failed}/${results.length}`);
Deno.exit(failed === 0 ? 0 : 1);
