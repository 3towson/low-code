// สร้างข้อมูลทดสอบ: ผู้ใช้ร้านค้า 4 ร้าน และรายงาน TEST_HASH_A..H
// รัน: deno run --allow-net --allow-read --allow-env scripts/seed_test.ts
// รันซ้ำได้: ใช้ผู้ใช้เดิมถ้ามีอยู่แล้ว และลบรายงาน TEST_HASH_* ก่อนใส่ใหม่

import {
  findTestUsers,
  loadEnv,
  serviceClient,
  type ShopKey,
  TEST_REPORTS,
  TEST_SHOPS,
} from "./_env.ts";

const env = await loadEnv(["SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY", "TEST_USER_PASSWORD"]);
const sb = serviceClient(env);

const DAY_MS = 24 * 60 * 60 * 1000;
const now = Date.now();
const daysAgo = (d: number) => new Date(now - d * DAY_MS).toISOString();

function fail(step: string, message: string): never {
  console.log(`FAIL  ${step}: ${message}`);
  Deno.exit(1);
}

// 1) ผู้ใช้ทดสอบ
const existing = await findTestUsers(sb);
const ids = {} as Record<ShopKey, string>;

for (const shop of TEST_SHOPS) {
  const key = shop.email.split("@")[0] as ShopKey;
  let id = existing.get(shop.email);
  if (id) {
    console.log(`OK    ${shop.email} มีอยู่แล้ว ใช้ของเดิม`);
  } else {
    const { data, error } = await sb.auth.admin.createUser({
      email: shop.email,
      password: env.TEST_USER_PASSWORD,
      email_confirm: true,
      user_metadata: { shop_name: shop.shopName },
    });
    if (error || !data.user) fail(`สร้างผู้ใช้ ${shop.email}`, error?.message ?? "ไม่มีข้อมูลผู้ใช้");
    id = data.user.id;
    console.log(`OK    สร้าง ${shop.email}`);
  }
  ids[key] = id;

  // 2) ตั้ง sellers.created_at (upsert เผื่อผู้ใช้ถูกสร้างก่อนมี trigger)
  const { error } = await sb.from("sellers").upsert({
    id,
    shop_name: shop.shopName,
    created_at: daysAgo(shop.ageDays),
  });
  if (error) fail(`ตั้งค่า sellers ของ ${shop.email}`, error.message);
}
console.log("OK    ตั้ง sellers.created_at แล้ว (shop1-3: 400 วันก่อน, shop4: วันนี้)");

// 3) ลบรายงานทดสอบเดิม
const { error: delError, count: delCount } = await sb
  .from("cod_reports")
  .delete({ count: "exact" })
  .like("phone_hash", "TEST\\_HASH\\_%");
if (delError) fail("ลบรายงาน TEST_HASH_*", delError.message);
console.log(`OK    ลบรายงาน TEST_HASH_* เดิม ${delCount ?? 0} แถว`);

// 4) ใส่รายงานใหม่
const rows = Object.entries(TEST_REPORTS).flatMap(([hash, reports]) =>
  reports.map(([shop, days, status]) => ({
    phone_hash: hash,
    customer_name: `ลูกค้าทดสอบ ${hash.slice(-1)}`,
    reported_by: ids[shop],
    platform: "shopee",
    reason: "refused_delivery",
    amount: 500,
    status,
    created_at: daysAgo(days),
  }))
);
const { error: insError } = await sb.from("cod_reports").insert(rows);
if (insError) fail("ใส่รายงานทดสอบ", insError.message);
console.log(`OK    ใส่รายงานทดสอบ ${rows.length} แถว`);
