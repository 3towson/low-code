// รัน: deno test supabase/functions/_shared/period.test.ts

import { assertEquals } from "jsr:@std/assert@1";
import { reportPeriod } from "./period.ts";

const NOW = new Date("2026-09-25T12:00:00Z");
const daysAgo = (d: number) => new Date(NOW.getTime() - d * 24 * 60 * 60 * 1000).toISOString();

const CASES: [string, string | null, string | null][] = [
  ["ไม่มีรายงาน (null)", null, null],
  ["วันที่อ่านไม่ได้", "not-a-date", null],
  ["เพิ่งรายงาน", daysAgo(0), "within_30_days"],
  ["30 วันพอดี", daysAgo(30), "within_30_days"],
  ["31 วัน", daysAgo(31), "1_to_3_months"],
  ["90 วันพอดี", daysAgo(90), "1_to_3_months"],
  ["91 วัน", daysAgo(91), "3_to_12_months"],
  ["364 วัน", daysAgo(364), "3_to_12_months"],
  ["เวลาอนาคต (นาฬิกาคลาดเคลื่อน)", daysAgo(-1), "within_30_days"],
  ["รูปแบบ timestamptz ของ Postgres", "2026-09-20 08:30:00.123+00", "within_30_days"],
];

for (const [name, input, expected] of CASES) {
  Deno.test(`reportPeriod: ${name} -> ${expected}`, () => {
    assertEquals(reportPeriod(input, NOW), expected);
  });
}
