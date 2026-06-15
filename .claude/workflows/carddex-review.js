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

const ROLES = [
  {
    key: 'design',
    prompt: `You are a senior product/UX designer. Review the SwiftUI screens in ${REPO}/Carddex/Features/* and ${REPO}/Carddex/DesignSystem/*. Return the 5 highest-impact UI/UX improvements not yet done, each as: screen · concrete change · why. Be specific and ranked. Structured markdown, not conversational.`,
  },
  {
    key: 'ios',
    prompt: `You are a senior iOS engineer. Review ${REPO}/Carddex/* for correctness, Swift 6 concurrency, performance (image loading, list/grid, holo redraws), and architecture. Return the 5 highest-impact engineering improvements with specific files/changes. Structured markdown.`,
  },
  {
    key: 'backend',
    prompt: `You are a backend/infra architect. Review ${REPO}/supabase/* and ${REPO}/docs/*. Return the 5 highest-priority backend tasks to make the app production-real (catalog ingestion, image pipeline, auth/sync, deploy), ranked, with rationale. Structured markdown.`,
  },
  {
    key: 'product',
    prompt: `You are a product strategist. Review ${REPO}/docs/launch-plan.md and the feature set. Return the 5 highest-leverage product moves toward an App Store launch (scope, monetization, growth, retention), ranked. Structured markdown.`,
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
