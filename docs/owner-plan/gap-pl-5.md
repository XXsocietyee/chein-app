# Gap analysis PL-5 — plan lines 865-1181 (ledger of original requirement IDs)

Branch `cloud/pl-5` @ `wip/owner-plan`. Read-only; no Swift edited. The plan file is treated as data.
Slice = W10.2-W10.3, W11, W12, W13, W14, W15, W16, W17, W18, W19, W20, L01-L03, A01-A09 (**90 IDs**). `W10.1` (line 860) sits before the slice and is excluded.

Method: for each ID I took the ledger's remaining/unproven clauses, then grepped and read the iOS code in `App/`, `Core/`, `Tests/`. Files marked "(exists)" were confirmed to exist but not read line by line; they are not claimed as proof. No row is marked IMPLEMENTED: no ID in this slice had all its iOS clauses proven by code I read. Most ledger rows are `无法核实` (unverifiable) with no named breakpoint, so those rows say so.
Caveats: (1) the plan cites `App/SideQuestPlayerEntry.swift` and `Core/SideQuestPlayerFlow.swift` @f8161adb; neither exists on this branch (grep finds only `sideQuestPlayer` nil-checks). (2) `docs/parity/page-map.csv` has no side-quest, location-share, walking-nav or workshop rows I could tie to these IDs. `hook-wiring.md` lists nothing for these IDs; it says production leases stay nil unless `productionGatesEnabled` (China), e.g. `nativeHomeReturnApprovalSelector` defaults to nil (App/AppSession.swift:1904).

## Counts per status

| Status | Count |
|---|---|
| IMPLEMENTED with proof | 0 |
| PARTIAL | 42 |
| MISSING | 4 |
| GATED-BY-DESIGN | 4 |
| BACKEND/MINIPROGRAM-ONLY | 33 |
| OWNER-DECISION | 7 |
| **Total** | 90 |

## Table

| ID | Remaining (unproven) clauses | iOS or backend? | iOS status | Proof (file:line) | Exact missing iOS work |
|---|---|---|---|---|---|
| W10.2 | Goods-repurchase and refund-adjusted net-revenue cells are marked unsupported by the backend calculator (Calculator.java:82). | Backend produces; iOS only renders the report. | PARTIAL | Core/SecondRegistrationMetrics.swift:8; App/SecondRegistrationStatsView.swift:5; Tests/CoreTests/SecondRegistrationMetricsTests.swift:11 | No iOS model/cell for goods-repurchase or net-revenue (grep GOODS_REPURCHASE/NET_REVENUE = no hits); add decode + "unavailable" cells once backend ships. |
| W10.3 | Remaining clauses not enumerated by the ledger (only "retain evidence-coverage clauses"); no concrete breakpoint. | Backend report; iOS reads it. | PARTIAL | Core/SecondRegistrationMetrics.swift:8; App/SecondRegistrationStatsView.swift:5 | Needs clause-level mapping of the original sentence; no specific iOS work identifiable. |
| W12.1 | Full original sentence not proven; fixtures and preflight runner exist. | Mixed: backend IT + iOS preflight runner. | PARTIAL | Core/AppStoreSubmissionFinalPreflightGateRunner.swift (file exists, run not verified) | Confirm runner covers the sentence; no iOS code gap named. |
| W12.2 | Remaining sentence not proven; real MySQL/Redis IT covers freeze/rollback/restart/concurrency. | Backend/test only. | BACKEND/MINIPROGRAM-ONLY | NOT FOUND (backend IT) | None on iOS. |
| W12.3 | Remaining sentence not proven; targeted conservation assertions exist in backend IT. | Backend/test only. | BACKEND/MINIPROGRAM-ONLY | NOT FOUND (backend IT) | None on iOS. |
| W12.4 | Business load test is not implemented; only pipeline description/sample checks exist. | Backend/ops load test; iOS has a descriptive audit only. | BACKEND/MINIPROGRAM-ONLY | Core/ProductionTelemetryAndPrivacyRedactionPipelineAudit.swift (audit description only) | No iOS load-test work; do not count the audit as stress test. |
| W11.1 | Client compatibility-capability contract not proven for the remaining sentence. | Mixed. | PARTIAL | Core/UnifiedOPT070To072ReceiptCapabilitiesMigrationAndTraceContract.swift (exists) | Show client reads capabilities and degrades on old servers; no named breakpoint. |
| W11.2 | Remaining sentence not proven; PII small-batch backfill exists. | Backend only. | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None on iOS. |
| W11.3 | Remaining sentence not proven; current/default compat query and legacy single-session adapter exist. | Backend only. | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None on iOS. |
| W11.4 | Remaining sentence not proven; canary stage checks and rollback fields exist as descriptions. | Mixed (release process). | PARTIAL | Core/ProductionCanaryRolloutAndPhasedReleaseContract.swift:32; Tests/AppUnitTests/ProductionCanaryRolloutAndPhasedReleaseSectionViewTests.swift | Contract is descriptive; no live canary gating on iOS proven. |
| W11.5 | Remaining sentence not proven; legacy default-scope read path preserved, switches described default-off. | Mixed. | PARTIAL | Core/BackendRolloutAllowlistSwitchboardContract.swift:37 | Descriptor only; no runtime switch consumption proven. |
| W11.6 | Remaining sentence not proven; Redis pre-reservation and log/location batch retention are backend. | Backend only. | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None on iOS. |
| W11.7 | Remaining sentence not proven; client has bounded redacted events with no auto-upload. | Mixed. | PARTIAL | Core/OpsAuditTrail.swift:5 (memory-only, bounded, no PII by design) | Nothing uploads by design; confirm remaining sentence needs a client emit path. |
| W11.8 | Remaining sentence not proven; local gate events exist. | Mixed. | PARTIAL | Core/OpsAuditTrail.swift:9 | Review-write audit is backend; client gate events present. |
| W11.9 | Remaining sentence not proven; six-layer switch client model, status/features decode exist. | iOS responsibility (client model). | PARTIAL | Core/OpsDegradedState.swift:10 (OpsKillSwitchLayer: global/theme/merchant/sku/node/aiTool); Core/OpsServerReadouts.swift | Prove that retained query/refund/fulfilment paths stay open when a layer is off. |
| W13.1 | No aggregated public-layers backend entry; six-source aggregation chain not formed. | Backend gate; iOS contract ready. | GATED-BY-DESIGN | Core/MapLayerSourceContracts.swift:6 (aggregatedQueryEnabled=false); Tests/CoreTests/MapLayerSourceContractsTests.swift:13 | Flip flag + call chain only after backend QueryMapLayers exists; do not enable earlier. |
| W13.2 | Server bbox/layer/cursor/snapshot chain is not closed (endpoint has no real source). | Backend. | BACKEND/MINIPROGRAM-ONLY | Core/MapPublicLayerService.swift:7 (client grant only) | None on iOS until backend ships. |
| W13.3 | Aggregation must call each source's public read; roam bbox pagination/limit, indexes and viewport fixed. | Backend. | BACKEND/MINIPROGRAM-ONLY | NOT FOUND (backend ApiMapController) | None on iOS. |
| W13.4 | Alias/history refs on merge, display point + navigation entrance, route-provider adapter returning polyline/steps/distance/ETA. | Mixed. | PARTIAL | Core/MapLayerSourceContracts.swift:34 (placeID); App/MapKitWalkingRoutePlanner.swift:5; (no WalkingRouteProvider protocol: grep none) | Add route-provider adapter protocol and navigation-entrance field consumption. |
| W13.5 | Exact/fuzzy/distance-only tiers; main play and navigation must work without sharing; remaining consent clauses. | iOS responsibility. | PARTIAL | Core/PersonalLocationShareContracts.swift:4 (EXACT/COARSE only); Core/PersonalLocationSharePolicy.swift; Tests/CoreTests/PersonalLocationShareTests.swift:186 | Add distance-only tier (tests assert distance is NOT decodable); confirm no-sharing main path. |
| W13.6 | Hide-sensitive-places, revoke anytime, stranger layer never shows precise position, UI states already-seen info cannot be recalled. | iOS responsibility (+backend). | PARTIAL | Core/PersonalLocationShareCoordinator.swift:313 (stop); Core/PersonalLocationShareContracts.swift:10 (alreadySeenCannotBeRecalled ack) | Add hide-sensitive-place control and stranger-layer coarse-only rendering. |
| W13.7 | Coarse distance bands, query move/frequency limits, no bypass via nearby sort/trail/check-in/count/error fields. | Mixed (backend limits + iOS no-leak). | MISSING | NOT FOUND (no distance-band output in Core/PersonalLocationShare*) | Implement banded distance presentation and client-side no-leak rules. |
| W13.8 | Offline/background/session end/revoke/leave team/ban each have stop semantics. | iOS responsibility. | PARTIAL | Core/PersonalLocationShareCoordinator.swift:313,338 (stop/stopAll); Core/PersonalLocationShareReceiverProjection.swift (stale) | Prove background/offline/team-exit/ban stop paths with tests; only stop/stopAll seen. |
| W14.1 | Business calendar, special eligibility, reward/product linkage; only UNRESTRICTED/ONCE policy, coupon rejected. | Backend; iOS publishing contract. | BACKEND/MINIPROGRAM-ONLY | Core/MerchantSideQuestContracts.swift:10 (instance model) | iOS merchant publishing UI for calendar/eligibility not built (backend must accept first). |
| W14.2 | Discovery filtering supports UNRESTRICTED only; no new marker layer; player entry beside search map. | iOS responsibility. | MISSING | Core/MerchantSideQuestContracts.swift:37 (isDiscoverable); Core/SideQuestAcceptHold.swift:7 (waitingSource); plan-cited App/SideQuestPlayerEntry.swift NOT FOUND in this checkout | Build nearby-sideQuest list/player entry; no SideQuestPlayerEntry/Flow files exist on this branch. |
| W14.3 | No FAILED outcome in service; no complete risk-disposal policy (substitute/compensation). | Mixed. | PARTIAL | Core/MerchantSideQuestContracts.swift:50 (attempt statuses); Core/SideQuestAcceptHold.swift:25 | Player flow for start/answer/cancel absent (no SideQuestPlayerFlow); wire after player entry. |
| W14.4 | Per-member unique attempt, photo/QR evidence, retention/review flow not proven for new executor (text/single choice only). | Mixed. | PARTIAL | Core/MerchantSideQuestContracts.swift:123 (SideQuestEvidenceState) | Photo evidence UI/review for sideQuest not built; backend rejects photo config. |
| W14.5 | Map the mini-program POI review entry/requests/tables to native; merchant/reviews is separate. | iOS + backend. | PARTIAL | Core/ContextualReviews.swift:7 (ContextualReviewTarget) | Confirm POI review parity vs mini-program; owner must supply mini-program request/table map. |
| W14.6 | Owner-union insert recovery exists; team-sharing privacy not signed off; no new grid upgrade mapping. | iOS responsibility. | PARTIAL | Core/PersonalFogLedger.swift:48 (applyServerPage:67, nextBatch:83); Core/PersonalFogLedger.swift:15 (roam-tile-legacy); Tests/CoreTests/PersonalFogLedgerTests.swift | Grid upgrade mapping and team-share consent rules absent; do not default-share. |
| W15.1 | Target authorizer cannot yield an allowed real target (city/nearby lack authoritative fields; storyNode unsupported). | Backend evidence fields + iOS. | GATED-BY-DESIGN | Core/SourceWalkingTargetAuthorizer.swift:23-70 (throws missingEvidence); Tests/CoreTests/SourceWalkingTargetTests.swift:12 | Needs backend fields (visibility/datum/revision/expiry); then lift missingEvidence. |
| W15.2 | Structured navigation entrance, floor, approach note, hours, temp closure, accessibility alternative, with source/reviewer/updated-at. | Backend data + iOS DTO. | PARTIAL | Core/WalkingNavigationContracts.swift:30 (AuthorizedWalkingTarget has address, businessTime only) | Add entrance/floor/closure/accessibility fields to DTO and UI. |
| W15.3 | WalkingRouteProvider adapter contract; minimal nav state, no default full trail. | iOS responsibility. | PARTIAL | App/MapKitWalkingRoutePlanner.swift:5; App/NativeWalkingNavigationFactory.swift:8; Core/WalkingNavigationCoordinator.swift:64 | Provider protocol not named in code; define it and test planner swap. |
| W15.4 | Normal navigation chain breaks at target authorization with real sources. | iOS + backend. | GATED-BY-DESIGN | Core/WalkingNavigationCoordinator.swift:64; Core/SourceWalkingTargetAuthorizer.swift:23 | Same blocker as W15.1. |
| W15.5 | Weak GPS, low battery, offline/cache, foreground/background, restart restore, lock-screen/voice policy. | iOS responsibility. | PARTIAL | Core/WalkingNavigationCoordinator.swift:129 (setForeground), :172 (weakGPS), Core/WalkingNavigationContracts.swift:123 (checkpoint) | No low-battery, offline-cache or lock-screen/voice handling found; add or record owner decision. |
| W15.6 | Arrival shows only the verification entry; /api/play/arrive limits stay. | iOS responsibility. | PARTIAL | Core/NativeNavigationCompletion.swift (exists, not read in depth); Core/WalkingNavigationCoordinator.swift:4 | Verify arrival never auto-completes; no proof read. |
| W16.1 | Random matchmaking revoked by owner. | n/a | OWNER-DECISION | n/a (plan line 994) | None; do not build. |
| W16.2 | Random matchmaking revoked by owner. | n/a | OWNER-DECISION | n/a (plan line 997) | None; do not build. |
| W16.3 | Random matchmaking revoked by owner. | n/a | OWNER-DECISION | n/a (plan line 1000) | None; do not build. |
| W16.4 | Harassment reporting, block ends contact, contact rate limit, minor review, solo-complete/safe-exit option. | iOS + backend. | PARTIAL | Core/ChannelDiscordMessaging.swift:580 (blocked senders filtered) | Add contact-frequency limit, minor gating, solo/safe-exit UI. |
| W17.1 | Payment provider must first confirm collect/split/refund/campaign/beneficiary support. | Owner/legal + backend. | OWNER-DECISION | Core/SponsoredRewardPool.swift:15 (cash default false) | Keep cash off until provider confirmation. |
| W17.2 | Versioned milestone/achievement/completion/random rules; AI may not pick winners or amounts. | Backend rules; iOS read-only. | GATED-BY-DESIGN | Core/SponsoredRewardPool.swift:15,27 (random gated off) | None until approved. |
| W17.3 | Multi-merchant quota order, sponsor withdrawal, freeze/chargeback, expiry, refunds, team allocation. | Backend. | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None on iOS. |
| W17.4 | Award from authoritative runtime event; budget reservation in same transaction; sponsor reconciliation. | Backend. | BACKEND/MINIPROGRAM-ONLY | Core/RewardPledge.swift:7 (comment: CAS/outbox live on backend) | None on iOS. |
| W18.1 | Schema, NPC and file safety scan before fixing. | Backend; iOS author import. | PARTIAL | Core/QmodManifestContract.swift; App/QmodAuthorImportView.swift:150 | Author-side import exists; scan/review is backend. |
| W18.2 | Public detail must not leak answers/internal knowledge; role-specific field projection; license bypass via save-as/export. | Mixed. | PARTIAL | Core/ModInstallationSavedRehearsal.swift (exists); App/ModInstallationSavedRehearsalView.swift | Projection per role not proven in client. |
| W18.3 | Bind NPC/product/route placeholders to buyer's real store/POI/SKU, then confirm, review, publish. | Mixed. | PARTIAL | Core/ModInstallationService.swift (exists); App/ModInstallationTemplateEditorView.swift | Binding to buyer facts UI not proven end to end. |
| W18.4 | Legal/safety emergency takedown separate from commercial withdrawal, with notice/substitute/refund rules. | Mixed. | PARTIAL | Core/WorkshopOwnedContracts.swift:11 (EMERGENCY_BLOCKED status) | Client shows blocked state; notice/replacement/refund UX absent. |
| W18.5 | Paid-order retry no duplicate license; revoking license must not break an active run. | Backend + iOS retry. | PARTIAL | Core/WorkshopPaidInstallService.swift; Core/WorkshopPaidInstallPendingStore.swift | Pending store recovers; run-continuity messaging not proven. |
| W18.6 | Payment confirmation grants license atomically through W08 event. | Backend. | BACKEND/MINIPROGRAM-ONLY | Core/WorkshopStoreKitLauncher.swift (client launcher only) | None beyond receipt readback. |
| W18.7 | Real chargeback query fact missing (Provider.queryChargeback default null). | Backend. | BACKEND/MINIPROGRAM-ONLY | Core/ModSettlementContracts.swift:91 (chargebackAmount decoded) | None; iOS already decodes the field. |
| W18.8 | Rights proof, infringement report, appeal, takedown, emergency withdrawal; refund/revoke per install state; ranking stats separation. | Mixed. | PARTIAL | App/ModOwnedContentReportView.swift (report); Core/ModOwnedContentReport.swift | Appeal / rights-proof flows not found; ranking is backend. |
| W19.1 | Old mini-program must not show unsupported interactions. | Mini-program. | BACKEND/MINIPROGRAM-ONLY | App/PrivateHomeView.swift:3 (iOS manage entry exists) | None on iOS. |
| W19.2 | Home never exposed to nearby players, teammates, NPCs, analytics, creators, territory; map layer must not leak it. | Mixed. | PARTIAL | Core/PrivateHomeContracts.swift; App/PrivateHomeView.swift:3 | Consumer-projection audit not done; add leak test across map/share layers. |
| W19.3 | None (source-complete server parameters). | Backend. | BACKEND/MINIPROGRAM-ONLY | n/a | None. |
| W19.4 | None for server (owner/proof/CAS); client submits proof. | Mixed. | PARTIAL | Core/NativeHomeReturnCoordinator.swift:23; Tests/CoreTests/NativeHomeReturnServiceTests.swift; App/AppSession.swift:1904 (approval selector default nil) | Production approval defaults nil; wire via hook after backend integration. |
| W19.5 | None for server (RUN/sys.hp only). | Backend. | BACKEND/MINIPROGRAM-ONLY | n/a | None. |
| W19.6 | Location off/denied, low accuracy, weak GPS, stale, cooldown, out of range, network each distinct with retry guidance. | iOS responsibility. | PARTIAL | Core/NativeHomeReturnRestore.swift:10-13 (locationOff, permissionDenied, lowAccuracy, staleFix, cooldown, outOfRadius, network) | Failure cases exist; confirm UI copy and retry per case. |
| W20.1 | Platform config/freeze and policy selection sentences not proven. | Backend. | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None on iOS. |
| W20.2 | Config fields still need review; not a source gap. | Backend + merchant UI. | PARTIAL | Core/CityMerchantOperationsService.swift; App/CityMerchantOperationsView.swift | Merchant-side CITY application UI exists; field review pending. |
| W20.3 | Policy and independence sentences unproven; per-domain models exist. | Backend. | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None on iOS. |
| W20.4 | First acquisition chain proven; remaining sentences not proven. | iOS responsibility. | PARTIAL | Core/CityAcquisitionService.swift; App/CityAcquisitionView.swift; Tests/CoreTests/CityAcquisitionTests.swift | Remaining original sentences need clause mapping. |
| W20.5 | No production service implementation for accept-service flow (platform capability, operator choice, visitor accept, one settlement). | Backend + iOS. | MISSING | Core/CityGameBoardProjection.swift:181 (CityGameServing protocol; only fixture impl) | Need real CityGameServing implementation; blocked on backend. |
| W20.6 | Neutral QA only; no paid access, income budget or settlement. | Backend + iOS. | PARTIAL | Core/CityNeutralTaskService.swift; App/CityNeutralTaskView.swift | Paid-visit/team-benefit UI absent; backend first. |
| W20.7 | Personal contribution rule and business-qualification sentences not proven. | Backend. | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None on iOS. |
| W20.8 | State cache binding / hidden source non-leak not proven. | Backend. | BACKEND/MINIPROGRAM-ONLY | Core/CityValueBoundedMapReading.swift (client reader) | None beyond reader. |
| W20.9 | Physical lat/lng column type and existing data prerequisites unread. | Backend. | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None on iOS. |
| W20.10 | Publisher coverage of task completability, economics, service capability, security fields. | Backend. | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None on iOS. |
| W20.11 | Paid-visit settlement, challenge transfer, compensation, closure reservation release chains not connected. | Backend. | BACKEND/MINIPROGRAM-ONLY | Core/CityAcquisitionService.swift (first acquisition only) | None on iOS until backend. |
| W20.12 | accepted_visit/fee_effect/challenge_id terminal uniqueness has no production chain. | Backend. | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None on iOS. |
| W20.13 | Service fees/rewards/team allocation/reservation release, reconciliation, board projection. | Backend. | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None on iOS. |
| W20.14 | Challenge exists only as client state machine; no production controller/persistence/settlement chain. | Backend + iOS. | MISSING | Core/CityActionContract.swift:155 (CityChallengeState); Core/HomeReturnAndCityDeltaCoordinator.swift:282 | Wire real challenge service once backend ships; state machine is only transport-neutral. |
| W20.15 | Accepted services/challenges lack production implementation; notify/grace/appeal/clock/closure handling. | Backend. | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None on iOS now. |
| W20.16 | No unified board_version/sequence; CityGameServing has no production impl; reducers not on real events. | Backend + iOS. | PARTIAL | Core/CityDeltaStream.swift; Core/CityGameCoordinator.swift; Tests/CoreTests/CityGameCoordinatorTests.swift | Real snapshot/delta service impl missing (fixtures only). |
| W20.17 | Team-share merge, timeline/challenge notification/distance inference leaks not fully checked. | Mixed. | PARTIAL | Core/PersonalLocationShareReceiverProjection.swift; Core/CityGameBoardProjection.swift | Add leak audit across notifications and distance. |
| W20.18 | Uniform permission matrix across all writes not proven. | Backend. | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None on iOS. |
| W20.19 | Diagnostics for non-acquisition flows; permissions/audit partial. | Mixed. | PARTIAL | Core/CityAcquisitionService.swift | Remaining sentences unproven. |
| W20.20 | Public/cooperative funnel and visit net-points/budget lack traceable production facts (UNAVAILABLE). | Backend + iOS display. | PARTIAL | Core/CityFairness.swift:14; App/CityFairnessView.swift:4 | Funnel cards show unavailable; needs backend facts. |
| W20.21 | No production producer of fairness/outing_id/effective outing found. | Backend. | BACKEND/MINIPROGRAM-ONLY | Core/CityFairness.swift:14; App/CityFairnessView.swift:4 (client reader) | None on iOS. |
| L01 | World/season, team full chain, anonymous, close version, late revision, anti-cheat freeze/appeal. | Mixed. | PARTIAL | App/GrowthLeaderboardView.swift:3; Core/GrowthAnonymousLeaderboardContract.swift; Core/GrowthCenterContracts.swift:12-15 (metric point/exp, period week/total only) | Add season/world/team boards, close-version params; blocked on backend. |
| L02 | Visit service, challenge, exit/expiry compensation not closed; P1/P2 sub-flows. | Mixed. | PARTIAL | Core/CityActionContract.swift:155; Core/CityGameBoardProjection.swift:181 | Depends on W20.5/W20.14. |
| L03 | Pre-launch concurrency/abuse test suite for W20. | QA/backend. | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None on iOS code; QA task. |
| A01 | Product sign-off on flagship content, refund/no-show rules; real merchants and stock. | Owner/product. | OWNER-DECISION | n/a | Owner sign-off. |
| A02 | Domain review of manifest, run/actor contracts, NPC binding, API/event schemas. | Backend/architecture. | BACKEND/MINIPROGRAM-ONLY | n/a | None on iOS. |
| A03 | Security/privacy/minor/offline-safety/payment review passed; consent UI available. | Owner/compliance + iOS. | OWNER-DECISION | Core/AppStorePrivacyManifestAndPermissionAudit.swift (audit) | Compliance sign-off; consent UI per feature. |
| A04 | Real MySQL concurrency, callback dup/out-of-order, conservation tests. | Backend. | BACKEND/MINIPROGRAM-ONLY | n/a | None on iOS. |
| A05 | Hotfix, kill-switch, runbooks, on-call, canary rollback drills. | Ops. | BACKEND/MINIPROGRAM-ONLY | Core/OpsDegradedState.swift:10 (client kill-switch model) | Ops drills only. |
| A06 | Second-registration N/D hand-checks; free/paid, refund, exposure strata visible; baseline. | Backend + iOS view. | BACKEND/MINIPROGRAM-ONLY | App/SecondRegistrationStatsView.swift:5 | Hand-verification of metrics; no iOS gap. |
| A07 | Map layers, side quest, review migration, fog recovery, voluntary location share, in-app walking nav verified on device/permission; W20 pilot. | iOS responsibility. | PARTIAL | App/PersonalLocationShareHost.swift:7; App/NativeWalkingNavigationFactory.swift:8; Core/PersonalFogLedger.swift:48 | Side-quest player and aggregated layers missing; no device acceptance evidence in repo. |
| A08 | Keep team/text easter eggs; contact/home P1; cash/random P2 stays closed absent approval. | Owner. | OWNER-DECISION | Core/SponsoredRewardPool.swift:15 (cash/random default off) | Owner approval gate. |
| A09 | Creator upload/pricing, review, buyer license, install draft, real run, income and refund reconciliation connected. | Mixed. | PARTIAL | App/QmodAuthorImportView.swift:150; App/WorkshopPaidInstallView.swift; App/ModSettlementViews.swift:8 | End-to-end chain not shown in repo; terms/settlement need independent review. |

## Top 15 missing iOS items by launch impact

| # | Item | Why |
|---|---|---|
| 1 | W20.5 / W20.14 / W20.16 | No production `CityGameServing`; challenge is only a state machine. City operation (paid visits, challenges, live board) cannot run. Blocked on backend. |
| 2 | W14.2 / W14.3 | Side-quest player entry, list beside search map, accept/answer/cancel flow absent on this branch (only contracts + accept-hold). |
| 3 | W15.1 / W15.4 | Walking navigation cannot start for real sources: authorizer always throws `missingEvidence`. Needs backend fields, then lift. |
| 4 | W13.1 | Aggregated map layers disabled (`aggregatedQueryEnabled=false`); needs backend QueryMapLayers. Do not enable early. |
| 5 | W13.7 | No coarse distance-band output or no-leak rules for location sharing; tests assert distance is not decodable. |
| 6 | W13.6 | No hide-sensitive-places control; no stranger-layer coarse-only rendering. |
| 7 | W16.4 | No contact-frequency limit, minor gating or solo/safe-exit option (only blocked-sender filtering). |
| 8 | W13.8 | Only stop/stopAll seen; background/offline/team-exit/ban stop paths need proof and tests. |
| 9 | W15.5 | No low-battery, offline-cache, lock-screen or voice handling for walking navigation (restart restore only via checkpoint type). |
| 10 | W15.2 | Navigation DTO lacks entrance/floor/closure/accessibility alternative fields. |
| 11 | W19.4 / W19.6 | Home-return client exists but production approval defaults nil; wire after backend integration and confirm per-case UI copy. |
| 12 | L01 | Leaderboard only point/exp x week/total; no world/season/team boards, close-version or appeal. |
| 13 | W18.8 / W18.4 | No rights-proof, appeal or notice/refund UX for takedown; only report + emergency-blocked status. |
| 14 | W14.5 | POI review migration unconfirmed; need mini-program request/table map from owner. |
| 15 | W10.2 | Revenue report has no goods-repurchase / net-revenue cells; add once backend supports. |
