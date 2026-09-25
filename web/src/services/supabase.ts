import { createClient } from "@supabase/supabase-js";

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || "";
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || "";

if (!supabaseUrl || !supabaseAnonKey) {
  console.warn("Missing VITE_SUPABASE_URL or VITE_SUPABASE_ANON_KEY in web/.env");
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
  },
});

export type RiskLevel = "green" | "yellow" | "red";

export interface CheckSuccess {
  status: "OK";
  level: RiskLevel;
  counted_reports: number;
  last_report_at?: string | null;
  recommendation: string;
  customer_name?: string | null;
  phone_masked: string;
  ai_unavailable?: boolean;
}

export interface CheckNoPhone {
  status: "NO_PHONE";
  message: string;
}

export interface CheckInvalidPhone {
  status: "INVALID_PHONE";
  message: string;
}

export type CheckResponse = CheckSuccess | CheckNoPhone | CheckInvalidPhone;

export async function checkCustomerApi(params: { text?: string; phone?: string }): Promise<CheckResponse> {
  const { data: sessionData } = await supabase.auth.getSession();
  const token = sessionData.session?.access_token;
  if (!token) {
    throw new Error("AUTH_REQUIRED");
  }

  const res = await fetch(`${supabaseUrl}/functions/v1/check-customer`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
      apikey: supabaseAnonKey,
    },
    body: JSON.stringify(params),
  });

  const body = await res.json();
  if (!res.ok) {
    throw new Error(body.error || body.message || `Error ${res.status}`);
  }

  return body as CheckResponse;
}

export interface ReportPayload {
  customer_name: string;
  phone: string;
  platform: string;
  reason: string;
  amount?: number | null;
}

export async function reportCustomerApi(payload: ReportPayload): Promise<{ status: string }> {
  const { data: sessionData } = await supabase.auth.getSession();
  const token = sessionData.session?.access_token;
  if (!token) {
    throw new Error("AUTH_REQUIRED");
  }

  const res = await fetch(`${supabaseUrl}/functions/v1/report-customer`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
      apikey: supabaseAnonKey,
    },
    body: JSON.stringify(payload),
  });

  const body = await res.json();
  if (res.status === 409) {
    throw new Error(body.message || "DUPLICATE_REPORT");
  }
  if (!res.ok) {
    throw new Error(body.error || body.message || `Error ${res.status}`);
  }

  return body;
}
