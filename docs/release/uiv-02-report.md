# UIV-02 report — player home / discovery group (NOT COMPILED)

Branch cloud/uiv-02 from origin/ui/own-1. Presentation only; no accessibilityIdentifier or string key changed. No new strings (docs/release/ui-strings-uiv-02.json not needed).

## Screens
| iOS file | mini-program page | reference |
|---|---|---|
| App/HomeFeedView.swift (+ HomeHeroHeaderSectionView in HomeSearchTabParityViews.swift, lines <360) | pages/index/index | 001 (screenshot shows the merchant workbench, not the player home; structure taken from page-map.csv: hero, 推荐路线, 近期活动, 继续探索, 即将上线) |
| App/GlobalSearchView.swift | pages/search2/index | 014-search |
| App/SearchMapExplorerView.swift | pages/searchmap/index | 015 — reviewed, NOT edited (UIV-TODO below) |
| App/SquareBrowserView.swift | pages/square/list | 017-square |
| App/OfficialEventsBrowserView.swift | pages/activity/list | 016, 019 |

## Fixed
- Raw system fonts/colours (`.font(.footnote/.caption/.headline/.subheadline/.title2)`, `.secondary`, `.primary`, `Color(uiColor: .tertiarySystemFill)`) replaced by CYTypography/CYColor tokens in the five files above (HomeSearchTabParityViews lines < 360 only; tab-bar/merchant-switch code untouched).
- HomeFeedView: banner placeholder uses CYColor.bgRaised + CYRadius.md; rail loading uses CYSkeleton; empty uses CYEmptyStateView; retry button uses .cySecondary; spacing via CYSpacing.
- GlobalSearchView: category loading uses CYSkeleton; empty-result uses CYEmptyStateView; spacing tokens; 44pt via CYSpacing.minTouchTarget.

## Left (UIV-TODO)
- 014: mini-program shows recommended keywords as outlined rounded chips and categories as a 2-column tile grid with leading icon; iOS still uses `.buttonStyle(.bordered)` grid. Needs a chip component (new file) — not done blind.
- 014: search field is an inline TextField in a List section, mini-program uses a pill field + 筛选 button; `.searchable` migration touches logic, left.
- 016/019: official list uses segmented Picker; mini-program uses pill chips; summary row links are in toolbar. Left.
- 017: composer row (avatar + prompt + media/location/flag icons) at top is not rendered in SquareBrowserView; needs data (viewer avatar) — left. Feed rows still plain List rows.
- Home first-load state is still ProgressView("homeFeed.loading") (no layout skeleton for whole page).
- SearchMapExplorerView.swift (610 lines): not reviewed in depth.
- Dynamic Type / VoiceOver: not verified (cannot compile).

## Compile risks
- `CYEmptyStateView(systemImage:title:description:)` takes LocalizedStringKey; string literals used. CYSkeleton() has no args. `.buttonStyle(.cySecondary)` is a static member on ButtonStyle (CYDesignComponents.swift:264) — verify it resolves for `Button` with a ButtonStyle context.
- CYTypography.meta/caption/cardTitle/bodyCompact/sectionTitle exist (checked).
