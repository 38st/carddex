# Carddex — Product Strategy Plan

*Author: Product Designer. Grounded in the Phase 0 repo.*

## 1. Target users & jobs-to-be-done

The wedge customer is the value-aware modern collector. Three personas, in priority order:

- **Persona A — "Marcus, the Returning Nostalgic" (PRIMARY, the launch wedge).** 32, opened a
  box of childhood Pokémon/Yu-Gi-Oh! in his parents' attic. JTBD: *"I have a shoebox of old
  cards — tell me what I have and whether any of it is worth something, without typing card
  names."* Ideal first-scan customer: low knowledge, high curiosity, instant payoff. Highest
  App Store search volume ("scan pokemon card value"). Build the magic moment for Marcus.
- **Persona B — "Priya, the Active Flipper/Reseller" (MONETIZATION).** 26, buys collections at
  estate sales, flips singles on eBay. JTBD: *"Intake a pile fast, see liquidation value, list
  the winners with minimal typing."* Pays $50–80/yr to save hours. The reason eBay listing and
  bulk scan exist. Highest willingness-to-pay and retention.
- **Persona C — "Dana, the Completionist" (RETENTION).** 40, hardcore Pokémon set collector.
  JTBD: *"Show me which cards I'm missing and what my collection is worth."* Lives for the
  set-completion progress bar. The long-tail retention engine.

Decision: optimize v1.0 acquisition for Marcus, monetization for Priya, retention for Dana.
Day-one marketing leads with Pokémon.

## 2. Competitive landscape

| Competitor | Wins | Our opening |
|---|---|---|
| Collectr | Polished multi-game portfolio, social feed, charts | Scan/intake clunky; mostly manual search; sell not native |
| TCGplayer app | Authoritative pricing, real marketplace | It's a store, not a collection manager; scan/portfolio afterthoughts |
| Ludex | Strong AI scanner incl. sports | Utilitarian UX; thin portfolio/value/sell loop |
| Dragon Shield app | Beloved by MTG for volume scanning | MTG-centric, deck-builder DNA; weak for nostalgic crowd |
| eBay | The liquidity | Terrible at identifying/organizing; single-card listing is high friction |

Differentiation/wedge: the only app that nails the full physical-card loop end to end with
scan-first intake as the front door. "Point your camera at any card and it becomes a tracked,
sellable asset in 3 seconds." The "Pokédex" framing (set completion) is the emotional moat.

## 3. v1.0 MVP scope (MoSCoW)

Smallest lovable product: *"I photographed a real card, it correctly told me what it is and what
it's worth, and saved it to a beautiful collection."*

- MUST: real camera + on-device OCR → cloud vision → catalog-grounding (Pokémon-first; MTG/YGO
  beta); identify-result confirmation + "search instead" fallback; save with quantity + condition;
  collection grid with filter; real market price + portfolio total; Sign in with Apple + Supabase
  sync; manual search-to-add fallback.
- SHOULD: Pokémon set-completion progress; basic value-history sparkline.
- COULD (defer v1.1): bulk/continuous scan; price-movement alerts; CSV export.
- WON'T (out of v1.0): **eBay auto-listing (ship v1.2)**; sports cards; social feed; Android/web.

Rationale: the riskiest, most differentiating thing is identification accuracy. A flawless
scan→value loop with no eBay beats a mediocre everything-app.

## 4. User journeys

TTFV (time-to-first-value) is the whole game: app open → "this card is worth $X" in < 60s, before
any account.

- Onboarding: 2–3 value-prop screens → camera permission prime → land on Scan. No forced sign-up.
- First scan → save: live viewfinder → OCR "reading…" → result sheet with image + name + set +
  price → "Add to collection" → celebration → soft account prompt.
- Building a collection: repeat; grid fills; set-completion bars appear.
- Portfolio: total value + by-game; v1.0 adds real prices; SHOULD-add 30-day sparkline.
- (v1.2) eBay: card detail → connect eBay (OAuth) → pre-filled listing → confirm → track status.

## 5. Activation & onboarding
Permission priming (never cold-fire the camera prompt). Magic moment = first identify-with-price.
Defer the account wall until after the first save. Empty states everywhere. Manual fallback is
part of activation — never fail silently.

## 6. Monetization — "Carddex Pro"

| Capability | Free | Pro |
|---|---|---|
| Scans / month | 15 | Unlimited |
| Collection size | Unlimited | Unlimited |
| Current market price | Yes | Yes |
| Price history & charts | — | Yes |
| Portfolio analytics (gain/loss, cost basis, movers) | — | Yes |
| Set-completion tracking | 1 set | Unlimited |
| Bulk / continuous scan | — | Yes |
| Price-movement alerts | — | Yes |
| eBay auto-list (v1.2) | — | Yes |
| CSV / export | — | Yes |

Price: $6.99/mo or $39.99/yr (push annual; 7-day trial). Lifetime $79.99 later. Lead paywall
messaging with "track your collection's value over time," not "more scans." Never gate collection
size or basic current price.

## 7. Retention & engagement
Set completion (the #1 mechanic + product metaphor); portfolio value as a living number (daily
refresh); price-movement alerts (push, Pro); light scan streaks; one-tap share cards; weekly
"your portfolio moved $X" push.

## 8. Success metrics
North Star: weekly active collectors who scanned ≥1 card. Funnel: install → camera granted →
first identify-with-price → first save → account created. Core: scan success rate, scans/WAU,
TTFV. Retention: D1/D7/D30, % reaching 5+ cards. Monetization: free→trial→paid, paywall→subscribe,
MRR/ARPU. Guardrail: mis-ID rate + manual-fallback usage (drives rating).

## 9. App Store positioning
Name: "Carddex — Scan & Track Cards". Subtitle: "Identify, value & collect your TCG cards".
Category: Lifestyle (Collecting), secondary Utilities. Keywords: pokemon card scanner, card value,
tcg collection tracker, magic gathering, yugioh, card price, collection manager, portfolio.
5-screenshot story: scan → result/price → collection grid → set completion → portfolio value.

## 10. Risks & de-risking
Identification accuracy (Pokémon-first, high threshold, manual fallback, real-photo test set);
eBay dependency (cut from v1.0); pricing ToS/rate limits (cache + attribute + "est."); free/paid
balance (launch 15 scans, instrument, A/B); multi-game dilution (lead Pokémon, label beta);
no paid dev account (start now); subscription review (real free value).

## 11. Roadmap
- v1.0 Launch: identification (Pokémon-first), confirm+save, manual fallback, grid, real price +
  portfolio, Sign in with Apple + sync, Pro paywall, set-completion (SHOULD), sparkline (SHOULD).
- v1.1 Engagement: bulk scan, price alerts, history charts, all-game completion, share, export.
- v1.2 Sell: eBay connect, auto-listings, one-tap list/relist, status tracking, sold comps.
- v2.0 Breadth: sports, condition/grading assist, social profiles, variant matching, wishlists.

## Top 5 product decisions
1. Cut eBay listing from v1.0 — ship the scan→value→collect loop first; sell in v1.2.
2. Lead with Pokémon and the returning-nostalgic persona; MTG/YGO as labeled beta.
3. Defer the account wall until after the first save; never gate the magic moment.
4. Freemium at $6.99/mo / $39.99/yr — gate scan volume + depth, never collection size or basic price.
5. Set-completion is the retention engine — prioritize as a v1.0 SHOULD.
