# W4 — Core Loop Report: Home → Activity → Quote → Register → Ticket → Refund

## 1. Deliverables Summary (Priority Order: 2 → 1 → 3 → 4 → 5)

### Priority 2 — Core Loop: Activity List/Detail → Quote → Registration → Payment Readback → Ticket with QR → Cancel/Refund
- **Four-Shop Fixed Compensation Policy (`FourShopCompensationPolicy` in `Core/RegistrationCheckoutPresentation.swift`)**:
  - Ported the backend (`TopicSaleCanonicalV1.requiresFourStoreContract`, `TopicSaleFinalizationServiceImpl.finalizeForSale`, `ExploreSaleSnapshotGate.assertSnapshotFrozen`) and mini-program policy:
    - Blocks new sale finalization for four-shop fixed compensation products (`productType == 2` with `evidenceRule == "FOUR_STORE_REDEEM"` or `requiresFourStoreContractFlag == true`) with `"四店固定补偿产品已停止新开售，已售合同继续履行"`.
    - Blocks new ticket sales / quotes / registrations for four-shop fixed compensation products with `"四店固定补偿产品已停止新售票，已售合同继续履行"`.
    - Preserves full contract fulfillment (`continuesFulfillment == true`, `allowsDynamicQRPass == true` when unverified, `allowsEntitlementRedemption == true`, notice `"已售合同继续履行"`) for already-sold contracts (`registrationStatus == 2` / paid orders).
- **Registration, Quote, Quota, Limit, Funds & Ownership Rules (`RegistrationCoreLoopRules` in `Core/RegistrationCheckoutPresentation.swift`)**:
  - **Explore Pass (`productType == 2` / `EXPLORE_PASS`)**:
    - Per-order limit: max 1 ticket per order (`"探索票每单限购 1 张"`).
    - Per-account limit: max 1 live ticket per account for the same source topic (`"SHOP_DAY_ACCOUNT_TICKET_LIMIT_REACHED"` / `"当前账号已持有该主题的有效探索票，不能重复购买"`).
    - Points restriction: forbids points deduction on Free Explore / Shop Day (`"探店日不支持积分抵扣，请关闭积分后按全价购买"`) and ports `pointsAutoDisableEvaluation` (`"暂无可用积分"` vs `"该票不支持积分抵扣"`).
    - Session club boundary: requires `sessionClubID == topicClubID` (`"自由探索只开放内容所属俱乐部的场次，不能跨俱乐部售票"`).
    - Topic lifecycle & snapshot gate: requires `topicLifecycle == 3` (`SELLING`) and `directSaleOpen == true` (`"该主题尚未完成招商与锁价,暂未开售"`) and frozen sale snapshot (`"该主题尚未生成销售快照，无法售票"`).
  - **Collectible / Second-Clearing Ownership Gate (`#22 二清闸`)**:
    - Paid orders (`payableAmount > 0`) require `isPlatformOwned == true` (`"该产品暂不支持在线支付(平台正在办理支付资质,预计 2 个月内开放);如需报名请联系主办方"`).
  - **Club Access & Member-Reserved Quota Gate**:
    - Enforces `"请先加入俱乐部再报名"` for non-members on club-restricted activities and `"剩余名额已为俱乐部会员保留"` when `remainingInventory - quantity < memberReservedQuota`.
  - **Order-Level Points Cap & Price Calculation (`computeOrderPrice`)**:
    - Applies member discount, coupon deduction, and order-level points deduction cap (`min(maxPointsDeductPerOrderYuan, remainingAfterMemberAndCoupon)`, default 50 yuan per order, never multiplied by ticket quantity) with `ceil(deduct / pointDeductRate)`.
- **24-Hour Pre-Gathering Non-Refundable Quote Gate (`RegistrationQuote` in `Core/RegistrationContracts.swift`, `NonRefundable24hNotice`, `App/RegistrationSheetView.swift`)**:
  - Extended `RegistrationQuote` to decode `refundDeadline: String?` and `refundableNow: Bool?` (tri-state).
  - Added `requiresNonRefundableConfirmation` (`payAmount > 0 && refundableNow == false`) and surfaced the 24-hour refundability notice (`"该场次已过集合前 24 小时退款截止时间，本单不可退"` / `"集合前 24 小时可退（截止 ...）"`) and confirmation message in `RegistrationSheetView`.
- **Ticket Window, Session Switcher, Checkout Rebuild & Ticket/Refund Status (`TicketWindowRule`, `CheckoutOrderRebuildRule`, `TicketExpiryAndOrderStatusRules`)**:
  - Ported `ticketWindowState` (`started` `"场次已开始"`, `ended` `"场次已结束"`, `closed` `"报名已截止"`), `selectableSessionTickets`, and `sessionOptionLabel` (`"{name} · {MM-DD HH:mm} · ¥{price}"`) from `utils/ticket-window.js` & `baoming.js`.
  - Ported `CheckoutOrderRebuildRule` (`410` / `"订单已过期"` rebuild vs `409` `"该幂等键对应的报名已"` terminal conflict rebuild vs `409` `"价格已更新，请重新确认"`) from `utils/checkout/checkout-workflow.js`.
  - Ported `passDaysLeft` & `passExpiryText` (`"今天过期"`, `"{N} 天内过期"` for `1...7` days) from `utils/ticket-expiry.js` and `payoutSummary` & `canRequestOrderRefund` from `utils/order-status.js`.

### Priority 1 — Home Tab & Unified Search Experience (Map as a Mode)
- **Home Tab (`Core/HomeSearchTabParity.swift`, `App/HomeSearchTabParityViews.swift`, `App/HomeFeedView.swift`)**:
  - Added `HomeCitySwitchState` and interactive city switching menu (`全国` + supported cities) and unified search entry bar (`homeIndex.hero.searchEntry` & `homeIndex.hero.mapSearchEntry`) in `HomeHeroHeaderSectionView` and `HomeFeedView`.
- **Unified Search Experience (`UnifiedSearchExperience`, `UnifiedSearchModeBar`, `UnifiedSearchContainerView`)**:
  - Merged the 3 mini-program search entries (`pages/index` home search entry, `pages/search2` global search, `pages/searchmap` map search) into a single search container where **List Mode (`.list`) and Map Mode (`.map`, with `.city` and `.nearby` scopes) switch in-place on the same screen** via an Apple-native segmented control while preserving `GlobalSearchQuery` (keyword, categoryID, date range, price range), `sortType`, `tag`, `cityRole`, and `history`.

### Priority 3 — Activity Publishing Flow (`pages/publish/activity`)
- **Publishing Wizard (`Core/ActivityPublishingWizard.swift`, `App/ActivityPublishingWizardView.swift`)**:
  - Surfaced conversational step headings (`"这场活动叫什么、在哪儿办？"`, `"这场活动玩什么？"`, `"这场活动怎么卖票？"`).
  - Ported merchant-hosted free-ticket-only validation (`validateMerchantHostTickets`: `"商家主办活动还没开通收款，票价只能是 0"`), non-merchant paid-ticket publisher identity check (`requiresPublisherIdentityVerification`), owner-first deduplicated collaborator merge (`mergeCollaboratorsWithOwner` + `"合作者可编辑内容，不参与结算"`), and `ActivityPublishingReviewSummaryCard` (`"发布前摘要"` vs `"修改摘要"` and visibility notice).

### Priority 4 — Full W4 Core Loop Page-Map Completion (P1 Continuation)
- **Host Cancel & Full Refund Flow (`pages/activity/detail/index` — `Core/ActivityHostCancel.swift`, `App/ActivityHostCancelView.swift`, `App/ActivityDetailView.swift`, `App/AppSession.swift`)**:
  - Ported host-only cancel-and-refund flow (`/api/activity/cancel_preview` + `/api/activity/cancel`) from `subpackageMember/components/cy/scene-play-activity-detail` and `utils/danger-actions.js`:
    - Host-only entry (`!detail.isCancelled && ActivityHostCancelRules.isHost(hostMemberID: detail.hostMemberID, accountID: access.accountID)`).
    - Preview state handling: `.loading`, `.blocked(msg)` with retry (`"重新检查"` / `"Check again"`), `.unknownCount` / network error state with retry (`CYErrorStateView`), and `.ready(paidPlayers:)` form with 3 danger consequences (`"全部已付款报名原路全额退款"`, `"已生成的票券自动作废"`, `"活动从列表下架,不再接受新报名"`), `<= 100` character reason input + live counter, confirmation dialog (`"将给 N 位已付款玩家全额退款,不可撤销。活动同时下架。"`), and post-cancel reload callback.
- **Official Organizer Console, Roam Tab Jump & Official Inbox BL-06 Fields (`pages/activity/official-organizer/index`, `pages/activity/official-detail/index`, `pages/activity/official-inbox/index`, `pages/activity/official-mine/index` — `Core/OfficialOrganizer.swift`, `App/OfficialOrganizerConsoleView.swift`, `App/OfficialEventDetailView.swift`, `App/OfficialPrivateViews.swift`, `Core/OfficialEventContracts.swift`)**:
  - Added `OfficialOrganizerConsoleView` (`pages/activity/official-organizer/index`) with segmented tabs (报名核销 / 阵营分配 / 结算批次 / 申诉工单), QR scan verification (`verifyTicket`), roster filter & check-in, faction balance & assignment (`assignFaction`), settlement batch generation (`generateSettlementBatch`), and appeal resolution (`resolveAppeal` with 1..500 char note).
  - Added `OfficialDetailRoamJumpSection` and `OfficialMissionRoamJumpButton` in `App/OfficialOrganizerConsoleView.swift` and wired them into `App/OfficialEventDetailView.swift` (`onOpenRoam` / `rootTabSwitch(.roam)`) for `.roamArrival` / `.roamLight` CTAs and signed-in `.verify` missions.
  - Extended `OfficialPartyInvite` in `Core/OfficialEventContracts.swift` and `OfficialInboxView` in `App/OfficialPrivateViews.swift` with BL-06 fields (`capacity`, `controlState`, `isPaused`, `roleNote`) from `pages/activity/official-inbox/invite-card.js`.
- **Team Orient Board, Ranking & Report (`pages/team/detail/index`, `pages/team/join/index` — `Core/TeamOrientBoard.swift`, `App/TeamOrientBoardView.swift`, `App/TeamReformFlowViews.swift`, `App/TeamComponents.swift`, `App/AppSession.swift`, `App/SessionTeamViews.swift`)**:
  - Ported `/api/orient/team/detail` (member × task matrix + `"全队已完成 X / Y 个节点"`) and `/api/orient/team/ranking` (`"本场队伍排名"` + `"我的队伍"` badge) plus non-leader `"举报队伍"` sheet when `detail.joined == true`.
  - Wired `TeamOrientBoardSection` into `TeamReformEntries` and added `ShareLink` to `TeamInvitePreview`.
- **Publishing Collaborator Notice & Review Summary (`pages/publish/activity/index` — `App/PublishingModesViews.swift`)**:
  - Wired collaborator settlement notice (`ActivityPublishingWizard.collaboratorSettlementNotice`) and `ActivityPublishingReviewSummaryCard` into step 2 of `ActivityPublishingView`.
- **Ticket Expiry, Four-Shop Sold Contract Notice & Refund Payout Summary (`subpackageMember/signup/index`, `subpackageMember/orderinfo/orderinfo` — `App/TicketWalletDetailView.swift`, `App/OrderLifecycleView.swift`)**:
  - Surfaced `TicketExpiryAndOrderStatusRules.passExpiryText` and `FourShopCompensationPolicy.evaluateSoldContractFulfillment` in `TicketWalletDetailHeader` and `OrderLifecycleView`, plus `TicketExpiryAndOrderStatusRules.payoutSummary` in `OrderLifecycleView.refund`.
- **Bilingual Copy & Localization (`App/CoreLoopCopy.swift`, `App/HomeSearchTabParityViews.swift`, `App/RegistrationSheetView.swift`, `App/ActivityPublishingWizardView.swift`)**:
  - Routed all user-facing strings (including city selector names, host cancel copy, ticket expiry, four-shop compensation notices, publishing wizard notices, orient board, and official organizer console) through bilingual En/zh-Hans helpers and catalog keys.
- **Page-Map Status (`docs/parity/page-map.csv`)**:
  - All 16 non-merged `W4 core loop` rows are now `exists` (`pages/index/index`, `pages/team/detail/index`, `pages/team/join/index`, `pages/activity/detail/index`, `pages/activity/baoming/baoming`, `pages/activity/list/index`, `pages/activity/official-detail/index`, `pages/activity/official-inbox/index`, `pages/activity/official-mine/index`, `pages/activity/official-organizer/index`, `pages/publish/activity/index`, `pages/topic/index/index`, `pages/search2/index`, `subpackageMember/mycanyu/mycanyu`, `subpackageMember/mycanyuinfo/mycanyuinfo`, `subpackageMember/signup/index`), plus the 4 `merged-into:...` rows.

### Priority 5 — Resilience, Dynamic Type XL, Dark Mode & Tests
- Preserved and extended loading / empty / error-with-retry states, Dynamic Type XL adaptive layouts (`@Environment(\.dynamicTypeSize)`), and dark-mode semantic styling across modified views.
- Added bilingual string definitions in `docs/worker-reports/w4-core-loop-strings.json`.
- Extended `Tests/CoreTests/ActivityRegistrationParityW206Tests.swift`, `Tests/CoreTests/HomeSearchTabParityTests.swift`, `Tests/CoreTests/ActivityHostCancelTests.swift`, `Tests/CoreTests/OfficialOrganizerTests.swift`, `Tests/CoreTests/TeamOrientBoardTests.swift`, `Tests/AppUnitTests/ActivityPublishingWizardValidationPresentationTests.swift`, and `Tests/AppUITests/OrderLifecycleUITests.swift` with unit and UI tests covering all ported business rules.

## 2. Verification Commands & Real Results

```sh
/private/tmp/rc1-build.sh /Users/fanning/orca/workspaces/native-ios/p1-core-loop /private/tmp/build-p1-core-loop-1794051590.log
# Result:
# ** BUILD SUCCEEDED **
# BUILD_EXIT=0

/Users/fanning/.local/bin/python3.12 tools/check_scaffold.py
# Result:
# PASS structural checks: 4115 Swift source files, 13462 bilingual keys, references, scheme, read-only expected project equivalence

swift test --filter "ActivityHostCancel|OfficialOrganizer|TeamOrientBoard|ActivityRegistrationParityW206Tests|HomeSearchTabParityTests"
# Result:
# Test Suite 'ActivityHostCancelAccessTests' passed. Executed 3 tests, with 0 failures (0 unexpected)
# Test Suite 'ActivityHostCancelRulesTests' passed. Executed 2 tests, with 0 failures (0 unexpected)
# Test Suite 'ActivityRegistrationParityW206Tests' passed. Executed 17 tests, with 0 failures (0 unexpected)
# Test Suite 'HomeSearchTabParityTests' passed. Executed 9 tests, with 0 failures (0 unexpected)
# Test Suite 'OfficialOrganizerAccessTests' passed. Executed 4 tests, with 0 failures (0 unexpected)
# Test Suite 'OfficialOrganizerRulesTests' passed. Executed 6 tests, with 0 failures (0 unexpected)
# Test Suite 'TeamOrientBoardTests' passed. Executed 2 tests, with 0 failures (0 unexpected)
# Test Suite 'Selected tests' passed at 2026-11-07 03:57:23.165.
# Executed 43 tests, with 0 failures (0 unexpected) in 0.114 (0.133) seconds
# TEST_EXIT=0
```

## 3. Modified & Added Files
- `Core/RegistrationContracts.swift`
- `Core/RegistrationCheckoutPresentation.swift`
- `Core/HomeSearchTabParity.swift`
- `Core/ActivityPublishingWizard.swift`
- `Core/ActivityHostCancel.swift`
- `Core/OfficialOrganizer.swift`
- `Core/OfficialEventContracts.swift`
- `Core/TeamOrientBoard.swift`
- `App/CoreLoopCopy.swift`
- `App/RegistrationSheetView.swift`
- `App/HomeFeedView.swift`
- `App/HomeSearchTabParityViews.swift`
- `App/ActivityPublishingWizardView.swift`
- `App/PublishingModesViews.swift`
- `App/ActivityHostCancelView.swift`
- `App/ActivityDetailView.swift`
- `App/OfficialOrganizerConsoleView.swift`
- `App/OfficialEventDetailView.swift`
- `App/OfficialPrivateViews.swift`
- `App/TeamOrientBoardView.swift`
- `App/TeamReformFlowViews.swift`
- `App/TeamComponents.swift`
- `App/SessionTeamViews.swift`
- `App/TicketWalletDetailView.swift`
- `App/OrderLifecycleView.swift`
- `App/AppSession.swift`
- `Tests/CoreTests/ActivityRegistrationParityW206Tests.swift`
- `Tests/CoreTests/HomeSearchTabParityTests.swift`
- `Tests/CoreTests/ActivityHostCancelTests.swift`
- `Tests/CoreTests/OfficialOrganizerTests.swift`
- `Tests/CoreTests/TeamOrientBoardTests.swift`
- `Tests/AppUnitTests/ActivityPublishingWizardValidationPresentationTests.swift`
- `Tests/AppUITests/OrderLifecycleUITests.swift`
- `docs/parity/page-map.csv`
- `docs/worker-reports/w4-core-loop-strings.json`
- `docs/worker-reports/W4-core-loop.md`
