# Receipt: `ui/cur-t1-2` — Template 1 and Template 2

Visual and layout only. Data bindings, grants, routes, and write gates are unchanged. `moneyPayments`, `payout`, `merchantWrites`, and `passwordLogin` were not touched. `App/RegionalLaunchConfiguration.swift`, `App/AppSession.swift`, `App/AppCompositionRoot.swift`, and `docs/release/contract-failing-baseline.txt` were not edited. No second color system, button, or card was added. Player surfaces stay on the dark canvas. Merchant surfaces stay on the light canvas.

Spec read from `origin/docs/design-md` at `b9193733e6539da09f016d134465b00c53a82317` (`DESIGN.md`, `design/tokens.yaml`). Those files were not copied onto this branch.

Mini-program structure read from `liboyang42-cpu/hengyin` `chengyinhub-xcx` (`pages/index/index`, `pages/template/index`, `pages/talent/list/index`). Copy that is not in the mini-program or the existing catalogs was left as the string already on the screen.

Purple `#7A5CFF` is not applied on these screens. Cards and the home search capsule no longer draw a perimeter stroke. Slate-blue inks were not introduced.

## Home — hero feed (Template 1)

- **Swift type:** `HomeFeedView` (`App/HomeFeedView.swift`), hero chrome in `HomeHeroHeaderSectionView` (`App/HomeSearchTabParityViews.swift`).
- **Mini-program route:** `pages/index/index`.
- **Section order:** featured banner (when the feed already has banners) → greeting / city / search → location-consent card → 编辑精选 → 附近活动 → 即将上线 → 主题 / 活动 feed → native Today card, city-pass card, and 继续探索 (kept, after the mini-program sequence).
- **Shared components:** `CYHeroBanner`, `CYTabs` (neutral underline), `CYEmptyState`, `CYLoadingStateView`, `CYSkeleton`, `CYStateLayout` (offline when the reader is not configured), `CYImageCard` / `HomeFeedCard`, `.cySecondary`.
- **States:** loading (`CYLoadingStateView` / `CYSkeleton` plus the existing 正在更新… lines), empty (`暂时没有主题` / `暂时没有活动`), error (named rail and stream retry on an elevated fill, no night stroke), offline (`CYStateLayout` `.offline`, identifier `homeFeed.configurationUnavailable`).
- **Fixture:** `d2-home` still hosts the rebuilt hero feed. `d2-home-offline` hosts the same view with `unavailableMessageKey` set, so the offline state shows. No network call was added.

## Square — shelf discovery (Template 2)

- **Swift type:** `SquareBrowserView` (`App/SquareBrowserView.swift`).
- **Mini-program route:** `pages/square/list/index` is merged into the talent feed in the mini-program. The iOS screen that still draws the square feed is `SquareBrowserView`. It was restyled in place. `SquareDetailView` was not restyled.
- **Section order:** large title 动态 → feed mode picker (same modes and `square.feed` control) → mode filters → 即将开始 strip when a reader is supplied → feed rows. Empty copy stays 广场还很安静 / 成为第一个发布创意路线的人吧, and a keyword miss stays the existing `square.empty` string.
- **Shared components:** `CYStateLayout`, `CYEmptyState`, `CYLoadingStateView`, `CYPillButton` (load more, secondary), existing `SquareXcxPostCard`.
- **States:** loading (`CYLoadingStateView`, `square.loading`), empty (`CYEmptyState`), error (`CYStateLayout` `.failure`, `square.error` / `square.retry`, server message kept verbatim), offline (`CYStateLayout` `.offline` for not configured, no connection, unavailable, and the closed-community gate). Unknown counts were not turned into 0.
- **Fixture:** `d2-square` still hosts the populated feed. `d2-square-empty` hosts `SquareFixtureHostView(scenario: .empty)`. No network call was added.

## Template list (Template 2)

- **Swift type:** `DiscoveryTemplateBrowserView` (`App/DiscoveryTemplateBrowserView.swift`).
- **Mini-program route:** `pages/template/index` (shelf lives in `tpl-shelf`).
- **Section order:** large title → staff read-only note when that scope is set → 主题 / 玩法 segmented control (`discovery.shelf`, kept as the system segmented control the flows already address) → search → category or pack chips → 推荐 / 其他模板 (topics) or 精选 / 最新 / 推荐 / 必玩 / 热门 (plays). `GameplayPresetSection` stays on this screen; its copy was already in the app and is not in the mini-program shelf, so it was not rewritten.
- **Shared components:** `CYFilterChip` (no chip stroke), `CYStateLayout`, `CYEmptyState`, `CYSkeleton`, `CYImageCard`, `CYSectionHeader`, `.cyDomainCard`.
- **States:** loading (`CYSkeleton` and the existing syncing row), empty (existing `discovery.emptyTopics` / `discovery.emptyGames` / `discovery.noResults`), error (`CYStateLayout` `.failure`, `discovery.retry` only when the existing reason is retryable), offline (`CYStateLayout` `.offline` for an unconfigured reader and for `DiscoveryTemplateUnavailable.offline`).
- **Fixture:** `template-topics` and `template-games` still host the populated shelf. `template-topics-offline` hosts `DiscoveryFixtureReader(scenario: .unconfigured)`. No network call was added.

## Talent list (Template 2)

- **Swift type:** `ClubHomeView` (`App/ClubHomeView.swift`). Loading, error, and offline for the club read still come from `ClubReadScreen`, which already uses `CYEmptyState` / `CYLoadSlot`. That shared reader was not edited, so other club screens keep their current chrome.
- **Mini-program route:** `pages/talent/list/index`.
- **Section order:** 发现 → 帖文 / 俱乐部 (`CYTabs` segmented, same labels `club.tab.top.feed` / `club.tab.top.club`) → on 帖文: author-delete line (em dash when square delete is not connected) → city-pass card → community feed; on 俱乐部: 创建你自己的俱乐部 → one list created → joined → nearby → existing directory / owned / events rows after the list.
- **Shared components:** `CYHeroHeader`, `CYTabs`, `CYEmptyState`, `CYListRow`, `CYClubPhotoCard`, `CYClubRowCard`, `CYSkeleton`, `.questifyPrimary` (the one create action; neutral fill, not purple). Event and empty plates use `bgElevated` with no stroke.
- **States:** loading (`club.loading` via `ClubReadScreen`, locality skeleton), empty (`还没有俱乐部` / `本城还没有俱乐部` / `club.emptyEvents`), error (`club.home.error`), offline (`club.unavailable` and merchant locality `.offline`).
- **Fixture:** `core-club-tab-facts` still hosts the populated tab. `core-club-tab-empty` hosts `ClubFixtureRootView(scenario: .empty)`. No network call was added.

## Screens not restyled

These exist and were left alone. Nothing was invented in their place.

- `pages/roam/index` → `RoamBrowserView` (task outside this pass).
- `pages/topic/catalog/index` → `PublicCatalogViews` (Template 2 in the spec, not in the named screen list).
- Map search, nearby, profile, settings, lists/inbox, chat.
- Templates 4, 5, 6, 10, 11, 12, and 13.

## Not found

The four named screens were already on this branch. No parallel screen was added.
