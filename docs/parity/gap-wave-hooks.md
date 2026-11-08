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

## Batch 2 (`cl-w5a`, `cl-w5b`, `cl-w6c`, `cl-w7a`)

### `cl-w5a`
- `pages/merchant/decor/perks/index`: in `MerchantOperationsHomeView` destination list, add a link to `MerchantPerkTemplatesFactory.makeView(coordinator: MerchantPerkTemplatesFactory.makeCoordinator(reader: session.cooperationFlowReader, executor: <CoopFlowDormantExecutor(service:) or nil>))`, plus reviewed grants for `api/coop/perk-template/save` and `/delete`.
- `pages/merchant/decor/ai-npc/index`: pass a reviewed grant + writer into `StoreCharacterCoordinator(reader:writer:gates:)` when `api/merchant/npc/save` is approved.
- `pages/merchant/team/index`: supply a reviewed `MerchantBusinessProductionApproval` for `api/merchant/operators/invite|role|remove|invite/revoke|invite/accept`.
- `subpackageRoam/my-teams/index`: pass `readApproval`/`writeApproval` to `makeNearbyTeamCoordinator()` once `api/team/my-applications` and `/api/team/my` are approved.
- `subpackageTools/capsule/index`: set `roamPrivateToolsReadAccess` / `roamPrivateToolsWriteAccess` and `makeRoamLiveWriteTransport(profile: .privateTools)` approval for `api/capsules/*`.

### `cl-w5b`
- `pages/merchant/citynode/create/index`: pass `gates:` and `market:` from composition root into `MerchantCityNodeWriteGate`/view, and add reviewed `api/merchant/city-node/save` in `reviewedEndpoints`.
- `pages/merchant/decor/coop-setting/index` (`App/AppSession.swift:5837`): pass `OperationEndpointApproval` for `api/merchant/coop-profile/save` and `OperationPendingJournal` into `MerchantOperationsSessionReader`.
- `pages/merchant/marketing/ai-insight/index` (`App/AppSession.swift:7103`): pass reviewed `reads: true, insight: true` with approval.
- `pages/topic/merchantapply/index`: add `register`/`updateRegistration` grants to `MerchantContentWriteApproval` and supply approval from composition root.
- `subpackageRoam/citynode-code/index`: provide `verificationCodeApproval` (kind `.cityVoucher`, paths `api/verify/citynode/issue` + `api/registration/info`).
- `subpackageRoam/nearby/index`: pass read grants (`api/team/nearby`, `api/team/applications`), write grants (`api/team/apply`, `api/team/withdraw`, `api/team/handle`), and fresh-evidence loader to `makeNearbyTeamCoordinator()`.

### `cl-w6c`
- `pages/club/detail/index` (`App/ClubDetailView.swift`): construct `ClubDetailEntryGate(club: club, signedIn: reader.clubIdentity.isSignedIn, grant: manageGrant)` and gate role/member/appeal/cooperation entries.
- `pages/club/governance/index`: call `ClubGovernanceEntryRoute.resolve(options)` in the club governance router.
- `pages/club/topic-detail/index`: add `cancellationEpoch` to `.endTopic` in `Core/ClubGovernanceCommands.swift` and route replies through `ClubTopicEndSummary.parse(_:sentEpoch:)`.
- `subpackageB/pages/im/chat/index`: inject `MessageSessionWriter` approved for sends when reviewed.

### `cl-w7a`
- `pages/gerenziliao/gerenziliao`: pass `ProfileAvatarDependencies(source:journal:pickerHost:)` into `ProfileEditView(avatarDependencies:)` once avatar upload is reviewed.
- `pages/topic/pricing/index`: compose `PublisherLifecycleHTTP` grants so `grants.pricing` is non-nil for reviewed deployments (`App/PublisherLifecycleHostHooks.swift`).
- `subpackageMember/invoice-apply/index` & `subpackageMember/invoice-titles/index`: provide `InvoiceLaunchService(mutationsEnabled: true)` and `InvoiceLaunchPresentation(permits:)` returning `true` for `.apply`/`.saveTitle`/`.deleteTitle`/`.cancel` under reviewed deployment.

## Batch 3 (`cl-w7b`, `cl-w7c`, `cl-w8a`, `cl-w8b`)

### `cl-w7b`
- `subpackageMember/complaint/index`: set `ProfileComplaintPreparationLink.submitterFactory = { session in ProfileComplaintCoordinatorSubmitter(coordinator: <session's CoopFlowCoordinator>, enabled: { <reviewed complaint-report grant> }) }` once the grant exists (`AppSession`/`AppCompositionRoot`).
- `pages/merchant/aftercare/detail/index` & `pages/merchant/customer/index`: wire `MerchantAftercareResponseDraft` / `MerchantCustomerBatchTag` into `App/MerchantBusinessEditor.swift` and supply reviewed `MerchantBusinessMutation` production transport when approved.

### `cl-w7c`
- `pages/merchant/aftercare/index`: respond write grant (`MerchantBusinessMutation` production transport, shared with aftercare detail).

### `cl-w8a`
- `pages/play/merchant/index`: inject an enabled `PlayStoreDayService` from composition root once the store-day check-in/answer grant exists.
- `pages/publish/temp/index` & `subpackageMember/mytemplate/mytemplate` (`App/AppSession.swift:4669`): inject live `TemplateAuthoringRequestHTTPService` once reviewed.

### `cl-w8b`
- Composition hooks (once reviewed routes/grants exist): set `StoryParticipationWriterFactory.makeWriter`, `ChallengePOIWriterFactory.makeWriter` (plus location provider for `ChallengePOIHostView`), `TopicTemplateUseFactory.makeUser`, `MyProjectMutationFactory.makeMutator`, `FreeExploreCancelFactory.makeCanceler`, and `OrientScoreReviewFactory.makeSubmitter`.
- Host view embedding: embed `TopicTemplateUseSection` in topic-template detail, `MyProjectMutationStatusView` + `begin(...)` in `MyProjectRowOperationsMenu`/list, cancel button + dialog in `FreeExploreBundleLaunchView`, and `OrientScoreReviewSection` + navigation entry in `OrientScoreReadyContent`.
