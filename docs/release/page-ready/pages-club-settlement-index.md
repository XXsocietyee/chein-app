# pages/club/settlement/index — CB252
Page-ready on rc: the settlement contract, states, and money rules are already in Core. No model change. Map status stays exists. No route was added or marked live.
Wired contract: POST api/club/settlement/summary (ClubGovernanceRead.settlement, club:finance:read). The direct-ledger read and /withdraw stay hidden. Payment, payout, and withdrawal stay off. showsMerchantChoice was not set.
States already present: loading is club.gov.loading; empty is clubOps.settlement.empty when topics are empty; error is clubOps.settlement.failed with clubOps.settlement.retry; UNKNOWN is a nil settled amount and ClubOwnerFundsAvailability.unknown.
Unknown money is not stored as 0. A verified server string, including a literal zero, is kept. An unverified total stays nil. Owner funds with amountsKnown false stay .unknown.
Missing EN+zh-Hans keys (raw zh-Hans only, in Core/ClubOpsSettlementPresentation.swift, not in a catalog): clubOps.settlement.directLedger.title = 商家计酬; clubOps.settlement.directLedger.empty = 暂无商家计酬记录; clubOps.settlement.directLedger.status.credited = 已入账; clubOps.settlement.directLedger.status.pending = 待结算; clubOps.settlement.directLedger.status.unverified = 待核验; clubOps.settlement.directLedger.status.void = 已作废.
Catalog keys already used by this page have both en and zh-Hans, including clubOps.settlement.* and club.settlementDetail.*. Catalogs, views, the xcodeproj, and tools/current_ci_manifest.json were not edited.
Tests left as they are: ClubOpsSettlementPresentationTests, RePoint03ClubSettlementTests, ClubSettlementDetailPresentationTests. ClubOpsSettlementWiring still expects view source this lane cannot edit.
Left: the summary card shows clubOps.settlement.amountUnverified (金额待核验), not an em dash; the non-owner row is a lock label, not a disabled payout button; the direct ledger is not mounted.
Swift was not compiled. xcodebuild was not run. No Xcode Cloud result is claimed.
