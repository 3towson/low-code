// จัดการเบอร์โทร: normalize, hash (HMAC-SHA256) และ mask
// ใช้ใน Edge Function เท่านั้น ห้ามเก็บหรือ log เบอร์จริง

const THAI_MOBILE = /^0[689]\d{8}$/;

// แปลงเลขไทย ๐-๙ (U+0E50-U+0E59) เป็น 0-9
function thaiDigitsToArabic(s: string): string {
  return s.replace(/[๐-๙]/g, (c) => String(c.charCodeAt(0) - 0x0e50));
}

// คืนเบอร์มือถือไทยรูปแบบ 0XXXXXXXXX หรือ null ถ้าไม่ใช่เบอร์มือถือไทย
export function normalizeThaiPhone(raw: string): string | null {
  let digits = thaiDigitsToArabic(raw ?? "").replace(/\D/g, "");
  if (digits.startsWith("66") && digits.length === 11) {
    digits = "0" + digits.slice(2);
  }
  return THAI_MOBILE.test(digits) ? digits : null;
}

// HMAC-SHA256(secret, normalized) คืนค่าเป็น hex ตัวเล็ก 64 ตัวอักษร
export async function hashPhone(normalized: string, secret: string): Promise<string> {
  if (!secret) throw new Error("PHONE_HASH_SECRET ว่าง");
  if (!THAI_MOBILE.test(normalized)) throw new Error("เบอร์โทรยังไม่ได้ normalize");
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = new Uint8Array(await crypto.subtle.sign("HMAC", key, enc.encode(normalized)));
  return Array.from(sig, (b) => b.toString(16).padStart(2, "0")).join("");
}

// 0812345678 -> 081-XXX-5678
export function maskPhone(normalized: string): string {
  if (!THAI_MOBILE.test(normalized)) throw new Error("เบอร์โทรยังไม่ได้ normalize");
  return `${normalized.slice(0, 3)}-XXX-${normalized.slice(6)}`;
}
