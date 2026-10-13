// สร้างบัญชีทดสอบสำหรับ Reviewer ของ Apple App Store และ Google Play Store (P0-8, N0)
// บัญชี 1: ร้านที่ KYC ผ่านแล้ว (approved) สามารถทดสอบการรายงานและการเช็กเบอร์ได้ทันที
// บัญชี 2: ร้านที่ยังไม่ผ่าน KYC (unverified) เพื่อให้ reviewer เห็นขั้นตอนและข้อความแจ้งเตือน KYC
// (ไม่รวมบัญชีแอดมินตามข้อกำหนดความปลอดภัย N0)
//
// รัน: deno run --allow-net --allow-read --allow-env scripts/seed_reviewer_accounts.ts

import { loadEnv, serviceClient } from "./_env.ts";

const env = await loadEnv(["SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY"]);
const sb = serviceClient(env);

// อ่านรหัสผ่านจาก Environment Variable หรือสุ่มรหัสผ่านที่ปลอดภัยหากไม่ได้ระบุ
function generateSecurePassword(): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+~";
  const array = new Uint8Array(20);
  crypto.getRandomValues(array);
  return Array.from(array, (byte) => chars[byte % chars.length]).join("");
}

const REVIEWER_PASSWORD = Deno.env.get("REVIEWER_PASSWORD") || generateSecurePassword();

const ACCOUNTS = [
  {
    email: "reviewer_approved@codcheck.app",
    password: REVIEWER_PASSWORD,
    shopName: "ร้านค้าตัวอย่าง (Approved KYC)",
    status: "approved",
    desc: "ร้านที่ KYC ผ่านแล้ว (ทดสอบรายงานและตรวจเบอร์ได้ทันที)",
  },
  {
    email: "reviewer_unverified@codcheck.app",
    password: REVIEWER_PASSWORD,
    shopName: "ร้านค้าใหม่ (Unverified)",
    status: "unverified",
    desc: "ร้านที่ยังไม่ผ่าน KYC (ทดสอบขั้นตอนการยื่นยืนยันตัวตนร้านค้า)",
  },
] as const;

console.log("\n=== เริ่มเตรียมบัญชีทดสอบสำหรับ Store Reviewer (P0-8) ===\n");

for (const acc of ACCOUNTS) {
  // 1) ค้นหาว่ามี user นี้อยู่แล้วหรือไม่
  const { data: listData } = await sb.auth.admin.listUsers({ page: 1, perPage: 1000 });
  const existingUser = listData?.users?.find((u: { email?: string; id: string }) => u.email?.toLowerCase() === acc.email.toLowerCase());

  let uid: string;
  if (existingUser) {
    uid = existingUser.id;
    // อัปเดตรหัสผ่านและข้อมูลร้านค้า
    const { error: updateErr } = await sb.auth.admin.updateUserById(uid, {
      password: acc.password,
      email_confirm: true,
      user_metadata: { shop_name: acc.shopName },
    });
    if (updateErr) {
      console.log(`WARN: อัปเดต ${acc.email} ไม่สำเร็จ: ${updateErr.message}`);
    } else {
      console.log(`OK: อัปเดตผู้ใช้เดิม ${acc.email} เรียบร้อย (ID: ${uid})`);
    }
  } else {
    // สร้างผู้ใช้ใหม่
    const { data: newUser, error: createErr } = await sb.auth.admin.createUser({
      email: acc.email,
      password: acc.password,
      email_confirm: true,
      user_metadata: { shop_name: acc.shopName },
    });
    if (createErr || !newUser?.user) {
      console.log(`FAIL: ไม่สามารถสร้างผู้ใช้ ${acc.email}: ${createErr?.message}`);
      continue;
    }
    uid = newUser.user.id;
    console.log(`OK: สร้างผู้ใช้ใหม่ ${acc.email} เรียบร้อย (ID: ${uid})`);
  }

  // 2) ตั้งค่าตาราง sellers ให้สถานะ KYC ตรงตามบทบาท
  const { error: sellerErr } = await sb.from("sellers").upsert({
    id: uid,
    shop_name: acc.shopName,
    verification_status: acc.status,
  });
  if (sellerErr) {
    console.log(`WARN: upsert sellers สำหรับ ${acc.email}: ${sellerErr.message}`);
  } else {
    console.log(`OK: ตั้งสถานะ KYC ของ ${acc.email} เป็น '${acc.status}'`);
  }
}

console.log("\n==========================================================");
console.log("สรุปข้อมูลบัญชีสำหรับ Review Notes:");
console.log("==========================================================");
for (const acc of ACCOUNTS) {
  console.log(`- ${acc.desc}:`);
  console.log(`  อีเมล: ${acc.email}`);
  console.log(`  รหัสผ่าน: ${acc.password}\n`);
}
