# Parity + native audit r10 · member (`subpackageMember/`, player side)

Briefs (all in `design/handoff-r2:docs/briefs/`):
- `audit-parity-r9.md`: the method;
- `native-r2.md`: the owner's EVERYTHING-native rule;
- `owner-decisions-1124.md`: MP-first.

Reviewer run on 2026-11-26. This was a code read only: no product code was edited, nothing was compiled, and no screenshots were taken.

- **App:** `origin/ui/combined-r7` @ `82bcf2c2d` ("native r2 tokens"). That is 212 commits after the r9 base `ebf6c160c`. It includes fix/r9-member (efd8ae2aa, a481048a4), cursor/r9-member (42d84ced3), cursor/r10-invite-history, the participation, ticket, free-explore and withdrawal merges, and cursor/r11-money-on (139e06853).
- **MP:** `hengyin` @ `06a1639d`. The r9 line refs still hold.
- **Method:** the same 30 pages and 484 rows as r7 to r9. Only ✅ counts. Every r9 queue row was re-checked in code. Receipts were not trusted.
- **Native column:**
  - **native:** system List / Form / controls only;
  - **partly:** the structure is a system List or Form, but CY* chrome sits inside it;
  - **custom:** a ScrollView or card page, gradients, hex colours or forced dark.
  - `.cyText` and `CYColor` are not counted as violations, because `native-r2.md` says `.cyText` is Dynamic Type and the r2 tokens resolve to semantic colours. `CYNight.*` is counted, because it is a fixed hex (`App/DesignSystem/CYNight.swift:23`, `CYRGB(hex: 0xFFB84D)`).

## 1. Scores

| | r9 | r10 | Δ |
|---|---|---|---|
| Functions present | 440 / 484 | **451 / 484** | **+11** |
| Parity | 91 % | **93 %** | **+2 pts** |
| Excluding page 26 (MP-retired) | 420/462 (91 %) | 431/462 (93 %) | +11 |
| **Native** (native = 1, partly = ½, custom = 0) | n/a | **9.5 / 30 = 32 %** | baseline |
| Fully native pages | n/a | **0 / 30** | baseline |

Contract coverage for member (Cursor checker on `ebf6c160c`, not re-run): 103 matched / 21 missing endpoint / 52 missing test.

### Per page (parity r9 → r10, native, non-Apple elements)

| # | MP page | r9 | r10 | native | non-Apple elements (app file:line) |
|---|---|---|---|---|---|
| 1 | market/passes | 16/16 | 16/16 | custom | ScrollView page `App/PassMarketViews.swift:218`; `CYNight` hex colours ×19 (:427,429,757); RadialGradient :815,949; LinearGradient :845; Capsule chips :429,725,732; `.cyDomainCard` :268; CYPillButton :705,709,770; CYOfflineStrip :223; CYEmptyState :292,347,396; CYStateLayout :248 |
| 2 | market/pass | 13/15 | 13/15 | custom | ScrollView `App/PassMembershipViews.swift:116`; `.cyDomainCard` :228; RoundedRectangle + strokeBorder :251-253; CYStatusChip :209-211; CYNight ×17 (:125,256,258); Capsule ×8 (:145,258,275) |
| 3 | market/gift | 6/8 | **7/8** | custom | CYEmptyState + `CYNight` background `App/MPParityPassSession.swift:476-478`; it shares the market chrome of rows 1 and 2 |
| 4 | market/membership | 12/16 | 12/16 | custom | LinearGradient `App/PassMembershipViews.swift:328,478,730`; `.shadow` :722; CYLoadingStateView :99,423; CYErrorState :102; CYEmptyState :104,106 |
| 5 | market/pass-order | 7/11 | 7/11 | partly | `Form` :1144 and `.confirmationDialog` :1138 are native; CYNoteBanner `App/PassMarketViews.swift:1116`; CYLoadingStateView :602; CYStateLayout :605 |
| 6 | market/library | 9/9 | 9/9 | custom | ScrollView `App/PassMarketViews.swift:1026`; CYMorphButton :976; `.cySecondary` :983 |
| 7 | free-explore | 8/16 | **10/16** | custom | `CYCardPage` `App/FreeExploreBundleLaunchView.swift:49`; CYArtCoverHeader :50; Capsule :55; CYInfoCard ×7 (:77,143,171,243); CYPillButton ×6 (:72,78,79,110); CYNoteBanner ×4 (:69,128); CYStepIndicator :138; CYChoiceRow :147,156; CYListRow/CYRowIcon :222,274. `App/FreeExploreTopicCatalogScreen.swift:39-47` uses CYStateLayout. |
| 8 | coupon-wallet | 12/12 | 12/12 | partly | List + `.searchable` are native; ScrollView branch `App/AccountCollectionCouponsView.swift:39`; CYSkeleton :50; CYEmptyState :60,68; Capsule :249-250 |
| 9 | coupon-qr | 13/14 | 13/14 | custom | ScrollView `App/CouponCodeView.swift:27`; `CYRadius` card :38; custom backgrounds :107,160,226; CYStateLayout :138; CYEmptyState :144; confirm `.sheet` :58 (MKT-9-2) |
| 10 | coupon/coupon | 11/12 | 11/12 | partly | List + Form are native; CYPillButtonStyle ×5 `App/CouponManagementView.swift:284,295,330`; CYFooterBar :323; CYSkeleton :72,227,438; CYEmptyState :45,46,75; CYStatusChip :99 |
| 11 | invoice | 17/17 | 17/17 | partly | CYTabs (look-alike segmented control) `App/InvoiceLaunchHistoryView.swift:25`; CYFooterBar + CYPillButton :71-76; CYStatusChip :115,121; CYEmptyState :38 |
| 12 | invoice-detail | 15/15 | 15/15 | partly | CYStatusChip `App/InvoiceLaunchDetailView.swift:24,27`; CYFooterBar :110 |
| 13 | invoice-apply | 20/20 | 20/20 | partly | CYSheetContainer `App/InvoiceLaunchApplyView.swift:290`; RoundedRectangle background :317; CYFooterBar :140; CYPillButton :94,155,324 |
| 14 | invoice-titles | 12/12 | 12/12 | partly | CYFooterBar + CYPillButton `App/InvoiceLaunchTitlesView.swift:59-60`; CYEmptyState :31 |
| 15 | invoice-title-edit | 14/14 | 14/14 | partly | Form + TextField are native; CYFooterBar + CYPillButton `App/InvoiceLaunchTitleEditor.swift:90-91` |
| 16 | order/order | 16/18 | 16/18 | partly | List is native; CYStatusChip `App/ProfileOrdersView.swift:659`; OrderPillLabel :338-343; CYEmptyState :62 |
| 17 | orderinfo | 19/25 | **20/25** | partly | List sections are native; CYStatusChip `App/ProfileOrdersView.swift:714`; `Text(verbatim:)` Core zh :454,458 |
| 18 | points-history | 14/14 | 14/14 | partly | List is native; CYEmptyState `App/WalletCommerceViews.swift:542`; CYSkeleton :584-585 |
| 19 | tixianjilu | 10/12 | **11/12** | partly | List is native; CYSkeleton `App/WithdrawalHistoryView.swift:23`; CYEmptyState :51,75,78; CYStatusChip :96 |
| 20 | myinvite | 14/15 | **15/15** | partly | List + ShareLink are native; CYStatusChip `App/SocialInviteHistoryView.swift:31,74,135`; CYLoadingStateView :34,69; CYPillButton :109; CYAvatarView :120; Capsule :134 |
| 21 | signup 票夹 | 26/27 | **27/27** | custom | ScrollView carousel `App/TicketWalletView.swift:41,196,248`; CYCarouselRail/Slide :336,342; LinearGradient :427,455; `.shadow` :527; CYEmptyIllustration :66; CYStatusChip :554-557. Pass sheet: `.preferredColorScheme(.dark)` `App/TicketPassPresentView.swift:44`; CYTicketPassShape `App/TicketPassSheet.swift:230-231`; CYPassFlip :237; CYPassTear :280; LinearGradient :332; `.shadow` :267; CYMotion :243,296 |
| 22 | mycanyu | 16/16 | 16/16 | partly | CYEmptyState `App/PlayerJourneyViews.swift:144,315`; CYSkeleton :304; Capsule :328 |
| 23 | mycanyuinfo | 19/21 | **20/21** | partly | RoundedRectangle :454-455; CYStatusChip :430; `.cyPrimary`/`.cySecondary` :576,582 |
| 24 | character | 16/17 | 16/17 | custom | ScrollView `App/CharacterSheetDetailView.swift:23`; CYCard ×4 (:30,43,48); CYSectionHeader :42,47; Capsule :96,305; CYEmptyState `App/CharacterCardReadbackView.swift:24,37,49` |
| 25 | orient-score | 19/24 | **22/24** | custom | ScrollView `App/OrientScoreView.swift:107`; CYCard ×8 (:217,234,252); CYEmptyState :149,155,160; CYListRow :490; CYCard `App/OrientScoreSettlementControls.swift:160` and `App/OrientScoreReviewSection.swift:75`; CYSheetHeader `App/MPGap/Member/OrientScoreGapViews.swift:22,88` |
| 26 | mytemplate (MP-retired) | 20/22 | 20/22 | custom | LinearGradient `App/TemplateAuthoringMineView.swift:358`; CYListRow :69,75; CYPillButton :267,343. Retire per R8-MEM-26-1. |
| 27 | complaint | 19/19 | 19/19 | partly | CYEmptyIllustration `App/ProfileComplaintPreparationView.swift:142`; CYPillButton :252,302,308; CYStatusChip :280 |
| 28 | report-mine | 15/15 | 15/15 | partly | CYEmptyState `App/SquareReportProgressView.swift:79,96,100`; CYSkeleton :93; custom background :44 |
| 29 | report-detail | 17/17 | 17/17 | partly | CYListRow `App/MemberReportProgressDetailView.swift:165,182`; RoundedRectangle :58; CYStatusChip :28; CYEmptyState :124,129 |
| 30 | appeal-mine | 15/15 | 15/15 | partly | CYTabs `App/MemberScoreAppealListView.swift:70`; CYStatusChip :230,303; CYSheetHeader :199; CYEmptyState :105,151 |
| | **Total** | **440 (91 %)** | **451 (93 %)** | **32 %** | |

Shared chrome found on every page:
- `CYEmptyState` is a custom VStack (`App/DesignSystem/CYStates.swift:5`).
- `CYStatusChip`, `CYPillButton`, `CYSkeleton` and `CYFooterBar` appear throughout.

Fixing those five at the component level lifts most "partly" pages to native.

## 2. Counts (r9 queue re-check)

| | r9 open | fixed | partly | still open | new in r10 | r10 open total |
|---|---|---|---|---|---|---|
| P0 | 2 | 1 (PLY-25-2) | 1 (MKT-3-1) | 0 | 0 parity rows (see MONEY-GOV-1) | **1** |
| P1 | 10 | 4 (STR-2, FIN-19-1, PLY-21-5, PLY-23-4) | 3 (R8-MEM-26-1, MKT-7-3, FIN-17-4) | 3 (STR-1, MKT-9-2, R8-MEM-21-1) | 3 native (NAT-1..3) | **9** |
| P2 | 13 + 2 nits | 2 (R8-MEM-21-2, FIN-20-6) + NIT-2 | 1 (PLY-23-6) | 10 + NIT-1 | 14 native (NAT-4..17) | **25 + 1 nit** |

**Money: TEST-only, not a gap.** This covers pass-order pay, cancel, confirm and refund (MKT-5-3), the 立即支付 and 取消并退款 buttons (R7-MEM-16-1), and the membership buy pill.

### MONEY-GOV-1: money, not a gap, but the owner must see it

Commit 139e06853 ("业主决定生产域名也开放真钱写入", merged via cursor/r11-money-on) turns payment, refund, payout and withdrawal ON in **Release**, for any installed host including `www.chengyinhub.com`:
- `App/ReviewedAreaSwitch.swift` `openMoney` now returns `normalizedHost(apiHost) != nil`;
- the code comment cites "Owner 2026-11-25".

This contradicts two binding documents:
- `owner-decisions-1124.md` #12 ("Money on: not yet; all money writes TEST-only");
- `COORDINATOR-HANDOVER.md:19,105`.

No owner "money on" appears in the briefs. This is not a parity gap. The coordinator must either confirm the owner said "money on" or revert 139e06853 before any TestFlight.

## 3. r9 rows: status in code

| id | r10 status | evidence |
|---|---|---|
| MKT-3-1 | **partly** | The App sends the MP claim (`App/MPParityPassSession.swift:696-723`, Core `Core/PlatformPassGiftClaimSource.swift:39-62`, efd8ae2aa), with a stable requestId, reason mapping and a registrationId link. On the production host, `refuseUnwiredChinaProduction` (`:57`) refuses it: `/api/marketing/product/gifts/claim` is in no admission set (`Core/ChinaReviewedRouteCapability.swift:61-90`), and `PlayerJourneyProductionLease.refused` still lists `.giftClaim` (`Core/PlayerJourneyProductionLease.swift:26`). In Release the claim always shows 礼品当前不可领取. |
| PLY-25-2 | **fixed** (a481048a4, 42d84ced3) | `App/OrientScoreView.swift:100,202,271`; `App/OrientScoreSettlementControls.swift:223` |
| R9-MEM-STR-1 | **open** | `tools/merge_localization_fragments.py --check-member` still reports **43** differing keys (21 member-a, 22 member-b), e.g. `mp.member.buy.renew` = 续期通行证 and `accountCollection.coupons.title` = 我的优惠券 |
| R9-MEM-STR-2 | **fixed** (42d84ced3) | `tools/merge_localization_fragments.py:46,72` |
| R8-MEM-26-1 | **partly** | Core redirect per receipt, but `Core/MiniProgramPageLink.swift:124-126` still keeps the mytemplate rule, and `App/MPReviewedPageScreen.swift:282` still mounts `TemplateAuthoringMineView` |
| MKT-7-3 | **partly** | validTo :189, refundHold :201, 售后记录 :242 and canCancel :225 are now shown in `App/FreeExploreBundleLaunchView.swift`. Two gaps remain: `reservation.startAt` is printed raw at :222, and there are no 取消预约 / 更换商家 / 评价 actions. |
| FIN-17-4 | **partly** (71ac8de83) | Team, seats and club are mounted (`App/ProfileOrderSourceDetailSections.swift:70-111`). The club follow no longer sends `/api/user/follow/action`; the MP does send it. |
| FIN-19-1 | **fixed** (39b9a1f94, 42d84ced3) | `App/WithdrawalHistoryView.swift:39-48` |
| MKT-9-2 | **open** | `App/CouponCodeView.swift:21,58-63` confirm sheet still there |
| R8-MEM-21-1 | **open** | Still a separate inert list `App/TicketWalletView.swift:34,114-127,271-280` |
| PLY-21-5 | **fixed** (6b940cb8c, cfb9298ad) | `App/TicketWalletView.swift:580-584`; `App/TicketWalletDetailView.swift:44-49` |
| PLY-23-4 | **fixed** (ea3ea68c8) | `App/PlayerJourneyViews.swift:563,591` (only when 需修改) |
| PLY-23-6 | **partly** | `App/PlayerJourneyViews.swift:481-482`: one slot, the banner first and the cover as fallback. The MP has two slots (wxml:29-30 cover, :101 banner). |
| R7-MEM-7-1 | **open** | `App/FreeExploreTopicCatalogScreen.swift:96` still 暂未开售 |
| R8-MEM-7-3 | **open** | `App/FreeExploreBundleLaunchModel.swift:111` (`message: nil`); `App/FreeExploreReceiptResolveScreen.swift:49` uses fixed copy |
| R8-MEM-21-2 | **fixed** (6b940cb8c) | `App/TicketWalletDetailView.swift:25,176-177,232-245` |
| MKT-8-2 | **open** | catalog `accountCollection.coupons.title` = 我的优惠券 (goes with STR-1) |
| MKT-10-3 | **open** | `App/CouponManagementView.swift:79-81` still a push |
| R7-MEM-16-1 | **open** | The card has no 取消订单 / 取消报名 (`App/ProfileOrdersView.swift:336` comment). The label logic exists only for the detail (:777-791). |
| FIN-20-6 | **fixed** (c1a70c209) | `App/SocialInviteHistoryView.swift:18-26,88` |
| R7-MEM-24-2 | **open** | `App/CharacterSheetDetailView.swift:41-43,66-69` |
| R9-MEM-17-2 | **open** | `App/ProfileOrdersView.swift:454,458`; `App/ProfileOrderSourceDetailSections.swift:50` |
| R9-MEM-5-1 | **open** | `App/PassMarketViews.swift:1192` `defer { refusedNotice = true }` |
| R9-MEM-3-1 | **open** | `App/PassRedeemCodeView.swift` still routed at `App/MPParityKit.swift:296` |
| R9-MEM-IOS-1 | **open** | `App/DesignSystem/CYStates.swift:5` still a custom VStack. It becomes NAT-1. |
| R9-MEM-NIT-1 | **open** | `App/TicketWalletView.swift:21,74,304` |
| R9-MEM-NIT-2 | **fixed** (42d84ced3) | `Core/MPGap/Member/MemberGapModels.swift:89` |

## 4. Fix queue

Owner is Claude App or Cursor Core. "A → B" means A lands first. Each row is sized for about one agent-hour.

### P0
| id | severity | MP file:line | app file:line | what to do | owner |
|---|---|---|---|---|---|
| MKT-3-1b | P0 · partly | market/gift/index.js:101-123 | Core/ChinaReviewedRouteCapability.swift:61-90; Core/PlayerJourneyProductionLease.swift:26 | Admit `POST /api/marketing/product/gifts/claim` on the production host, and drop `.giftClaim` from `refused`. Under MP-first it is not money: the claimer sends only a token. The App side is done. | Cursor Core |

### P1
| id | severity | MP file:line | app file:line | what to do | owner |
|---|---|---|---|---|---|
| R9-MEM-STR-1a | P1 · open | coupon-wallet/index.json:3; membership/index.wxml:62-65 | Resources/Localizable.xcstrings vs docs/port/strings/fix-r3-member-a.json | Write the 21 member-a zh values into the catalog. `--check-member` must report 0 for member-a. This also closes MKT-8-2. | Claude App |
| R9-MEM-STR-1b | P1 · open | per key in the fragment | Resources/Localizable.xcstrings vs docs/port/strings/fix-r3-member-b.json | Write the 22 member-b zh values. `--check-member` must exit 0. | Claude App |
| R8-MEM-26-1b | P1 · partly | app.json (no mytemplate) | Core/MiniProgramPageLink.swift:124-126; App/MPReviewedPageScreen.swift:282 | Remove the mytemplate page rule (keep only the redirect), and delete the reviewed-page case. | Cursor Core → Claude App |
| MKT-7-3b | P1 · partly | free-explore/index.wxml:31-104 | App/FreeExploreBundleLaunchView.swift:222-229 | Format `reservation.startAt` as a date. Add 取消预约 (when `canCancel`), 更换商家 and 评价 as the MP shows them. | Claude App |
| FIN-17-4b | P1 · partly | scene-member-order-detail D:205-214 | App/ProfileOrderSourceDetailSections.swift:70-111 | Send the club follow via `/api/user/follow/action`, as the MP does. | Claude App |
| MKT-9-2 | P1 · open | coupon-qr/index.js:58-85 | App/CouponCodeView.swift:21,58-63,95-100 | Drop the confirm sheet, and issue the code on appear. | Claude App |
| R8-MEM-21-1 | P1 · open | signup/index.js:246-247,293-300,374 | App/TicketWalletView.swift:34,114-127,271-280 | Merge the companion seats into the deck as 同伴席位 cards. 开始游戏 → `entry=ticket`. | Claude App |
| NAT-1 | P1 · native | n/a | App/DesignSystem/CYStates.swift:5-60 | Back `CYEmptyState` / `CYErrorState` / `CYStateLayout` with `ContentUnavailableView` (keep the action button as `.borderedProminent`, and keep the ids). One change covers 25 call sites on member pages. | Claude App |
| NAT-2 | P1 · native | n/a | App/TicketPassPresentView.swift:44 | Remove `.preferredColorScheme(.dark)` (player page; `native-r2.md` "Remove"). | Claude App |
| NAT-3 | P1 · native | market/passes, pass, membership | App/PassMarketViews.swift:427-858; App/PassMembershipViews.swift:125-275 | Replace all 36 `CYNight.*` hex colours with semantic or accent colours, and remove the Radial/LinearGradients (:815,845,949; :328,478,730) and `.shadow` :722. | Claude App |

### P2
| id | severity | MP file:line | app file:line | what to do | owner |
|---|---|---|---|---|---|
| PLY-23-6 | P2 · partly | participation-detail wxml:29-30, :101 | App/PlayerJourneyViews.swift:481-482 | Two slots: the cover header from `record.cover`, and the banner from `templateBannerURL`. | Claude App |
| R7-MEM-7-1 | P2 · open | free-explore/index.wxml:23 | App/FreeExploreTopicCatalogScreen.swift:96 | Show 可用 / 暂不可用 per store with new keys. | Claude App |
| R8-MEM-7-3 | P2 · open | free-explore/index.js:97-270 | App/FreeExploreBundleLaunchModel.swift:111; App/FreeExploreReceiptResolveScreen.swift:49 | Show the server `msg` before the fixed fallback. | Claude App |
| MKT-10-3 | P2 · open | coupon/coupon.wxml:46 | App/CouponManagementView.swift:79-81 | Present the detail as `.sheet` with `[.medium, .large]` detents. | Claude App |
| R7-MEM-16-1 | P2 · open | scene-member-order-history/index.wxml:84-90 | App/ProfileOrdersView.swift:336 | Put 取消订单 / 取消报名 on the card, reusing the :777 label logic. 立即支付 / 取消并退款: money, not a gap. | Claude App |
| R7-MEM-24-2 | P2 · open | character/index.* | App/CharacterSheetDetailView.swift:41-43,60-70 | Remove 此刻环境 and 掷骰. | Claude App |
| R9-MEM-17-2 | P2 · open | order-detail D:110-123,260-275 | App/ProfileOrdersView.swift:454,458; App/ProfileOrderSourceDetailSections.swift:50 | Key the settlement and party labels. | Claude App |
| R9-MEM-5-1 | P2 · open (TEST path) | market/pass-order/index.js:70-127 | App/PassMarketViews.swift:1192 | Set the notice only on refusal, and reload after success. | Claude App |
| R9-MEM-3-1 | P2 · open | market/gift mode=code | App/PassRedeemCodeView.swift; App/MPParityKit.swift:296 | Delete the dead duplicate and route to `PlatformCodeRedeemPage` (`App/PassMarketViews.swift:1225`). | Claude App |
| NAT-4 | P2 · native | n/a | App/DesignSystem (CYStatusChip) | Draw `CYStatusChip` as `Text` in `.secondary` (or a tinted `Label`). No capsule. Member uses: Invoice, Orders, Withdrawal, Invite, Appeal, Report, Complaint, Coupon. | Claude App |
| NAT-5 | P2 · native | n/a | App/DesignSystem (CYPillButton, CYPillButtonStyle, `.cyPrimary` / `.cySecondary`) | Map them to `.borderedProminent` / `.bordered` / `.borderless` + `.controlSize(.large)`. Member: 35 call sites. | Claude App |
| NAT-6 | P2 · native | n/a | CYFooterBar in App/InvoiceLaunch*.swift:59-140; App/CouponManagementView.swift:323 | Move the primary action to a toolbar `.confirmationAction` or a last Form section. | Claude App |
| NAT-7 | P2 · native | n/a | CYSkeleton in App/WithdrawalHistoryView.swift:23, AccountCollectionCouponsView.swift:50, CouponManagementView.swift:72,227,438, SquareReportProgressView.swift:93, MemberReport*/MemberScoreAppeal*, WalletCommerceViews.swift:584 | Use `.redacted(reason: .placeholder)` on the real rows, or `ProgressView()`. | Claude App |
| NAT-8 | P2 · native | invoice tabs; appeal-mine tabs | App/InvoiceLaunchHistoryView.swift:25; App/MemberScoreAppealListView.swift:70-73 | Replace `CYTabs` with `Picker(.segmented)`. | Claude App |
| NAT-9 | P2 · native | free-explore/index.wxml | App/FreeExploreBundleLaunchView.swift:49-279 | Rebuild as `List(.insetGrouped)`: header `Image` in the first section; CYInfoCard → `Section`; CYChoiceRow → `Picker`; CYStepIndicator → section header text; CYNoteBanner → section footer. | Claude App |
| NAT-10 | P2 · native | orient-score/index.wxml | App/OrientScoreView.swift:107-490; App/OrientScoreSettlementControls.swift:160; App/OrientScoreReviewSection.swift:75 | ScrollView + 10 CYCards → `List` sections with `LabeledContent`. Keep the ids. | Claude App |
| NAT-11 | P2 · native | character/index.wxml | App/CharacterSheetDetailView.swift:23-96,305 | ScrollView + CYCard + CYSectionHeader → `List` sections. Capsule tags → `.secondary` text. | Claude App |
| NAT-12 | P2 · native | signup/index.wxml | App/TicketWalletView.swift:41-527 | Remove the gradients :427,455, `.shadow` :527 and the custom backgrounds :477-521. Keep the MP pager, using `TabView(.page)` instead of CYCarouselRail :336-342. | Claude App |
| NAT-13 | P2 · native | signup pass sheet | App/TicketPassSheet.swift:230-400 | Remove CYTicketPassShape / CYPassTear / CYPassFlip, LinearGradient :332, `.shadow` :267 and CYMotion. Use a plain `.sheet` with a system-background code card, like Wallet's pass back. | Claude App |
| NAT-14 | P2 · native | market/passes, library | App/PassMarketViews.swift:218,629,1026 | ScrollView card pages → `List`. Remove `.cyDomainCard` :268,463, the Capsule chips and CYMorphButton :976,1273. | Claude App |
| NAT-15 | P2 · native | market/pass, membership | App/PassMembershipViews.swift:116-530 | ScrollView → `List`. Remove RoundedRectangle + strokeBorder :251-253 and the Capsules; CYStatusChip :209-211 per NAT-4. | Claude App |
| NAT-16 | P2 · native | coupon-qr | App/CouponCodeView.swift:27-226 | Use a `List` / `VStack` with system backgrounds; drop the `CYRadius` card :38 and the custom fills :107,160,226. | Claude App |
| NAT-17 | P2 · native | invoice-apply; report-detail; mycanyuinfo; myinvite | App/InvoiceLaunchApplyView.swift:290,317; App/MemberReportProgressDetailView.swift:58,165,182; App/PlayerJourneyViews.swift:328,454-455; App/SocialInviteHistoryView.swift:120,134 | Remove the leftover RoundedRectangle / Capsule backgrounds and CYSheetContainer; CYListRow → `LabeledContent` / `NavigationLink`. | Claude App |
| R9-MEM-NIT-1 | nit | signup (no filter) | App/TicketWalletView.swift:21,74,304 | Remove the dead filter code. | Claude App |

## 5. Go-live blockers

| id | page | blocker | owner |
|---|---|---|---|
| MKT-3-1b | 3 market/gift | The production host refuses the claim, so 领取礼品 always fails in Release. | Cursor Core |
| MONEY-GOV-1 | all money pages | Money, not a gap. Release has real-money writes ON (139e06853), against owner decision #12. The owner must confirm or the change must be reverted before TestFlight. | Coordinator / owner |

## 6. Closed since r9 (verified in code)

| id | sha | app file:line |
|---|---|---|
| PLY-25-2 | a481048a4, 42d84ced3, adeaaceb8 | App/OrientScoreView.swift:100,202,271; App/OrientScoreSettlementControls.swift:223 |
| R9-MEM-STR-2 | 42d84ced3 | tools/merge_localization_fragments.py:46,72 |
| FIN-19-1 | 39b9a1f94 | App/WithdrawalHistoryView.swift:39-48 |
| PLY-21-5 | 6b940cb8c | App/TicketWalletView.swift:580-584; App/TicketWalletDetailView.swift:44-49 |
| PLY-23-4 | ea3ea68c8 | App/PlayerJourneyViews.swift:563,591 |
| R8-MEM-21-2 | 6b940cb8c | App/TicketWalletDetailView.swift:176-177,245 |
| FIN-20-6 | c1a70c209 | App/SocialInviteHistoryView.swift:18-26,88 |
| R9-MEM-NIT-2 | 42d84ced3 | Core/MPGap/Member/MemberGapModels.swift:89 |
