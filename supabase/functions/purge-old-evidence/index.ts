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
        .eq("id", auth.user.id)
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

    // 3) ค้นหารายงานที่มี evidence_path และสร้างก่อน cutoffDate (วนซ้ำเป็น Batch จนหมด)
    while (true) {
      const { data: oldReports, error: queryErr } = await admin
        .from("cod_reports")
        .select("id, evidence_path")
        .not("evidence_path", "is", null)
        .lt("created_at", cutoffIso)
        .limit(BATCH_SIZE);

      if (queryErr) {
        console.error("Query old reports error:", queryErr.message);
        return json(500, { error: "Failed to query expired reports" });
      }

      if (!oldReports || oldReports.length === 0) {
        break;
      }

      const filePathsToDelete: string[] = [];
      const reportIdsToClear: string[] = [];

      for (const report of oldReports) {
        reportIdsToClear.push(report.id);
        if (report.evidence_path) {
          const paths = report.evidence_path
            .split(",")
            .map((p: string) => p.trim())
            .filter((p: string) => p.length > 0);
          filePathsToDelete.push(...paths);
        }
      }

      // ลบไฟล์จาก Storage Bucket 'report-evidences' (ทีละ batch 100 ไฟล์)
      for (let i = 0; i < filePathsToDelete.length; i += 100) {
        const batch = filePathsToDelete.slice(i, i + 100);
        const { error: removeErr } = await admin.storage
          .from("report-evidences")
          .remove(batch);
        if (removeErr) {
          console.warn("Storage remove batch error:", removeErr.message);
        } else {
          deletedFilesCount += batch.length;
        }
      }

      // ปรับ evidence_path ให้เป็น null ในตาราง cod_reports
      const { error: updateErr } = await admin
        .from("cod_reports")
        .update({ evidence_path: null })
        .in("id", reportIdsToClear);

      if (updateErr) {
        console.error("Update cod_reports error:", updateErr.message);
        return json(500, { error: "Failed to update cod_reports evidence_path" });
      }

      updatedReportsCount += reportIdsToClear.length;

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
