# CB48 — Fixed heights follow Dynamic Type

Base: `origin/rc/20261108` `88e981b3308558939e405606cd731b4b29fc9499`.
Source: `origin/cursor/cb16` `docs/release/cb16-accessibility.md` (`4aba7815dfa34a730fb01f59950f8e734898b256`), section “Fixed-height findings”. That note names six. All six are in this change. Nothing else was restyled.

`swift`, `swiftc`, and `xcodebuild` were not run. This is not a compile or a runtime pass. No test was deleted. `tools/current_ci_manifest.json` was not refreshed. `Config/Base.xcconfig` stays `MARKETING_VERSION = 0.1.0` and `CURRENT_PROJECT_VERSION = 1`. Password login, bank-card withdrawal, and virtual goods were not touched.

At Dynamic Type `.large`, each `@ScaledMetric` below is the old constant. Identifiers and localization keys are unchanged.

## Changes

| # | CB16 site | What changed |
|---|---|---|
| 1 | `App/DiscoveryTemplateBrowserView+Port.swift` 72×72 cover | `DiscoveryTopicCoverThumb` adds `@ScaledMetric(relativeTo: .caption2) private var side: CGFloat = 72`. The shared frame is `.frame(width: side, height: side)`. The fallback text stays `discovery.coverUnavailable` at `.caption2`. Corner radius 10, the photo symbol, and the success/failure branches are unchanged. The loaded cover uses the same frame, so that square scales with the fallback. |
| 2 | `App/RoamPassportToolsViews.swift` 170pt week chart | `RoamRecapWeekChart` adds `@ScaledMetric(relativeTo: .caption) private var chartHeight: CGFloat = 170`. The column frame is `.frame(minHeight: chartHeight)` instead of `.frame(height: 170)`. The 110pt bar, 14pt bar width, caption count, and `roam.tools.recap.week` label are unchanged. Identifier `roam.tools.recap.weeks` is unchanged. A minimum is used so a taller caption can grow past the scaled floor; the bar does not shrink. |
| 3 | `App/WalletEarningsOverview.swift` earnings tabs at 44pt | `WalletEarningsTabBar` adds `@ScaledMetric(relativeTo: .body) private var tabHeight: CGFloat = 44`. The frame is `.frame(minHeight: tabHeight)` instead of `.frame(height: 44)`. Horizontal padding and the vertical `Theme.Space.s2 - 6` padding are unchanged. |
| 4 | `App/WalletEarningsAccessibleTabs.swift` `sizeThatFits` height 44 | The representable adds `@ScaledMetric(relativeTo: .body) private var minimumHeight: CGFloat = 44`. `sizeThatFits` returns `max(minimumHeight, intrinsicContentSize.height)` and still uses the proposed width, or the intrinsic width when the proposal has none. `WalletEarningsSegmentedControl.intrinsicContentSize` is still `max(44, size.height)`. Segment titles, traits, and identifiers `wallet.earnings.tabs`, `wallet.earnings.tab.income`, and `wallet.earnings.tab.organizer` are unchanged. |
| 5 | `App/SearchMapFilterSheet.swift` 160pt date wheel | `SearchMapDatePickerSheet` adds `@ScaledMetric(relativeTo: .title2) private var wheelHeight: CGFloat = 160`. The year/month/day wheel is `.frame(height: wheelHeight).clipped()` instead of `.frame(height: 160).clipped()`. `.labelsHidden()`, the sibling title, and identifiers `mapDatePicker.year`, `mapDatePicker.month`, and `mapDatePicker.day` are unchanged. |
| 6 | `App/RoamMedalShareView.swift` 400pt poster pinned to `.large` | `RoamMedalShareView` reads `@Environment(\.dynamicTypeSize)` and `@ScaledMetric(relativeTo: .title3) private var posterHeight: CGFloat = 400`. `prepare()` passes both into `RoamMedalShareRenderer.render`. The card frame is `.frame(width: 300, height: posterHeight)`. Width stays 300. The medal mark stays 96×96 inside a 120pt stack. The name keeps `.lineLimit(3).minimumScaleFactor(0.5)`. `render(_:dynamicTypeSize:posterHeight:)` defaults to `.large` and `400`, so existing `render(card)` calls stay on the 300×400pt, scale 2.5, 750×1000px portrait. The shipping path no longer forces `.large`. |

## Left alone

Labels, traits, colors, fonts, copy, and the other fixed frames in the CB16 note (hairlines, hidden covers, maps, avatars, the 110pt bars’ own height, the 240pt check-in slot, route sketches) were not changed.
