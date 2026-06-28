export const meta = {
  name: 'carddex-product-manager',
  description: 'Run a product manager agent that reads the current Carddex docs and code, then returns a ranked, evidence-backed feature backlog.',
  whenToUse: 'When you need to decide what to build next — generates prioritized feature candidates with impact, effort, and rationale.',
  phases: [
    { title: 'State', detail: 'read product docs and inventory current features' },
    { title: 'Backlog', detail: 'product manager proposes and prioritizes features' },
  ],
}

const REPO = '/Users/armanruzgar/dev/carddex'

const DOCS = [
  `${REPO}/docs/product-plan.md`,
  `${REPO}/docs/launch-plan.md`,
  `${REPO}/docs/handoff-guide.md`,
  `${REPO}/docs/design-spec.md`,
]

const FEATURE_DIRS = [
  `${REPO}/Carddex/Features/Collection`,
  `${REPO}/Carddex/Features/Scan`,
  `${REPO}/Carddex/Features/Market`,
  `${REPO}/Carddex/Features/Portfolio`,
  `${REPO}/Carddex/Features/Grails`,
  `${REPO}/Carddex/Features/Selling`,
  `${REPO}/Carddex/Features/Sharing`,
  `${REPO}/Carddex/Features/Settings`,
]

const CONTEXT = `Carddex is an iOS app that scans, identifies, and tracks collectible cards. The current strategy is Pokémon-first TCG, with the sports-card / Card Ladder direction as a long-term (v2.0) expansion. The three personas are:
- Marcus, the Returning Nostalgic (acquisition wedge): wants to know what a shoebox of old cards is worth with no typing.
- Priya, the Active Flipper/Reseller (monetization): wants fast intake, liquidation value, and low-friction listing.
- Dana, the Completionist (retention): wants set-completion progress and portfolio value over time.

Current shipped features and known gaps are documented in ${REPO}/docs/handoff-guide.md. Do not propose features that already exist unless you are extending them in a meaningful way.`

phase('State')
const state = await agent(
  `Read these files and summarize the current state of Carddex in structured markdown:\n${DOCS.map((d) => `- ${d}`).join('\n')}\n\nAlso list the SwiftUI files under these directories and briefly note what each feature area covers:\n${FEATURE_DIRS.map((d) => `- ${d}`).join('\n')}\n\nReturn:\n1. **Positioning & bet**: one sentence.\n2. **Shipped features**: bullets grouped by area (Scan, Collection, Portfolio, Market, Account, Pro).\n3. **Known gaps from handoff-guide.md**: top 5, with priority label.\n4. **Persona priority order**: the three personas and which one each shipped feature primarily serves.\nBe concise — the product manager will use this as input.`,
  { label: 'state-inventory', phase: 'State' }
)

const PM_PROMPT = `${CONTEXT}\n\nYou are the sole Product Manager for Carddex. Your job is to decide what new features to build next.\n\nUse the state summary below plus the source docs and current SwiftUI feature directories to produce a ranked feature backlog.\n\n**Process**\n1. List 8–12 candidate features that are plausible next builds.\n2. Score each on a simple RICE-style scale (1–5): Reach, Impact, Confidence, Effort.\n3. Rank the top 5 by highest (Reach × Impact × Confidence) / Effort.\n4. For each top-5 feature provide:\n   - **Feature** (short name)\n   - **Persona** (Marcus / Priya / Dana)\n   - **Hypothesis** (what job it does and why it moves a metric)\n   - **Evidence** (cite specific files, docs, or gaps that justify it)\n   - **MVP scope** (smallest lovable version)\n   - **Effort** (solo developer days, rough)\n   - **Risks / open questions**\n   - **Files likely to be touched** (Swift files, Edge Functions, migrations)\n\n**Constraints**\n- Default to the Pokémon/TCG launch plan; only push sports-card/Card Ladder features if the user explicitly asks for that direction.\n- Respect the existing v1.0/v1.1/v1.2 roadmap in ${REPO}/docs/launch-plan.md.\n- Do not duplicate already-shipped features.\n- Tie every feature to a persona and a business metric (acquisition, retention, monetization, or efficiency).\n\nOutput structured markdown. Be specific and concise.`

phase('Backlog')
const backlog = await agent(
  `${PM_PROMPT}\n\n---\n\n**State summary to ground your analysis:**\n\n${state}`,
  { label: 'pm-backlog', phase: 'Backlog' }
)

return {
  state,
  backlog,
}
