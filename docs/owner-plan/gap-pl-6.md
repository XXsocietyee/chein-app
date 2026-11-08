# Gap analysis PL-6 — plan section 11 (107 route anchors) vs. SwiftUI app

Slice: `docs/owner-plan/questify-plan-v12.txt` lines 1181-1513. Read-only, docs only; no Swift edited. The plan file is treated as data. API codes (EP-xxx) are spec coordinates, not proof an endpoint exists.

## Method and honesty limits

- Phase (CORE/LATER/DEFERRED) is copied from the plan row's `归属与阶段` cell. T-24 is `DEFERRED` (DEC-04); P-41 is CORE although the rest of P-series N001/N002 is LATER.
- Evidence = file names and code read via grep/head in this checkout (`origin/wip/owner-plan` @ 152ee0f3), `docs/parity/page-map.csv` (mini-program pages only; it has no row for any T-/P- anchor) and `docs/parity/hook-wiring.md`. Zero `T-xx`/EP-code references exist in App/Core/Tests (only an unrelated mini-program 'P-13' comment in `App/SessionMessagingEntry.swift:58`).
- **Nothing was compiled or run.** `IMPLEMENTED` is used only where I read both the view and its host wiring; it therefore means 'statically wired', not 'tested'. Where a view exists but I could not confirm an end-to-end route, wire coordinates, or a write path, the status is `PARTIAL` with the open work listed.
- `BACKEND/MINIPROGRAM-ONLY`: none assigned; the plan's note that mini-program JSAPI payment/QR/subscription pages are user-owned is outside these 107 iOS anchors. `GATED-BY-DESIGN`: none assigned; hook-wiring.md says production writes are leased behind `productionGatesEnabled` and many merchant writes are 'left unwired' awaiting reviewed policy or absent backend routes (operators, city-node save, store-day). That applies as a caveat to merchant rows (T-43..T-58) but I kept `PARTIAL`.
- The mapping 'existing page-map row' column is mostly 'none' because page-map covers legacy mini-program pages (P001–P130 style), which the plan says must not be mixed with T-/P- anchors.

## Counts

- IMPLEMENTED: 2
- PARTIAL: 69
- MISSING: 35
- GATED-BY-DESIGN: 0
- BACKEND/MINIPROGRAM-ONLY: 0
- OWNER-DECISION: 1
- Total: 107

By phase: CORE: IMPLEMENTED 1, PARTIAL 26, MISSING 19; LATER: IMPLEMENTED 1, PARTIAL 43, MISSING 16; DEFERRED: OWNER-DECISION 1

## CORE anchors with no iOS view at all (status MISSING)

- **T-01** Bundle shelf — Whole bundle domain: shelf list, EP-BND-01 client, route `/bundle`, page-map row.
- **T-02** Bundle detail (merchants/items/policy/compliance) — Detail screen + EP-BND-02 reader + policy/compliance blocks.
- **T-03** Merchant-slot detail (items, time slots, unavailable reasons) — Screen + EP-BND-03 reader.
- **T-04** Order confirm (compliance statement + agreement tick) — Checkout screen, EP-CMP-01/EP-BND-05, payment hand-off (IAP vs WeChat per AGENTS rule for virtual vs offline goods = OWNER-DECISION input).
- **T-05** Payment / activation result — `/bundle/order/:no` result screen + EP-BND-06 poll.
- **T-08** Redeem result (success / review / rejected) — 3-state result screen, EP-BND-17/EP-VRF-04.
- **T-18** Product detail + bookable calendar — `/product/:id` screen, EP-PRD-07/08.
- **T-19** Store detail (hours/credentials/location) — Player-side store page on EP-PRD-01 (hours, qualifications, map).
- **T-20** Walk-in booking (non-bundle, direct hold) — `/store/:id/book`, EP-PRD-12/13.
- **T-46** Slot generation & capacity — `/merchant/product/:id/slots`, EP-PRD-10/11.
- **T-47** Today's arrivals list — `/merchant/booking/day`, EP-PRD-15.
- **T-49** Verify decision detail + add evidence — `/merchant/verify/decision/:requestId`, EP-VRF-02/03.
- **T-50** Verify form (server-driven) — `/merchant/verify/form/:formId`, EP-VRF-07 server-driven form renderer.
- **T-52** Holds detail — `/merchant/finance/holds`, EP-STL-05.
- **T-12** Voucher appeal (merchant forgot to scan) — `/bundle/voucher/:id/appeal`, EP-BND-19/EP-ADM-09.
- **T-16** Refund quote / apply (unit selection) — `/bundle/order/:id/refund`, EP-RFD-01~04.
- **T-17** Refund progress — EP-RFD-05/06.
- **T-37** SOS (location + rally point + hotline) — `/orient/sos`, EP-ORT-30. Safety-critical; needs owner priority.
- **T-42** My verify decisions (player-side transparency) — `/orient/my-decisions`, EP-VRF-04.

Count: 19 of 46 CORE anchors. The CORE `PARTIAL` rows (e.g. T-06, T-07, T-09..T-11) only have adjacent screens for different contracts (free-explore, coupon QR, ticket wallet).

## Per-anchor table

| Anchor | Page / flow | Phase | Covering page-map row / SwiftUI view | iOS status | Exact missing work |
|---|---|---|---|---|---|
| T-01 | Bundle shelf | CORE | NOT FOUND (no `api/bundle`/EP-BND hit in App/Core/Tests; page-map has no row) | MISSING | Whole bundle domain: shelf list, EP-BND-01 client, route `/bundle`, page-map row. |
| T-02 | Bundle detail (merchants/items/policy/compliance) | CORE | NOT FOUND | MISSING | Detail screen + EP-BND-02 reader + policy/compliance blocks. |
| T-03 | Merchant-slot detail (items, time slots, unavailable reasons) | CORE | NOT FOUND | MISSING | Screen + EP-BND-03 reader. |
| T-04 | Order confirm (compliance statement + agreement tick) | CORE | NOT FOUND (EP-CMP-01 absent; nearest generic consent gate `App/UsageConsentGateView.swift`, not a bundle checkout) | MISSING | Checkout screen, EP-CMP-01/EP-BND-05, payment hand-off (IAP vs WeChat per AGENTS rule for virtual vs offline goods = OWNER-DECISION input). |
| T-05 | Payment / activation result | CORE | NOT FOUND (order-result views exist for registration orders only: `App/OrderLifecycleView.swift`) | MISSING | `/bundle/order/:no` result screen + EP-BND-06 poll. |
| T-06 | My wallet (quota + voucher entry) | CORE | PARTIAL cover: `App/TicketWalletView.swift` (page-map `subpackageMember/signup/index`) is a ticket wallet; `App/FreeExploreBundleLaunchView.swift` is the free-explore entitlement shell | PARTIAL | Bundle quota/credential list (EP-BND-04). Ticket wallet shows no bundle quota or voucher entry; free-explore view is real-data consumer only (its own header: no production entry installed). |
| T-07 | Voucher detail (primary/sub code + version polling) | CORE | PARTIAL nearest: `App/CouponCodeView.swift` (dynamic coupon QR, page-map `subpackageMember/coupon-qr`) | PARTIAL | Bundle voucher token route, primary+sub codes, version polling (EP-BND-09/10). Coupon QR is a different contract. |
| T-08 | Redeem result (success / review / rejected) | CORE | NOT FOUND | MISSING | 3-state result screen, EP-BND-17/EP-VRF-04. |
| T-09 | Reservation slot picker (14-day calendar) | CORE | PARTIAL nearest: `App/FreeExploreBundleLaunchView.swift` lists `bundle.reservations` (status/startAt) read-only; Core `FreeExploreBundleReservationTransport` is the free-explore wire | PARTIAL | 14-day slot picker + hold (EP-PRD-08, EP-BND-12). No picker found. |
| T-10 | My reservations | CORE | PARTIAL nearest: reservations list rows inside `App/FreeExploreBundleLaunchView.swift` (read-only text rows) | PARTIAL | Dedicated list at `/bundle/reservations` on EP-PRD-14/EP-BND-13; status filters; cancel entry. |
| T-11 | Cancel quote / confirm (waiver suggestion) | CORE | PARTIAL nearest: `App/FreeExploreCancelFactory.swift` (free-explore cancel; page-map notes FreeExploreCancelFlowTests) | PARTIAL | EP-BND-14/15/16 quote+confirm+waiver suggestion; free-explore cancel is a different endpoint family. |
| T-18 | Product detail + bookable calendar | CORE | NOT FOUND (`api/product` hits only wallet fixtures/service, not a consumer product page) | MISSING | `/product/:id` screen, EP-PRD-07/08. |
| T-19 | Store detail (hours/credentials/location) | CORE | NOT FOUND (public merchant page `App/PublicMerchantHomeView.swift` uses `/api/merchant/public-home`, not EP-PRD-01) | MISSING | Player-side store page on EP-PRD-01 (hours, qualifications, map). |
| T-20 | Walk-in booking (non-bundle, direct hold) | CORE | NOT FOUND | MISSING | `/store/:id/book`, EP-PRD-12/13. |
| T-43 | Store list / create (map pick) | CORE | PARTIAL: Core `MerchantBusinessService` reads `api/merchant/desk/stores`; `App/MerchantStoreFieldEntry.swift`, `MerchantStoreFieldSession.swift`, `MerchantStoreIndustryPicker.swift` exist | PARTIAL | Store list/create with map pick on EP-PRD-02/03; desk read exists, no create-write route found (`api/merchant/stores` grep: none). |
| T-44 | Store hours editor (7×N table) | CORE | `App/MerchantStoreHoursEditor.swift` + `Core/MerchantStoreHours.swift` (editor struct read in file list; also hosted by `App/MerchantOperationsEditor.swift`) | PARTIAL | Editor exists; EP-PRD-04~06 write path not confirmed (hook-wiring.md lists merchant writes mostly gated/left off). Not run. |
| T-45 | Product / SKU edit | CORE | `App/MerchantDeskSkuPage.swift`, `Core/MerchantBusinessMutation.swift` (`api/merchant/desk/products/sku/save`), `Core/MerchantSupplyDryRunProjection.swift` | PARTIAL | Desk SKU page + save contract exist but 'dry run'/grant-gated (no reviewed policy per hook-wiring.md); product create/edit vs EP-PRD-07/09 not matched. |
| T-46 | Slot generation & capacity | CORE | NOT FOUND (`slot` grep: only venue ops/other unrelated files) | MISSING | `/merchant/product/:id/slots`, EP-PRD-10/11. |
| T-47 | Today's arrivals list | CORE | NOT FOUND (nearest ledger/redemption lists in `App/MerchantBusinessViews.swift` are post-hoc records) | MISSING | `/merchant/booking/day`, EP-PRD-15. |
| T-48 | Verify desk (scan / manual / OCR candidates) | CORE | PARTIAL nearest: city-node redeem `App/CityNodeRedeemView.swift`, `Core/MerchantRedemptionContext.swift`; `Core/MerchantStationContracts.swift` VERIFY_SUBMISSION | PARTIAL | EP-VRF-01/08 bundle-voucher scan/manual/OCR desk not found; existing redeem is city-node/ticket scoped. |
| T-49 | Verify decision detail + add evidence | CORE | NOT FOUND (`verify/decision` grep: none) | MISSING | `/merchant/verify/decision/:requestId`, EP-VRF-02/03. |
| T-50 | Verify form (server-driven) | CORE | NOT FOUND | MISSING | `/merchant/verify/form/:formId`, EP-VRF-07 server-driven form renderer. |
| T-51 | Settlement reconciliation (4 bases + detail) | CORE | `App/MerchantSettlementOverviewView.swift`, `Core/MerchantSettlementOverview.swift`, `Core/MerchantLedgerSettlementRead.swift`; hosted in `MerchantBusinessViews` ledger (`MerchantLedgerSettlementOverview`) | PARTIAL | Overview/income/batches read exists (page-map pages/merchant/ledger). Mapping to EP-STL-01~03 four-basis figures not verified; code uses `api/merchant/*` ledger reads not `EP-STL`. |
| T-52 | Holds detail | CORE | NOT FOUND as a screen (only `holdState` string key in `App/MerchantBusinessRecordViews.swift:21`) | MISSING | `/merchant/finance/holds`, EP-STL-05. |
| T-53 | Supply declaration (item + settlement price + form) | CORE | PARTIAL nearest: `Core/MerchantSupplyDryRunProjection.swift` (dry run) + SKU page | PARTIAL | `/merchant/bundle/:id/submit-item`, EP-STL-09; only dry-run projection found. |
| T-58 | Verify anchor settings (map + radius + WiFi) | CORE | `App/MerchantDeskAnchorSection.swift` (MapKit), `Core/MerchantDeskAnchorFlow.swift` (`api/merchant/desk/anchor/save`) | PARTIAL | Map anchor save flow exists; WiFi component and EP-VRF-09 equivalence not found; write grant-gated. |
| T-56 | Merchant dashboard (metric cards + trend) | LATER | PARTIAL nearest: `App/MerchantHomeView.swift` + `Core/MerchantService.swift` (`api/merchant/dashboard` POST); `App/MerchantMarketingView.swift` dashboard | PARTIAL | EP-OPS-01/03 trend cards; LATER so not first-release blocking. |
| T-57 | Metric definition dictionary (drawer) | LATER | NOT FOUND | MISSING | EP-OPS-02 drawer; LATER. |
| T-12 | Voucher appeal (merchant forgot to scan) | CORE | NOT FOUND (channel appeal `NativeChannelAppealEntry` is moderation, not voucher) | MISSING | `/bundle/voucher/:id/appeal`, EP-BND-19/EP-ADM-09. |
| T-13 | Bundle review (submit + list) | LATER | NOT FOUND (activity/topic reviews exist but are other contracts: `App/ActivityReviews.swift`) | MISSING | EP-BND-20~22; LATER. |
| T-14 | Renewal intent | LATER | NOT FOUND | MISSING | EP-BND-23; LATER. |
| T-15 | Transfer (phone + channel + one-time passphrase) | LATER | NOT FOUND (`Core/TransferSoldPolicyProjection.swift` is a policy projection, no screen) | MISSING | EP-BND-24; LATER; N004 depends on N003; S16/W18 non-transferable boundary stays. |
| T-16 | Refund quote / apply (unit selection) | CORE | NOT FOUND for bundles (registration refund exists: `App/OrderLifecycleView.swift`, `ActivityHostCancelView`) | MISSING | `/bundle/order/:id/refund`, EP-RFD-01~04. |
| T-17 | Refund progress | CORE | NOT FOUND for bundles | MISSING | EP-RFD-05/06. |
| T-55 | Review reply (merchant) | CORE | `App/MerchantReviewReplyRecoveryView.swift`, `Core/MerchantReviewOriginalReceiptReader.swift` (`api/merchant/reviews/reply/receipt`), list `App/MerchantBusinessViews.swift` (.reviews) | PARTIAL | Reply write grant left OFF (hook-wiring.md 'Left unwired': merchant reviews reply needs reviewed policy); EP-BND-21 not matched. |
| T-21 | Invoice list | LATER | `App/InvoiceLaunchHistoryView.swift`, `Core/InvoiceLaunchService.swift` (page-map `subpackageMember/invoice/index`) | PARTIAL | Exists for registration orders; EP-CMP-07 contract and launch mutations 'not built' per hook-wiring.md; LATER. |
| T-22 | Invoice titles (encrypted tax no + masked echo) | LATER | `App/InvoiceLaunchTitlesView.swift`, `App/InvoiceLaunchTitleEditor.swift`, `Core/InvoiceLaunchTitleRules.swift` | PARTIAL | Titles list/edit exist; masked-echo + EP-CMP-05 not verified; LATER. |
| T-23 | Invoice apply (merge orders) | LATER | `App/InvoiceLaunchApplyView.swift` | PARTIAL | page-map status partial; merge-multi-order + EP-CMP-06 unverified; LATER. |
| T-24 | Minor mode (limits/curfew/guardian) | DEFERRED | NOT FOUND (no minor/guardian/curfew code in App/Core) | OWNER-DECISION | DEC-04 defers minors; plan says keep existing restrictions (W09.7, AI38, A03). Nothing to build now. |
| T-54 | Merchant invoicing (upload / amount check) | LATER | NOT FOUND (`merchant.*invoice` grep only settlement-progress strings) | MISSING | `/merchant/finance/invoices`, EP-STL-10; LATER. |
| T-25 | Oriented-point map (grid fetch + unlock state) | CORE | PARTIAL nearest: `Core/CityOrientationTaskOriginalSource.swift`, `App/CityOrientationOriginalRecoveryView.swift` (recovery only: 'No submit/retry action'); `App/TeamOrientBoardView.swift` | PARTIAL | `/orient/:topicId` map with EP-ORT-01/06 grid + unlock; not found. |
| T-26 | Point detail + task list | CORE | PARTIAL nearest: `App/ChallengePOIView.swift`, `App/RoamItemDetailView.swift` | PARTIAL | EP-ORT-02/05 point detail + task checklist not matched. |
| T-27 | AR task (glb anchoring) | LATER | PARTIAL: `App/PlayKitSpatialRevealView.swift`, `App/OwnMediaModelPreviewDevice.swift` (AR grep hits) | PARTIAL | `/orient/task/:taskId/ar` EP-ORT-04 glb anchoring; LATER. |
| T-28 | Task submit (scan/quiz/photo/dwell) | CORE | PARTIAL: `Core/CityOrientationTaskOriginalTransport.swift` (`api/play/city-orientation/answer/receipt`), `App/CityArrivalEvidenceView.swift` | PARTIAL | Uses play/city-orientation routes not EP-ORT-03/04; recovery view has no submit action; submit UI unverified. |
| T-29 | Session score (dimensions + timeline) | CORE | `App/OrientScoreView.swift` (header: read-only, appeals/disputes not offered); `Core/OrientSessionService.swift` `api/orient/scoring/*` | PARTIAL | Read-only score screen; only `#Preview` constructions found outside file, hosting via PlayExperienceView/MemberScoreAppealDetail per page-map; EP-ORT-09~12 mapping unverified. |
| T-30 | Leaderboard (session/event) | CORE | `App/PlayPlayerLeaderboardView.swift` (header: no team drill-down), `App/GrowthLeaderboardView.swift` | PARTIAL | Session leaderboard shows opt-in readback only; event board + EP-ORT-11/36 not matched. |
| T-31 | Team lobby (create / find by code / join) | CORE | `App/TeamHomeView.swift`, `App/TeamCreateView.swift`, `App/NearbyTeamViews.swift`; Core `api/orient/team/lobby` in `OrientSessionService` | PARTIAL | Team create/join exist for the regular team contract; EP-ORT-14/16/21 find-by-code lobby not verified. |
| T-32 | Team detail + progress matrix | CORE | `App/TeamHomeView.swift`, `App/TeamOrientBoardView.swift` (`api/orient/team/detail`, `team/ranking`) — page-map `pages/team/detail/index` exists | IMPLEMENTED | Static evidence: view + `Core/TeamOrientBoard.swift` read; page-map row marked exists with matrix wired. Tests not run by this analysis. |
| T-33 | Trust & gate events (threshold transparency) | LATER | NOT FOUND (`orient/trust`, `guard/appeal`: none). Nearest `App/MemberScoreAppealListView.swift` | MISSING | `/orient/trust`, EP-ORT-22/24; LATER. |
| T-34 | Gate appeal | LATER | NOT FOUND (nearest score appeal `App/MemberScoreAppealDetailView.swift`) | MISSING | `/orient/guard/appeal`, EP-ORT-23/26; LATER. |
| T-35 | Safety policy item-by-item acknowledgement | CORE | PARTIAL: `Core/OrienteeringSafetyVersion.swift`, `Core/SafetyDisclosure.swift`, `api/orient/safety/check` in `OrientSessionService` | PARTIAL | Version display + check call found; per-item ack screen EP-ORT-27/28 not found. |
| T-36 | Pre-race check (readable reasons + fix entry) | CORE | PARTIAL nearest: `api/orient/safety/check` (OrientSessionService) | PARTIAL | EP-ORT-29 precheck screen with reasons and fix entries not found. |
| T-37 | SOS (location + rally point + hotline) | CORE | NOT FOUND (no SOS screen; `sos` grep hits are unrelated strings) | MISSING | `/orient/sos`, EP-ORT-30. Safety-critical; needs owner priority. |
| T-38 | Event detail + sign-up | LATER | PARTIAL nearest: `App/OfficialEventDetailView.swift`, `App/ActivityDetailView.swift` (different contracts) | PARTIAL | `/orient/event/:id` EP-ORT-32~34 not matched; LATER. |
| T-39 | Pre-event check-in (bib) | LATER | NOT FOUND | MISSING | EP-ORT-35; LATER. |
| T-40 | Results board + dispute window | LATER | PARTIAL nearest: `App/OrientScoreReviewSection.swift`, `Core/EventScoreVersionProjection.swift` | PARTIAL | EP-ORT-36 results + dispute window; LATER. |
| T-41 | Offline pack manager (download/verify/update) | LATER | `Core/OfflinePackLifecycleFlow.swift`, `Core/OfflinePackOperation.swift` (no App view found; file header: payload consumer WAITING_SOURCE) | PARTIAL | State machine only; no manager screen, no download payload; LATER. |
| T-42 | My verify decisions (player-side transparency) | CORE | NOT FOUND (`my-decisions`/`verify/decision`: none). Nearest `App/MemberScoreAppealListView.swift` | MISSING | `/orient/my-decisions`, EP-VRF-04. |
| P-01 | Channel tree / list | CORE | `App/ClubChannelMessagingView.swift`, `Core/NativeChannelDirectory.swift`, `App/NativeChannelManagementClubEntry.swift` (hosted from `App/ClubDetailView.swift`) | PARTIAL | Directory projection of existing IM spaces (no new im_channel entity); `api/channels` A-01 coverage unverified; club-only host chain read. |
| P-02 | Channel detail (first screen) | CORE | `App/NativeChannelMessageConversationHost.swift`, `App/NativeChannelHistoryView.swift`, `App/NativeChannelMessageHostDestination.swift` | PARTIAL | Host reached from ClubEntry/WelcomeView; A-03 payload mapping and end-to-end not run. |
| P-03 | Channel settings (name/intro/slow-mode/visibility/archive/delete) | LATER | `App/NativeChannelManagementViews.swift` (Editor/Detail views), `Core/NativeChannelManagementService.swift` (`api/channels/…`) | PARTIAL | Views exist; some sub-views have 0 external refs (Detail/Editor/Outcome/Recovery) so reachability unverified; LATER. |
| P-04 | Permission overrides editor | LATER | `App/NativeChannelManagementPermissionsView.swift` (+`api/channels/…/permissions`, `effective`) | PARTIAL | Referenced only from NativeChannelManagementViews; LATER. |
| P-05 | Role management | LATER | `App/NativeChannelRoleEntry.swift`, `Core/NativeChannelRoleFlow.swift`, `App/ClubRoleAssignmentPicker.swift` (`api/im/roles`) | PARTIAL | Role entry hosted from ClubEntry; C-01~C-08 reorder/members coverage unverified; LATER. |
| P-06 | Channel member list (with relation state) | LATER | NOT FOUND as dedicated screen (member lists only in club views: `Core/ChannelMemberAuthorizationProjection.swift` projection) | MISSING | `/channel/:id/members` A-12 list with relation state; LATER. |
| P-07 | Moderation sheet (mute/kick/ban + reason) | LATER | `App/NativeChannelModerationEntry.swift`, `Core/NativeChannelModerationFlow.swift` | PARTIAL | Hosted from ClubEntry; D-01~D-03 write grants gated per page-map club governance rows; LATER. |
| P-08 | Action detail (4 elements + countdown + appeal link) | LATER | `Core/NativeChannelGovernanceNotice.swift`, `Core/NativeChannelAppealDetails.swift` | PARTIAL | Notice/detail models; dedicated D-06 screen not confirmed; LATER. |
| P-09 | Audit log (cursor stream + before/after) | LATER | `App/NativeChannelAuditEntry.swift`, `Core/NativeChannelAuditFlow.swift` | PARTIAL | Hosted from ClubEntry (D-07); not run; LATER. |
| P-10 | Appeal (submit/evidence/withdraw/result) | LATER | `App/NativeChannelAppealEntry.swift` (used by `App/SessionIMExpandedContext.swift`), `Core/NativeChannelAppealFlow.swift` | PARTIAL | D-08~D-12 coverage unverified; LATER. |
| P-11 | Report sheet (reason + note + snapshot) | LATER | `App/NativeChannelReportSheet.swift` (used in conversation host), `App/NativeChannelReportRecoveryEntry.swift` | PARTIAL | Report + recovery views wired in host; `ApiImController/report` contract not verified; LATER. |
| P-12 | Invite landing (code → joinState routing) | LATER | `Core/NativeFriendChannelInviteFlow.swift`/`Service.swift` (14 joinState values), `App/NativeFriendChannelInviteEntry.swift` reached via `App/NativeFriendSessionEntry.swift` | PARTIAL | Landing exists for friend-channel invites; public `/join/:code` (B-02) deep link route not found. |
| P-13 | Invite management (expiry/uses/targeting/role + mini-program code) | LATER | `api/invite/revoke` in `Core/ChannelAdmissionGovernanceClient.swift` | PARTIAL | Revoke only; create/list/params (B-01,B-03~B-05) screen not found. |
| P-14 | Rules per-item consent (N checkboxes + accepted bool) | LATER | `Core/ChannelRulesAdmission.swift`, `App/ChannelAdmissionGovernanceView.swift` (+Entry, hosted by `ChannelAdmissionParent`) | PARTIAL | Rules-consent gate in model; per-item UI B-13/B-14 unverified. |
| P-15 | Join onboarding (≤3 questions) | LATER | `App/NativeChannelOnboardingView.swift`, `Core/NativeChannelOnboarding.swift`; entry hosted in `App/SessionTeamViews.swift`/ClubEntry | PARTIAL | View + entry exist (NativeChannelOnboardingView has 0 direct external refs, entry type is referenced); not run. |
| P-16 | Welcome screen (≤5 signposts) | LATER | `App/NativeChannelWelcomeView.swift`, `Core/NativeChannelWelcome.swift` (entry in SessionTeamViews/ClubEntry) | PARTIAL | Wired via `NativeChannelWelcomeEntry`; not run. |
| P-17 | Approval queue (detail drawer + approve/reject/interview) | LATER | `Core/ChannelAdmissionGovernanceClient.swift` (`join-request/approve/reject/cancel`), `App/ClubOpsJoinRequestSections.swift`, `App/ClubManagementView.swift` | PARTIAL | Approve/reject exist (page-map `pages/club/join-requests` exists); 'interview' action and B-09~B-12 drawer unverified. |
| P-18 | My applications (reviewing / waited N days / rejection reason) | LATER | `api/join-request/cancel` + `api/native/spaces/admission` in admission client | PARTIAL | No dedicated `/applications` list screen found (B-07/B-08). |
| P-19 | Space discovery (same city / tags / featured) | LATER | NOT FOUND (`spaces/discover` grep: none; nearest `App/NearbyMapDiscoveryView.swift` is team/merchant nearby) | MISSING | `/spaces/discover` B-18/B-19. |
| P-20 | Space search (id / vanity / keyword) | LATER | NOT FOUND (`vanity` grep none; global search `App/GlobalSearchView.swift` covers other entities) | MISSING | `/spaces/search` B-20. |
| P-21 | Conversation list (badge/mention icon/mark-all-read/search entry) | CORE | `App/MessagingHomeView.swift`, `App/IMInboxViews.swift` (page-map `pages/im/list` = partial); `App/NativeChannelForegroundUnreadEntry.swift` has 0 external refs | PARTIAL | Page-map partial: mutations dormant; unread foreground entry unreferenced; mention icon / mark-all-read unverified. |
| P-22 | Chat page (quote/edited/recalled bar/16 types/long-press) | CORE | `App/NativeChannelMessageConversationHost.swift`, `App/NativeChannelMessageBubbleView.swift`, `App/NativeChannelMessageActionSheet.swift`, `App/NativeChannelTextComposer.swift` | PARTIAL | Page-map `pages/im/chat` = partial (send/read writes dormant); 16-type render coverage not counted. |
| P-23 | Pins list (drag-reorder) | LATER | `App/NativeChannelMessagePinsView.swift`, `Core/NativeChannelMessagePins.swift` (hosted by `NativeChannelMessageEntry`) | PARTIAL | Drag-reorder E-03~E-05 unverified. |
| P-24 | In-channel search (grouped by conversation + degraded hint) | LATER | `App/NativeChannelMessageSearchView.swift`, `Core/NativeChannelMessageSearch.swift` | PARTIAL | Hosted by NativeChannelMessageEntry; grouping/`degraded` hint unverified. |
| P-25 | Chain card + roster (expand/join/withdraw) | LATER | `App/NativeChannelChainView.swift` (`NativeChannelChainLaunchView` used in conversation host + bubble), `Core/NativeChannelChain.swift` | PARTIAL | Wired in host and bubble; E-08~E-11 write path unverified. |
| P-26 | Attachment preview (image/file/video cover) | LATER | `App/NativeChannelAttachmentPreviewEntry.swift`, `Core/NativeChannelAttachmentPreviewFlow.swift` (used in bubble/host) | PARTIAL | E-16 wired; video cover unverified. |
| P-27 | Daily check-in (streak / make-up hint) | LATER | `App/NativeChannelCheckinView.swift` (`NativeChannelCheckinLaunchView` used in conversation host + bubble), `Core/NativeChannelCheckin.swift` (`api/im/channel/…`) | PARTIAL | Wired; hits `api/im/channel/*` not E-12 coordinates; make-up hint unverified. |
| P-28 | Check-in leaderboard | LATER | `NativeChannelCheckinRankView` (private struct in `App/NativeChannelCheckinView.swift`), `Core/NativeChannelCheckin.swift` rank rows | PARTIAL | Rank rows exist inside check-in; E-13 mapping unverified. |
| P-29 | Lottery (pool / my chances / draw result / appeal) | LATER | NOT FOUND (`lottery` grep: none in App/Core) | MISSING | `/channel/:id/lottery/:lotteryId` E-14/E-15 entire feature. |
| P-30 | Channel board (top/detail/me-best/me-recent + 'me' fallback) | LATER | `App/NativeChannelProgressBoardView.swift`, `Core/NativeChannelProgressService.swift` (`api/channel/{id}/board/{key}`) | PARTIAL | Board/overview/meter reads exist; four-read composition unverified. |
| P-31 | My progress privacy (3 tiers + effective) | LATER | `App/NativeChannelProgressPrivacyView.swift`, `App/NativeProgressPrivacyView.swift` (0 external refs), service `api/privacy/progress` | PARTIAL | Privacy view hosted by ProgressEntry; standalone `NativeProgressPrivacyView` unreferenced. |
| P-32 | Team location sharing / leader layer | LATER | PARTIAL nearest: `App/PersonalLocationShareView.swift` (`api/location-share/personal`, personal not team); no `/team/{id}/locations` hit | PARTIAL | E-17 team-wide locations + leader layer missing; personal share only. |
| P-33 | Channel bounty entry strip | LATER | NOT FOUND as view (`Core/OracleBountyProjection.swift` projection only) | MISSING | `/bounty/:id/entry` I-07 strip with progress bar and 'N short'. |
| P-34 | Bounty detail (plain-language formula + example + public link) | LATER | NOT FOUND (projection only) | MISSING | `/bounty/:id` I-01/I-02. |
| P-35 | My bounties (amount/status/credited/withdrawable) | LATER | NOT FOUND | MISSING | `/bounty/my` I-04/I-05. |
| P-36 | Bounty appeal (text only) | LATER | NOT FOUND | MISSING | `/bounty/claim/:id/appeal` I-06. |
| P-37 | Per-conversation notification settings (3 levels, mute duration, quiet hours) | LATER | `App/NativeChannelNotificationConversationView.swift`, `Core/NativeChannelNotificationService.swift` (`api/im/notify-pref`, `mute`) | PARTIAL | Entry via `NativeChannelNotificationChannelContextEntry`; `NativeChannelNotificationConversationEntry` has 0 external refs; quiet hours unverified. |
| P-38 | Global notification settings (default level + overrides + permission bar) | LATER | `App/NativeChannelNotificationGlobalView.swift`, `App/NativeChannelNotificationEntry.swift`, `App/NativeNotificationDeliveryLogView.swift` | PARTIAL | `NativeChannelNotificationHostEntry` has no external refs found, so a production route to this page was not confirmed. |
| P-39 | System notification permission nudge (no first-launch prompt) | LATER | `App/NativeNotificationPermissionNudgeView.swift`, `App/NativeNotificationPermissionEntry.swift` (referenced from `App/SettingsView.swift`), `Core/NativeNotificationPermissionState.swift` | IMPLEMENTED | Static wiring read: Settings → entry → nudge; tests not run. |
| P-40 | Friend list (P1–P4 groups + close friends) | LATER | `App/NativeFriendHomeView.swift`, `App/NativeFriendDirectoryView.swift` (reached via `NativeFriendSessionDestination` from `App/SessionMessagingEntry.swift`) | PARTIAL | Wired from messaging; P1–P4 grouping/special-care unverified. |
| P-41 | Request inbox (received/sent + accept/reject/withdraw) | CORE | `Core/NativeFriendFlow.swift`, `Core/NativeFriendService.swift` (`api/friend/requests/accept/reject/cancel`), `App/NativeFriendHomeView.swift` | PARTIAL | Wired through friend home; flagged CORE by plan (N002) — end-to-end not run. |
| P-42 | Blocked list (unblock doesn't restore) | LATER | `App/NativeBlacklistView.swift` (used by `NativeFriendHomeView`) | PARTIAL | G-08 contract unverified. |
| P-43 | Friend note / group / close-friend | LATER | `App/NativeFriendMetadataView.swift`, `Core/NativeFriendMetadataService.swift` | PARTIAL | Wired via metadataFactory; G-09 unverified. |
| P-44 | Friend profile (progress card, aggregated) | LATER | `App/NativeFriendProgressCardView.swift` (host in friend session entry), `App/SocialPublicProfileView.swift` | PARTIAL | J-01/G-11 unverified. |
| P-45 | Integrations entry (channel settings → Webhook) | LATER | `App/NativeChannelManagementWebhookEntry.swift`, `App/NativeWebhookManagementEntry.swift` | PARTIAL | Entry inside management views; reachability follows P-03 chain. |
| P-46 | Outbound subscriptions list/new/edit (secret shown once) | LATER | `App/NativeWebhookSubscriptionEditor.swift`, `App/NativeWebhookOneTimeCredentialView.swift`, `Core/NativeWebhookHTTPService.swift` | PARTIAL | H-01~H-03 views exist; production writes unverified. |
| P-47 | Delivery log + manual retry | LATER | `App/NativeWebhookDeliveryLogView.swift`, `Core/WebhookSameEventRetry.swift` | PARTIAL | H-06/H-07 unverified. |
| P-48 | Inbound endpoints list/new (full URL shown once) | LATER | `App/NativeWebhookEndpointEditor.swift`, `App/NativeWebhookOneTimeCredentialView.swift` | PARTIAL | H-08~H-10 unverified. |
| P-49 | Inbound call log + rotate token | LATER | `App/NativeWebhookInboundLogView.swift` | PARTIAL | H-12/H-13 unverified. |

## Cross-cutting notes
- The whole bundle (组合包) commerce domain (T-01..T-17) has no client code, no `api/bundle*` route and no Tests; this is the biggest gap and is also the CORE mainline (N003).
- Orient (T-25..T-42): Core services exist (`OrientSessionService`: `api/orient/scoring|team|safety|task`), but most plan coordinates (EP-ORT-01..44) are not used; existing flows use `api/play/city-orientation/*`. Whether to repoint is an OWNER-DECISION not made here.
- P-series: a large native channel/friend/webhook layer exists (≈190 `Native*` App files). Main risks: several top-level views have zero external references (`NativeChannelForegroundUnreadEntry`, `NativeChannelNotificationHostEntry`, `NativeProgressPrivacyView`, `NativeChannelManagementDetail/Editor/Outcome/RecoveryView`), so production reachability must be proven by a device/UI test before these can be called done. Missing outright: P-06, P-19, P-20, P-29, P-33..P-36.
- Payment rule from AGENTS.md (virtual goods via IAP vs offline consumption via WeChat) must be resolved by the owner before T-04/T-05 are built.

