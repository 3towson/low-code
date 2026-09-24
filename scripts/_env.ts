// โหลดค่าจากไฟล์ .env ที่ root ของโปรเจกต์ ใช้ร่วมกันระหว่างสคริปต์
// ห้ามพิมพ์ค่าที่อ่านได้ออกมา แสดงเฉพาะชื่อ key ที่ขาด

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

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

export async function loadEnv(required: string[]): Promise<Record<string, string>> {
  let env: Record<string, string>;
  try {
    env = parseEnv(await Deno.readTextFile(ENV_URL));
  } catch {
    console.log("FAIL  อ่านไฟล์ .env ไม่ได้");
    Deno.exit(1);
  }
  const miss = required.filter((k) => !env[k]);
  if (miss.length) {
    console.log(`FAIL  ไม่มีค่าใน .env: ${miss.join(", ")}`);
    Deno.exit(1);
  }
  return env;
}

export function serviceClient(env: Record<string, string>): SupabaseClient {
  return createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export const TEST_SHOPS = [
  { email: "shop1@test.local", shopName: "ร้านทดสอบ 1", ageDays: 400 },
  { email: "shop2@test.local", shopName: "ร้านทดสอบ 2", ageDays: 400 },
  { email: "shop3@test.local", shopName: "ร้านทดสอบ 3", ageDays: 400 },
  { email: "shop4@test.local", shopName: "ร้านทดสอบ 4", ageDays: 0 },
] as const;

export type ShopKey = "shop1" | "shop2" | "shop3" | "shop4";

// ข้อมูลรายงานทดสอบ: [ร้าน, จำนวนวันย้อนหลัง, status]
export const TEST_REPORTS: Record<string, [ShopKey, number, string][]> = {
  TEST_HASH_A: [],
  TEST_HASH_B: [["shop1", 30, "active"]],
  TEST_HASH_C: [["shop1", 30, "active"], ["shop1", 60, "active"]],
  TEST_HASH_D: [["shop1", 20, "active"], ["shop2", 10, "active"]],
  TEST_HASH_E: [["shop1", 200, "active"], ["shop2", 210, "active"]],
  TEST_HASH_F: [["shop1", 400, "active"], ["shop2", 380, "active"]],
  TEST_HASH_G: [["shop1", 20, "active"], ["shop2", 15, "disputed"]],
  TEST_HASH_H: [["shop1", 20, "active"], ["shop4", 0, "active"]],
};

// คืน map email -> user id ของผู้ใช้ทดสอบที่มีอยู่แล้ว
export async function findTestUsers(sb: SupabaseClient): Promise<Map<string, string>> {
  const wanted = new Set<string>(TEST_SHOPS.map((s) => s.email));
  const found = new Map<string, string>();
  for (let page = 1; ; page++) {
    const { data, error } = await sb.auth.admin.listUsers({ page, perPage: 1000 });
    if (error) throw new Error(`listUsers ล้มเหลว: ${error.message}`);
    for (const u of data.users) {
      const email = u.email?.toLowerCase();
      if (email && wanted.has(email)) found.set(email, u.id);
    }
    if (data.users.length < 1000) break;
  }
  return found;
}
