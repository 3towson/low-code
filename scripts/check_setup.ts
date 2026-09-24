// ตรวจสอบการตั้งค่า: Supabase REST และ Gemini
// รัน: deno run --allow-net --allow-read --allow-env scripts/check_setup.ts
// ห้ามพิมพ์ค่า key ใดๆ ออกมา แสดงเฉพาะ PASS/FAIL และรหัส HTTP

export {};

const ENV_URL = new URL("../.env", import.meta.url);

function parseEnv(text: string): Record<string, string> {
  const out: Record<string, string> = {};
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith("#")) continue;
    const eq = line.indexOf("=");
    if (eq < 1) continue;
    const key = line.slice(0, eq).trim();
    let value = line.slice(eq + 1).trim();
    if (
      value.length >= 2 &&
      ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'")))
    ) {
      value = value.slice(1, -1);
    }
    out[key] = value;
  }
  return out;
}

let env: Record<string, string>;
try {
  env = parseEnv(await Deno.readTextFile(ENV_URL));
} catch {
  console.log("FAIL  อ่านไฟล์ .env ไม่ได้");
  Deno.exit(1);
}

let failed = 0;
function report(name: string, ok: boolean, detail: string) {
  if (!ok) failed++;
  console.log(`${ok ? "PASS" : "FAIL"}  ${name} — ${detail}`);
}

function missing(keys: string[]): string[] {
  return keys.filter((k) => !env[k]);
}

async function checkSupabase() {
  const name = "Supabase REST (GET /rest/v1/)";
  const miss = missing(["SUPABASE_URL", "SUPABASE_ANON_KEY"]);
  if (miss.length) return report(name, false, `ไม่มีค่าใน .env: ${miss.join(", ")}`);
  try {
    const url = env.SUPABASE_URL.replace(/\/+$/, "") + "/rest/v1/";
    const res = await fetch(url, {
      headers: {
        apikey: env.SUPABASE_ANON_KEY,
        Authorization: `Bearer ${env.SUPABASE_ANON_KEY}`,
      },
    });
    await res.body?.cancel();
    report(name, true, `ได้ HTTP response กลับมา (status ${res.status})`);
  } catch {
    report(name, false, "เชื่อมต่อไม่ได้ (connection error)");
  }
}

async function checkGemini() {
  const name = "Gemini generateContent";
  const miss = missing(["GEMINI_API_KEY", "GEMINI_MODEL"]);
  if (miss.length) return report(name, false, `ไม่มีค่าใน .env: ${miss.join(", ")}`);

  const key = env.GEMINI_API_KEY;
  if (!key.startsWith("AIzaSy") && !key.startsWith("AQ.")) {
    return report(name, false, "รูปแบบ GEMINI_API_KEY ไม่รู้จัก (ต้องขึ้นต้นด้วย AIzaSy หรือ AQ.)");
  }
  // key ทั้งสองแบบ (AIzaSy, AQ.) ส่งผ่าน x-goog-api-key
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    "x-goog-api-key": key,
  };

  const model = env.GEMINI_MODEL.replace(/^models\//, "");
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`;
  try {
    const res = await fetch(url, {
      method: "POST",
      headers,
      body: JSON.stringify({
        contents: [{ parts: [{ text: "ตอบสั้นๆ ว่า OK" }] }],
      }),
    });
    if (!res.ok) {
      await res.body?.cancel();
      return report(name, false, `HTTP ${res.status}`);
    }
    const data = await res.json();
    const parts = data?.candidates?.[0]?.content?.parts;
    const text = Array.isArray(parts)
      ? parts.map((p: { text?: string }) => p.text ?? "").join("").trim()
      : "";
    report(
      name,
      text.length > 0,
      text.length > 0 ? `ได้ข้อความตอบกลับ (${text.length} ตัวอักษร)` : "ไม่ได้ข้อความตอบกลับ",
    );
  } catch {
    report(name, false, "เชื่อมต่อไม่ได้ (connection error)");
  }
}

await checkSupabase();
await checkGemini();
Deno.exit(failed === 0 ? 0 : 1);
