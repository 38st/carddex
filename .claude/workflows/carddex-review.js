export const meta = {
  name: 'carddex-review',
  description: 'Spin up the Carddex specialist panel (design, iOS, backend, product) to review the repo, then build-verify',
  whenToUse: 'After a batch of changes — get a multi-role review of the current state plus a build check.',
  phases: [
    { title: 'Review', detail: 'four specialists review the repo in parallel' },
    { title: 'Build', detail: 'generate + build + test' },
  ],
}

const REPO = '/Users/armanruzgar/carddex'

const CONTEXT = `Carddex has pivoted to a Card Ladder-style (cardladder.com) SPORTS-FIRST card market & investment tracker. The new Market tab (Carddex/Features/Market/*) has a market index, movers, graded PSA values, recent sales, and a searchable database; there's also Scan, Collection, Portfolio (cost-basis/ROI). Card Ladder's core is: market index, searchable card database with real sales history, graded values + population, portfolio ROI, price alerts, per-category/player indices. Focus every recommendation on building out this Card Ladder direction, sports-first.`

const ROLES = [
  {
    key: 'design',
    prompt: `${CONTEXT}\n\nYou are a senior product/UX designer. Review the SwiftUI screens in ${REPO}/Carddex/Features/* (especially Market/*) and ${REPO}/Carddex/DesignSystem/*. Return the 5 highest-impact UI/UX features to build next for the Card Ladder direction (e.g. category/player indices, watchlist, price alerts, graded matrix), each as: screen · concrete change · why. Ranked. Structured markdown.`,
  },
  {
    key: 'ios',
    prompt: `${CONTEXT}\n\nYou are a senior iOS engineer. Review ${REPO}/Carddex/* for correctness, Swift 6 concurrency, performance, and architecture as the app scales to a market-data app. Return the 5 highest-impact engineering improvements/features with specific files/changes. Structured markdown.`,
  },
  {
    key: 'backend',
    prompt: `${CONTEXT}\n\nYou are a backend/infra architect. Review ${REPO}/supabase/* and ${REPO}/docs/*. Card Ladder lives on real SPORTS sales data (eBay sold comps, auction houses) + graded values + population. Return the 5 highest-priority backend tasks to power this (sports catalog + sales/price pipeline, indices, alerts, deploy), ranked. Structured markdown.`,
  },
  {
    key: 'product',
    prompt: `${CONTEXT}\n\nYou are a product strategist. Return the 5 highest-leverage product moves to win as a sports-card-first Card Ladder competitor (data moat, monetization, growth, retention, what to build vs cut), ranked. Structured markdown.`,
  },
]

phase('Review')
const reviews = await parallel(
  ROLES.map((r) => () => agent(r.prompt, { label: `review:${r.key}`, phase: 'Review' }))
)

phase('Build')
const build = await agent(
  `Run \`bash scripts/dev.sh build\` in ${REPO} and report the result. If it fails, return the first compiler error verbatim. Then run \`bash scripts/dev.sh test\` and report pass/fail counts. Be terse.`,
  { label: 'build-verify', phase: 'Build' }
)

return {
  reviews: ROLES.map((r, i) => ({ role: r.key, findings: reviews[i] })),
  build,
}
