// ข้อมูลสาธิตส่วนที่ 4 ใช้ร่วมกันระหว่าง seed_demo.ts และ test_part4.ts
// เบอร์สมมติเท่านั้น ในฐานข้อมูลเก็บเฉพาะ phone_hash

import type { ShopKey } from "./_env.ts";

export type DemoPhone = {
  phone: string;
  expected: "green" | "yellow" | "red";
  reports: [ShopKey, number][]; // [ร้าน, จำนวนวันย้อนหลัง]
};

export const DEMO_PHONES: DemoPhone[] = [
  { phone: "0800000001", expected: "green", reports: [] },
  { phone: "0800000002", expected: "yellow", reports: [["shop1", 20]] },
  { phone: "0800000003", expected: "red", reports: [["shop1", 20], ["shop2", 10]] },
];
