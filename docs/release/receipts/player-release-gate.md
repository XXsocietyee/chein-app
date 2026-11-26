# Receipt: Lane G player release gate (`claude/player-release-gate`)

Base: `origin/ui/combined-r7` 2446657fb. Brief: `docs/briefs/player-launch-lanes.md` (design/handoff-r2), Lane G.

## The flag

`Core/PlayerLaunch.swift`: `PlayerLaunch.merchantCenterEnabled` is `false` in Release and `true` under `DEBUG || TEST`
(fixtures, UI tests and the merchant console keep working in Debug). Hidden pages:

- every page under `pages/merchant/`, `pages/coop/`, `pages/cooperation/`, except `pages/merchant/profile/index`
  (商家公开主页, the public store page players open from topics, maps and search);
- `pages/topic/merchantapply/index` (商家报名承接, merchant onboarding to a topic);
- `pages/topic/merchantinfo/merchantinfo` (主题商家视角).

A hidden link becomes `.miniProgramPage(pages/index/index)` (`PlayerLaunch.gate`), which the reviewed page screen
hands off to the 首页 tab (`MPTabHandoff`, the same path as a normal home link). Nothing hidden crashes or shows an error.

## Entries guarded

| # | Surface | File | Guard |
|---|---------|------|-------|
| 1 | Deep links (chein://mp), universal links, push taps, journey links | `App/AppSession.swift` `receiveNativeIntent` | `NativeEntryPresentation(intent: PlayerLaunch.gate(intent))`; the only writer of `nativeEntry` |
| 2 | QR / share-code scan | `Core/ScanPayload.swift` | both `.entry(...)` returns pass `PlayerLaunch.gate` |
| 3 | Parity route table (`MPParityRoute(miniProgramPath:)`, used by deep-link entry and in-app routes) | `App/MPParityKit.swift` | hidden page → `.screen(pages/index/index)`; `myproject?scope=MERCHANT` opens the player variant |
| 4 | Reviewed page screen (every in-app `MPReviewedPageScreen(page:)`, 38 merchant/coop cases) | `App/MPReviewedPageScreen.swift` | hidden page → `playerHomeFallback`; `coupon?scope=MERCHANT` opens the player scope |
| 5 | Generated page route table | `tools/build_page_route_table.py` → `Core/MiniProgramPages.swift` | `MiniProgramPage(path:)` is nil for a hidden page in Release (→ `AppRoute.unsupported`); `isMerchantCenterPage` added |
| 6 | Merchant root console (auto-entry for merchant-role accounts) | `App/HomeSearchTabParityViews.swift` `MerchantRootModeCoordinator` | `resolvedRoute` always `.consumerTabs`; `requestMerchantMode` returns false; `makeModeSwitch` returns `.unavailable` |
| 7 | 玩家视角/商家工作台 switch row and banner | `App/AccountView.swift`, `HomeSearchTabParityViews.swift` | via #6 (`merchantRootModeSwitch.isAvailable == false`) and #8 |
| 8 | Me tab / Settings merchant rows: 商家概览, 商家项目, 商家工作台, payout account (merchant), 申请入驻 | `App/AccountView.swift` `AccountRoleSections` | `showsMerchant && PlayerLaunch.merchantCenterEnabled && …` |
| 9 | Me tab 合作 (cooperation) row | `App/AccountView.swift` | `WelcomeView.showsMerchantChoice && PlayerLaunch.merchantCenterEnabled` |
| 10 | Welcome 商家 sign-in choice | `App/WelcomeView.swift` | same |
| 11 | Settings 成为商家 | `App/SettingsAccountEntries.swift` | `if PlayerLaunch.merchantCenterEnabled` |
| 12 | Settings 商家工具 (BeGap merchant hub) | `App/SettingsView.swift` | `PlayerLaunch.merchantCenterEnabled && effectiveRole == "merchant"` |
| 13 | Home 更多玩法 banner 成为商家 | `Core/HomeSearchTabParity.swift` `playerActionBanners`, `App/HomeSearchTabParityViews.swift`, `App/SessionHomeFeedView.swift` | banner filtered; action `case "merchant_apply" where PlayerLaunch.merchantCenterEnabled` |
| 14 | Merchant denied state 申请入驻 | `App/QuestifyApp.swift` `merchantGateActions` | nil in Release |
| 15 | 我的项目 › 查看申请 (received coop applications) | `App/ProjectOwnedContentViews.swift` | `myProjectReceivedApplies` nil in Release |
| 16 | 消息 coop invite strip | `App/IMCoopInviteStripFactory.swift` | factory returns nil in Release |
| 17 | Club detail coop pool (可对接的活动 / 我的合作) | `App/ClubDetailR8Mounts.swift` `ClubCoopPoolMount` | whole mount behind the flag |
| 18 | Club apply, merchant account: 切换到商家端 / 查看商家入驻 | `App/ClubGovernanceViews.swift` | link behind the flag (返回 stays) |
| 19 | Club topic 更多 › 审核承接 and 招募 quick action (merchantinfo) | `App/ClubGovernanceViews.swift` | `canReviewUndertake` and the merchantinfo branch need the flag; 招募 falls back to the merchant list sheet |
| 20 | Coupon management deny state 申请成为商家 | `App/CouponManagementView.swift` | Release shows 返回 |
| 21 | Participation 去修改 (merchant apply editor) | `App/PlayerJourneyViews.swift` | button behind the flag |

Search: Settings search has no merchant rows. Global search keeps its 商家 tab: its rows open
`SearchMapMerchantDetailView`, the public store page, which has no merchant-center or coop link.

## Kept on (by decision)

- Player money flows (owner 11-26 "money on"): payment, refund, host-cancel refund, payout and withdrawal are not
  touched. `WalletOrganizerFinanceAccess` (主办分润, reads `api/coop/finance`) in `SessionWalletCommerceView.swift` /
  `WalletEarningsOverview.swift` is a player wallet read and stays.
- Public merchant pages: `PublicMerchantHomeView`, `pages/merchant/profile/index`, `pages/play/merchant/index`
  (探店日 play node), merchant reviews, nearby merchants and map store details.
- `subpackageMember/coupon/coupon` stays for players (the merchant scope is dropped in Release, #4).
- Club settlement and club payout pages (clubs are not merchants).

## Merchant-only screens (unreachable once the entries above are hidden)

`CoopRelationDiscoveryView`, `CooperationBrowserView`, `CooperationFlowWorkbench`, `IMCoopInviteStripView`,
`MerchantCoopCenterSessionBinding`, `MerchantDecorR8Parity`, `MerchantHomeView`, `MerchantPersonalIncomeHandoff`,
`MerchantReading`, `NativeEntryLandingView` (`SessionMerchantMarketingDestination`), `OrphanScreenMounts`,
`SubscribeMessageTapScreens` (`.coopList`, only from the gated parity route). They stay compiled for Debug.

## Tests

- `Tests/CoreTests/PlayerReleaseGateTests.swift` (Swift, `QuestifyCoreTests`): pins the 60 hidden pages of the route
  table exactly, player pages stay visible, hidden deep links (internal path / push) fall back to the home intent, the
  home banner list drops 成为商家. Runs under DEBUG, so each check passes `enabled: false`.
- `Tests/ContractChecks/test_player_release_gate.py` (Python, 9 tests): the flag is false in Release and declared once;
  every intake passes the gate; route tables fall back home; root merchant mode is off; each guard above is present;
  **any App/ file that opens a merchant/coop screen or names a hidden page and is not classified fails**; the Swift
  test pins the same set as the route table; no money switch is gated.

Not run here: Swift compile and the Swift test (no compiler in the cloud). `python3 tools/check_scaffold.py` PASS.

## Hidden pages (route table, Release)

- `pages/coop/finance/index`
- `pages/coop/invite-detail/index`
- `pages/coop/invite/index`
- `pages/coop/list/index`
- `pages/coop/nearby/index`
- `pages/coop/settlement-detail/index`
- `pages/coop/withdraw/index`
- `pages/coop/withdraw/records/index`
- `pages/cooperation/detail`
- `pages/cooperation/finance`
- `pages/cooperation/index`
- `pages/merchant/aftercare`
- `pages/merchant/aftercare/detail/index`
- `pages/merchant/aftercare/index`
- `pages/merchant/aiInsight`
- `pages/merchant/apply`
- `pages/merchant/apply/index`
- `pages/merchant/brand`
- `pages/merchant/cityNode`
- `pages/merchant/citynode/create/index`
- `pages/merchant/citynode/index`
- `pages/merchant/coop-center/index`
- `pages/merchant/coupons`
- `pages/merchant/crm-campaigns/index`
- `pages/merchant/customer/detail/index`
- `pages/merchant/customer/index`
- `pages/merchant/customers`
- `pages/merchant/decor/ai-npc/index`
- `pages/merchant/decor/coop-setting/index`
- `pages/merchant/decor/gallery/index`
- `pages/merchant/decor/index`
- `pages/merchant/decor/perks/index`
- `pages/merchant/game-node/index`
- `pages/merchant/index`
- `pages/merchant/index/index`
- `pages/merchant/ledger`
- `pages/merchant/ledger/batch-detail/index`
- `pages/merchant/ledger/index`
- `pages/merchant/ledger/order-detail/index`
- `pages/merchant/marketing`
- `pages/merchant/marketing/ai-insight/index`
- `pages/merchant/marketing/index`
- `pages/merchant/operations`
- `pages/merchant/operators`
- `pages/merchant/payout-account/index`
- `pages/merchant/predict/index`
- `pages/merchant/profile`
- `pages/merchant/relation`
- `pages/merchant/relation/index`
- `pages/merchant/reviews`
- `pages/merchant/reviews/index`
- `pages/merchant/settlement`
- `pages/merchant/store/index`
- `pages/merchant/team/index`
- `pages/merchant/todo`
- `pages/merchant/verify`
- `pages/merchant/verify-records/index`
- `pages/merchant/workbench`
- `pages/topic/merchantapply/index`
- `pages/topic/merchantinfo/merchantinfo`
