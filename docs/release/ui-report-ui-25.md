# UI-25 report — NOT COMPILED

Owns: Workshop*, Bundle*, Mod*, Unified*, Cooperation*, Coop*, Team* (App/*.swift). Theme: dark (player). No per-view colour scheme added.

Files reviewed: 112 (all matching the patterns). Wave-1 overlap (cloud/ui-01..11): none.
Review method: grep sweep for raw colours (Color.red/green/orange/blue/secondary, hex, Color(...)), `.cornerRadius`, fixed `.font(.system(size:))`, `preferredColorScheme`.

## Files changed (5) — raw system colours -> CYColor tokens (status semantics unchanged)
| File | Change | Follows |
|---|---|---|
| CoopFinanceProfitView.swift | status badge fg/bg: green/orange/secondary -> successText/warningText/textSecondary, fills successSoft/warningSoft/bgSurfaceSubtle | design tokens |
| CoopListParitySections.swift | stage label orange/secondary -> warningText/textSecondary | design tokens |
| TeamMeetingHandshakeSectionView.swift | badge fill Color.blue.opacity -> infoSoft | design tokens |
| UnifiedDecisionsU01ToU08SectionView.swift | verified/unverified green/red -> successText/dangerText | design tokens |
| UnifiedReleaseAuditHubView.swift | verified/pending green/orange -> successText/warningText | design tokens |

## Skipped
Remaining 107 files: no raw colours/fonts found by sweep; left unchanged (rule: if clean/unsure, don't change). `.font(.system(size: 7))` in CoopSettlementDetailView is a bullet glyph, left. Hard-coded Chinese verbatim strings in some Unified*/Team* views were not touched (would need new keys; out of scope for a no-logic pass).
Not done: no empty/loading/error-state rework, no numeric-typography pass — not verifiable without compiling.

New string keys: 0 (`docs/release/ui-strings-ui-25.json` = `[]`).
