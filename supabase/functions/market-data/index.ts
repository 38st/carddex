// Carddex `market-data` Edge Function.
//
// Serves Card Ladder-style market data from the 0008 tables (card_sales,
// card_grade_values, market_index_points). Public read — catalog and market
// data are shared, so no auth is required.
//
// Request (GET):
//   ?cardId=<id>          → { cardId, gradedPrices, recentSales, population, change30d }
//   ?index               → overall Case Index: { category: null, points: [{ asOf, value }] }
//   ?index=<category>     → a sub-index, e.g. ?index=basketball
//
// The iOS client maps this 1:1 onto CardMarket / MarketIndex. Until this is
// deployed and populated, the app falls back to bundled SampleData.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

const RECENT_SALES_LIMIT = Number(Deno.env.get("RECENT_SALES_LIMIT") ?? "12");

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const url = new URL(req.url);
    // deno-lint-ignore no-explicit-any
    const supabase: any = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    if (url.searchParams.has("index")) {
      const category = url.searchParams.get("index") || null; // "" → overall
      let q = supabase
        .from("market_index_points")
        .select("as_of, value")
        .order("as_of", { ascending: true });
      q = category === null ? q.is("category", null) : q.eq("category", category);
      const { data, error } = await q;
      if (error) throw error;
      return json({
        category,
        points: (data ?? []).map((r: { as_of: string; value: number }) => ({
          asOf: r.as_of,
          value: Number(r.value),
        })),
      });
    }

    const cardId = url.searchParams.get("cardId");
    if (!cardId) return json({ error: "pass ?cardId=<id> or ?index[=category]" }, 400);

    const [grades, sales, history] = await Promise.all([
      supabase
        .from("card_grade_values")
        .select("grade, market_price, population, change_30d")
        .eq("card_id", cardId),
      supabase
        .from("card_sales")
        .select("grade, price, currency, platform, sold_at")
        .eq("card_id", cardId)
        .order("sold_at", { ascending: false })
        .limit(RECENT_SALES_LIMIT),
      // Real price history (one point per captured snapshot), oldest → newest.
      supabase
        .from("price_snapshots")
        .select("market_price, captured_at")
        .eq("card_id", cardId)
        .not("market_price", "is", null)
        .order("captured_at", { ascending: true })
        .limit(365),
    ]);
    if (grades.error) throw grades.error;
    if (sales.error) throw sales.error;
    if (history.error) throw history.error;

    // Population and 30d change are taken from the top (most valuable) grade.
    const gradedPrices = (grades.data ?? [])
      .map((g: GradeRow) => ({ grade: g.grade, price: Number(g.market_price ?? 0) }))
      .sort((a: { price: number }, b: { price: number }) => b.price - a.price);
    const top = (grades.data ?? []).slice().sort(
      (a: GradeRow, b: GradeRow) => Number(b.market_price ?? 0) - Number(a.market_price ?? 0),
    )[0];

    return json({
      cardId,
      gradedPrices,
      population: top?.population ?? null,
      change30d: Number(top?.change_30d ?? 0),
      recentSales: (sales.data ?? []).map((s: SaleRow) => ({
        grade: s.grade,
        price: Number(s.price),
        currency: s.currency,
        platform: s.platform,
        soldAt: s.sold_at,
      })),
      history: (history.data ?? []).map((h: HistoryRow) => ({
        asOf: h.captured_at,
        price: Number(h.market_price),
      })),
    });
  } catch (err) {
    // deno-lint-ignore no-explicit-any
    const e = err as any;
    return json({ error: e?.message ?? e?.hint ?? JSON.stringify(e) }, 500);
  }
});

interface GradeRow {
  grade: string;
  market_price: number | null;
  population: number | null;
  change_30d: number | null;
}
interface SaleRow {
  grade: string;
  price: number;
  currency: string;
  platform: string;
  sold_at: string;
}
interface HistoryRow {
  market_price: number;
  captured_at: string;
}

// deno-lint-ignore no-explicit-any
function json(body: any, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "content-type": "application/json" },
  });
}
