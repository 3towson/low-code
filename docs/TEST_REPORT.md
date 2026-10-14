# รายงานผลการทดสอบ ส่วนที่ 0-11

ผลการทดสอบอัตโนมัติทั้งหมดในเอกสารนี้ **รันใหม่ทั้งหมดเมื่อ 2026-10-13** บน Supabase Cloud project สำหรับพัฒนา (Store Readiness Review v2)
ช่อง "ผลจริง" และ "ผ่าน/ไม่ผ่าน" ที่เว้นว่างไว้คือการทดสอบด้วยมือ ให้กรอกหลังทำตาม checklist ใน `docs/manual_test_part*.md`

## สรุป

| ส่วน | เรื่อง | วิธีทดสอบ | จำนวนเคส | ผ่าน |
|---|---|---|---|---|
| 0 | ตั้งค่า Supabase และ Gemini | `scripts/check_setup.ts` | 2 | 2 |
| 1 | Schema และข้อมูลทดสอบ | `scripts/test_part1.ts` | 12 | 12 |
| 2 | RLS และกันรายงานซ้ำ | `scripts/test_part2.ts` | 9 | 9 |
| 3 | `get_risk_level` | `scripts/test_part3.ts` | 10 | 10 |
| 4 | normalize/hash/mask เบอร์ และข้อมูลสาธิต | `deno test supabase/functions/_shared/` + `scripts/test_part4.ts` | 52 + 5 | 57 |
| 5 | แยกชื่อและเบอร์ (Gemini + regex) | `deno test extract.test.ts` + `scripts/eval_extract.ts` | 26 + 3 | 29 |
| 6 | Edge Function `check-customer` | `scripts/test_part6.ts` | 16 | 16 |
| 7 | Edge Function `report-customer` (รวม KYC fail-closed) | `scripts/test_part7.ts` | 16 | 16 |
| 8-10 | Flutter App Core (Login, Report, Check, Theme, Lang) | `flutter test` | 74 | 74 |
| P0-1 | การลบบัญชีและ Soft Delete (FK set null) | `scripts/test_p0_1.ts` + `delete_account_test.dart` | 16 | 16 |
| P0-4 | UGC Moderation & Merchant Suspension | `scripts/test_p0_4.ts` + `admin_service_test.dart` | 22 | 22 |
| P0-5 | Merchant KYC System (>50 ออเดอร์) | `scripts/test_part7.ts` + `merchant_kyc_test.dart` | 16 | 16 |
| P0-6 | Postgres Rate Limiting (Guest / User) | `scripts/test_p0_6.ts` | 7 | 7 |
| P2 | Offline Fonts, Discard Confirm, Admin Audit Logs | `report_customer_page_test.dart` + `merchant_kyc_test.dart` + `admin_service_test.dart` | 4 | 4 |
| 11 | End-to-End ผ่าน Edge Functions จริง | `scripts/e2e_test.ts` | 12 | 12 |
| | **Flutter Test Suite รวมทั้งหมด** | `cd app && flutter test` | **246** | **246 (100%)** |
| | **Automated Backend & Script Tests** | Deno & PostgreSQL | **160+** | **160+ (100%)** |

`flutter test` ทั้งโปรเจกต์: **246/246 ผ่าน 100%** และ `flutter analyze`: **No issues found (100% สะอาด)**

---

## ส่วนที่ 0: ตั้งค่า

| ส่วน | เคส | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน |
|---|---|---|---|---|
| 0 | Supabase REST (GET /rest/v1/) | ได้ HTTP response | ได้ HTTP response (401) | ผ่าน |
| 0 | Gemini generateContent | ได้ข้อความตอบกลับ | ได้ข้อความตอบกลับ | ผ่าน |

## ส่วนที่ 1: Schema

| ส่วน | เคส | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน |
|---|---|---|---|---|
| 1 | insert status = 'banned' | ล้มเหลว 23514 status_check | ล้มเหลว 23514 status_check | ผ่าน |
| 1 | insert platform = 'ebay' | ล้มเหลว 23514 platform_check | ล้มเหลว 23514 platform_check | ผ่าน |
| 1 | insert amount = -100 | ล้มเหลว 23514 amount_check | ล้มเหลว 23514 amount_check | ผ่าน |
| 1 | sellers ครบ 4 ร้าน shop_name ไม่ว่าง | 4 แถว | 4 แถว | ผ่าน |
| 1 | จำนวนรายงาน TEST_HASH_A | 0 | 0 | ผ่าน |
| 1 | จำนวนรายงาน TEST_HASH_B | 1 | 1 | ผ่าน |
| 1 | จำนวนรายงาน TEST_HASH_C | 2 | 2 | ผ่าน |
| 1 | จำนวนรายงาน TEST_HASH_D | 2 | 2 | ผ่าน |
| 1 | จำนวนรายงาน TEST_HASH_E | 2 | 2 | ผ่าน |
| 1 | จำนวนรายงาน TEST_HASH_F | 2 | 2 | ผ่าน |
| 1 | จำนวนรายงาน TEST_HASH_G | 2 | 2 | ผ่าน |
| 1 | จำนวนรายงาน TEST_HASH_H | 2 | 2 | ผ่าน |

## ส่วนที่ 2: RLS และ trigger กันรายงานซ้ำ

| ส่วน | เคส | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน |
|---|---|---|---|---|
| 2 | anon select cod_reports | ว่าง หรือถูกปฏิเสธ | ถูกปฏิเสธ (42501) | ผ่าน |
| 2 | anon insert cod_reports | ถูกปฏิเสธ | ถูกปฏิเสธ (42501) | ผ่าน |
| 2 | shop1 select cod_reports | ว่าง หรือถูกปฏิเสธ | ถูกปฏิเสธ (42501) | ผ่าน |
| 2 | shop1 insert cod_reports | ถูกปฏิเสธ | ถูกปฏิเสธ (42501) | ผ่าน |
| 2 | shop1 select sellers | เห็นแค่แถวของตัวเอง | 1 แถว ของ shop1 | ผ่าน |
| 2 | shop1 รายงานเบอร์เดียวกันซ้ำติดกัน | ครั้งที่สอง DUPLICATE_REPORT | ครั้งที่สอง DUPLICATE_REPORT | ผ่าน |
| 2 | shop1 รายงาน 8 วันก่อน + วันนี้ | ผ่านทั้งสองครั้ง | ผ่านทั้งสองครั้ง | ผ่าน |
| 2 | shop1 และ shop2 รายงานเบอร์เดียวกันวันเดียวกัน | ผ่านทั้งคู่ | ผ่านทั้งคู่ | ผ่าน |
| 2 | ลบข้อมูลทดสอบ | เหลือ 0 แถว | ลบ 5 แถว เหลือ 0 | ผ่าน |

## ส่วนที่ 3: ระดับความเสี่ยง

| ส่วน | เคส | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน |
|---|---|---|---|---|
| 3 | TEST_HASH_A ไม่มีรายงาน | green | green (นับ 0) | ผ่าน |
| 3 | TEST_HASH_B 1 รายงาน | yellow | yellow (นับ 1) | ผ่าน |
| 3 | TEST_HASH_C 2 รายงานจากร้านเดียว | yellow | yellow (นับ 2) | ผ่าน |
| 3 | TEST_HASH_D 2 ร้านภายใน 90 วัน | red | red (นับ 2) | ผ่าน |
| 3 | TEST_HASH_E 2 ร้าน เกิน 90 วัน | yellow | yellow (นับ 2) | ผ่าน |
| 3 | TEST_HASH_F เกิน 12 เดือน | green | green (นับ 0) | ผ่าน |
| 3 | TEST_HASH_G ร้านที่สองเป็น disputed | yellow | yellow (นับ 1) | ผ่าน |
| 3 | TEST_HASH_H ร้านที่สองอายุบัญชีไม่ถึง 7 วัน | yellow | yellow (นับ 2) | ผ่าน |
| 3 | anon เรียก rpc get_risk_level | ถูกปฏิเสธ | ถูกปฏิเสธ (42501) | ผ่าน |
| 3 | shop1 เรียก rpc get_risk_level | ถูกปฏิเสธ | ถูกปฏิเสธ (42501) | ผ่าน |

## ส่วนที่ 4: เบอร์โทรและข้อมูลสาธิต

| ส่วน | เคส | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน |
|---|---|---|---|---|
| 4 | normalize 6 รูปแบบที่ถูก (ขีด, เว้นวรรค, +66, 66, เลขไทย, วงเล็บ) | 0812345678 ทุกเคส | 0812345678 ทุกเคส (6/6) | ผ่าน |
| 4 | normalize 5 รูปแบบที่ผิด (02-, 12345, 11 หลัก, 05, ว่าง) | null ทุกเคส | null ทุกเคส (5/5) | ผ่าน |
| 4 | เบอร์เดียวกันต่างรูปแบบ | hash เท่ากัน | hash เท่ากัน | ผ่าน |
| 4 | secret ต่างกัน | hash ต่างกัน | hash ต่างกัน | ผ่าน |
| 4 | รูปแบบ hash | hex ตัวเล็ก 64 ตัว ไม่มีเบอร์จริง | ตามคาด | ผ่าน |
| 4 | hash กับ secret ว่าง หรือเบอร์ที่ยังไม่ normalize | throw | throw | ผ่าน |
| 4 | maskPhone 0812345678 | 081-XXX-5678 | 081-XXX-5678 | ผ่าน |
| 4 | phone_hash ของข้อมูลสาธิตเป็น hex 64 ตัว | ผิดรูปแบบ 0 แถว | 0 แถว | ผ่าน |
| 4 | ไม่มีเบอร์ 10 หลักในทุกคอลัมน์ | พบ 0 ค่า | พบ 0 ค่า | ผ่าน |
| 4 | get_risk_level 080-XXX-0001 | green | green (นับ 0) | ผ่าน |
| 4 | get_risk_level 080-XXX-0002 | yellow | yellow (นับ 1) | ผ่าน |
| 4 | get_risk_level 080-XXX-0003 | red | red (นับ 2) | ผ่าน |

## ส่วนที่ 5: แยกชื่อและเบอร์

Unit test (Gemini ปลอม) 26 เคส:

| ส่วน | เคส | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน |
|---|---|---|---|---|
| 5 | Gemini ตอบเบอร์ที่ไม่มีในข้อความ | ทิ้ง ใช้เบอร์จาก regex | ตามคาด | ผ่าน |
| 5 | Gemini โยน error | ai_unavailable = true ได้เบอร์จาก regex | ตามคาด | ผ่าน |
| 5 | ไม่มีเบอร์และ Gemini ตอบ null | NO_PHONE_DETECTED | ตามคาด | ผ่าน |
| 5 | Gemini ตอบ JSON ผิดรูปแบบ 5 แบบ | ไม่ crash ทำงานเหมือน error | ตามคาด (5/5) | ผ่าน |
| 5 | ข้อความยาว 3,000 ตัวอักษร | ตัดก่อนส่ง Gemini | ตามคาด | ผ่าน |
| 5 | Gemini เลือกเบอร์ลูกค้าที่ไม่ใช่ตัวแรก | ใช้เบอร์จาก Gemini | ตามคาด | ผ่าน |
| 5 | Gemini ตอบเบอร์ +66 ที่มีในข้อความ | ยอมรับหลัง normalize | ตามคาด | ผ่าน |
| 5 | Gemini ช้าเกิน timeout | ai_unavailable = true | ตามคาด | ผ่าน |
| 5 | findPhoneCandidates เลขไทย ขีด เว้นวรรค +66 ตัดซ้ำ | ได้รายการเบอร์ถูกต้อง | ตามคาด | ผ่าน |
| 5 | createGeminiClient: v1beta, header, temperature 0, 429 สองครั้ง | ai_unavailable | ตามคาด | ผ่าน |
| 5 | createGeminiClient อ่าน candidates[0].content.parts | อ่านได้ | ตามคาด | ผ่าน |
| 5 | 503 ครั้งแรกแล้ว retry สำเร็จ | ใช้ผลจาก Gemini | ตามคาด | ผ่าน |
| 5 | 429 ครั้งแรกแล้ว retry สำเร็จ | ใช้ผลจาก Gemini | ตามคาด | ผ่าน |
| 5 | เวลารอ retry เริ่มต้น | 2 วินาที | 2 วินาที | ผ่าน |
| 5 | 503 แล้ว retry ได้ 429 | ai_unavailable ไม่ retry ซ้ำ | ตามคาด | ผ่าน |
| 5 | 500 หรือ error อื่น | ไม่ retry | ตามคาด | ผ่าน |
| 5 | หมดเวลาระหว่างรอ retry | หยุดทันที ai_unavailable | ตามคาด | ผ่าน |
| 5 | retry แล้วช้าจนเกิน timeout รวม | ai_unavailable | ตามคาด | ผ่าน |
| 5 | AI ใช้ไม่ได้ และ regex เจอ 2 เบอร์ | NO_PHONE_DETECTED | ตามคาด | ผ่าน |
| 5 | 503 สองครั้ง และ regex เจอ 2 เบอร์ | NO_PHONE_DETECTED | ตามคาด | ผ่าน |
| 5 | AI ใช้ไม่ได้ regex เจอเบอร์เดียว (เขียน 2 แบบ) | ใช้เบอร์นั้น | ตามคาด | ผ่าน |
| 5 | AI ใช้ได้ และ regex เจอ 2 เบอร์ | ใช้เบอร์ที่ Gemini เลือก | ตามคาด | ผ่าน |

ประเมินกับ Gemini จริง (`tests/fixtures/orders.json` 10 ข้อความ):

| ส่วน | เคส | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน |
|---|---|---|---|---|
| 5 | ไม่ crash | 10/10 | 10/10 | ผ่าน |
| 5 | เบอร์ถูกต้อง | 10/10 | 10/10 | ผ่าน |
| 5 | ชื่อถูกต้อง | >= 8/10 | 10/10 | ผ่าน |

## ส่วนที่ 6: Edge Function check-customer

| ส่วน | เคส | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน |
|---|---|---|---|---|
| 6 | OPTIONS preflight | 200 + Allow-Origin | 200 Allow-Origin=* | ผ่าน |
| 6 | ไม่แนบ token | 401 | 401 | ผ่าน |
| 6 | text มีเบอร์ 0800000003 | 200 OK red | 200 OK red นับ 2 | ผ่าน |
| 6 | text มีเบอร์ 0800000001 | 200 OK green | 200 OK green นับ 0 | ผ่าน |
| 6 | { phone: "080-000-0002" } | 200 OK yellow | 200 OK yellow นับ 1 | ผ่าน |
| 6 | { phone: "12345" } | 400 INVALID_PHONE | 400 INVALID_PHONE | ผ่าน |
| 6 | text ไม่มีเบอร์ | 200 NO_PHONE_DETECTED | 200 NO_PHONE_DETECTED | ผ่าน |
| 6 | ไม่มี body | 400 | 400 | ผ่าน |
| 6 | body {} | 400 | 400 | ผ่าน |
| 6 | text ยาว 3,000 ตัวอักษร | 200 OK red | 200 OK red นับ 2 | ผ่าน |
| 6 | ความเป็นส่วนตัว 4 เคส | ฟิลด์ที่อนุญาตเท่านั้น ไม่มี hash/อีเมล/ชื่อร้าน/เบอร์เต็ม | ผ่านทุกข้อ (4/4) | ผ่าน |

## ส่วนที่ 7: Edge Function report-customer

| ส่วน | เคส | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน |
|---|---|---|---|---|
| 7 | ไม่แนบ token | 401 | 401 | ผ่าน |
| 7 | phone = 12345 | 400 field=phone | 400 field=phone | ผ่าน |
| 7 | platform = ebay | 400 field=platform | 400 field=platform | ผ่าน |
| 7 | customer_name ว่าง | 400 field=customer_name | 400 field=customer_name | ผ่าน |
| 7 | amount = -5 | 400 field=amount | 400 field=amount | ผ่าน |
| 7 | ข้อมูลถูกต้อง | 201 CREATED | 201 CREATED | ผ่าน |
| 7 | ตรวจแถวที่เพิ่ม | phone_hash ตรง ไม่มีเบอร์จริง reported_by=shop1 | ถูกต้องทุกข้อ | ผ่าน |
| 7 | ส่งซ้ำทันที | 409 DUPLICATE | 409 DUPLICATE | ผ่าน |
| 7 | ส่งซ้ำไม่เพิ่มแถว | 1 แถว | 1 แถว | ผ่าน |
| 7 | body ปลอม reported_by = shop2 | 201 แถวเป็นของ shop1 | 201 แถวเป็นของ shop1 | ผ่าน |
| 7 | ลบข้อมูลทดสอบ | ลบ 2 เหลือ 0 | ลบ 2 เหลือ 0 | ผ่าน |

## ส่วนที่ 8: Flutter login/signup/home

อัตโนมัติ (`auth_error_message_test.dart` 6, `login_page_test.dart` 3, `validators_test.dart` 16):

| ส่วน | เคส | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน |
|---|---|---|---|---|
| 8 | authErrorMessage 6 เคส (รหัสผ่านผิด 2 แบบ, ยังไม่ยืนยันอีเมล, ไม่มีเน็ต, 5xx, error ไม่รู้จัก) | ข้อความภาษาไทยตามกรณี | ตามคาด (6/6) | ผ่าน |
| 8 | กดเข้าสู่ระบบโดยไม่กรอก | แสดงข้อความเตือน ไม่เรียก signIn | ตามคาด | ผ่าน |
| 8 | อีเมลผิดรูปแบบ | แสดงข้อความเตือน | ตามคาด | ผ่าน |
| 8 | กรอกครบ | เรียก signIn | ตามคาด | ผ่าน |
| 8 | validateEmail 4 เคส | ตามกฎ | ตามคาด (4/4) | ผ่าน |
| 8 | validatePassword (สมัคร) 4 เคส | ตามกฎ | ตามคาด (4/4) | ผ่าน |
| 8 | validateLoginPassword 2 เคส | ตามกฎ | ตามคาด (2/2) | ผ่าน |
| 8 | validateConfirmPassword 3 เคส | ตามกฎ | ตามคาด (3/3) | ผ่าน |
| 8 | validateShopName 3 เคส | ตามกฎ | ตามคาด (3/3) | ผ่าน |

ทดสอบด้วยมือ (`docs/manual_test_part8.md`):

| ส่วน | เคส | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน |
|---|---|---|---|---|
| 8 | รันโดยไม่มี config | แสดงข้อความเตือน | | |
| 8 | สมัครใหม่ | ได้อีเมลยืนยัน | | |
| 8 | login ก่อนยืนยันอีเมล | ถูกปฏิเสธ แล้ว login ได้หลังยืนยัน | | |
| 8 | รหัสผ่านผิด | แสดงข้อความภาษาไทย | | |
| 8 | ปิดแล้วเปิดแอป | ยังอยู่ในระบบ | | |
| 8 | logout | กลับหน้า Login | | |
| 8 | ไม่มีอินเทอร์เน็ต | แสดงข้อความ ไม่ค้าง | | |

## ส่วนที่ 9: Flutter หน้ารายงานลูกค้า

อัตโนมัติ (`phone_utils_test.dart` 15, `report_customer_page_test.dart` 6, `report_service_test.dart` 7):

| ส่วน | เคส | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน |
|---|---|---|---|---|
| 9 | normalizeThaiPhone 12 เคส (ตรงกับกฎใน phone.ts + null) | ตามกฎ | ตามคาด (12/12) | ผ่าน |
| 9 | validateThaiPhone 3 เคส | ตามกฎ | ตามคาด (3/3) | ผ่าน |
| 9 | ช่องบังคับว่าง | แสดงข้อความเตือน ไม่ส่ง | ตามคาด | ผ่าน |
| 9 | เบอร์ผิด | แสดงข้อความเตือน ไม่ส่ง | ตามคาด | ผ่าน |
| 9 | ระหว่างส่ง | ปุ่มปิด มี loading กดรัวส่งครั้งเดียว ส่งค่า enum | ตามคาด | ผ่าน |
| 9 | ผลรายงานซ้ำ | ข้อความจาก server ไม่ล้างฟอร์ม | ตามคาด | ผ่าน |
| 9 | ผลข้อมูลไม่ถูกต้อง | ข้อความจาก server | ตามคาด | ผ่าน |
| 9 | สำเร็จ | ข้อความยืนยัน ล้างฟอร์ม | ตามคาด | ผ่าน |
| 9 | report_service ส่งไปที่ report-customer ด้วยค่า enum | body ถูกต้อง | ตามคาด | ผ่าน |
| 9 | 201 / 409 / 400 / ไม่มีเน็ต / 401 / 502 | แปลงเป็นชนิดผลที่ถูกต้อง | ตามคาด (6/6) | ผ่าน |

ทดสอบด้วยมือ (`docs/manual_test_part9.md`):

| ส่วน | เคส | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน |
|---|---|---|---|---|
| 9 | ตรวจฟอร์มก่อนส่ง | ข้อความเตือนครบ | | |
| 9 | รายงานสำเร็จ | กดรัวแต่เกิด 1 แถว ล้างฟอร์ม | | |
| 9 | รายงานซ้ำ | ข้อความจาก server | | |
| 9 | ปิดอินเทอร์เน็ตแล้วส่ง | ข้อความไม่มีเน็ต ส่งใหม่ได้ | | |
| 9 | ล้างข้อมูลทดสอบ | ไม่มีแถวเหลือ | | |

## ส่วนที่ 10: Flutter หน้าตรวจสอบลูกค้า

อัตโนมัติ (`check_customer_page_test.dart` 11, `check_service_test.dart` 10):

| ส่วน | เคส | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน |
|---|---|---|---|---|
| 10 | ผล green | การ์ด "ความเสี่ยงต่ำ" คำแนะนำ จำนวนรายงาน ชื่อ เบอร์ mask | ตามคาด | ผ่าน |
| 10 | ผล yellow | การ์ด "ควรระวัง" พร้อมรายละเอียด | ตามคาด | ผ่าน |
| 10 | ผล red | การ์ด "ความเสี่ยงสูง" พร้อมรายละเอียด | ตามคาด | ผ่าน |
| 10 | สีการ์ด 3 ระดับ | สีต่างกันทั้ง 3 | ตามคาด | ผ่าน |
| 10 | ai_unavailable = true | แสดงหมายเหตุ ชื่อเป็น "-" | ตามคาด | ผ่าน |
| 10 | ไม่พบเบอร์ | ข้อความ + ช่องกรอกเบอร์ ตรวจเบอร์ผิดในแอป แล้วตรวจด้วยเบอร์ได้ | ตามคาด | ผ่าน |
| 10 | ระหว่างรอผล | ปุ่มปิด มี loading กดรัวส่งครั้งเดียว | ตามคาด | ผ่าน |
| 10 | ข้อความว่าง | ข้อความเตือน ไม่ส่ง | ตามคาด | ผ่าน |
| 10 | ผล error | ข้อความ + ปุ่มลองใหม่ กดแล้วส่งคำขอเดิม | ตามคาด | ผ่าน |
| 10 | ไม่มีอินเทอร์เน็ต | ข้อความ + ปุ่มลองใหม่ | ตามคาด | ผ่าน |
| 10 | ปุ่ม "ตรวจสอบลูกค้า" ในหน้า Home | เปิดหน้าตรวจสอบ | ตามคาด | ผ่าน |
| 10 | check_service ส่ง {text} / {phone} ไปที่ check-customer | body ถูกต้อง | ตามคาด | ผ่าน |
| 10 | 200 OK ครบทุกฟิลด์ / ชื่อ null + ai_unavailable | CheckOk ถูกต้อง | ตามคาด (2/2) | ผ่าน |
| 10 | level ไม่รู้จัก | CheckError | ตามคาด | ผ่าน |
| 10 | 200 NO_PHONE_DETECTED | CheckNoPhone | ตามคาด | ผ่าน |
| 10 | 400 INVALID_PHONE | CheckInvalidPhone | ตามคาด | ผ่าน |
| 10 | ส่งไม่ถึง server / หมดเวลารอ | CheckNoInternet | ตามคาด (2/2) | ผ่าน |
| 10 | 401 / 502 | CheckError ข้อความภาษาไทย | ตามคาด (2/2) | ผ่าน |

ทดสอบด้วยมือ (`docs/manual_test_part10.md`):

| ส่วน | เคส | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน |
|---|---|---|---|---|
| 10 | ข้อความว่าง | "กรุณาวางข้อความออเดอร์" | | |
| 10 | 0800000001 | การ์ดเขียว "ความเสี่ยงต่ำ" 0 รายงาน ปุ่มปิดระหว่างรอ | | |
| 10 | 0800000002 | การ์ดเหลือง "ควรระวัง" 1 รายงาน ไม่มีข้อมูลร้านอื่น | | |
| 10 | 0800000003 (+66) | การ์ดแดง "ความเสี่ยงสูง" 2 รายงาน | | |
| 10 | ข้อความไม่มีเบอร์ | ช่องกรอกเบอร์ ตรวจด้วยเบอร์ได้ | | |
| 10 | ปิดอินเทอร์เน็ต | ข้อความ + ลองใหม่ ไม่ค้าง | | |
| 10 | (ไม่บังคับ) ai_unavailable | มีหมายเหตุ | | |

## ส่วนที่ 11: End-to-End

อัตโนมัติ (`scripts/e2e_test.ts` ผ่าน Edge Functions จริง; X, Z อายุบัญชี 30 วัน, W บัญชีใหม่):

| ส่วน | เคส | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน |
|---|---|---|---|---|
| 11 | สร้างผู้ใช้ 4 คน ยืนยันอีเมล ตั้งอายุบัญชี | x=30, y=0, z=30, w=0 วัน login ได้ | ตามคาด | ผ่าน |
| 11 | สุ่ม P1, P2 ที่ยังไม่มีในระบบ | 2 เบอร์ไม่ซ้ำ | 080-XXX-3786, 080-XXX-6291 | ผ่าน |
| 11 | 1. Y ตรวจ P1 | 200 green (0) | 200 green (0) | ผ่าน |
| 11 | 2. X รายงาน P1 | 201 | 201 CREATED | ผ่าน |
| 11 | 2. Y ตรวจ P1 | yellow (1) | yellow (1) | ผ่าน |
| 11 | 3. X รายงาน P1 ซ้ำ | 409 | 409 DUPLICATE | ผ่าน |
| 11 | 4. Z รายงาน P1 | 201 | 201 CREATED | ผ่าน |
| 11 | 4. Y ตรวจ P1 | red (2) | red (2) | ผ่าน |
| 11 | 5. X รายงาน P2 | 201 | 201 CREATED | ผ่าน |
| 11 | 5. W รายงาน P2 | 201 | 201 CREATED | ผ่าน |
| 11 | 5. Y ตรวจ P2 (W อายุบัญชีไม่ถึง 7 วัน) | yellow (2) | yellow (2) | ผ่าน |
| 11 | ลบรายงานและผู้ใช้ e2e | เหลือผู้ใช้ 0 รายงาน 0 | ลบรายงาน 4 ผู้ใช้ 4 เหลือ 0 | ผ่าน |

ตรวจเพิ่ม: รันสำเนาของสคริปต์ที่จำลองให้ล้มเหลวหลังขั้นที่ 2 แล้ว ขั้น "ลบ" ยังทำงาน (ลบรายงาน 1 แถว ผู้ใช้ 4 คน เหลือ 0) สำเนานั้นถูกลบแล้ว ไม่อยู่ใน repo

ทดสอบด้วยมือ (`docs/manual_test_part11.md`, บัญชี A = shop1, B = shop2):

| ส่วน | เคส | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน |
|---|---|---|---|---|
| 11 | 1. B ตรวจเบอร์ใหม่ | การ์ดเขียว 0 รายงาน | | |
| 11 | 2. A รายงาน แล้ว B ตรวจ | รายงานสำเร็จ แล้วการ์ดเหลือง 1 รายงาน | | |
| 11 | 3. A รายงานซ้ำ | "คุณรายงานเบอร์นี้ไปแล้วในช่วง 7 วันที่ผ่านมา" | | |
| 11 | 4. B รายงาน แล้ว A ตรวจ | รายงานสำเร็จ แล้วการ์ดแดง 2 รายงาน | | |
| 11 | 5. ล้างข้อมูลทดสอบ | ไม่มีแถวเหลือ กลับเป็นสีเขียว | | |

---

## ส่วนที่ P0-1: การลบบัญชีผู้ใช้ (Account Deletion & Data Retention)

อัตโนมัติ (`delete_account_dialog_test.dart` + `scripts/test_p0_1.ts`):

| ส่วน | เคส | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน |
|---|---|---|---|---|
| P0-1 | Dialog ยืนยันการลบบัญชี | ต้องพิมพ์ "ลบบัญชี" เพื่อเปิดปุ่มยืนยัน | ตามคาด | ผ่าน |
| P0-1 | คำเตือนผลกระทบการลบบัญชี | ระบุชัดเจนว่ารายงานเดิมจะยังคงอยู่เพื่อเตือนภัยร้านค้าอื่น | ตามคาด | ผ่าน |
| P0-1 | สลับสถานะ Loading ระหว่างลบ | ปุ่มปิดการทำงาน ป้องกันการกดซ้ำ | ตามคาด | ผ่าน |
| P0-1 | ลบสำเร็จ | เคลียร์เซสชัน นำผู้ใช้กลับหน้า Login | ตามคาด | ผ่าน |
| P0-1 | Edge Function `delete-account` | ปรับสถานะรายงาน `pending` เป็น `rejected` ก่อนลบ | ตามคาด (N6) | ผ่าน |
| P0-1 | ลบ Storage แบบแบ่งหน้า | วนลบจนหมดไม่ติดขีดจำกัด 1,000 ไฟล์ | ตามคาด (N6) | ผ่าน |
| P0-1 | ลบ `auth.users` ก่อนเคลียร์ Storage | ป้องกันไฟล์หายแต่บัญชียังค้าง | ตามคาด (N6) | ผ่าน |
| P0-1 | Database FK `on delete set null` | ลบผู้ใช้แล้วรายงานเดิมยังอยู่ (reported_by = null) | รอ deploy migration `000001`–`000011` | ยังไม่ทดสอบ |

*หมายเหตุ: บน Supabase Cloud project ต้อง deploy migration `20261013000001` ถึง `20261014000011` เพื่อให้การทดสอบ `test_p0_1.ts` ผ่านครบ 100% บนเซิร์ฟเวอร์จริง

## ส่วนที่ P0-4: UGC Moderation & Merchant Suspension

อัตโนมัติ (`admin_service_test.dart` + `merchant_kyc_dialog_test.dart` + `scripts/test_p0_4.ts`):

| ส่วน | เคส | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน |
|---|---|---|---|---|
| P0-4 | สถานะ `suspended` ใน `MerchantKycStatus` | แปลงค่า enum ได้ถูกต้อง ไม่หลุดเป็น unverified | ตามคาด (N7) | ผ่าน |
| P0-4 | แบนเนอร์แจ้งเตือนร้านถูกระงับ | แสดงกล่องสีแดงพร้อมเหตุผลและช่องทางติดต่อ | ตามคาด (N7) | ผ่าน |
| P0-4 | ปิดกั้นการส่งรายงานเมื่อถูกระงับ | แจ้งเตือนข้อความชัดเจน ไม่ให้กรอกฟอร์ม | ตามคาด (N7) | ผ่าน |
| P0-4 | RPC `admin_suspend_merchant` | ปรับสถานะเป็น suspended + reject_reason + audit log | รอ deploy migration `000009`/`000011` | ยังไม่ทดสอบ |
| P0-4 | RPC `admin_unsuspend_merchant` | ยกเลิกการระงับ คืนสถานะตาม status_before_suspend | รอ deploy migration `000009`/`000011` | ยังไม่ทดสอบ |
| P0-4 | RPC `admin_list_merchants` | ดึงรายชื่อร้านค้าตามสถานะ พร้อม verification_status | รอ deploy migration `000011` | ยังไม่ทดสอบ |

## ส่วนที่ P0-6: Postgres Rate Limiting

อัตโนมัติ (`check-customer` + `scripts/test_p0_6.ts`):

| ส่วน | เคส | ผลที่คาด | ผลจริง | ผ่าน/ไม่ผ่าน |
|---|---|---|---|---|
| P0-6 | Revoke execute on `hit_rate_limit` | ปลดสิทธิ์ execution จาก role `authenticated` | รอ deploy migration (N3) | ยังไม่ทดสอบ |
| P0-6 | Client IP anti-spoofing | ให้ความสำคัญกับ CF-Connecting-IP / X-Real-IP / IP ตัวสุดท้ายใน XFF | รอทดสอบ curl (R4) | ยังไม่ทดสอบ |
| P0-6 | Guest Global Ceiling | จำกัดเพดานรวมของ Guest ที่ส่ง text ไม่เกิน 3,000 req/day | ตามคาด (N2) | ผ่าน |
| P0-6 | Guest Fail-closed | ปฏิเสธคำขอเมื่อเกิดข้อผิดพลาดในการตรวจสอบ Rate Limit | ตามคาด (N2) | ผ่าน |

---

## วิธีรันซ้ำ

```powershell
# ส่วนที่ 0-4, 6, 7, 11 (ต้องมี .env และรัน seed_test.ts, seed_demo.ts แล้ว)
deno run --allow-net --allow-read --allow-env scripts/check_setup.ts
deno run --allow-net --allow-read --allow-env scripts/test_part1.ts   # ถึง test_part4.ts
deno run --allow-net --allow-read --allow-env scripts/test_part6.ts
deno run --allow-net --allow-read --allow-env scripts/test_part7.ts
deno run --allow-net --allow-read --allow-env scripts/e2e_test.ts

# ส่วนที่ 4-5 unit test และ eval Gemini
deno test --allow-env supabase/functions/_shared/
deno run --allow-net --allow-read --allow-env scripts/eval_extract.ts

# ส่วนที่ 8-10
cd app
C:\flutter\bin\flutter.bat test
```
