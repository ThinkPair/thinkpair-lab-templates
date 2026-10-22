---
type: design_qa
layer: output
status: active
validity: current
retrieval: on_demand
effective_from: 2026-07-30
privacy: private
---

# Design QA

- source visual truth path: `reference/self-media-dashboard-visual-target-v0.6-2026-07-30.png`
- normalized source path: `reference/visual-target-v0.6-normalized-1440x1024.png`
- implementation URL: `http://localhost:4173/`
- implementation screenshot path: `reference/implementation-v1.4-1440x1024.png`
- viewport: `1440 × 1024 CSS px`
- source pixels: `1487 × 1058`
- normalized source pixels: `1440 × 1024`
- implementation pixels: `1440 × 1024`
- density normalization: source was bicubic-normalized to the exact implementation pixel size; both were compared at 1:1 CSS/pixel scale
- state: 经营链路首页；全部平台；近 4 周；有效线索为默认焦点；图表动画完成

## Full-view comparison evidence

- combined comparison: `reference/design-qa-side-by-side-passed.png`
- result: the implementation preserves the selected asymmetrical composition—left operating-path card begins below the KPI strip, while the right source card begins higher and the trend card aligns with the lower half.
- hierarchy: title, four KPIs, six-stage path, source donut, and cumulative trend follow the same reading order as the source.
- layout: no viewport overflow; persistent controls and the full desktop dashboard are visible within `1440 × 1024`.

## Focused-region comparison evidence

- combined chart comparison: `reference/design-qa-focus-charts-passed.png`
- donut: three platform shares, center total, labels, values, and percentages match the source logic.
- trend: four complete week labels, point values, and right-side platform endpoint labels are visible and legible.
- funnel detail: the acid-lime vertical operating spine, five adjacent-stage ratios, lower endpoint, and effective-lead focus marker are present.

## Required fidelity surfaces

- Fonts and typography: Chinese UI uses the approved system/MiSans-style stack; numeric display uses Outfit/Satoshi fallbacks. Weight, hierarchy, line height, and wrapping are consistent with the target. No truncation was found in the selected state.
- Spacing and layout rhythm: top navigation, editorial whitespace, KPI rhythm, asymmetric bento placement, card radii, and internal stage spacing align with the source. Minor optical spacing differences are acceptable responsive implementation choices.
- Colors and visual tokens: mist canvas, pale blue operating-path surface, sage source surface, warm stone trend surface, indigo/coral/teal platform colors, and acid-lime emphasis are mapped to centralized CSS variables and visibly match the selected direction.
- Image quality and asset fidelity: this screen is chart- and icon-led; no photographic or illustrative asset from the source was replaced. Icons come from the existing icon library and charts remain vector-rendered.
- Copy and content: six stages, units, platform splits, five adjacent-stage ratios, source shares, and cumulative weekly values match the locked logic. “相邻阶段比” is not presented as user-level conversion.

## Primary interactions tested

- three main navigation tabs;
- platform filter and reset;
- 4-week / 12-week trend switch;
- funnel stage detail drawer and close action;
- supplement-data modal, intake-method selection, review state, and confirmation;
- desktop viewport `1440 × 1024`;
- mobile viewport `390 × 844`, with no horizontal overflow and no fixed disclaimer overlay;
- browser console warnings/errors: none.

## Comparison history

### Pass 1 — blocked

- finding: source and implementation evidence were not yet available in one comparison input.
- fix: captured the browser-rendered implementation and produced equal-size full-view and focused combined comparisons.

### Pass 2 — blocked

- finding: the first implementation aligned both columns at one top edge and used a wider left-column ratio than the selected target.
- fix: restored the target’s asymmetric composition, moved the right source module upward, set the left/right grid ratio to `1.7 / 1`, and matched the target’s 610 px operating-path height.
- post-fix evidence: `reference/design-qa-side-by-side-final.png`.

### Pass 3 — blocked

- finding: the operating path lacked a visually continuous acid-lime spine and focus node; trend labels and endpoint attribution were too small.
- fix: added the continuous vertical spine, bottom node, effective-lead focus dot, larger axes/data labels, and direct endpoint labels.
- post-fix evidence: `reference/design-qa-side-by-side-passed.png` and `reference/design-qa-focus-charts-passed.png`.

### Pass 4 — passed

- independent read-only QA found no remaining P0, P1, or P2 differences.
- production build passed.
- Sites packaging regression test passed `4/4`.
- core browser interactions passed and browser console remained clean.

## Findings

- No actionable P0/P1/P2 findings remain.

## Follow-up polish

- P3: before real data import is added, decide whether 12-week endpoint labels should abbreviate large values for very narrow screens.
- P3: when real platform exports replace demo data, add regression cases for long labels, missing values, and extreme stage imbalance.

final result: passed
