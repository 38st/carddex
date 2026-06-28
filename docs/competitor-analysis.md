# Carddex — Competitor Analysis & Feature Ideas

*Product Manager pass — June 2026. Based on App Store listings, competitor websites, and industry reviews.*

---

## 1. Competitive Landscape

The trading-card collection app market is **crowded and accelerating**. There are at least 12 active competitors ranging from solo indie apps to VC-backed platforms with millions of users. The market split is roughly:

- **All-in-one scanners** (Ludex, Shiny, BankTCG) — scan + value + track, broad game coverage
- **Investor-grade portfolio tools** (Collectr, PullPortfolio, Card Atlas) — financial analytics, P&L, predictions
- **Marketplace-first** (TCGplayer) — collection tracking as a secondary feature to buying/selling
- **Grading-focused** (BinderAI, CardSense AI) — AI pre-grading as the wedge feature
- **Vendor/dealer tools** (VendBro) — built for buying/selling at shows and shops
- **Pokemon-only single-game** (Cardex, CardDex variants) — narrow but fast

### Direct Competitors (multi-game + scan + portfolio)

| App | Games | Users | Scanning | Grading | Pricing | Key Differentiator |
|---|---|---|---|---|---|---|
| **Ludex** | Sports + Pokémon + MTG | 3M+ | AI, unlimited free | No | Free + paid tiers | List-It eBay feature, hobby trends |
| **Shiny** | Pokémon + MTG + One Piece | 500K+ | AI, "most accurate" | No | Free + paid | 4.9★ rating, unlimited collections |
| **BankTCG** | Pokémon + MTG + YGO + One Piece | — | AI, 127K+ cards | Pre-grade 94% | 5 free/mo, paid unlimited | AI grading + binder scan + offline |
| **Card Atlas** | 22 TCGs + 9 sports | — | Scan + CSV import | Graded tracker | Free / $7.99 / $14.99 | Broadest game coverage, community |
| **Collectr** | 25+ TCGs | — | Scan | No | Free + Pro | Trade analyzer, search by artist |
| **PullPortfolio** | Pokémon + Sports + MTG + YGO + One Piece | — | AI scan | Grade probability | Free / Collector / Investor $24.99 | AI chat agent, predictions, arbitrage |

### Niche / Adjacent Competitors

| App | Focus | Notable Feature |
|---|---|---|
| **BinderAI** | AI grading | 87% PSA accuracy, sub-grades for centering/corners/edges/surface |
| **CardSense AI** | AI grading | Confidence scores, "should I grade or sell raw?" recommendation |
| **VendBro** | Vendors/dealers | Trade mode, vendor station (desktop), Japanese card support, session naming |
| **TCGplayer** | Marketplace | Free, tied to their marketplace sales data |
| **CollX** | Sports cards | 2025 Mantel Hobby Awards Innovation winner |
| **Cardex** | Pokémon only | Weekly $6.99-9.99, lifetime $79.99-99.99 |
| **CardDex (various)** | Pokémon only | **Name conflict** — multiple apps using "CardDex" on App Store |

---

## 2. Feature Matrix — Carddex vs. Every Competitor

### Legend
- ✅ = Has it, fully functional
- 🟡 = Partial / scaffold / stub
- 🔲 = Does not have it
- ⭐ = Best-in-class implementation

### 2A. Core Features (Scan + Identify + Collection)

| Feature | Carddex | Ludex | Shiny | BankTCG | Card Atlas | Collectr | PullPortfolio | TCGplayer | VendBro | BinderAI |
|---|---|---|---|---|---|---|---|---|---|---|
| Camera scan + identify | ✅ OCR-first + cloud vision | ✅ AI | ✅ AI | ✅ AI 127K cards | ✅ | ✅ | ✅ AI | ✅ | ✅ AI 400-700ms | ✅ |
| Photo picker scan | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Bulk scan (multi-photo) | ✅ 12 photos | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ batch | ✅ | ✅ | ✅ |
| Binder page scan (one photo, multi-card) | 🔲 | 🔲 | ✅ | ✅ | 🔲 | 🔲 | 🔲 | 🔲 | ✅ | 🔲 |
| Offline scanning | 🟡 OCR on-device, catalog needs cloud | 🔲 | 🔲 | ✅ | 🔲 | 🔲 | 🔲 | 🔲 | ✅ local DB | 🔲 |
| Multi-game support | ✅ 4 games | ✅ 7+ | ✅ 3 | ✅ 5 | ✅ 22 TCG + 9 sports | ✅ 25+ | ✅ 5+ | ✅ all TCG | ✅ 2 (Pokémon + MTG) | ✅ sports + TCG |
| Sports cards | ✅ | ✅ | 🔲 | 🔲 | ✅ | 🔲 | ✅ | 🔲 | 🔲 | ✅ |
| Japanese card support | 🔲 | 🔲 | 🔲 | 🔲 | ✅ | ✅ | 🔲 | 🔲 | ✅ 30K+ JP | 🔲 |
| Set completion tracking | ✅ binder page + missing list + % | ✅ | ✅ | 🔲 | ✅ | ✅ | 🔲 | 🔲 | ✅ | 🔲 |
| Grail list / wishlist | ✅ with target price tracking | 🔲 | 🔲 | 🔲 | ✅ wishlist | 🔲 | 🔲 | 🔲 | ✅ want lists | 🔲 |
| Collection search + filter | ✅ by game, sport, name, set, number | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Collection sort | ✅ multiple options | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Graded card tracking | 🟡 condition field, no cert lookup | ✅ | ✅ raw + graded | ✅ | ✅ cert lookup | ✅ | ✅ PSA/BGS/CGC/SGC | ✅ | ✅ | ✅ |
| Sealed product tracking | 🔲 | 🔲 | 🔲 | 🔲 | ✅ | ✅ | ✅ | ✅ | 🔲 | 🔲 |
| CSV import | 🔲 | 🔲 | 🔲 | 🔲 | ✅ | ✅ | ✅ | ✅ | ✅ | 🔲 |
| CSV export | 🔲 | 🔲 | 🔲 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 🔲 |

### 2B. Market + Pricing Features

| Feature | Carddex | Ludex | Shiny | BankTCG | Card Atlas | Collectr | PullPortfolio | TCGplayer | VendBro | BinderAI |
|---|---|---|---|---|---|---|---|---|---|---|
| Live market prices | 🟡 sample data, infra ready | ✅ eBay sold | ✅ | ✅ TCGplayer + eBay | ✅ multi-source | ✅ | ✅ eBay comps | ✅ TCGplayer | ✅ TCGplayer + eBay | ✅ |
| Price history charts | 🟡 infra exists, limited display | ✅ | ✅ 1yr | ✅ | ✅ | ✅ | ✅ 24h/7d/30d | ✅ | ✅ trends | ✅ 30/90/365d |
| Market index | ✅ overall + per-category | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | ✅ | 🔲 | 🔲 | 🔲 |
| Movers (gainers/losers) | ✅ | 🔲 | 🔲 | 🔲 | 🔲 | ✅ | ✅ daily movers | ✅ hot cards | 🔲 | 🔲 |
| Price alerts | ✅ target price alerts | ✅ | ✅ | ✅ | ✅ Plus tier | 🔲 | ✅ spike alerts | 🔲 | ✅ | 🔲 |
| Card comparison | ✅ up to 3 cards, 30d trend | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | ✅ comp sets | 🔲 | 🔲 | 🔲 |
| Snipe alerts (underpriced eBay) | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | ✅ | 🔲 | 🔲 | 🔲 |
| Arbitrage finder | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | ✅ | 🔲 | 🔲 | 🔲 |
| Hobby trends / hot cards | 🔲 | ✅ hourly | 🔲 | 🔲 | 🔲 | 🔲 | ✅ | ✅ | 🔲 | 🔲 |
| AI price predictions | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | ✅ 7d/30d/90d | 🔲 | 🔲 | 🔲 |

### 2C. Portfolio + Analytics

| Feature | Carddex | Ludex | Shiny | BankTCG | Card Atlas | Collectr | PullPortfolio | TCGplayer | VendBro | BinderAI |
|---|---|---|---|---|---|---|---|---|---|---|
| Portfolio total value | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| P&L / gain-loss tracking | ✅ cost basis + ROI | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 🔲 |
| Portfolio value history | ✅ daily snapshots + chart | ✅ | ✅ 1yr | ✅ | ✅ | ✅ | ✅ | ✅ | 🔲 | 🔲 |
| Attribution by game | ✅ | 🔲 | 🔲 | 🔲 | ✅ | ✅ | ✅ allocation | 🔲 | 🔲 | 🔲 |
| Top movers in portfolio | ✅ | 🔲 | 🔲 | ✅ | 🔲 | ✅ | ✅ top performers | 🔲 | 🔲 | 🔲 |
| Box EV calculator | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | ✅ | 🔲 | 🔲 | 🔲 |
| Pull odds calculator | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | ✅ | 🔲 | 🔲 | 🔲 |
| PSA profit calculator | 🔲 | 🔲 | 🔲 | ✅ | 🔲 | 🔲 | ✅ net profit | 🔲 | 🔲 | 🔲 |

### 2D. AI Grading Features

| Feature | Carddex | Ludex | Shiny | BankTCG | Card Atlas | Collectr | PullPortfolio | TCGplayer | VendBro | BinderAI | CardSense |
|---|---|---|---|---|---|---|---|---|---|---|---|
| AI pre-grading | 🔲 | 🔲 | 🔲 | ✅ 94% accuracy | 🔲 | 🔲 | ✅ grade probability | 🔲 | 🔲 | ✅ 87% PSA accuracy | ✅ sub-grades |
| Centering analysis | 🔲 | 🔲 | 🔲 | ✅ | 🔲 | 🔲 | ✅ | 🔲 | 🔲 | ✅ | ✅ |
| Corner/edge/surface analysis | 🔲 | 🔲 | 🔲 | ✅ | 🔲 | 🔲 | ✅ | 🔲 | 🔲 | ✅ | ✅ |
| "Should I grade?" recommendation | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | ✅ | 🔲 | 🔲 | 🔲 | ✅ |
| Confidence score | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | ✅ | 🔲 | 🔲 | 🔲 | ✅ |

### 2E. Selling + Marketplace

| Feature | Carddex | Ludex | Shiny | BankTCG | Card Atlas | Collectr | PullPortfolio | TCGplayer | VendBro | BinderAI |
|---|---|---|---|---|---|---|---|---|---|---|
| eBay listing composer | 🟡 UI done, API stub | ✅ List-It | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | ✅ marketplace | ✅ quick-sell | 🔲 |
| Fee calculator | ✅ eBay 13.25% + $1 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | ✅ net profit | ✅ | 🔲 | 🔲 |
| eBay sold comps link | ✅ affiliate link | 🔲 | 🔲 | ✅ | 🔲 | 🔲 | ✅ | ✅ | ✅ | 🔲 |
| eBay OAuth connection | 🔲 stub | ✅ | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | ✅ native | 🔲 | 🔲 |
| Trade mode / analyzer | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | ✅ trade analyzer | 🔲 | 🔲 | ✅ two-sided | 🔲 |
| Buy on platform | 🔲 | ✅ | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | ✅ | ✅ | 🔲 |
| Chrome extension | 🔲 | 🔲 | 🔲 | ✅ | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 |

### 2F. Social + Community

| Feature | Carddex | Ludex | Shiny | BankTCG | Card Atlas | Collectr | PullPortfolio | TCGplayer | VendBro | BinderAI |
|---|---|---|---|---|---|---|---|---|---|---|
| Public profile / collection sharing | 🔲 | 🔲 | 🔲 | 🔲 | ✅ | 🔲 | ✅ | 🔲 | 🔲 | 🔲 |
| Share collection image | ✅ branded poster | 🔲 | 🔲 | 🔲 | ✅ | 🔲 | ✅ share pulls | 🔲 | 🔲 | 🔲 |
| Community feed | 🔲 | 🔲 | 🔲 | 🔲 | ✅ feed + badges | 🔲 | ✅ community feed | 🔲 | 🔲 | 🔲 |
| Leaderboards | 🔲 | 🔲 | 🔲 | 🔲 | ✅ badges | 🔲 | ✅ | 🔲 | 🔲 | 🔲 |
| Events calendar | 🔲 | 🔲 | 🔲 | ✅ trade shows | 🔲 | 🔲 | ✅ conventions | 🔲 | 🔲 | 🔲 |
| Discord community | 🔲 | ✅ | ✅ | 🔲 | 🔲 | ✅ | 🔲 | ✅ | 🔲 | 🔲 |
| AI chat agent | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | ✅ | 🔲 | 🔲 | 🔲 |

### 2G. Platform + Technical

| Feature | Carddex | Ludex | Shiny | BankTCG | Card Atlas | Collectr | PullPortfolio | TCGplayer | VendBro | BinderAI |
|---|---|---|---|---|---|---|---|---|---|---|
| Cross-device sync | ✅ SwiftData + PostgREST | ✅ | ✅ | ✅ cloud sync | ✅ | ✅ | ✅ | ✅ | 🔲 | 🔲 |
| Widgets | ✅ WidgetKit | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 |
| Siri / App Intents | ✅ | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 |
| Spotlight indexing | ✅ | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 |
| Sign in with Apple | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 🔲 | 🔲 |
| Account deletion | ✅ full flow | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 🔲 | 🔲 |
| StoreKit 2 IAP | ✅ real | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | free | ✅ | ✅ |
| Dark mode / premium design | ⭐ vault aesthetic | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Haptic feedback | ✅ | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 |
| Flip card view (front/back) | ✅ gyroscope tilt | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 |
| Onboarding flow | ✅ 3-page vault | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 🔲 | ✅ |
| Android app | 🔲 | ✅ | 🔲 | 🔲 | 🔲 | ✅ | 🔲 | ✅ | 🔲 | 🔲 |
| Web app | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 | ✅ | ✅ vendor station | 🔲 |
| No SPM dependencies | ⭐ zero deps | — | — | — | — | — | — | — | — | — |

---

### 2H. Summary Scorecard

| Category | Carddex | Ludex | Shiny | BankTCG | Card Atlas | Collectr | PullPortfolio |
|---|---|---|---|---|---|---|---|
| Scan + identify | 7/10 | 8/10 | 7/10 | 9/10 | 6/10 | 6/10 | 8/10 |
| Collection mgmt | 7/10 | 7/10 | 7/10 | 6/10 | 9/10 | 8/10 | 6/10 |
| Market + pricing | 6/10 | 7/10 | 7/10 | 8/10 | 7/10 | 7/10 | 9/10 |
| Portfolio analytics | 7/10 | 6/10 | 7/10 | 6/10 | 7/10 | 7/10 | 9/10 |
| AI grading | 0/10 | 0/10 | 0/10 | 8/10 | 0/10 | 0/10 | 5/10 |
| Selling | 4/10 | 8/10 | 0/10 | 0/10 | 0/10 | 0/10 | 3/10 |
| Social | 2/10 | 2/10 | 1/10 | 2/10 | 7/10 | 1/10 | 7/10 |
| Platform/tech | 9/10 | 6/10 | 6/10 | 5/10 | 6/10 | 6/10 | 5/10 |
| **Total** | **42/80** | **44/80** | **35/80** | **44/80** | **42/80** | **35/80** | **52/80** |

---

## 3. Feature Gaps — What Carddex is Missing

### Tier 1 — High impact, differentiating, feasible

| # | Feature | Who has it | Effort | Why it matters |
|---|---|---|---|---|
| 1 | **AI pre-grading** (centering, corners, edges, surface → grade estimate) | BankTCG, BinderAI, CardSense, PullPortfolio | High | "Should I grade this card?" is the #1 question collectors ask. Saves $25/card in grading fees. Massive user acquisition hook. |
| 2 | **Trade mode / trade analyzer** (scan both sides, running totals, fairness check) | Collectr, VendBro | Medium | Every collector trades. A built-in trade tool keeps users in the app during trades instead of switching to a calculator. |
| 3 | **Binder page scan** (photograph 9-card page → identify all at once) | BankTCG, Shiny, VendBro | Medium | We have bulk scan (one at a time, multi-photo). True multi-card detection in a single photo is a major speed win at shows/shops. |
| 4 | **CSV import/export** | Card Atlas, VendBro, Collectr, PullPortfolio | Low | Onboarding friction killer — let users import from other apps. Also enables dealer workflows. 5/8 competitors have this. |
| 5 | **Graded card cert lookup** (enter PSA/BGS/CGC cert # → auto-populate grade) | Card Atlas, Collectr, PullPortfolio | Medium | Collectors with graded cards want to link their slabs. We have a condition field but no cert verification. |

### Tier 2 — Medium impact, builds moat

| # | Feature | Who has it | Effort | Why it matters |
|---|---|---|---|---|
| 6 | **"Should I grade or sell raw?" recommendation** | CardSense, PullPortfolio | Medium | Natural extension of pre-grading. Combines grade estimate + market price delta (raw vs PSA 9 vs PSA 10) into a actionable recommendation. |
| 7 | **PSA profit calculator** (card cost + grading fee + pop rate → projected ROI) | BankTCG, PullPortfolio | Low | Simple math tool but huge value. Collectors share these calculations constantly on social media. |
| 8 | **Price history charts** (1yr+ daily price history per card) | Sparkl, PullPortfolio, Collectr, BinderAI | Medium | We have price snapshots infrastructure but limited history display. Longer history = more informed decisions + more time in app. |
| 9 | **Sealed product tracking** (boxes, packs, ETBs) | Card Atlas, Collectr, PullPortfolio, TCGplayer | Medium | Many collectors hold sealed product as investments. Expands the catalog beyond singles. |
| 10 | **Offline scanning mode** (on-device catalog cache) | BankTCG, VendBro | Medium | Critical for card shows, shops, conventions where connectivity is poor. OCR-first path already works; needs on-device catalog cache. |

### Tier 3 — Growth / engagement features

| # | Feature | Who has it | Effort | Why it matters |
|---|---|---|---|---|
| 11 | **Community feed + public profiles** | Card Atlas, PullPortfolio | High | Social features drive retention. Card Atlas has achievement badges + feed. PullPortfolio has leaderboards + share pulls. |
| 12 | **Hobby trends / hot cards** (trending by sales volume) | Ludex, PullPortfolio, TCGplayer | Medium | Discovery feature — "what's hot right now." Drives browsing + market engagement. |
| 13 | **Events calendar** (conventions, card shows, tournaments) | PullPortfolio, BankTCG | Low-Medium | Community touchpoint. Keeps app relevant between collection sessions. |
| 14 | **Box EV / pull odds calculator** | PullPortfolio | Medium | "Should I open this box or sell it sealed?" — viral content on YouTube/TikTok. |
| 15 | **Arbitrage finder** (cross-platform price differences) | PullPortfolio | High | Niche but sticky for power users. Requires multiple data sources. |
| 16 | **Snipe alerts** (underpriced eBay listings) | PullPortfolio | Medium | Real-time eBay monitoring for deals. Requires eBay Browse API (not gated like Marketplace Insights). |

### Tier 4 — Nice to have

| # | Feature | Who has it | Effort | Why it matters |
|---|---|---|---|---|
| 17 | **Japanese card support** | Card Atlas, Collectr, VendBro | Medium | Significant market segment, especially for Pokémon. |
| 18 | **Artist tags / error card flags** | VendBro | Low | Deep catalog metadata that serious collectors care about. |
| 19 | **Chrome extension** (eBay pricing overlay) | BankTCG | Medium | Extends brand beyond mobile. |
| 20 | **AI chat agent** (ask about card values, grading advice) | PullPortfolio | High | Trendy but expensive to run. Low priority until user base justifies it. |
| 21 | **Android app** | Ludex, Collectr, TCGplayer | High | Expands addressable market. Not urgent — iOS-first is fine for launch. |

---

## 4. Blue Ocean — Features Nobody Has

These are features that **no competitor in our analysis currently offers**. Building any of these creates a category-of-one.

| # | Feature | What it does | Why nobody has it | Effort | Opportunity |
|---|---|---|---|---|---|
| 1 | **Collection insurance valuation report** | Generate a PDF report of your collection's total value, itemized with grades + market prices, formatted for insurance underwriters. | Insurance is unsexy; apps focus on the collector, not the bureaucracy. | Low-Medium | **High**. Collectors with $10K+ collections need insurance. This is a "must have" tool that drives Pro subscriptions. Unique selling point: "The only app that generates an insurance-ready valuation report." |
| 2 | **Portfolio rebalancing suggestions** | "Your Pokémon allocation is 80% of your portfolio — consider diversifying into MTG." Like a robo-advisor for cards. | Requires portfolio analytics + multi-game support, which most apps don't combine well. | Medium | **Medium-High**. Positions Carddex as the "serious investor" app. PullPortfolio has AI predictions but no rebalancing. |
| 3 | **Grading submission tracker** | Track which cards you've sent to PSA/BGS/CGC, submission status (received → in grading → shipped → slabbed), expected return date, and auto-update collection when the slab arrives. | Nobody treats grading as a workflow. It's a black box — you send cards and wait. | Medium | **High**. Every serious collector sends cards for grading. The anxiety of "where are my cards?" is universal. Push notifications when status changes = daily app engagement. |
| 4 | **Card show mode** | A special UI for buying at card shows: quick-scan → buy price vs market price → instant margin display → session totals → CSV export. Like VendBro's vendor station but for the buyer side. | VendBro is vendor-focused. Nobody has built a buyer's companion for shows. | Medium | **High**. Card shows are where impulse purchases happen. Real-time "is this a good deal?" scanning is a killer use case. |
| 5 | **Collection depreciation alerts** | "Your Charizard dropped 15% this week — consider selling." Inverse of price alerts, but portfolio-level instead of per-card. | Most apps have per-card alerts but nobody aggregates to portfolio-level risk. | Low | **Medium**. Keeps users engaged even when they're not actively collecting. Fear of loss > hope of gain (loss aversion). |
| 6 | **Card condition timeline** | Photograph your raw cards periodically. The app tracks visual changes (corner dings, surface scratches) over time and alerts you if a card's condition is degrading. | Requires persistent photo storage + image comparison AI. Nobody has thought of cards as things that *change* over time. | High | **Medium**. Niche but sticky. Collectors with expensive raw cards would pay for this peace of mind. |
| 7 | **Estate / succession planning** | Designate a beneficiary who inherits your digital collection + valuation if something happens to you. Generates a legal-adjacent document. | Nobody in the hobby has thought about what happens to a digital collection when the owner dies. | Low-Medium | **Low-Medium**. Niche but generates press coverage and trust. "The app that cares about your legacy." |
| 8 | **Tax lot tracking** | Track each card purchase as a tax lot (date, cost basis, quantity). When you sell, calculate realized gains/losses using FIFO/LIFO/specific identification. Export as Schedule D-compatible CSV. | Apps track P&L but nobody treats cards as actual capital assets for tax purposes. | Medium | **Medium-High**. IRS treats collectibles as capital assets (28% rate). Serious collectors need this. Unique Pro feature. |
| 9 | **Smart bundle suggestions** | "You own 8/10 cards from Base Set — the 2 missing cards cost $340 total. Buy them both from this seller for $290." | Requires catalog + market data + set completion + marketplace integration. Nobody connects these dots. | High | **Medium**. Long-term play. Needs marketplace integration first. |
| 10 | **Collection health score** | A single metric (0-100) that combines diversification, liquidity, condition distribution, and trend momentum into a "how healthy is your portfolio?" score. Like a credit score for your collection. | Requires holistic analytics that most apps don't have. Nobody has tried to distill collection quality into one number. | Medium | **High**. Gamification + analytics in one. Shareable. "My collection health score is 87 — what's yours?" Viral loop. |

---

## 5. Strategic Positioning for Carddex

### Current positioning tension

There are **multiple apps named "CardDex"** on the App Store (at least 3 different developers). The display name "The Case" is a smart differentiator — **lead with "The Case" in all marketing and ASO**, not "Carddex."

### Recommended positioning

**"The Case" — The collector's vault. Scan, grade, and manage your trading card portfolio with bank-grade precision.**

Carddex's unique assets to lean into:
- **Vault aesthetic** — no competitor has this level of design polish. Most look like spreadsheets.
- **Cost-optimized AI** — OCR-first means faster scans and lower operating costs than competitors who send every photo to a vision model.
- **Widgets + Siri** — almost no competitor has these. iOS power users notice.
- **Grail list** — unique feature, emotional hook for collectors chasing dream cards.
- **Set completion → grail loop** — the binder page + missing cards + grail list flow is unique to Carddex.

### Where to differentiate vs. where to match

| Dimension | Strategy |
|---|---|
| **Scanning speed/accuracy** | Match competitors (OCR-first is already good) |
| **Game coverage** | Match (4 games is competitive; add One Piece + Lorcana next) |
| **Design/UX** | **Win** — vault aesthetic is a moat |
| **Grading** | **Win** — AI pre-grading is the #1 missing feature and highest-impact differentiator |
| **Social/community** | Match later (Phase 4+) — don't spread thin early |
| **Dealer/vendor tools** | Skip for now — VendBro owns this niche |
| **Marketplace** | Skip — TCGplayer owns this; eBay listing is enough |
| **Blue ocean features** | **Win** — insurance reports, grading tracker, collection health score, tax lot tracking. Nobody has these. |

---

## 6. Recommended Feature Roadmap (Prioritized)

### Immediate (can build now, no external dependencies)

1. **CSV import/export** — Low effort, removes onboarding friction. Import from Collectr/TCGplayer/Card Atlas exports. 5/8 competitors have this; we're behind.
2. **PSA profit calculator** — Low effort, high shareability. Simple tool: card cost + PSA tier fee + estimated grade → ROI.
3. **Collection insurance valuation report** — Low-Medium effort, blue ocean. PDF export of itemized collection value for insurance. Unique Pro feature.
4. **Collection health score** — Medium effort, blue ocean. Single 0-100 metric combining diversification, liquidity, trends. Shareable viral loop.
5. **Collection depreciation alerts** — Low effort, blue ocean. Portfolio-level risk alerts. Keeps users engaged passively.

### Next quarter (requires moderate engineering)

6. **AI pre-grading** — Highest-impact feature gap. Use on-device Vision for centering analysis + cloud model for surface/corner/edge assessment. Output: estimated grade + sub-grades + confidence score.
7. **"Should I grade or sell raw?" recommendation** — Natural follow-on from #6. Combines grade estimate + raw price vs. graded price delta.
8. **Binder page scan (true multi-card)** — Upgrade BulkScanView to detect and identify multiple cards in a single photo.
9. **Trade mode** — Two-sided scanner with running values + fairness indicator.
10. **Grading submission tracker** — Blue ocean. Track PSA/BGS/CGC submissions with status updates + push notifications.
11. **Card show mode** — Blue ocean. Buyer's companion for card shows: quick-scan → margin display → session totals.

### Phase 3+ (post-launch, growth-focused)

12. **Price history charts** (extend existing infrastructure)
13. **Sealed product tracking**
14. **Offline scanning mode** (on-device catalog cache)
15. **Tax lot tracking** — Blue ocean. FIFO/LIFO/specific ID, Schedule D CSV export.
16. **Portfolio rebalancing suggestions** — Blue ocean. Robo-advisor for cards.
17. **Hobby trends / hot cards**
18. **Community feed + public profiles**
19. **Box EV / pull odds calculator**
20. **Graded card cert lookup**

---

## 7. Monetization Comparison

| App | Free Tier | Mid Tier | Pro Tier |
|---|---|---|---|
| **Carddex (us)** | 25 scans/mo | — | $6.99/mo or $39.99/yr |
| Ludex | Unlimited scans | — | Paid for listing features |
| Shiny | Basic | — | Paid for unlimited |
| BankTCG | 5 scans/mo | — | Paid unlimited |
| Card Atlas | Unlimited tracking | $7.99/mo | $14.99/mo (API access) |
| Collectr | Basic | — | Pro subscription |
| PullPortfolio | Core tracking | Collector | Investor $24.99/mo |
| Cardex (Pokemon-only) | — | Weekly $6.99 | Lifetime $99.99 |

### Recommendations

- **25 free scans/mo is competitive** — BankTCG only gives 5, but Ludex gives unlimited. Keep 25.
- **$6.99/mo is well-positioned** — below PullPortfolio ($24.99) and Card Atlas Pro ($14.99).
- **Add a lifetime tier** — Cardex charges $79.99-99.99 lifetime. Collectors hate subscriptions. A $79.99 lifetime tier could capture price-sensitive users who'd otherwise churn.
- **Gate blue ocean features behind Pro** — Insurance reports, tax lot tracking, collection health score, grading submission tracker. These are uniquely valuable and justify the subscription.
- **Consider a "Dealer" tier** — if we ever add vendor tools, $14.99-19.99/mo for bulk scan + CSV export + trade mode + card show mode.

---

## 8. Naming Conflict Alert

There are **at least 3 other apps named "CardDex"** on the App Store right now:
- "CardDex – TCG Card Scanner" (separate developer, Pokemon-only)
- "CardDex: TCG Portfolio" (SD Techno, portfolio tracker)
- "CardDex: TCG Scanner & Price" (UK developer, Pokemon-only)

**Recommendation:** Lead with **"The Case"** as the primary brand name in all App Store metadata, screenshots, and marketing. The bundle ID `com.carddex.app` can stay, but the App Store title should be "The Case — Card Scanner & Portfolio" or similar. This avoids ASO collision and builds a distinct brand.
