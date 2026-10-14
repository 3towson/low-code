# แนวทางการกรอก App Privacy (Apple) และ Data Safety (Google Play)
## COD Customer Check (COD Risk Shield)

เอกสารนี้ใช้สำหรับกรอกข้อมูลใน **Apple App Store Connect** และ **Google Play Console** ให้สอดคล้องกับ [app/web/privacy-policy.html](file:///c:/Users/deku/low-code/app/web/privacy-policy.html) และการทำงานจริงของระบบ

---

## 1. Google Play Console: Data Safety (ความปลอดภัยของข้อมูล)

### คำถามภาพรวม (Overview Questions)
- **แอปของคุณมีการเก็บรวบรวมหรือแชร์ข้อมูลผู้ใช้ตามประเภทที่กำหนดหรือไม่?**
  → ตอบ: **ใช่ (Yes)**
- **ข้อมูลทั้งหมดที่แอปของคุณเก็บรวบรวมจะได้รับการเข้ารหัสระหว่างส่งหรือไม่?**
  → ตอบ: **ใช่ (Yes)** (ส่งผ่าน HTTPS / TLS)
- **คุณมีวิธีให้ผู้ใช้ขอลบบัญชีและข้อมูลของตนหรือไม่?**
  → ตอบ: **ใช่ (Yes)**
  - ให้ระบุ URL ลบบัญชี: `https://3towson.github.io/low-code/delete-account.html`

### รายละเอียดประเภทข้อมูลที่รวบรวม (Data Types & Purposes)

| ประเภทข้อมูล (Data Type) | เก็บรวบรวม? | แชร์กับบุคคลที่สาม? | มีการประมวลผลชั่วคราว? | วัตถุประสงค์ (Purpose) | เชื่อมโยงกับตัวตนผู้ใช้? |
|---|---|---|---|---|---|
| **ข้อมูลส่วนบุคคล (Personal Info)** | | | | | |
| • ชื่อ (Name) | เก็บ (Collected) | ไม่แชร์ (No) | ไม่ (No) | การทำงานของแอป (App functionality), ป้องกันการฉ้อโกง (Fraud prevention) | ใช่ (ร้านค้า) / ไม่ (ชื่อลูกค้าปลายทาง) |
| • ที่อยู่อีเมล (Email) | เก็บ (Collected) | ไม่แชร์ (No) | ไม่ (No) | การจัดการบัญชี (Account management), ป้องกันการฉ้อโกง | ใช่ (Linked to user) |
| • หมายเลขโทรศัพท์ (Phone number) | เก็บ (Collected) | ไม่แชร์ (No) | ไม่ (No) | ติดต่อร้านค้า (Merchant KYC) *หมายเหตุ: เบอร์ลูกค้าไม่ได้เก็บจริง แปลงเป็นแฮช SHA-256 ทันที* | ใช่ (สำหรับเบอร์ร้านค้า) |
| **รูปภาพและวิดีโอ (Photos and videos)** | | | | | |
| • รูปภาพ (Photos) | เก็บ (Collected) | ไม่แชร์ (No) | ไม่ (No) | การทำงานของแอป, การยืนยันตัวตนร้านค้า (KYC), หลักฐานการรายงานลูกค้า | ใช่ (Linked to merchant user) |
| **ข้อมูลแอปและประสิทธิภาพ (App info and performance)** | | | | | |
| • บันทึกข้อขัดข้อง (Crash logs) | ไม่เก็บ (No) | ไม่แชร์ (No) | — | — | — |

---

## 2. Apple App Store Connect: App Privacy (ความเป็นส่วนตัวของแอป)

### หมวดหมู่ข้อมูลที่เก็บ (Data Types)

1. **Contact Info (ข้อมูลติดต่อ):**
   - **Email Address:** ใช้สำหรับ *App Functionality* (เข้าสู่ระบบ) เชื่อมโยงกับตัวตน (Linked to user), ไม่ใช้เพื่อการติดตาม (Not used for tracking)
   - **Phone Number:** ใช้สำหรับ *App Functionality* (ติดต่อร้านค้า KYC) เชื่อมโยงกับตัวตนร้านค้า, ไม่ใช้เพื่อการติดตาม
   - **Name:** ใช้สำหรับ *App Functionality* (ชื่อร้านค้า)

2. **User Content (เนื้อหาของผู้ใช้):**
   - **Photos or Videos:** ภาพหลักฐานรายงาน และภาพยืนยันร้านค้า KYC ใช้สำหรับ *App Functionality*, เชื่อมโยงกับบัญชีผู้ใช้, ไม่ใช้เพื่อการติดตาม

3. **Data Used to Track You (ข้อมูลที่ใช้ติดตามคุณ):**
   - ตอบ: **ไม่มี (None)** แอปไม่มี Third-party Ad tracking ใดๆ ทั้งสิ้น

4. **Third-Party AI Disclosure (การประมวลผล AI):**
   - มีการส่งข้อความออเดอร์ไปยัง Google Gemini API แบบชั่วคราว (Ephemeral Processing) เพื่อสกัดเฉพาะหมายเลขโทรศัพท์ โดยไม่มีการเก็บบันทึกข้อความดิบลงในฐานข้อมูล และไม่นำชื่อลูกค้ามาจัดเก็บในระบบรายงาน

---

## 3. URLs สำคัญที่ต้องใช้ในการส่ง Store

- **Privacy Policy URL:** `https://3towson.github.io/low-code/privacy-policy.html`
- **Account Deletion URL:** `https://3towson.github.io/low-code/delete-account.html`
- **Support Contact Email:** `codriskshield.support@gmail.com`
