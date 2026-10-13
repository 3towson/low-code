// Edge Function: ลบบัญชีผู้ใช้ (Account Deletion) ตามเกณฑ์ Apple 5.1.1(v) และ Google Play
// ดำเนินการลบ:
// 1. ไฟล์หลักฐานใน Storage ทั้ง report-evidences/{uid}/ และ merchant-evidences/{uid}/
// 2. บัญชีผู้ใช้ใน auth.users (ซึ่งจะ cascade ไปยัง sellers และ set null ให้กับรายงานที่เคยส่งไว้)
// ห้าม log ข้อมูลส่วนตัว (PII)

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

async function deleteFolderFiles(bucketName: string, prefix: string): Promise<void> {
  try {
    const { data: files, error: listError } = await admin.storage
      .from(bucketName)
      .list(prefix, { limit: 1000 });

    if (listError) {
      console.error(`List files error in bucket ${bucketName}/${prefix}:`, listError.message);
      return;
    }

    if (files && files.length > 0) {
      const pathsToDelete = files
        .filter((f) => f.name && f.name !== ".emptyFolderPlaceholder")
        .map((f) => `${prefix}/${f.name}`);

      if (pathsToDelete.length > 0) {
        const { error: removeError } = await admin.storage
          .from(bucketName)
          .remove(pathsToDelete);

        if (removeError) {
          console.error(`Remove files error in bucket ${bucketName}:`, removeError.message);
        }
      }
    }
  } catch (err) {
    console.error(`Unexpected storage error in bucket ${bucketName}:`, err);
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return json(405, { error: "ไม่รองรับคำขอนี้" });
  }

  try {
    // 1) ตรวจสอบสิทธิ์ผู้ใช้จาก JWT token
    const token = req.headers.get("Authorization")?.match(/^Bearer\s+(.+)$/i)?.[1];
    if (!token) {
      return json(401, { error: "กรุณาเข้าสู่ระบบก่อนใช้งาน" });
    }

    const { data: auth, error: authError } = await admin.auth.getUser(token);
    if (authError || !auth.user) {
      return json(401, { error: "กรุณาเข้าสู่ระบบก่อนใช้งาน" });
    }

    const uid = auth.user.id;

    // 2) ลบไฟล์หลักฐานทั้งหมดใน Storage buckets ของผู้ใช้
    await Promise.all([
      deleteFolderFiles("report-evidences", uid),
      deleteFolderFiles("merchant-evidences", uid),
    ]);

    // 3) ลบบัญชีผู้ใช้ใน auth.users ด้วย service role
    //    ฐานข้อมูลจะ cascade ไปยังตาราง sellers และปรับ foreign keys ใน cod_reports เป็น null อัตโนมัติ
    const { error: deleteError } = await admin.auth.admin.deleteUser(uid);
    if (deleteError) {
      console.error("deleteUser failed:", deleteError.message);
      return json(500, { error: `ลบบัญชีไม่สำเร็จ: ${deleteError.message}` });
    }

    return json(200, {
      ok: true,
      message: "ลบบัญชีผู้ใช้และข้อมูลที่เกี่ยวข้องเรียบร้อยแล้ว",
    });
  } catch (err) {
    console.error("delete-account unexpected error:", err);
    return json(500, { error: "เกิดข้อผิดพลาดในการลบบัญชี กรุณาลองใหม่อีกครั้ง" });
  }
});
