# Gap-Closing Wave — Required Composition & G1 Hooks

Recorded by GM-INT-G during gap-wave integration. `App/AppSession.swift`, `App/AppCompositionRoot.swift`, and `App/RegionalLaunchConfiguration.swift` were not edited.

## Batch 1 (`cl-w5c`, `cl-w5d`, `cl-w6a`, `cl-w6b`)

### `cl-w5c`
- `pages/merchant/decor/gallery/index` (`App/AppSession.swift` ~5837): build `MerchantOperationsSessionReader(... approval: OperationEndpointApproval(paths: ["api/merchant/decor/save"]), journal: <OperationPendingJournal>)` once reviewed.
- `pages/merchant/marketing/index` (`App/AppSession.swift` ~7103): pass `MerchantMarketingService.Gates(reads: true)` behind a reviewed per-market approval.
- `pages/topic/merchantinfo/merchantinfo` (`App/AppSession.swift`): `merchantContentWriteApproval(context)` -> return `.init(chapterApply: true, chapterWithdraw: true)` once reviewed.
- `subpackageRoam/session/index`: where the session page is built with a share token, wire `RoamSharedFootprintView(token:, reader: RoamShareSnapshotReaderFactory.make(baseURL:, transport:, approval: { <reviewed per-market flag> }))`.

### `cl-w5d`
- `pages/merchant/crm-campaigns/index` (`App/NativeRuntimeDependencies.swift:27/57`): set `NativeRuntimeDependencies.merchantEngagementApproval` to a reviewed `MerchantEngagementProductionApproval` once the grant exists.
- `pages/merchant/decor/index` (`App/AppSession.swift:5837`): pass `OperationEndpointApproval` for `api/merchant/decor/save` and an `OperationPendingJournal` into `MerchantOperationsSessionReader`.
- `pages/merchant/reviews/index` (`App/AppSession.swift:7260`): build `MerchantBusinessProductionTransport` + `MerchantBusinessActionGrant` for review reply actions (`Core/MerchantBusinessProduction.swift:57`).
- `subpackageRoam/history/index` & `subpackageTools/anniversary/index` (`App/AppSession.swift:6126`): supply a passport-history/tools read grant when building `RoamPassportHistoryReader`.

### `cl-w6a`
- `pages/merchant/relation/index` (composition root): `.environment(\.cooperationRelationPostFeed, CoopRelationPostFeedFactory.make(community: <ClubCommunityContext>, identity: { session.clubIdentity }))` on the cooperation tab.
- `subpackageB/pages/im/list/index` (composition root): `.environment(\.imCoopInviteStrip, IMCoopInviteStripFactory.make(reader: <CooperationReading>))` on `MessagingHomeView`.
- `pages/club/edit/index`: ensure `ClubManagementContext.governance` is non-nil for the `.club(id)` host so the owner dissolve entry and governance routes appear.

### `cl-w6b`
- `pages/square/detail/index`: if/when a backend square block route and grant exist, inject a block coordinator through an environment key.
