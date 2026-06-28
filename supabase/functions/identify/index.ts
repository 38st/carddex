// Carddex `identify` Edge Function.
//
// Turns a card photo (+ on-device OCR hints) into ranked, catalog-grounded
// candidates, minimizing paid vision calls. Holds all secrets server-side.
//
// Cost guardrails (so one vision key safely serves every user):
//   - OCR-first fast path resolves clean scans for $0.
//   - Result cache (scan_cache) → never re-bill the same photo.
//   - Per-user DAILY vision cap → bounds any single account.
//   - Global DAILY spend circuit-breaker → if today's spend exceeds the ceiling,
//     stop calling the model and fall back to OCR-only.
//
// Vision provider is configurable via VISION_PROVIDER env var:
//   - "anthropic" (default) — Claude Haiku, ~$0.004/scan
//   - "deepseek"            — DeepSeek VL2, ~$0.001/scan (4× cheaper)
//
// Request:  { scanId, gameHint?, ocr: { lines, topToken?, numberGuess? }, imageBase64? }
// Response: { scanId, usedVision, cached?, candidates: [{ card, confidence, matchReasons }], lowConfidence }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const VISION_PROVIDER = (Deno.env.get("VISION_PROVIDER") ?? "anthropic").toLowerCase();
const VISION_MODEL = Deno.env.get("VISION_MODEL") ?? (VISION_PROVIDER === "deepseek" ? "deepseek-vl2" : "claude-haiku-4-5-20251001");
const DAILY_VISION_CAP = Number(Deno.env.get("DAILY_VISION_CAP") ?? "8");
const SPEND_CEILING_USD = Number(Deno.env.get("DAILY_SPEND_CEILING_USD") ?? "50");
const VISION_COST_USD = Number(Deno.env.get("VISION_COST_USD") ?? (VISION_PROVIDER === "deepseek" ? "0.001" : "0.004"));
const CACHE_TTL_DAYS = Number(Deno.env.get("CACHE_TTL_DAYS") ?? "7");

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const { scanId, gameHint, ocr, imageBase64 } = await req.json();
    // deno-lint-ignore no-explicit-any
    const supabase: any = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const userId = await getUserId(supabase, req);

    // 0) Cache: same photo → cached result, no model call, no charge.
    const cacheKey = await sha256(
      `${imageBase64 ?? ""}|${(ocr?.lines ?? []).join("|")}|${gameHint ?? ""}`,
    );
    const cached = await getCached(supabase, cacheKey);
    if (cached) return json({ scanId, usedVision: false, cached: true, ...cached });

    // 1) OCR-first fast path (free).
    const ocrCandidates = await groundFromOCR(supabase, ocr, gameHint);
    if (ocrCandidates.length && ocrCandidates[0].confidence >= 0.92) {
      const payload = { candidates: ocrCandidates.slice(0, 5), lowConfidence: false };
      await putCached(supabase, cacheKey, payload);
      return json({ scanId, usedVision: false, ...payload });
    }

    // 2) Vision path (paid) — gated by the guardrails.
    if (imageBase64) {
      const startOfToday = utcStartOfToday();
      const overBudget = await isOverGlobalBudget(supabase, startOfToday);

      if (!overBudget) {
        if (userId) {
          const used = await userVisionCountToday(supabase, userId, startOfToday);
          if (used >= DAILY_VISION_CAP) {
            return json({
              error: { code: "QUOTA_EXCEEDED", message: "Daily scan limit reached", retryable: false },
            }, 402);
          }
        }

        const extracted = await callVisionModel(imageBase64, ocr?.lines ?? [], gameHint);
        if (extracted) {
          const visionCandidates = await groundFromExtraction(supabase, extracted);
          if (visionCandidates.length) {
            const top = visionCandidates[0];
            const payload = { candidates: visionCandidates.slice(0, 5), lowConfidence: top.confidence < 0.85 };
            await recordScan(supabase, scanId, userId, top.confidence, payload.candidates);
            await putCached(supabase, cacheKey, payload);
            return json({ scanId, usedVision: true, ...payload });
          }
        }
      }
      // Over budget or vision failed → fall back to OCR-only below.
    }

    // 3) OCR-only fallback (low confidence → the app shows a picker / manual search).
    return json({ scanId, usedVision: false, candidates: ocrCandidates.slice(0, 5), lowConfidence: true });
  } catch (err) {
    return json({ error: { code: "INTERNAL", message: String(err), retryable: false } }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "content-type": "application/json" },
  });
}

// ---- Guardrails -------------------------------------------------------------

// deno-lint-ignore no-explicit-any
async function getUserId(supabase: any, req: Request): Promise<string | null> {
  const auth = req.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) return null;
  try {
    const { data } = await supabase.auth.getUser(auth.slice(7));
    return data?.user?.id ?? null;
  } catch {
    return null;
  }
}

function utcStartOfToday(): string {
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate())).toISOString();
}

// deno-lint-ignore no-explicit-any
async function isOverGlobalBudget(supabase: any, since: string): Promise<boolean> {
  try {
    const { data } = await supabase.from("scans").select("cost_usd").gte("created_at", since);
    // deno-lint-ignore no-explicit-any
    const spent = (data ?? []).reduce((sum: number, r: any) => sum + (Number(r.cost_usd) || 0), 0);
    return spent >= SPEND_CEILING_USD;
  } catch {
    return false; // never block on a telemetry read failing
  }
}

// deno-lint-ignore no-explicit-any
async function userVisionCountToday(supabase: any, userId: string, since: string): Promise<number> {
  try {
    const { count } = await supabase.from("scans")
      .select("id", { count: "exact", head: true })
      .eq("user_id", userId).eq("used_vision", true).gte("created_at", since);
    return count ?? 0;
  } catch {
    return 0;
  }
}

// deno-lint-ignore no-explicit-any
async function recordScan(supabase: any, scanId: string, userId: string | null, confidence: number, result: unknown) {
  try {
    await supabase.from("scans").upsert({
      id: scanId,
      user_id: userId,
      used_vision: true,
      vision_provider: VISION_PROVIDER,
      confidence,
      cost_usd: VISION_COST_USD,
      result,
    });
  } catch { /* telemetry best-effort */ }
}

// deno-lint-ignore no-explicit-any
async function getCached(supabase: any, hash: string) {
  try {
    const since = new Date(Date.now() - CACHE_TTL_DAYS * 86400_000).toISOString();
    const { data } = await supabase.from("scan_cache")
      .select("result").eq("content_hash", hash).gte("created_at", since).maybeSingle();
    return data?.result ?? null;
  } catch {
    return null;
  }
}

// deno-lint-ignore no-explicit-any
async function putCached(supabase: any, hash: string, result: unknown) {
  try {
    await supabase.from("scan_cache").upsert({ content_hash: hash, result, created_at: new Date().toISOString() });
  } catch { /* best-effort */ }
}

async function sha256(input: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input));
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

// ---- Vision model -----------------------------------------------------------

interface Extraction {
  game: string | null;
  name: string | null;
  setName: string | null;
  setCode: string | null;
  number: string | null;
  variantCues: string[];
  confidence: number;
}

function buildPrompt(ocrLines: string[], gameHint?: string): string {
  return [
    "You identify trading cards (Pokémon, Magic: The Gathering, Yu-Gi-Oh!, sports).",
    "Return ONLY a JSON object, no prose, with this exact shape:",
    '{"game":"pokemon|magic|yugioh|sports|unknown","name":string|null,"setName":string|null,',
    '"setCode":string|null,"number":string|null,"variantCues":string[],"confidence":number}',
    "Read the card in the image. Use the OCR hints to disambiguate; if the image",
    "contradicts a hint, prefer the image. If unsure of a field, use null and lower the",
    "confidence (0.0–1.0). variantCues are visible cues like 'holo','reverse holo','rookie'.",
    gameHint ? `The user thinks this is a ${gameHint} card.` : "",
    ocrLines.length ? `OCR hints: ${ocrLines.slice(0, 12).join(" | ")}` : "No OCR hints.",
  ].join("\n");
}

function parseExtraction(text: string): Extraction | null {
  const match = text.match(/\{[\s\S]*\}/);
  if (!match) return null;
  try {
    const parsed = JSON.parse(match[0]);
    return {
      game: parsed.game ?? null,
      name: parsed.name ?? null,
      setName: parsed.setName ?? null,
      setCode: parsed.setCode ?? null,
      number: parsed.number ?? null,
      variantCues: Array.isArray(parsed.variantCues) ? parsed.variantCues : [],
      confidence: typeof parsed.confidence === "number" ? parsed.confidence : 0.5,
    };
  } catch {
    return null;
  }
}

async function callVisionModel(
  imageBase64: string,
  ocrLines: string[],
  gameHint?: string,
): Promise<Extraction | null> {
  const prompt = buildPrompt(ocrLines, gameHint);

  if (VISION_PROVIDER === "deepseek") {
    return callDeepSeek(imageBase64, prompt);
  } else {
    return callAnthropic(imageBase64, prompt);
  }
}

async function callAnthropic(imageBase64: string, prompt: string): Promise<Extraction | null> {
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) return null;

  let response: Response;
  try {
    response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: VISION_MODEL,
        max_tokens: 400,
        messages: [{
          role: "user",
          content: [
            { type: "image", source: { type: "base64", media_type: "image/jpeg", data: imageBase64 } },
            { type: "text", text: prompt },
          ],
        }],
      }),
    });
  } catch {
    return null;
  }
  if (!response.ok) return null;

  const data = await response.json();
  const text: string = data?.content?.[0]?.text ?? "";
  return parseExtraction(text);
}

async function callDeepSeek(imageBase64: string, prompt: string): Promise<Extraction | null> {
  const apiKey = Deno.env.get("DEEPSEEK_API_KEY");
  if (!apiKey) return null;

  const baseUrl = Deno.env.get("DEEPSEEK_BASE_URL") ?? "https://api.deepseek.com/v1";

  let response: Response;
  try {
    response = await fetch(`${baseUrl}/chat/completions`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: VISION_MODEL,
        max_tokens: 400,
        messages: [{
          role: "user",
          content: [
            { type: "image_url", image_url: { url: `data:image/jpeg;base64,${imageBase64}` } },
            { type: "text", text: prompt },
          ],
        }],
      }),
    });
  } catch {
    return null;
  }
  if (!response.ok) return null;

  const data = await response.json();
  const text: string = data?.choices?.[0]?.message?.content ?? "";
  return parseExtraction(text);
}

// ---- Catalog grounding ------------------------------------------------------

// deno-lint-ignore no-explicit-any
async function groundFromExtraction(supabase: any, e: Extraction) {
  if (!e.name && !e.number) return [];
  const game = e.game && e.game !== "unknown" ? e.game : undefined;
  const candidates = await queryCatalog(supabase, e.name, e.number, game);
  // deno-lint-ignore no-explicit-any
  return candidates.map((c: any) => ({
    ...c,
    confidence: Math.min(0.97, 0.5 * c.confidence + 0.5 * e.confidence + 0.2),
  // deno-lint-ignore no-explicit-any
  })).sort((a: any, b: any) => b.confidence - a.confidence);
}

// deno-lint-ignore no-explicit-any
async function groundFromOCR(supabase: any, ocr: any, gameHint?: string) {
  const lines: string[] = ocr?.lines ?? [];
  if (!lines.length) return [];
  const name: string = ocr?.topToken ?? lines[0];
  const number: string | null = ocr?.numberGuess ?? extractNumber(lines);
  return queryCatalog(supabase, name, number, gameHint);
}

// deno-lint-ignore no-explicit-any
async function queryCatalog(supabase: any, name: string | null, number: string | null, game?: string) {
  if (!name) return [];
  let query = supabase.from("cards").select("*").ilike("name", `%${name}%`).limit(8);
  if (game) query = query.eq("game", game);
  if (number) query = query.ilike("number", `%${number}%`);
  const { data, error } = await query;
  if (error || !data) return [];
  return data
    // deno-lint-ignore no-explicit-any
    .map((row: any) => ({
      card: toCard(row),
      confidence: scoreMatch(row, name, number),
      matchReasons: reasons(row, name, number),
    }))
    // deno-lint-ignore no-explicit-any
    .sort((a: any, b: any) => b.confidence - a.confidence);
}

function extractNumber(lines: string[]): string | null {
  for (const line of lines) {
    const m = line.match(/\d+\s*\/\s*\d+/) ?? line.match(/[A-Z]{2,4}-?\d{1,4}/);
    if (m) return m[0];
  }
  return null;
}

// deno-lint-ignore no-explicit-any
function toCard(row: any) {
  return {
    id: row.id,
    game: row.game,
    name: row.name,
    setName: row.set_name ?? "",
    number: row.number ?? "",
    rarity: row.rarity ?? null,
    imageURL: row.image_url ?? null,
    marketPrice: null,
  };
}

// deno-lint-ignore no-explicit-any
function scoreMatch(row: any, name: string, number: string | null): number {
  let score = 0.5;
  if (name && String(row.name ?? "").toLowerCase().includes(name.toLowerCase())) score += 0.25;
  if (number && String(row.number ?? "").includes(number)) score += 0.2;
  return Math.min(score, 0.95);
}

// deno-lint-ignore no-explicit-any
function reasons(row: any, name: string, number: string | null): string[] {
  const out: string[] = [];
  if (name && String(row.name ?? "").toLowerCase().includes(name.toLowerCase())) out.push("name");
  if (number && String(row.number ?? "").includes(number)) out.push("number");
  return out;
}
