# UIV-07 report (NOT COMPILED)
Group: topic / activity / template detail / sign-up. Branch cloud/uiv-07 from origin/ui/own-1. Reference: chengyin `docs/evidence/player-e2e-20260927/` 003..011, 020, 023..029 (screenshots not viewed this run; structure taken from existing code + ui-standard §4 Detail).

## Screens
| iOS file | mini page | diffs found | status |
|---|---|---|---|
| App/TopicXcxSections.swift (hero, stat bar, route, templates, session chip, action bar) | pages/topic/index | raw fonts (.caption2/.headline), raw `.orange`, `Color.secondary.opacity` fills, `systemBackground` bar, fixed 22pt badge, 10/12 literals | FIXED |
| App/OfficialPrivateViews.swift (inbox, published, stats) | official-inbox / official-mine | `.orange`, `Color.secondary` capsule | FIXED (colour only) |
| TopicDetailView, TopicSessionSelectionView, ticket selection, TopicReviewsContent/review sheet, ActivityDetailView, DiscoveryTemplateBrowserView | topic/activity/template | not audited | LEFT |

## Fixed
- Key facts: tokenised card (bgElevated, Radius.lg), tabular numerals, label type via Theme.Font.
- Category chips: 8-radius bgRaised fill, line limit.
- Sticky action bar: `.bar` material + hairline, warning token for merchant-closed notice, 44pt min height on secondary.
- Route index badge: scalable min size, hidden from VoiceOver (row text carries meaning).
- Template cards: elevated surface, token padding/radius.
- Statuses use `cyPalette.warning`, not raw orange.

## Left / risks
- Remaining files above not touched (scope/time); need audit for hard-coded colours, skeleton/empty/error states, hero image for detail.
- Action bar `.selfPlay` shows two buttons (sessions bordered + primary): one primary kept.
- Compile risks: `Theme.Font.label.weight(.semibold).monospacedDigit()` (Font chain, iOS 17 ok); `@Environment(\.cyPalette)` in structs with memberwise-init callers (private, so init unchanged); `.background(.bar)` as ShapeStyle.
- No new strings; no ui-strings-uiv-07.json needed.
