# รีวิวความพร้อมส่ง App Store / Google Play — COD Customer Check

> เอกสารนี้ใช้ส่งต่อให้ AI agent (Antigravity) ลงมือแก้
> ฐานโค้ด: commit `a259f4b` + งานที่ยังไม่ commit (Merchant KYC, migration `20261013000001`)
> วันที่ตรวจ: 2026-10-13 · ตรวจจากการอ่านโค้ด ยังไม่ได้รัน `flutter analyze` / `flutter test`

## กติกาสำหรับผู้ลงมือแก้

- ทำตามลำดับ P0 → P1 → P2 แล้วรัน `flutter analyze`, `flutter test` และ `deno test` หลังจบแต่ละกลุ่ม
- ห้ามทำข้อมีป้าย **[ต้องตัดสินใจ]** จนกว่าเจ้าของจะเลือกตัวเลือก
- เคารพกฎใน `docs/PROJECT_CONTEXT.md` เช่น hash เบอร์ใน Edge Function เท่านั้น และไม่ log PII
- ถ้าข้อไหนต้องขัดกฎ ให้แก้เอกสารด้วยว่าเป็นข้อยกเว้น
- migration ใหม่ให้สร้างเป็นไฟล์ใหม่เสมอ ห้ามแก้ migration เก่าที่ deploy ไปแล้ว

---

## P0 — ไม่แก้ = โดน reject หรือมีช่องโหว่ร้ายแรง

### P0-1 ไม่มีการลบบัญชีในแอป (Apple 5.1.1(v), Google Play account deletion)

**ปัญหา**
- แอปให้สมัครสมาชิกได้ แต่ไม่มีปุ่มลบบัญชี
- ต่อให้เพิ่มปุ่มไปตอนนี้ก็จะลบไม่สำเร็จ เพราะ FK เหล่านี้ไม่มี `on delete`:
  - `cod_reports.reported_by → sellers.id`
  - `cod_reports.reviewed_by → auth.users`
  - `sellers.verified_by → auth.users`

**สิ่งที่ต้องทำ**
1. สร้าง migration ใหม่ แก้ FK
   - `reviewed_by` และ `verified_by` → `on delete set null`
   - `reported_by` → ดูตัวเลือกด้านล่าง
2. สร้าง Edge Function `delete-account`
   - ตรวจ JWT
   - ลบไฟล์ใน `report-evidences/{uid}/` และ `merchant-evidences/{uid}/`
   - เรียก `admin.auth.admin.deleteUser(uid)`
3. เพิ่มปุ่ม "ลบบัญชี" ในเมนูผู้ใช้ มี dialog ยืนยันสองชั้น และแสดงข้อความภาษาไทยว่าข้อมูลใดจะถูกลบหรือถูกเก็บต่อ
4. Google Play ต้องมี **URL ลบบัญชีบนเว็บ** ด้วย (กรอกใน Data safety) อาจเป็นหน้าเว็บที่บอกขั้นตอนหรือเป็นแบบฟอร์มก็ได้

**[ต้องตัดสินใจ] รายงานของร้านที่ลบบัญชีไปแล้วจะทำอย่างไร**

| ตัวเลือก | ผลที่ได้ | ข้อควรระวัง |
|---|---|---|
| **A (แนะนำ)** `reported_by` nullable + `on delete set null` และคงรายงานไว้ | ฐานข้อมูลความเสี่ยงไม่หายไปกับร้าน | `get_risk_level` ใช้ `join sellers` (inner join) รายงานที่ไม่มีเจ้าของจะหลุดจากการคำนวณ ต้องเปลี่ยนเป็น left join และกำหนดว่ารายงานไร้เจ้าของนับเป็นเกณฑ์แดงหรือไม่ (แนะนำนับแค่ yellow) |
| B `on delete cascade` | ง่ายที่สุด | ร้านที่โดนลูกค้าฟ้องลบบัญชีหนีได้ และลบประวัติที่ตัวเองรายงานได้ |
| C เปลี่ยนสถานะรายงานเป็น `resolved` ก่อนลบ | ไม่กระทบคะแนนอีก แต่ยังมีร่องรอยไว้ตรวจสอบ | ต้องเขียน logic เพิ่มใน Edge Function |

**เกณฑ์ผ่าน:** ร้านที่เคยรายงานและเคยยื่น KYC ลบบัญชีสำเร็จ แถวใน `auth.users` และ `sellers` หายไป ไฟล์ใน storage หายไป และ `get_risk_level` ไม่ error

### P0-2 นโยบายความเป็นส่วนตัว และ Data Safety / App Privacy

**ปัญหา**
- ยังไม่มีนโยบายความเป็นส่วนตัวเลย
- แอปส่งข้อความออเดอร์ (ชื่อ เบอร์ ที่อยู่ของ**บุคคลที่สาม**) ไปให้ Gemini
- KYC เก็บเบอร์ติดต่อของร้าน และภาพหลักฐานที่อาจมีข้อมูลลูกค้าของร้านติดมาด้วย

**สิ่งที่ต้องทำ**
1. หน้านโยบายความเป็นส่วนตัว (ภาษาไทย อ้างอิง PDPA) โฮสต์บน URL สาธารณะ ระบุอย่างน้อย:
   - ข้อมูลที่เก็บ: อีเมล ชื่อร้าน URL ร้าน เบอร์ติดต่อร้าน ภาพหลักฐาน hash เบอร์ลูกค้า ชื่อลูกค้า
   - การส่งข้อมูลให้ Google Gemini เพื่อแยกชื่อ/เบอร์
   - ระยะเวลาเก็บข้อมูล (รายงานนับ 12 เดือน แต่ข้อมูลอยู่นานแค่ไหน)
   - ช่องทางให้เจ้าของข้อมูลขอเข้าถึง แก้ไข หรือลบ
   - ช่องทางติดต่อ
2. ใส่ลิงก์นโยบายไว้ในหน้าสมัครสมาชิก (checkbox ยอมรับ) และในเมนูตั้งค่า
3. ใช้ `url_launcher` เปิดลิงก์ (`url_launcher_windows` มีอยู่ใน symlinks แล้ว แต่ต้องตรวจว่า `url_launcher` อยู่ใน `pubspec.yaml` จริง)
4. เตรียมคำตอบ App Privacy (Apple) และ Data safety (Google) ให้ตรงกับนโยบาย

### P0-3 ความเสี่ยงเชิงนโยบายของตัวแอป (Apple 5.1.1(viii)) **[ต้องตัดสินใจ]**

**ปัญหา**

Apple ระบุว่า *"Apps that compile personal information from any source that is not directly from the user or without the user's explicit consent… are not permitted"* แอปนี้รวบรวมข้อมูลลูกค้าปลายทางโดยที่ลูกค้าไม่ได้ยินยอม ระบบ KYC ช่วยให้ข้อมูลน่าเชื่อถือขึ้น แต่**ไม่ได้แก้ข้อนี้**

| ตัวเลือก | รายละเอียด |
|---|---|
| **A (แนะนำ)** ลดข้อมูลให้น้อยที่สุดก่อนส่ง | เลิกเก็บ `customer_name` (เก็บแค่ `phone_hash`) ทำ Dispute Portal ให้เจ้าของเบอร์โต้แย้งหรือขอลบได้ แล้วเขียน App Review Notes อธิบายวัตถุประสงค์ (ป้องกันการฉ้อโกง COD), การ hash, การอนุมัติโดยแอดมิน และช่องทางโต้แย้ง |
| B ส่ง Android ก่อน แล้วเตรียม iOS ตามหลัง | Google Play ไม่มีข้อนี้ตรงๆ แต่ยังต้องผ่านนโยบาย UGC และ Data safety |
| C ส่งทั้งคู่ตามสภาพปัจจุบัน | โอกาสโดน reject ฝั่ง iOS สูง |

ถ้าเลือก A ให้ทำ migration ลบคอลัมน์ `customer_name` หรือทำให้ nullable แล้วหยุดเขียนลงไป แก้ `admin_get_pending_reports` และ UI ฝั่งแอดมินด้วย แอดมินยังดูชื่อได้จากภาพหลักฐาน

### P0-4 ข้อกำหนดเนื้อหาที่ผู้ใช้สร้าง (Apple 1.2 / Google Play UGC)

ตอนนี้มีแอดมินอนุมัติรายงานและอนุมัติ KYC แล้ว ซึ่งดี ส่วนที่ยังขาด:
- **ช่องทางติดต่อที่เผยแพร่ในแอป** (อีเมลหรือ LINE OA) ไว้ในเมนูตั้งค่า
- **ระงับหรือแบนร้านค้า:** เพิ่มสถานะ `suspended` ใน `sellers_verification_status_check` เพิ่ม RPC `admin_suspend_merchant` และให้ `report-customer` ปฏิเสธร้านที่ถูกระงับ
- **ช่องทางโต้แย้งของเจ้าของข้อมูล:** ดูหัวข้อ Dispute Portal ท้ายเอกสาร หรืออย่างน้อยมีอีเมลรับเรื่องที่ระบุในนโยบาย

### P0-5 การเช็ก KYC ใน `report-customer` เปิดทางให้ผ่าน (fail-open)

ไฟล์: `supabase/functions/report-customer/index.ts`

```ts
if (seller && seller.verification_status !== "approved") { ... 403 }
```

ถ้า query error หรือไม่พบแถว `sellers` ค่า `seller` จะเป็น `null` เงื่อนไขนี้เลยผ่าน แล้วรายงานถูกบันทึกโดยไม่ได้ตรวจ KYC เลย

แก้เป็น:

```ts
if (sellerError) throw new Error(`load seller failed: ${sellerError.code}`);
if (!seller || seller.verification_status !== "approved") {
  return json(403, { status: "UNVERIFIED_MERCHANT", error: "..." });
}
```

ทางเลือกเสริมคือย้ายการตรวจไปไว้ใน DB เป็น trigger `before insert on cod_reports` เพื่อกันทุกทาง

**เกณฑ์ผ่าน:** เพิ่มเคสใน `test_part7.ts` ให้ร้าน `unverified`, `pending` และร้านที่ไม่มีแถวใน `sellers` ได้ 403 ทั้งหมด

### P0-6 Rate limit ของโหมด guest ไม่ทำงานจริง

ไฟล์: `supabase/functions/check-customer/index.ts`

**ปัญหา**
- โค้ดจำกัดจำนวนเฉพาะคำขอที่ไม่มี header `Authorization`
- แต่ `supabase_flutter` ส่ง `Authorization: Bearer <anon key>` มาทุกครั้งแม้ยังไม่ login จึงไม่เคยโดนจำกัด
- คนนอกก็ส่ง header แบบเดียวกันได้ ผลคือไล่ตรวจเบอร์ได้ไม่จำกัด และเผาโควตา Gemini
- ตัวนับแบบ `Map` เก็บในหน่วยความจำ แต่ละ isolate นับแยกกัน

**สิ่งที่ต้องทำ**
1. แยกว่าเป็น user จริงหรือ guest: ถ้า bearer token เท่ากับ anon key หรือ `admin.auth.getUser(token)` ไม่สำเร็จ ให้ถือเป็น guest
2. ย้ายตัวนับไปเก็บใน Postgres: ตาราง `rate_limits(key text, window_start timestamptz, count int)` + RPC `hit_rate_limit(p_key, p_limit, p_window_seconds)` ที่ใช้ `insert ... on conflict do update` คืนค่า boolean
3. กำหนดเพดานแยกกัน:
   - guest ต่อ IP: เช่น 30/นาที, 300/วัน
   - user ต่อ uid: สูงกว่า
   - การเรียก Gemini (โหมด `text`): ต่ำกว่าโหมด `phone`

**[ต้องตัดสินใจ]** จะเก็บโหมด guest ไว้ไหม ถ้ามี guest ใครก็ไล่ถามเบอร์ได้ ทางที่ปลอดภัยที่สุดคือบังคับ login ก่อนตรวจ หรือให้ guest ตรวจได้วันละไม่กี่ครั้ง

### P0-7 การตั้งค่า build สำหรับ store

| # | ไฟล์ | ปัญหา | วิธีแก้ |
|---|---|---|---|
| a | `android/app/build.gradle.kts` | release ยังเซ็นด้วย debug key | สร้าง upload keystore ทำ `key.properties` (ใส่ใน .gitignore) แล้วตั้ง `signingConfigs.release` เปิดใช้ Play App Signing |
| b | `android/app/build.gradle.kts` + `ios/Runner.xcodeproj` | Application ID / Bundle ID ยังเป็นค่าที่ Flutter สร้างให้ (`com.codcheck.cod_customer_check` / `com.codcheck.codCustomerCheck`) | **[ต้องตัดสินใจ]** ใช้ reverse-domain ของเจ้าของ เช่น `th.co.<โดเมน>.codcheck` และใช้ให้ตรงกันทั้งสองฝั่ง ส่งแล้วเปลี่ยนไม่ได้ |
| c | ไอคอนทั้งหมด | ยังเป็นโลโก้ Flutter | ใช้ `flutter_launcher_icons` + ไฟล์ 1024×1024 ไม่มี alpha (iOS) + adaptive icon (Android) |
| d | `ios/Runner/Info.plist` | ไม่มี `NSPhotoLibraryUsageDescription` และ `NSCameraUsageDescription` แต่ใช้ `image_picker` (ทั้งหน้ารายงานและ KYC) | เพิ่มข้อความภาษาไทย เช่น "ใช้เพื่อแนบภาพหลักฐานการรายงานและการยืนยันร้านค้า" ไม่งั้นมีโอกาสโดน ITMS-90683 |
| e | `AndroidManifest.xml` / `Info.plist` / `app_strings.dart` | ชื่อแอปไม่ตรงกันสามที่ (`cod_customer_check` / `Cod Customer Check` / `ตรวจสอบลูกค้า COD`) และในหน้า Home ใช้ "COD Risk Shield" | **[ต้องตัดสินใจ]** ชื่อทางการชื่อเดียว แล้วใช้ให้ตรงกันทุกที่ |
| f | `build.gradle.kts` | Google Play บังคับ target API 36 ตั้งแต่ 31 ส.ค. 2026 ตอนนี้ใช้ `flutter.targetSdkVersion` | ตรวจ AAB จริง (`bundletool dump manifest`) หรือกำหนด `targetSdk = 36` |
| g | `pubspec.yaml` | `version: 1.0.0+1` | เพิ่มเลข build ทุกครั้งที่อัปโหลด |
| h | `ios` `TARGETED_DEVICE_FAMILY = "1,2"` | ต้องมีภาพหน้าจอ iPad และ reviewer จะทดสอบบน iPad | **[ต้องตัดสินใจ]** ถ้า UI ยังไม่ได้ทดสอบบน iPad ให้ตั้งเป็น `1` (iPhone อย่างเดียว) |
| i | — | โปรเจกต์พัฒนาบน Windows ยังไม่เคย build iOS | ต้องใช้ Mac + Xcode (หรือ Codemagic / GitHub Actions macOS) ทดสอบ `flutter build ipa` ก่อน |

### P0-8 การยืนยันอีเมล และบัญชีสำหรับ reviewer

**ปัญหา**
- ลิงก์ยืนยันอีเมลพาไปหน้า `localhost:3000` (ระบุไว้เองใน `docs/manual_test_part8.md`) reviewer สมัครแล้วจะเจอหน้าเปิดไม่ได้
- ตอนนี้การรายงานต้องผ่าน KYC ด้วย reviewer จึงทดสอบฟีเจอร์หลักไม่ได้ ถ้าไม่มีบัญชีที่อนุมัติไว้แล้ว

**สิ่งที่ต้องทำ**
1. ตั้ง Supabase Auth → Site URL เป็นหน้าเว็บจริง เช่นหน้า "ยืนยันอีเมลสำเร็จ กลับไปเปิดแอป"
2. (ทางเลือก) ทำ deep link หรือ universal link ให้กลับเข้าแอปเอง
3. เตรียมบัญชีทดสอบ 2 บัญชีใส่ใน App Review Notes:
   - บัญชีร้านที่ KYC `approved` แล้ว
   - บัญชีร้านที่ยัง `unverified` เพื่อให้เห็นขั้นตอน KYC
4. เพิ่มปุ่ม "ลืมรหัสผ่าน" (`resetPasswordForEmail`) ตอนนี้ยังไม่มี

---

## P1 — Bug และสิ่งที่ขัดกันเอง (ควรแก้ก่อนส่ง)

### P1-1 สคริปต์ทดสอบเสีย
- `scripts/test_part7.ts` และ `scripts/e2e_test.ts` **ไม่ส่ง `evidence_path`** แต่ `report-customer` บังคับให้มี จึงได้ 400
- e2e ยังคาดว่ารายงานมีผลกับระดับความเสี่ยงทันที แต่ตอนนี้รายงานเริ่มที่ `pending` ต้องอนุมัติก่อน
- แก้ด้วยการอัปโหลดไฟล์ทดสอบเข้า `report-evidences/{uid}/` ส่ง path ไปด้วย แล้วเรียก `admin_review_report` (หรืออัปเดตด้วย service role) ให้เป็น `active` ก่อนตรวจระดับความเสี่ยง
- เพิ่มเคส KYC ตาม P0-5
- อัปเดต `docs/TEST_REPORT.md` (ตัวเลข 194/194 รันก่อนเพิ่มระบบแอดมินและ KYC)

### P1-2 สิทธิ์แอดมินเช็กคนละแบบ
- SQL `is_admin()` ดูทั้ง `admin_users` และ `app_metadata.role`
- `AuthService.isAdmin` ดูแค่ `app_metadata.role` ถ้าเพิ่มแอดมินผ่านตาราง ปุ่มแอดมินจะไม่ขึ้น
- แนะนำ: ให้แอปเรียก `rpc('is_admin')` แทน หรือเลือกใช้แหล่งเดียว (แนะนำ `app_metadata` เพราะผู้ใช้แก้เองไม่ได้ แล้วลบตาราง `admin_users`)

### P1-3 Merchant KYC
1. **`submit_merchant_kyc` ไม่ตรวจ input เลย** ต้องเพิ่มใน SQL:
   - `shop_url`: ไม่ว่าง, ≤ 300 ตัวอักษร, ขึ้นต้นด้วย `https://` หรือ `http://`
   - `category`: อยู่ในรายการที่กำหนด (ทำเป็น check constraint)
   - `contact_phone`: ตรง `^0[0-9]{8,9}$`
   - `evidence_paths`: 1–3 path ทุก path ขึ้นต้นด้วย `{auth.uid()}/` และมีอยู่จริงใน `storage.objects`
2. **ห้ามยื่นใหม่ตอน `approved`:** ตอนนี้ร้านที่อนุมัติแล้วกดยื่นซ้ำ สถานะจะกลับเป็น `pending` และส่งรายงานไม่ได้ ให้อนุญาตเฉพาะ `unverified` หรือ `rejected`
3. **`admin_approve_merchant` / `admin_reject_merchant`** ควรอัปเดตเฉพาะแถวที่ `verification_status = 'pending'` (เหมือน `admin_review_report`)
4. **`MerchantKycService.getKycStatus` กลืน error ทุกชนิด** แล้วคืน `unverified` ถ้าเน็ตหลุด ร้านที่อนุมัติแล้วจะเห็น dialog ให้ยื่น KYC ใหม่ ควรแยก error ออกมาแล้วแสดง "โหลดสถานะไม่สำเร็จ ลองใหม่"
5. **`HomePage._openReport` ใช้สถานะ KYC ที่แคชไว้** หลังแอดมินอนุมัติแล้ว ร้านต้องปิดแล้วเปิดแอปใหม่ ควรดึงสถานะใหม่ทุกครั้งที่กดรายงาน (มี loading สั้นๆ)
6. **ร้านเก่า:** หลัง migration ทุกร้านกลายเป็น `unverified` ต้องตัดสินใจว่ารายงานเดิมของร้านเหล่านั้นยังนับไหม และจะแจ้งร้านอย่างไร
7. **`contact_phone` เป็นเบอร์จริง** ขัดกับกฎ "ห้ามเก็บเบอร์โทรจริงลงฐานข้อมูล" (กฎเขียนไว้สำหรับลูกค้า) ให้เขียนข้อยกเว้นใน `PROJECT_CONTEXT.md` และนโยบายความเป็นส่วนตัว
8. **ข้อความ ">50 ออเดอร์"** อยู่ใน UI แต่ระบบไม่ได้ตรวจ ให้เขียนเป็นเกณฑ์ที่แอดมินใช้พิจารณา

### P1-4 การอัปโหลดหลักฐาน (รายงานและ KYC)
- อัปโหลดรูปก่อนส่งข้อมูล ถ้าส่งไม่ผ่าน (ซ้ำ, ข้อมูลผิด, 403) รูปจะค้างใน storage และพอกดส่งใหม่ก็อัปซ้ำ
  - แก้: เก็บ path ที่อัปแล้วไว้ใน state แล้วใช้ซ้ำตอนกดส่งใหม่ และให้ Edge Function/RPC ลบไฟล์เมื่อ insert ไม่สำเร็จ หรือมี job ลบไฟล์ที่ไม่มีใครอ้างอิงเกิน 24 ชม.
- `resolveMimeType` แปลง `heic`/`gif` ได้ แต่ bucket อนุญาตแค่ jpeg/png/webp ให้บังคับแปลงเป็น jpg (`image_picker` ที่ตั้ง `imageQuality` มักได้ jpg อยู่แล้ว) หรือแสดงข้อความชัดเจน
- `report-customer` ตรวจ path แค่ `startsWith(uid/)` ควรตรวจด้วย regex `^{uid}/evidence_\d+_\d+\.(jpg|jpeg|png|webp)$` และเช็กว่าไฟล์มีอยู่จริง
- ลบ trigger `auto_link_recent_evidence` (migration ใหม่) เพราะ Edge Function บังคับแนบ path อยู่แล้ว trigger นี้อาจผูกรูปผิดรายงาน

### P1-5 ข้อความ error ดิบ
ห้ามโชว์ `$e` ให้ผู้ใช้เห็น ให้เปลี่ยนเป็นข้อความภาษาไทยทั่วไป แล้ว log รายละเอียดเฉพาะใน debug:
- `report_customer_page.dart`: "เลือกรูปภาพไม่สำเร็จ: $e" และ "อัปโหลดภาพหลักฐานไม่สำเร็จ: $e"
- `merchant_kyc_dialog.dart`: "เลือกรูปภาพไม่สำเร็จ: $e" และ "เกิดข้อผิดพลาด: $e"
- `admin_dashboard_page.dart`: "เกิดข้อผิดพลาด: $e" (หลายจุด)

### P1-6 Line ending
`app.dart` และ `home_page.dart` ถูกแปลงเป็น CRLF ทั้งไฟล์ ทำให้ git diff แสดงว่าเปลี่ยนทั้งไฟล์ (เช่น home_page +2373 บรรทัด) และรีวิวยาก
- เพิ่ม `.gitattributes` ใส่ `* text=auto eol=lf`
- รัน `git add --renormalize .` ใน commit แยก

### P1-7 เอกสารไม่ตรงกับระบบ
- `PROJECT_CONTEXT.md` ยังระบุ status 3 ค่า (จริงมี 5 ค่า) ไม่มีเรื่องแอดมิน, KYC, guest mode และกฎ "Flutter ห้ามแตะ cod_reports" ขัดกับ RPC ของแอดมิน
- `README.md` ไม่มีเรื่องแอดมิน, หลักฐาน และ KYC
- ส่วน "ขอบเขต (ห้ามเพิ่มฟีเจอร์นอกเหนือจากนี้)" ล้าสมัย ควรอัปเดตให้ตรงกับขอบเขตปัจจุบัน

---

## P2 — ปรับปรุง (ทำหลังส่งได้)

- `google_fonts` โหลดฟอนต์ Prompt จากเน็ตตอนเปิดแอป ให้ฝังไฟล์ฟอนต์ไว้ใน `assets/fonts` แล้วตั้ง `GoogleFonts.config.allowRuntimeFetching = false`
- Modal รายงานใช้ `barrierDismissible: true` แตะนอกกรอบแล้วข้อมูลที่กรอกหาย ควรถามยืนยันก่อนปิดถ้ามีข้อมูลอยู่
- `sellers` มี grant `insert, update, delete` ให้ `authenticated` (RLS ยังกันอยู่ แต่ควร revoke ให้เหลือแค่ `select`)
- `check_customer_page.dart` ถูกลบแล้ว ดีแล้ว และ `web/` ไม่อยู่ใน archive นี้ ถ้าจะทำหน้าเว็บ (นโยบาย, ลบบัญชี, Dispute Portal) ต้องตัดสินใจว่าจะใช้ React เดิมหรือ Flutter web
- เก็บ log การกระทำของแอดมิน (ใครอนุมัติ/ปฏิเสธอะไร เมื่อไร) ไว้ในตาราง audit
- **ความปลอดภัยของ secrets:** `.env` มี service role key, Gemini key และ `PHONE_HASH_SECRET` ไม่ได้ commit แต่ติดไปกับไฟล์ archive ถ้าเคยส่ง archive ให้คนอื่น ให้เปลี่ยน service role key กับ Gemini key ส่วน `PHONE_HASH_SECRET` **ห้ามเปลี่ยน** (hash เดิมทั้งหมดจะใช้ไม่ได้) เว้นแต่ทำ migration re-hash ซึ่งทำไม่ได้เพราะไม่มีเบอร์จริงเก็บไว้

---

## ถ้าจะทำ Customer Dispute Portal (แก้จากแผนเดิม)

1. **Mock OTP** เปิดได้ด้วย env ฝั่ง server เท่านั้น (`DISPUTE_MOCK_OTP=true`) ห้ามมีปุ่มในฝั่ง client และใน production ต้องเปิดไม่ได้ ต้องเลือกผู้ให้บริการ SMS จริงก่อนเริ่ม **[ต้องตัดสินใจ]**
2. **อย่าใช้ Supabase Phone Auth กับลูกค้า** เพราะ trigger `handle_new_user` จะสร้างแถว `sellers` ให้ ลูกค้าจะกลายเป็นร้าน ให้ Edge Function จัดการ OTP เอง แล้วออก token ชั่วคราว (ผูกกับ `phone_hash` หมดอายุใน 15 นาที)
3. **ส่งคำร้องผ่าน Edge Function** ห้ามใช้ RPC ที่ anon เรียกได้ เพราะต้อง hash เบอร์ด้วย `PHONE_HASH_SECRET` อัปโหลดรูปผ่าน signed upload URL ที่ Edge Function ออกให้
4. **Ticket ID ต้องเดาไม่ได้:** ใช้รหัสสุ่มยาว ≥ 128 bit เป็นตัวยืนยัน แยกจากเลขที่แสดงให้ลูกค้า หรือบังคับ OTP อีกรอบก่อนดูสถานะ
5. **สิ่งที่ลูกค้าเห็น:** จำนวนรายงานกับช่วงเวลาแบบคร่าวๆ (ตาม `period.ts`) เท่านั้น ห้ามแสดงเดือนที่แน่นอน ชื่อร้าน หรือรูปหลักฐานของร้าน
6. **แอดมินเลือก resolve ทีละรายงาน** ไม่ล้างทั้งเบอร์
7. **ระหว่างพิจารณา** รายงานคงสถานะ `active` (กันคนยื่นคำร้องเพื่อล้างประวัติชั่วคราว) และกำหนดว่าหลัง resolve แล้วร้านเดิมรายงานซ้ำได้หรือไม่
8. **ไม่เก็บ `customer_name` / `phone_masked`** ในตารางคำร้อง
9. **ทำ Portal เป็นหน้าเว็บ** แล้วใส่ลิงก์ไว้ในแอปและในนโยบาย ส่วนหน้าแอดมินที่พิจารณาคำร้องทำในแอปได้

---

## สรุปเรื่องที่เจ้าของต้องตัดสินใจก่อนเริ่ม

| # | เรื่อง | ค่าที่แนะนำ |
|---|---|---|
| 1 | รายงานของร้านที่ลบบัญชี (P0-1) | A: set null + คงรายงาน นับแค่ yellow |
| 2 | ลดข้อมูล / ลำดับการส่ง store (P0-3) | A: เลิกเก็บชื่อลูกค้า + Dispute Portal + Review Notes |
| 3 | เก็บโหมด guest ไหม (P0-6) | เก็บไว้แต่จำกัดต่อวันแบบเข้มงวด |
| 4 | Bundle ID / ชื่อแอป (P0-7 b, e) | — |
| 5 | รองรับ iPad (P0-7 h) | iPhone อย่างเดียวในเวอร์ชันแรก |
| 6 | รายงานเดิมของร้านที่ยังไม่ผ่าน KYC (P1-3.6) | ยังนับต่อ แต่ร้านต้องยื่น KYC ก่อนรายงานครั้งถัดไป |
| 7 | ผู้ให้บริการ SMS OTP (Dispute Portal) | — |
