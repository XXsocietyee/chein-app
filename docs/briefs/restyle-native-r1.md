# Native iOS restyle r1: shared brief for R1–R6 (owner, 2026-11-24, runs IN PARALLEL with the port packages)

**Owner decisions:**
- "I need the native iOS style."
- "Your work should be parallel, not sequential."
- The repo is PUBLIC: no secrets and no MP screenshots.

## Read first
1. `git show origin/design/handoff-r2:docs/briefs/WORKERS-HANDBOOK.md`: the complete picture.
2. `git show origin/design/handoff-r2:docs/briefs/port-packages-r1.md`: the **Native iOS style rule** section. That is your design rule.
3. If `origin/design/native-ios-r1` exists, read `docs/design/native-ios-r1.md` (the full spec, being written in parallel) and follow it where it is more specific. If it lands while you work, re-read it before your last commit.
4. Reference implementation: chengyin-ios (`docs/native-design-and-motion.md` and its views; clone https://github.com/liboyang42-cpu/chengyin-ios).
5. Skills: `git clone --depth 1 https://github.com/s1gmamale1/apple-design-skills /tmp/s/apple` and `git clone --depth 1 https://github.com/dickwu/apple-design-skill /tmp/s/review` (apple-design-os, -foundations, -interaction, -tactics; HIG review lens).

## What to change in every screen you own
- **Navigation:** system `NavigationStack` title plus the system back.
  - Remove custom back chevrons and custom title bars. Use `cyGuardedBack` only for unsaved edits.
  - Use `.navigationBarTitleDisplayMode(.large)` on tab roots and `.inline` on details.
- **Structure:** settings, detail and info pages become `List`/`Form` with `.insetGrouped` sections (section headers in sentence case, footers for help text).
  - Card feeds stay cards, but with one card style (radius 12, 16 pt margins, no heavy shadows).
  - Heroes use radius 20, full-bleed only where content is visual.
- **States:**
  - empty and error: `ContentUnavailableView` (with a retry `Button`);
  - loading: `ProgressView` or the existing skeleton;
  - no "0" for unknown values.
- **Type:** semantic Dynamic Type styles only (`.largeTitle … .caption`), via `.font(.headline)` etc. or `.cyText(.token)` if the token maps to a text style.
  - Replace `.font(.system(size:))` and static `.font(CYTypography.x)` for text.
  - Nothing below `.caption`. Use `.monospacedDigit()` for numbers. No `lineLimit(1)` truncation of titles.
- **Controls:**
  - `.buttonStyle(.borderedProminent)` for the one primary action per screen, `.bordered` for secondary;
  - destructive actions use `role: .destructive` plus a confirmationDialog;
  - toggles, pickers and steppers are system controls;
  - sheets use `.presentationDetents` and `.presentationDragIndicator(.visible)`.
- **Colour:** system background and grouped-background colours, semantic label colours, and the MP accent as `.tint`. Keep the MP status colours for tags. Follow system light and dark.
- **Keep everything else:**
  - every function, request, state, navigation target and MP Chinese copy;
  - the `CYMotion` / `CYInPlaceResult` motion, respecting Reduce Motion;
  - VoiceOver labels and 44 pt targets.
- **Scope:** this is a visual and structural restyle only. No contract or behaviour changes.

## Ownership (disjoint; touch only your files)
**NEVER touch files owned by a port package:** the file lists in plan §4 (`git show origin/port/plan-r1:docs/port/ios-port-plan.md`), which cover P1–P5.

You own the top-level `App/` files whose name starts with these prefixes, plus the listed folders:

| pkg | prefixes / folders | branch |
|---|---|---|
| R1 player front | `Home`, `Discovery`, `Search`, `Topic` (except P3's), `Activity`, `Registration`, `Official`, `Square`, `Public`, `Player`, `Team`, `Map` | `restyle/r1-player-front` |
| R2 club & social | `Club`, `ClubKit/`, `Social`, `Session`, `Messaging`, `IM`, `Channel`, `Friend` | `restyle/r2-club-social` |
| R3 merchant & creator | `Merchant`, `MerchantKit/`, `Coop`, `Cooperation`, `Workshop`, `Mod`, `Creator`, `Project`, `Publishing`, `Editor`, `Template` | `restyle/r3-merchant-creator` |
| R4 me & account | `Profile`, `Account`, `Settings`, `Wallet`, `Ticket`, `Member`, `Bundle`, `Own`, `Owned`, `Retained`, `Unified`, `Approved`, `Reviewed`, `Invoice`, `Coupon`, `Order` | `restyle/r4-me-account` |
| R5 play, roam & city (non-port files only) | `Roam`, `City`, `CityKit/`, `Free` (except P2's), `Play` (except P1/P2/P4's), `Journey` (except P1's), `Guest` | `restyle/r5-play-roam-city` |
| R6 design system + everything else | `DesignSystem/`, `Theme/`, `DesignFixtures/`, `App`, `Questify`, `Native`, and any `App/*.swift` not matched by R1–R5 | `restyle/r6-system-rest` |

- **R6 changes the shared components FIRST and pushes within 1 hour:** `CYCard` radius 12, `CYSheet` with system detents, the state kit to `ContentUnavailableView`, text tokens to text styles, and the raw sizes in `App/DesignSystem`. That way R1–R5 benefit. R1–R5 do not edit `App/DesignSystem/*`. If you need a component change, note it in your receipt.
- Work in batches of ≤ 40 files per commit. Push at least every hour.

## Done means
- Base `origin/ui/combined-r6`; branch as above.
- Write `docs/port/accept/<pkg>.txt`: the fixture routes of your 10–20 most important screens.
- **Cloud acceptance:** once `.github/workflows/acceptance.yml` exists (Cursor is adding it now), push and let it run, or run `gh workflow run acceptance.yml --ref <branch>` if gh is available. Iterate until it is green with no new failures.
  - Until then, run `swiftc -parse` on the changed files if available, keep expressions short, and reuse existing types (no compiler in the cloud; the acceptance run is the compiler).
- **Receipt** `docs/release/receipts/restyle-<pkg>.md`: the files changed, the before→after patterns, the screens for acceptance, the component requests, and anything left.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never push ui/main or ui/combined-*.
