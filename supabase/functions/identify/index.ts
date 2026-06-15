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

const VISION_MODEL = Deno.env.get("VISION_MODEL") ?? "claude-haiku-4-5-20251001";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const { scanId, gameHint, ocr, imageBase64 } = await req.json();
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // 1) OCR-first fast path (free): ground directly from on-device text.
    const ocrCandidates = await groundFromOCR(supabase, ocr, gameHint);
    if (ocrCandidates.length && ocrCandidates[0].confidence >= 0.92) {
      return json({ scanId, usedVision: false, candidates: ocrCandidates.slice(0, 5), lowConfidence: false });
    }

    // 2) Vision path (paid): when OCR is ambiguous, ask the vision model to read
    //    the card, then re-ground its structured output against the catalog.
    if (imageBase64) {
      const extracted = await callVisionModel(imageBase64, ocr?.lines ?? [], gameHint);
      if (extracted) {
        const visionCandidates = await groundFromExtraction(supabase, extracted);
        if (visionCandidates.length) {
          const top = visionCandidates[0];
          return json({
            scanId,
            usedVision: true,
            candidates: visionCandidates.slice(0, 5),
            lowConfidence: top.confidence < 0.85,
          });
        }
      }
    }

    // 3) Fall back to whatever OCR grounding produced (low confidence → picker).
    return json({
      scanId,
      usedVision: Boolean(imageBase64),
      candidates: ocrCandidates.slice(0, 5),
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

async function callVisionModel(
  imageBase64: string,
  ocrLines: string[],
  gameHint?: string,
): Promise<Extraction | null> {
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) return null;

  const prompt = [
    "You identify trading cards (Pokémon, Magic: The Gathering, Yu-Gi-Oh!).",
    "Return ONLY a JSON object, no prose, with this exact shape:",
    '{"game":"pokemon|magic|yugioh|unknown","name":string|null,"setName":string|null,',
    '"setCode":string|null,"number":string|null,"variantCues":string[],"confidence":number}',
    "Read the card in the image. Use the OCR hints below to disambiguate; if the image",
    "contradicts a hint, prefer the image. If unsure of a field, use null and lower the",
    "confidence (0.0–1.0). variantCues are visible cues like 'holo','reverse holo',",
    "'1st edition','full art','promo'.",
    gameHint ? `The user thinks this is a ${gameHint} card.` : "",
    ocrLines.length ? `OCR hints: ${ocrLines.slice(0, 12).join(" | ")}` : "No OCR hints.",
  ].join("\n");

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

// ---- Catalog grounding ------------------------------------------------------

// deno-lint-ignore no-explicit-any
async function groundFromExtraction(supabase: any, e: Extraction) {
  if (!e.name && !e.number) return [];
  const game = e.game && e.game !== "unknown" ? e.game : undefined;
  const candidates = await queryCatalog(supabase, e.name, e.number, game);
  // Blend the model's confidence with the catalog match score.
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
