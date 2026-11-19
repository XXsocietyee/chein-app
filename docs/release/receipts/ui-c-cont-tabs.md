# Receipt: ui/c-cont-tabs (continuity r1, task 7: in-page tabs and segmented controls)

Brief: `origin/design/continuity-brief:docs/briefs/continuity-r1.md`. Base: `origin/ui/main`.
Skills: all three repos cloned and read (apple-design-motion/os/interaction, emil choreograph/gestures/animation-vocabulary/break-ui/write-swift, mifb make-interfaces-feel-better).
Swift is not installed here: **nothing in this branch has been compiled or run.** Every API was checked against existing repo usage and the iOS 17 deployment target (`Package.swift` `.iOS(.v17)`). `tools/check_swift_syntax.py` could not run (its pinned tree-sitter wheel failed the hash check), so the integrator's Xcode build is the first compile.

## Files touched
- `App/DesignSystem/CYTabs.swift` (only file). No screen edited, no new dependency, no navigation change.

## What changed

### 1. Indicator (underline, sticky, segmented): automatic for every CYTabs user
- Before: a `matchedGeometryEffect` capsule/pill hopping on `.easeOut(0.18)`; the tapped label snapped from semibold to bold, so in the ≥5-tab scroll layout neighbours reflowed.
- Now: ONE indicator, drawn once in a background layer behind the row (`backgroundPreferenceValue`), from each tab's rest box (the same 24×2.5 underline box, the same full-cell pill with `CYRadius.sm + 2`). It is a `Shape` whose two edges are animated separately:
  - front edge (the side it is travelling toward) moves at t = 0 on ease-in-out 0.30 s;
  - back edge follows at t = 0.12 s (`CYMotion.Duration.instant`) on the same curve → lands at **0.42 s**;
  - while stretched its height drops by up to **15%** (at the longest gap ≈ 60% of the travel) and returns to full as it settles.
  - Labels: both weights are laid out on top of each other and cross-fade (semibold/secondary ↔ bold/primary, or ↔ bold/inverse on the segmented pill) on ease-in-out 0.28 s after 60 ms, so the crossover happens while the indicator is mid-way and the tab width never changes.
- Nothing reflows: no frame or padding animates; the row's layout is the same at every frame.
- Interruption: a new tap mid-flight retargets from where the edges are (bezier animations are additive in SwiftUI, so neither edge jumps); the pending "land" task is cancelled. Input is never blocked.
- Reduce Motion (in-app setting, system, or `--uitesting-reduce-motion`, via `@QuestifyReduceMotion`): every slot draws its own indicator and only the selected one is opaque, so a change is a **150 ms fade in place** with no travel or squash; labels cross-fade in the same 150 ms.
- Chip variant: unchanged visuals (each chip owns its background), only the selection animation is the new label curve.

First / last frame: frame 0 = the indicator exactly on the old tab's rest box (drawn from the live box, so it equals the old static capsule/pill), labels at old weight/colour. Last frame (0.42 s) = the indicator exactly on the new rest box; then it is handed back to the live box without animation (same values, no visible change). At rest every bar looks as before, except: in the ≥5-tab scrolling underline each tab now reserves its bold width even when unselected (≈1 pt wider), which is what removes the reflow.

### 2. Content: provided, but CANNOT be applied without editing the screens
The bar does not own the content under it, so it cannot move it. `CYTabs.swift` now ships `View.cyTabContent(_ selection:, order:)`: the new content enters from the chosen tab's side (a trailing tab's content from the trailing side, RTL-aware) with a `CYSpacing.lg` (16 pt) offset + opacity; the old content leaves the other way. Old fades in the first 0.12 s (≈30%), new enters from 0.18 s (≈45%) to 0.42 s. The exit direction is read when the exit starts (a shared reference both transitions read), so fast switching never sends an old view the wrong way. Reduce Motion: 150 ms cross-fade.

**Not adopted anywhere** (adoption is a screen edit, outside my scope). Recommended one-line adoptions for the owners:

| Screen | CYTabs use | Content today | Adoption |
|---|---|---|---|
| `App/ClubHomeView.swift:54` club tab 帖文/俱乐部 (`.segmented`) | swaps two branches (`if topTab == .feed … else …`) with the default opacity transition, now on the new label curve | wrap the `if/else` in a `Group { … }.cyTabContent(topTab, order: ClubTabPresentation.TopTab.allCases)` (owner: club pages worker) |
| `App/TopicXcxSections.swift:39` topic detail 详情/故事/路线 (`.sticky`) | scrolls to sections (`proxy.scrollTo`), no swap | none needed: the scroll is the continuity; the indicator change applies |
| `App/E1ActivityDetailParts.swift:174` activity 详情/票种/评价与更多 (`.sticky`) | scrolls to sections | none needed |
| `App/HomeFeedView.swift:116` home 主题/活动 (`.underline`) | list replaced after an async reload | optional `.cyTabContent(kind, order: [.topics, .activities])` on the items' container (owner: player tab roots worker) |
| `App/DesignFixtures/DesignKitFixture.swift` | fixtures | none |

### 3. Merchant segments and hand-rolled controls (listed, not edited)
No merchant screen uses `CYTabs`. Merchant segments are system `Picker(...).pickerStyle(.segmented)` (UISegmentedControl, already native motion): `MerchantCoopCenterView.swift:144`, `MerchantMarketingView.swift:56`, `MerchantLedgerSettlementOverview.swift:118`, `MerchantGameNodeView.swift:571`, `MerchantBusinessViews.swift:875/895/914`, `MerchantOperationsEditor.swift:77`, `MerchantProjectBrowserControls.swift:11` (77 `.segmented` pickers app-wide).
Hand-rolled tab/segment controls with their own indicator (candidates to move onto `CYTabs`, not edited):
- `App/MPParityKit.swift:381` `MPChipTabs` (matched-geometry pill)
- `App/EditorKitCards.swift:119` `EditorSectionBar` (matched-geometry underline)
- `App/ClubDetailTabBar.swift:4` `ClubDetailTabBar` (matched-geometry underline, accent colour)
- `App/TemplateDetailXbChrome.swift:91` `TemplateXbTabs` (matched-geometry underline)
- `App/WalletEarningsOverview.swift:139` `WalletEarningsTabBar`
- `App/DesignSystem/CYNightTabBar.swift` (root tab bar, the reference; not in scope)

## Skill rules applied
- apple-design-motion: "Interruptible + velocity handoff… never block input" → additive edge animations, cancellable land task; "Animate transform/opacity only… don't animate layout properties" → indicator is a drawn shape in a background layer, labels cross-fade opacity; "Honor reduced motion: a fade, not the big move".
- emil/choreograph: Cast — Lead = indicator, Support = labels (cross-fade, no movement), Static = row/track. "Never stagger tab content" → content appears as one block. "Direction follows the user's mental model… content enters from the side of the trigger" and "Exits read state when they start, so pass the direction through" → shared direction reference. "Exits are simultaneous, shorter and simpler" → 0.12 s ease-in out vs 0.24 s ease-out in. "Sub-animations of one component share a timing family" → all ease-in-out/out within 0.42 s. "Reduced Motion: collapse, keep the opacity".
- mifb make-interfaces-feel-better: no layout shift on state change (weights stacked, width reserved); tabular digits kept on badges.
- Brief continuity rules: one element (single indicator), transforms/drawing not reflowing frames, end-only content fades in after ~45%, start-only out in first ~30%, 400–450 ms indicator, moves within a screen on ease-in-out, Reduce Motion 150 ms cross-fade, at rest identical.

## Checks
- `python3 -B tools/check_scaffold.py`: PASS. `python3 -B tools/check_design_lint.py`: PASS. `python3 -B tools/contract_ratchet.py --check`: see commit message / below.

## LOCAL VERIFICATION CHECKLIST (integrator)
1. Build. Expect possible fixes only in `CYTabs.swift` (generic `crossingLabel` builder, `AnimatablePair` shape, `CYTabContentModifier` body with explicit `return`).
2. Club tab (`--uitesting-club-fixture owner --uitesting-club-top-tabs`): tap 帖文 → pill's trailing edge leaves first, leading edge follows, pill visibly thinner mid-way, lands at ~0.42 s; labels swap bold/inverse colour mid-way. Record at 120 fps and step frames: frame 0 = old box, last = new box, no jump at hand-off. `ClubTabTopTabsFlowTests` must still pass (buttons are still found by title; `isSelected` trait kept).
3. Topic detail 详情/故事/路线 and activity 详情/票种/评价与更多 (sticky): underline travels with the stretch while the list scrolls; sticky header stays opaque above content.
4. Home 主题/活动 (underline): underline travel; list behaviour unchanged.
5. Fast repeated taps (A→C→B within 200 ms, and hammering two tabs): no jump, no stuck stretched indicator; it ends on the last tapped tab.
6. Long and short text: zh long titles (`进行中的城市漫游路线`), en, largest Dynamic Type — label wraps identically selected/unselected; no width change on selection; indicator under the right tab after a Dynamic Type change.
7. ≥5 tabs (scrolling underline, DesignKitFixture): indicator scrolls with the row; first and last tab; scrolled row then tap.
8. Badge counts: VoiceOver reads "title, value N", selected trait on the current tab, focus stays on the tapped tab; announcements unchanged.
9. Going back / leaving the screen mid-animation: no crash, no warning from the cancelled task.
10. Light and dark (player dark, merchant light): indicator `textPrimary`, segmented label `textInverse` on the pill, no colour flash mid-crossover.
11. Reduce Motion (system and in-app, `--uitesting-reduce-motion`): no travel, no squash; old indicator fades out and new fades in over 150 ms in place.
12. RTL (if exercised): front edge is still the side of travel.
13. Missing images / empty and scrolled lists / gesture cancelled half-way: n/a to the bar (no gestures; tap only) — confirm the bar renders before the list loads and with an empty list.
