# UI-F01 fidelity report — NOT COMPILED

Branch `cloud/ui-f01` (from `origin/wip/gate-allowlist`). Mini-program source (`chengyin` repo, `chengyinhub-xcx/pages/**`) was accessible and read.
Theme: all pages here are PLAYER surfaces (dark); the mini-program pages are also `theme-dark`. No per-view colour scheme added. Presentation only; every `accessibilityIdentifier` and text key kept. No new strings, no new component files.

**Screenshots:** none found for any of the seven pages. `chengyinhub-xcx/artifacts/` holds only merchant-ai-npc / route-flow-audit / route-m5; `docs/xcx-wechat-review-board-shots/` holds only `stub-square.png` and `orphan-talent-search.png` (a stub/orphan board, not the live pages; not used as layout source). Layout was therefore derived from the `.wxml`/`.wxss` only.

| Mini page | Screenshot | iOS file | Matched (already, verified in WXML) | Changed in this branch |
|---|---|---|---|---|
| `pages/index/index` | none found | `App/HomeFeedView.swift` | hero banner pager -> 推荐主题 rail -> 继续探索 -> 附近活动 rail -> 即将上线 (hidden when empty) -> 主题/活动 tabs feed; per-section loading/error/empty; “没有更多了” footer | rail spacing and banner placeholder moved to `CYSpacing`/`CYRadius`/`CYColor` tokens |
| `pages/search2/index` | none found | `App/GlobalSearchView.swift` | field + 筛选, 搜索历史 (清空), 推荐搜索, 类别 (hidden when empty; loading/error kept), map entry last; results replace suggestions | 筛选 now icon+text (mini ghost button; icon-only is no longer forced), pill chips for 推荐搜索, rounded tiles for 类别, history/hint text on `CYTypography`/`CYColor` |
| `pages/searchmap/index` | none found | `App/SearchMapExplorerView.swift` | merged into search2 as the map mode (page-map) | only two secondary-text styles moved to CY tokens; layout untouched (large file, not restructured without a screenshot) |
| `pages/square/list/index` | none found (`stub-square.png` is a stub board) | `App/SquareBrowserView.swift` | feed modes, upcoming strip, closed-community and empty states | closed/empty states re-laid as centred empty states with CY typography and `cySecondary` retry; offline note tokenised |
| `pages/talent/list/index` | none found (`orphan-talent-search.png` is the legacy search) | `App/ClubHomeView.swift` | 帖文/俱乐部 top tabs, create-club prompt pinned top, one list owned->joined->nearby, merchant locality status | tab picker padding, create prompt, warning colour (`.orange` -> `CYColor.warningText`), empty-events text on tokens |
| `pages/userinfo/userinfo` | none found | `App/SocialPublicProfileView.swift` | cy-profile identity head, missing-param empty state with back-home CTA | missing-link state centred as empty state (icon, title, detail, existing CTA + ids kept); identity head name/level on `CYTypography` (level uses monospaced digits) |
| `pages/member/index/index` | none found | `App/AccountView.swift` (+ `MemberHomeHeader.swift`) | mini page is only `<cy-profile viewer="self">`; iOS identity card + grouped links already follow it | NOT changed: the file is a ~240-line `Form` of integration links; restructuring blind risks regressions. Needs the `components/cy-profile` WXML pass plus a Cursor screenshot |

## Not done / deliberately left
- `HomeSearchTabParityViews.swift` (1472 lines), `MemberHomeHeader.swift`, `AccountView.swift`: not edited.
- Hero banner: mini-program full-bleed avatar/greeting overlay (`v3-hero-head`) lives in `HomeHeroHeaderSectionView`; not touched.
- Revolut-style numerals not applicable on these pages.
- Category tiles have no per-category icon (iOS `DiscoveryCategory` exposes none).

## Files touched
`App/GlobalSearchView.swift`, `App/HomeFeedView.swift`, `App/SquareBrowserView.swift`, `App/ClubHomeView.swift`, `App/SocialPublicProfileView.swift`, `App/SearchMapExplorerView.swift`, `docs/release/ui-report-ui-f01.md`
