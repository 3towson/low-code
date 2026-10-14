// ฟังก์ชันจัดการการล้างข้อมูลหมดอายุตามนโยบาย PDPA (หลักฐาน 12 เดือน, รายงาน 24 เดือน)

export interface PurgeOptions {
  now?: Date;
  batchSize?: number;
  storageChunkSize?: number;
}

export interface PurgeResult {
  ok: boolean;
  evidenceCutoffIso: string;
  reportCutoffIso: string;
  deletedFilesCount: number;
  updatedReportsCount: number;
  deletedReportsCount: number;
  cleanedRateLimits: boolean;
}

export function calculateCutoffs(now: Date = new Date()) {
  const evidenceCutoff = new Date(now);
  evidenceCutoff.setDate(evidenceCutoff.getDate() - 365); // 12 เดือน (365 วัน)

  const reportCutoff = new Date(now);
  reportCutoff.setDate(reportCutoff.getDate() - 730); // 24 เดือน (730 วัน)

  const rateLimitCutoff = new Date(now);
  rateLimitCutoff.setDate(rateLimitCutoff.getDate() - 2); // 2 วัน

  return {
    evidenceCutoff,
    evidenceCutoffIso: evidenceCutoff.toISOString(),
    reportCutoff,
    reportCutoffIso: reportCutoff.toISOString(),
    rateLimitCutoff,
    rateLimitCutoffIso: rateLimitCutoff.toISOString(),
  };
}

export async function purgeExpiredReports(
  // deno-lint-ignore no-explicit-any
  admin: any,
  reportCutoffIso: string,
  batchSize = 500,
): Promise<number> {
  let deletedReportsCount = 0;

  while (true) {
    const { data: oldReports, error: queryErr } = await admin
      .from("cod_reports")
      .select("id")
      .lt("created_at", reportCutoffIso)
      .order("created_at", { ascending: true })
      .limit(batchSize);

    if (queryErr) {
      throw new Error(`Failed to query expired reports for deletion: ${queryErr.message}`);
    }

    if (!oldReports || oldReports.length === 0) {
      break;
    }

    const idsToDelete = oldReports.map((r: { id: string }) => r.id);
    const { error: deleteErr } = await admin
      .from("cod_reports")
      .delete()
      .in("id", idsToDelete);

    if (deleteErr) {
      throw new Error(`Failed to delete expired cod_reports: ${deleteErr.message}`);
    }

    deletedReportsCount += idsToDelete.length;

    if (oldReports.length < batchSize) {
      break;
    }
  }

  return deletedReportsCount;
}

export async function purgeExpiredEvidences(
  // deno-lint-ignore no-explicit-any
  admin: any,
  evidenceCutoffIso: string,
  batchSize = 500,
  chunkSize = 50,
): Promise<{ deletedFilesCount: number; updatedReportsCount: number }> {
  let deletedFilesCount = 0;
  let updatedReportsCount = 0;
  let lastSeenId: string | null = null;

  while (true) {
    let query = admin
      .from("cod_reports")
      .select("id, evidence_path")
      .not("evidence_path", "is", null)
      .lt("created_at", evidenceCutoffIso)
      .order("id", { ascending: true })
      .limit(batchSize);

    if (lastSeenId) {
      query = query.gt("id", lastSeenId);
    }

    const { data: oldReports, error: queryErr } = await query;
    if (queryErr) {
      throw new Error(`Failed to query expired evidence reports: ${queryErr.message}`);
    }

    if (!oldReports || oldReports.length === 0) {
      break;
    }

    lastSeenId = oldReports[oldReports.length - 1].id;

    const reportItems = oldReports.map((report: { id: string; evidence_path: string | null }) => ({
      id: report.id,
      paths: report.evidence_path
        ? report.evidence_path
            .split(",")
            .map((p: string) => p.trim())
            .filter((p: string) => p.length > 0)
        : [],
    }));

    const reportIdsToClear: string[] = [];

    // 1) รายงานที่ไม่มีพาธไฟล์ที่ถูกต้อง (เช่น สตริงว่าง) สามารถล้างเป็น null ได้ทันที
    for (const r of reportItems) {
      if (r.paths.length === 0) {
        reportIdsToClear.push(r.id);
      }
    }

    // 2) รายงานที่มีไฟล์ ต้องลบไฟล์ออกจาก Storage ให้สำเร็จก่อน จึงจะล้าง evidence_path ได้
    const reportsWithFiles = reportItems.filter((r) => r.paths.length > 0);

    for (let i = 0; i < reportsWithFiles.length; i += chunkSize) {
      const chunk = reportsWithFiles.slice(i, i + chunkSize);
      const chunkPaths = chunk.flatMap((r) => r.paths);

      const { error: removeErr } = await admin.storage
        .from("report-evidences")
        .remove(chunkPaths);

      if (!removeErr) {
        deletedFilesCount += chunkPaths.length;
        for (const r of chunk) {
          reportIdsToClear.push(r.id);
        }
      } else {
        console.warn("Storage remove chunk error, retrying per report:", removeErr.message);
        for (const r of chunk) {
          const { error: singleErr } = await admin.storage
            .from("report-evidences")
            .remove(r.paths);

          if (singleErr) {
            console.warn(`Storage remove failed for report ${r.id}:`, singleErr.message);
          } else {
            deletedFilesCount += r.paths.length;
            reportIdsToClear.push(r.id);
          }
        }
      }
    }

    // 3) ปรับ evidence_path ให้เป็น null เฉพาะรายงานที่ลบไฟล์ใน Storage สำเร็จเท่านั้น
    if (reportIdsToClear.length > 0) {
      const { error: updateErr } = await admin
        .from("cod_reports")
        .update({ evidence_path: null })
        .in("id", reportIdsToClear);

      if (updateErr) {
        throw new Error(`Failed to update cod_reports evidence_path: ${updateErr.message}`);
      }

      updatedReportsCount += reportIdsToClear.length;
    }

    if (oldReports.length < batchSize) {
      break;
    }
  }

  return { deletedFilesCount, updatedReportsCount };
}

export async function purgeExpiredRateLimits(
  // deno-lint-ignore no-explicit-any
  admin: any,
  rateLimitCutoffIso: string,
): Promise<boolean> {
  const { error: rlErr } = await admin
    .from("rate_limits")
    .delete()
    .lt("window_start", rateLimitCutoffIso);

  if (rlErr) {
    console.warn("Clean rate_limits error:", rlErr.message);
    return false;
  }
  return true;
}

export async function purgeAllExpired(
  // deno-lint-ignore no-explicit-any
  admin: any,
  options: PurgeOptions = {},
): Promise<PurgeResult> {
  const cutoffs = calculateCutoffs(options.now);
  const batchSize = options.batchSize ?? 500;
  const storageChunkSize = options.storageChunkSize ?? 50;

  // 1) ล้างไฟล์หลักฐาน (12 เดือน)
  const { deletedFilesCount, updatedReportsCount } = await purgeExpiredEvidences(
    admin,
    cutoffs.evidenceCutoffIso,
    batchSize,
    storageChunkSize,
  );

  // 2) ลบแถวรายงาน cod_reports (24 เดือน) เป็น batch
  const deletedReportsCount = await purgeExpiredReports(
    admin,
    cutoffs.reportCutoffIso,
    batchSize,
  );

  // 3) ล้าง rate limits เก่าเกิน 2 วัน
  const cleanedRateLimits = await purgeExpiredRateLimits(
    admin,
    cutoffs.rateLimitCutoffIso,
  );

  return {
    ok: true,
    evidenceCutoffIso: cutoffs.evidenceCutoffIso,
    reportCutoffIso: cutoffs.reportCutoffIso,
    deletedFilesCount,
    updatedReportsCount,
    deletedReportsCount,
    cleanedRateLimits,
  };
}
