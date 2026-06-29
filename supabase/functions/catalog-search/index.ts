// Carddex `catalog-search` Edge Function.
//
// Free-text catalog search for the manual fallback: when a scan can't be
// identified, the app lets the user type a name/number and pick a real,
// catalog-grounded card instead of creating an untracked orphan.
//
// Unlike `identify`, this makes NO vision call, charges no quota, and writes no
// telemetry — it's a plain catalog lookup, safe to call on every keystroke
// (the client debounces). Public read: the catalog is shared, so no auth is
// required (an Authorization header is accepted but ignored).
//
// Request (POST):  { query: string, gameHint?: "pokemon"|"magic"|"yugioh"|"sports" }
// Response:        { candidates: [{ card, confidence }], lowConfidence: true }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const RESULT_LIMIT = Number(Deno.env.get("CATALOG_SEARCH_LIMIT") ?? "12");

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const { query, gameHint } = await req.json();
    const q = typeof query === "string" ? query.trim() : "";
    if (q.length < 2) return json({ candidates: [], lowConfidence: true });

    // deno-lint-ignore no-explicit-any
    const supabase: any = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const candidates = await searchCatalog(supabase, q, gameHint);
    return json({ candidates: candidates.slice(0, RESULT_LIMIT), lowConfidence: true });
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

// ---- Catalog search ---------------------------------------------------------

// deno-lint-ignore no-explicit-any
async function searchCatalog(supabase: any, query: string, game?: string) {
  // Escape LIKE wildcards in user input so a typed "%" doesn't match everything.
  const safe = query.replace(/[%_]/g, "\\$&");
  // Match the typed text against either the card name or its collector number,
  // so "Charizard" and "4/102" both resolve.
  let q = supabase
    .from("cards")
    .select("*")
    .or(`name.ilike.%${safe}%,number.ilike.%${safe}%`)
    .limit(RESULT_LIMIT);
  if (game && game !== "unknown") q = q.eq("game", game);

  const { data, error } = await q;
  if (error || !data) return [];
  return data
    // deno-lint-ignore no-explicit-any
    .map((row: any) => ({ card: toCard(row), confidence: scoreMatch(row, query) }))
    // deno-lint-ignore no-explicit-any
    .sort((a: any, b: any) => b.confidence - a.confidence);
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

// Rank exact and prefix name matches above mid-string hits.
// deno-lint-ignore no-explicit-any
function scoreMatch(row: any, query: string): number {
  const name = String(row.name ?? "").toLowerCase();
  const q = query.toLowerCase();
  if (name === q) return 0.95;
  if (name.startsWith(q)) return 0.85;
  if (name.includes(q)) return 0.7;
  // Matched on number only.
  return 0.6;
}
