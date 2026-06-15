# Carddex — Visual & Interaction Design Spec ("The Vault")

*Author: Visual/UI Designer.*

## 1. Art-direction north star
"The Vault." Carddex is a glass display case in a dark, climate-controlled vault — cards float on
near-black graphite under soft museum lighting; rare cards earn a living holographic foil that
reacts to tilt. The chrome is quiet, premium, and gets out of the way; the cards are the only
thing that glows. Three pillars: dark-first museum lighting; foil is the hero interaction;
tactile, weighted chrome (glass, hairlines, spring physics). NOT: default indigo-on-white,
neon/cyberpunk, skeuomorphic wood binder.

## 2. Brand identity
Wordmark "Carddex" in SF Pro Rounded Semibold, tight tracking, "dex" in the active game accent,
a 2px foil underline. App icon: a single trading card at a 3D ¾ tilt floating in a graphite case,
foil gradient (magenta→cyan→gold) with diffraction texture, warm-silver bezel, one specular
hotspot. No letters. Tone: confident, collector-literate, reverent. "Your grails, on display." /
"Caught it." / "Up $128 this week."

## 3. Color system (dark-first)

Dark mode (primary):
| Token | Hex |
|---|---|
| bg/base | #0B0B0F |
| bg/raised | #16161D |
| surface/1 | #1C1C26 |
| surface/2 | #262633 |
| stroke/hairline | #FFFFFF @ 8% |
| stroke/strong | #FFFFFF @ 14% |
| text/primary | #F4F4F7 |
| text/secondary | #A0A0AE |
| text/tertiary | #6C6C7A |
| accent/primary | #6E6BFF |
| accent/pressed | #5552E6 |
| gain | #34D399 |
| loss | #FB7185 |
| warning | #FBBF24 |

Spotlight gradient (signature): linear `#1A1A24 → #0B0B0F` + faint top-center radial
`#2A2A3A @ 40% → clear`. This single device sells the concept.

Light mode ("daylight case"): bg/base #F6F6F9, raised #FFFFFF, text/primary #16161D, secondary
#5B5B66, accent #5A57F0, gain #0EA371, loss #E11D48.

Per-game accents (refined for the dark vault) + 2-stop foil gradient:
| Game | accent | foil stops |
|---|---|---|
| Pokémon | #FFD23F | #FFE16B → #FF8A3D |
| Magic | #9B6BFF | #B98BFF → #5AC8FA |
| Yu-Gi-Oh! | #E8702A | #FFB347 → #C2410C |
| Sports | #2DD4A7 | #5EEAD4 → #0EA371 |

Theming rule: active game tints accents within a card's context only (detail, identify sheet,
that game's header) — never the global chrome. Global accent stays indigo `#6E6BFF`.

Rarity → foil tier:
| Tier | examples | treatment |
|---|---|---|
| common | Common, Uncommon | matte, no foil |
| rare | Rare, Holo Rare, Ultra Rare | foil sheen on art |
| mythic | Mythic, Secret, Special Illustration | full diffraction + animated sweep + gold edge |
| grail | price ≥ $500 OR graded | mythic + persistent slow shimmer + case-glass reflection |

## 4. Typography
System type. SF Pro for data/UI, SF Pro Rounded for display & numbers. `.monospacedDigit()` on
all prices/counts. Scale: Display 40/Bold, Title1 28/Bold, Title2 22/Semibold, Headline 17/Semibold,
Body 17/Regular, Subhead 15/Medium, Caption 13, Caption2 11 uppercase, Numeric = rounded mono.
Uppercase + wide tracking only on tiny labels (museum-placard feel). Animated figures use
`.contentTransition(.numericText())`.

## 5. Layout system
Spacing: add `xxs 2`, `xms 12`, `xxxl 48` to the existing scale. Radii: `xs 8 · sm 12 · md 16 ·
lg 20 · xl 28 · card 14 (continuous) · pill ∞`; always `.continuous`. Grid: collection
`.adaptive(minimum: 104)`, gutter 16, margin 16, card aspect 2.5/3.5. Depth: glass panels =
`.ultraThinMaterial` + 1px hairline + soft shadow; cards = radius 12 + shadow. Materials:
`.ultraThinMaterial` for sheets/tab bar/filters; `.regularMaterial` over busy art.

## 6. Motion & microinteractions
Global springs `response 0.4 / damping 0.82` (UI), `0.28 / 0.7` (taps). Gate all on
`accessibilityReduceMotion`.

- Holographic shine (signature): three stacked blend-mode layers clipped to the card shape, driven
  by `CoreMotion` attitude — foil AngularGradient (`.overlay`), diffraction lines (`.colorDodge`),
  specular sweep (`.screen`). Tier-gated by rarity. Reduce Motion → static foil gradient at 20%.
- Card flip / 3D tilt: `.rotation3DEffect` ±8° on two axes, parallax art plane; tap to flip to back.
- Scan success (~1.1s): reticle corners snap inward → scan-line sweep → accent flash → card rises
  and scales into the result sheet with holo kicking in. Success haptic.
- Pull-to-refresh (portfolio): number counts up from 0 + foil bar fills.
- Number roll-ups: `.contentTransition(.numericText)` + spring.
- Haptics map: tab `.selection`; chip `.light`; edge detected `.soft`; scan success `.success`;
  add `.medium`+success; card flip `.rigid`; remove `.warning`; set 100% `.success ×2`.

## 7. Component library
PrimaryButton (filled accent + subtle sheen, press scale 0.97; secondary glass; destructive;
prominent CTA). CardCell (rarity-aware: AsyncImage art, foil edge on rare+, foil tier dot, ×N badge
on regularMaterial). GamePill (refined accent 0.16 fill + 0.30 stroke + leading symbol badge).
FilterChip (selected = accent fill + glow; matched-geometry highlight). Custom floating glass tab
bar with center Scan FAB. Bottom sheets (ultraThinMaterial, 28pt corners). Live-camera scan overlay
(animated L-corner reticle, states: searching/locked/identifying/result; torch + import). Price tag
(regularMaterial pill, mono, gain/loss). Portfolio charts (Swift Charts: accent line, gradient area,
hidden axes, interactive RuleMark). Empty/loading (skeletons)/error states. Onboarding cards.

## 8. Signature screens
- Onboarding: 3 vault scenes (tilting holo card, scan reticle locking, portfolio roll-up) + camera
  permission primer.
- Scan: live camera in vault vignette; animated reticle; success → holo hero in a medium sheet with
  game pill, name, set·number, big mono price, prominent "Add to collection."
- Collection ("The Pokédex"): sticky glass filter bar; 3-col grid; Grid/Sets toggle — Sets = binder
  completion view (9-pocket pages, owned cards holo, missing as ghosted numbered slots, completion
  ring); 100% → celebratory haptic + foil shimmer.
- Card Detail: 3D-tilt + holo hero card, parallax bezel, floor shadow; tap to flip to back; 3 stat
  tiles; condition selector; price-history mini-chart; "List on eBay" + quiet "Remove".
- Portfolio: Display rounded-mono total + gain/loss delta; time-range segmented + area chart; by-game
  stacked bar + legend; Movers with mini sparklines; count-up pull-to-refresh.

## 9. Accessibility
AA contrast on all tokens; gain/loss paired with ▲▼ glyphs (never color-only). Dynamic Type via
scalable styles. VoiceOver: holo card = one labeled element; decorative layers hidden; reticle
states announced; charts get descriptors. Reduce Motion fallbacks for every effect. Reduce
Transparency → solid surfaces. Tap targets ≥44pt.

## 10. App Store screenshots
Titanium iPhone frames on the dark vault gradient; one bold caption per shot (keyword in game
accent); foil-underline motif. Shots: "Snap any card. Know it instantly." → "Holos that actually
shine." → "Your whole collection, on display." → "Track every dollar." → "Complete the set."
15s preview video leading with the foil.

## 11. Upgrade map (token-level)
- `Theme.swift`: add a `Theme.Color` semantic namespace (light/dark); accent → `#6E6BFF`; add
  `Spacing.xxs/xms/xxxl`, `Radius.xl/card`; `.continuous` everywhere; add `spotlightBackground`,
  `glassPanel(_:)`, spring constants.
- `CardGame.swift`: refined accents + `foilGradient`.
- `PrimaryButton.swift`: `Style { primary, secondary, destructive, prominent }` + press spring.
- `CardArtwork.swift`: `AsyncImage` + game-tinted shimmer placeholder + `rarity` → holo overlay.
- `CardCell/GamePill/StatTile/EmptyState/FilterChip`: dark glass + rarity/delta/glow upgrades.
- `CardDetailView/PortfolioView/RootView`: holo hero + 3D tilt; charts + count-up; floating glass tab
  bar + center FAB; `spotlightBackground` app-wide.
- New files: `HolographicFoil.swift`, `MotionManager.swift`, `GlassTabBar.swift`, `ScanOverlay.swift`,
  `PriceTag.swift`, `RollingNumber.swift`, `BinderPageView.swift`, `Rarity.swift`.

## Top 5 design decisions
1. Dark "vault" as the default identity — graphite spotlight + glass chrome so cards glow.
2. Holographic foil as the signature interaction — gyroscope-driven, rarity-tiered.
3. Refined indigo `#6E6BFF` global accent + per-game accents scoped to card context only.
4. SF Pro Rounded + monospaced digits with numeric content transitions.
5. Custom floating glass tab bar with a center Scan FAB.
