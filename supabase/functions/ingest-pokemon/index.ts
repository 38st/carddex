// Catalog ingestion: Pokémon TCG API → Supabase `cards` table.
// Free API, no key required. ~100k cards across all sets.
//
// Usage:
//   deno run --allow-net --allow-env supabase/functions/ingest-pokemon/index.ts
//
// Env vars:
//   SUPABASE_URL       — project URL
//   SUPABASE_SERVICE_ROLE_KEY — service role key (bypasses RLS)
//
// Paginates through https://api.pokemontcg.io/v2/cards in batches of 250,
// upserts into the `cards` and `sets` tables.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const POKEMON_API = "https://api.pokemontcg.io/v2";
const PAGE_SIZE = 250;
const MAX_CARDS = Number(Deno.env.get("MAX_CARDS") ?? "0"); // 0 = all

// deno-lint-ignore no-explicit-any
const supabase: any = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

async function ingestSets() {
  console.log("📦 Fetching Pokémon sets…");
  const res = await fetch(`${POKEMON_API}/sets?pageSize=250`);
  if (!res.ok) { console.error(`Sets fetch failed: ${res.status}`); return; }
  const data = await res.json();
  const sets = (data.data ?? []).map((s: any) => ({
    id: s.id,
    game: "pokemon",
    name: s.name,
    code: s.ptcgoCode ?? s.id,
    series: s.series,
    release_date: s.releaseDate ?? null,
    total_cards: s.printedTotal ?? s.totalCount ?? null,
    printed_total: s.printedTotal ?? null,
    symbol_url: s.images?.symbol ?? null,
    logo_url: s.images?.logo ?? null,
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
  console.log("🎴 Fetching Pokémon cards…");
  let page = 1;
  let total = 0;

  while (true) {
    const url = `${POKEMON_API}/cards?page=${page}&pageSize=${PAGE_SIZE}`;
    const res = await fetch(url);
    if (!res.ok) {
      console.error(`Cards fetch failed (page ${page}): ${res.status}`);
      break;
    }
    const data = await res.json();
    const cards = data.data ?? [];
    if (cards.length === 0) break;

    const rows = cards.map((c: any) => ({
      id: c.id,
      game: "pokemon",
      name: c.name,
      set_name: c.set?.name ?? null,
      set_id: c.set?.id ?? null,
      number: c.number ?? null,
      rarity: c.rarity ?? null,
      image_url: c.images?.small ?? c.images?.large ?? null,
      variant: c.subtypes?.join(",") ?? null,
      supertype: c.supertype ?? null,
      name_normalized: (c.name ?? "").toLowerCase().normalize("NFKD").replace(/[^\w\s]/g, ""),
      number_normalized: (c.number ?? "").replace(/\D/g, ""),
    }));

    const BATCH = 100;
    for (let i = 0; i < rows.length; i += BATCH) {
      const batch = rows.slice(i, i + BATCH);
      const { error } = await supabase.from("cards").upsert(batch, { onConflict: "id" });
      if (error) console.error(`Card upsert error (page ${page}, batch ${i}):`, error.message);
    }

    total += cards.length;
    console.log(`  page ${page}: ${cards.length} cards (total: ${total})`);

    if (cards.length < PAGE_SIZE) break;
    if (MAX_CARDS > 0 && total >= MAX_CARDS) {
      console.log(`  reached MAX_CARDS limit (${MAX_CARDS})`);
      break;
    }
    page++;
    // Be polite to the API.
    await new Promise((r) => setTimeout(r, 200));
  }

  console.log(`✅ Ingested ${total} Pokémon cards`);
}

console.log("=== Pokémon TCG Catalog Ingestion ===");
await ingestSets();
await ingestCards();
console.log("=== Done ===");
