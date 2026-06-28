// Catalog ingestion: Scryfall API → Supabase `cards` table.
// Free API, no key required. ~80k Magic cards.
//
// Usage:
//   deno run --allow-net --allow-env supabase/functions/ingest-mtg/index.ts
//
// Env vars:
//   SUPABASE_URL
//   SUPABASE_SERVICE_ROLE_KEY
//   MAX_CARDS — 0 = all

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SCRYFALL_API = "https://api.scryfall.com";
const PAGE_SIZE = 175; // Scryfall max page size
const MAX_CARDS = Number(Deno.env.get("MAX_CARDS") ?? "0");

// deno-lint-ignore no-explicit-any
const supabase: any = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

async function ingestSets() {
  console.log("📦 Fetching MTG sets…");
  const res = await fetch(`${SCRYFALL_API}/sets`);
  if (!res.ok) { console.error(`Sets fetch failed: ${res.status}`); return; }
  const data = await res.json();
  const sets = (data.data ?? []).map((s: any) => ({
    id: s.id,
    game: "magic",
    name: s.name,
    code: s.code ?? null,
    series: s.block ?? null,
    release_date: s.released_at ?? null,
    total_cards: s.card_count ?? null,
    printed_total: s.card_count ?? null,
    symbol_url: s.icon_svg_uri ?? null,
    logo_url: null,
  }));

  const BATCH = 100;
  for (let i = 0; i < sets.length; i += BATCH) {
    const batch = sets.slice(i, i + BATCH);
    const { error } = await supabase.from("sets").upsert(batch, { onConflict: "id" });
    if (error) console.error(`Set upsert error (batch ${i}):`, error.message);
  }
  console.log(`✅ Ingested ${sets.length} sets`);
}

async function ingestCards() {
  console.log("🎴 Fetching MTG cards (this will take a while)…");
  let page = 1;
  let total = 0;

  // Scryfall uses a cursor-based pagination via the data + has_more + next_page pattern.
  let url: string | null = `${SCRYFALL_API}/cards?page=1`;

  while (url) {
    const res = await fetch(url);
    if (!res.ok) {
      console.error(`Cards fetch failed: ${res.status}`);
      break;
    }
    const data = await res.json();
    const cards = data.data ?? [];
    if (cards.length === 0) break;

    const rows = cards.map((c: any) => ({
      id: c.id,
      game: "magic",
      name: c.name,
      set_name: c.set_name ?? null,
      set_id: c.set_id ?? null,
      number: c.collector_number ?? null,
      rarity: c.rarity ?? null,
      image_url: c.image_uris?.small ?? c.image_uris?.normal ?? null,
      variant: c.frame ?? null,
      supertype: c.type_line?.split("—")[0]?.trim() ?? null,
      name_normalized: (c.name ?? "").toLowerCase().normalize("NFKD").replace(/[^\w\s]/g, ""),
      number_normalized: (c.collector_number ?? "").replace(/\D/g, ""),
    }));

    const BATCH = 100;
    for (let i = 0; i < rows.length; i += BATCH) {
      const batch = rows.slice(i, i + BATCH);
      const { error } = await supabase.from("cards").upsert(batch, { onConflict: "id" });
      if (error) console.error(`Card upsert error (page ${page}, batch ${i}):`, error.message);
    }

    total += cards.length;
    console.log(`  page ${page}: ${cards.length} cards (total: ${total})`);

    if (MAX_CARDS > 0 && total >= MAX_CARDS) {
      console.log(`  reached MAX_CARDS limit (${MAX_CARDS})`);
      break;
    }

    page++;
    // Scryfall rate limiting: 50-100ms between requests.
    await new Promise((r) => setTimeout(r, 100));
    url = data.has_more ? data.next_page : null;
  }

  console.log(`✅ Ingested ${total} MTG cards`);
}

console.log("=== Scryfall (MTG) Catalog Ingestion ===");
await ingestSets();
await ingestCards();
console.log("=== Done ===");
