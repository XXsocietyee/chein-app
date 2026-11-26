# Parity re-audit r11: player-content (groups B topic, C activity, D subpackages)

- App: `origin/ui/combined-r7` @ `b9a9d4d29` (r10 audited `82bcf2c2d`; 588 commits since, including the fix-r10 content-a and content-b lanes).
- MP: `origin/mp-source:chengyinhub-xcx/` (snapshot 2026-11-24). MP paths are relative to `chengyinhub-xcx/`. In group C rows, bare `baoming.*`, `utils/quote-view.js` and `scene-play-activity-detail/*` mean `pages/activity/baoming/`, `pages/activity/utils/` and `subpackageMember/components/cy/scene-play-activity-detail/`. MP line numbers differ slightly from r10's, which used an older checkout.
- Previous report: `origin/design/handoff-r2:docs/audit/parity-r10/player-content-groups/{B-topic,C-activity,D-subpackages}.md`. Receipts checked against code: `docs/release/receipts/fix-r10-content-{a,b}.md`.
- Method: same pages, lines and formula as r10. Page parity = (✅ + ⚠️) / (lines − N/A). A line moves only when its status changed. r10 kept line counts but not line lists, so each moved line is tied to the r10 row that covers it. Every r10 row (r10 §2 and §4) was re-read in code on the tip, not in commit messages or receipts.
- Scope (owner 11-26): player side and clubs. Merchant-only pages and rows are marked `merchant release` and not counted. Money is ON in Release (payment, refund, host-cancel refund, payout, withdrawal); virtual goods are off.
- No visual redesign. A native row is **fixed** when the custom component was replaced by an Apple component, or now renders one. Shared wrappers were checked in `App/DesignSystem`: `CYEmptyState` → `ContentUnavailableView`, `CYPillButton` → system button styles, `CYLoadingStateView` → `ProgressView`, and so on. Leftovers that only affect looks (corner clips, gradient scrim, card surface on a system container, avatar art) are **closed (looks, out of scope)**. A custom control that stands in for an Apple control (custom option sheet or modal, `ScrollView` in place of `List`, custom search field) stays open. This re-classifies the receipt's "blocked (design paused)" rows.
- Caveat: this clone is shallow (boundary `0ab79f407`, 2026-11-25). Fixes at or below the boundary (R7-PC-B1-5, R7-PC-B1-7) are confirmed in code, and their SHAs come from the receipt.

## 1. Parity per MP page (r10 → r11) and area total

| group | page | r10 | r11 | Δ |
|---|---|---|---|---|
| B | topic/index | 54/59 (91.5%) | 59/59 (100%) | +5 |
| B | topic/merchantinfo (host view is player-reachable, so it counts) | 31/31 (100%) | 31/31 (100%) | 0 |
| B | topic/merchantapply | 15/17 (88.2%) | 17/17 (100%) | **merchant release**, not counted |
| B | topic/pricing | 11/18 (61.1%) | 17/18 (94.4%) | +6 |
| B | topic/pricing/partner | 10/10 | 10/10 | 0 |
| B | topic/catalog | 3/3 | 3/3 | 0 |
| C | activity/detail (+ scene-play-activity-detail) | 29/29 | 29/29 | 0 |
| C | activity/baoming | 22/25 (88.0%) | 24/25 (96.0%) | +2 |
| C | activity/list | 19/19 | 19/19 | 0 |
| C | activity/official-detail | 24/25 (96.0%) | 25/25 (100%) | +1 |
| C | activity/official-inbox | 16/16 | 16/16 | 0 |
| C | activity/official-mine | 13/14 (92.9%) | 14/14 (100%) | +1 |
| C | activity/official-organizer | 19/19 | 19/19 | 0 |
| D | myproject | 24/24 | 24/24 | 0 |
| D | infomation | 15/16 (93.8%) | 16/16 (100%) | +1 |
| D | infomationdetail | 10/10 | 10/10 | 0 |
| D | assetcenter/income-detail | 14/14 | 14/14 | 0 |
| D | assetcenter/earnings | 15/15 | 15/15 | 0 |
| D | assetcenter/analysis | 12/12 | 12/12 | 0 |
| D | video-bounty | 16/16 | 16/16 | 0 |
| D | im/list | 19/19 | 19/19 | 0 |
| D | im/chat | 21/21 | 21/21 | 0 |

| total | r10 | r11 | Δ |
|---|---|---|---|
| B (without merchantapply) | 109/121 (90.1%) | 120/121 (99.2%) | +11 |
| C | 142/147 (96.6%) | 146/147 (99.3%) | +4 |
| D | 146/147 (99.3%) | 147/147 (100%) | +1 |
| **area, in scope (r10 lines)** | **397/415 (95.7%)** | **413/415 (99.5%)** | **+16** |
| area, if the new r11 rows are counted as lines (B +3 ❌, C +1 ⚠️ +3 ❌; D new rows sit on existing ⚠️ lines) | — | 414/422 (98.1%) | |
| reference: r10 page set incl. merchantapply | 412/432 (95.4%) | 430/432 (99.5%) | +18 |

Apple components (r10 → r11): B 50% → 90% (merchantapply not counted), C 43% → mostly system (only N8/N10 still open), D 22% → 83%.

## 2. Open counts

| | P0 | P1 | P2 |
|---|---|---|---|
| r10 (B + C + D) | 2 | 15 | 76 |
| **r11** | **0** | **5** | **22** |

Of the 100 row ids tracked in r10 (§2 + §4; B 35, C 35, D 30):
- 75 are fixed or still hold, including 6 merchant release.
- 8 are closed as looks (C-N1, C-N9 and D: 6).
- 17 are partly or open (B 7, C 3, D 7).
- 0 regressed.

The r11 MP scan added 10 rows: B 3, C 5, D 2. Some open rows are partly done because the r10 fix was incomplete or aimed at the wrong thing; see §4.

## 3. Fix queue (input for fix round r11)

P1 rows come first. Every row names the MP evidence, the app site and the change. Size: S < ½ day, M ≈ 1 day, L > 1 day.

| grp | id | sev | MP file:line | app file:line | what to change | size |
|---|---|---|---|---|---|---|
| B | R7-PC-B4-3 (fee / 到手) | P1 | pages/topic/pricing/index.js:150, 171, 375-385, 489-495; index.wxml:52-55, 70-73 | Core/PublisherLifecycleContracts.swift:75-93; App/PublisherLifecycleViews.swift:102-132, 280-284; App/MPGap/PlayerContent/TopicAndOfficialGapSections.swift:66-115 | (1) Add `public let platformRate: Decimal?` to `PublisherPricingPreview`, decoded from `b["platformRate"]` as a number or numeric string; nil when empty, NaN or < 0. (2) Add `TopicPricingXcx.fee(price: Decimal, rate: Decimal?) -> (fee: Decimal, takeHome: Decimal, percent: Decimal)?`: nil when rate is nil or price ≤ 0; fee = price×rate rounded to 0.01; takeHome = price − fee; percent = round(rate×10000)/100. (3) With ≤1 ticket, show two `LabeledContent` rows under 你的终价: 平台服务费 `¥fee（pct%）` and 预计到手 `¥takeHome`. With >1 ticket, show them under each ticket `TextField` in `TopicPricingGapSection`. (4) Remove the unused `platformFeeRatePercent` row. (5) Build `ticketFields` only when `subtype == .guided` (MP index.js:469-476). (6) In `ticketPriceRows()`, reject a ticket below `preview.minimum` and show 不能低于最低价 ¥X under that ticket (MP index.js:478-484) | M |
| B | R7-PC-B1-6 (merchant cards) | P1 | pages/topic/index/index.js:489, 850-853; pages/topic/utils/topic-motion.js:178-200, 246-261; index.wxml:190-192, 414 | Core/TopicContracts.swift:126-140; Core/MPGap/PlayerContent/TopicRouteMapAndPreviewModels.swift:242-252, 385-402; App/TopicXcxSections.swift:513-520, 567-569; App/MPGap/PlayerContent/TopicRouteMapAndTeamsSection.swift:111-130 | (1) Add `merchantID` (`mmsMerchant.id`), `slogan` and `coverImage` to `TopicMerchant`. (2) Add `TopicFreeExploreMerchantCard.cards(fromChapters:)`: one card per shop id (else name) from `chapters[].nodes[].merchants`, keep `memberID` and the node name as place. (3) Then overlay the catalog perk line by `merchantId`, else `merchantName` (port `mergeExploreCatalog`). (4) Base cards need no sign-in. Also show them in the 详情 section for `productType == 2` ("参与商家 · N 家"). (5) Pass `onSelectMerchant` to open `PublicMerchantHomeView(target: .ownerMemberID(PublicMerchantOwnerID(card.memberID)), context: publicMerchant)` | M |
| C | R7-PC-C2-1 | P1 | pages/activity/baoming/baoming.wxml:205-212; utils/quote-view.js:20-71; baoming.js:1155, 1714-1719 | Core/RegistrationContracts.swift:44-101; App/RegistrationSheetView.swift:593-601; Core/RegistrationUIFlow.swift:290-297 | (a) **包含内容:** add a Core `public struct RegistrationQuoteDelivery: Decodable, Equatable`. Decode leniently: `purchaseKind` (Int or numeric String), `ticketName`, `teamSize`/`minPeople`/`maxPeople` (Int?), `needAudit` (true only when 1 or `true`), `serviceStartAt`/`serviceEndAt` (String, or epoch number where 10 digits = seconds), `beneficiaryKind`, `refundRule`. Add `public let delivery: RegistrationQuoteDelivery?` to `RegistrationQuote` (CodingKey `delivery`, `try?`). Add `func rows(locale:) -> [ActivityDeliveryItem]` that ports `deliveryRows`:<br>1. `票种类型` from map {1: 场次票, 2: 场次票, 3: 自由探索票}, only for those keys.<br>2. `perTicket` = empty `ticketName`. If true, add row `包含内容` = `按票种分别说明`. Otherwise add `人数` (min=max → "N 人"; min–max → "a–b 人"; teamSize → "N 人一队"; max only → "最多 N 人"; min only → "N 人起"), then `报名审核` = `需主办方审核` when needAudit.<br>3. `服务时间` = "yyyy.MM.dd HH:mm – yyyy.MM.dd HH:mm" in Asia/Shanghai, or "… 起" / "至 …" when one end is missing.<br>4. `使用人` = `付款人本人` for `PAYER_SELF`.<br>5. `退款` = refundRule, only when not perTicket and non-empty.<br>Row ids: kind/perTicket/people/audit/window/beneficiary/refundRule. Pass `deliveryItems: flow.quoteState.quoteValue?.delivery?.rows(locale:) ?? []` into `ActivityRegistrationGapSections`, which already titles it `registration.delivery.title` = 包含内容. Do not reuse `OrderDeliveryFacts`: its `purchaseKind` is a String and `needAudit` a Bool. (b) **Child age required:** in `prepareConfirmation()`, when `selectedTicket?.childAgeRange != nil && childAge == nil`, set a new `confirmationBlock` case `.childAgeRequired` with copy 请选择儿童年龄 (MP `isFamily` is `childCount == 1`) | M |
| C | R11-PC-C-2 | P1 | baoming.js:1150-1156, 1447-1459, 1491-1499, 1877; baoming.wxml:135-138, 174-183; utils/quote-view.js:90-135 | Core/RegistrationContracts.swift:44-101, 136-190; App/RegistrationSheetView.swift:763-813; App/G6CapabilityViews.swift:59-95; Core/RegistrationCheckoutPresentation.swift:561-576 | **Decode (`RegistrationQuote`):** `marketingSign: String?`, `listAmount: Decimal?`, `marketingDiscountAmount: Decimal?`, `marketingAdjustments: [{kind, code, label, amount}]` (keep only non-empty label with amount ≠ 0, show abs), `completeRewardCoupon` (name from `couponName`, `name` or `title`).<br>**Send:** add `marketingSign` (null when nil) to `RegistrationCreateIntent` CodingKeys and encode.<br>**Show in `quoteSection`:** when discount > 0 and adjustments are present, add a 原价 struck-through row (listAmount, only if ≠ ticket price), then one deduction `RegistrationAmountRow` per adjustment (label verbatim). Add a 完局奖励 `LabeledContent` row to the 优惠 section (`G6PromotionCatalogSection`) when the coupon is present.<br>**Create 409:** in `CheckoutOrderRebuildRule`, a msg containing 优惠已变化或与本单不一致 shows 优惠已变化或与本单不一致，请重新报价后再提交; others keep 价格已更新，请重新确认. Both re-quote | M |
| D | R11-PC-D-1 | P1 | subpackageA/pages/assetcenter/earnings/index.js:61-76 | App/WalletCommerceViews.swift:233-240, 432; App/WithdrawalSupportLandingView.swift:71-72 | In `WalletCommerceHomeView.quickItems`, make 提现 (`wallet.withdrawalSupport.open`) always open `WalletWithdrawPermissionGate()`, whatever `WalletPayoutCapability.isOn` says. Drop the `isOn` branch that opens `WithdrawalSupportLandingView`. Keep the 提现记录 item. Gate the `wallet.assets.withdraw` link (:432) the same way. Remove or hide the `bank.withdrawal.entry` `NavigationLink` in `WithdrawalSupportLandingView` (MP has no bank form). Flag it to the owner only if they want the bank form as an app-only extra. Update the contract pins that grep `WithdrawalSupportLandingView(reader: reader)` in `quickItems` (`grep -rn "wallet.withdrawalSupport.open\|bank.withdrawal.entry" Tests`) | M |
| B | R7-PC-B1-12 (consent) | P2 | pages/topic/index/index.js:2083-2139; utils/marketing-consent-entry.js:52-100 | App/TopicPurchaseRevealMount.swift:6-25; App/MPGap/PlayerContent/PlayerContentRound4Views.swift:328-375; Core/MPGap/PlayerContent/PlayerContentRound4Models.swift:136-150 | (1) After the reveal shows, `GET api/merchant/crm/marketing-consents` and pick the offer whose owner is `topic.memberId` (port `pickOffer`). (2) Set `TopicPurchaseRevealCardModel.merchantRowID` / owner id and the merchant name. (3) Bind the Toggle so that turning it on calls `submitMarketingConsent(optedIn: true, requestID:)` once per intent (reuse the id on retry). Show saving, saved or error with retry inline. (4) Fix `"channel"` to `"IN_APP"` | M |
| B | R7-PC-B1-13 | P2 | pages/topic/index/index.js:629-639, 1312-1351; index.wxml:548 | App/TopicSessionSelectionView.swift:37-89; App/PlatformConsumerSessionOwner.swift:50 | When a session is picked, push `ActivityDetailView(id:, reader:, registrationEnabled: true, opensRegistrationOnLoad: true, registrationTicketID:)` (the same as the `pages/activity/baoming/baoming` case at App/MPReviewedPageScreen.swift:139-144) instead of the plain activity page. Resolve the ticket id inside that activity by `preferredTicketName`, so the registration sheet opens with that ticket chosen | M |
| B | R7-PC-B2-5 | P2 | pages/topic/components/project-host/index.wxml:18, 64; pages/topic/merchantinfo/merchantinfo.js:2516-2545 | App/MerchantContentViews.swift:466-468 | Replace the raw `MerchantContentFields(... ["nodeFilled","nodeTotal","pendingCount"])` with `LabeledContent` 已招满 `nodeFilled/nodeTotal`, a `ProgressView(value: nodeFilled, total: nodeTotal)`, and 待审 `pendingCount`; hide pending when 0 | S |
| B | R10-PC-B-N9 | P2 | — (native) | App/MerchantContentViews.swift:106-118 | `MerchantContentDocumentView.body`: replace `ScrollView { LazyVStack {...}.padding() }` with `List { ... }.listStyle(.insetGrouped)`. Wrap each content block (`MerchantContentProjectView`, `MerchantContentRows`, the status) in `Section`s. Keep `.refreshable` and `.task` | M |
| B | R10-PC-B-N10 | P2 | — (native) | App/MerchantContentViews.swift:514, 518-534 | Once N9 is in place, drop `.buttonStyle(MerchantContentRowLinkStyle())` and delete the struct, so `NavigationLink`/`Button` rows use the system list row and disclosure | S |
| B | R11-PC-B-1 | P2 | utils/theme-records.js:35-42, 127-161; pages/topic/index/index.wxml:563 | App/TopicThemeRecordsView.swift:3, 74-120; App/PlayThemeReplayProduction.swift:78; App/MPParityKit.swift:211-218 | Add a 查看战报 `NavigationLink` in `TopicThemeCardView` to `MPReviewedPageScreen(page: "subpackageJourney/pages/report/index", query: [topicId, runId: sessionID, topicName])`. Add 再玩一局, shown only when `GET api/play/theme/state` returns `replayAllowed == true` for that session and the scope is not TEAM. It calls the existing `PlayThemeReplayProduction.replay()` and then opens `SessionPlayRuntimeView(.journey(.topic(id)))` | M |
| B | R11-PC-B-2 | P2 | pages/topic/pricing/index.js:146-147, 169-180, 188, 202; index.wxml:69, 104-105 | Core/PublisherLifecycleContracts.swift:84-93; App/PublisherLifecycleViews.swift:157-171, 280 | (1) Decode `currentPrice: Decimal?`, `selfPriceError: String?`, `confirmBlockReason: String?` and `priced: Bool?` into `PublisherPricingPreview`. (2) Start `price` at `currentPrice` when it is ≥ the floor. (3) Show `selfPriceError` in red under the final price and disable confirm while it is set. (4) When `canConfirm == false` and `productType == 2`, show `confirmBlockReason` instead of `phaseBlockedDetail`. (5) When `priced == true`, show `saleStatusText ?? 终价已确认` above the confirm button | S |
| B | R11-PC-B-3 | P2 | pages/topic/components/project-host/index.wxml:383; pages/topic/merchantinfo/merchantinfo.js:3231-3247 | App/MerchantContentViews.swift:466-484 | In the host block, add a 自己承接 row per unclaimed recruit node (`nodeId`, `chapterId`, `nodeName` from the host payload). For a free-explore host, open a `Form` sheet (name, redeem rule, capacity, valid end) that posts the MP self-supply. Otherwise push `MerchantContentEditView(service:, query: .chapters(topicID:), kind: .registrationCreate(topicID:, nodeID:))` | M |
| C | R11-PC-C-1 | P2 | utils/quote-view.js:108; baoming.js:1155, 1221 | Core/RegistrationContracts.swift:64-79, 100 | Decode `coveredByPass` from the top-level quote key (`case coveredByPass` in `CodingKeys`, true only on JSON `true`). Drop the `Marketing`/`mkt` nested decode, or keep it only as a fallback. Fix the doc comment at `:64` | S |
| C | R11-PC-C-3 | P2 | baoming.wxml:345-351; baoming.js:1300-1368; utils/marketing-consent-entry.js:52-100 | App/RegistrationSheetView.swift:252-275; Core/AccountComplianceService.swift:305 | After a successful create, GET `/api/merchant/crm/marketing-consents`. Pick the row whose `merchantOwnerMemberId` is `ActivityDetail.hostMemberID` and that is not yet opted in, as `pickOffer` does. If found, show an off-by-default `Toggle` "接收{merchantName}站内活动消息" in `resultOrderSection`. On toggle on, POST {merchantRowId, merchantOwnerMemberId, channel: "IN_APP", optedIn: true, requestId} once. Show an inline error + retry on failure. A failed GET hides the row silently | M |
| C | R11-PC-C-4 | P2 | scene-play-activity-detail/index.wxml:89-98 | App/ActivityPresentationComponents.swift:185-192, 202 | Render `ticket.registrants` as rows: `AsyncImage` avatar (`@ScaledMetric` side) + nickname, each a `NavigationLink`/`Button` to the member profile by `memberId`. When the list is empty, show secondary text 这个票种还没有人报名. Narrow `.accessibilityElement(children: .combine)` so the person rows stay tappable | S |
| C | R11-PC-C-5 | P2 | utils/quote-view.js:79-84; baoming.js:1243-1253, 1425 | Core/RegistrationContracts.swift:44-101; App/RegistrationSheetView.swift:147 (`RegistrationPaymentReadinessSection`) | Decode `paymentChannels: [String]?` on `RegistrationQuote`. When it is present, `payAmount > 0`, and it does not contain the app channel (`"APP"`), treat payment as not ready: disable the pay CTA with the reason 支付通道未就绪 and skip the readiness probe. A missing field keeps today's behaviour | S |
| C | R10-PC-C-N8 | P2 | — (native) | App/RegistrationSheetView.swift:194-233, 374-420; App/PlayAreaPopupSurfaces.swift:146-190 | Ticket picker: replace `CYOptionSheet` with `.sheet` + `NavigationStack { List { Button rows with checkmark } }` (`.presentationDetents([.medium, .large])`), or drop it since the in-form `Picker` (`:615-622`) exists. Participant picker: `List` in `.sheet`. Confirm: `CYModal` → `.alert(title, isPresented:) { Button(confirm) ; Button(role: .cancel) } message: { Text(message) }`. Non-refundable: `.alert`. Leave waitlist: `.confirmationDialog` with a `.destructive` 退出候补 button and the consequences joined into the message | M |
| C | R10-PC-C-N10 | P2 | pages/activity/list/index.wxml (search hidden on 我的) | App/OfficialEventsBrowserView.swift:34-39 | Replace the in-page `TextField` with `.searchable(text: $keyword, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("official.search"))`, applied only when `bucket.isSearchable` (wrap in a conditional modifier). Keep the `official.search` accessibility id via `.searchable` on iOS 17+ | S |
| D | R9-PC-D5-1 | P2 | subpackageA/pages/assetcenter/earnings/index.js:70-73 | App/WalletCommerceViews.swift:233-239 | Closed by the R11-PC-D-1 change: the 暂无提现权限 gate (`walletWithdrawPermission`, App/QuestifyApp.swift:572-576) must apply on the money-ON branch too | S |
| D | R9-PC-D4-1 | P2 | subpackageA/components/scene-asset-income-detail/index.js:31-39, 59-75; index.wxml:9-11 | App/WalletCommerceViews.swift:771-797 (`WalletEarningsTabBar`, `hold`), 854-870 (`incomeLedger` Picker) | (1) Add an App-side `enum WalletIncomeSegment { all, create, brand, organizer }`. Do not touch Core `WalletIncomeFilter` (its rawValues are API `eventType`). (2) In `incomeLedger`, use a 4-segment `Picker`; the 4th is `Text("wallet.earnings.tab.organizer", tableName: "WalletEarningsOverview")`, shown when `financeAccess != nil`. (3) When `.organizer` is chosen, show `WalletOrganizerFinancePane(access:mounted:)` in place of `WalletLedgerView`. Keep `WalletEarningsTabHold` (`select(.organizer/.income)`, `background()/foreground()`) driving mount, so the unit test `testTabHoldDoesNotRemountOnSwitchAndDropsOnBackground` stays valid. (4) Delete `WalletEarningsTabBar` (App/WalletEarningsOverview.swift:143-154) and App/WalletEarningsAccessibleTabs.swift. **Tests that must change together:** Tests/AppUITests/WalletEarningsOverviewUITests.swift (all 6 tests tap `app.buttons["wallet.earnings.tab.income"/"…organizer"]`, :28-29, 38, 52-54, 61-66). Retarget them to the Picker segments, e.g. `app.segmentedControls["wallet.income.filter"].buttons["主办分润"]`/`["全部"]`, or keep the ids via `.accessibilityIdentifier` on the segment `Text`. Delete Tests/AppUITests/WalletEarningsSegmentHitAreaFlowTests.swift (`testLargeTextSegmentEdgesSelectNativeTabs`, it pins the UIKit control) and Tests/AppUnitTests/WalletEarningsSegmentHitAreaTests.swift (instantiates `WalletEarningsSegmentedControl`). Remove both from tools/current_ci_manifest.json. Tests/ContractChecks/check_wallet_earnings_overview.py: keep the string pins :86-87 and the UI test names :108-112 (names unchanged); re-run it. Needs a simulator run | M |
| D | R9-PC-D9-1 | P2 | subpackageB/pages/im/chat/index.js:733-768, 850-858 | App/IMExpandedViews.swift:262-298; App/MessagingHistoryView.swift:112, 223-225 | 位置: replace the 4 `TextField`s (`name/address/latitude/longitude`) with a system location picker: a MapKit `Map` + `MKLocalSearch` sheet, or `CLLocationManager` current place + `MKReverseGeocoding`. It returns name, address and coordinate, and sends the same `.location(name:address:latitude:longitude:)` intent through `review(.send)`. 图片: when `focus == .image`, open `PhotosPicker` directly from `openAttach` (skip the `d7.chatInfo.sendPhoto` row) and hand the result to `IMImageComposeView`'s upload path | M |
| D | R9-PC-D7-2 | P2 | subpackageA/pages/video-bounty/index.wxml (no attribution) | App/VideoBountyView.swift:75, 83, 94-95; App/VideoBountySession.swift:120-150 | Delete `VideoBountyState.attribution` (and its `==` term), the `VideoBountyBinding` requirements `loadSubmissionAttribution(id:)` / `loadCampaignAttribution(campaignID:topicID:)` and their `VideoBountySessionModel` implementations. Remove `VideoBountySource.attribution(in:)` if it has no other caller (check with grep). Fix any test doubles that implement the protocol | S |
| D | R10-PC-D-N3 | P2 | subpackageA/pages/myproject/index.wxml:59 (cy-empty) | App/MyProjectTabViews.swift:97-111 | Rebuild `MyProjectEmptyView` as `ContentUnavailableView { Label { Text(keys.title) } icon: { CYStateArt(kind: .generic) } } actions: { NavigationLink(cta) { entry.make() }.buttonStyle(.borderedProminent) }`. Keep the ids `myProject.empty.<type>` and `myProject.emptyCTA.<type>`. Drop `.cyText` and `.cyPrimary` | S |
| D | R10-PC-D-N15 | P2 | subpackageA/pages/video-bounty/index.wxml | App/VideoBountyView.swift:237-242, 287-298 | Replace `MPRows(items:)` with `ForEach(rows) { submissionRow($0) }` so each row is its own List row; drop the `.padding` at :280-281. Accruals: `ForEach(rows) { LabeledContent(amountText) { views } }`, with `MPGatedNote` → Section `footer: { Label("mp.vb.accrual.note", systemImage: "lock") }`. `MPLoadSwitch` may stay (its states are `ProgressView` / `CYStateLayout`) | S |
| D | R10-PC-D-N16 | P2 | subpackageB/pages/im/list/index.wxml:78-91, 103-108 | App/MessagingHomeView.swift:38-46 | Outbox: replace `ScrollView` with `List { … }.listStyle(.insetGrouped)`; keep the `coopInviteStrip` row and `ContentUnavailableView("im.list.box.outboxEmpty")`; keep the id `messaging.list.outboxEmpty` | S |
| D | R11-PC-D-2 | P2 | subpackageA/components/scene-asset-income-detail/index.js:62-68 | Core/WalletPointsLedgerEmptyState.swift:8-9; App/WalletCommerceViews.swift:533-535 | Pass the income filter into the key: `.all` → `wallet.income.empty` (还没有收益记录); `.create` → new `wallet.income.empty.create` (创作收益还没有收益); `.brand` → new `wallet.income.empty.brand` (品牌收益还没有收益). Add zh-Hans/en to Resources/Localizable.xcstrings and update the CoreTests for `WalletPointsLedgerEmptyState.key` | S |

## 4. Regressions and receipt corrections

**No code regressions against r10.** Every line r10 had as ✅ still holds on `b9a9d4d29`. The r10 regression (C6 安全恢复原投递, `4bbba2ba4`) is fixed by `695cd746c`.

The fix-r10 receipts were wrong on these points:
- **R11-PC-D-1 (money, P1).** This was missed in r10, not caused by a new commit; the cause is `139e06853`, which was already in r10. With payout on in Release, 提现 opens `WithdrawalSupportLandingView` (App/WalletCommerceViews.swift:233-234). That links to `BankWithdrawalView`, which posts `/api/withdrawal/create` with no `withdrawable` gate. In MP, 提现 only opens the CS popup, or shows 暂无提现权限. MP removed the bank form (`subpackageA/pages/assetcenter/earnings/index.js:61-76`, PG-033). If the app-only bank form is kept on purpose, that is an owner decision.
- **R11-PC-C-1.** The `d582e632f` fix for the 通行证 row decodes `quote.mkt.coveredByPass`. MP reads the top-level `quote.coveredByPass`, and `mkt` is only page data (`pages/activity/utils/quote-view.js:107`). So the row never shows.
- **merchantinfo is not merchant only.** content-a marked R7-PC-B2-5, R10-PC-B-N9 and N10 as merchant release. The host view can be reached in Release through Publish → 我的项目 → topic (App/ProjectOwnedContentViews.swift:153) and through the pricing chapter-supply row (App/PlatformConsumerSessionOwner.swift:67-69), so these rows stay open.
- **Rows the receipts claimed but that are only partly done:**
  - R7-PC-B1-12: the consent toggle never shows because `merchantRowID` is never set, and the channel is `APP`, not `IN_APP`.
  - R7-PC-B1-6: the merchant cards come from the catalog only, guests don't see them, and they can't be tapped.
  - R7-PC-B1-13: the picker checkmarks the ticket but does not go to checkout.
  - R7-PC-C2-1: 儿童年龄 is not required before submit.
  - R9-PC-D5-1: the gate only applies when payout is off.
  - R9-PC-D9-1: 位置 is a typed lat/lng form, not a picker.
  - R9-PC-D7-2: dead attribution code remains.
  - R10-PC-D-N3: the empty state is a hand-built `VStack`.
- **Keys the receipts said were blocked on the MP source, found now:**
  - pricing fee rate = preview `platformRate`, a fraction (pages/topic/pricing/index.js:150, 171, 489-495).
  - 包含内容 rows and 票种类型 labels: pages/activity/utils/quote-view.js:20-71.
  - Both are in the fix queue.

## 5. Group detail (row-by-row evidence)

## 6B. pages/topic/*

App `origin/ui/combined-r7` @ `b9a9d4d29` (r10 audited `82bcf2c2d`). MP: `$S/mp/chengyinhub-xcx/`. In this snapshot, MP line numbers differ from r10's (for example, r10's index.js:1469 create is index.js:1485 here). Every row was re-read in code on the tip.

Method notes:
- The SHA clone is shallow (boundary `0ab79f407`, 2026-11-25). For a fix that landed at or below the boundary, `git log -S` shows the boundary commit. In that case I cite the receipt SHA and say that it is not in this clone.
- The r10 report lists line counts but not the lines themselves. I mapped every line that moved one-to-one onto the open r10 row that covers it. For topic/pricing I rebuilt its 18 lines from the MP (see the line moves list).
- Reachability (owner 11-26 rule). `pages/topic/merchantapply` is merchant only: its routes are gated by `Core/PlayerLaunch.swift:29-32` and it is linked only from the merchant recruit view (`App/MerchantContentViews.swift:422, 440`). It is reported but **excluded** from the area total. `pages/topic/merchantinfo` is **not** merchant only. Its host view (MP `role=host`, merchantinfo.js:2221; component `pages/topic/components/project-host`) is reachable by a player or club topic owner in Release without the page-route gate:
  - Publish tab → 我的项目 → topic: `App/PublishTabRootView.swift:61` → `App/ProjectOwnedContentViews.swift:153`, which shows `MerchantContentDocumentView(.project)`.
  - Topic pricing chapter-supply row: `App/PlatformConsumerSessionOwner.swift:67-69` → `App/PublisherLifecycleViews.swift:139-141`.
  
  So host-view rows count. Only the join (merchant) role is merchant release. This contradicts receipt-content-a, which marked R7-PC-B2-5, N9 and N10 as "merchant release".

| page | r10 | r11 | Δ | note |
|---|---|---|---|---|
| topic/index | 54/59 (91.5%) | **59/59 (100%)** | +5 | 3 lines ❌→✅ and 2 lines ❌→⚠️ (B1-6, B1-12 partly). New line R11-PC-B-1 ❌ → 59/60 (98.3%) |
| topic/merchantinfo | 31/31 (100%) | 31/31 (100%) | 0 | in scope (host view reachable by a player). B2-5 is still ⚠️. New line R11-PC-B-3 ❌ → 31/32 (96.9%) |
| topic/merchantapply | 15/17 (88.2%) | 17/17 (100%) | +2 | **merchant release**, excluded from the total |
| topic/pricing | 11/18 (61.1%) | **17/18 (94.4%)** | +6 | only fee / 到手 ❌. New line R11-PC-B-2 ❌ → 17/19 (89.5%) |
| topic/pricing/partner | 10/10 | 10/10 | 0 | |
| topic/catalog | 3/3 | 3/3 | 0 | dead `PublicCatalogViews` deleted |
| **total (excl. merchantapply)** | **109/121 (90.1%)** | **120/121 (99.2%)** | **+11** | with the 3 new lines: 120/124 (96.8%) |
| reference: incl. merchantapply | 124/138 (89.9%) | 137/138 (99.3%) | +13 | r10 formula and page set |

Native verdict r11 (r10 → r11):
- topic/index: custom → native. The leftovers are looks only: `CYAvatarView`, review photo clip `App/ContextualReviewComposer.swift:88`, and `CYNight` tint in `App/MPPassEntries.swift:104`.
- merchantinfo: custom → partly.
- merchantapply: native.
- pricing: partly → native.
- partner: partly → native.
- catalog: native.

Group native % without merchantapply: 90% (4.5/5). In r10 it was 50% on 6 pages.

### Line moves
- topic/index, self-play create (R8-PC-B1-1): ❌ → ✅. `4b5aa40e2`, `App/GlobalSearchLinksAndTemplates.swift:551-558`. Money is on, so a paid order is sent. With the switch off, ¥0 is still sent and paid orders show `TopicSelfPlayUnavailableSheet` (`App/TopicDetailView.swift:135-145`).
- topic/index, prep 开始游玩 → play (R7-PC-B1-5): ❌ → ✅. `0ab79f407`, `App/TopicDetailView.swift:19-20, 72-76, 125-127`; `App/PlatformConsumerSessionOwner.swift:62-64`. The safety check runs first in `PlayTopicPrepSection.beginStart`.
- topic/index, review photos (R7-PC-B1-7): ❌ → ✅. Receipt cites `ef6471025`, which is below the shallow boundary. Code: `App/ContextualReviewComposer.swift:16-22, 104` uses a ≤9 `PhotosPicker` and sends `img_arr`.
- topic/index, route progress + merchant cards (R7-PC-B1-6): ❌ → ⚠️. Progress is fixed (`002dfb536`). The cards are catalog only and cannot be tapped (`a215b7833`). See the fix queue.
- topic/index, pass reveal (R7-PC-B1-12): ❌ → ⚠️. Mounted in `858262b40`, `App/TopicSelfPlaySheet.swift:22-30`. The consent row never shows. See the fix queue.
- merchantapply, 你的门店 card and success summary (R7-PC-B3-3): ❌ → ✅ ×2. `062388650`, `App/MerchantContentEditor.swift:30-33, 236`. Merchant release.
- topic/pricing: the 7 r10 non-counted lines, rebuilt from the MP:
  - (1) confirm enabled by the grant
  - (2) confirm posts
  - (3) 200 → toast `msg` and go back
  - (4) 支付资质 → modal
  - (5) error → `submitError`
  - (6) per-ticket finals → `ticketPrices` with `guidedPrice` = min
  - (7) 平台服务费 / 预计到手
  
  (1) ❌ → ✅ (`aac860d1c`). (2)-(5) ❌ → ✅ (`8800ad57b`, `App/PublisherLifecycleViews.swift:333-362`). (6) ❌ → ⚠️ (`dfde7dbc8`; no per-ticket floor check, not gated on 有人带). (7) stays ❌.

### r10 rows (§2 r9 rows + §4 queue), re-checked on the tip

| id | r10 sev | r11 status | evidence (file:line, SHA) |
|---|---|---|---|
| R8-PC-B1-1 | P0 | fixed | `4b5aa40e2` App/GlobalSearchLinksAndTemplates.swift:551-558; Core/PlayerContentMPContract.swift:16-20; App/TopicDetailView.swift:138-140. Money is on in Release (App/ReviewedAreaSwitch.swift:79); `/api/registration/create` is `.liveInProduction` (Core/ChinaReviewedRouteCapability.swift:1633) |
| R7-PC-B2-1 | P0 | fixed (r10), still holds | Core/MerchantContentService.swift:124 (all default `true`) |
| R7-PC-B3-2 | P0 | fixed (r10), still holds; merchant release | App/MPGap/PlayerContent/PlayerContentRound4Views.swift:219, 267, 313 |
| R7-PC-B4-1 | P0 | fixed | `aac860d1c` Core/RuntimeDependencyConfiguration.swift:115-141 (`pricing` grant adds `api/topic/pricing/confirm`); Core/PlayerContentMPContract.swift:12-14 `pricingGrantEnabled { true }`; confirm route live (Core/ChinaReviewedRouteCapability.swift:1769) |
| R8-PC-B4-1 | P1 | fixed | `8800ad57b` App/PublisherLifecycleViews.swift:333-362, 185-189 |
| R7-PC-B1-4 | P1 | fixed (r10), still holds | App/AppCompositionRoot.swift:691; App/PlatformConsumerSessionOwner.swift:55 |
| R7-PC-B1-5 | P1 | fixed | `0ab79f407` App/TopicDetailView.swift:72-76, 125-127, 481 |
| R7-PC-B1-6 | P1 | **partly** | progress done: `002dfb536` App/TopicXcxSections.swift:521-526. Cards: `a215b7833` :513-520, 567-569. They come from the catalog only (Core/MPGap/PlayerContent/TopicRouteMapAndPreviewModels.swift:385-402) and have no opener (TopicRouteMapAndTeamsSection.swift:111-130). MP builds them from `registrationMerchantList` for everyone and opens the merchant home |
| R7-PC-B1-7 | P1 | fixed | receipt `ef6471025` (not in this shallow clone); App/ContextualReviewComposer.swift:16-22, 104 |
| R7-PC-B1-12 | P1 | **partly** | `858262b40` App/TopicSelfPlaySheet.swift:22-30. The consent row is dead: App/TopicPurchaseRevealMount.swift:6-25 never sets `merchantRowID`, so the Toggle at PlayerContentRound4Views.swift:371 is hidden. `submitMarketingConsent` (Core/MPGap/PlayerContent/PlayerContentRound4Models.swift:136) has no caller and sends `channel:"APP"` (:148), but MP sends `IN_APP` |
| R7-PC-B3-3 | P1 | fixed; merchant release | `062388650` App/MerchantContentEditor.swift:30-33, 236 |
| R9-PC-B3-1 | P1 | fixed (r10), still holds; merchant release | PlayerContentRound4Views.swift:24, 118-130 |
| R7-PC-B4-3 | P1 | **partly** | Per-ticket finals: `dfde7dbc8` App/PublisherLifecycleViews.swift:135, 281-284; Core/PublisherLifecycleContracts.swift:60-74, 92. Sale and pending: `36c849a9f`. Open: fee / 到手. The key is **`platformRate`** (preview `res.data.platformRate`, a fraction) at MP pricing/index.js:150, 171, 375-385, 489-495; wxml:52-55, 70-73. Not decoded in the app; `platformFeeRatePercent` is never set |
| R9-PC-B3-2 | P2 | fixed (r10), still holds; merchant release | App/MerchantContentEditor.swift:131 |
| R7-PC-B2-5 | P2 | **open** (in scope, not merchant release) | App/MerchantContentViews.swift:468 still shows raw `nodeFilled/nodeTotal/pendingCount` fields. MP project-host/index.wxml:64 has metrics and a segment bar (merchantinfo.js:2516-2545) |
| R7-PC-B1-13 | P2 | **partly** | `4cc1461c6` (its title says "partly") App/TopicSessionSelectionView.swift:13, 55-70 checkmarks the ticket. Picking a session still opens activity detail (:84-89). MP index.js:1343-1351 goes straight to `baoming?activityId&ticketId` |
| R7-PC-B1-18 | P2 | fixed (r10), still holds | App/TopicXcxSections.swift:614; Core/TopicContracts.swift:171 |
| R8-PC-B6-1 | P2 | fixed | `27c7d351d`: App/PublicCatalogViews.swift deleted; the redirect stays at App/MPReviewedPageScreen.swift:430 and Core/MiniProgramPageLink.swift:359-361 |
| R9-PC-BN-3 | P2 | fixed | `e6e9e8f5e` App/ContextualReviewComposer.swift:28-29 `@ScaledMetric` |
| R9-PC-BN-4 | P2 | fixed | `a1824d03d` App/TopicDetailView.swift:508-512 `Button` |
| R9-PC-BN-5 | P2 | fixed (r10), still holds | App/PlatformConsumerSessionOwner.swift:55 |
| R10-PC-B-N1 | P2 | fixed | `a2e6ea95c`: no `CYOptionSheet`/`CYModal`/`CYField`/`CYPrimaryButtonStyle`. App/TopicDetailView.swift:147-258 uses `List`, `Form` with `.textContentType`, and `.alert` |
| R10-PC-B-N2 | P2 | fixed | `c944cc8eb` + `a2e6ea95c` App/TopicDetailView.swift:79, 285-307; `ContentUnavailableView` for the refused state |
| R10-PC-B-N3 | P2 | fixed | `a2e6ea95c`, `a1824d03d`: `.bordered`/`.borderedProminent` at App/TopicDetailView.swift:493, 505, 547; no `.scrollContentBackground(.hidden)` |
| R10-PC-B-N4 | P2 | fixed | `a2e6ea95c` App/TopicXcxSections.swift:26-63 `Picker(.segmented)`; pinned copy on `.bar` (TopicDetailView.swift:571-580) |
| R10-PC-B-N5 | P2 | fixed | `6cbd6e71c` App/TopicXcxSections.swift:222-254 (`LabeledContent`/`NavigationLink` rows); chips and stat card plain (`a2e6ea95c`, :76-114, 117-175) |
| R10-PC-B-N6 | P2 | fixed | `1a987bb8e` App/TopicXcxSections.swift:318-330 `.background(.bar)` in `.safeAreaInset`; :394-416 pass-throughs |
| R10-PC-B-N7 | P2 | fixed | `a2e6ea95c` (no `CYNight`/`Capsule`) + `0e4bc5bc7` App/TopicXcxSections.swift:631-637 |
| R10-PC-B-N8 | P2 | fixed | `0f8388e54` App/MPGap/PlayerContent/TopicRouteMapAndTeamsSection.swift:55-78 `Marker`; no clip; teams are plain rows |
| R10-PC-B-N9 | P2 | **partly** (in scope) | `b1e2db839` `CYSkeleton` → `ProgressView`. `ScrollView` + `LazyVStack` page body stays at App/MerchantContentViews.swift:107-108, an Apple control replaced by a custom one |
| R10-PC-B-N10 | P2 | **partly** (in scope) | `b1e2db839` `ContentUnavailableView` at :293, 510. `MerchantContentRowLinkStyle` (custom row with drawn chevron and surface) stays at :514, 518-534 |
| R10-PC-B-N11 | P2 | fixed | `b1e2db839` App/MerchantContentViews.swift:215 `.confirmationDialog`; :606-611 `.borderedProminent` |
| R10-PC-B-N12 | P2 | fixed; merchant release | `81e15fa3d` PlayerContentRound4Views.swift:118-130 |
| R10-PC-B-N13 | P2 | fixed | `a72d8c1ed` App/PublisherLifecycleViews.swift:55-69, 99, 165 |
| R10-PC-B-N14 | P2 | fixed | `a72d8c1ed` App/PublisherLifecycleViews.swift (partner `ProgressView`, `.bordered`) |

Tally of the 35 r10 ids:
- 28 fixed or still holding (including 6 merchant release).
- 6 partly: B1-6, B1-12, B4-3, B1-13, N9, N10.
- 1 open: B2-5.
- 0 regressed.

### New rows (r11 scan)
- **R11-PC-B-1** (topic/index, P2). The topic page's 我的游玩记录 card has no 再玩一局 (replay) and no 查看战报 (run report).
  - MP: index.wxml:563 `cy-theme-records` with `bind:replay` / `bind:report`; utils/theme-records.js:35-42 navigates to `subpackageJourney/pages/report/index?topicId&runId`; :139-161 `GET api/play/theme/state` (`replayAllowed`), then `POST api/play/theme/replay`, then the play page.
  - App: App/TopicThemeRecordsView.swift:3 says "Read-only; no replay". `TopicThemeCardView` (:74-120) has neither action, although `PlayThemeReplayProduction` exists (App/PlayThemeReplayProduction.swift:78) and the report route exists (App/MPParityKit.swift:211-218).
- **R11-PC-B-2** (topic/pricing, P2). Four preview fields are not decoded:
  - `currentPrice`: MP index.js:146-147 starts at the saved price when it is ≥ the floor.
  - `selfPriceError`: MP index.js:169, 176; wxml:69. Red text under the price that blocks confirm.
  - `confirmBlockReason`: MP index.js:180; wxml:105. The free-explore blocked reason.
  - `priced`: MP index.js:188, 202; wxml:104. The 终价已确认 / sale-status note.
  
  App: Core/PublisherLifecycleContracts.swift:84-93 decodes none of them. App/PublisherLifecycleViews.swift:280 always starts at `initialPrice(floor:)`, and :160 shows a fixed `phaseBlockedDetail`.
- **R11-PC-B-3** (topic/merchantinfo host view, P2). 自己承接 is missing.
  - MP: pages/topic/components/project-host/index.wxml:383 `data-act="selfTakeNode"`; merchantinfo.js:3231-3247. A free-explore host gets the self-supply sheet; any other host goes to `merchantapply?topicId&nodeId&templateId=0`.
  - App: no self-take anywhere (`grep -rn "selfTake\|自己承接" App Core` finds nothing). The host block at App/MerchantContentViews.swift:466-484 only links players, reviews, node reviews and invitable.

### Regressions
None found. Every row r10 had as ✅ still holds on `b9a9d4d29`: guest read, 到店礼, the merchant write defaults, map picker, photos, `showsSubmit:false`.

Process issue, not a code regression: receipt-content-a marked R7-PC-B2-5, R10-PC-B-N9 and N10 as "merchant release". The merchantinfo host view is player-reachable in Release, so those rows stay open.

Counts (excluding merchant release and closed): **open P0 0 · P1 2 · P2 8** (10 rows: 7 partly or open r10 rows plus 3 new). In r10 the counts were P0 2 · P1 7 · P2 19.

## 6C. pages/activity/*

App `origin/ui/combined-r7` @ `b9a9d4d29` (r10 audited `82bcf2c2d`). MP `chengyinhub-xcx` snapshot 2026-11-24. Every row was re-checked in code on the tip. Receipt claims were not trusted.

Method: the same 147 r10 function lines and formula (✅+⚠️)/(lines−N/A). A line moves only when its status changed. r10 never listed the lines one by one, so each r10 ❌ line is tied to its open queue row (stated per move).

### Per-page parity

| page | r10 | r11 | Δ | note |
|---|---|---|---|---|
| C1 activity/detail (+ scene-play-activity-detail) | 29/29 (100%) | 29/29 (100%) | 0 | host cancel works in Release. Lineup is text only (new row R11-PC-C-4) |
| C2 activity/baoming | 22/25 (88.0%) | 24/25 (96.0%) | +2 | 主持预约 ❌→✅. Gap-sections line ❌→⚠️ (包含内容 missing, child age not required, pass row mis-keyed). 3 new behaviour rows not in the 147 |
| C3 activity/list | 19/19 (100%) | 19/19 (100%) | 0 | 即将上线 fixed |
| C4 activity/official-detail | 24/25 (96.0%) | 25/25 (100%) | +1 | notification permission after signup |
| C5 activity/official-inbox | 16/16 (100%) | 16/16 (100%) | 0 | busy line on the card |
| C6 activity/official-mine | 13/14 (92.9%) | 14/14 (100%) | +1 | 安全恢复原投递 restored |
| C7 activity/official-organizer | 19/19 (100%) | 19/19 (100%) | 0 | |
| **group** | **142/147 (96.6%)** | **146/147 (99.3%)** | **+4** | Counting the 4 new rows as lines (C1 +1 ⚠️, C2 +3 ❌) gives 147/151 (97.4%) |

### Line moves (r10 → r11)

- **C6 #14 安全恢复原投递 ❌ → ✅.** `695cd746c`: `App/OfficialPrivateViews.swift:276-311` shows the button when `canRecoverInapp`, with a `confirmationDialog` (`official.broadcast.recover.message` = MP copy), one request at a time, an inline error and a stats re-read. The production reader POSTs `/api/official/broadcast/{id}/recover` (`App/GlobalSearchLinksAndTemplates.swift:417-434`; request built at `Core/PlayerContentMPContract.swift:422-436`). Matches MP `official-mine/index.wxml:30` and `index.js:181-197`. The default in `Core/OfficialEventReading.swift:48` still throws; only mocks use it.
- **C4 #23 notification permission ❌ → ✅** (the only open C4 function row, R7-PC-C4-4). `c6a8f1a83` `App/PlayerGapViews.swift:89-96` calls `NativeNotificationPermissionAdapter().requestFromUserAction()` after an APPLIED signup. That is the live path when `playerGapService` is set (`App/OfficialActionViews.swift:389-391`; injected at `App/QuestifyApp.swift:621`). MP `official-detail/index.js:604-610` asks at tap time. The order differs but the behaviour is the same.
- **C2 主持预约 ❌ → ✅** (R9-PC-C2-1). `4478e3472` `App/RegistrationSheetView.swift:658-688` adds its own section: status, 付款截止 while awaiting payment, 撤销申请, and 请求主持 (`ClubHostRequestButton`). It is mounted at `:150`. Matches MP `baoming.wxml:224-241`.
- **C2 registration gap sections ❌ → ⚠️** (R7-PC-C2-1). `d582e632f` and `af0db705a` mount `ActivityRegistrationGapSections` (`App/RegistrationSheetView.swift:143, 593-601`) with the 商家暂停营业 banner, the 儿童年龄 Picker and the 通行证 row. Three gaps remain:
  - 包含内容 is missing (`deliveryItems` is never passed).
  - The child age is not required before submit. MP blocks with 请选择儿童年龄 (`baoming.js:1714-1719`).
  - The pass row reads the wrong key (R11-PC-C-1).
- No other line changed. C1 #5/#17/#21/#23/#27, C2 #11/#17/#19/#21 (except the two above), C3 #3 and C5 #14 stay as in r10. The third C2 ❌ line (unidentified in r9/r10) stays ❌.

### r10 rows: r11 status

| id | r10 sev | r11 status | evidence (file:line, SHA) |
|---|---|---|---|
| R9-PC-C1-2 | P1 | **fixed, Release verified** | Host footer: `App/ActivityDetailView.swift:712-730` (`579750de3`). `session.activityHostCancelAccess` (`App/AppSession.swift:3481-3492`) needs only `ReviewedAreaSwitch.moneyPayments(apiHost:)`, which is `openMoney`, which is true for any installed host including www.chengyinhub.com in Release (`App/ReviewedAreaSwitch.swift:94-96`, `139e06853`). The Core gate `ReleaseMoneyWriteSwitch.isEnabled(.hostCancelRefund)` (`Core/ActivityHostCancel.swift:96`) is installed in the Release path too (`App/RegionalLaunchConfiguration.swift:21` → `releaseMoneyDerivation` `.hostCancelRefund`, `App/ReviewedAreaSwitch.swift:84`). Routes `/api/activity/cancel(_preview)` are `.liveInProduction` (`Core/ChinaReviewedRouteCapability.swift:871-872`). The disabled variant (`:731-745`) shows only with no host. Doc-only leftovers: stale "TEST-only" comments at `App/AppSession.swift:3482`, `App/ActivityDetailView.swift:733-734`, `Core/ActivityHostCancel.swift:95` |
| R7-PC-C2-1 | P1 | partly | Done: banner, child-age Picker with `childAge` on quote and create, pass row mounted (`d582e632f`, `af0db705a`; `App/RegistrationSheetView.swift:593-608`). Open: 包含内容 (shape below), child age not required (`Core/RegistrationUIFlow.swift:290-297` has no gate), pass key wrong (R11-PC-C-1) |
| R9-PC-C2-1 | P1 | fixed | `App/RegistrationSheetView.swift:658-688`, `4478e3472` |
| R7-PC-C1-6 | P1 | fixed | `PhotosPicker` ≤9, `img_arr` joined with `;` (`App/ContextualReviewComposer.swift:19, 39, 104-105`; `Core/ContextualReviews.swift:18-20, 31`; `0ab79f407`). Cap 300 in UTF-16 (`Core/ContextualReviews.swift:24-27`, `11b55e20a`). The 500 at `:194` is `PlaceReviewDraft`, a different surface |
| R10-PC-C6-1 | P1 | fixed | `App/GlobalSearchLinksAndTemplates.swift:417-434`; `Core/PlayerContentMPContract.swift:422-436`; `695cd746c` |
| R10-PC-C6-2 | P1 | fixed | `App/OfficialPrivateViews.swift:276-311`, `695cd746c` |
| R9-PC-C1-1 | P2 | fixed | `ActivityCancelledStateView` shows one CTA: 查看我的订单 (pushes orders, `App/ActivityDetailView.swift:202-203`) or 返回活动列表 (`App/MPGap/PlayerContent/PlayerContentRound2Views.swift:200-216`). `c22e01bc5` |
| R7-PC-C1-5 | P2 | fixed | `ActivityTicket.registrants` decoded from `cmsRegistrationList` (`Core/ActivityDetail.swift:18, 55-56`). Lineup shown at `App/ActivityPresentationComponents.swift:185-192`. `48b65bc1a`. Residual parity is R11-PC-C-4 |
| R7-PC-C4-4 | P2 | fixed | `App/PlayerGapViews.swift:89-96`, `c6a8f1a83` |
| R7-PC-C3-3 | P2 | fixed | `official.bucket.upcoming` zh-Hans 即将上线, `0d781059d` |
| R9-PC-C3-1 | P2 | fixed (r9 false positive) | `Core/OfficialEventContracts.swift:245`, `4dbde728d` |
| R7-PC-C4-5 | P2 | fixed | `official.detail` zh-Hans 活动详情, `b3c239088` |
| R9-PC-C4-1 | P2 | fixed | Leaderboard now follows tasks (`App/OfficialEventDetailView.swift:234-236` after `:201-233`). Keys `official.leaderboard.provisional/.final` exist. `ec64ed4ef` |
| R7-PC-C5-2 | P2 | fixed | `App/OfficialActionViews.swift:10-34, 232-306` (`onBusyChange`, `writing`), `56da9bcf8` |
| R9-PC-C6-1 | P2 | fixed | `App/OfficialPrivateViews.swift:113-114`, `1f06c015d` |
| R9-PC-CN-1 | P2 | fixed | `ContentUnavailableView` + `ProgressView` (`App/ActivityDetailView.swift:168-186, 338-343`), `a22c8c50d` |
| R9-PC-CN-2 | P2 | fixed | `App/OfficialEventComponents.swift:42-44`, `0aef2aedf` |
| R9-PC-CN-3 | P2 | fixed | `@ScaledMetric` (`App/ActivityPeopleSection.swift:78, 90`; `App/ContextualReviewComposer.swift:27-29`), `e6e9e8f5e` |
| R10-PC-C-N1 | P2 | closed (looks, out of scope) | Gradient scrim + `CYRadius.xl` clip (`App/E1ActivityDetailParts.swift:55-66`) are looks only. Receipt said "blocked (design paused)" |
| R10-PC-C-N2 | P2 | fixed (component); rest closed (looks) | `CYTabs` is a segmented `Picker` (`App/DesignSystem/CYTabs.swift:174-184`, `724ae0b61`). Stats strip / `cyDomainCard` / `CYRowIcon` (`App/E1ActivityDetailParts.swift:115-149, 246, 261`) are surfaces |
| R10-PC-C-N3 | P2 | fixed; rest closed (looks) | Tiles, `bgPage` and card surfaces gone. `questifyCardListRow` (`App/ActivityDetailView.swift:398`) only sets insets and a clear background (`App/QuestifyMotionComponents.swift:22-26`) |
| R10-PC-C-N4 | P2 | fixed | 写评价 `Label` (`a8c02e0a1`). Host footer is a system `Button` (`App/ActivityDetailView.swift:715-721`). `CYPillButton` renders `.borderedProminent/.bordered/.borderless` `.large` (`App/DesignSystem/CYPillButton.swift:64-115`, `351f40779`) |
| R10-PC-C-N5 | P2 | fixed | MapKit `Map` with no forced `.light`, placeholder or clip (`App/ActivityDetailView.swift:434-443`), `58a1d349c` |
| R10-PC-C-N6 | P2 | fixed | No `cyDomainCard`/clip/`CYStatusChip` in `App/ActivityPresentationComponents.swift`, `58a1d349c` |
| R10-PC-C-N7 | P2 | fixed (component) | `CYPillButton` is a system button (above) |
| R10-PC-C-N8 | P2 | **partly (open)** | `CYLoadingStateView` is now a `ProgressView` (`App/DesignSystem/CYSharedStates.swift:33`, `351f40779`). Still custom controls in place of Apple ones: `CYOptionSheet` for the ticket and participant pickers (`App/RegistrationSheetView.swift:194-233`; `App/DesignSystem/CYSheetModal.swift:206-287`, a hand-drawn row list) and `CYModal` for the confirm, non-refundable and leave-waitlist dialogs (`App/RegistrationSheetView.swift:374-420`; `App/PlayAreaPopupSurfaces.swift:146-190`; `App/DesignSystem/CYSheetModal.swift:297+`, a scrim panel). The receipt's "blocked (design paused)" does not apply: these are controls, not looks |
| R10-PC-C-N9 | P2 | closed (looks, out of scope) | Summary card clip + `cyDomainCard` (`App/RegistrationSheetView.swift:307, 350`) |
| R10-PC-C-N10 | P2 | **partly (open)** | Segmented `Picker` + `ContentUnavailableView` done (`App/OfficialEventsBrowserView.swift:42-50, 137`, `58a1d349c`). Search is still an in-page `TextField(.roundedBorder)` (`:35-39`), not `.searchable`. `QuestifyCardButtonStyle` (`:126`) is a press effect (looks) |
| R10-PC-C-N11 | P2 | fixed | Only `.background(.bar)` is left (`App/OfficialEventComponents.swift:301`), `58a1d349c` |
| R10-PC-C-N12 | P2 | fixed; rest closed (looks) | Hero, mission card, chip and strip gone. `questifyCardListRow` (`App/OfficialEventDetailView.swift:162`) is insets only |
| R10-PC-C-N13 | P2 | fixed | `.safeAreaInset` + system `.bar` material (`App/OfficialEventDetailView.swift:283-290`) |
| R10-PC-C-N14 | P2 | fixed | No CY wrappers or page background in `App/OfficialPrivateViews.swift:1-90`, `58a1d349c` |
| R10-PC-C-N15 | P2 | fixed | Only `cySheet`/`cyPageTitle`/`cyToast` modifiers remain in `App/OfficialActionViews.swift` |
| R10-PC-C-N16 | P2 | fixed | `emptyRow` is a plain secondary `Text` in a `List` row (`App/OfficialPrivateViews.swift:162-168`). No custom chrome |
| R10-PC-C-N17 | P2 | fixed | `.confirmationDialog` (`App/OfficialOrganizerConsoleView.swift:188-198`). `CYConfirmConsequence` only feeds the message text (`:427-445`) |
| R10-PC-C-N18 | P2 | fixed | No `CYFilterChip`/`CYPillButtonStyle` left, `58a1d349c` |

### New rows (r11 scan)

- **R11-PC-C-1 (P2) 通行证 row reads the wrong key.** MP reads `quote.coveredByPass` at the top level of the quote (`pages/activity/utils/quote-view.js:90-108`, `marketingView(data)` with `data` = quote `res.data`, `baoming.js:1150-1156, 1221`). `mkt` is only the page-data name (`baoming.wxml:184-187`). The app decodes `quote.mkt.coveredByPass` (`Core/RegistrationContracts.swift:64-79, 100`, `d582e632f`), so the row never shows.
- **R11-PC-C-2 (P1) Quote promotion facts are not ported.** MP:
  - stores `marketingSign` from the quote and sends it on create (`baoming.js:1154, 1447-1459, 1877`);
  - shows 原价 struck through plus one 减免 row per `marketingAdjustments` (`baoming.wxml:174-183`; `quote-view.js:90-111`);
  - shows 完局奖励 from `completeRewardCoupon` (`baoming.wxml:135-138`; `quote-view.js:114-119`);
  - splits a create 409 into price vs marketing text (`baoming.js:1491-1499`; `quote-view.js:126-135`).

  The app has none of this. `marketingSign`, `marketingAdjustments`, `listAmount` and the text 优惠已变化 are absent from Core and App. `RegistrationQuote` (`Core/RegistrationContracts.swift:44-101`) and `RegistrationCreateIntent` (`:136-190`) only carry `quoteSign`. Money is on, so a promotion-bearing quote can lead to a marketing 409 loop (server side not verified).
- **R11-PC-C-3 (P2) No marketing opt-in on the signup result.** MP shows an optional "接收该商家站内活动消息" check on the success sheet (`baoming.wxml:345-351`; `baoming.js:1300-1368`). It is loaded via GET and saved via POST `/api/merchant/crm/marketing-consents` (`utils/marketing-consent-entry.js:52-100`). App result section `App/RegistrationSheetView.swift:252-275` has no consent row. A Core client exists in `Core/AccountComplianceService.swift:305`.
- **R11-PC-C-4 (P2) Ticket lineup is text only.** MP shows an avatar and name per registrant, a tap opens the profile, and an empty ticket says 这个票种还没有人报名 (`subpackageMember/components/cy/scene-play-activity-detail/index.wxml:89-98`). The app shows one joined text line inside a combined accessibility element (`App/ActivityPresentationComponents.swift:185-192, 202`).
- **R11-PC-C-5 (P2) Quote `paymentChannels` is ignored.** MP disables pay when `payAmount > 0` and the quote's `paymentChannels` lacks its channel (`quote-view.js:79-84`; `baoming.js:1243-1253`). `RegistrationQuote` does not decode `paymentChannels` (`Core/RegistrationContracts.swift:44-101`). Only the order side has it (`Core/OrderLifecycleContracts.swift:38, 89`).

### Regressions

None against r10. `RegistrationQuote.coveredByPass` (R11-PC-C-1, `d582e632f`) is a wrong fix, not a regression.

Counts (excluding merchant release and closed/looks): **open P0 0 · P1 2 · P2 6** (8 rows: R7-PC-C2-1, R11-PC-C-2 | R11-PC-C-1, R11-PC-C-3, R11-PC-C-4, R11-PC-C-5, R10-PC-C-N8, R10-PC-C-N10). r10 had P0 0 · P1 6 · P2 29. Of the 35 r10 queue rows: 30 fixed, 2 closed as looks (N1, N9; N2, N3 and N12 also have looks leftovers), 3 still open (R7-PC-C2-1, N8, N10).

## 6D. subpackageA / subpackageB

App `origin/ui/combined-r7` @ `b9a9d4d29` (r10 audited `82bcf2c2d`; 588 commits since). MP: `chengyinhub-xcx/` snapshot 2026-11-24. Status checked in code at the tip, not taken from the receipt. Formula as in r10: (✅+⚠️)/(lines−N/A).

### Per-page parity

| page | r10 | r11 | Δ | note |
|---|---|---|---|---|
| D1 myproject/index | 24/24 | 24/24 | 0 | 模板 tab now inline (D1-4) and post-publish link fixed (D1-1): ⚠️→✅. The empty state is still hand-built (D-N3). Native: partly |
| D2 infomation | 15/16 | 16/16 | +1 | The doc detail opens as a sheet (R7-PC-D2-4), ❌→✅. Native: yes |
| D3 infomationdetail | 10/10 | 10/10 | 0 | #8 img/a ⚠️→✅ (document order + labels). Native: yes |
| D4 income-detail | 14/14 | 14/14 | 0 | The deep link now gets 主办分润. It is still a separate UIKit tab bar, not the 4th chip (⚠️). New R11-PC-D-2 (per-filter empty copy) recorded ⚠️ on the empty-state line. Native: yes |
| D5 earnings/index | 15/15 | 15/15 | 0 | The 提现 line stays ⚠️. With money ON, Release takes the ungated bank-withdrawal path (R9-PC-D5-1 partly, R11-PC-D-1). Native: yes |
| D6 analysis/index | 12/12 | 12/12 | 0 | Charts now use Swift Charts `BarMark`. Native: yes |
| D7 video-bounty | 16/16 | 16/16 | 0 | List/Form/Picker rebuild. `MPRows` card still sits inside the List (D-N15). Native: partly |
| D8 im/list | 19/19 | 19/19 | 0 | The outbox is still a `ScrollView` (D-N16). Native: partly |
| D9 im/chat | 21/21 | 21/21 | 0 | The + items route separately. 位置 is a typed lat/lng form, not a picker (⚠️). Menu and confirm are now system. Native: yes |
| **total** | **146/147 (99.3%)** | **147/147 (100%)** | **+1** | Group native: 6 native + 3 partly = 83% (r10: 22%) |

### Line moves

- D2: 玩法文档 detail ❌→✅. `SocialPlayGuideView` presents `SocialInformationView` through `.cySheet(item: $openedDoc)` with 完成 (App/SocialGuideViews.swift:54-67, 243d3223a). MP infomation.wxml:78-83. This is the only move that changes the %.
- Moves inside ✅/⚠️ (no % change): D1 模板 tab ⚠️→✅ (7d71f2209), D1 post-publish 我的项目 ⚠️→✅ (a38979df5), D3 #8 img/a ⚠️→✅ (c2dabfef5).
- Lines that stay ⚠️ despite the receipt: D4 主办分润 segment, D5 提现 under money ON, D9 位置.

### r10 rows (§2 + §4) re-checked

| id | r10 sev | r11 status | evidence (file:line, SHA) |
|---|---|---|---|
| R7-PC-D1-4 | P1 | fixed | App/CreatorContentViews.swift:111-114: the 模板 tab renders `shelf.make(typeTabs header)`. That is the own-shelf (`TemplateAuthoringMineView.embeddedHeader` :14-16, :46) with row actions: 删除 :105, more menu :109. 7d71f2209 |
| R10-PC-D-N13 | P1 | fixed | App/VideoBountyView.swift:305-317: `VideoBountyAppealSheet` is a `Form` with a vertical `TextField`, no `CYNight`. b8e2c23a8 |
| R9-PC-D9-1 | P2 | **partly** | App/MessagingHistoryView.swift:112 `openAttach` sets `attachFocus`. App/IMExpandedViews.swift:227 (路线 opens the picker at once), :262 (图片 → photo row), :288-298 (位置). b5f6908aa. **Gap:** MP 位置 calls `wx.chooseLocation` (system map picker, chat/index.js:744-768). The app shows four `TextField`s (name/address/lat/lng). 图片 is two steps (row → `IMImageComposeView`); MP goes straight to `app.chooseImage` (js:850-858) |
| R9-PC-D4-1 | P2 | **partly** | Deep link passes `incomeOrganizerFinance(merchant:)` (App/MPReviewedPageScreen.swift:10-16, 186-188, 61f3d1269). 主办分润 is still the separate `WalletEarningsTabBar` (App/WalletCommerceViews.swift:774 → App/WalletEarningsOverview.swift:143-154 → UIKit `WalletEarningsAccessibleTabs`). The filter `Picker` has 3 segments (WalletCommerceViews.swift:856-860). See the fix queue for the tests that must change |
| R9-PC-D5-1 | P2 | **partly** | `WalletWithdrawPermissionGate` (App/WalletCommerceViews.swift:1279-1310, 7c2ae8e91) is used only on the payout-OFF branch (:235-239). With money ON (`WalletPayoutCapability.isOn` = `ReleaseMoneyWriteSwitch.withdrawalEnabled`, true for any host since 139e06853), :233-234 opens `WithdrawalSupportLandingView` with no `withdrawable` check. :432 does the same. See R11-PC-D-1 |
| R9-PC-D1-1 | P2 | fixed | App/PublishingModesViews.swift:70, 256-260: `makeProjects` (`SessionCreatorProjectsView`) is first; `PublishingProjectsView` is only the nil fallback. Hosts pass it (App/SessionPublishingModesView.swift:31, 41, 130). a38979df5 |
| R9-PC-D3-1 | P2 | fixed | App/SocialGuideViews.swift:96-111 `SocialArticleMediaBlocks.segments` renders blocks in document order. Image label `social.article.image` at App/MPGap/PlayerContent/PlayerContentRound2Views.swift:280. c2dabfef5 |
| R7-PC-D2-4 | P2 | fixed | App/SocialGuideViews.swift:32, 54-67 (sheet + 完成). 243d3223a |
| R9-PC-D9-2 | P2 | fixed | App/CommunityMemberReportSheet.swift:106-114 (`Form`, toolbar 提交), :198 `TextField(axis:.vertical)`, :221 `ContentUnavailableView`. d87b7f6ec |
| R9-PC-D7-1 | P2 | fixed | App/VideoBountyView.swift:136, 168 (`List` `.insetGrouped`), :190-205 (`Picker` + `TextField` rows, footer validation). 9e02e49a6 |
| R9-PC-D7-2 | P2 | **partly** | The sheet and the view callbacks are gone (188bb4a39; :169 note). Dead code remains: `VideoBountyState.attribution` (App/VideoBountyView.swift:75, 83), the `VideoBountyBinding` requirements `loadSubmissionAttribution` / `loadCampaignAttribution` (:94-95), and their implementations (App/VideoBountySession.swift:120-150). No caller |
| R10-PC-D-N1 | P2 | fixed | App/CreatorContentViews.swift:188-198 segmented `Picker`. a72d8c1ed |
| R10-PC-D-N2 | P2 | closed (looks) | Card chrome is gone: plain `Button` row :149-157, `card()` :205-239 is plain text + `Divider`. Only the thumbnail corner clip :212 is left (looks). a72d8c1ed |
| R10-PC-D-N3 | P2 | **partly** | `CreatorContentIssueView` is `ContentUnavailableView` + `.borderedProminent`/`.bordered` (CreatorContentViews.swift:46-74, a72d8c1ed). `CYEmptyState` / `CYLoadingStateView` now render system views (App/DesignSystem/CYStates.swift:51-56, CYSharedStates.swift:33-47). **Open:** `MyProjectEmptyView` (App/MyProjectTabViews.swift:97-111) is a hand-built `VStack` (`CYStateArt` + `.cyText(.sectionTitle)` + `.cyPrimary`) standing in for `ContentUnavailableView` |
| R10-PC-D-N4 | P2 | fixed | App/SocialGuideXcxParity.swift:21-50: `Label` row + accent 去看看, no `CYNight`. ad06ffc86 |
| R10-PC-D-N5 | P2 | fixed | App/SocialGuideTemplateSection.swift:133-142, 178-191 (`ContentUnavailableView`, `.bordered`, `ProgressView`). 开始 is tinted text (:166). The cover clip :155 is looks. 5a223a87b |
| R10-PC-D-N6 | P2 | closed (looks) | Doc rows are `Button { Label }` (SocialGuideViews.swift:31-45). Empty is `ContentUnavailableView` :27. `SocialInformationArt` :156-171 is a `.quaternary` thumbnail placeholder (looks). 35852c11d |
| R10-PC-D-N7 | P2 | closed (looks) | All states are `ContentUnavailableView` (:80-127). Plain header :174-190. Left: `.tint(CYDomainPalette(.player).brand)` :139 (accent colour = looks) and the image clip (PlayerContentRound2Views.swift:277) |
| R10-PC-D-N8 | P2 | fixed | Income rows are plain List rows (App/WalletCommerceViews.swift:692-741), badge as secondary text :706-711. No `WalletIncomeListCard`. 63c28ff09 |
| R10-PC-D-N9 | P2 | closed (looks) | `List` `.insetGrouped` with system background (:163, 190), `ProgressView` :167. `WalletEarningsHero` :1228-1250 is system fonts only (layout = looks). 63c28ff09 |
| R10-PC-D-N10 | P2 | fixed | `WalletQuickAction` = system `.borderedProminent` / `.bordered` `NavigationLink`/`Button` (:1175-1209). The 更多 sheet is a standard `List` :347-375. No `orderCardSurface` / `CYListRow`. 63c28ff09 |
| R10-PC-D-N11 | P2 | fixed | App/WalletEarningsParity.swift:20-42 `ContentUnavailableView` + `.bordered`. The icon is MP art (looks). 8bd25cb04 |
| R10-PC-D-N12 | P2 | fixed | App/WalletIncomeAnalysisView.swift:2, 164 Swift Charts `BarMark`; :139 `ProgressView(value:)`; :98 `ContentUnavailableView`. 63c28ff09 |
| R10-PC-D-N14 | P2 | fixed | App/VideoBountyView.swift:136-168 `List` + segmented `Picker` :153-158 + `.borderedProminent` :226. No `MPNightGround` / `CYMorphButton` / `MPChipTabs`. 9e02e49a6 |
| R10-PC-D-N15 | P2 | **partly** (not "blocked") | `CYEmptyState` and `CYStatusChip` now render system views. Still open: `MPLoadSwitch` → `MPRows` → `MPCard` (`.cyDomainCard`, App/MPParityKit.swift:359-364, 425-435) puts a card with `MPDivider` hairlines inside one List row (App/VideoBountyView.swift:237-242, 287-298). `MPGatedNote` :297. This is a custom list standing in for `List` rows |
| R10-PC-D-N16 | P2 | **partly** | `CYPillButtonStyle` and the page background are gone. The outbox is still `ScrollView { … ContentUnavailableView }` (App/MessagingHomeView.swift:38-46) instead of a `List`. 28976a8a0 |
| R10-PC-D-N17 | P2 | closed (looks) | The 官方 tag `CYStatusChip` renders secondary text (CYStatusChip.swift:40-60). `CYIMCoverArt` avatar fallback + circle clip (App/IMInboxViews.swift:99-105) is avatar art (looks) |
| R10-PC-D-N18 | P2 | fixed | The ⋯ menu is a system `Menu` (App/MessagingHistoryView.swift:654-678; `CYOptionSheetItem` is now only a data struct). The confirm is `MemberConfirmSheet` = `List(.insetGrouped)` + `.borderedProminent` (:916; App/MemberAreaPopupSurfaces.swift:850-930). 28976a8a0. The receipt's "blocked" is stale |
| R10-PC-D-N19 | P2 | fixed (looks remainder closed) | Reply bars are `Label` + `.bar` (:186-200). States are `ContentUnavailableView` (:815, 829, 845). No `CYListRow` / `CYSkeleton` / page background. The notice card `.background(.quaternary, in: .rect)` :562 and the avatar `Circle` clips :267, 594 are looks. 28976a8a0 |
| R10-PC-D-N20 | P2 | closed (looks) | The field is a system `TextField(axis:.vertical)` (App/MessageActionComposer.swift:164). Send is a system `Button` `.borderless` (:206). Retry is `CYConfirmSheet` = system sheet + `Form` (App/DesignSystem/CYConfirmSheet.swift:99-130). The rounded field fill :216, the circle/blur send glyph :192-202 and the receipt bubble :291 are looks |

r10 rows: 30. Fixed 17, closed (looks) 6, partly 7 (R9-PC-D9-1, R9-PC-D4-1, R9-PC-D5-1, R9-PC-D7-2, D-N3, D-N15, D-N16), regressed 0.

Where the receipt does not hold:
- The receipt says D9-1, D5-1, D7-2 and D-N3 are fixed. They are partly.
- The receipt marks D-N15, D-N17, D-N20 and D-N18 as "blocked (design paused)". Under the rule they are re-classed: D-N15 is open (custom list standing in for `List`), D-N17 and D-N20 are closed (looks), and D-N18 is fixed.

### New rows

| id | sev | finding |
|---|---|---|
| R11-PC-D-1 | P1 (money) | MP 提现 never writes. It checks `roleGuard.can('withdrawable')` → toast 暂无提现权限, else `withdrawCs.showWithdrawCsPopup()` (subpackageA/pages/assetcenter/earnings/index.js:61-76). The comment at js:61-62 says the bank form and the `/api/withdrawal/create` submit were deleted (PG-033). `subpackageA/utils/withdrawal-preflight.js` has no live page caller. The app with money ON opens `WithdrawalSupportLandingView` from 提现 (App/WalletCommerceViews.swift:233-234; assets link :432). That view links `bank.withdrawal.entry` → `BankWithdrawalView` (App/WithdrawalSupportLandingView.swift:71-72), which submits `api/withdrawal/create` (App/BankWithdrawalView.swift:350-355 → Core/BankWithdrawalAdapter.swift:137). None of this is gated on `withdrawable`. Money ON does not add a write the MP does not have, so this is a gap. It is not a regression: the path exists since 139e06853, which is already in r10, and r10 missed it |
| R11-PC-D-2 | P2 | MP income-detail empty title follows the filter: 还没有收益记录 / 创作收益还没有收益 / 品牌收益还没有收益 (subpackageA/components/scene-asset-income-detail/index.js:62-68). The app always shows `wallet.income.empty` = 还没有收益记录 (Core/WalletPointsLedgerEmptyState.swift:9; App/WalletCommerceViews.swift:533-535) |

### Regressions vs r10

None found in group D. The money-ON withdrawal path (R11-PC-D-1) predates r10 (139e06853 is an ancestor of `82bcf2c2d`), so it is a missed row, not a regression.

**Open in D after r11: P0 0 · P1 1 · P2 8** (excludes closed (looks) 6 and merchant release 0). Fixed since r10: 17 rows; closed (looks): 6; partly 7 + new 2 = the 9 queue rows.
