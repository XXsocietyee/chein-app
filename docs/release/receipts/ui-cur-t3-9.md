# Receipt: `ui/cur-t3-9` — Template 3 and Template 9

Visual and layout only. Bindings, location grants, and money switches are unchanged. `RegionalLaunchConfiguration`, `AppSession`, `AppCompositionRoot`, and `docs/release/contract-failing-baseline.txt` were not edited. No background-location entitlement. No second color system, button, or card. Player surfaces stay on the dark canvas. Merchant surfaces stay on the light canvas. The IM screens keep the player domain lock they already had.

Spec read from `origin/docs/design-md` at `b9193733e6539da09f016d134465b00c53a82317` (`DESIGN.md`, `design/tokens.yaml`). Those files were not copied onto this branch.

Mini-program structure read from public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `master` (`316f717d1040af392647891dbe9a8b01a41b290f`): `subpackageB/pages/im/list`, `subpackageB/pages/im/chat`, `pages/search2`, `pages/search2/result`, `pages/searchmap`, `subpackageRoam/nearby`. Copy that is not in the mini-program or the existing catalogs was left as the string already on the screen.

Purple `#7A5CFF` is only the existing result spinner (`CYColor.resultSpinner`) on the search-field spinner and the map result capsule while loading. Cards and pills do not draw a perimeter stroke. Slate-blue inks were not introduced. `CYRadius.card` was not used. Unknown unread and unknown search totals stay an em dash.

## Messages — conversation list (Template 9)

- **Swift type:** `MessagingHomeView` (`App/MessagingHomeView.swift`), rows in `IMInboxRow` (`App/IMInboxViews.swift`).
- **Mini-program route:** `subpackageB/pages/im/list/index`.
- **Section order:** nav title 消息 → scope control (全部 / 频道 / 私信, same `MessagingSegment` cases) → prediction entry and coop-invite strip when the host already injects them → refresh/error from `MessagingReadScreen` → empty or day groups (今天 / 昨天 / 更早) or channel groups (主题 / 俱乐部 / 队伍).
- **Shared components:** `CYEmptyState`, `CYPillButton` (the one 去发现找人 action), `CYStatusChip` (官方), `CYColor` / `CYTypography`. The scope control stays a system segmented picker so `messaging.list.scope` remains a segmented control. The glass stroke around it is gone.
- **States:** loading, empty (`messaging.empty.all` / `im.inbox.emptyGroup` / `im.inbox.emptyDirect`), error, and unconfigured (`messaging.list.unconfigured`) stay on `MessagingReadScreen`. Unknown unread is `—`.
- **Fixture:** `d2-inbox` still hosts the populated list. `d2-inbox-empty` hosts `MessagingFixtureReader(.empty)`. No network call was added.

## Messages — thread (Template 9)

- **Swift type:** `MessagingHistoryView` (`App/MessagingHistoryView.swift`), bubbles in `ChatMessageBubble` (`App/ChatMessageBubble.swift`).
- **Mini-program route:** `subpackageB/pages/im/chat/index`.
- **Section order:** inline title → hero name → 我的举报 when the host injects it → load-earlier row → loading / missing / failed / unknown / empty → bubbles (system notices full width, own messages trailing on the primary fill) → composer.
- **Shared components:** `CYEmptyState`, `CYSkeleton`, `CYListRow`, `ChatMessageBubble`. Own bubbles use `CYColor.actionPrimaryBg` / `actionPrimaryFg`. The hero name wraps.
- **States:** loading (`messaging.history.loading`), empty (`messaging.history.empty`), unknown (`im.chat.unknown`), error and unconfigured (`messaging.history.unconfigured`) stay distinct.
- **Fixture:** the populated thread is still `MessageActionFixtureHost` / module `composer`. The empty list fixture above is the empty state for this pass. No network call was added.

## Club channel thread (Template 9)

- **Swift type:** `ClubChannelMessagingView` (`App/ClubChannelMessagingView.swift`). It already exists. `d4-channel-chat` hosts it.
- **Mini-program route:** no separate club-chat page. `pages/club/detail` says 进入群聊 was removed from the header; the thread is the native channel screen.
- **Section order:** channel list or the open thread (rules gate, header, transcript, composer). Sender names and message bodies wrap. One primary remains the existing send / rules action.
- **States:** the moderation banner, rules gate, and send phases (sending / failed) were already distinct and were left in place.

## Search entry and results (Template 3)

- **Swift type:** `GlobalSearchView` (`App/GlobalSearchView.swift`), result cards in `SearchMapCard` (`App/SearchMapComponents.swift`).
- **Mini-program routes:** `pages/search2/index` and `pages/search2/result/index`. The result page is the same screen after a search. No second type was added.
- **Section order:** 搜索 field and 筛选 → 搜索 (the one primary, only when the query can search) → 搜索历史 → 推荐搜索 → 类别 (hidden only when the directory is known empty) → 在地图上找活动与主题节点. Results replace suggestions: kind chips (全部, then each kind with its count or `—`) → retention / failure notes → rows → 内容已加载完 / 刷新搜索结果.
- **Shared components:** `CYLoadingStateView`, `CYSkeleton`, `CYEmptyState`, `CYColor.bgElevated` cards, borderless `searchNightPill`. The field spinner uses `CYColor.resultSpinner`.
- **States:** loading, empty (`globalSearch.empty`), error (`searchMap.failed` and partial failure), offline example (`searchMap.offline`), unconfigured (`searchMap.notConfigured`), unknown (`searchMap.unknown`).
- **Fixture:** `d2-search-results` still hosts a populated search. `d2-search-offline` hosts `SearchMapFixtureReader(scenario: .unconfigured)`. No network call was added.

## Map search (Template 3)

- **Swift type:** `SearchMapExplorerView` (`App/SearchMapExplorerView.swift`), with `SearchMapActivityCard`, `SearchMapResultsCapsuleView`.
- **Mini-program route:** `pages/searchmap/index`, already merged into search as the map mode. The explorer was restyled in place.
- **Section order:** full-bleed map, area and filter controls, result capsule, selected-place summary, list sheet. Map chrome stays full-bleed. The capsule fill is `CYColor.bgGlass`. The selected summary is a flat elevated card. Activity cards no longer draw a stroke.
- **States:** loading capsule (result spinner), empty, failed, and offline banner stay distinct.
- **Fixture:** `d2-search` still hosts `SearchMapFixtureHostView`. No network call was added.

## Nearby (Template 3)

- **Swift type:** `NearbyTeamsView` (`App/NearbyTeamViews.swift`), list and map pieces in `App/NearbyTeamMapViews.swift`, layer chips in `NearbyMapDiscoveryControls` (`App/NearbyMapDiscoveryView.swift`).
- **Mini-program route:** `subpackageRoam/nearby/index`.
- **Section order:** 附近的队伍 → 附近 / 我的 → layer chips (全部 / 主题队伍 / 地点玩法 / 商家) when discovery sources exist → count → map or list → team card → 范围 / 我的队伍. The glass stroke on the layer picker is gone. Headings wrap. Agree stays the primary; 拒绝 is secondary.
- **States:** loading (`CYLoadingStateView`), empty (`nearby.empty`), issue card (login / denied / failed), and discovery offline (`nearby.map.eventsUnavailable` / `nearby.map.poisUnavailable`) stay distinct.
- **Fixture:** `nearby-empty` hosts `NearbyTeamFixtureRoot(emptyMine: true)`. The launch argument `--nearby-team-fixture-empty-mine` still opens the same empty mine. No network call was added.

## Screens not restyled

These were left alone. Nothing was invented in their place.

- `HomeFeedView`, `HomeSearchTabParityViews`, `SquareBrowserView`, `DiscoveryTemplateBrowserView`, `ClubHomeView`.
- Profile, settings, and the template-8 lists.
- `RoamBrowserView` (`pages/roam/index`).

## Not found

Every named route already had a screen. `pages/search2/result/index` and `pages/searchmap/index` are states of `GlobalSearchView` and `SearchMapExplorerView`, not extra types.
