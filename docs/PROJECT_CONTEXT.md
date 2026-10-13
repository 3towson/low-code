# Project Context: COD Customer Check

## เป้าหมาย
เว็บและแอปพลิเคชันสำหรับร้านค้าออนไลน์รายย่อย ใช้ตรวจสอบว่าลูกค้า COD มีประวัติปฏิเสธรับสินค้าหรือไม่ และใช้รายงานลูกค้าที่มีปัญหา เพื่อช่วยลดต้นทุนค่าส่งพัสดุตีกลับและป้องกันความเสียหาย

## ขอบเขตระบบ
1. **การจัดการบัญชีร้านค้า (Merchant Accounts)**:
   - เข้าสู่ระบบ / สมัครสมาชิกร้านค้า (Supabase Auth พร้อมบังคับยืนยันอีเมล)
   - รีเซ็ตรหัสผ่าน (Forgot Password via Supabase Auth)
   - ลบบัญชีผู้ใช้และข้อมูลร้านค้าถาวร (Account Deletion ตามมาตรฐาน Apple App Store Guideline 5.1.1(v) และ Google Play Data Safety)
2. **การตรวจสอบลูกค้า (Customer Risk Check)**:
   - ตรวจสอบประวัติเบอร์โทรศัพท์โดยตรง หรือวางข้อความออเดอร์ดิบเพื่อสกัดข้อมูลด้วย Google Gemini AI
   - แสดงระดับความเสี่ยง (เขียว / เหลือง / แดง), จำนวนรายงานที่นับ, และช่วงเวลาที่เคยถูกรายงาน
   - รองรับโหมดผู้เยี่ยมชม (Guest Mode) โดยมีระบบ Rate Limiting บันทึกตัวนับใน PostgreSQL อย่างเข้มงวด
3. **การยืนยันตัวตนร้านค้า (Merchant KYC)**:
   - เพื่อป้องกันสแปมและรักษาความน่าเชื่อถือ ร้านค้าต้องยื่นยืนยันตัวตนก่อนมีสิทธิ์รายงานลูกค้า
   - กรอก URL หน้าร้านจริง, หมวดหมู่สินค้า, เบอร์ติดต่อร้านค้า, และภาพหลักฐานยอดขาย/ส่งพัสดุ (>50 ออเดอร์) 1–3 ภาพ
   - ผู้ดูแลระบบ (Admin) จะตรวจสอบและอนุมัติผ่านระบบ Admin Moderation
4. **การรายงานลูกค้าที่มีปัญหา (Problematic Customer Reporting)**:
   - ฟอร์มรายงาน: เบอร์โทร, แพลตฟอร์ม, สาเหตุ, มูลค่าความเสียหาย, รายละเอียดเพิ่มเติม
   - บังคับแนบภาพหลักฐาน 1–3 ภาพ (จัดเก็บใน Supabase Storage Bucket `report-evidences`)
   - รายงานเริ่มต้นที่สถานะ `pending` เพื่อรอการตรวจสอบจากผู้ดูแลระบบ
   - ป้องกันการรายงานซ้ำเบอร์เดิมจากร้านเดิมภายใน 7 วัน
5. **ระบบผู้ดูแลระบบ (Admin Moderation & UGC Safety)**:
   - ตรวจสอบและอนุมัติ/ปฏิเสธรายงานลูกค้า (`admin_review_report`)
   - ตรวจสอบและอนุมัติ/ปฏิเสธการยืนยันตัวตนร้านค้า (`admin_approve_merchant`, `admin_reject_merchant`)
   - ระงับสิทธิ์บัญชีร้านค้าที่สร้างรายงานเท็จหรือละเมิดเงื่อนไข UGC (`admin_suspend_merchant`)

## Tech Stack
- **Frontend**: Flutter (Dart 3+, Material 3, Responsive Glassmorphism Design) อยู่ในโฟลเดอร์ `app/`
- **Backend**: Supabase Cloud (PostgreSQL 15+, Supabase Auth, Storage Buckets, Edge Functions แบบ TypeScript/Deno)
- **AI Integration**: Google Gemini API เรียกจาก Edge Function (`check-customer`) ผ่านโมเดลที่กำหนดใน `GEMINI_MODEL`
- **Testing & Scripts**: Deno scripts ในโฟลเดอร์ `scripts/` และ Flutter test suite ใน `app/test/`

## โครงสร้างโฟลเดอร์
- `app/`                                  Flutter Application
- `supabase/migrations/`                  SQL Migrations (Schemas, RLS, Functions, Triggers)
- `supabase/functions/_shared/`           โมดูลที่ใช้ร่วมกัน (Phone normalizer, HMAC hash, Period calculator, Rate limit)
- `supabase/functions/check-customer/`    Edge Function ตรวจสอบประวัติลูกค้า
- `supabase/functions/report-customer/`   Edge Function บันทึกรายงานลูกค้า
- `supabase/functions/delete-account/`   Edge Function ลบบัญชีผู้ใช้ถาวร
- `scripts/`                              สคริปต์ seed, ทดสอบอัตโนมัติ และ deployment
- `docs/`                                 เอกสารประกอบโปรเจกต์และรายงานการทดสอบ

## กฎความปลอดภัยและความเป็นส่วนตัว (Privacy & Security Rules)
- ห้ามเขียน API Key, Secret, Service Role Key หรือรหัสผ่านลงในซอร์สโค้ด ให้ใช้ Supabase secrets และ `.env` เสมอ
- การ Normalize และ Hash เบอร์โทรลูกค้า (HMAC-SHA256 ด้วย `PHONE_HASH_SECRET`) ต้องทำบน Edge Function เท่านั้น ห้ามทำใน Client
- **ห้ามเก็บเบอร์โทรจริงของลูกค้าลงฐานข้อมูล**: ตาราง `cod_reports` เก็บเฉพาะ `phone_hash`
- **ความเป็นส่วนตัวของชื่อลูกค้า (P0-3)**: ไม่เก็บ `customer_name` ลงในตาราง `cod_reports` เพื่อลดปริมาณข้อมูลส่วนบุคคลที่จัดเก็บ
- **ข้อยกเว้นสำหรับเบอร์โทรของร้านค้า**: ฟิลด์ `contact_phone` ในตาราง `sellers` ได้รับการยกเว้น เนื่องจากเป็นข้อมูลติดต่อของตัวร้านค้าเองเพื่อใช้ยืนยันตัวตน KYC โดยแอดมิน และไม่ได้เปิดเผยสู่สาธารณะ
- ร้านค้าทั่วไปห้าม query ตาราง `cod_reports` โดยตรง ต้องผ่าน Edge Function หรือ RPC เท่านั้น
- สิทธิ์ผู้ดูแลระบบ (Admin) ตรวจสอบผ่าน `public.is_admin()` ซึ่งรองรับทั้งตาราง `admin_users` และ `auth.jwt() -> 'app_metadata' ->> 'role' = 'admin'`

## กฎ Normalize เบอร์โทร
1. แปลงเลขไทย ๐-๙ เป็น 0-9
2. ตัดทุกตัวอักษรที่ไม่ใช่ตัวเลขทิ้ง
3. ถ้าขึ้นต้นด้วย 66 และยาว 11 หลัก ให้แทน 66 ด้วย 0
4. ผลลัพธ์ต้องตรงกับ `^0[689]\d{8}$` ถ้าไม่ตรงถือว่าไม่ใช่เบอร์มือถือไทย (คืนค่า null)

## ระดับความเสี่ยง (Risk Assessment)
- **รายงานที่นับ**: รายงานที่มีสถานะ `active` และ `created_at` อยู่ภายใน 12 เดือนล่าสุด
- **รายงานเกณฑ์แดง**: รายงานที่นับ ที่มี `created_at` ภายใน 90 วัน และร้านค้าที่รายงานมีอายุบัญชีอย่างน้อย 7 วัน ณ วันที่รายงาน
- **ระดับความเสี่ยง**:
  - `green` (เขียว): ไม่มีรายงานที่นับ ("ส่งได้ตามปกติ")
  - `yellow` (เหลือง): มีรายงานที่นับอย่างน้อย 1 รายงาน แต่ไม่ถึงเกณฑ์ red ("ควรโทรหรือทักยืนยันออเดอร์กับลูกค้าก่อนแพ็กสินค้า")
  - `red` (แดง): มีรายงานเกณฑ์แดงจากร้านค้าที่ต่างกันตั้งแต่ 2 ร้านขึ้นไป ("ไม่แนะนำให้ส่งแบบเก็บเงินปลายทาง ควรให้ลูกค้าโอนชำระก่อน")

## ค่าสถานะและข้อมูลที่อนุญาต (Allowed Enums & Values)
- **Report Status (5 ค่า)**:
  - `pending`: รอการอนุมัติจากผู้ดูแลระบบ
  - `active`: อนุมัติแล้ว มีผลต่อการคำนวณความเสี่ยง
  - `rejected`: ไม่อนุมัติ
  - `appealed`: อยู่ระหว่างการยื่นคำร้องโต้แย้ง
  - `resolved`: ยุติข้อโต้แย้งแล้ว
- **Merchant KYC Status (5 ค่า)**:
  - `unverified`: ยังไม่ยืนยันตัวตน
  - `pending`: รอการอนุมัติ
  - `approved`: ผ่านการยืนยันตัวตนแล้ว
  - `rejected`: ไม่อนุมัติ
  - `suspended`: บัญชีถูกระงับสิทธิ์
- **Platform**: `shopee`, `lazada`, `facebook`, `line`, `tiktok`, `other`
- **Reason**: `refused_delivery` (ปฏิเสธรับสินค้า), `unreachable` (ติดต่อไม่ได้), `fake_address` (ที่อยู่ปลอม), `other` (อื่นๆ)