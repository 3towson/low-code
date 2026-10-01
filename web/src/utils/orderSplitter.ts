/**
 * orderSplitter.ts
 * แยกข้อความออเดอร์หรือเบอร์โทรศัพท์หลายรายการ ให้ทำงานเหมือน Flutter order_splitter.dart
 */

export const MAX_ORDERS_PER_CHECK = 10;

const THAI_MOBILE = /^0[689]\d{8}$/;
const NON_DIGIT = /\D/g;

/**
 * แปลงเลขไทย ๐-๙ (U+0E50-U+0E59) เป็น 0-9
 */
export function thaiDigitsToArabic(s: string): string {
  return s.replace(/[๐-๙]/g, (c) => String(c.charCodeAt(0) - 0x0e50));
}

/**
 * คืนเบอร์มือถือไทยรูปแบบ 0XXXXXXXXX หรือ null ถ้าไม่ใช่เบอร์มือถือไทย
 */
export function normalizeThaiPhone(raw: string | null | undefined): string | null {
  if (!raw) return null;
  let digits = thaiDigitsToArabic(raw).replace(NON_DIGIT, "");
  if (digits.startsWith("66") && digits.length === 11) {
    digits = "0" + digits.slice(2);
  }
  return THAI_MOBILE.test(digits) ? digits : null;
}

const DIGIT_RUN = /[0-9๐-๙]+(?:[ \t\-.()]+[0-9๐-๙]+)*/g;
const DIGIT_GROUP = /[0-9๐-๙]+/g;

/**
 * ตรวจสอบว่ามีเบอร์มือถือไทยอยู่ในข้อความหรือไม่
 */
export function containsThaiMobile(text: string): boolean {
  const arabic = thaiDigitsToArabic(text);
  const runs = arabic.match(DIGIT_RUN) || [];
  for (const run of runs) {
    const groups = run.match(DIGIT_GROUP) || [];
    for (let i = 0; i < groups.length; i++) {
      let digits = "";
      for (let j = i; j < groups.length && digits.length < 11; j++) {
        digits += groups[j];
        if (normalizeThaiPhone(digits)) return true;
      }
    }
  }
  return false;
}

const BLANK_LINES = /\n[ \t]*(?:\n[ \t]*)+/;

export function getOrdersWithPhone(text: string): string[] {
  const normalized = text.replace(/\r\n/g, "\n");

  // 1. แยกด้วยบรรทัดว่างก่อน (กรณีออเดอร์หลายบรรทัด)
  const blankSeparated = normalized
    .split(BLANK_LINES)
    .map((chunk) => chunk.trim())
    .filter((chunk) => chunk.length > 0 && containsThaiMobile(chunk));

  if (blankSeparated.length > 1) {
    return blankSeparated;
  }

  // 2. ถ้าไม่ได้แยกด้วยบรรทัดว่าง ตรวจสอบว่าแยกเป็นบรรทัดๆ (หรือคั่นด้วย comma/semicolon) แล้วมีเบอร์ทุกบรรทัดหรือไม่
  // เช่น 0924582481\n0959307725 หรือ 0924582481, 0959307725
  const lines = normalized
    .split(/[\n,;]+/)
    .map((l) => l.trim())
    .filter((l) => l.length > 0);

  if (lines.length > 1 && lines.every((l) => containsThaiMobile(l))) {
    return lines;
  }

  return blankSeparated;
}

/**
 * แยกข้อความเป็นออเดอร์
 * ถ้าได้ไม่ถึง 2 ออเดอร์ คืนข้อความทั้งก้อน
 * ได้ไม่เกิน MAX_ORDERS_PER_CHECK ออเดอร์
 */
export function splitOrders(text: string): string[] {
  const orders = getOrdersWithPhone(text);
  if (orders.length <= 1) return [text];
  return orders.slice(0, MAX_ORDERS_PER_CHECK);
}

/**
 * true เมื่อข้อความมีออเดอร์ที่มีเบอร์เกิน MAX_ORDERS_PER_CHECK
 */
export function exceedsOrderLimit(text: string): boolean {
  return getOrdersWithPhone(text).length > MAX_ORDERS_PER_CHECK;
}
