# Sports market data via eBay (the real pipeline)

The app's sports prices come from **eBay completed sales** — the same raw data
Card Ladder is built on. This doc is the runbook: how to get access, how the
ingestion works, and what to do if eBay says no.

## The honest reality of eBay access

eBay's **Marketplace Insights API** (the one with *sold* prices) is a
**Limited-Release, restricted API**. Per eBay's own developer community:

- It works in **sandbox** with any keyset, but **production access is granted
  only to vetted partners** after an Application Growth Check + business review.
- New/small developers are frequently **denied** production access.
- The sports-cards category must be **whitelisted** for your app.

So: apply, but treat approval as the bottleneck, not a formality. The ingestion
code is identical for sandbox and production — only the keyset/`EBAY_ENV` differ —
so you can prove the whole pipeline in sandbox today and flip to prod if approved.

## Step 1 — Get an eBay developer keyset (free, ~10 min)

1. Sign up at <https://developer.ebay.com> (free).
2. **Application Keys** → create a keyset. You get **App ID (Client ID)** and
   **Cert ID (Client Secret)** for both **Sandbox** and **Production**.
3. Accept the API License Agreement.

That alone unlocks **sandbox** Marketplace Insights — enough to verify our code.

## Step 2 — Apply for PRODUCTION Marketplace Insights access

1. In your dev account, run the **Application Growth Check**
   (<https://developer.ebay.com/api-docs/static/gs_use-the-application-growth.html>).
2. Request the scope `buy.marketplace.insights` for production, and **email eBay
   developer support** with your use case (a card price-tracking app) and ask for
   the **Sports Trading Cards** category to be whitelisted.
3. Wait. This is the long pole and may be denied.

## Step 3 — Drop the keys in and run

Once you have a keyset (sandbox now, or production when approved):

```bash
supabase secrets set \
  EBAY_CLIENT_ID=<App ID> \
  EBAY_CLIENT_SECRET=<Cert ID> \
  EBAY_ENV=sandbox            # or: production
supabase functions deploy ebay-ingest

# trigger an ingest (or schedule it as a cron):
curl -X POST "$SUPABASE_URL/functions/v1/ebay-ingest" -H "Authorization: Bearer $ANON"
```

`ebay-ingest` does the rest:

1. OAuth client-credentials token (scope `buy.marketplace.insights`).
2. For each card in `cards` with an `ebay_query`, calls `item_sales/search`.
3. Parses the **grade from the listing title** (PSA/BGS/SGC → else Raw — eBay has
   no structured grade field).
4. Upserts rows into `card_sales` (deduped on the eBay `itemId`).
5. Calls `rollup_card()` → recomputes `card_grade_values` (30-day avg per grade +
   30-day change). The Market tab then serves real prices via `market-data`.

Index rollups (`market_index_points`) come next as a `market-rollup` cron.

## If eBay denies production access — fallbacks

- **eBay Browse API** (`item_summary/search`) — *active* listings (asking prices,
  a proxy for market), **not** restricted; any dev gets production access. Nearly
  the same request shape — `ebay-ingest` can be pointed at it with small changes.
- **PriceCharting / SportsCardsPro API** — paid (~$30+/mo), no approval, real
  graded + raw sports prices + bulk CSV. The fastest *guaranteed* real-data path.

## What I can / can't do

I can write and run all the code (done: schema, `ebay-ingest`, rollups). I
**cannot** create your eBay account, pay for a feed, or get you approved — those
need your credentials. Hand me a keyset and I verify the pipeline end-to-end.
