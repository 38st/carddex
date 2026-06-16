// Carddex `ebay-ingest` Edge Function.
//
// Pulls recent eBay SOLD prices into `card_sales`, then rolls them up into
// `card_grade_values` (per-grade market price + 30d change) via rollup_card().
//
// Uses eBay's Marketplace Insights API (`item_sales/search`) — a RESTRICTED,
// Limited-Release API. Works in sandbox immediately; PRODUCTION access must be
// granted by eBay (Application Growth Check + business review). See
// docs/ebay-data-pipeline.md. The code is identical for sandbox/prod; only the
// EBAY_ENV/secrets differ.
//
// Secrets (set with `supabase secrets set ...`):
//   EBAY_CLIENT_ID, EBAY_CLIENT_SECRET   — your production (or sandbox) keyset
//   EBAY_ENV = production | sandbox       — default production
//   EBAY_MARKETPLACE_ID = EBAY_US         — default EBAY_US
//
// Trigger: POST (manually or from a cron). Returns per-card ingest counts.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const ENV = Deno.env.get("EBAY_ENV") ?? "production";
const HOST = ENV === "sandbox" ? "https://api.sandbox.ebay.com" : "https://api.ebay.com";
const OAUTH_URL = `${HOST}/identity/v1/oauth2/token`;
const INSIGHTS_URL = `${HOST}/buy/marketplace_insights/v1_beta/item_sales/search`;
const SCOPE = "https://api.ebay.com/oauth/api_scope/buy.marketplace.insights";
const MARKETPLACE = Deno.env.get("EBAY_MARKETPLACE_ID") ?? "EBAY_US";
// eBay "Sports Mem, Cards & Fan Shop" → Sports Trading Cards (261328).
const CATEGORY = Deno.env.get("EBAY_SPORTS_CATEGORY") ?? "261328";
const PER_CARD_LIMIT = Number(Deno.env.get("EBAY_PER_CARD_LIMIT") ?? "50");

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    // deno-lint-ignore no-explicit-any
    const supabase: any = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const token = await appToken();

    const { data: cards, error } = await supabase
      .from("cards")
      .select("id, ebay_query")
      .not("ebay_query", "is", null);
    if (error) throw error;

    const results: Record<string, number> = {};
    for (const card of cards ?? []) {
      results[card.id] = await ingestCard(supabase, token, card.id, card.ebay_query);
    }
    return json({ ingested: results, env: ENV });
  } catch (err) {
    // deno-lint-ignore no-explicit-any
    const e = err as any;
    return json({ error: e?.message ?? String(e) }, 500);
  }
});

async function appToken(): Promise<string> {
  const id = Deno.env.get("EBAY_CLIENT_ID");
  const secret = Deno.env.get("EBAY_CLIENT_SECRET");
  if (!id || !secret) {
    throw new Error("Missing EBAY_CLIENT_ID / EBAY_CLIENT_SECRET — set them with `supabase secrets set` (see docs/ebay-data-pipeline.md).");
  }
  const res = await fetch(OAUTH_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      Authorization: `Basic ${btoa(`${id}:${secret}`)}`,
    },
    body: `grant_type=client_credentials&scope=${encodeURIComponent(SCOPE)}`,
  });
  if (!res.ok) throw new Error(`eBay OAuth ${res.status}: ${await res.text()}`);
  return (await res.json()).access_token;
}

async function ingestCard(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  token: string,
  cardId: string,
  query: string,
): Promise<number> {
  const url = new URL(INSIGHTS_URL);
  url.searchParams.set("q", query);
  url.searchParams.set("filter", `categoryIds:{${CATEGORY}}`);
  url.searchParams.set("limit", String(PER_CARD_LIMIT));

  const res = await fetch(url, {
    headers: {
      Authorization: `Bearer ${token}`,
      "X-EBAY-C-MARKETPLACE-ID": MARKETPLACE,
    },
  });
  if (!res.ok) throw new Error(`Insights ${res.status} for "${query}": ${await res.text()}`);
  const data = await res.json();

  const rows = (data.itemSales ?? [])
    .map((s: ItemSale) => ({
      card_id: cardId,
      grade: gradeFromTitle(s.title ?? ""),
      price: Number(s.lastSoldPrice?.value ?? 0),
      currency: s.lastSoldPrice?.currency ?? "USD",
      platform: "eBay",
      sold_at: s.lastSoldDate,
      source: "ebay",
      external_id: s.itemId,
    }))
    .filter((r: { price: number; sold_at?: string }) => r.price > 0 && !!r.sold_at);

  if (rows.length) {
    const { error } = await supabase
      .from("card_sales")
      .upsert(rows, { onConflict: "source,external_id", ignoreDuplicates: true });
    if (error) throw error;
    await supabase.rpc("rollup_card", { p_card_id: cardId });
  }
  return rows.length;
}

/// Infer the grade from a listing title — eBay has no structured grade field.
function gradeFromTitle(title: string): string {
  const t = title.toUpperCase();
  const psa = t.match(/PSA\s?(10|9\.5|9|8|7|6|5|4|3|2|1)/);
  if (psa) return `PSA ${psa[1]}`;
  const bgs = t.match(/BGS\s?(10|9\.5|9|8\.5|8)/);
  if (bgs) return `BGS ${bgs[1]}`;
  const sgc = t.match(/SGC\s?(10|9\.5|9|8)/);
  if (sgc) return `SGC ${sgc[1]}`;
  return "Raw";
}

interface ItemSale {
  itemId?: string;
  title?: string;
  lastSoldDate?: string;
  lastSoldPrice?: { value?: string; currency?: string };
}

// deno-lint-ignore no-explicit-any
function json(body: any, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "content-type": "application/json" },
  });
}
