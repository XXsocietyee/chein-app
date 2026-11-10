# pages/coop/settlement-detail/index — CB263

Page-ready on rc/20261108. Native screen `App/CoopSettlementDetailView.swift`. Map status stays exists. No model change. No route was added or marked live. Payment, payout, and withdrawal stay off.

Wired contracts already in Core: `POST api/coop/finance` is `CoopFlowReading.read(.finance)` and `CoopSettlementDetailModel.resolve(source: .finance)`. `POST api/coop/mybiz` is `.myBusiness` and `source: .mybiz`. `source=club` stays on the existing club detail (`ClubSettlementDetail`, `POST api/club/settlement/summary`, `club:finance:read`). It was not rewired onto the coop reader.

States already present: loading is `CoopSettlementReadJourney.isLoading` (`cooperation.settlement.loading`, and `cooperation.settlement.refreshing` while a detail is on screen). Empty is a missing id (no read) and `CoopFlowFailure.unavailable` → `Issue.missingRecord`. Error is `Issue.failed` and `Issue.permission`. A transient failure keeps the last detail; malformed, ambiguous, permission, and missing-record responses clear it. UNKNOWN money is a nil amount and `Value.unavailable`, which the screen draws as `—`. A server literal 0 stays 0 (`Status.noIncomeDue`, `¥0.00`). Invalid status codes are rejected as malformed and are not stored as 0.

Missing EN+zh-Hans keys: none. Every `cooperation.settlement.*` catalog entry used by this page, plus `cooperation.login`, `cooperation.loading`, `cooperation.refresh`, `cooperation.unnamedTopic`, `cooperation.finance.topicFallback %lld`, and `coopflow.amount.unknown`, already has translated `en` and `zh-Hans`. Club keys used by the separate club detail (`club.settlementDetail.*`) also have both.

Catalogs, views, the Xcode project, and `tools/current_ci_manifest.json` were not edited. Existing tests were not changed or weakened: `CoopSettlementDetailModelTests`, `CoopSettlementReadJourneyTests`.

Left: the hero and income em dash live in `App/CoopSettlementDetailView.swift`. On the club detail, a null `amountText` still uses `club.settlementDetail.amountUnknown` (金额待核验), not `—`. Swift was not compiled. `xcodebuild` was not run. No Xcode Cloud result is claimed.
