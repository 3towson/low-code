// Edge Function: รายงานลูกค้า COD ที่มีปัญหา
// body: { customer_name, phone, platform, reason, amount?, other_details? }
// reported_by ใช้ user id จาก token เท่านั้น ห้ามอ่านจาก body
// ห้าม log ชื่อ เบอร์โทร หรือ hash และเก็บเฉพาะ phone_hash ลงฐานข้อมูล

import { createClient } from "npm:@supabase/supabase-js@2";
import { findPhoneCandidates } from "../_shared/extract.ts";
import { hashPhone, normalizeThaiPhone } from "../_shared/phone.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const PLATFORMS = ["shopee", "lazada", "facebook", "line", "tiktok", "other"];
const REASONS = ["refused_delivery", "unreachable", "fake_address", "other"];
const MAX_NAME_LENGTH = 100;
const MAX_AMOUNT = 1_000_000;

type FieldError = { field: string; message: string };

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

// ตรวจ body คืนค่าที่พร้อม insert หรือรายการ field ที่ผิด
function validate(body: Record<string, unknown>):
  | {
      ok: true;
      name: string;
      phone: string;
      platform: string;
      reason: string;
      amount: number | null;
      other_details: string | null;
      evidence_path: string;
      evidence_paths: string[];
    }
  | { ok: false; errors: FieldError[] } {
  const errors: FieldError[] = [];

  const name = typeof body.customer_name === "string" ? body.customer_name.trim() : "";
  const nameLength = [...name].length;
  if (nameLength < 1 || nameLength > MAX_NAME_LENGTH) {
    errors.push({ field: "customer_name", message: `กรุณากรอกชื่อลูกค้า 1-${MAX_NAME_LENGTH} ตัวอักษร` });
  } else if (findPhoneCandidates(name).length > 0) {
    // กันเบอร์จริงหลุดลงฐานข้อมูลผ่านช่องชื่อ
    errors.push({ field: "customer_name", message: "ชื่อลูกค้าห้ามมีเบอร์โทร" });
  }

  const phone = typeof body.phone === "string" ? normalizeThaiPhone(body.phone) : null;
  if (!phone) errors.push({ field: "phone", message: "เบอร์โทรไม่ถูกต้อง ต้องเป็นเบอร์มือถือไทย" });

  const platform = body.platform;
  if (typeof platform !== "string" || !PLATFORMS.includes(platform)) {
    errors.push({ field: "platform", message: "กรุณาเลือกแพลตฟอร์มที่กำหนด" });
  }

  const reason = body.reason;
  if (typeof reason !== "string" || !REASONS.includes(reason)) {
    errors.push({ field: "reason", message: "กรุณาเลือกเหตุผลที่กำหนด" });
  }

  const amount = body.amount ?? null;
  if (
    amount !== null &&
    (typeof amount !== "number" || !Number.isFinite(amount) || amount < 0 || amount > MAX_AMOUNT)
  ) {
    errors.push({ field: "amount", message: "มูลค่าความเสียหายต้องเป็นตัวเลข 0 ถึง 1,000,000" });
  }

  const MAX_OTHER_DETAILS_LENGTH = 500;
  let otherDetails: string | null = null;
  if (typeof body.other_details === "string") {
    const trimmed = body.other_details.trim();
    if (trimmed.length > MAX_OTHER_DETAILS_LENGTH) {
      errors.push({
        field: "other_details",
        message: `รายละเอียดเพิ่มเติมต้องไม่เกิน ${MAX_OTHER_DETAILS_LENGTH} ตัวอักษร`,
      });
    } else if (trimmed.length > 0) {
      if (findPhoneCandidates(trimmed).length > 0) {
        errors.push({ field: "other_details", message: "รายละเอียดเพิ่มเติมห้ามมีเบอร์โทร" });
      } else {
        otherDetails = trimmed;
      }
    }
  }

  let evidencePaths: string[] = [];
  if (Array.isArray(body.evidence_paths)) {
    evidencePaths = body.evidence_paths
      .filter((p): p is string => typeof p === "string")
      .map((p) => p.trim())
      .filter((p) => p.length > 0);
  } else if (typeof body.evidence_path === "string" && body.evidence_path.trim().length > 0) {
    evidencePaths = body.evidence_path
      .split(",")
      .map((p) => p.trim())
      .filter((p) => p.length > 0);
  }

  if (evidencePaths.length === 0) {
    errors.push({ field: "evidence_path", message: "กรุณาแนบรูปภาพหลักฐานอย่างน้อย 1 รูป" });
  } else if (evidencePaths.length > 3) {
    errors.push({ field: "evidence_path", message: "แนบรูปภาพหลักฐานได้สูงสุดไม่เกิน 3 รูป" });
  } else {
    for (const p of evidencePaths) {
      if (p.length > 255) {
        errors.push({ field: "evidence_path", message: "ชื่อไฟล์หลักฐานยาวเกินไป" });
        break;
      }
    }
  }

  if (errors.length) return { ok: false, errors };
  return {
    ok: true,
    name,
    phone: phone as string,
    platform: platform as string,
    reason: reason as string,
    amount: amount as number | null,
    other_details: otherDetails,
    evidence_path: evidencePaths.join(","),
    evidence_paths: evidencePaths,
  };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json(405, { error: "ไม่รองรับคำขอนี้" });

  try {
    // 1) ตรวจผู้ใช้
    const token = req.headers.get("Authorization")?.match(/^Bearer\s+(.+)$/i)?.[1];
    if (!token) return json(401, { error: "กรุณาเข้าสู่ระบบก่อนใช้งาน" });
    const { data: auth, error: authError } = await admin.auth.getUser(token);
    if (authError || !auth.user) return json(401, { error: "กรุณาเข้าสู่ระบบก่อนใช้งาน" });
    if (!auth.user.email_confirmed_at) {
      return json(403, { error: "กรุณายืนยันอีเมลก่อนรายงานลูกค้า" });
    }

    // 2) อ่านและตรวจ body
    let body: unknown;
    try {
      body = await req.json();
    } catch {
      body = null;
    }
    const input = validate(
      (body && typeof body === "object" && !Array.isArray(body) ? body : {}) as Record<string, unknown>,
    );
    if (!input.ok) return json(400, { status: "INVALID_INPUT", errors: input.errors });

    // ตรวจสอบว่า evidence_paths ทุกไฟล์ขึ้นต้นด้วย user id ของตนเอง
    const invalidPath = input.evidence_paths.find((p) => !p.startsWith(`${auth.user.id}/`));
    if (invalidPath) {
      return json(400, {
        status: "INVALID_INPUT",
        errors: [{ field: "evidence_path", message: "ไฟล์หลักฐานต้องอยู่ในโฟลเดอร์ของร้านคุณ" }],
      });
    }

    // 3) hash เบอร์แล้ว insert (reported_by มาจาก token เท่านั้น)
    const phoneHash = await hashPhone(input.phone, Deno.env.get("PHONE_HASH_SECRET") ?? "");
    const { error: insertError } = await admin.from("cod_reports").insert({
      phone_hash: phoneHash,
      customer_name: input.name,
      reported_by: auth.user.id,
      platform: input.platform,
      reason: input.reason,
      amount: input.amount,
      other_details: input.other_details,
      evidence_path: input.evidence_path,
      status: "pending",
    });
    if (insertError) {
      if (insertError.message?.includes("DUPLICATE_REPORT")) {
        return json(409, {
          status: "DUPLICATE",
          message: "คุณรายงานเบอร์นี้ไปแล้วในช่วง 7 วันที่ผ่านมา",
        });
      }
      throw new Error(`insert ล้มเหลว: ${insertError.code ?? "unknown"}`);
    }

    return json(201, { status: "CREATED", report_status: "pending" });
  } catch (e) {
    console.error("report-customer error:", e instanceof Error ? e.message : "unknown");
    return json(500, { error: "เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง" });
  }
});
