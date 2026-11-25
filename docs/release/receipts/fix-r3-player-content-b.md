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

### Local verification (round 3)
- Contract checks (`python3 -m unittest discover -s Tests/ContractChecks`): branch vs `origin/ui/combined-r7` `b0ac0108d` gives 218 FAIL/ERROR on both, and the sets are identical. Nothing new failed and nothing was fixed.
- No new Swift files or folders. No compiler in the cloud. APIs grepped on `b0ac0108d` before use: `IMRemoteAvatar<EmptyView>.url`, `MPAsset.AvatarDefault.dProfile`, `IMExpandedCoordinator.isCurrent` / `canReviewOrdinaryRead` / `reviewOrdinaryRead()` / `confirm(stillAuthorized:)`, `IMReadReceiptTriggerPolicy.autoOnLoadWhenGranted` / `shouldAutoMarkRead(unreadCount:)`, `MessagingConversation.unread`, `SessionCreatorProjectsView(entryScope:)`, `CreatorContentQuery.type`.

## Round 4 (2026-11-25, brief `design/handoff-r2:docs/briefs/fix-r3-round4.md`)

- **Sync:** `git merge origin/ui/combined-r7` (`4ef0a2840`, F-agent round 3 + Cursor round 4 + Gemini round 7), no conflicts.
- **Gemini's MP-alignment work for C2–D9 was taken over** (Gemini out of quota). `App/MPGap/**` is no longer parked (it is in the `generate_project.py` glob), but none of its player-content views has a data source on r7; see "Left" below.
- **Skipped as in flight:** `restyle/*`, `cursor/*`, `gap/*`, `port/*` (unchanged from round 1).

### 1. Flows (`docs/mp-gap/flows-g1.md` / `flows-g2.md`, C2–D9 edges)

| MP edge | status in the app |
|---|---|
| `baoming` → after signup `orderinfo` (redirect) / `mycanyu` / member tab / address / club | OK (unchanged) |
| `activity/list` → `official-detail` / `official-mine` / `official-inbox`, back | OK. The list is pushed with system back (R7-PC-C3-1). |
| `official-detail` → `official-organizer`, `topic/index`, `switchTab roam`; load error → `activity/list` | OK. The unavailable state's 返回活动列表 dismisses to the previous page, which is the MP `navigateBack` branch of `onLoadErrorBack`. A cold deep link has a host page under it, so the `reLaunch` branch has no app equivalent. **Mount `OfficialEventLeaderboardSection`: left** (no producer, below). |
| `infomation` → `templatedetail`; `infomationdetail` → back to list | OK (R7-PC-D2-1 square part, R7-PC-D3-4). **Rich blocks: left** (below). |
| `im/chat` → `report-mine`, `signup`, `topic/index`, back | OK. Peer report is in the ⋯ menu (Cursor wiring). Closed chat → 返回消息列表. **`IMComposerPlusMenuButton`: left** (below). |
| flows-g2 `merchant/index.js:1650` `myproject?scope=MERCHANT`, `publish/temp/index.js:3520` `myproject?type=template` | App route done in round 3. The link-parser allow-list is still a Core request (round 3). |

### 2. Image parity (every image slot on the 15 MP pages)

Only shipped artwork counts here. `cy-icon` is the MP icon font (no image file), so those glyphs stay SF Symbols: arrow-right, chevron-right, poi-landmark, pin, flag, check, gift, share, edit, list, close, info, draft, trash, clock, connect, bell, warning, plus, sort, more, coupon, image.

| MP page | MP slot (`file:line`) | MP image | app | status |
|---|---|---|---|---|
| C2 baoming | `baoming.wxml:84-85` | activity `imgUrl` / `imgArr[0]`, fallback `/images/cover-route.svg` | `RegistrationSheetView` ticket card: remote cover, fallback `MPAsset.BannerCover.coverRoute` | ✅ (round 2) |
| C2 baoming | `baoming.wxml:19,66,106,112,304` `cy-empty` (missing-param, gate, not-started, no kind) | glyphs only | — | ✅ no image |
| C3 activity list | `list/index.wxml:51` | missing cover → `/images/cover-route.svg` | `OfficialEventCard` fallback `coverRoute` | ✅ (round 2) |
| C3 activity list | `list/index.js:40-50` `EMPTY_COPY` | glyph kinds; the MP says not to use `no_data.svg` here | `CYEmptyState` glyph art | ✅ no image |
| C4 official-detail | `index.wxml:25-26` hero | `coverImg`, fallback `cy-icon image` | `OfficialEventCard` (remote cover); fallback is `coverRoute` (shared with the list card) | ⚠️ fallback differs (the MP detail uses a glyph). Left: the card is shared with C3, where `coverRoute` is right. |
| C4 official-detail | `index.wxml:31` | `/images/cy_logo_mark.png` | `MPAsset.BrandLogo.cyLogoMark` | ✅ (round 2) |
| C4 official-detail | `index.wxml:100-101` activity cards | `coverImg` per card, fallback `cy-icon flag` | cards have no thumbnail | ⚠️ left (layout change on a pinned section; remote image only, no MP asset involved) |
| C5 official-inbox | `index.wxml:11` `cy-empty kind="empty"` | `empty_state_bg.svg` + `empty_state_figure.svg` | `CYEmptyState(systemImage: "tray")` → `CYEmptyIllustration(.generic)` = `MPAsset.EmptyState.emptyStateBg/Figure` | ✅ **round 4** (was the `envelope.open` generated art) |
| C6 official-mine | `index.wxml:15,23` `cy-empty` (no kind) | none (legacy default: no art) | text rows | ✅ no image |
| C7 official-organizer | — | none | — | ✅ |
| D1 myproject | `index.wxml:38` | `item.cover`, fallback `/subpackageA/images/route_free_cover.png` | `MPAsset.BannerCover.subpackageAImagesRouteFreeCover` | ✅ (round 2) |
| D1 myproject | `index.wxml:59` `cy-empty kind="empty"` | empty_state bg + figure | `MyProjectEmptyView` `CYStateArt(kind: .generic)`; the no-tab fallback uses `tray` | ✅ **round 4** (was `.projects` generated art) |
| D1 myproject | `index.wxml:72,83` template / shelf rows | fallback `/images/route_city_cover.png` | no inline shelf rows (R7-PC-D1-4 left) | ⚠️ left with D1-4 |
| D1 myproject | `index.wxml:162` audit attachments | user upload (remote) | review sheet | ✅ remote only |
| D2 infomation | `infomation.wxml:40` template pic | `item.imgUrl` (remote) | `E1CoverArt(imageURL: item.imgUrl)` | ✅ |
| D2 infomation | `infomation.wxml:35,72` `cy-empty kind="empty"` (templates, docs) | empty_state bg + figure | both `CYEmptyState(systemImage: "tray")` | ✅ **round 4** (were `square.grid.2x2` / `doc.text`, which drew the ticket art) |
| D2 infomation | `infomation.wxml:18` doc row | `cy-icon {{item.icon}}` | `SocialInformationArt` | ✅ glyph slot |
| D3 infomationdetail | `infomationdetail.wxml:25` error `icon="empty-state"` | empty_state bg + figure | `SocialReadScreen` shared error view | ⚠️ left: the error view is shared by every social read screen |
| D4 income-detail | `scene-asset-income-detail/index.wxml:43` `cy-empty kind="empty"` | empty_state bg + figure | ledger empty for `.income` → `tray` (points ledger unchanged) | ✅ **round 4** |
| D5 earnings | `scene-asset-earnings/index.wxml:22` `cy-empty kind="empty"` | empty_state bg + figure | `WalletEarningsEmptyNote` now draws `CYEmptyIllustration(.generic)` | ✅ **round 4** |
| D6 analysis | — | none (`cy-empty` / `cy-error` without art) | — | ✅ |
| D7 video-bounty | `index.wxml:26,45` `cy-empty kind="empty"` | empty_state bg + figure | submissions / accruals empty → `tray` | ✅ **round 4** (were `film` / `doc.text`) |
| D8 im/list | `index.wxml:141` | `counterparty.avatar`, fallback `/images/d_profile.png` | `IMRemoteAvatar` → `MPAsset.AvatarDefault.dProfile` | ✅ (round 2/3) |
| D8 im/list | `index.wxml:57` invite card | `topicImgUrl`, fallback `cy-icon connect` | `IMCoopInviteStripView` cover | ✅ glyph fallback |
| D9 im/chat | `index.wxml:68,160` | `senderAvatar ‖ avatar ‖ d_profile.png` | `MPAsset.AvatarDefault.dProfile` | ✅ (round 3) |
| D9 im/chat | `index.wxml:55,148,164` image messages | remote | image bubbles | ✅ remote only |
| D9 im/chat | `index.wxml:92` route card no cover | `/images/cover-route.svg` | `IMCardPreviewViews` `coverRoute` | ✅ (round 2) |
| D9 im/chat | `index.wxml:43` `cy-empty kind="empty"` 还没有消息 | empty_state bg + figure | `tray` | ✅ **round 4** (was the inbox bubble art) |
| D9 im/chat | `index.wxml:237` composer route picker | `/subpackageB/images/route_free_cover.png` | the `+` route picker is not mounted (below) | ⚠️ left |

### 3. Copy (zh must equal MP; overrides in `docs/port/strings/fix-r3-player-content-b.json`)

| page | MP text (`file:line`) | key | change |
|---|---|---|---|
| C2 | 结算 (`baoming.json` / nav-bar) | `registration.form.title` | override 活动报名 → 结算 (en Checkout) |
| C3 我的 | 登录后查看我的活动 / 当前身份不能查看这些活动 (`list/index.wxml:32-33`) | new `official.mine.signInRequired`, `official.mine.forbidden` | `OfficialReadScreen.issueLabel` (optional, nil keeps the shared label) |
| C5 | 暂无待处理的活动职责, no sub (`official-inbox/index.wxml:11`) | `official.inbox.empty` | the extra `official.inbox.emptyDetail` line is gone |
| C6 | 发布记录加载失败 (`official-mine/index.wxml:11`) | new `official.published.loadFailed` | via `issueLabel` |
| D1 | 还没有主题 / 还没有活动 / 还没有节点玩法, `sub: ''` (`myproject/index.js:50-54`) | `myProject.empty.*` | the detail line is no longer rendered (the Core keys stay, `MyProjectPageReadyTests` still pins them) |
| D1 | 当前身份不能查看这些项目 / 项目加载失败 (`myproject/index.wxml:22-23`) | new `myProject.accessDenied`, `myProject.loadFailed` | `CreatorContentIssueView` optional `deniedTitleKey` / `failureTitleKey`; denied has no 重试, like the MP |
| D4 | 登录后查看收益明细 / 当前身份不能查看收益明细 / 收益明细加载失败 (`scene-asset-income-detail/index.wxml:41`) | new `wallet.income.signInRequired`, `.denied`, `.loadFailed` | `WalletIssueView` optional `loginKey` / `deniedKey` (nil keeps the shared copy) |
| D5 | 登录后查看账户收益 / 当前身份不能查看收益 / 收益加载失败 (`scene-asset-earnings/index.wxml:7`) | new `wallet.earnings.signInRequired`, `.denied`, `.loadFailed` | same |
| D5 | 还没有收益, no sub (`scene-asset-earnings/index.wxml:22`) | `member.wallet.noEarnings` | the `noEarningsHint` line is gone |
| D6 | 登录后查看 (`analysis/index.wxml:13`) | `wallet.analysis.login` (table `WalletIncomeAnalysis`) | 登录后查看分析 → 登录后查看, in `Resources/WalletIncomeAnalysis.xcstrings` and its ui-strings doc |
| D9 | 这个会话无法打开 (`im/chat/index.wxml:41`) | `messaging.accessDenied` | override 无法查看会话 → 这个会话无法打开 |

Already equal (checked): 官方活动, 官方活动邀约, 我发布的, 主办控制台, 我的项目, 城瘾玩法, 玩法详情, 收益明细, 账户收益, 分析, 视频悬赏, 消息, 聊天, 活动详情 (round 1 override), 登录后查看我的项目, 还没发过活动, 还没发过通知, 还没有上架的现成玩法, 现成玩法加载失败, 暂无玩法说明, 这篇玩法说明不在了, 还没有投稿, 还没有应计记录, 读取失败, 还没有消息, 登录后查看消息, 消息加载失败, 这个组局已结束, 返回消息列表, 分析数据加载失败, 去发布路线, 暂无可用票, the four 暂无…的活动 tab empties, 还没有收益记录.

### 4. P2 / P1 rows

Every Claude-owned P2 row for C2–D9 in `audit/parity-r7-player-content` was closed in rounds 1–3, or is listed as left with its reason. Both P1 rows in this half (D1-1 tab root, D4-1) are done. No new P1 is open.

### 5. Accessibility lint

`python3 -B tools/check_a11y_lint.py`: this branch adds 0 findings. The one current finding, `App/ClubKit/ClubWorkbenchKit.swift:261` (unlabeled `square.and.arrow.up`), comes from `origin/ui/combined-r7` itself. It is in the club area, and Cursor's receipts keep `ClubWorkbenchKit` hands-off, so it is left for the club F-agent / integrator. The new `CYEmptyIllustration` is already `accessibilityHidden(true)` inside the shared view.

### Left, with reasons (round 4)

| id | reason / request |
|---|---|
| R7-PC-C4-1 `OfficialEventLeaderboardSection` | **Core request (Cursor):** still no producer of `OfficialEventLeaderboardRow` on r7. The section also has a raw 「暂列第 \(n) 名」 literal that needs a key. |
| R7-PC-D3-2 `SocialArticleRichBlocksView` | **Core request (Cursor):** `SocialArticleContent` drops `img`/`a` on purpose (`Core/SocialArticleContent.swift:246,303`, "contains no URLs"). Nothing builds `SocialArticleRichBlock`. Showing article images needs a reviewed Core change (https-only `src`, allowed hosts). |
| R7-PC-D9-3 `IMComposerPlusMenuButton` | The image, location and route sends are all off by default (`canSendOrdinaryImage`, `canSendStaticLocation`, `canSendRoute`), so the mounted menu would hold only 投票, which is already the composer's `+`. `IMComposerPlusItem.title` is a raw Chinese string in Core. |
| R7-PC-C2-1 `ActivityRegistrationGapSections` | **Core request (Cursor):** no decoder produces `ActivityChildAgeRange`, `ActivityDeliveryItem` or merchant-closed/pass-covered flags from the baoming reads. Its host reservation part waits on `reservationState` (R7-PC-C2-2). |
| R7-PC-C6-2 安全恢复原投递 | **Core request (Cursor):** the audit points at `PlayerContentGapService.swift:167`, which on r7 is `checkOrientSafety`. No broadcast-recover command exists. |
| C2 报名已截止 | `registration.form.signupClosed` keeps the longer sentence: `Tests/AppUITests/RegistrationWaitlistUITests.swift:25` pins the label. |
| C5 failure title | `official.w206.inbox.failed.title` (邀约没有加载出来) above 邀约加载失败 is pinned by `test_official_inbox_page_ready` / `OfficialEventComponentsClosureTests`. |
| D3 error art, D8 list 加载失败 | Both come from shared views (`SocialReadScreen`, `MessagingLoadIssue` is shared by the list and the chat). Changing them would change other pages. |
| Image ⚠️ rows above | Reasons are in the table. |
| Round 1–3 left items | Unchanged: R7-PC-C2-2, D1-6 (coordinates), D3-3 (Core); D1-1 (pushed menu), D1-4, D2-1 (detail push), C4-3 (price row) (pins). |

### Files changed in round 4
`App/CreatorContentViews.swift`, `App/MyProjectTabViews.swift`, `App/OfficialEventComponents.swift`, `App/OfficialEventsBrowserView.swift`, `App/OfficialPrivateViews.swift`, `App/SocialGuideTemplateSection.swift`, `App/SocialGuideViews.swift`, `App/VideoBountyView.swift`, `App/MessagingHistoryView.swift`, `App/WalletCommerceViews.swift`, `App/WalletEarningsParity.swift`, `Resources/WalletIncomeAnalysis.xcstrings`, `docs/release/ui-strings-subpackageA-pages-assetcenter-analysis-index.json`, `docs/port/strings/fix-r3-player-content-b.json` (+13 keys/overrides). No new Swift files or folders. No Core change.

APIs grepped on r7 before use: `CYEmptyIllustration(kind:size:)`, `CYStateArt(kind: .generic)`, `CYEmptyIllustration.kind(matching: "tray")`, `OfficialScreenIssue` cases, `CreatorContentIssue` (`.unavailable`, `.server`), `WalletIssueView.failedKey`, `CYSpacing.xs`.

### Local verification (round 4)
- Contract checks (`python3 -m unittest discover -s Tests/ContractChecks`, 6064 tests): `origin/ui/combined-r7` `4ef0a2840` has 222 FAIL/ERROR, and this branch has 223. Nothing was fixed-then-broken. The one new failure is the expected fragment check, `test_official_event_contracts…test_every_static_user_facing_key_has_two_languages`: `official.mine.signInRequired`, `official.mine.forbidden` and `official.published.loadFailed` live only in the strings fragment until the integrator merges it.
- `tools/check_typography_lint.py`: PASS. `tools/check_a11y_lint.py`: no new finding from this branch (the one current finding is on the base; see §5).
- No compiler in the cloud. The coordinator compiles.

## Round 5 (2026-11-25, brief `design/handoff-r2:docs/briefs/COORDINATOR-HANDOVER.md` §4/§8, MP-first rule in `owner-decisions-1124.md`)

### Step 1 · merge `origin/ui/combined-r7` (f95850a46) — `44d7bb26e`
- One conflict: `App/WalletCommerceViews.swift` ledger empty state. My side used MP empty_state art (`tray`) for income; the integration side used it for points. Kept both: `tray` for income and points.
- The gate failed on 9 missing keys because my round-4 fragment was a plain map. Fix: `docs/port/strings/fix-r3-player-content-b.json` now has the xcstrings shape, and its entries were applied to the catalog, including the round-4 overrides (`registration.form.title` 结算, `official.detail` 活动详情, `official.bucket.upcoming` 即将上线 (closes R7-PC-C3-3 / C4-5), `messaging.accessDenied`).
- The a11y lint failed on the base (`App/ObjectBadgeTileArtwork.swift:30`). Fix: the decorative thumbnail is hidden.
- Checks: no conflict markers; no new duplicate type names (diffed against the base); `check_scaffold` PASS.

### Step 2 · rows fixed (MP-first)
| row | MP (`file:line`) | app change | commit |
|---|---|---|---|
| **R8-PC-D9-1 (P0)** / R7-PC-D9-2 | `subpackageB/pages/im/chat/index.js:961-968`, `index.wxml:250`; `subpackageMember/components/cy/report-sheet/index.js:56-150`, `model.js` | Before: 举报对方 was a dead end. Now it sends the MP member report. The peer is the sender of the latest message that is not mine; with none, the alert says 对方还没发过消息，暂不能举报. The flow: GET `community-trust/reports/taxonomy` → pick a reason → 具体说明 (1–2000) → POST `community-trust/reports/submit` `{targetType: MEMBER, targetId, reasonCode, policyVersion, description, requestId}`. On success it shows 受理编号. A business reject shows the server `msg` and gets a new requestId. A transport failure shows 提交结果未知, and 再试一次 replays the same requestId. New `App/CommunityMemberReportSheet.swift`; the Core `CommunityMemberReportClient` is composed with `writesEnabled: true`. The audit's "contract mismatch" note is wrong: the MP uses the same `community-trust` endpoints. | `ad5cd3e22` |
| R7-PC-D9-1 | `im/chat/index.js:861-867` `markRead` | When the reviewed ordinary-read path is unavailable (it needs `read-receipt` / `read-state` GETs that the MP never calls), the chat posts the plain `api/im/read` after the first page if the row has unread messages. It stays silent on failure, like the MP. `imExpandedWriter` turns on `inboxConversationReadEnabled`; the route grant was already in the lease. Gap: `read_to` is not sent, because Core's inbox request has only `conversation_id`. **Core request (Cursor):** add `read_to` to `merchantInboxMarkReadRequest`, or add an MP-shaped chat read. | `e0189a1c7` |
| R8-PC-C6-1 | `official-mine/index.js:150-178` | A stats reply that arrives after a scope change resets the row to idle. Before, the row stayed on 正在读取复盘…. | `f87e85227` |
| R7-PC-C5-2 | `official-inbox/index.wxml:32` | 正在提交，请稍候 shows while the inbox write runs. It is in the review sheet because the write runs there and the sheet can't be dismissed while busy. | `f87e85227` |
| R7-PC-D8-1 | `im/list/index.wxml:11`, `index.js:268-281`, `:106` | One 收件箱 / 发件箱 picker replaces 全部/频道/私信 and the strip's own 收到/发出 picker. 收件箱 = received invites + every conversation; 发件箱 = sent invites only (empty: 还没有发出的邀请). The UI tests are updated to two tabs. | `4f8a3b7c6` |

Already closed on the integration branch by `fix/r8-mp-first`: R8-PC-D4-1, R7-PC-D5-1, R7-PC-C6-1, R7-PC-D7-1, R7-PC-D3-5.

### Left, with reasons (round 5)
| id | reason / request |
|---|---|
| R7-PC-D8-1 tab badge | The MP 收件箱 badge (unread + pending received invites) is not shown yet. The unread count lives inside the list view and the invite count lives inside the strip. Next round. |
| R7-PC-D9-3 composer `+` | Under MP-first, the image, location and route sends should be turned on like the MP (`im/chat/index.wxml:196`). They are still off in `IMExpandedService` (`canSendOrdinaryImage`, `canSendStaticLocation`, `canSendRoute`), and the static-location and route paths need Core receipts. Next round, together with Cursor. |
| R7-PC-D9-1 `read_to` | Core request (above). |
| R7-PC-C2-1, C2-2, C4-1, C6-2, D3-2, D3-3, D1-6 | Core requests (Cursor), unchanged from round 4. |
| R7-PC-D1-1, D1-4, D2-1, C4-3 | Blocked by SHA or hash test pins, unchanged. |

### Verification (round 5)
- `python3 tools/check_scaffold.py`: PASS structural checks. `check_a11y_lint`: 0. `check_typography_lint`: PASS. `check_appsession_ratchet`: PASS.
- Contract checks for every module that references the touched files were run before and after, module by module (171 for messaging/AppSession, 5 for official, 8 for the message list). There are no new failures. Failures that were already on the base and stay the same: `test_profile_avatar` (AppSession hash) and `test_c07_fulfillment_projections`.
- Every declaration used was checked with grep first: `CommunityMemberReportClient.taxonomyRequest/submitRequest`, `CommunityMemberReportDraft.requestID`/`descriptionMax`, `IMExpandedWriter.canWriteInboxConversationRead`/`markInboxConversationRead`, `MessagingMessage.senderID: Int?`, `MessagingReadIdentity.accountID`, `AppSession.regionalConfiguration`/`runtimeHTTPTransport`/`token`, `CooperationDirection`, `CYEmptyState(systemImage:_:messageIdentifier:)`, `CYPillButton`, `CYOptionSheetItem`.
- There is no compiler in the cloud; the coordinator builds. New Swift file: `App/CommunityMemberReportSheet.swift` (the project was regenerated).
