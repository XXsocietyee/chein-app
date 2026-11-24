# Wave ×10: fix, verify and optimize everything to go-live (owner, 2026-11-24)

The owner wants ten times the parallel workload, covering verification, checking, fixing and optimization.

- **Base for all:** `origin/ui/combined-r7`.
- **Read first:** `git show origin/design/handoff-r2:docs/briefs/WORKERS-HANDBOOK.md`, especially the native iOS rule and the MP-asset rule. MP brand, feature and category icons, logos, badges, illustrations and default images must be identical to the MP; only system-control glyphs stay SF Symbols. When `cursor/mp-assets` exists, use its `MPAsset` accessors and `docs/mp-assets/mapping.md`.

## The gap sources (use ALL of them, newest first)
- `origin/audit/parity-r7-<area>:docs/audit/parity-r7/<area>.md`: the r7 fix queue, once it is pushed.
- `origin/review/r7-rev-{a,b,c}:docs/review/r7-*.md`: the code-review findings.
- `origin/audit/ios-parity-<area>`, `origin/audit/parity-<area>` (round 1), and `docs/release/receipts/fix-parity-<area>.md` / `fix-parity2-<area>.md` on r7: the items marked deferred, partial or open.
- `origin/gap/g1-player` and `origin/gap/g2-ops`: `docs/mp-gap/*.md`.
- **Skip** anything an in-flight branch already covers: `restyle/*` is visual only, `cursor/*`, `gap/*` and `port/*`. Note those in your receipt.

## Layer split (avoids collisions)
- **Claude F-agents** own the **App/ layer** for their area: screens, flows, states, navigation, copy, MP assets in views, accessibility (VoiceOver labels, 44 pt targets, Dynamic Type) and the native iOS structure.
  - They don't change Core types; if Core is wrong, they write the request into the receipt for Cursor.
  - If the `restyle/*` agent for your area already changed a file, build on its branch: merge `origin/restyle/<area-branch>` first.
- **Cursor K-agents** own the **Core/ layer and Tests/** for their area: contracts (path, method, params, fields, error codes exactly as in the MP api modules), state machines, validation, caching, plus Core tests that pin each MP request and response.
- **Gemini** owns whole MP features missing from the app (new files), plus copy and contract alignment docs.

## Areas
- member
- account-publish
- merchant-coop
- club
- player-content
- play-roam

Each area's MP pages are listed in the round-1 audit. **Halves:** "a" covers the first half of the audit's page list, "b" the second half.

## Claude F-agents (12): `fix/r3-<area>-<a|b>`
For each page in your half, in this order:
1. P0 gaps.
2. P1 gaps.
3. Missing states (loading, empty, error, not signed in, no permission).
4. MP-asset consistency.
5. Native iOS structure.
6. Accessibility.

Write `docs/port/accept/f-<area>-<half>.txt` (fixture routes). Receipt: `docs/release/receipts/fix-r3-<area>-<half>.md`, listing each fixed id, the files changed, and the items left with reasons.

## Cursor K-agents (6) + infrastructure (see the Slack thread)
- `cursor/core-<area>`: every Core contract and logic gap for the area, plus tests.
- Infrastructure: wiring (W1), assets (C7), test burn-down (C3), the speed of the acceptance pipeline, and performance.

## Rules for everyone
- **Push every 30–60 minutes**, and push first if you are stopped.
- **No compiler in the cloud:** reuse existing types, and grep every API you call on `origin/ui/combined-r7` before using it. The coordinator compiles and sends back exact errors.
- **New Swift folders:** add their glob to `tools/generate_project.py`.
- **Strings:** fragment files `docs/port/strings/<branch-name>.json` (xcstrings format).
- **Safety:**
  - money stays TEST-only;
  - new gates default off;
  - never push main, ui/main or ui/combined-*;
  - no secrets and no MP screenshots (the repo is public).
- **Commit trailer:** `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (Cursor and Gemini use their own).
