import { assertEquals } from "jsr:@std/assert@1";
import {
  calculateCutoffs,
  purgeAllExpired,
  purgeExpiredEvidences,
  purgeExpiredRateLimits,
  purgeExpiredReports,
} from "./purge.ts";

Deno.test("calculateCutoffs: คำนวณวันที่ cutoff ถูกต้องตามเกณฑ์", () => {
  const baseDate = new Date("2026-10-15T12:00:00.000Z");
  const cutoffs = calculateCutoffs(baseDate);

  // หลักฐาน 12 เดือน (365 วัน)
  const expectedEvidence = new Date("2025-10-15T12:00:00.000Z");
  assertEquals(cutoffs.evidenceCutoff.toISOString(), expectedEvidence.toISOString());

  // รายงาน 24 เดือน (730 วัน)
  const expectedReport = new Date("2024-10-15T12:00:00.000Z");
  assertEquals(cutoffs.reportCutoff.toISOString(), expectedReport.toISOString());

  // rate limits 2 วัน
  const expectedRateLimit = new Date("2026-10-13T12:00:00.000Z");
  assertEquals(cutoffs.rateLimitCutoff.toISOString(), expectedRateLimit.toISOString());
});

Deno.test("purgeExpiredReports: ลบแถว cod_reports ที่เก่ากว่า 24 เดือนเป็น batch", async () => {
  // จำลองตารางรายงานที่มี 5 แถวเก่า
  const mockRows = [
    { id: "rep-1", created_at: "2024-01-01T00:00:00Z" },
    { id: "rep-2", created_at: "2024-02-01T00:00:00Z" },
    { id: "rep-3", created_at: "2024-03-01T00:00:00Z" },
    { id: "rep-4", created_at: "2024-04-01T00:00:00Z" },
    { id: "rep-5", created_at: "2024-05-01T00:00:00Z" },
  ];

  let currentRows = [...mockRows];
  const deletedBatches: string[][] = [];

  const mockAdmin = {
    from: (table: string) => {
      assertEquals(table, "cod_reports");
      return {
        select: (_fields: string) => ({
          lt: (_col: string, _val: string) => ({
            order: (_col: string, _opts: unknown) => ({
              limit: (limit: number) => {
                const batch = currentRows.slice(0, limit);
                return Promise.resolve({ data: batch, error: null });
              },
            }),
          }),
        }),
        delete: () => ({
          in: (_col: string, ids: string[]) => {
            deletedBatches.push(ids);
            currentRows = currentRows.filter((r) => !ids.includes(r.id));
            return Promise.resolve({ error: null });
          },
        }),
      };
    },
  };

  const count = await purgeExpiredReports(mockAdmin, "2024-10-15T00:00:00Z", 2);

  assertEquals(count, 5);
  // batchSize = 2 จึงต้องวนลบ 3 รอบ: [rep-1, rep-2], [rep-3, rep-4], [rep-5]
  assertEquals(deletedBatches.length, 3);
  assertEquals(deletedBatches[0], ["rep-1", "rep-2"]);
  assertEquals(deletedBatches[1], ["rep-3", "rep-4"]);
  assertEquals(deletedBatches[2], ["rep-5"]);
  assertEquals(currentRows.length, 0);
});

Deno.test("purgeExpiredReports: ไม่มีรายงานเก่า ไม่ทำอะไรและคืนค่า 0", async () => {
  const mockAdmin = {
    from: () => ({
      select: () => ({
        lt: () => ({
          order: () => ({
            limit: () => Promise.resolve({ data: [], error: null }),
          }),
        }),
      }),
    }),
  };

  const count = await purgeExpiredReports(mockAdmin, "2024-10-15T00:00:00Z", 100);
  assertEquals(count, 0);
});

Deno.test("purgeExpiredEvidences: ลบไฟล์ใน storage และเคลียร์ evidence_path", async () => {
  const mockReports = [
    { id: "rep-old-1", evidence_path: "evidence/1.jpg, evidence/2.jpg" },
    { id: "rep-old-2", evidence_path: "" }, // ไม่มีไฟล์ เคลียร์ได้ทันที
  ];

  const removedStoragePaths: string[] = [];
  const clearedReportIds: string[] = [];

  const mockAdmin = {
    from: (table: string) => {
      assertEquals(table, "cod_reports");
      return {
        select: () => ({
          not: () => ({
            lt: () => ({
              order: () => ({
                limit: () => Promise.resolve({ data: mockReports, error: null }),
              }),
            }),
          }),
        }),
        update: (values: Record<string, unknown>) => {
          assertEquals(values.evidence_path, null);
          return {
            in: (_col: string, ids: string[]) => {
              clearedReportIds.push(...ids);
              return Promise.resolve({ error: null });
            },
          };
        },
      };
    },
    storage: {
      from: (bucket: string) => {
        assertEquals(bucket, "report-evidences");
        return {
          remove: (paths: string[]) => {
            removedStoragePaths.push(...paths);
            return Promise.resolve({ error: null });
          },
        };
      },
    },
  };

  const res = await purgeExpiredEvidences(mockAdmin, "2025-10-15T00:00:00Z", 50, 50);

  assertEquals(res.deletedFilesCount, 2);
  assertEquals(res.updatedReportsCount, 2);
  assertEquals(removedStoragePaths, ["evidence/1.jpg", "evidence/2.jpg"]);
  assertEquals(clearedReportIds, ["rep-old-2", "rep-old-1"]);
});

Deno.test("purgeExpiredRateLimits: ลบแถว rate_limits ที่เก่ากว่า 2 วัน", async () => {
  let deletedBeforeIso = "";
  const mockAdmin = {
    from: (table: string) => {
      assertEquals(table, "rate_limits");
      return {
        delete: () => ({
          lt: (_col: string, val: string) => {
            deletedBeforeIso = val;
            return Promise.resolve({ error: null });
          },
        }),
      };
    },
  };

  const ok = await purgeExpiredRateLimits(mockAdmin, "2026-10-13T00:00:00Z");
  assertEquals(ok, true);
  assertEquals(deletedBeforeIso, "2026-10-13T00:00:00Z");
});

Deno.test("purgeAllExpired: ทำงานครบทุกส่วนและคืนผลสรุปถูกต้อง", async () => {
  const mockAdmin = {
    from: (table: string) => {
      if (table === "cod_reports") {
        return {
          select: (fields: string) => {
            if (fields.includes("evidence_path")) {
              return {
                not: () => ({
                  lt: () => ({
                    order: () => ({
                      limit: () => Promise.resolve({ data: [], error: null }),
                    }),
                  }),
                }),
              };
            }
            return {
              lt: () => ({
                order: () => ({
                  limit: () => Promise.resolve({ data: [], error: null }),
                }),
              }),
            };
          },
        };
      }
      if (table === "rate_limits") {
        return {
          delete: () => ({
            lt: () => Promise.resolve({ error: null }),
          }),
        };
      }
      throw new Error(`Unexpected table ${table}`);
    },
    storage: {
      from: () => ({
        remove: () => Promise.resolve({ error: null }),
      }),
    },
  };

  const res = await purgeAllExpired(mockAdmin, { now: new Date("2026-10-15T00:00:00Z") });
  assertEquals(res.ok, true);
  assertEquals(res.deletedFilesCount, 0);
  assertEquals(res.deletedReportsCount, 0);
  assertEquals(res.cleanedRateLimits, true);
});
