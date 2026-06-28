// Carddex `catalog-sync` Edge Function.
//
// Pulls card catalog data from free public APIs and upserts into the `cards`
// and `sets` tables. Supports:
//   - Pokémon TCG API (https://api.pokemontcg.io/v2) — no key needed (rate-limited)
//   - Scryfall (https://api.scryfall.com) — Magic: The Gathering, no key needed
//   - YGOPRODeck (https://db.ygoprodeck.com/api/v7) — Yu-Gi-Oh!, no key needed
//
// Trigger: POST (manually or from pg_cron). Optional body: { "game": "pokemon" }
// to sync only one game. Defaults to all three.
//
// Secrets (optional):
//   POKEMON_TCG_API_KEY — raises Pokémon TCG API rate limit (otherwise 250 req/day)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    // deno-lint-ignore no-explicit-any
    const supabase: any = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    let requestedGame: string | null = null;
    if (req.method === "POST") {
      try {
        const body = await req.json();
        requestedGame = body.game ?? null;
      } catch { /* empty body is fine */ }
    }

    const results: Record<string, { sets: number; cards: number }> = {};

    if (!requestedGame || requestedGame === "pokemon") {
      results.pokemon = await syncPokemon(supabase);
    }
    if (!requestedGame || requestedGame === "magic") {
      results.magic = await syncMagic(supabase);
    }
    if (!requestedGame || requestedGame === "yugioh") {
      results.yugioh = await syncYugioh(supabase);
    }

    return json({ synced: results });
  } catch (err) {
    // deno-lint-ignore no-explicit-any
    const e = err as any;
    return json({ error: e?.message ?? String(e) }, 500);
  }
});

// ─── Pokémon TCG API ──────────────────────────────────────────────────────────

async function syncPokemon(supabase: any): Promise<{ sets: number; cards: number }> {
  const apiKey = Deno.env.get("POKEMON_TCG_API_KEY");
  const headers: Record<string, string> = {};
  if (apiKey) headers["X-Api-Key"] = apiKey;

  // Sync sets first.
  let setCount = 0;
  let setsUrl: string | null = "https://api.pokemontcg.io/v2/sets?pageSize=250";
  while (setsUrl) {
    const res = await fetch(setsUrl, { headers });
    if (!res.ok) throw new Error(`Pokémon sets ${res.status}: ${await res.text()}`);
    const data = await res.json();
    const rows = (data.data ?? []).map((s: PokemonSet) => ({
      id: s.id,
      game: "pokemon",
      name: s.name,
      code: s.ptcgoCode ?? s.id,
      series: s.series,
      release_date: s.releaseDate,
      total_cards: s.printedTotal ?? s.total,
      printed_total: s.printedTotal,
      symbol_url: s.images?.symbol,
      logo_url: s.images?.logo,
      updated_at: new Date().toISOString(),
    }));
    if (rows.length) {
      const { error } = await supabase.from("sets").upsert(rows, { onConflict: "id" });
      if (error) throw error;
      setCount += rows.length;
    }
    setsUrl = data.page ? nextPageUrl(setsUrl, data.page, data.totalCount) : null;
  }

  // Sync cards (paginated, page size 250).
  let cardCount = 0;
  let page = 1;
  while (true) {
    const url = `https://api.pokemontcg.io/v2/cards?pageSize=250&page=${page}`;
    const res = await fetch(url, { headers });
    if (!res.ok) throw new Error(`Pokémon cards p${page} ${res.status}: ${await res.text()}`);
    const data = await res.json();
    const cards = data.data ?? [];
    if (!cards.length) break;

    const rows = cards.map((c: PokemonCard) => ({
      id: c.id,
      game: "pokemon",
      name: c.name,
      set_name: c.set?.name ?? "",
      set_id: c.set?.id,
      number: c.number ?? "",
      rarity: c.rarity,
      image_url: c.images?.large ?? c.images?.small,
      supertype: c.supertype,
      updated_at: new Date().toISOString(),
    }));

    const { error } = await supabase.from("cards").upsert(rows, { onConflict: "id" });
    if (error) throw error;
    cardCount += rows.length;

    if (cards.length < 250) break;
    page++;
    // Safety cap: 50 pages = 12,500 cards per run.
    if (page > 50) break;
  }

  return { sets: setCount, cards: cardCount };
}

// ─── Scryfall (Magic: The Gathering) ──────────────────────────────────────────

async function syncMagic(supabase: any): Promise<{ sets: number; cards: number }> {
  // Sync sets.
  const setsRes = await fetch("https://api.scryfall.io/sets");
  if (!setsRes.ok) throw new Error(`Scryfall sets ${setsRes.status}: ${await setsRes.text()}`);
  const setsData = await setsRes.json();
  const setRows = (setsData.data ?? [])
    .filter((s: ScryfallSet) => !s.digital)
    .map((s: ScryfallSet) => ({
      id: s.code,
      game: "magic",
      name: s.name,
      code: s.code.toUpperCase(),
      series: s.set_type,
      release_date: s.released_at,
      total_cards: s.card_count,
      printed_total: s.card_count,
      symbol_url: s.icon_svg_uri,
      logo_url: null,
      updated_at: new Date().toISOString(),
    }));
  if (setRows.length) {
    const { error } = await supabase.from("sets").upsert(setRows, { onConflict: "id" });
    if (error) throw error;
  }

  // Sync cards via bulk data (default cards — all non-digital, English+non-English).
  // Scryfall provides a bulk-data JSON URI that contains all cards in one file.
  const bulkRes = await fetch("https://api.scryfall.io/bulk-data");
  if (!bulkRes.ok) throw new Error(`Scryfall bulk ${bulkRes.status}: ${await bulkRes.text()}`);
  const bulkData = await bulkRes.json();
  const defaultBulk = (bulkData.data ?? []).find(
    (b: ScryfallBulk) => b.type === "default_cards",
  );
  if (!defaultBulk) throw new Error("Scryfall: no default_cards bulk data found");

  // Download the bulk file (can be ~100MB; stream-parse in chunks if needed).
  const cardsRes = await fetch(defaultBulk.download_uri);
  if (!cardsRes.ok) throw new Error(`Scryfall bulk download ${cardsRes.status}`);
  const allCards: ScryfallCard[] = await cardsRes.json();

  // Batch upsert (Supabase has a 1000-row practical limit per request).
  let cardCount = 0;
  const BATCH = 500;
  for (let i = 0; i < allCards.length; i += BATCH) {
    const batch = allCards.slice(i, i + BATCH);
    const rows = batch.map((c) => ({
      id: c.id,
      game: "magic",
      name: c.name,
      set_name: c.set_name ?? "",
      set_id: c.set,
      number: c.collector_number ?? "",
      rarity: c.rarity,
      image_url: c.image_uris?.normal ?? c.image_uris?.small,
      supertype: c.type_line?.split("—")[0]?.trim(),
      updated_at: new Date().toISOString(),
    }));
    const { error } = await supabase.from("cards").upsert(rows, { onConflict: "id" });
    if (error) throw error;
    cardCount += rows.length;
  }

  return { sets: setRows.length, cards: cardCount };
}

// ─── YGOPRODeck (Yu-Gi-Oh!) ───────────────────────────────────────────────────

async function syncYugioh(supabase: any): Promise<{ sets: number; cards: number }> {
  // YGOPRODeck has no separate sets endpoint; use cardinfo which includes set info.
  const res = await fetch("https://db.ygoprodeck.com/api/v7/cardinfo.php");
  if (!res.ok) throw new Error(`YGOPRODeck ${res.status}: ${await res.text()}`);
  const data = await res.json();
  const allCards: YgoCard[] = data.data ?? [];

  // Extract unique sets from card set memberships.
  const setMap = new Map<string, { id: string; name: string; code: string }>();
  for (const c of allCards) {
    for (const sm of c.card_sets ?? []) {
      if (!setMap.has(sm.set_code)) {
        setMap.set(sm.set_code, { id: sm.set_code, name: sm.set_name, code: sm.set_code });
      }
    }
  }
  const setRows = [...setMap.values()].map((s) => ({
    id: s.id,
    game: "yugioh",
    name: s.name,
    code: s.code,
    updated_at: new Date().toISOString(),
  }));
  if (setRows.length) {
    const { error } = await supabase.from("sets").upsert(setRows, { onConflict: "id" });
    if (error) throw error;
  }

  // Upsert cards.
  let cardCount = 0;
  const BATCH = 500;
  for (let i = 0; i < allCards.length; i += BATCH) {
    const batch = allCards.slice(i, i + BATCH);
    const rows = batch.map((c) => ({
      id: String(c.id),
      game: "yugioh",
      name: c.name,
      set_name: c.card_sets?.[0]?.set_name ?? "",
      number: String(c.id),
      rarity: c.rarity,
      image_url: c.card_images?.[0]?.image_url,
      supertype: c.type,
      updated_at: new Date().toISOString(),
    }));
    const { error } = await supabase.from("cards").upsert(rows, { onConflict: "id" });
    if (error) throw error;
    cardCount += rows.length;
  }

  return { sets: setRows.length, cards: cardCount };
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function nextPageUrl(url: string, page: number, totalCount: number): string | null {
  const perPage = 250;
  if (page * perPage >= totalCount) return null;
  const u = new URL(url);
  u.searchParams.set("page", String(page + 1));
  return u.toString();
}

// deno-lint-ignore no-explicit-any
function json(body: any, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "content-type": "application/json" },
  });
}

// ─── Types ────────────────────────────────────────────────────────────────────

interface PokemonSet {
  id: string; name: string; series: string; releaseDate: string;
  printedTotal?: number; total?: number; ptcgoCode?: string;
  images?: { symbol?: string; logo?: string };
}
interface PokemonCard {
  id: string; name: string; number?: string; rarity?: string; supertype?: string;
  set?: { id: string; name: string };
  images?: { small?: string; large?: string };
}
interface ScryfallSet {
  code: string; name: string; set_type: string; released_at: string;
  card_count: number; digital: boolean; icon_svg_uri: string;
}
interface ScryfallBulk { type: string; download_uri: string; }
interface ScryfallCard {
  id: string; name: string; set: string; set_name?: string;
  collector_number?: string; rarity?: string; type_line?: string;
  image_uris?: { small?: string; normal?: string };
}
interface YgoCard {
  id: number; name: string; type: string; rarity?: string;
  card_sets?: { set_name: string; set_code: string }[];
  card_images?: { image_url: string }[];
}
