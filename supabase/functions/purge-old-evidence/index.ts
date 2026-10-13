// Edge Function: ล้างภาพหลักฐานและข้อมูลที่หมดอายุตามนโยบาย PDPA (12 เดือน) (R5.1)
// รองรับการเรียกจาก Cron (pg_cron), Scheduled Task หรือแอดมินระบบ
// ป้องกันการเข้าถึงด้วย Service Role Key หรือ Admin JWT

import { createClient } from "npm:@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json; charset=utf-8" },
  });
}

const admin = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  { auth: { persistSession: false, autoRefreshToken: false } },
);

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return json(405, { error: "Method Not Allowed" });
  }

  try {
    // 1) ตรวจสอบสิทธิ์: ต้องมี Bearer token (Service Role Key หรือ Admin User)
    const authHeader = req.headers.get("Authorization") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const isServiceRole = serviceKey.length > 0 && authHeader === `Bearer ${serviceKey}`;

    if (!isServiceRole) {
      const token = authHeader.match(/^Bearer\s+(.+)$/i)?.[1];
      if (!token) return json(401, { error: "UNAUTHORIZED" });
      const { data: auth, error: authErr } = await admin.auth.getUser(token);
      if (authErr || !auth.user) return json(401, { error: "UNAUTHORIZED" });

      // ตรวจสอบสิทธิ์ admin จาก admin_users หรือ app_metadata
      const { data: adminUser, error: adminErr } = await admin
        .from("admin_users")
        .select("id")
        .eq("user_id", auth.user.id)
        .maybeSingle();

      const isAppAdmin =
        auth.user.app_metadata?.role === "admin" || (!adminErr && !!adminUser);
      if (!isAppAdmin) return json(403, { error: "FORBIDDEN" });
    }

    // 2) คำนวณวันที่ย้อนหลัง 12 เดือน (Rolling window 365 วัน)
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - 365);
    const cutoffIso = cutoffDate.toISOString();

    let deletedFilesCount = 0;
    let updatedReportsCount = 0;
    const BATCH_SIZE = 500;
    let lastSeenId: string | null = null;

    // 3) ค้นหารายงานที่มี evidence_path และสร้างก่อน cutoffDate (วนซ้ำเป็น Batch จนหมด)
    while (true) {
      let query = admin
        .from("cod_reports")
        .select("id, evidence_path")
        .not("evidence_path", "is", null)
        .lt("created_at", cutoffIso)
        .order("id", { ascending: true })
        .limit(BATCH_SIZE);

      if (lastSeenId) {
        query = query.gt("id", lastSeenId);
      }

      const { data: oldReports, error: queryErr } = await query;

      if (queryErr) {
        console.error("Query old reports error:", queryErr.message);
        return json(500, { error: "Failed to query expired reports" });
      }

      if (!oldReports || oldReports.length === 0) {
        break;
      }

      lastSeenId = oldReports[oldReports.length - 1].id;

      const reportItems = oldReports.map((report) => ({
        id: report.id,
        paths: report.evidence_path
          ? report.evidence_path
              .split(",")
              .map((p: string) => p.trim())
              .filter((p: string) => p.length > 0)
          : [],
      }));

      const reportIdsToClear: string[] = [];

      // 3.1) รายงานที่ไม่มีพาธไฟล์ที่ถูกต้อง (เช่น สตริงว่าง) สามารถล้างเป็น null ได้ทันที
      for (const r of reportItems) {
        if (r.paths.length === 0) {
          reportIdsToClear.push(r.id);
        }
      }

      // 3.2) รายงานที่มีไฟล์ ต้องลบไฟล์ออกจาก Storage ให้สำเร็จก่อน จึงจะล้าง evidence_path ได้
      const reportsWithFiles = reportItems.filter((r) => r.paths.length > 0);
      const CHUNK_SIZE = 50;

      for (let i = 0; i < reportsWithFiles.length; i += CHUNK_SIZE) {
        const chunk = reportsWithFiles.slice(i, i + CHUNK_SIZE);
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
          // หาก batch ภาพรวมมีข้อผิดพลาด ให้ลองลบทีละรายงานเพื่อคัดเฉพาะรายงานที่ลบไฟล์สำเร็จ
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

      // 3.3) ปรับ evidence_path ให้เป็น null เฉพาะรายงานที่ลบไฟล์ใน Storage สำเร็จเท่านั้น
      if (reportIdsToClear.length > 0) {
        const { error: updateErr } = await admin
          .from("cod_reports")
          .update({ evidence_path: null })
          .in("id", reportIdsToClear);

        if (updateErr) {
          console.error("Update cod_reports error:", updateErr.message);
          return json(500, { error: "Failed to update cod_reports evidence_path" });
        }

        updatedReportsCount += reportIdsToClear.length;
      }

      if (oldReports.length < BATCH_SIZE) {
        break;
      }
    }

    // 4) ทำความสะอาดตาราง rate_limits ที่เก่าเกิน 2 วัน
    const twoDaysAgo = new Date();
    twoDaysAgo.setDate(twoDaysAgo.getDate() - 2);
    const { error: rlErr } = await admin
      .from("rate_limits")
      .delete()
      .lt("window_start", twoDaysAgo.toISOString());

    if (rlErr) {
      console.warn("Clean rate_limits error:", rlErr.message);
    }

    return json(200, {
      ok: true,
      cutoff_date: cutoffIso,
      deleted_files_count: deletedFilesCount,
      updated_reports_count: updatedReportsCount,
      message: "Purged expired evidences and rate limits successfully",
    });
  } catch (err) {
    console.error("purge-old-evidence unexpected error:", err);
    return json(500, { error: "Internal Server Error" });
  }
});
