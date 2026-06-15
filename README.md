# Carddex

A Pokédex for trading-card collectors. Scan a card, identify it automatically, save it
to your collection, track its value, and (later) list it on eBay.

Supports multiple card games from day one — Pokémon, Magic: The Gathering, and Yu-Gi-Oh!
lead (great free catalog APIs); sports cards are staged in.

## Stack

- **App:** native SwiftUI (iOS 18+), Swift 6
- **Backend:** Supabase (Postgres + Auth + Storage + Edge Functions) — see `supabase/`
- **Identification:** on-device Vision pre-pass → cloud vision model → catalog grounding

## Getting started

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen      # one time
xcodegen generate          # regenerates Carddex.xcodeproj after changing project.yml
open Carddex.xcodeproj
```

Then pick an iPhone simulator and run. No Apple Developer account needed for the simulator.

## Roadmap

- **Phase 0 — Foundations:** project, design system, models, app shell ✅ (in progress)
- **Phase 1 — Core loop:** camera capture → identify → confirm → save → browse
- **Phase 2 — Pricing & portfolio:** live prices, daily refresh, value history
- **Phase 3 — eBay:** connect account, auto-list cards
- **Phase 4 — Accuracy & breadth:** variant matching, sports cards, condition assist
