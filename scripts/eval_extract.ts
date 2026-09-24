// ประเมิน extractOrderInfo กับ Gemini จริง ด้วย tests/fixtures/orders.json
// ใช้ GEMINI_API_KEY และ GEMINI_MODEL จาก .env (ห้ามพิมพ์ค่า key)
// รัน: deno run --allow-net --allow-read --allow-env scripts/eval_extract.ts

import {
  createGeminiClient,
  extractOrderInfo,
  type ExtractResult,
  type GeminiClient,
} from "../supabase/functions/_shared/extract.ts";
import { loadEnv } from "./_env.ts";

type Fixture = {
  id: string;
  label: string;
  text: string;
  expected_name: string | null;
  expected_phone: string | null;
};

const DELAY_MS = 7000;

const env = await loadEnv(["GEMINI_API_KEY", "GEMINI_MODEL"]);
const real = createGeminiClient({ apiKey: env.GEMINI_API_KEY, model: env.GEMINI_MODEL });

// เก็บสาเหตุที่ Gemini ใช้งานไม่ได้ (HTTP 429/503, timeout, JSON ผิดรูปแบบ) ไว้แสดงในตาราง
let lastAiError: string | null = null;
let lastAiResponded = false;
const client: GeminiClient = {
  async generateContent(req, signal) {
    try {
      const raw = await real.generateContent(req, signal);
      lastAiResponded = true;
      return raw;
    } catch (e) {
      lastAiError = e instanceof Error ? e.message : String(e);
      throw e;
    }
  },
};
const fixtures: Fixture[] = JSON.parse(
  await Deno.readTextFile(new URL("../tests/fixtures/orders.json", import.meta.url)),
);

// เทียบชื่อแบบไม่สนคำนำหน้า ช่องว่าง และตัวพิมพ์เล็กใหญ่
const HONORIFIC = /^(คุณ|นางสาว|นาง|นาย|น\.ส\.|mr\.?|mrs\.?|ms\.?|miss|k\.)\s*/i;
function sameName(a: string | null, b: string | null): boolean {
  const norm = (s: string | null) =>
    s === null ? null : s.trim().replace(HONORIFIC, "").replace(/\s+/g, " ").toLowerCase();
  return norm(a) === norm(b);
}

const show = (v: string | null) => (v === null ? "null" : v);

type Row = {
  fx: Fixture;
  result: ExtractResult | null;
  error: string | null;
  aiError: string | null;
  phoneOk: boolean;
  nameOk: boolean;
};
const rows: Row[] = [];

console.log(`โมเดล: ${env.GEMINI_MODEL}  เคสทั้งหมด: ${fixtures.length}\n`);

for (const [i, fx] of fixtures.entries()) {
  if (i > 0) await new Promise((r) => setTimeout(r, DELAY_MS));
  try {
    lastAiError = null;
    lastAiResponded = false;
    const result = await extractOrderInfo(fx.text, client);
    rows.push({
      fx,
      result,
      error: null,
      aiError: result.ai_unavailable ? (lastAiError ?? (lastAiResponded ? "JSON ผิดรูปแบบ" : "timeout")) : null,
      phoneOk: result.phone === fx.expected_phone,
      nameOk: sameName(result.customer_name, fx.expected_name),
    });
  } catch (e) {
    rows.push({ fx, result: null, error: String(e), aiError: null, phoneOk: false, nameOk: false });
  }
  const r = rows[rows.length - 1];
  console.log(`[${i + 1}/${fixtures.length}] ${fx.id} เสร็จ${r.error ? " (crash)" : ""}`);
}

console.log(
  "\n# | เคส | ชื่อที่คาด | ชื่อที่ได้ | เบอร์ที่คาด | เบอร์ที่ได้ | status | ai_unavailable | ชื่อ | เบอร์",
);
for (const [i, r] of rows.entries()) {
  const res = r.result;
  console.log(
    [
      i + 1,
      r.fx.label,
      show(r.fx.expected_name),
      res ? show(res.customer_name) : `CRASH: ${r.error}`,
      show(r.fx.expected_phone),
      res ? show(res.phone) : "-",
      res ? res.status : "-",
      res ? (r.aiError ? `true (${r.aiError})` : "false") : "-",
      r.nameOk ? "ถูก" : "ผิด",
      r.phoneOk ? "ถูก" : "ผิด",
    ].join(" | "),
  );
}

const n = rows.length;
const noCrash = rows.filter((r) => !r.error).length;
const phoneOk = rows.filter((r) => r.phoneOk).length;
const nameOk = rows.filter((r) => r.nameOk).length;
const aiDown = rows.filter((r) => r.result?.ai_unavailable).length;

console.log("\nเกณฑ์ | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน");
console.log(`ไม่ crash | ${n}/${n} | ${noCrash}/${n} | ${noCrash === n ? "ผ่าน" : "ไม่ผ่าน"}`);
console.log(`เบอร์ถูกต้อง | ${n}/${n} | ${phoneOk}/${n} | ${phoneOk === n ? "ผ่าน" : "ไม่ผ่าน"}`);
console.log(`ชื่อถูกต้อง | >= 8/${n} | ${nameOk}/${n} | ${nameOk >= 8 ? "ผ่าน" : "ไม่ผ่าน"}`);
if (aiDown) console.log(`\nหมายเหตุ: Gemini ใช้งานไม่ได้ ${aiDown} เคส (ai_unavailable = true)`);

Deno.exit(noCrash === n && phoneOk === n && nameOk >= 8 ? 0 : 1);
