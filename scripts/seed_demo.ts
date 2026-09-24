// ใส่ข้อมูลสาธิตส่วนที่ 4 ด้วยเบอร์สมมติ 0800000001-0800000003
// ต้องรัน seed_test.ts ก่อน (ใช้ร้าน shop1-shop3 ที่มีอายุบัญชี 400 วัน)
// รัน: deno run --allow-net --allow-read --allow-env scripts/seed_demo.ts
// รันซ้ำได้: ลบรายงานของ hash เบอร์สาธิตทั้งหมดก่อนใส่ใหม่

import { hashPhone, maskPhone, normalizeThaiPhone } from "../supabase/functions/_shared/phone.ts";
import { findTestUsers, loadEnv, serviceClient, type ShopKey } from "./_env.ts";
import { DEMO_PHONES } from "./_demo.ts";

const env = await loadEnv(["SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY", "PHONE_HASH_SECRET"]);
const sb = serviceClient(env);

const DAY_MS = 24 * 60 * 60 * 1000;
const now = Date.now();
const daysAgo = (d: number) => new Date(now - d * DAY_MS).toISOString();

function fail(step: string, message: string): never {
  console.log(`FAIL  ${step}: ${message}`);
  Deno.exit(1);
}

// 1) ร้าน shop1-shop3 ต้องมีอยู่แล้ว และอายุบัญชีพอสำหรับเกณฑ์แดง
const users = await findTestUsers(sb);
const ids = {} as Record<ShopKey, string>;
for (const key of ["shop1", "shop2", "shop3"] as const) {
  const id = users.get(`${key}@test.local`);
  if (!id) fail(`หา ${key}`, "ไม่พบผู้ใช้ ให้รัน scripts/seed_test.ts ก่อน");
  ids[key] = id;
}
const { data: sellers, error: sellersError } = await sb
  .from("sellers")
  .select("id, created_at")
  .in("id", Object.values(ids));
if (sellersError) fail("อ่าน sellers", sellersError.message);
const minAgeDays = Math.max(...DEMO_PHONES.flatMap((d) => d.reports.map(([, days]) => days))) + 7;
for (const s of sellers ?? []) {
  if (now - Date.parse(s.created_at) < minAgeDays * DAY_MS) {
    fail("ตรวจอายุบัญชี", `ร้านทดสอบอายุน้อยกว่า ${minAgeDays} วัน ให้รัน scripts/seed_test.ts ก่อน`);
  }
}
console.log("OK    พบร้าน shop1-shop3 และอายุบัญชีเพียงพอ");

// 2) hash เบอร์สาธิต
const demos = [];
for (const d of DEMO_PHONES) {
  const normalized = normalizeThaiPhone(d.phone);
  if (!normalized) fail("normalize", `${d.phone} ไม่ใช่เบอร์มือถือไทย`);
  demos.push({ ...d, normalized, hash: await hashPhone(normalized, env.PHONE_HASH_SECRET) });
}

// 3) ลบรายงานสาธิตเดิม
const { error: delError, count: delCount } = await sb
  .from("cod_reports")
  .delete({ count: "exact" })
  .in("phone_hash", demos.map((d) => d.hash));
if (delError) fail("ลบรายงานสาธิตเดิม", delError.message);
console.log(`OK    ลบรายงานสาธิตเดิม ${delCount ?? 0} แถว`);

// 4) ใส่รายงานใหม่
const rows = demos.flatMap((d, i) =>
  d.reports.map(([shop, days]) => ({
    phone_hash: d.hash,
    customer_name: `ลูกค้าสาธิต ${i + 1}`,
    reported_by: ids[shop],
    platform: "facebook",
    reason: "refused_delivery",
    amount: 390,
    status: "active",
    created_at: daysAgo(days),
  }))
);
const { error: insError } = await sb.from("cod_reports").insert(rows);
if (insError) fail("ใส่รายงานสาธิต", insError.message);

for (const d of demos) {
  const detail = d.reports.map(([shop, days]) => `${shop} ${days} วันก่อน`).join(", ") || "ไม่มีรายงาน";
  console.log(`OK    ${maskPhone(d.normalized)}: ${detail} (คาดว่า ${d.expected})`);
}
console.log(`OK    ใส่รายงานสาธิต ${rows.length} แถว`);
