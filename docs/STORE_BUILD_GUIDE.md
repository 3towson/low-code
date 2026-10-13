# คู่มือการเตรียม Build และ Release สำหรับ App Store และ Google Play (P0-7)

เอกสารนี้สรุปการตั้งค่า ข้อกำหนดทางเทคนิค และขั้นตอนการสร้างไฟล์พร้อมส่งขึ้น Store (AAB และ IPA) สำหรับแอป **COD Risk Shield** (`com.codcheck.app`)

---

## 1. ข้อมูลประจำตัวของแอป (App Identity & Identifiers)

| รายการ | ค่าที่กำหนด | หมายเหตุ |
|---|---|---|
| **App Name (หน้าจอ/Store)** | `COD Risk Shield` | ตรงกันทั้ง Android, iOS และ Web |
| **Package Name / Application ID (Android)** | `com.codcheck.app` | ตั้งค่าใน `android/app/build.gradle.kts` |
| **Bundle Identifier (iOS)** | `com.codcheck.app` | ตั้งค่าใน `Runner.xcodeproj` และ `Info.plist` |
| **Target Device Family (iOS)** | `1` (iPhone Only) | เวอร์ชันแรกจำกัดเฉพาะ iPhone เพื่อตัดภาระภาพหน้าจอและการทดสอบบน iPad |
| **Target SDK (Android)** | `36` (Android 15) | ผ่านเกณฑ์ข้อบังคับ Google Play (บังคับ target SDK 36 ตั้งแต่ 31 ส.ค. 2026) |
| **Min SDK** | Android: `21` (5.0) / iOS: `15.0` | ครอบคลุมผู้ใช้อุปกรณ์ส่วนใหญ่ |
| **Version** | `1.0.0+1` | กำหนดใน `pubspec.yaml` (ต้องเพิ่มเลข build เช่น `+2`, `+3` ทุกครั้งที่อัปโหลดไฟล์ใหม่) |

---

## 2. การตั้งค่าไอคอน (App Icons)

- ภาพต้นฉบับอยู่ที่: [app/assets/icon/app_icon.png](file:///c:/Users/deku/low-code/app/assets/icon/app_icon.png) (ขนาด 1024×1024, 24bpp RGB, **ไม่มี alpha channel** ตามเกณฑ์ Apple App Store)
- ปลั๊กอิน: `flutter_launcher_icons`
- หากต้องการอัปเดตไอคอนในอนาคต:
  1. วางไฟล์ใหม่ที่ `app/assets/icon/app_icon.png` (1024×1024)
  2. รันคำสั่ง:
     ```bash
     cd app
     dart run flutter_launcher_icons
     ```

---

## 3. สิทธิ์การเข้าถึง (Permissions) บน iOS

ใน `ios/Runner/Info.plist` ได้เพิ่มคำอธิบายภาษาไทยตามเกณฑ์ความยินยอมของผู้ใช้:
- `NSPhotoLibraryUsageDescription`: "ใช้เพื่อแนบภาพหลักฐานการรายงานลูกค้าและการยืนยันตัวตนร้านค้า"
- `NSCameraUsageDescription`: "ใช้สำหรับถ่ายภาพหลักฐานการรายงานลูกค้าและการยืนยันตัวตนร้านค้า"

*(ป้องกันการถูกปฏิเสธด้วยรหัสข้อผิดพลาด ITMS-90683 จาก App Store Connect)*

---

## 4. ขั้นตอนการเตรียม Release สำหรับ Google Play (Android)

### 4.1 การสร้าง Upload Keystore (ทำครั้งเดียว)
รันคำสั่งต่อไปนี้ใน terminal เพื่อสร้างไฟล์ Keystore:
```bash
keytool -genkey -v -keystore app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
*(เก็บรหัสผ่าน `storePassword` และ `keyPassword` ไว้ในที่ปลอดภัย และสำรองไฟล์ `upload-keystore.jks` ไว้นอกโฟลเดอร์ git เสมอ)*

### 4.2 สร้างไฟล์ `android/key.properties`
คัดลอกไฟล์ [app/android/key.properties.example](file:///c:/Users/deku/low-code/app/android/key.properties.example) เป็น `app/android/key.properties`:
```properties
storePassword=รหัสผ่านที่ตั้งตอนรัน_keytool
keyPassword=รหัสผ่าน_alias
keyAlias=upload
storeFile=../../upload-keystore.jks
```
*(ไฟล์นี้และไฟล์นามสกุล `.jks`/`.keystore` ถูกเพิ่มใน `.gitignore` เรียบร้อยแล้วเพื่อความปลอดภัย)*

### 4.3 คำสั่ง Build Android App Bundle (AAB)
```bash
cd app
flutter build appbundle --release
```
ผลลัพธ์ไฟล์ AAB จะอยู่ที่:
`build/app/outputs/bundle/release/app-release.aab`
สามารถนำไฟล์นี้ไปอัปโหลดขึ้น Google Play Console (Production หรือ Internal Testing)

---

## 5. ขั้นตอนการเตรียม Release สำหรับ Apple App Store (iOS)

> [!NOTE]
> การ build iOS ต้องดำเนินการบนเครื่อง macOS ที่ติดตั้ง Xcode และลงทะเบียน Apple Developer Program เรียบร้อยแล้ว

### 5.1 ตรวจสอบบน macOS / Xcode
1. เปิดโปรเจกต์ `app/ios` ด้วย Xcode:
   ```bash
   open app/ios/Runner.xcworkspace
   ```
2. ในแท็บ **Signing & Capabilities**:
   - เลือก **Team** ของคุณใน Apple Developer Account
   - ตรวจสอบว่า Bundle Identifier เป็น `com.codcheck.app`
3. ในแท็บ **General**:
   - ตรวจสอบ Supported Destinations เป็น **iPhone** อย่างเดียว (Deployment Target 15.0+)

### 5.2 คำสั่ง Build iOS IPA
```bash
cd app
flutter build ipa --release
```
ผลลัพธ์จะอยู่ที่ `build/ios/archive/Runner.xcarchive` และไฟล์ `.ipa` ใน `build/ios/ipa/`
สามารถอัปโหลดไปยัง App Store Connect ผ่าน Xcode Organizer หรือ Transporter app

---

## 6. รายการตรวจสอบก่อนส่ง Store (Pre-Submission Checklist)

- [x] Application ID / Bundle ID เป็น `com.codcheck.app` ทั้งสองฝั่ง
- [x] App Display Name เป็น `COD Risk Shield`
- [x] ไอคอนแอปไม่มี alpha channel และมีครบทุกขนาดสำหรับ Android/iOS
- [x] iOS Device Family เป็น iPhone Only (`TARGETED_DEVICE_FAMILY = 1`)
- [x] เพิ่มคำอธิบาย `NSPhotoLibraryUsageDescription` และ `NSCameraUsageDescription`
- [x] Target SDK Android เป็น 36 (ตามข้อกำหนด 31 ส.ค. 2026)
- [x] มีเทมเพลตและระบบโหลด signing configuration จาก `key.properties`
- [x] มีหน้าเว็บ Account Deletion URL และ Privacy Policy URL พร้อมใช้งาน (จาก P0-1, P0-2)
- [ ] ใส่หมายเหตุการรีวิว (Reviewer Notes) พร้อมบัญชีทดสอบที่ผ่านและไม่ผ่าน KYC (P0-8)

---

## 7. การตั้งค่าระบบตั้งเวลาลบหลักฐานอัตโนมัติ (PDPA 12 เดือน - R5.1 / S2)

ตามนโยบายความเป็นส่วนตัว ระบบจะต้องลบภาพหลักฐานที่เก่ากว่า 12 เดือนโดยอัตโนมัติ ผ่าน Edge Function `purge-old-evidence`

### ขั้นตอนตั้งค่าใน Supabase Dashboard:
1. ไปที่ **Supabase Dashboard** -> เลือกโปรเจกต์ของคุณ
2. ไปที่เมนู **Edge Functions** -> คลิกฟังก์ชัน `purge-old-evidence`
3. ในแถบ **Scheduled Triggers / Invocations** หรือเมนู **Integrations -> Cron**:
   - ตั้งค่า Schedule: `0 20 * * *` (03:00 น. ตามเวลาไทย UTC+7)
   - HTTP Method: `POST`
   - Headers: ใส่ `Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>`
4. ทดสอบกด **Invoke** เพื่อให้มั่นใจว่าฟังก์ชันทำงานและตอบกลับ `200 OK`
