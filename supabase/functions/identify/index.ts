// Carddex `identify` Edge Function.
//
// Turns a card photo (+ on-device OCR hints) into ranked, catalog-grounded
// candidates, minimizing paid vision calls. Holds all secrets server-side.
// See docs/backend-plan.md §3.1 and §5 for the full contract.
//
// Request:  { scanId, storagePath?, gameHint?, ocr: { lines, topToken?, numberGuess? }, imageBase64? }
// Response: { scanId, usedVision, candidates: [{ card, confidence, matchReasons }], lowConfidence }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const { scanId, gameHint, ocr } = await req.json();
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // 1) OCR-first fast path (free): ground directly from on-device text.
    const candidates = await groundFromOCR(supabase, ocr, gameHint);
    if (candidates.length && candidates[0].confidence >= 0.92) {
      return json({ scanId, usedVision: false, candidates: candidates.slice(0, 5), lowConfidence: false });
    }

    // 2) Vision path (paid): TODO — when OCR is ambiguous, call the vision model
    //    (Deno.env.get("VISION_PROVIDER")) with the photo + OCR hints to extract
    //    { game, name, setName, setCode, number, variantCues, confidence }, then
    //    re-ground against the catalog. Increment scan_usage.vision_count.

    // 3) Fall back to whatever OCR grounding produced (low confidence → picker).
    return json({
      scanId,
      usedVision: false,
      candidates: candidates.slice(0, 5),
      lowConfidence: true,
    });
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

// deno-lint-ignore no-explicit-any
async function groundFromOCR(supabase: any, ocr: any, gameHint?: string) {
  const lines: string[] = ocr?.lines ?? [];
  if (!lines.length) return [];

  const name: string = ocr?.topToken ?? lines[0];
  const number: string | null = ocr?.numberGuess ?? extractNumber(lines);

  let query = supabase.from("cards").select("*").ilike("name", `%${name}%`).limit(8);
  if (gameHint) query = query.eq("game", gameHint);
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

// Shapes a `cards` row into the client's `Card` JSON. Prices come from
// card_prices_latest in a fuller implementation; left null in this scaffold.
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
