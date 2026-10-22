---
type: agent_manifest
layer: governance
status: active
validity: current
retrieval: on_demand
effective_from: 2026-07-30
privacy: private
---

# Prototype Instructions

Run the local server yourself and open the preview in the browser available to this environment. Do not give the user server-start instructions when you can run it.

Before making substantial visual changes, use the Product Design plugin's `get-context` skill when the visual source is unclear or no longer matches the current goal. When the user gives durable prototype-specific design feedback, preferences, or decisions, record them in `AGENTS.md`.

When implementing from a selected generated mock, treat that image as the source of truth for layout, component anatomy, density, spacing, color, typography, visible content, and hierarchy.

Build app UI in `src/`. Keep `.openai/hosting.json`, `worker/index.js`, `scripts/prepare-sites-build.mjs`, and `tests/sites-worker.test.mjs` intact so the same local prototype can be handed to Sites. Before a Sites handoff, run `npm run build` and `npm run test:sites`; the build must leave `dist/client/index.html`, `dist/server/index.js`, and `dist/.openai/hosting.json`.

## Selected visual target

- Source truth: `reference/self-media-dashboard-visual-target-v0.6-2026-07-30.png`.
- Durable user direction (2026-07-30): lock the v0.5 premium mist-white / mist-blue / sage visual system, but use the six-stage operating logic shown in the user reference: 内容触达 → 新增关注 → 有效线索 → 深度沟通 → 首次付费 → 升级续费.
- Homepage composition: one dominant six-stage operating-path rail, one supporting lead-source donut, and one supporting four-week cumulative lead trend.
- Primary benchmark role: cool mist-white canvas, pale mist-blue hero surface, sage and warm-stone supporting surfaces, editorial black typography, generous whitespace, restrained acid-lime focus, and almost no shadow.
- Keep the working UI separate from any Xiaohongshu/Douyin sales presentation image.
- Preserve semantic boundaries: reach is event volume; followers/leads/conversations are platform records approximated as people; paid/renewal are orders; cross-platform identities are not deduplicated. All five percentages are “相邻阶段比”, never strict user conversion rates.
- The trend is cumulative valid-lead records across the selected four-week window; do not label it as weekly new leads.
- Unknown is not zero. Demo values and evidence states must remain visibly labeled.
- Durable user direction (2026-08-01): the deliverable is a portable local Web-dashboard package inside the Obsidian vault, not a public website. The visual renderer and formulas stay fixed; Obsidian Copilot/DeepSeek may only update the package data note under a strict schema and human-confirmation gate.
- The shipped package starts with all business values as `null`. It must work from any Windows path without `node_modules` or a first-run install, prefer a `127.0.0.1` link, and fall back to a built-in PowerShell local server when Node.js is unavailable.
- Never let AI-authored totals, ratios, chart widths, HTML, CSS, JavaScript, or operating recommendations enter the runtime data contract. Invalid data must preserve the last valid snapshot.
- Durable user direction (2026-08-01, second revision): the live-stream dashboard is single-mode with a "real where recorded, reference-fill where not" rule — reach (6,713/649/466) and new follows (8/3, bilibili kept null) are real backend data; leads (14/8/4), conversations (6/3/2), paid (2/1/1), renewal (1/0/0) and the 4-week rising lead trend are reference-image fills because no records exist (real paid/renewal = 0). The amber “演示数据” badge and a mixed-provenance footer stay on screen; filled numbers must never be called real leads, conversations, or sales. Real data is archived at `真实数据存档-2026-08-01.md` (package) and `public/data/real-data-2026-08-01.js` (this repo); restore with `恢复真实数据.cmd` after the live stream.
- Durable user direction (2026-08-01): the donut and trend cards are adaptive — with no lead data they show reach platform mix and per-episode play trend (with snapshot-window caveats); once real lead data exists they switch back to lead source and cumulative lead trend automatically.
- Durable user direction (2026-08-01, motion): the live-stream dashboard carries ambient "breathing" motion — staggered lime light sweeps across each stage rail, a rotating conic light ring on the donut, a periodic light sweep plus line glow and pulsing dots on the trend chart, and soft metric-number breathing. Motion is CSS-only, changes no numbers, and is disabled by the existing prefers-reduced-motion global rule.
