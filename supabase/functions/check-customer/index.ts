// Edge Function: ตรวจสอบระดับความเสี่ยงของลูกค้า COD
// body: { text: string } (ข้อความออเดอร์) หรือ { phone: string } (ผู้ใช้กรอกเบอร์เอง)
// รองรับการใช้งานโดยไม่ต้อง login (Guest Mode) หรือเข้าสู่ระบบก็ได้
// ห้าม log ข้อความออเดอร์ ชื่อ เบอร์โทร หรือ hash และห้ามส่ง hash หรือข้อมูลผู้รายงานกลับไป

import { createClient } from "npm:@supabase/supabase-js@2";
import { extractOrderInfo, geminiClientFromEnv } from "../_shared/extract.ts";
import { reportPeriod } from "../_shared/period.ts";
import { hashPhone, maskPhone, normalizeThaiPhone } from "../_shared/phone.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const RECOMMENDATION: Record<string, string> = {
  green: "ส่งได้ตามปกติ",
  yellow: "ควรโทรหรือทักยืนยันออเดอร์กับลูกค้าก่อนแพ็กสินค้า",
  red: "ไม่แนะนำให้ส่งแบบเก็บเงินปลายทาง ควรให้ลูกค้าโอนชำระก่อน",
};

type RiskRow = { level: string; counted_reports: number; last_report_at: string | null };

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json; charset=utf-8" },
  });
}

const nonEmpty = (v: unknown): v is string => typeof v === "string" && v.trim() !== "";

const admin = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  { auth: { persistSession: false, autoRefreshToken: false } },
);

// Rate limiter สำหรับ Guest Mode (30 คำขอ / 60 วินาที ต่อ IP)
const GUEST_RATE_LIMIT = 30;
const GUEST_WINDOW_MS = 60_000;
const rateLimitMap = new Map<string, { count: number; resetAt: number }>();

function getClientIp(req: Request): string {
  return (
    req.headers.get("cf-connecting-ip") ??
    req.headers.get("x-real-ip") ??
    req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ??
    "unknown"
  );
}

function isRateLimited(ip: string): boolean {
  if (ip === "unknown") return false;
  const now = Date.now();
  const entry = rateLimitMap.get(ip);
  if (!entry || now > entry.resetAt) {
    rateLimitMap.set(ip, { count: 1, resetAt: now + GUEST_WINDOW_MS });
    if (rateLimitMap.size > 10_000) {
      for (const [k, v] of rateLimitMap.entries()) {
        if (now > v.resetAt) rateLimitMap.delete(k);
      }
    }
    return false;
  }
  entry.count++;
  return entry.count > GUEST_RATE_LIMIT;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json(405, { error: "ไม่รองรับคำขอนี้" });

  try {
    // 1) ตรวจสิทธิ์: อนุญาต Guest Mode โดยตรวจสอบว่ามี apikey หรือ Authorization
    const apiKey = req.headers.get("apikey");
    const authHeader = req.headers.get("Authorization");
    if (!apiKey && !authHeader) {
      return json(401, { error: "กรุณาระบุ apikey หรือเข้าสู่ระบบก่อนใช้งาน" });
    }

    const expectedAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    if (!authHeader && expectedAnonKey && apiKey !== expectedAnonKey) {
      return json(401, { error: "apikey ไม่ถูกต้อง หรือกรุณาเข้าสู่ระบบก่อนใช้งาน" });
    }

    // 1.1) ตรวจ Rate Limit สำหรับ Guest Mode (ป้องกันการยิงสแปมทำลายโควต้า Gemini)
    if (!authHeader) {
      const clientIp = getClientIp(req);
      if (isRateLimited(clientIp)) {
        return json(429, { error: "คำขอถี่เกินไป กรุณารอสักครู่แล้วลองใหม่" });
      }
    }

    // 2) อ่าน body: ต้องมี text หรือ phone อย่างใดอย่างหนึ่งที่ไม่ว่าง
    let body: unknown;
    try {
      body = await req.json();
    } catch {
      body = null;
    }
    const { text, phone } = (body && typeof body === "object" && !Array.isArray(body)
      ? body
      : {}) as { text?: unknown; phone?: unknown };
    if (nonEmpty(text) === nonEmpty(phone)) {
      return json(400, { error: "กรุณาส่งข้อความออเดอร์หรือเบอร์โทรอย่างใดอย่างหนึ่ง" });
    }

    // 3) หาเบอร์ที่ normalize แล้ว
    let normalized: string;
    let customerName: string | null = null;
    let aiUnavailable = false;
    if (nonEmpty(text)) {
      const extracted = await extractOrderInfo(text, geminiClientFromEnv());
      if (extracted.status === "NO_PHONE_DETECTED" || !extracted.phone) {
        return json(200, { status: "NO_PHONE_DETECTED" });
      }
      normalized = extracted.phone;
      customerName = extracted.customer_name;
      aiUnavailable = extracted.ai_unavailable;
    } else {
      const p = normalizeThaiPhone(phone as string);
      if (!p) return json(400, { status: "INVALID_PHONE" });
      normalized = p;
    }

    // 4) hash แล้วคำนวณระดับความเสี่ยง
    const hash = await hashPhone(normalized, Deno.env.get("PHONE_HASH_SECRET") ?? "");
    const { data: risk, error: rpcError } = await admin
      .rpc("get_risk_level", { p_phone_hash: hash })
      .single<RiskRow>();
    if (rpcError || !risk || !(risk.level in RECOMMENDATION)) {
      throw new Error(`get_risk_level ล้มเหลว: ${rpcError?.code ?? "ผลลัพธ์ผิดรูปแบบ"}`);
    }

    // 5) ตอบเฉพาะฟิลด์ที่อนุญาต
    return json(200, {
      status: "OK",
      level: risk.level,
      counted_reports: risk.counted_reports,
      recommendation: RECOMMENDATION[risk.level],
      customer_name: customerName,
      phone_masked: maskPhone(normalized),
      // ส่งแค่ช่วงเวลา ห้ามส่ง last_report_at จริง
      last_report_period: reportPeriod(risk.last_report_at),
      ai_unavailable: aiUnavailable,
    });
  } catch (e) {
    console.error("check-customer error:", e instanceof Error ? e.message : "unknown");
    return json(500, { error: "เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง" });
  }
});
