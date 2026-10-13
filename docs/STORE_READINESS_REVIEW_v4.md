# รีวิวรอบที่ 4 — ตรวจ commit `b17e51e` (R1, R2, R5.1, R6)

> วันที่ตรวจ: 2026-10-14 · ตรวจจากการอ่านโค้ด (ยังไม่ได้รัน test)
> ใช้คู่กับ `STORE_READINESS_REVIEW_v3.md`

## สถานะ

| ข้อ | สถานะ | หมายเหตุ |
|---|---|---|
| R1 suspend / unsuspend / delete-account | ✅ ฝั่ง DB และ Edge Function ถูกต้องแล้ว | ปุ่มยกเลิกการระงับในแอปไม่มีทางขึ้น ดู S1 |
| R2 reset-password / email-verified | ✅ โค้ดรองรับ `token_hash` แล้ว | **เจ้าของ**ต้องแก้ Email Templates ใน Supabase ด้วย ไม่งั้นโค้ดส่วนนี้จะไม่ได้ใช้ |
| R3 ทดสอบจริง + แก้ TEST_REPORT | ❌ ยังไม่ทำ | `TEST_REPORT.md` ไม่ได้แก้เลย |
| R4 ทดสอบ IP spoofing | ❌ ยังไม่ทำ | — |
| R5.1 ลบหลักฐานที่เก่ากว่า 12 เดือน | ⚠️ เขียน function แล้ว แต่ไม่มีการตั้งเวลาให้รัน และการตรวจสิทธิ์มีปัญหา | ดู S2 |
| R6 เก็บกวาด | ⚠️ ยังไม่เสร็จ | ดู S3 |

---

## S1 🟠 ปุ่มยกเลิกการระงับไม่มีทางแสดง

`admin_dashboard_page.dart` จะแสดงปุ่ม "ยกเลิกการระงับ" ก็ต่อเมื่อ `merchant.verificationStatus == 'suspended'` แต่รายการร้านค้ามาจาก `admin_get_pending_merchants` ซึ่ง:
- คืนเฉพาะร้านที่ `verification_status = 'pending'`
- ไม่ได้คืนคอลัมน์ `verification_status` กลับมา (ค่าจึงเป็น `null` เสมอ)

ผลคือ**แอดมินไม่มีทางเห็นร้านที่ถูกระงับ และกดยกเลิกการระงับไม่ได้** widget test ผ่านเพราะ test ใส่ข้อมูลปลอมที่มี `verification_status` เข้าไปเอง

**แก้:**
1. สร้าง RPC `admin_list_merchants(p_status text, p_limit int, p_offset int)` ตรวจ `is_admin()` คืน `verification_status`, `rejection_reason`, `verified_at` ด้วย
2. เพิ่มตัวกรองหรือแท็บ "ร้านที่ถูกระงับ" ใน Admin Dashboard แล้วแสดงปุ่มยกเลิกการระงับในแท็บนั้น
3. **[ต้องตัดสินใจ] ร้านที่ถูกระงับตอนที่ยังรอ KYC:** แอดมินกดระงับได้จากรายการ "รอตรวจ KYC" ด้วย พอยกเลิกการระงับ `admin_unsuspend_merchant` จะตั้งเป็น `approved` ทันที เท่ากับ**ข้าม KYC** แนะนำ:
   - เพิ่มคอลัมน์ `status_before_suspend` ตั้งค่าตอนระงับ
   - ตอนยกเลิกการระงับ ให้คืนสถานะเดิม ถ้าเดิมเป็น `approved` คืนเป็น `approved` ถ้าไม่ใช่ ให้เป็น `unverified` (ต้องยื่น KYC ใหม่)

**เกณฑ์ผ่าน:** ระงับร้านที่ `approved` แล้วยกเลิกการระงับ → กลับเป็น `approved` / ระงับร้านที่ `pending` แล้วยกเลิกการระงับ → เป็น `unverified` / แอดมินเห็นร้านที่ถูกระงับในแอปจริง (ไม่ใช่แค่ใน widget test)

## S2 🟠 `purge-old-evidence`

1. **ไม่มีการตั้งเวลาให้รัน:** ยังไม่มี migration หรือ config ของ pg_cron เลย function นี้จะไม่เคยทำงาน แต่นโยบายสัญญาไว้ว่าจะลบ ให้ทำอย่างใดอย่างหนึ่ง:
   - migration ที่เปิด `pg_cron` + `pg_net` เก็บ service role key ใน Supabase Vault แล้ว `cron.schedule('purge-old-evidence', '0 3 * * *', $$ select net.http_post(...) $$)` หรือ
   - เขียนขั้นตอนตั้งค่าใน Supabase Dashboard → Integrations → Cron ไว้ใน `STORE_BUILD_GUIDE.md` ให้เจ้าของทำ
2. **ตรวจสิทธิ์แบบหละหลวม:** `authHeader.includes(serviceKey)` ถ้า env `SUPABASE_SERVICE_ROLE_KEY` เป็นค่าว่าง ทุก header จะผ่าน เพราะ `"x".includes("") === true` ให้เปลี่ยนเป็น:
   ```ts
   const isServiceRole = serviceKey.length > 0 && authHeader === `Bearer ${serviceKey}`;
   ```
3. **แอดมินเรียกใช้ไม่ได้:** `admin.rpc("is_admin")` เรียกผ่าน service-role client ซึ่ง `auth.uid()` เป็น null จึงได้ `false` เสมอ แอดมินจะได้ 403 ทุกครั้ง ให้เช็ก `auth.user.app_metadata.role === 'admin'` หรือ query `admin_users` ด้วย `auth.user.id` แทน ถ้าไม่จำเป็นต้องให้แอดมินเรียก ก็ตัดส่วนนี้ออกได้เลย
4. query ไม่ได้กำหนด limit PostgREST จะคืนไม่เกิน 1,000 แถวต่อครั้ง ถ้ารันทุกวันก็พอ แต่ควรวนจนหมด หรือเขียนไว้ในคอมเมนต์

## S3 🟢 R6 ยังค้าง

- `app/android/app/src/main/kotlin/com/codcheck/cod_customer_check/MainActivity.kt` **ยังอยู่** (เป็น untracked จึงไม่หายด้วย commit ต้องลบไฟล์จริงในเครื่อง)
- `_nameController` ใน `report_customer_page.dart` ยังเหลืออยู่ แต่ไม่ได้ใช้แล้ว

## S4 ยังต้องทำ R3 และ R4 (จาก v3)

- deploy migration `000001`–`000009` และ Edge Functions ทั้งหมด (`check-customer`, `report-customer`, `delete-account`, `purge-old-evidence`) ไป Supabase project สำหรับทดสอบ
- รัน `test_part2/6/7`, `test_p0_1/4/6`, `e2e_test` แล้วแก้ `TEST_REPORT.md` ช่อง "ผ่าน" ใส่ได้เฉพาะข้อที่รันจริงแล้วเท่านั้น
- ทดสอบ IP spoofing ด้วย curl ตาม R4 แล้วบันทึกผล
