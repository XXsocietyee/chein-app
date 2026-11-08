# gap-pl-4: plan §10 ledger lines 550-865 vs iOS code

Scope: plan lines 550-865 (G, W01, C, S, W02-W10.2 up to W10.2). Read-only analysis; branch `cloud/pl-4` at origin/wip/owner-plan 152ee0f3. Plan text treated as data.
Caveats: (1) the plan cites line numbers at SHA 5e6d218a; the repo now differs, so proof lines are re-grepped at the current commit. (2) Plan classes almost all rows 无法核实 (unverified) - 'MISSING' here means *no clause-level evidence located*, not proven absent. (3) Most clauses are backend (Java) and out of scope for the iOS repo. (4) iOS sections in `App/*SectionView.swift` are mostly reachable only from fixture hosts (`App/QuestifyApp.swift:24,64`) - flagged `no production host`.

Total rows: 87. Counts: BACKEND/MINIPROGRAM-ONLY: 37; GATED-BY-DESIGN: 1; IMPLEMENTED with proof: 1; MISSING: 17; OWNER-DECISION: 3; PARTIAL: 28

| ID | Remaining (unproven) clauses | Owner | iOS status | Proof | Missing iOS work |
|---|---|---|---|---|---|
| G01 | Per-path theme/release isolation of NPC/memory/tools and private-assistant vs public-NPC authority chain unproven. | backend | BACKEND/MINIPROGRAM-ONLY | iOS only sends chat; scope derived server-side. Client send gate App/ShopNPCView.swift:14 | None for iOS beyond W09.4/W09.5 wiring. |
| G02 | Merchant authority conditions and physical product/theme/game linkage unproven (owner occupancy not a code gap). | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None; iOS draft contract Core/MerchantAIAuthoring.swift is pure (see W05.x). |
| G03 | Module retention boundary / non-bundled upgrade delivery evidence. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None. |
| W01.1 | Full call-chain ledger and per-column delivery record. | non-code | OWNER-DECISION | NOT FOUND | Owner/ops deliverable, no iOS code. |
| W01.2 | Read-only investigation of real environments + report/approval. | non-code | OWNER-DECISION | NOT FOUND | Owner decision/access; not iOS. |
| W01.3 | Full source-of-truth mapping and delivery checklist. | non-code | OWNER-DECISION | docs/parity/page-map.csv (164 rows: 112 exists, 36 partial, rest merged/dropped) is a partial map only | Owner sign-off of mapping; keep page-map current. |
| C01 | No clause-level evidence at all; original text not in this slice. | iOS+backend | MISSING | NOT FOUND | Needs original C01 text (底稿A/M7) to audit; unproven, not proven absent. |
| C02 | Android/Flutter login-order-pay-run parity and per-end difference register; per-interaction capability downgrade proof; map nav owned by Gemini. | iOS (Android out of scope) | PARTIAL | App/SessionPublishingModesView.swift:29 (ProjectEditView + publisherLifecycleContext, AppSession.swift:4179) | Capability negotiation per interaction not proven; end-difference register missing. |
| C03 | Whole-app hardcoded-string/fallback/plural/price/date audit; content-translation licensing. | iOS | PARTIAL | App/AppLocalizedString.swift:6; Resources/*.xcstrings (e.g. Resources/AccountCompliance.xcstrings). Cited Resources/MerchantOrderGoods.xcstrings: NOT FOUND at that path | Run full localization sweep; confirm order-goods strings exist (cited file absent). |
| C04 | Global visual-token uniformity; small-screen/large-text/dark/keyboard/safe-area/weak-network behaviour per screen. | iOS | PARTIAL | App/GrowthLeaderboardView.swift:130 (accessibilityElement combine), reached via App/GrowthCenterView.swift:116 | Per-screen Dynamic Type/dark/offline verification evidence. |
| C05 | Dedicated security review; all permission copy/denial fallbacks; device-risk signals; deep-link safety actually wired. | iOS | PARTIAL | App/KeychainTokenStore.swift:33 (ThisDeviceOnly); App/AppSession.swift:7459 (restoreBlocked + vault.clear); App/RuntimeNativeLocationProvider.swift:15-21,40 (when-in-use on explicit action). DeepLinkSafetyAudit type: NOT FOUND; App/DeepLinkSafetyDiagnosticsSectionView.swift has no production host | Wire deep-link safety audit into real entry; device-risk signals; permission-copy audit. |
| C06 | Backend->all map render/provider chain baseline; stronghold-verification purpose separation. | iOS | PARTIAL | App/RuntimeNativeLocationProvider.swift:42 (datum .wgs84); Core/RuntimeLocationProjection.swift:15-31 (gcj02); App/RuntimePlayDeviceProvider.swift:29 | Map-render datum chain end to end and verification-purpose split. |
| S01 | No clause-level evidence; whole original clause unproven. | unknown (original text outside slice) | MISSING | NOT FOUND | Needs original text to audit; unproven, not proven absent. |
| S03 | No clause-level evidence; whole original clause unproven. | unknown (original text outside slice) | MISSING | NOT FOUND | Needs original text to audit; unproven, not proven absent. |
| S04 | No clause-level evidence; whole original clause unproven. | unknown (original text outside slice) | MISSING | NOT FOUND | Needs original text to audit; unproven, not proven absent. |
| S05 | No clause-level evidence; whole original clause unproven. | unknown (original text outside slice) | MISSING | NOT FOUND | Needs original text to audit; unproven, not proven absent. |
| S08 | No clause-level evidence; whole original clause unproven. | unknown (original text outside slice) | MISSING | NOT FOUND | Needs original text to audit; unproven, not proven absent. |
| S09 | No clause-level evidence; whole original clause unproven. | unknown (original text outside slice) | MISSING | NOT FOUND | Needs original text to audit; unproven, not proven absent. |
| S10 | No clause-level evidence; whole original clause unproven. | unknown (original text outside slice) | MISSING | NOT FOUND | Needs original text to audit; unproven, not proven absent. |
| S12 | No clause-level evidence; whole original clause unproven. | unknown (original text outside slice) | MISSING | NOT FOUND | Needs original text to audit; unproven, not proven absent. |
| S13 | No clause-level evidence; whole original clause unproven. | unknown (original text outside slice) | MISSING | NOT FOUND | Needs original text to audit; unproven, not proven absent. |
| S14 | No clause-level evidence; whole original clause unproven. | unknown (original text outside slice) | MISSING | NOT FOUND | Needs original text to audit; unproven, not proven absent. |
| S15 | No clause-level evidence; whole original clause unproven. | unknown (original text outside slice) | MISSING | NOT FOUND | Needs original text to audit; unproven, not proven absent. |
| S16 | No clause-level evidence; whole original clause unproven. | unknown (original text outside slice) | MISSING | NOT FOUND | Needs original text to audit; unproven, not proven absent. |
| S17 | No clause-level evidence; whole original clause unproven. | unknown (original text outside slice) | MISSING | NOT FOUND | Needs original text to audit; unproven, not proven absent. |
| S18 | No clause-level evidence; whole original clause unproven. | unknown (original text outside slice) | MISSING | NOT FOUND | Needs original text to audit; unproven, not proven absent. |
| S21 | No clause-level evidence; whole original clause unproven. | unknown (original text outside slice) | MISSING | NOT FOUND | Needs original text to audit; unproven, not proven absent. |
| S23 | No clause-level evidence; whole original clause unproven. | unknown (original text outside slice) | MISSING | NOT FOUND | Needs original text to audit; unproven, not proven absent. |
| S02 | Legacy text-easter-egg/pro-publish regression and no-new-entry check. | iOS (+backend publish chain) | PARTIAL | App/SessionPublishingModesView.swift:29,40 | Regression evidence vs mini-program publish; no-new-entry audit. |
| S06 | Same as S02 (identical evidence). | iOS (+backend) | PARTIAL | App/SessionPublishingModesView.swift:29,40 | As S02. |
| S07 | qmod missing-dep/cycle/all-runtime-version/address-carry/unauthorised-remix cross-format checks. | backend (qmod compiler) + iOS install UI | PARTIAL | App/ModInstallationView.swift:27 (production host); Core/ModInstallationContracts.swift:243 | iOS side only displays; remaining checks are backend. |
| S11 | Access-fee / ownership-change double-charge chain; concurrent shop/signup cross-account verification. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None. |
| S19 | Full dependency closure/cycle detection, asset licence/attribution, abstract venue slots, merchant consent withdrawal across formats. | backend + iOS install UI | PARTIAL | App/ModInstallationView.swift:27; Core/ModInstallationContracts.swift:310 | iOS-visible licence/attribution/consent-withdrawal presentation unproven. |
| S20 | All auto/manual review policies; simulated map/bot/GPS/is_test chain; copyright appeal/export bypass; infringement proof->report->appeal->emergency takedown notices. | backend (+iOS notices) | PARTIAL | App/ModInstallationView.swift:27; Core/ModCompositionInstallationReceipt.swift | iOS takedown/appeal notification surfaces not found. |
| S22 | Chargeback fact->reversal chain (queryChargeback default null); full refund/chargeback/takedown/cancel policy; market metrics; App-channel review. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | App-channel (Apple IAP/review) treatment of MOD sales is an owner/launch decision. |
| S24 | Unified-sequence production source for snapshot/delta; round/protection/deactivation/close persistent worker restart; failed business-task retention. | iOS reducer + backend producer | PARTIAL | Core/CityDeltaStream.swift:33-78 (ingest/reset); Core/CityGameCoordinator.swift:134; App/HomeReturnAndCityDeltaSectionView.swift no production host (only fixtures/tests) | Wire delta stream to a real sequence feed and a production host. |
| W02.1 | Whether publish snapshot satisfies original manifest semantics; pre-publish clauses. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None. |
| W02.2 | Full no-in-place-change + old/new read rules; delete-guard vs reachable runs. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None. |
| W02.3 | Safety override/review substitution/compensation; version/request/audit on all publish/retire paths. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None. |
| W03.1 | Outbox + conflict-current-version return chain for theme actions. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | iOS must handle conflict response; not located. |
| W03.2 | Receipt/replay for all write actions and client recovery. | backend + iOS recovery | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | Client recovery of action state unproven. |
| W03.3 | Action DTO has no kind/schemaVersion; unknown-field rejection and full input caps. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | Confirm iOS sends operation DTO matching contract. |
| W03.4 | Adapter boundary across W20; no model-driven progression. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None. |
| W04.0 | Scene fields/consent versions; ACL/projection and cache/session isolation. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None. |
| W04.1 | run->release/binding derivation; per-retrieval and exit revocation. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None. |
| W04.2 | Pre-retrieval hard filtering; storage/cache scope. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None. |
| W04.3 | Generic-theme forbidden context; per-scene fixed boundary answers. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None. |
| W04.4 | Legacy enabled-profile persona/knowledge write source and authority. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None. |
| W04.5 | Three-layer memory sources; cross-run consent; cross-theme isolation; scene permission retention. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None. |
| W04.6 | Runtime/order event facts vs model preference; consent revoke/expiry and all copies cleared. | backend + iOS data view | PARTIAL | App/NPCChatDataView.swift; App/NPCChatDataReadSettingsEntry.swift | Revoke/expiry UX and copy deletion not proven. |
| W04.7 | Full original whitelist enforcement; all service boundaries. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None. |
| W04.8 | Theme-level and global non-generative degradation chain. | backend + iOS fallback | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | iOS shows fixed fallback copy? not verified. |
| W05.5 | Remaining clauses beyond server branch selection not proven; no concrete source break identified. | iOS (Core+view) + backend | PARTIAL | Core/EnvironmentBranchSelection.swift:26,51-52,70; Core/EnvironmentBranchHostPresentation.swift:26-47; App/EnvironmentBranchAndRewardLedgerSectionView.swift (no production host (only fixtures/tests)) | Production host embedding of environment-branch section; live reader wiring. |
| W05.6 | Remaining clauses beyond server branch selection not proven; no concrete source break identified. | iOS (Core+view) + backend | PARTIAL | Core/EnvironmentBranchSelection.swift:26,51-52,70; Core/EnvironmentBranchHostPresentation.swift:26-47; App/EnvironmentBranchAndRewardLedgerSectionView.swift (no production host (only fixtures/tests)) | Production host embedding of environment-branch section; live reader wiring. |
| W05.7 | Remaining clauses beyond server branch selection not proven; no concrete source break identified. | iOS (Core+view) + backend | PARTIAL | Core/EnvironmentBranchSelection.swift:26,51-52,70; Core/EnvironmentBranchHostPresentation.swift:26-47; App/EnvironmentBranchAndRewardLedgerSectionView.swift (no production host (only fixtures/tests)) | Production host embedding of environment-branch section; live reader wiring. |
| W05.1 | Remaining clauses beyond stage/CAS contract; AI log fields. | iOS+backend | PARTIAL | Core/MerchantAIAuthoring.swift:63-127 | Production host for authoring UI; only pure contract + fixtures proven. |
| W05.2 | Remaining clauses beyond duration/headcount/etc. validation. | iOS+backend | PARTIAL | Core/MerchantAIAuthoring.swift:136-157; Core/MerchantInStoreGameAuthoringPresentation.swift:50; App/MerchantInStoreGameDraftSectionView.swift (no production host (only fixtures/tests)) | Embed draft section in merchant flow; connect to backend save route (absent per hook-wiring.md). |
| W05.3 | Remaining SKU/price/discount clauses. | iOS+backend | PARTIAL | Core/MerchantAIAuthoring.swift:179-226 | Production wiring. |
| W05.4 | Remaining dual-domain approval clauses. | iOS+backend | PARTIAL | Core/MerchantAIAuthoring.swift:101-123; Core/MerchantAICommerceGates.swift:7-20 | Production wiring; capability grant is off by design. |
| W06.1 | Remaining stock/entitlement clauses. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None. |
| W06.2 | Remaining signup-tx/close-order clauses. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None. |
| W06.3 | Legacy WX self-play order path not bound to confirmed price; shipping/slot/address pre-pay validation scope. | iOS+backend | PARTIAL | Core/TopicSelfPlayFlow.swift:51-69 (price recheck via fresh topic, priceChanged); App/TopicSelfPlaySheet.swift | Pre-pay shipping/slot/address validation not found in iOS. |
| W06.4 | Remaining arrival/redemption separation clauses. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None. |
| W06.5 | Source proven whole; build/run/integration/release acceptance separate. Webhook/parse/route work is server-side. | backend; iOS = server readback only | IMPLEMENTED with proof | Core/PaymentProviderReturnFlow.swift:3-40 (no SDK success bool; readback only); Core/OrderPaymentVerifier.swift:27; App/PaymentProviderReturnSheet.swift | Real-device payment run (gated; real payment not enabled). |
| W06.6 | Remaining redemption/ticket clauses. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | iOS merchant order-lines reader unverified. |
| W06.7 | Remaining refund clauses. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | iOS refund UI: App/ClubOwnerRefundPanel.swift exists (not audited). |
| W06.8 | Remaining refund/ledger clauses. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None. |
| W08.1 | Payment callback inbox terminal state not completed on signup path; refund-tx capture only. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None. |
| W08.2 | Remaining outbox clauses. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None. |
| W08.3 | Consumer inbox not written by signup payment consume path; unknown-first-query elsewhere. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None. |
| W07.1 | Remaining fee/accrual clauses. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None. |
| W07.2 | Remaining reconciliation clauses. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None. |
| W07.3 | Remaining operator/permission clauses. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | Merchant operators routes absent (hook-wiring.md:44) so iOS team UI cannot write. |
| W07.4 | Dynamic redeem code exposes registration id/type in signed payload (not opaque). | backend (VerifyDynCodeUtil) | BACKEND/MINIPROGRAM-ONLY | iOS issue path Core/NativeVerificationWorkflow.swift / App/VerificationCodeView.swift (render only) | Backend change; iOS citynode-code issue leased (hook-wiring.md:35), ticket dyncode/redeem/receipt still off. |
| W07.5 | Remaining points/exp ledger clauses. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None. |
| W07.6 | Remaining leaderboard clauses. | backend + iOS list | PARTIAL | App/GrowthLeaderboardView.swift:14-85 via App/GrowthCenterView.swift:116 | Leaderboard shows hold view when not configured (GrowthLeaderboardView.swift:30); enable by gate. |
| W09.1 | Remaining scope clauses. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None. |
| W09.2 | Remaining risk-review clauses. | backend | BACKEND/MINIPROGRAM-ONLY | NOT FOUND | None. |
| W09.3 | Remaining no-auto-funds/unknown-safety clauses. | iOS+backend | PARTIAL | Core/SafetyDisclosure.swift:92-146 (OfflineNodeSafetyState); only referenced by App/OpsSafetyViews.swift, itself fixture-only (App/QuestifyApp.swift:24) | Wire safety disclosure into real node/navigation screens. |
| W09.4 | Remaining AI moderation clauses; AI identity text. | iOS+backend | PARTIAL | Core/SafetyDisclosure.swift:46-73; App/ShopNPCView.swift:14 (AIOutgoingSendGate in prod) | AI identity disclosure not wired in prod (OpsSafetyViews fixture-only). |
| W09.5 | Remaining review/AI-identity-scope clauses. | iOS+backend | PARTIAL | Core/SafetyDisclosure.swift:10-35 (AIIdentityDisclosure) - no production use found | Wire AIIdentityDisclosure into NPC/assistant screens. |
| W09.6 | Remaining retention/consent clauses. | iOS+backend | PARTIAL | Core/UsageConsentPolicy.swift:7-90; App/QuestifyApp.swift:372 (usageConsentLaunchGate); App/UsageConsentGateView.swift:119 | Sensitive-text prompt in prod via ShopNPCView gate; retention is backend. |
| W09.7 | Remaining minor-age features (deferred this period). | iOS | GATED-BY-DESIGN | Core/AppStoreSubmissionReadinessAudit.swift:1-356 (tests only: Tests/CoreTests/AppStoreSubmissionReadinessAuditTests.swift) | None this period; new minor features deferred by owner. |
| W09.8 | Remaining offline-risk/navigation clauses. | iOS | PARTIAL | Core/SafetyDisclosure.swift:92-152; App/NativeWalkingNavigationFactory.swift; App/AppSession.swift:1971 | Risk disclosure UI is fixture-only; walking nav factory wired. |
| W09.9 | Remaining payment-isolation/submission-readiness clauses. | iOS | PARTIAL | Core/WalletCommerceSafety.swift (used by App/WalletCommerceViews.swift); Core/AppStoreSubmissionReadinessAudit.swift tests only | Readiness audit not enforced at runtime; legal/platform approval owner-gated. |
| W10.1 | Remaining second-registration metric clauses. | backend + iOS stats | PARTIAL | Core/SecondRegistrationMetrics.swift:62; App/SecondRegistrationStatsView.swift (only App/QuestifyApp.swift:64 fixture host) | Production reader + entry for stats view. |
| W10.2 | GOODS_REPURCHASE and NET_REVENUE marked unsupported by backend calculator. | backend | BACKEND/MINIPROGRAM-ONLY | iOS decode Core/SecondRegistrationMetrics.swift (view fixture-only) | Backend must supply metrics; iOS stats host as W10.1. |

## Top 15 missing iOS items by launch impact

1. Money-path wiring: only server-readback payment return flow is proven; ticket `dyncode`/redeem/receipt/groupcode routes stay off (hook-wiring.md:35) - core verify/redeem loop not live (W06.5/W07.4).
2. Merchant operators routes absent in backend (hook-wiring.md:44), blocking merchant team UI (W07.3).
3. Fixture-only hosts: Environment-branch section (W05.5-7), merchant in-store game draft (W05.2), second-registration stats (W10.1/2), ops-safety (W09.x) have no production entry.
4. AI identity disclosure never wired in production (W09.4/W09.5) - compliance risk for NPC/assistant.
5. Offline-node safety disclosure not shown in real flows (W09.3/W09.8).
6. Deep-link safety audit not wired to real entries; no DeepLinkSafetyAudit type (C05).
7. City snapshot/delta stream has no production sequence feed or host (S24).
8. Self-play pre-pay shipping/slot/address validation not in iOS (W06.3).
9. Full-app localization sweep; cited MerchantOrderGoods.xcstrings missing (C03).
10. Per-screen Dynamic Type/dark/small-screen/weak-network evidence (C04).
11. Device-risk signals and permission-copy/denial audit (C05).
12. Map render datum chain WGS84/GCJ02 end to end (C06).
13. MOD takedown/appeal/licence-attribution notices on iOS (S19/S20).
14. NPC chat-data revoke/expiry UX (W04.6).
15. Leaderboard stays on hold view until gate configured (W07.6); AppStoreSubmissionReadinessAudit is test-only, not enforced (W09.9).

Unaudited (M): 17 IDs (C01, S01,S03,S04,S05,S08,S09,S10,S12-S18,S21,S23) have no evidence in this slice; their original text (底稿A/M7) is needed.
