// Edge Function: ล้างภาพหลักฐาน (12 เดือน) และแถวรายงาน (24 เดือน) ตามนโยบาย PDPA (R5.1, P1-5)
// รองรับการเรียกจาก Cron (pg_cron), Scheduled Task หรือแอดมินระบบ
// ป้องกันการเข้าถึงด้วย Service Role Key หรือ Admin JWT

import { createClient } from "npm:@supabase/supabase-js@2";
import { purgeAllExpired } from "./purge.ts";

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

    // 2) รันการล้างข้อมูลหมดอายุ (หลักฐาน 12 เดือน, รายงาน 24 เดือน, rate limits 2 วัน)
    const result = await purgeAllExpired(admin);

    return json(200, {
      ok: true,
      cutoff_date: result.evidenceCutoffIso,
      evidence_cutoff_date: result.evidenceCutoffIso,
      report_cutoff_date: result.reportCutoffIso,
      deleted_files_count: result.deletedFilesCount,
      updated_reports_count: result.updatedReportsCount,
      deleted_reports_count: result.deletedReportsCount,
      cleaned_rate_limits: result.cleanedRateLimits,
      message: "Purged expired evidences, reports, and rate limits successfully",
    });
  } catch (err) {
    console.error("purge-old-evidence unexpected error:", err);
    return json(500, { error: "Internal Server Error" });
  }
});
