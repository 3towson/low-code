// รัน: deno test supabase/functions/_shared/phone.test.ts

import { assert, assertEquals, assertNotEquals, assertThrows } from "jsr:@std/assert@1";
import { hashPhone, maskPhone, normalizeThaiPhone } from "./phone.ts";

const SECRET_A = "unit-test-secret-a";
const SECRET_B = "unit-test-secret-b";

const VALID = [
  "081-234-5678",
  "081 234 5678",
  "+66812345678",
  "66812345678",
  "๐๘๑๒๓๔๕๖๗๘",
  "(081)2345678",
];

const INVALID = ["02-123-4567", "12345", "08123456789", "0512345678", ""];

for (const raw of VALID) {
  Deno.test(`normalize "${raw}" -> 0812345678`, () => {
    assertEquals(normalizeThaiPhone(raw), "0812345678");
  });
}

for (const raw of INVALID) {
  Deno.test(`normalize "${raw}" -> null`, () => {
    assertEquals(normalizeThaiPhone(raw), null);
  });
}

Deno.test("เบอร์เดียวกันต่างรูปแบบ hash ได้ค่าเดียวกัน", async () => {
  const hashes = new Set<string>();
  for (const raw of VALID) {
    hashes.add(await hashPhone(normalizeThaiPhone(raw)!, SECRET_A));
  }
  assertEquals(hashes.size, 1);
});

Deno.test("secret ต่างกัน hash ต่างกัน", async () => {
  const a = await hashPhone("0812345678", SECRET_A);
  const b = await hashPhone("0812345678", SECRET_B);
  assertNotEquals(a, b);
});

Deno.test("hash เป็น hex ตัวเล็ก 64 ตัว และไม่มีเบอร์จริง", async () => {
  const h = await hashPhone("0812345678", SECRET_A);
  assertEquals(h.length, 64);
  assert(/^[0-9a-f]{64}$/.test(h), "ต้องเป็น hex ตัวเล็ก");
  assert(!h.includes("0812345678"), "ต้องไม่มีเบอร์ 0812345678");
  assert(!h.includes("812345678"), "ต้องไม่มีเลข 812345678");
});

Deno.test("hash ปฏิเสธ secret ว่าง และเบอร์ที่ยังไม่ normalize", async () => {
  let err = false;
  try {
    await hashPhone("0812345678", "");
  } catch {
    err = true;
  }
  assert(err, "secret ว่างต้อง throw");
  err = false;
  try {
    await hashPhone("081-234-5678", SECRET_A);
  } catch {
    err = true;
  }
  assert(err, "เบอร์ที่ยังไม่ normalize ต้อง throw");
});

Deno.test("maskPhone 0812345678 -> 081-XXX-5678", () => {
  assertEquals(maskPhone("0812345678"), "081-XXX-5678");
  assertEquals(maskPhone("0998765432"), "099-XXX-5432");
  assertThrows(() => maskPhone("12345"));
});
