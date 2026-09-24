// รัน: deno test supabase/functions/_shared/extract.test.ts
// ใช้ geminiClient ปลอมทั้งหมด ไม่เรียก Gemini จริง

import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  createGeminiClient,
  extractOrderInfo,
  findPhoneCandidates,
  GeminiHttpError,
  type GeminiClient,
  type GeminiRequest,
  MAX_TEXT_LENGTH,
} from "./extract.ts";

function fakeClient(respond: (req: GeminiRequest) => string | Promise<string>) {
  const calls: GeminiRequest[] = [];
  const client: GeminiClient = {
    async generateContent(req) {
      calls.push(req);
      return await respond(req);
    },
  };
  return { client, calls };
}

const json = (name: string | null, phone: string | null) =>
  JSON.stringify({ customer_name: name, recipient_phone: phone });

const ORDER = "ผู้รับ สมหญิง ใจดี\nโทร 081-234-5601\nที่อยู่ 99/9 ต.บางพูด อ.ปากเกร็ด จ.นนทบุรี 11120";

Deno.test("Gemini ตอบเบอร์ที่ไม่มีในข้อความ → ทิ้ง ใช้เบอร์จาก regex", async () => {
  const { client } = fakeClient(() => json("สมหญิง ใจดี", "0899999999"));
  const r = await extractOrderInfo(ORDER, client);
  assertEquals(r, {
    status: "OK",
    customer_name: "สมหญิง ใจดี",
    phone: "0812345601",
    ai_unavailable: false,
  });
});

Deno.test("Gemini โยน error → ai_unavailable = true และได้เบอร์จาก regex", async () => {
  const { client } = fakeClient(() => {
    throw new Error("network down");
  });
  const r = await extractOrderInfo(ORDER, client);
  assertEquals(r, {
    status: "OK",
    customer_name: null,
    phone: "0812345601",
    ai_unavailable: true,
  });
});

Deno.test("ข้อความไม่มีเบอร์และ Gemini ตอบ null → NO_PHONE_DETECTED", async () => {
  const { client } = fakeClient(() => json(null, null));
  const r = await extractOrderInfo("สนใจสินค้าค่ะ เดี๋ยวแจ้งที่อยู่ทีหลัง", client);
  assertEquals(r, {
    status: "NO_PHONE_DETECTED",
    customer_name: null,
    phone: null,
    ai_unavailable: false,
  });
});

for (const bad of ['{customer_name: "สม', "", "[1,2]", "null", '{"customer_name":123}']) {
  Deno.test(`Gemini ตอบ JSON ผิดรูปแบบ ${JSON.stringify(bad)} → ไม่ crash ทำงานเหมือน error`, async () => {
    const { client } = fakeClient(() => bad);
    const r = await extractOrderInfo(ORDER, client);
    assertEquals(r, {
      status: "OK",
      customer_name: null,
      phone: "0812345601",
      ai_unavailable: true,
    });
  });
}

Deno.test("ข้อความยาว 3,000 ตัวอักษร → ถูกตัดก่อนส่ง Gemini", async () => {
  const head = "ผู้รับ สมหญิง ใจดี โทร 0812345601 ";
  const tail = " ร้านติดต่อ 0899990000";
  const text = head + "ก".repeat(3000 - head.length - tail.length) + tail;
  assertEquals(text.length, 3000);

  const { client, calls } = fakeClient(() => json("สมหญิง ใจดี", "0899990000"));
  const r = await extractOrderInfo(text, client);

  assertEquals(calls.length, 1);
  const sent = calls[0].contents[0].parts[0].text;
  assertEquals(sent.length, MAX_TEXT_LENGTH);
  assertEquals(sent, text.slice(0, MAX_TEXT_LENGTH));
  assert(!sent.includes("0899990000"), "ส่วนที่ถูกตัดต้องไม่ถูกส่งไป Gemini");
  // เบอร์หลังตำแหน่งที่ตัดถือว่าไม่อยู่ในข้อความ จึงต้องถูกทิ้ง
  assertEquals(r.phone, "0812345601");
});

Deno.test("Gemini เลือกเบอร์ลูกค้าที่ไม่ใช่ตัวแรก → ใช้เบอร์จาก Gemini", async () => {
  const text = "ติดต่อร้าน 089-999-0000\nผู้รับ กิตติ พงษ์ดี โทร 061 234 5608";
  const { client } = fakeClient(() => json("กิตติ พงษ์ดี", "061-234-5608"));
  const r = await extractOrderInfo(text, client);
  assertEquals(r.phone, "0612345608");
  assertEquals(r.ai_unavailable, false);
});

Deno.test("Gemini ตอบเบอร์ +66 ที่มีในข้อความ → ยอมรับหลัง normalize", async () => {
  const { client } = fakeClient(() => json("Somchai", "+66956789010"));
  const r = await extractOrderInfo("Name: Somchai Tel. +66 95 678 9010", client);
  assertEquals(r.phone, "0956789010");
});

Deno.test("Gemini ช้าเกิน timeout → ai_unavailable = true", async () => {
  const { client } = fakeClient(() => new Promise<string>(() => {}));
  const r = await extractOrderInfo(ORDER, client, { timeoutMs: 50 });
  assertEquals(r.ai_unavailable, true);
  assertEquals(r.phone, "0812345601");
});

Deno.test("findPhoneCandidates: เลขไทย ขีด เว้นวรรค +66 และตัดค่าซ้ำ", () => {
  const text = "๐๘๑๒๓๔๕๖๐๑ / 081-234-5601 / (+66) 812345601 / 06 1234 5608 / " +
    "66956789010 / ออเดอร์ 250925081234560199 / 02-123-4567";
  assertEquals(findPhoneCandidates(text), ["0812345601", "0612345608", "0956789010"]);
});

Deno.test("createGeminiClient: v1beta, x-goog-api-key, temperature 0 และ 429 ทั้ง 2 ครั้ง → ai_unavailable", async () => {
  const seen: { url: string; headers: Headers; body: GeminiRequest }[] = [];
  const fakeFetch = ((url: string, init: RequestInit) => {
    seen.push({
      url,
      headers: new Headers(init.headers),
      body: JSON.parse(String(init.body)),
    });
    return Promise.resolve(new Response("rate limited", { status: 429 }));
  }) as typeof fetch;

  const client = createGeminiClient({ apiKey: "fake-key", model: "test-model", fetch: fakeFetch });
  const r = await extractOrderInfo(ORDER, client, { retryDelayMs: 10 });

  assertEquals(r.ai_unavailable, true);
  assertEquals(r.phone, "0812345601");
  assertEquals(seen.length, 2, "429 ต้อง retry 1 ครั้ง");
  assertEquals(
    seen[0].url,
    "https://generativelanguage.googleapis.com/v1beta/models/test-model:generateContent",
  );
  assertEquals(seen[0].headers.get("x-goog-api-key"), "fake-key");
  assert(!seen[0].url.includes("fake-key"), "ห้ามส่ง key ใน URL");
  const cfg = seen[0].body.generationConfig;
  assertEquals(cfg.temperature, 0);
  assertEquals(cfg.responseMimeType, "application/json");
  assertEquals(cfg.responseSchema.type, "OBJECT");
});

Deno.test("createGeminiClient: อ่านผลจาก candidates[0].content.parts", async () => {
  const fakeFetch = (() =>
    Promise.resolve(Response.json({
      candidates: [{ content: { parts: [{ text: json("สมหญิง ใจดี", "0812345601") }] } }],
    }))) as typeof fetch;
  const client = createGeminiClient({ apiKey: "fake-key", model: "test-model", fetch: fakeFetch });
  const r = await extractOrderInfo(ORDER, client);
  assertEquals(r, {
    status: "OK",
    customer_name: "สมหญิง ใจดี",
    phone: "0812345601",
    ai_unavailable: false,
  });
});

// ---------- retry เมื่อ 503/429 ----------

// ตอบตามลำดับ: ตัวเลข = throw GeminiHttpError(status), ข้อความ = ผลจาก Gemini
function scriptedClient(steps: (number | string)[]) {
  const times: number[] = [];
  const client: GeminiClient = {
    generateContent() {
      times.push(Date.now());
      const step = steps[times.length - 1];
      if (typeof step === "number") return Promise.reject(new GeminiHttpError(step));
      return Promise.resolve(step);
    },
  };
  return { client, times };
}

for (const status of [503, 429]) {
  Deno.test(`Gemini ตอบ ${status} ครั้งแรก แล้ว retry สำเร็จ → ใช้ผลจาก Gemini`, async () => {
    const { client, times } = scriptedClient([status, json("สมหญิง ใจดี", "0812345601")]);
    const r = await extractOrderInfo(ORDER, client, { retryDelayMs: 100 });
    assertEquals(times.length, 2);
    assert(times[1] - times[0] >= 90, `ต้องรอก่อน retry (รอจริง ${times[1] - times[0]}ms)`);
    assertEquals(r, {
      status: "OK",
      customer_name: "สมหญิง ใจดี",
      phone: "0812345601",
      ai_unavailable: false,
    });
  });
}

Deno.test("retry ใช้เวลารอเริ่มต้น 2 วินาที", async () => {
  const { client, times } = scriptedClient([503, json("สมหญิง ใจดี", "0812345601")]);
  const r = await extractOrderInfo(ORDER, client);
  assertEquals(times.length, 2);
  const waited = times[1] - times[0];
  assert(waited >= 1990 && waited < 3000, `ต้องรอประมาณ 2000ms (รอจริง ${waited}ms)`);
  assertEquals(r.ai_unavailable, false);
});

Deno.test("Gemini ตอบ 503 แล้ว retry ได้ 429 → ai_unavailable = true ไม่ retry ซ้ำ", async () => {
  const { client, times } = scriptedClient([503, 429, json("x", null)]);
  const r = await extractOrderInfo(ORDER, client, { retryDelayMs: 10 });
  assertEquals(times.length, 2);
  assertEquals(r, {
    status: "OK",
    customer_name: null,
    phone: "0812345601",
    ai_unavailable: true,
  });
});

Deno.test("Gemini ตอบ 500 หรือ error อื่น → ไม่ retry", async () => {
  for (const first of [500, 400]) {
    const { client, times } = scriptedClient([first, json("สมหญิง ใจดี", "0812345601")]);
    const r = await extractOrderInfo(ORDER, client, { retryDelayMs: 10 });
    assertEquals(times.length, 1, `HTTP ${first} ต้องไม่ retry`);
    assertEquals(r.ai_unavailable, true);
  }
  const { client, calls } = fakeClient(() => {
    throw new Error("network down");
  });
  await extractOrderInfo(ORDER, client, { retryDelayMs: 10 });
  assertEquals(calls.length, 1, "error ที่ไม่ใช่ HTTP ต้องไม่ retry");
});

Deno.test("หมดเวลาระหว่างรอ retry → หยุดทันที ai_unavailable = true", async () => {
  const { client, times } = scriptedClient([503, json("สมหญิง ใจดี", "0812345601")]);
  const t0 = Date.now();
  const r = await extractOrderInfo(ORDER, client, { timeoutMs: 100, retryDelayMs: 5000 });
  const elapsed = Date.now() - t0;
  assert(elapsed < 1000, `ต้องหยุดที่ timeout ไม่รอ retry ครบ (ใช้ ${elapsed}ms)`);
  assertEquals(times.length, 1, "ต้องไม่ retry หลังหมดเวลา");
  assertEquals(r.ai_unavailable, true);
  assertEquals(r.phone, "0812345601");
});

Deno.test("retry แล้ว Gemini ช้าจนเกิน timeout รวม → ai_unavailable = true", async () => {
  let n = 0;
  const client: GeminiClient = {
    generateContent() {
      n++;
      return n === 1 ? Promise.reject(new GeminiHttpError(503)) : new Promise<string>(() => {});
    },
  };
  const t0 = Date.now();
  const r = await extractOrderInfo(ORDER, client, { timeoutMs: 200, retryDelayMs: 50 });
  assert(Date.now() - t0 < 1000, "timeout ต้องครอบการ retry ด้วย");
  assertEquals(n, 2);
  assertEquals(r.ai_unavailable, true);
});

// ---------- AI ใช้งานไม่ได้ + เจอหลายเบอร์ ----------

const TWO_PHONES = "ติดต่อร้าน 089-999-0000\nผู้รับ กิตติ พงษ์ดี โทร 061 234 5608";

Deno.test("AI ใช้งานไม่ได้และ regex เจอ 2 เบอร์ → NO_PHONE_DETECTED", async () => {
  const { client } = fakeClient(() => {
    throw new Error("network down");
  });
  const r = await extractOrderInfo(TWO_PHONES, client);
  assertEquals(r, {
    status: "NO_PHONE_DETECTED",
    customer_name: null,
    phone: null,
    ai_unavailable: true,
  });
});

Deno.test("503 ทั้ง 2 ครั้งและ regex เจอ 2 เบอร์ → NO_PHONE_DETECTED", async () => {
  const { client, times } = scriptedClient([503, 503]);
  const r = await extractOrderInfo(TWO_PHONES, client, { retryDelayMs: 10 });
  assertEquals(times.length, 2);
  assertEquals(r.status, "NO_PHONE_DETECTED");
  assertEquals(r.phone, null);
  assertEquals(r.ai_unavailable, true);
});

Deno.test("AI ใช้งานไม่ได้และ regex เจอเบอร์เดียว (เขียนซ้ำ 2 แบบ) → ใช้เบอร์นั้น", async () => {
  const { client } = fakeClient(() => "not json");
  const r = await extractOrderInfo("ผู้รับ กิตติ โทร 061-234-5608 (๐๖๑๒๓๔๕๖๐๘)", client);
  assertEquals(r, {
    status: "OK",
    customer_name: null,
    phone: "0612345608",
    ai_unavailable: true,
  });
});

Deno.test("AI ใช้งานได้และ regex เจอ 2 เบอร์ → ยังใช้เบอร์ที่ Gemini เลือก", async () => {
  const { client } = fakeClient(() => json("กิตติ พงษ์ดี", "0612345608"));
  const r = await extractOrderInfo(TWO_PHONES, client);
  assertEquals(r.status, "OK");
  assertEquals(r.phone, "0612345608");
  assertEquals(r.ai_unavailable, false);
});
