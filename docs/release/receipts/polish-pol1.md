# Polish pass pol1: Explore / Today tab

Branch `ui/pol1`, base `origin/ui/main` 9ad1f1649. Code-only (no xcodebuild / simulator run; the integrator compiles and records).
Spec: `design-wave3.md` (Night-city light). Lint: `tools/check_design_lint.py` PASS, `tools/check_scaffold.py` PASS.

## Files
- NEW `App/DesignSystem/CYExploreKit.swift`: `CYExploreGround`, `CYSectionReveal` (+gate), `cyBackdropParallax`, `cyNightCardDepth`, `Text.cyEyebrow`, `CYTodayMedallion`.
- `App/HomeFeedView.swift`, `App/HomeSearchTabParityViews.swift` (search pill edge only). `project.pbxproj` regenerated.

## Before / after
| Area | Before | After |
|---|---|---|
| Ground | `#000` page | ink0 with an indigo wash fading out by mid-screen (dark); light unchanged |
| Today card | 240 pt slab, title3 title, black-to-0.78 scrim, no edge, tiny inline glyph | 280 pt, 22 pt radius, page-title type, indigo-dusk to ink0 scrim, 1 pt night-glass edge, layered depth shadows, glass medallion top trailing, eyebrow uppercase +0.6 pt (zh +1 pt, no heavy) |
| Lantern | none | gold glow + hot glyph only when the card is the roam (discovery) prompt; breathes 2.4 s; ticket / club event stay neutral glass. No gold on chrome or text |
| Entrance | whole feed appeared in one frame | spring reveal per section (fade, 22 pt rise, 0.97 to 1), 70 ms apart on the first fold only; later sections reveal on arrival with no delay; plays once per screen |
| Parallax | none | Today art drifts 8 % of its distance from mid-screen (cap 14 pt), 12 % oversize so no edge shows |
| Rails | skeleton / failure / content swapped instantly | cross-fade in place via `cyAnimation` (spring) |
| Offline state | system `ContentUnavailableView` | `CYStateLayout(.offline)` art on the ink ground, same identifier |
| Failure rows | bare label + button | surface card with edge + depth, fade transition |
| Section titles | title2 bold | 20 pt semibold (spec), 4 pt top air; bottom padding 48 so the last card clears the tab bar |
| Search pill | flat 1 pt border | night-glass gradient edge + soft shadow |
| Cover image | popped in | 0.35 s fade |

## Fallbacks
Reduce Motion: no reveal offset/fade, no parallax, medallion static (existing press-wave rules unchanged). Low Power / thermal: medallion static (`CYLightBudget.shadersAllowed`). No shader used. Reduce Transparency: unchanged (medallion material only).

## Identifiers kept
`homeFeed.today.*`, `homeFeed.today.action`, `homeFeed.configurationUnavailable`, `homeFeed.retry.*`, `homeFeed.kind/category/empty/loadMore/noMoreFooter`, `homeIndex.hero.*`, `homeFeed.carousel.*`. No strings added (card copy stays on `CYKitCopy`).

## Not done / notes
Pull-to-stretch of the hero was not added (the greeting header sits above the Today card, so there is no top-pinned art to stretch). Unverified by compile: `proxy.bounds(of: .scrollView)` (iOS 17) inside `visualEffect`.

SHA: see the commit tip of `ui/pol1`.
