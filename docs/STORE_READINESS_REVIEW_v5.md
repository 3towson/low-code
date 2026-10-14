# รีวิวรอบที่ 5 — ก่อนขึ้น Store (เน้น Google Play)

> วันที่ตรวจ: 2026-10-15 · ผู้รับผิดชอบ: Phanuwat Thammaruksa
> ใช้ต่อจาก `STORE_READINESS_REVIEW_v4.md` · ตรวจจากการอ่านโค้ด commit ล่าสุดบน `main` (ยังไม่ได้ build หรือรันเทสต์ในการรีวิวนี้)

## สรุป

โค้ดแอปและ backend พร้อมเกือบหมดแล้ว แต่**ยังส่ง Google Play ไม่ได้**เพราะมี 4 เรื่อง: โดเมน `codcheck.app` ไม่มีอยู่จริง, อีเมลของ Supabase ยังใช้ตัว default (**แก้แล้ว**), ยังไม่มีข้อกำหนดการใช้งาน (Terms of Use) และบัญชีนักพัฒนาส่วนตัวต้องผ่าน closed test 12 คน 14 วันก่อน

ส่วนที่ดีอยู่แล้ว: targetSdk 36 ตรงเกณฑ์ใหม่ของ Play, ใช้ photo picker จึงไม่ต้องขอสิทธิ์รูปภาพ, มีลบบัญชีในแอปและหน้าเว็บ, ไม่เก็บเบอร์จริง (HMAC), มี KYC, moderation, rate limit และไม่มี secret หลุดใน repo (anon key ในหน้าเว็บเป็นค่าสาธารณะตามปกติ)

## ค่าที่ตัดสินใจแล้ว

| เรื่อง | ค่าที่เลือก |
| --- | --- |
| อีเมลติดต่อ (support / dispute / DPO) | `codriskshield.support@gmail.com` ที่อยู่เดียวกันทั้งหมด |
| ส่งเมลยืนยัน / รีเซ็ตรหัสผ่าน | Gmail SMTP ตั้งใน Supabase แล้ว (ไม่ต้องแก้ฝั่ง auth) |
| ชื่อผู้ควบคุมข้อมูล | Phanuwat Thammaruksa (ผู้พัฒนา COD Risk Shield) |
| การตรวจเบอร์ | **A1** — คง guest mode ไว้ แต่ลดโควตา |
| ระยะเก็บรายงาน | **D1** — ลบแถว `cod_reports` ที่เก่ากว่า 24 เดือน |
| ฟีเจอร์ Admin History | **ยกเลิก** ห้ามสร้าง และลบ `.agents/rules/admin_history_reminder.md` |

## P0 — ต้องแก้ก่อนส่ง Google Play

### P0-1 โดเมน codcheck.app ไม่มีอยู่จริง

เช็ก DNS แล้วได้ NXDOMAIN แปลว่าอีเมล `support@`, `dispute@`, `privacy@codcheck.app` ส่งไม่ถึงใคร กระทบ:

- หน้า `delete-account.html` วิธีที่ 2 (ขอลบผ่านอีเมล) ใช้ไม่ได้ ทั้งที่ Play ใช้ URL นี้ตรวจเรื่องการลบบัญชี
- `dispute.html` สร้าง mailto ไป `dispute@codcheck.app` ผู้บริโภคยื่นโต้แย้งไม่ได้จริง
- Privacy Policy ระบุ DPO และช่องทางติดต่อเป็นอีเมลที่ไม่มีจริง
- อีเมลติดต่อใน Play Console ต้องรับเมลได้
- LINE `@codcheck` ใน `url_helper.dart` ยังไม่ได้ยืนยันว่ามีจริง ถ้าไม่มีให้ลบออก

**แก้:** แทนที่ทุกจุดด้วย `codriskshield.support@gmail.com` และรวมไว้ค่าคงที่เดียวใน `AppUrls` ไฟล์ที่เกี่ยวข้อง: `app/lib/utils/url_helper.dart`, `app/web/*.html`, `supabase/functions/report-customer/index.ts` (ข้อความ suspended), `app/lib/pages/home_page.dart`, `app/lib/widgets/merchant_kyc_dialog.dart`, `docs/*REVIEW_NOTES.md`, `app/test/settings_test.dart`

หมายเหตุ: บัญชี reviewer `reviewer_approved@codcheck.app` / `reviewer_unverified@codcheck.app` ไม่ต้องเปลี่ยน เพราะ `seed_reviewer_accounts.ts` ตั้ง `email_confirm: true` ให้ ไม่ต้องรับอีเมล

### P0-2 อีเมลของ Supabase — เสร็จแล้ว (15 ต.ค. 2026)

ตัว default ของ Supabase ส่งได้เฉพาะสมาชิกทีม และจำกัด 2 ฉบับต่อชั่วโมง ตอนนี้เปลี่ยนเป็น Gmail SMTP (`codriskshield.support@gmail.com`) แล้ว template Reset Password มี `{{ .Token }}` และ Confirm signup ใช้ลิงก์ `email-verified.html?token_hash={{ .TokenHash }}&type=email` เทสต์สมัคร ยืนยันอีเมล และรีเซ็ตรหัสผ่านด้วยอีเมลภายนอกผ่านทั้งหมด **ไม่ต้องแก้โค้ดฝั่ง auth**

### P0-3 ยังไม่มี Terms of Use / ข้อกำหนดการใช้งาน

แอปเป็น UGC (ร้านค้าส่งรายงานพร้อมรูป) นโยบาย UGC ของ Play กำหนดให้ผู้ใช้ยอมรับข้อกำหนดที่นิยามเนื้อหาต้องห้ามก่อนสร้างเนื้อหา ตอนนี้ signup มีแค่ checkbox ยอมรับ Privacy Policy และข้อความระงับบัญชีอ้าง "ข้อกำหนดการใช้งาน UGC" ที่ไม่มีอยู่จริง

**แก้:**

1. เพิ่ม `app/web/terms.html` (ธีมเดียวกับหน้าอื่น) ระบุชัดว่าห้ามรายงานเท็จ ห้ามใช้เพื่อกลั่นแกล้งหรือคุกคาม ห้ามเผยแพร่ผลตรวจ บทลงโทษ (ระงับบัญชี) และช่องทางโต้แย้ง
2. เพิ่ม `AppUrls.terms` และแก้ checkbox ใน `signup_page.dart` / `login_page.dart` เป็น "ยอมรับข้อกำหนดการใช้งานและนโยบายความเป็นส่วนตัว" พร้อมลิงก์ทั้งสอง (คง Key ของ checkbox เดิมไว้ถ้าทำได้)
3. ในหน้ารายงาน (`report_customer_page.dart`) เพิ่ม checkbox บังคับ "ข้าพเจ้ารับรองว่าข้อมูลและหลักฐานเป็นความจริง" ก่อนกดส่ง
4. ใส่ลิงก์ Terms ใน `settings_dialog.dart` ข้าง Privacy Policy
5. เพิ่ม/แก้ widget test ให้ครอบคลุม checkbox ใหม่

### P0-4 บัญชีนักพัฒนาส่วนตัวต้องผ่าน closed test ก่อน

บัญชี Play Console แบบบุคคลที่เปิดหลัง 13 พ.ย. 2023 ต้องมีผู้ทดสอบอย่างน้อย 12 คนอยู่ใน closed test ต่อเนื่อง 14 วันก่อนขอสิทธิ์ production (งานของเจ้าของ ไม่ใช่โค้ด)

## P1 — ควรแก้ก่อนส่ง

| # | เรื่อง | ไฟล์ / จุดที่แก้ | วิธีแก้ |
| --- | --- | --- | --- |
| P1-1 | Guest ตรวจเบอร์ได้ 300 ครั้ง/วัน/IP | `supabase/functions/check-customer/index.ts`, `check_panel.dart`, `home_page.dart` | ตัวเลือก A1 ดูหัวข้อถัดไป |
| P1-2 | Gemini free tier อาจนำข้อความออเดอร์ไปใช้ปรับปรุงโมเดล ขัดกับ Privacy Policy | Google AI Studio / Cloud Billing | งานของเจ้าของ: ใช้ paid tier หรือแก้ Policy ให้ตรงความจริง |
| P1-3 | Privacy Policy ไม่ระบุชื่อผู้ควบคุมข้อมูลจริง | `app/web/privacy-policy.html` | ใส่ "Phanuwat Thammaruksa (ผู้พัฒนา COD Risk Shield)" + อีเมลจาก P0-1 |
| P1-4 | `cron.schedule` ใน migration ถูก comment ไว้ | migration ใหม่ | เขียน migration ตั้ง cron ที่อ่าน URL และ key จาก Vault (ไม่ฝัง key) ต้องรันซ้ำได้โดยไม่สร้าง job ซ้ำ |
| P1-5 | รายงานเก่าไม่เคยถูกลบ มีแค่ลบรูป | `purge-old-evidence/index.ts` | D1: ลบแถวที่ `created_at` เก่ากว่า 24 เดือน วนเป็น batch (รูปยังลบที่ 12 เดือนเหมือนเดิม) พร้อมเทสต์ |
| P1-6 | `rate_limits` ใช้ IP ดิบเป็น key | `check-customer/index.ts` | hash IP ด้วย HMAC ก่อนใช้เป็น key และระบุใน Privacy Policy ว่าใช้ IP เพื่อกันการใช้งานเกิน |
| P1-7 | `allowBackup` ค่าเริ่มต้น true ทำให้ session token ติดไปกับ backup | `AndroidManifest.xml` | ใส่ `android:allowBackup="false"` ใน `<application>` |
| P1-8 | เปิด URL ภายนอกบน Android 11+ อาจไม่ทำงานบางเครื่อง | `AndroidManifest.xml` | เพิ่ม `<intent>` สำหรับ `VIEW` + `https` และ `SENDTO` + `mailto` ใน `<queries>` ที่มีอยู่แล้ว |
| P1-9 | ชื่อแอปไม่ตรงกัน: "COD Risk Shield" vs "COD Customer Check" | `app/web/*.html`, `url_helper.dart` (subject "COD Check Support") | ใช้ "COD Risk Shield" ชื่อเดียวทุกที่ |

### รายละเอียดตัวเลือก A1 (ที่เลือกแล้ว)

- โควตา guest ต่อ IP: ตรวจรวม **20 ครั้ง/วัน** และ AI สกัดข้อความ **5 ครั้ง/วัน** (ผู้ใช้ที่ login คงค่าเดิม 2000 และ 500)
- ข้อความ error ใน `check-customer` ตอนนี้ฝังเลข 300 และ 60 ไว้ ต้องแก้ให้ตรงกับโควตาใหม่ และบอกว่าโควตารีเซ็ตเมื่อครบ 24 ชั่วโมงนับจากครั้งแรก (ไม่ใช่ตอนเที่ยงคืน)
- ฝั่งแอป: เมื่อ guest ได้ `status: RATE_LIMITED` ให้แสดงปุ่ม "เข้าสู่ระบบเพื่อตรวจต่อ" ใต้ข้อความ error ที่พาไปหน้า login
- โควตาต่อนาทีและเพดานรวม `guest:global:text:day` คงไว้

## จุดที่ขัดแย้งกันในเอกสารและโค้ด

| จุด | เอกสารบอก | ของจริง | แก้ |
| --- | --- | --- | --- |
| Target SDK | README: "SDK 36 (Android 15)" | API 36 คือ Android 16 | แก้ README และ badge |
| ที่เก็บ keystore | `key.properties.example`: `storeFile=../upload-keystore.jks` | `STORE_BUILD_GUIDE.md` สร้างไว้ที่ `app/upload-keystore.jks` จึงต้องเป็น `../../upload-keystore.jks` | ให้ example ตรงกับคู่มือ |
| การล้างข้อมูล | README: cron รันทุกวัน 03:00 และลบรายงานด้วย | migration ไม่ได้ตั้ง cron, function ลบแค่รูป | ดู P1-4, P1-5 |
| การ hash เบอร์ | Play notes / Data Safety: "salted SHA-256" | HMAC-SHA256 ด้วย secret ฝั่งเซิร์ฟเวอร์ | ใช้คำว่า HMAC-SHA256 ทุกเอกสาร |
| กู้รหัสผ่าน | README: Mobile Deep Link | แอปใช้ OTP 6 หลัก ไม่มี deep link | แก้ README (ไม่ต้องเพิ่ม deep link) |
| ProGuard | README: ตั้งค่า ProGuard แล้ว | ไม่มีไฟล์ rules ใช้ R8 ค่าเริ่มต้นของ Flutter | แก้ README |
| สิทธิ์กล้อง | Info.plist มี `NSCameraUsageDescription` | แอปเลือกรูปจาก gallery อย่างเดียว | **คงไว้** — image_picker มีโค้ดกล้องใน binary ถ้าลบ Apple อาจเตือน ITMS-90683 |
| ผลเทสต์ | README badge: 244 + 160 tests passed | `TEST_REPORT.md` ยังไม่ได้อัปเดตตาม R3/R4 | อัปเดต `TEST_REPORT.md` หลังรันเทสต์รอบนี้ |
| Guest mode | Google Play Review Notes: "accessible to all users (including Guest Mode)" | ยังถูกต้องเพราะเลือก A1 | อัปเดตโควตาใหม่ในเอกสาร |

ของที่ต้องเก็บกวาด:

- `app/android/build/reports/problems/problems-report.html` เป็นไฟล์ build ที่ถูก commit ไว้ ลบออกจาก git
- `pubspec.yaml` ยังมี `description: "A new Flutter project."`
- เอกสารหลายไฟล์มีลิงก์ `file:///c:/Users/deku/...` เปลี่ยนเป็น path ใน repo
- `.agents/rules/admin_history_reminder.md` ลบออก (ยกเลิกฟีเจอร์ Admin History)

## iOS

- เพิ่ม `ios/Runner/PrivacyInfo.xcprivacy` ประกาศ `NSPrivacyAccessedAPICategoryUserDefaults` เหตุผล `CA92.1` และ `NSPrivacyTracking = false` — **ห้ามแก้ `project.pbxproj` ด้วยมือ** สร้างไฟล์ไว้แล้วเจ้าของจะเพิ่มเข้า target ใน Xcode เอง
- เพิ่ม `ITSAppUsesNonExemptEncryption = false` ใน `Info.plist`
- คง `NSCameraUsageDescription` และ `NSPhotoLibraryUsageDescription` ไว้
- Terms of Use จาก P0-3 ใช้เป็น EULA สำหรับ Apple Guideline 1.2 ได้

## งานที่เจ้าของต้องทำเอง (ไม่ใช่โค้ด)

1. ดู diff ก่อน commit โดยเฉพาะ Privacy Policy และ Terms
2. `supabase db push` และ `supabase functions deploy check-customer purge-old-evidence report-customer`
3. ตั้ง secret ใน Vault ตามที่ migration cron ต้องใช้ และตั้ง secret สำหรับ hash IP (ถ้าแยกจาก `PHONE_HASH_SECRET`)
4. Deploy หน้าเว็บใหม่ด้วย `scripts/deploy_web.ps1` (Play ตรวจ Privacy / Terms / ลบบัญชีจาก GitHub Pages)
5. เปิด closed test ใน Play Console (P0-4)
6. เทสต์ซ้ำด้วยอีเมลภายนอก: สมัคร → ยืนยันอีเมล → ลืมรหัสผ่าน → ตรวจเบอร์ (guest ให้ชนโควตาด้วย) → ส่งรายงานพร้อมรูป → ลบบัญชี
7. iOS: ลาก `PrivacyInfo.xcprivacy` เข้า target ใน Xcode

## Play Console ที่ต้องกรอก

- App access: บัญชี reviewer 2 บัญชี (รัน `scripts/seed_reviewer_accounts.ts` บนโปรเจกต์ production)
- Data safety: ตาม `docs/STORE_PRIVACY_DATA_SAFETY.md` หลังแก้คำว่า HMAC และเพิ่ม "Other user-generated content"
- Account deletion URL, Privacy Policy URL (หลัง deploy หน้าเว็บใหม่)
- Content rating: มีเนื้อหาจากผู้ใช้และมีการ moderation
- Target audience: 18+
- Store listing: เครื่องมือสำหรับร้านค้า ไม่แสดงชื่อหรือเบอร์เต็มของบุคคล มีช่องทางโต้แย้งสำหรับผู้บริโภค

## Sources

- [Target API level requirements — Android Developers](https://developer.android.com/google/play/requirements/target-sdk)
- [App testing requirements for new personal developer accounts — Play Console Help](https://support.google.com/googleplay/android-developer/answer/14151465)
- [User Generated Content policy — Play Console Help](https://support.google.com/googleplay/android-developer/answer/9876937)
- [Send emails with custom SMTP — Supabase Docs](https://supabase.com/docs/guides/auth/auth-smtp)
