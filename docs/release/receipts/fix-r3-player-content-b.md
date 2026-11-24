# Receipt — fix/r3-player-content-b (wave ×10, Claude F-agent, player-content half b)

- **Brief:** `design/handoff-r2:docs/briefs/wave-x10.md`. Base `origin/ui/combined-r7` @ 7fdfad1f1.
- **Half b** = the second 15 of the 30 round-1 audit pages: C2 baoming, C3 activity list, C4 official-detail, C5 official-inbox, C6 official-mine, C7 official-organizer, D1 myproject, D2 infomation, D3 infomationdetail, D4 income-detail, D5 earnings, D6 analysis, D7 video-bounty, D8 im/list, D9 im/chat.
- **Gap sources used:** r7 fix queue (`audit/parity-r7-player-content:docs/audit/parity-r7/player-content.md`, all Claude-owned lines for C2–D9), r7 review (`review/r7-rev-b` B-14), round-1 audit and `fix-parity2-player-content.md` deferrals (all carried into the r7 queue).
- **Restyle merged first** (they had already changed files in this half): `restyle/r1-player-front`, `restyle/r2-club-social`, `restyle/r3-merchant-creator`, `restyle/r4-me-account`. One conflict, `Tests/ContractChecks/test_global_chrome_domain_contract.py` (both sides' sheet lists kept).
- **Skipped as in flight:** `restyle/*` (visual only), `gap/g1-player` (deck-preview cover only), `gap/g2-ops`, `port/*`. No `cursor/core-player-content` branch existed at start.
- **App layer only.** No Core type changed. Strings go in `docs/port/strings/fix-r3-player-content-b.json` (xcstrings format), not in `Localizable.xcstrings`.

## Fixed

| id | page | what changed | files |
|---|---|---|---|
| R7-PC-C2-3 | C2 | `baoming?ticketId=` preselects that ticket in the sheet (environment value, so the sheet call stays pinned); the sheet no longer auto-opens when `signUpBlock` is set | `App/MPReviewedPageScreen.swift`, `App/ActivityDetailView.swift`, `App/SessionRegistrationSheet.swift`, `App/RegistrationSheetView.swift` |
| R7-PC-C2-4 | C2 | An activity with no ticket shows the activity and a `ContentUnavailableView` 暂无可用票; no quote request, no checkout bar | `App/RegistrationSheetView.swift` |
| R7-PC-C3-1 | C3 | `OfficialEventsBrowserView` has no own `NavigationStack`; the 首页 sheet and the fixture host wrap it; the deep link pushes it with `onClose: nil` (system back, no dead 关闭) | `App/OfficialEventsBrowserView.swift`, `App/SessionHomeFeedView.swift`, `App/OfficialEventFixtureSupport.swift`, `App/MPReviewedPageScreen.swift` |
| R7-PC-C3-2 | C3, C6 | Status is a `CYStatusChip` whose tone follows MP `activity-status.js` (报名中 info, 进行中 success, others neutral) with `play.fill` when live; same on the 我发布的 owner row | `App/OfficialEventComponents.swift` (`OfficialEventStatusStyle`), `App/OfficialPrivateViews.swift` |
| R7-PC-C3-3 | C3 | Tab 即将上线; empty state is one title line per tab (MP `EMPTY_COPY`), the search keeps its 换个关键词 line; upcoming uses the clock glyph | `App/OfficialEventsBrowserView.swift`, strings fragment |
| R7-PC-C4-2 | C4 | Source CTA (topic link / waiting-ended text / roam jump) is pinned in a `safeAreaInset` bottom bar; the 暂时没有需要你操作的事项 row is gone and the participation section only renders when there is an action | `App/OfficialEventDetailView.swift`, `App/OfficialActionViews.swift` |
| R7-PC-C4-3 (rewards) | C4 | 活动奖励 section hidden when no reward is configured | `App/OfficialEventDetailView.swift` |
| R7-PC-C4-5 | C4 | zh `official.detail` = 活动详情 | strings fragment |
| R7-PC-C5-1 | C5, C6 | Inbox and 我发布的 deep links pass `onLogin: signIn` | `App/MPReviewedPageScreen.swift` |
| R7-PC-C5-2 (failure part) | C5 | After the review sheet closes on a rejected/unknown write, the card shows 这次操作没有完成 + 重试 (reopens the same review) | `App/OfficialActionViews.swift` |
| R7-PC-C5-3 | C5 | One inset card per invite: plain-text title (not a `CYListRow`), its 接受/拒绝/退出 buttons inside the same card | `App/OfficialPrivateViews.swift`, `App/OfficialActionViews.swift` (`embedded`) |
| R7-PC-C6-3 | C6 | Tapping a broadcast card reads its 复盘 in place: 正在读取复盘… → 站内触达 N 人 · 点击 M 人, or 复盘没读到，点一下重试; the stats screen no longer prints unknown keys | `App/OfficialPrivateViews.swift` |
| R7-PC-C7-1 | C7 | Pause presets are chips (tap again to clear); every text field clamps to 200 with an n/200 counter | `App/OfficialOrganizerConsoleView.swift` |
| R7-PC-C7-2 | C7 | Denied state has 返回; 最近恢复说明 shows while running (暂停原因 while paused); title is a catalog key | `App/OfficialOrganizerConsoleView.swift` |
| R7-PC-D1-1 (tab root) | D1 | 发布 tab root 我的项目 row opens `SessionCreatorProjectsView` (same screen as the deep link and ⋯ menu) | `App/PublishRootContent.swift`, `App/SessionPublishingModesView.swift` |
| R7-PC-D1-5 | D1 | Row menu 收到的申请 (MP `canViewApplies`: topic with clubOpen / merchantOpen / *Accepted) pushes `CooperationBrowserView(initialDirection: .received)` with the entry scope | `App/MyProjectTabViews.swift`, `App/ProjectOwnedContentViews.swift` |
| R7-PC-D1-6 (partial) | D1 | Card address is a button that opens Maps (address search; see left items) | `App/MyProjectTabViews.swift` |
| R7-PC-D1-7 | D1 | Signed-out: 登录后查看我的项目 + 登录 (switches to 我的, where sign-in lives) | `App/CreatorContentViews.swift` |
| R7-PC-D2-1 (square part) | D2 | 去发布广场 / 更多玩法 switch to the 发布 tab (MP `switchTab`); the deep-link host dismisses the native entry first. Hosts without tabs keep the catalog sheet | `App/SocialGuideTemplateSection.swift`, `App/MPReviewedPageScreen.swift` |
| R7-PC-D2-3 | D2 | Loading is `CYLoadingStateView(rows: 3)`; failure is a `CYEmptyState` with a primary 重试; raw `.headline/.subheadline/.caption` → `.cyText` | `App/SocialGuideTemplateSection.swift` |
| R7-PC-D3-1 | D3 | Bar shows the article title once loaded (玩法详情 while loading) | `App/SocialGuideViews.swift` |
| R7-PC-D3-4 | D3 | Removed state has 返回玩法列表 | `App/SocialGuideViews.swift` |
| R7-PC-D4-2 | D4 | Top-level 收益 / 分佣 segmented control while the allocation read is not hidden; the income list stays mounted (MP L09-121); 分佣 shows `G6RevenueAllocationsView` or 收益暂不可用 + 重试 | `App/WalletCommerceViews.swift` |
| R7-PC-D4-3 | D4 | The ledger's 全部/收入/支出 picker is hidden on 收益明细 (one filter row) | `App/WalletCommerceViews.swift` |
| R7-PC-D4-4 | D4 | Next page loads when the end scrolls in; 加载更多 stays as fallback | `App/WalletCommerceViews.swift` |
| R7-PC-D4-5 | D4 | Merchant entry (`MerchantPersonalIncomeHandoff`, deep link `theme=merchant`) uses merchant chrome and no 分佣 tabs | `App/WalletCommerceViews.swift`, `App/MerchantPersonalIncomeHandoff.swift`, `App/MPReviewedPageScreen.swift` |
| R7-PC-D5-2 | D5 | 更多 = 本人俱乐部结算 · 个人收款 · 提现记录 · 邀请记录 (+ app-only 积分 / 商城 when gated on); 分析 and 我的资产 no longer repeat | `App/WalletCommerceViews.swift`, `App/SessionWalletCommerceView.swift` |
| R7-PC-D5-3 | D5 | A loaded zero balance (non-merchant) shows only 还没有收益 + 去发布路线 under the actions; month and assets sections hidden | `App/WalletCommerceViews.swift` |
| R7-PC-D5-4 | D5 | `t("…","…")` literals on the earnings home → catalog keys (existing keys reused; 2 new) | `App/WalletCommerceViews.swift`, strings fragment |
| R7-PC-D6-2 | D6 | Month chart has an `accessibilityChartDescriptor` (Audio Graph, spoken amounts) instead of `accessibilityHidden` | `App/WalletIncomeAnalysisView.swift` |
| R7-PC-D7-2 | D7 | Submission URL is selectable and has a 复制 context menu | `App/VideoBountyView.swift` |
| R7-PC-D7-3 | D7 | Stale "Logic stub" comment replaced | `App/VideoBountyView.swift` |
| R7-PC-D8-2 | D8 | Inbox row shows the counterparty's https avatar; system rows and missing/failed images keep the generated art | `App/IMInboxViews.swift` (`IMRemoteAvatar`) |
| R7-PC-D8-3 | D8 | Merchant account inbox (and the merchant ledger inbox) uses merchant chrome | `App/MessagingHomeView.swift`, `App/SessionMessagingEntry.swift`, `App/MerchantLedgerInboxNavigation.swift` |
| R7-PC-D8-4 | D8 | Day headers use `messaging.day.today/yesterday/earlier` | `App/MessagingHomeView.swift`, strings fragment |
| R7-PC-D9-4 | D9 | Chat bar avatar (counterparty) and bubble avatar (`senderAvatar`) via `IMRemoteAvatar`, generated art fallback | `App/MessagingHistoryView.swift` |
| review B-14 | D8, D9 | `MessagingConversationName` puts `IMConversationTitlePolicy` first: a type-2 conversation is always 城瘾小助手 (list rows, chat title) | `App/MessagingComponents.swift` |

## Left, with reasons

| id | reason / request |
|---|---|
| R7-PC-C2-2 | **Core request (Cursor):** `RegistrationWaitlistStatus` does not decode `reservationState`, and its guard `joinAllowed == (eligibility == .eligible)` throws `malformedResponse` on the host-required shape (`ELIGIBLE` + `waitlistJoinAllowed:false`, MP `pages/activity/utils/host-reservation.js:35-37`). Add `reservationState` (+ relax the guard); then the App can show 主持预约 / 请求主持 / 撤销申请 outside the waitlist card. |
| R7-PC-C4-3 (price row) | 价格 暂无价格信息 row kept: pinned by `Tests/AppUITests/OfficialEventFlowTests.swift` (`expectUnspecifiedPrice()` ×2) and two contract checks (`test_official_detail_parity_w2_06`, `test_official_preference_ui_regressions`). Cursor: retire those pins, then delete the row. |
| R7-PC-C5-2 (busy part) | The write runs in the review sheet, which shows its own busy state; there is no per-card in-flight phase to show under the sheet. |
| R7-PC-D1-1 (pushed menu) | `PublishingModesView` (pushed publish menu) still opens `PublishingProjectsView`: the file prefix is SHA-pinned by `test_activity_publishing_wizard.test_untouched_publishing_slices_and_activity_handoff`. `PublishingProjectsView` is not retired (fixtures and that menu use it). |
| R7-PC-D1-4 | Inline template shelf rows need `TemplateAuthoringMineView` split into embeddable sections (its List, `.task`, `onDisappear` shelf lifecycle and review sheet); too risky without a compiler. The 模板 tab keeps its 查看我的节点玩法 link. |
| R7-PC-D1-6 (coordinates) | **Core request (Cursor):** `CreatorContentProject` has no `latitude`/`longitude` (MP passes `data-lat/lng`). The App opens a Maps address search until those fields exist. |
| R7-PC-D2-1 (detail push) | Template detail stays a sheet: the presenter lives on a `Section` inside the guide's `List`, where `navigationDestination` is ignored (lazy container). Needs the selection model lifted to `SocialPlayGuideView`. |
| R7-PC-D3-3 | **Core request (Cursor):** no public universal-link builder for `subpackageA/pages/infomationdetail/infomationdetail?id=` (`PublicContentShareLink` only builds parser-typed paths). Add `PublicContentShareLink.information(id:)`; then a toolbar `ShareLink` is one line. |
| B-14 (asset) | The type-2 avatar glyph (`cy-icon connect`) and the MP default avatar `/images/d_profile.png` need the C7 MP-asset set (`cursor/mp-assets` does not exist yet). |
| Cursor-owned queue lines | R7-PC-D1-2, D1-3, D4-1, D6-1, D9-1, D9-2, D2-2 (not App layer). |
| Gemini-owned | R7-PC-C2-1, C4-1, C6-2, D3-2, D9-3 (parked `App/MPGap/**`). |
| Owner decisions | R7-PC-C4-4, C6-1, D2-4, D3-5, D5-1, D7-1, D8-1. |

## Tests and pins touched (Cursor layer; minimal, each tied to an audited change)
- `Tests/ContractChecks/test_global_chrome_domain_contract.py`: merge resolution (restyle r1 + r4 sheet lists both kept).
- `Tests/ContractChecks/test_official_event_contracts.py`: the empty-state pin now asserts the one-line (non-search) empty copy (R7-PC-C3-3).
- `Tests/ContractChecks/test_wallet_income_analysis_closure.py`, `test_assetcenter_analysis_page_ready.py`, `docs/release/ui-strings-subpackageA-pages-assetcenter-earnings-index.json`: 分析 / 我的资产 identifiers repointed from the removed 更多 rows to the quick action and the section (R7-PC-D5-2).

## Local verification (no compiler in the cloud)
- Contract checks (`python3 -m unittest discover -s Tests/ContractChecks`, 6064 tests), branch vs merge base `8870f522d`: base 196 FAIL/ERROR, branch 197; 0 fixed-then-broken, exactly 1 new (the strings-fragment check below).
- Expected new failure until the integrator merges the strings fragment: `test_official_event_contracts.OfficialSourceChecks.test_every_static_user_facing_key_has_two_languages` (new keys live only in `docs/port/strings/fix-r3-player-content-b.json`, per the brief).
- `tools/check_typography_lint.py`: PASS (unchanged counts). `tools/check_scaffold.py` fails identically on the base (project file not regenerated); no new Swift files or folders were added.
- APIs used were grepped on the branch before use: `CYStatusChip`, `CYFilterChip(verbatim:)`, `CYEmptyStateView(actionTitle:action:)`, `RootTabSwitch`, `G6RevenueAllocationsModel`, `ClubSettlementMineView`, `ClubPayoutReceiverView(clubID:mine:)`, `CooperationBrowserView(embedsNavigationStack:)`, `LocalPasteboard.copy`, `OfficialEventReading.broadcastStats(id:)`, `OfficialActionCoordinator.state`.

## Acceptance
- Fixture routes: `docs/port/accept/f-player-content-b.txt`.
- Acceptance run: not started from this session (no `gh` workflow access here); the coordinator compiles and returns exact errors.

## Round 2 (2026-11-24, brief `design/handoff-r2:docs/briefs/fix-r3-round2.md`)

- **Sync:** merged `origin/ui/combined-r7` (Core K1–K10, W1 wiring, C7 MP assets). One conflict, `tools/check_typography_lint.py`, resolved to the r7 side (newer). Merged again before the final push.
- **Cursor call sites:** there is no `cursor/wire-player-content` branch. `cursor-r7-wiring.md` lists only play-runtime mounts (cast, P4 stage, arrival, visit config), none on C2–D9 pages, so nothing here touches them. The App callers that `cursor-core-player-content.md` hands to the F-agent were done or are listed below.

### Fixed in round 2

| id | page | what changed | files |
|---|---|---|---|
| Owner decision 9 (two-decimal money) | D4, D5, D6 | Wallet money pads to `MoneyDisplay.minimumFractionDigits()` (¥12.50) through one shared `WalletNumberLocalization.money`. It never rounds, keeps the exact-decimal roundtrip guard and leaves points unpadded. It covers the balance hero, the asset rows, ledger balance and signed rows, and the analysis totals. The registration sheet already used `RegistrationUIMoney` (two places). | `App/WalletNumberLocalization.swift`, `App/WalletCommerceViews.swift` |
| R7-PC-D4-1 (P1) | D4 | With no coop-finance read grant (`allowsRead() == false`), the 主办分润 tab bar is gone, so there is no tab that can only show "—". | `App/WalletCommerceViews.swift` |
| R7-PC-D6-1 | D6 | The analysis reads `api/user/balance/list` in 200-row pages (`WalletAnalysisPagingPolicy.mpPageSize`). It stops when the oldest row on a full page falls before the six-month window (Beijing month start minus 5), and the 10-page budget stays as a fence. The budget copy now says the latest 2,000 records. | `App/WalletIncomeAnalysisReader.swift`, `Resources/WalletIncomeAnalysisRead.xcstrings`, `docs/release/ui-strings-subpackageA-pages-assetcenter-analysis-index.json` |
| R7-PC-D1-2 | D1 | The row menu 取消 on an activity calls `MyProjectMutationModel.beginActivityCancel(id:title:)`, which reads `cancel_preview` first. The confirm sheet shows `confirmationText` (「将给 N 位已付款玩家全额退款」), and a missing count shows the model's failure without opening the confirm. The write stays behind its existing grant. | `App/MyProjectTabViews.swift`, `App/MyProjectMutationViews.swift` |
| review B-23 | D9 | `im.reply.systemNotice` in the reply-policy fragment = 城瘾小助手不接收回复 / "Chengyin Assistant does not accept replies" (matches `p5.json`). `messaging.system` en = "Chengyin Assistant" (fragment). | `Resources/IMConversationReplyPolicyLocalizations.fragment.json`, strings fragment |
| B-14 (asset part) | D8, D9 | A person with no avatar shows the MP `/images/d_profile.png`. The system row keeps its glyph: the MP `cy-icon bell/connect` is an icon font, not a shipped image. | see MP assets |

### MP assets applied (`docs/mp-assets/mapping.md`)

| asset | MP source | app place |
|---|---|---|
| [x] `MPAsset.BannerCover.coverRoute` | `pages/activity/baoming/baoming.wxml:85` | registration ticket card cover fallback (`App/RegistrationSheetView.swift`, aspect-fit on the neutral tile like `cy-cover-fb`) |
| [x] `MPAsset.BannerCover.coverRoute` | `pages/activity/list/index.wxml:51` | official event card with no cover (`App/OfficialEventComponents.swift`) |
| [x] `MPAsset.BannerCover.coverRoute` | `subpackageB/pages/im/chat/index.wxml:92` | IM route/signup card with no cover (`App/IMCardPreviewViews.swift`) |
| [x] `MPAsset.BrandLogo.cyLogoMark` | `pages/activity/official-detail/index.wxml:31` | 城瘾官方 organizer row on official detail (`App/OfficialEventDetailView.swift`) |
| [x] `MPAsset.BannerCover.subpackageAImagesRouteFreeCover` | `subpackageA/pages/myproject/index.wxml:38` | 我的项目 card cover fallback (`App/CreatorContentViews.swift`) |
| [x] `MPAsset.AvatarDefault.dProfile` | `subpackageB/pages/im/list/index.wxml:141`, `im/chat/index.wxml:68,160` | inbox row, chat bar and bubble avatar fallback; the bubble also falls back to the counterparty avatar first, as the MP does (`App/IMInboxViews.swift`, `App/MessagingHistoryView.swift`) |
| [ ] `MPAsset.EmptyState.noData` | `pages/activity/list/index.js:45` | Not applied: that line is a comment in the MP saying this page must **not** use `no_data.svg`; the page uses `cy-empty` glyphs. |
| [ ] `MPAsset.BannerCover.routeCityCover` | `subpackageA/pages/myproject/index.wxml:72,83` | Template shelf rows are not inline on the app (R7-PC-D1-4 left), so there is no row to put it on. |
| [ ] `MPAsset.BannerCover.subpackageBImagesRouteFreeCover` | `subpackageB/pages/im/chat/index.wxml:237` | That is the composer `+` route picker, which is Gemini's parked `IMComposerPlusMenuButton` (R7-PC-D9-3). |

- Every other glyph on these pages is a `cy-icon` font glyph (arrow-right, pin, flag, gift, bell, connect, check, warning, plus) or a system control, so they stay SF Symbols.
- **Shared components:** `E1CoverArt` (`fallbackImage`, `fallbackFills`), `QuestifyImageEntityCard.fallbackArtwork(_:)` and `CYImageCard.fallbackArtwork(_:)` gained optional, additive fallbacks. Every other caller is unchanged.

### Left, with reasons (round 2)

| id | reason / request |
|---|---|
| R7-PC-D9-2 (App row) | **Composition request (Cursor W1):** no `CommunityMemberReportClient` exists on `AppSession`, and its `writesEnabled` defaults to false with no grant. A 举报对方 row would open a sheet whose submit always throws `notConfigured`, which is a dead end. Once the session owns a client and a grant exists, add a `peerReport` choice to `MessagingSafetyMenuButton`'s option list from `IMSafetyMenu.offersPeerReport` and `im.chat.more.reportPeer` (keep `IMSafetyMenu.Item` unchanged, as the K receipt asks). |
| R7-PC-D9-1 | **Core request (Cursor):** the ordinary read is only reachable through `reviewOrdinaryRead()` followed by an explicit confirm. `dispatchOrdinaryRead` is private, and `IMReadReceiptTriggerPolicy` defaults to `.explicitUserActionOnly`. A silent post after the first page needs a public `autoMarkReadAfterFirstPage()` on the coordinator, gated by that policy, which stays off by default. |
| R7-PC-C2-2, R7-PC-D1-6 (coordinates), R7-PC-D3-3 | The round-1 Core requests are still open on r7: `RegistrationWaitlistStatus` has no `reservationState`, `CreatorContentProject` has no `latitude`/`longitude`, and `PublicContentShareLink.information(id:)` does not exist. |
| R7-PC-D1-1 (pushed menu), R7-PC-D1-4, R7-PC-D2-1 (detail push), R7-PC-C4-3 (price row) | Unchanged from round 1. The pins still exist (`test_activity_publishing_wizard`, `test_social_guide_templates` sheet structure, `OfficialEventFlowTests`). |
| review B-02…B-09, B-15, B-16, B-21, B-22, B-24, B-25 | These are topic, ticket-wallet, settle, club or Core rows (P3/P5), not on pages C2–D9. They are left for their owners. |
| review rev-a, rev-c | rev-a covers play runtime only (Cursor). rev-c's Claude rows are integrator and mount rows (F-C02 MPGap glob, F-C21 club money gate), not this half. |
| Owner decisions 8, 10, 7 | The arrival lock, the game-kit pilot gate and cast fixtures concern play pages; none is on C2–D9. Decisions 3, 6, 12: no money write was added or enabled here. Registration pay and withdrawal stay on their existing TEST-only gates. |

### Tests and pins touched in round 2 (each tied to a change above)
- `Tests/AppUnitTests/WalletNumberLocalizationTests.swift`: three signed-money expectations go from `1,234.5` to `1,234.50` (owner decision 9). Exact four-place values (`1,234.5678`) and points are unchanged.
- `Tests/AppUnitTests/WalletIncomeAnalysisClosureTests.swift`: the harness and counts scale with `WalletIncomeAnalysisAccumulator.pageSize` (now 200). Row ids start at 100 000 so twelve pages stay positive, and `createTime` is "now" in Beijing time so the six-month cutoff never ends a read early. Each test asserts the same stop reasons as before.
- `Tests/ContractChecks/test_wallet_income_analysis_closure.py`: the `pageSize = 20` pin is now `pageSize = WalletAnalysisPagingPolicy.mpPageSize`.

### Local verification (round 2)
- Contract checks: branch vs `origin/ui/combined-r7`, 200 → 202 FAIL/ERROR. Both new failures are the expected strings-fragment ones: `test_official_event_contracts…two_languages` and `test_localization_key_catalog_contract…missing_from_every_catalog`. The 8 keys it lists are all in `docs/port/strings/fix-r3-player-content-b.json`.
- `tools/check_typography_lint.py`: PASS. No new Swift files or folders.
- APIs grepped on r7 before use: `MPAsset.BannerCover.coverRoute`, `.subpackageAImagesRouteFreeCover`, `MPAsset.BrandLogo.cyLogoMark`, `MPAsset.AvatarDefault.dProfile`, `MoneyDisplay.minimumFractionDigits()`, `WalletAnalysisPagingPolicy.shouldContinue`, `BeijingServerTime`, `MyProjectMutationModel.beginActivityCancel(id:title:)` / `confirmationText`, `WalletOrganizerFinanceAccess.allowsRead`, `palette.bgStrong/bgRaised`.

## Round 3 (2026-11-24 evening, brief `design/handoff-r2:docs/briefs/fix-r3-round3.md`)

- **Sync:** `git merge origin/ui/combined-r7` (`b0ac0108d`) fast-forwarded (my round 2 was already in it). Merged again before the final push.
- **Checked:** for each round-1 and round-2 commit of this branch, `git diff <c>^ <c> -- <file> | git apply -R --check` on the new base, and a read of `git diff 3a4c99e03 HEAD` for every Swift file this branch touched. None of the files restored to Cursor's side (`SettingsView`, `MerchantVerifyRecordsSections`, `PlatformConsumerSessionOwner`, `RoamPOIActions`, `JourneyReportViews`, `TeamHomeView`, `TicketWalletView`, `TopicXcxSections`, `ClubDetailView`, `ClubKit/ClubWorkbenchKit`) was touched by this branch. `WalletIncomeAnalysisReader` (kept on my side) is intact.

### Round 3 · re-applied

| hunk | what was lost | how it is back | files |
|---|---|---|---|
| r2 `b5ead1e46` (MP assets, B-14 asset part) | The integrator's `IMRemoteAvatar<EmptyView>.url` compile fix also dropped the MP `/images/d_profile.png` fallback: inbox rows, the chat bar and bubbles showed generated art again, and bubbles lost the counterparty-avatar step. | Re-applied on top of the compile fix (keeps `IMRemoteAvatar<EmptyView>.url`): a person falls back to `MPAsset.AvatarDefault.dProfile`; system and group rows keep the glyph art; bubbles use `senderAvatar ?? counterparty avatar (1:1 only) ?? d_profile` (MP `im/chat/index.wxml:160`). | `App/IMInboxViews.swift`, `App/MessagingHistoryView.swift` |
| r2 `353aa4753` (D1-2) | Not lost: the merge rewrote `confirmationText` as `model.confirmationText` first, `confirmationMessage` second (the same effect). | Kept as merged. | — |
| r2 `b5ead1e46` (`QuestifyImageEntityCard`) | Not lost: only the corner radius became `CYRadius.hero`. The `fallbackArtwork` hook is intact. | Kept as merged. | — |

Every other round-1/round-2 hunk is present on the new base. The ones `git apply -R --check` flagged were later edits by this branch or by others to the same lines (for example the C2 ticket preselect now flows through Cursor's `registrationPreselectedTicketID` environment value, and the peer-report row came from `cursor/wire-player-content`).

### Fixed in round 3

| id | page | what changed | files |
|---|---|---|---|
| R7-PC-D9-1 | D9 | After the first page loads, the chat marks the conversation read (MP `api/im/read`) through the coordinator's own `reviewOrdinaryRead()` → `confirm(stillAuthorized:)`, so the frozen cursor, journal and recovery are the same as the explicit path. It runs only when `IMReadReceiptTriggerPolicy.autoOnLoadWhenGranted(imReadGranted: owner.canReviewOrdinaryRead)` says so, which needs the `.imRead` runtime grant (default off) and an unread count above zero. No grant was turned on. | `App/MessagingHistoryView.swift` |
| flows-g2 (myproject, for Claude) | D1 | `subpackageA/pages/myproject/index` with `scope=MERCHANT` opens the merchant entry (`entryScope: "MERCHANT"`, browse-only until access/me grants `merchant:project:manage`). With `type=` it starts on the MP tab (`club_activity` → 活动, `template` → 模板, other old types → 主题; MP `index.js:132, 150-155`). A bare link is still `.myProjects`. New route case `MPParityRoute.myProjectsEntry(merchant:initialType:)`; `CreatorContentProjectsView.initialType` is applied once on appear. | `App/MPParityKit.swift`, `App/SubscribeMessageTapScreens.swift`, `App/ProjectOwnedContentViews.swift`, `App/CreatorContentViews.swift` |

### MP assets (round 3)
- The new mapping rows (template-detail shelf covers and props, growth-center leaderboard memojis, journey rank-board laurel) are on `DiscoveryTemplateDetailView` (half a), `GrowthLeaderboardView` (member) and `PlayExperienceView` (play-roam). None of them is on pages C2–D9.
- The round-2 rows still apply. The three unticked rows (`EmptyState.noData` on the activity list, `routeCityCover` on template shelf rows, `subpackageBImagesRouteFreeCover` in the composer route picker) keep their reasons.

### Left, with reasons (round 3)

| id | reason / request |
|---|---|
| flows-g1 `official-detail` → `OfficialEventLeaderboardSection` | **Core request (Cursor):** there is no official-event leaderboard read on r7 (no producer of `OfficialEventLeaderboardRow`). The section can only render empty. The section also has a raw 「暂列第 N 名」 string, which Gemini needs to make a catalog key. |
| flows-g1 `infomationdetail` → `SocialArticleRichBlocksView` | **Core request (Cursor/Gemini):** nothing decodes `SocialArticleRichBlock` from `api/information/info`. Mount it once `SocialInformation` exposes blocks. |
| flows-g1 `im/chat` → `IMComposerPlusMenuButton` | The image, location and route rows need the composer's send paths (`canSendOrdinaryImage`, `canSendStaticLocation`, `canSendRoute`, all default off), and `IMComposerPlusItem.title` is a raw Chinese string, not a key. Poll is already the composer's leading `+`. Peer report is in the ⋯ menu (Cursor wiring). |
| flows-g2 `merchant/index.js:1650`, `publish/temp/index.js:3520` (myproject links) | The App route now honours `scope` and `type`. **Core request (Cursor):** `MiniProgramPageLink.reviewedPages["subpackageA/pages/myproject/index"]` is the `open` rule (`allowed: []`), so a universal or `chein://` link carrying `scope`/`type` is rejected before it reaches the App route. Allow `scope` ∈ {`MERCHANT`} and `type` ∈ {`club_activity`, `template`, `simple_topic`, `pro_topic`, `self_play`}. The merchant-home and publish callers belong to merchant-coop and account-publish. |
| R7-PC-D2-1 (detail push) | Still a sheet: `test_social_guide_templates.test_details_and_full_catalog_use_read_only_existing_destinations` asserts there is no `NavigationLink` in `SocialGuideTemplateSection.swift`. |
| R7-PC-C2-2, R7-PC-D1-6 (coordinates), R7-PC-D3-3 | The Core requests are still open on `b0ac0108d`: no `reservationState`, no `CreatorContentProject` coordinates, no `PublicContentShareLink.information(id:)`. |
| R7-PC-D1-1 (pushed menu), R7-PC-D1-4, R7-PC-C4-3 (price row) | Unchanged; the same pins are still there. |
| review rev-a/b/c | No new Claude rows for C2–D9 since round 2 (rev-b B-14 and B-23 are done; the rest belong to other areas). |
| audit `parity-r7-player-content` P1 | Both P1 rows in this half are done (D1-1 tab root in round 1, D4-1 in round 2). |

### Tests and pins touched in round 3
- None. `Tests/AppUnitTests/MPParityDeepLinkRouteTests.swift` still expects `.myProjects` for a bare myproject link, which is unchanged.
