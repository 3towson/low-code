// Edge Function: ตรวจสอบระดับความเสี่ยงของลูกค้า COD
// body: { text: string } (ข้อความออเดอร์) หรือ { phone: string } (ผู้ใช้กรอกเบอร์เอง)
// รองรับการใช้งานโดยไม่ต้อง login (Guest Mode) หรือเข้าสู่ระบบก็ได้
// ห้าม log ข้อความออเดอร์ ชื่อ เบอร์โทร หรือ hash และห้ามส่ง hash หรือข้อมูลผู้รายงานกลับไป

import { createClient } from "npm:@supabase/supabase-js@2";
import { extractOrderInfo, geminiClientFromEnv } from "../_shared/extract.ts";
import { reportPeriod } from "../_shared/period.ts";
import { hashIp, hashPhone, maskPhone, normalizeThaiPhone } from "../_shared/phone.ts";

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

function getClientIp(req: Request): string {
  // Cloudflare และ Supabase Edge Runtime จะกำหนด cf-connecting-ip หรือ x-real-ip
  const cfIp = req.headers.get("cf-connecting-ip")?.trim();
  if (cfIp) return cfIp;

  const realIp = req.headers.get("x-real-ip")?.trim();
  if (realIp) return realIp;

  const forwarded = req.headers.get("x-forwarded-for");
  if (forwarded) {
    const parts = forwarded.split(",").map((p) => p.trim()).filter(Boolean);
    // ใช้ IP ตัวสุดท้ายที่ proxy ฝั่ง platform เติม ป้องกัน client ปลอมค่าตัวแรก
    const lastIp = parts[parts.length - 1];
    if (lastIp) return lastIp;
  }
  return "127.0.0.1";
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

    const expectedAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    if (!authHeader && expectedAnonKey && apiKey !== expectedAnonKey) {
      return json(401, { error: "apikey ไม่ถูกต้อง หรือกรุณาเข้าสู่ระบบก่อนใช้งาน" });
    }

    // แยกว่าเป็น user จริง หรือเป็น guest (P0-6):
    // ถ้าไม่มี bearer token, หรือ token เท่ากับ anon key, หรือ getUser ไม่สำเร็จ ให้ถือเป็น guest
    const tokenMatch = authHeader?.match(/^Bearer\s+(.+)$/i);
    const token = tokenMatch ? tokenMatch[1].trim() : null;

    let userId: string | null = null;
    if (token && token !== expectedAnonKey) {
      try {
        const { data: authUser, error: authError } = await admin.auth.getUser(token);
        if (!authError && authUser?.user) {
          userId = authUser.user.id;
        }
      } catch (_) {
        // หาก token ไม่ถูกต้องหรือไม่พบผู้ใช้ จะนับเป็น guest
      }
    }

    const isGuest = (userId === null);

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

    const isTextMode = nonEmpty(text);

    // 2.1) ตรวจ Rate Limit ใน Postgres ผ่าน RPC hit_rate_limit (P0-6, N2, P1-6)
    const clientIp = getClientIp(req);
    let identifier: string;
    if (isGuest) {
      const ipSecret =
        Deno.env.get("IP_HASH_SECRET") ||
        Deno.env.get("PHONE_HASH_SECRET");
      if (!ipSecret) {
        throw new Error("IP_HASH_SECRET หรือ PHONE_HASH_SECRET ไม่ได้ถูกกำหนด");
      }
      identifier = await hashIp(clientIp, ipSecret);
    } else {
      identifier = userId!;
    }
    const prefix = isGuest ? `guest:${identifier}` : `user:${identifier}`;

    // A) Rate limit ต่อนาที (Window 60 วินาที)
    const minLimit = isGuest ? 30 : 120;
    const { data: minAllowed, error: minErr } = await admin.rpc("hit_rate_limit", {
      p_key: `${prefix}:min`,
      p_limit: minLimit,
      p_window_seconds: 60,
    });
    // สำหรับ Guest: หาก RPC มีข้อผิดพลาด ให้ fail-closed ปฏิเสธคำขอทันที
    if ((isGuest && minErr) || minAllowed === false) {
      return json(429, {
        status: "RATE_LIMITED",
        error: "คำขอถี่เกินไป กรุณารอ 1 นาทีแล้วลองใหม่อีกครั้ง",
      });
    }

    // B) Rate limit ต่อวัน (Window 86,400 วินาที)
    const dayLimit = isGuest ? 20 : 2000;
    const { data: dayAllowed, error: dayErr } = await admin.rpc("hit_rate_limit", {
      p_key: `${prefix}:day`,
      p_limit: dayLimit,
      p_window_seconds: 86400,
    });
    if ((isGuest && dayErr) || dayAllowed === false) {
      return json(429, {
        status: "RATE_LIMITED",
        error: isGuest
          ? "คุณใช้โควตาตรวจสอบสำหรับผู้เยี่ยมชมครบ 20 ครั้งแล้ว (โควตารีเซ็ตเมื่อครบ 24 ชั่วโมงนับจากครั้งแรก) กรุณาเข้าสู่ระบบเพื่อตรวจต่อ"
          : "คุณใช้โควตาตรวจสอบประจำวันครบแล้ว กรุณาลองใหม่ในวันพรุ่งนี้",
      });
    }

    // C) Rate limit สำหรับ Gemini AI (โหมด text)
    if (isTextMode) {
      // เพดานรวมของ guest ทั้งระบบต่อวัน ป้องกันค่าใช้จ่าย Gemini บานปลาย
      if (isGuest) {
        const { data: gTextAllowed, error: gTextErr } = await admin.rpc("hit_rate_limit", {
          p_key: "guest:global:text:day",
          p_limit: 3000,
          p_window_seconds: 86400,
        });
        if (gTextErr || gTextAllowed === false) {
          return json(429, {
            status: "RATE_LIMITED",
            error: "โควตา AI สำหรับผู้เยี่ยมชมของระบบเต็มแล้วสำหรับวันนี้ กรุณาเข้าสู่ระบบ หรือกรอกเบอร์โทรโดยตรง",
          });
        }
      }

      const textMinLimit = isGuest ? 10 : 40;
      const { data: tMinAllowed, error: tMinErr } = await admin.rpc("hit_rate_limit", {
        p_key: `${prefix}:text:min`,
        p_limit: textMinLimit,
        p_window_seconds: 60,
      });
      if ((isGuest && tMinErr) || tMinAllowed === false) {
        return json(429, {
          status: "RATE_LIMITED",
          error: "การใช้ AI สกัดข้อความถี่เกินไป กรุณารอสักครู่ หรือกรอกเบอร์โทรโดยตรง",
        });
      }

      const textDayLimit = isGuest ? 5 : 500;
      const { data: tDayAllowed, error: tDayErr } = await admin.rpc("hit_rate_limit", {
        p_key: `${prefix}:text:day`,
        p_limit: textDayLimit,
        p_window_seconds: 86400,
      });
      if ((isGuest && tDayErr) || tDayAllowed === false) {
        return json(429, {
          status: "RATE_LIMITED",
          error: isGuest
            ? "โควตา AI สกัดข้อความสำหรับผู้เยี่ยมชมหมดแล้ว (5 ครั้ง/วัน รีเซ็ตเมื่อครบ 24 ชั่วโมงนับจากครั้งแรก) กรุณาเข้าสู่ระบบ หรือกรอกเบอร์โทรโดยตรง"
            : "โควตา AI สกัดข้อความประจำวันครบแล้ว กรุณากรอกเบอร์โทรโดยตรง",
        });
      }
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
