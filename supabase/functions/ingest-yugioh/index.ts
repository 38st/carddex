// Catalog ingestion: YGOPRODeck API → Supabase `cards` table.
// Free API, no key required. ~12k Yu-Gi-Oh! cards.
//
// Usage:
//   deno run --allow-net --allow-env supabase/functions/ingest-yugioh/index.ts
//
// Env vars:
//   SUPABASE_URL
//   SUPABASE_SERVICE_ROLE_KEY

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const YGO_API = "https://db.ygoprodeck.com/api/v7";

// deno-lint-ignore no-explicit-any
const supabase: any = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

async function ingestSets() {
  console.log("📦 Fetching Yu-Gi-Oh! sets…");
  const res = await fetch(`${YGO_API}/cardsets.php`);
  if (!res.ok) { console.error(`Sets fetch failed: ${res.status}`); return; }
  const sets = await res.json();

  const rows = (sets as any[]).map((s) => ({
    id: s.set_code ?? s.set_name,
    game: "yugioh",
    name: s.set_name,
    code: s.set_code ?? null,
    series: null,
    release_date: s.tcg_date ?? s.ocg_date ?? null,
    total_cards: Number(s.num_of_cards) ?? null,
    printed_total: Number(s.num_of_cards) ?? null,
    symbol_url: s.set_image ?? null,
    logo_url: null,
  }));

  const BATCH = 100;
  for (let i = 0; i < rows.length; i += BATCH) {
    const batch = rows.slice(i, i + BATCH);
    const { error } = await supabase.from("sets").upsert(batch, { onConflict: "id" });
    if (error) console.error(`Set upsert error (batch ${i}):`, error.message);
  }
  console.log(`✅ Ingested ${rows.length} sets`);
}

async function ingestCards() {
  console.log("🎴 Fetching Yu-Gi-Oh! cards…");
  const res = await fetch(`${YGO_API}/cardinfo.php`);
  if (!res.ok) {
    console.error(`Cards fetch failed: ${res.status}`);
    return;
  }
  const data = await res.json();
  const cards = data.data ?? [];

  const rows = cards.map((c: any) => ({
    id: `ygo-${c.id}`,
    game: "yugioh",
    name: c.name,
    set_name: c.card_sets?.[0]?.set_name ?? null,
    set_id: c.card_sets?.[0]?.set_code ?? null,
    number: c.card_sets?.[0]?.set_code ?? null,
    rarity: c.card_sets?.[0]?.set_rarity ?? null,
    image_url: c.card_images?.[0]?.image_url_small ?? c.card_images?.[0]?.image_url ?? null,
    variant: c.frameType ?? null,
    supertype: c.type ?? null,
    name_normalized: (c.name ?? "").toLowerCase().normalize("NFKD").replace(/[^\w\s]/g, ""),
    number_normalized: String(c.id ?? ""),
  }));

  const BATCH = 100;
  for (let i = 0; i < rows.length; i += BATCH) {
    const batch = rows.slice(i, i + BATCH);
    const { error } = await supabase.from("cards").upsert(batch, { onConflict: "id" });
    if (error) console.error(`Card upsert error (batch ${i}):`, error.message);
  }

  console.log(`✅ Ingested ${rows.length} Yu-Gi-Oh! cards`);
}

console.log("=== YGOPRODeck Catalog Ingestion ===");
await ingestSets();
await ingestCards();
console.log("=== Done ===");
