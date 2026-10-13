# รีวิวรอบที่ 3 — ตรวจงานที่แก้ตาม STORE_READINESS_REVIEW_v2

> ฐานโค้ด: `9a8e035` · วันที่ตรวจ: 2026-10-13
> ตรวจจากการอ่านโค้ด และเช็กของจริงบน GitHub (ยังไม่ได้รัน `flutter test` / `deno test`)
> ใช้คู่กับ `docs/STORE_READINESS_REVIEW_v2.md`

## สรุป

แก้ได้เกือบครบทุกข้อ แต่ **migration ใหม่ (`..._000008`) มีบั๊กที่ทำให้ระงับร้านค้าไม่ได้เลย** และ `TEST_REPORT.md` ใส่ "ผ่าน" ให้ข้อที่ยังไม่ได้ทดสอบจริง (เขียนว่า "เตรียม migration แล้ว") บั๊กนี้หลุดมาเพราะเหตุผลนั้น

### สถานะข้อ N0–N9

| ข้อ | สถานะ | หมายเหตุ |
|---|---|---|
| N0 รหัสผ่านหลุด | ⚠️ ลบออกจากไฟล์แล้ว แต่**บน GitHub ยังมีอยู่** | ดู R0 |
| N1 หน้าเว็บสำเร็จปลอม | ⚠️ dispute ใช้ mailto แล้ว ✅ deep link เอาออกแล้ว ✅ แต่ reset-password ยังใช้กับแอปไม่ได้ | ดู R2 |
| N2 IP spoofing / fail-closed / เพดานรวม | ⚠️ แก้ตามแนวทางแล้ว แต่ยังไม่ได้ทดสอบกับ platform จริง | ดู R4 |
| N3 revoke `hit_rate_limit` | ✅ | — |
| N4 นโยบายความเป็นส่วนตัว | ⚠️ ดีขึ้นมาก แต่ยังขาดตัวตนผู้ควบคุมข้อมูล และมีคำสัญญาที่ระบบยังไม่ได้ทำ | ดู R5 |
| N5 ชื่อลูกค้า | ✅ เอาช่องออกแล้ว ไม่ส่งแล้ว และล้างข้อมูลเก่าแล้ว | เหลือ `validateCustomerName` ที่ไม่ได้ใช้ (ลบได้) |
| N6 ลบบัญชี | ❌ ขั้นตอน reject รายงาน pending ล้มเหลวแบบเงียบ | ดู R1 |
| N7 suspended | ❌ ฝั่งแอปครบ แต่ฟังก์ชันใน DB พัง | ดู R1 |
| N8 ตรวจไฟล์หลักฐาน | ✅ ทั้ง report-customer และ KYC | ไฟล์ `MainActivity.kt` เก่ายังค้าง (ดู R6) |
| N9 build | ✅ fail ถ้าไม่มี keystore + adaptive icon แล้ว | — |

---

## R0 🚨 รหัสผ่านแอดมินยังอยู่บน GitHub สาธารณะ

ตรวจ `raw.githubusercontent.com/3towson/low-code/master/docs/APPLE_REVIEW_NOTES.md` แล้ว **ยังมีส่วน Administrator Account พร้อมรหัสผ่านอยู่** commit ใหม่ยังไม่ได้ push และต่อให้ push แล้ว รหัสเดิมก็ยังอยู่ใน git history

**เจ้าของต้องทำเอง:**
1. Supabase Dashboard → Authentication → ลบบัญชี `admin@codcheck.app` (สคริปต์ใหม่แค่ไม่สร้างบัญชีนี้แล้ว แต่ไม่ได้ลบบัญชีที่มีอยู่) และลบแถวใน `admin_users` ของบัญชีนี้
2. เปลี่ยนรหัสผ่านบัญชี reviewer ทั้งสองบัญชี
3. ตรวจ `admin_audit_logs` ว่ามีใครใช้บัญชีแอดมินทำอะไรหรือไม่
4. เมื่อเปลี่ยนรหัสแล้ว ค่อย push commit ใหม่ (ไม่ต้องลบประวัติ git ถ้ารหัสเดิมใช้ไม่ได้แล้ว)

## R1 ❌ คอลัมน์ `review_notes` ไม่มีอยู่จริง ทำให้ระงับร้านค้าและ reject ตอนลบบัญชีพัง

ตาราง `cod_reports` มีคอลัมน์ `reject_reason` **ไม่มี `review_notes`** แต่โค้ดใหม่สองจุดใช้ `review_notes`:

### (ก) `20261013000008` → `admin_suspend_merchant`
- ทุกครั้งที่เรียกด้วยค่าเริ่มต้น (`p_reject_pending = true`) คำสั่ง `UPDATE cod_reports SET review_notes = ...` จะ error ว่า `column "review_notes" does not exist` แล้ว transaction ทั้งหมด rollback **ผลคือระงับร้านไม่ได้เลย**
- **ซ้ำร้าย:** `create or replace` ที่ใช้ signature ใหม่ `(uuid, text, boolean)` ไม่ได้แทนที่ฟังก์ชันเดิม `(uuid, text)` แต่สร้างฟังก์ชันชื่อเดียวกันเพิ่มขึ้นมาอีกตัว (overload) ตอนแอปเรียกด้วย `{p_seller_id, p_reason}` จะตรงทั้งสองตัว PostgREST เลยตอบ error `PGRST203` (เลือกฟังก์ชันไม่ได้) **ต่อให้แก้ชื่อคอลัมน์แล้ว แอปก็ยังเรียกไม่ได้**
- ฟังก์ชันใหม่ไม่ได้บันทึก `admin_audit_logs` (ตัวใน `..._000007` บันทึก) ระบบ audit จึงถอยหลัง

### (ข) `admin_unsuspend_merchant`
- ไม่ได้เช็กสถานะเดิม เรียกกับร้านที่ `unverified`/`pending`/`rejected` แล้วจะกลายเป็น `approved` ทันที **ข้าม KYC ได้** ต้องเพิ่ม `and verification_status = 'suspended'`
- ไม่บันทึก audit log

### (ค) `delete-account/index.ts`
- `update({ review_notes: ... })` ล้มเหลวแบบเดียวกัน แต่ supabase-js ไม่ throw (คืน `{ error }` แทน) `try/catch` จึงจับไม่ได้ **รายงาน pending ไม่ถูก reject และไม่มีใครรู้** จากนั้นผู้ใช้ถูกลบ รายงานจะค้างอยู่โดยไม่มีหลักฐานให้แอดมินตรวจ

### วิธีแก้ (migration ใหม่ `..._000009`)
```sql
drop function if exists public.admin_suspend_merchant(uuid, text);
-- สร้าง admin_suspend_merchant(uuid, text, boolean) ใหม่:
--   ใช้ reject_reason แทน review_notes
--   insert admin_audit_logs (action 'suspend_merchant', details รวม rejected_pending_reports)
-- สร้าง admin_unsuspend_merchant ใหม่:
--   where id = p_seller_id and verification_status = 'suspended'
--   insert admin_audit_logs (action 'unsuspend_merchant')
```
- `delete-account`: เปลี่ยนเป็น `reject_reason` และเช็ก `{ error }` ที่คืนมา ถ้า error ให้หยุด ไม่ลบผู้ใช้ แล้วตอบ 500
- เพิ่มปุ่ม "ยกเลิกการระงับ" ใน Admin Dashboard ถ้ายังไม่มี

### เกณฑ์ผ่าน (ต้องรันกับ Supabase จริง ห้ามใส่ "ผ่าน" ถ้ายังไม่ได้รัน)
- `test_p0_4.ts`: ระงับร้านที่มีรายงาน pending 2 ฉบับ → ร้านเป็น `suspended`, รายงานเป็น `rejected` ทั้งสองฉบับ และมีแถวใน `admin_audit_logs`
- `admin_unsuspend_merchant` กับร้าน `unverified` → ต้อง error
- `test_p0_1.ts`: ร้านที่มีรายงาน pending ลบบัญชี → รายงานเป็น `rejected` และ `reject_reason` ไม่ว่าง

## R2 ❌ หน้ารีเซ็ตรหัสผ่านใช้กับคำขอจากแอปไม่ได้ (ปัญหา PKCE)

`supabase_flutter` ใช้ **PKCE flow** เป็นค่าเริ่มต้น เมื่อแอปเรียก `resetPasswordForEmail` แอปจะเก็บ `code_verifier` ไว้ในเครื่อง ลิงก์ในอีเมลจะพาไป `reset-password.html?code=...` แต่หน้าเว็บไม่มี verifier ตัวนั้น `exchangeCodeForSession(code)` จึง error ทุกครั้ง (เช่น "invalid flow state / code verifier") ข้อดีคือรอบนี้หน้าเว็บแสดง error ถูกต้อง ไม่แสดงสำเร็จปลอมแล้ว แต่ผู้ใช้ก็ยังรีเซ็ตรหัสไม่ได้อยู่ดี

**วิธีแก้ที่แนะนำ:** ใช้ token hash แทน code
1. Supabase Dashboard → Authentication → Email Templates → **Reset Password** เปลี่ยนลิงก์เป็น
   `{{ .SiteURL }}/low-code/reset-password.html?token_hash={{ .TokenHash }}&type=recovery`
   (ปรับ path ให้ตรงกับ Site URL ที่ตั้งไว้)
2. ใน `reset-password.html` เพิ่มการตรวจลำดับแรก:
   ```js
   const tokenHash = urlParams.get('token_hash');
   if (tokenHash) {
     const { error } = await supabaseClient.auth.verifyOtp({ token_hash: tokenHash, type: 'recovery' });
     if (error) throw error;
     isSessionReady = true; return;
   }
   ```
3. ทำแบบเดียวกันกับเทมเพลต **Confirm signup** ถ้า `email-verified.html` ต้องยืนยันอีเมลเอง (`type: 'email'`) ไม่งั้นการยืนยันจะขึ้นกับการตั้งค่า redirect ของ Supabase
4. **ทดสอบจริงบนมือถือ:** กด "ลืมรหัสผ่าน" ในแอป → เปิดลิงก์ในอีเมล → ตั้งรหัสใหม่ → login ในแอปด้วยรหัสใหม่

ทางเลือกอื่น: ทำ deep link ให้ลิงก์กลับเข้าแอป แล้วตั้งรหัสใหม่ในแอปเลย ใช้เวลามากกว่า

## R3 ❌ `TEST_REPORT.md` ใส่ "ผ่าน" ให้ข้อที่ยังไม่ได้ทดสอบ

หลายแถวมีผลจริงเป็น "เตรียม migration แล้ว" แต่ช่องผ่าน/ไม่ผ่านเขียนว่า **ผ่าน** และหมายเหตุบอกเองว่ายังต้อง deploy migration `000001`–`000008` ก่อน ตัวอย่าง:
- P0-1 `on delete set null`
- P0-4 `admin_suspend_merchant` (ซึ่งพังจริงตาม R1)
- P0-4 `admin_unsuspend_merchant`
- P0-6 revoke `hit_rate_limit`

**กติกาใหม่สำหรับ agent:** ช่อง "ผ่าน" ใส่ได้ก็ต่อเมื่อรันกับระบบจริงแล้วได้ผลตามที่คาด ถ้ายังไม่ได้รัน ให้ใส่ **"ยังไม่ทดสอบ"** แล้ว deploy migration ทั้งหมดไป Supabase project สำหรับพัฒนา และรัน `test_part2/6/7`, `test_p0_1/4/6`, `e2e_test` ใหม่

## R4 🟠 การอ่าน IP ยังต้องทดสอบกับ platform จริง

ตอนนี้ `getClientIp` อ่านตามลำดับ `cf-connecting-ip` → `x-real-ip` → IP ตัวสุดท้ายใน XFF ซึ่งถูกตามหลักการ แต่ถ้า proxy ของ Supabase **ไม่ได้เขียนทับ** `x-real-ip` หรือ `cf-connecting-ip` client ก็ส่ง header พวกนี้มาเองเพื่อหลบ rate limit ได้อีก

ต้องทดสอบจริง (ข้อ N2.1 เดิม ยังไม่ได้ทำ):
```bash
curl -X POST "$SUPABASE_URL/functions/v1/check-customer" \
  -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "X-Real-IP: 9.9.9.9" -H "CF-Connecting-IP: 8.8.8.8" -H "X-Forwarded-For: 7.7.7.7" \
  -d '{"phone":"0812345678"}'
```
- ให้ function log (ชั่วคราว) ว่าได้ IP อะไร
- ถ้าได้ `9.9.9.9` หรือ `8.8.8.8` แปลว่า client ปลอมได้ ต้องเลิกใช้ header นั้น
- เขียนผลลงใน `TEST_REPORT.md`

หมายเหตุ: เพดานรวม `guest:global:text:day = 3000` ทำให้คนคนเดียวใช้โควตา AI ของ guest ทั้งระบบหมดได้ (guest คนอื่นจะใช้ไม่ได้ทั้งวัน แต่ยังตรวจด้วยเบอร์ได้) ถือว่ายอมรับได้ เพราะกันค่าใช้จ่ายไม่ให้บานปลาย แต่ควรรู้ไว้

## R5 🟠 นโยบายความเป็นส่วนตัว: คำสัญญาที่ระบบยังไม่ได้ทำ

1. **"ภาพหลักฐานเก็บไม่เกิน 12 เดือนแล้วลบถาวร"** ยังไม่มี job ลบภาพเลย (ไม่มี pg_cron หรือ scheduled function) ต้องเลือก:
   - ทำ scheduled job (pg_cron เรียก Edge Function `purge-old-evidence` ทุกวัน: ลบไฟล์ใน `report-evidences` ที่อายุเกิน 12 เดือน และ `evidence_path` ของรายงานที่เกิน 12 เดือน) หรือ
   - แก้นโยบายให้ตรงกับที่ระบบทำจริง
   - ตาราง `rate_limits` ก็ควรมี job ลบแถวเก่าด้วย
2. **ผู้ควบคุมข้อมูล:** ยังเขียนว่า "ทีมงานผู้พัฒนาและให้บริการ COD Risk Shield" PDPA ต้องระบุชื่อบุคคลหรือนิติบุคคลจริงและช่องทางติดต่อ **[เจ้าของต้องกรอก]**
3. **Region ของ Supabase:** นโยบายระบุ "Singapore / ap-southeast-1" ต้องตรวจใน Dashboard ว่าตรงจริง
4. **โดเมน `codcheck.app`:** อีเมล support, dispute และ privacy ทั้งหมดยังใช้โดเมนนี้ **[เจ้าของต้องยืนยัน]** ว่าเป็นเจ้าของโดเมนและรับอีเมลได้จริง ปุ่ม mailto ในหน้า dispute จะใช้ได้ก็ต่อเมื่อ `dispute@codcheck.app` รับอีเมลได้จริง
5. ยังควรให้นักกฎหมายตรวจก่อนเผยแพร่

## R6 🟢 เก็บกวาด

- ลบ `app/android/app/src/main/kotlin/com/codcheck/cod_customer_check/MainActivity.kt` (ยังค้างอยู่ เป็น untracked)
- ลบ `validateCustomerName` และ `_nameController` ที่ไม่ได้ใช้แล้วใน `report_customer_page.dart`
- `docs/STORE_READINESS_REVIEW_v2.md` ถูก commit เข้า repo ด้วย ไม่มีความลับ เก็บไว้ได้ แต่ repo เป็น public ทุกคนจะเห็นรายการช่องโหว่ทั้งหมด ควรย้ายเอกสารรีวิวไปไว้นอก repo จนกว่าจะแก้ครบ

---

## ลำดับที่แนะนำ

1. **เจ้าของ (ทันที):** R0
2. **agent:** R1 → R2 → deploy migration ทั้งหมดไป dev project → R3 (รันทดสอบจริงทั้งหมด แล้วแก้ TEST_REPORT ให้ตรงความจริง) → R4 → R5.1 → R6
3. **เจ้าของ:** R5.2–R5.5 (ข้อมูลผู้ควบคุมข้อมูล, region, โดเมน และให้นักกฎหมายตรวจ)
4. ค่อยเริ่ม build สำหรับส่ง store: Android AAB → Internal testing ก่อน และ iOS ผ่าน Mac/CI → TestFlight
