# Recognition cost & scaling

How one server-side vision key safely serves every user, and how recognition gets
cheaper as the app grows.

## The ladder (cheapest → most capable)
Each scan walks down only as far as it must:

1. **On-device OCR + catalog match — $0.** Apple Vision reads the card text; we fuzzy-match
   it against the catalog. Resolves the majority of clean scans with no network call.
2. **Cache hit — $0.** The same photo (content hash) returns its stored result; never re-billed.
3. **Cloud vision model — ~sub-cent.** Only ambiguous scans reach the model (Claude Haiku),
   which reads the card and we ground its output against the catalog.
4. **(Scale) Embedding search — ~$0/query.** Index every card's official image once; match a
   photo by nearest-neighbor on our own infra. The LLM becomes the long-tail fallback, not a
   per-scan tax.
5. **(Later) On-device Core ML — $0, offline.** Identification on the phone for the common case.

Steps 1–3 are built. Steps 4–5 are the scale path below.

## Cost guardrails (built — `functions/identify`)
One Anthropic key serves all users; these keep the bill bounded:
- **OCR-first** deflects ~60% of scans before any paid call.
- **`scan_cache`** (migration 0007): same photo → cached result, no charge.
- **Per-user daily vision cap** (`DAILY_VISION_CAP`, default 8): bounds any single account.
- **Global daily spend circuit-breaker** (`DAILY_SPEND_CEILING_USD`, default 50): if today's
  spend exceeds the ceiling, stop calling the model and serve OCR-only until tomorrow.
- **Per-scan cost recorded** in `scans.cost_usd` for live spend tracking + alerting.

Tune via Edge Function secrets: `DAILY_VISION_CAP`, `DAILY_SPEND_CEILING_USD`, `VISION_COST_USD`,
`CACHE_TTL_DAYS`, `VISION_MODEL`.

## Rough economics
Assume ~$0.003 effective cost/scan after OCR deflection.

| Users | Scans/mo (~6 ea) | Vision calls (~40%) | Vision cost/mo | ≈ % of sub revenue |
|---|---|---|---|---|
| 10k | 60k | 24k | ~$70 | ~10% |
| 100k | 600k | 240k | ~$720 | ~11% |
| 1M | 6M | 2.4M | ~$7.2k | ~11% |

Cost scales *with* revenue (heavy scanners are Pro), and the embedding migration flattens the
per-scan cost toward zero for common cards.

## The scale migration (step 4)
When vision spend or latency warrants it:
1. **Build the index:** for each catalog card, store an image embedding (from a vision encoder)
   in a vector column (`pgvector` on Supabase, or a dedicated vector DB).
2. **Match:** embed the scan photo once, nearest-neighbor against the index, return top-N.
   This replaces most step-3 LLM calls with a cheap vector query on our own infra.
3. **LLM as fallback:** only when embedding confidence is low (new sets, weird angles) do we
   call the model — and that result feeds back into the index.
4. **On-device (step 5):** distill the common-case matcher into a Core ML model for offline,
   zero-cost identification; keep the cloud for the long tail.

Net: the LLM is the bootstrap that makes recognition work on day one with zero training, and a
shrinking fraction of traffic as the index and on-device model take over the common path.
