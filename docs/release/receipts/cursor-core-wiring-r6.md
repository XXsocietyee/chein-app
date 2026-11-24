# cursor/core-wiring-r6 — Core client wiring

Base: `origin/ui/combined-r6` `f1115875e53a3fbc03969720d44e91f01eeb5ada`.
Scope: `docs/release/backend-needed-r6.md` §2, plus the three r5 §2 findings named in the work order (MKT-7-2 bundle review, FIN-11-4, CLB-detail-11).
Gates added here stay default-off. Production mounts were not switched on.

## 1. IM `POST /api/im/read` `{conversation_id}`

Finding: `merchant/index-P1`. `canWriteOrdinaryRead` still requires the ordinary read-receipt fields and stays false unless a mount opts into that older write.

- Core file: `Core/IMExpandedService.swift`
- Gate: `inboxConversationReadEnabled` (init default `false`). `canWriteInboxConversationRead` is that flag, and `api/im/read` when `enabledPaths` is set.
- Hook: `markInboxConversationRead(conversationID:token:)`. POST JSON `{"conversation_id": <Int>}` only. No `read_to`, no `request_id`. Refuses with `APIError.notConfigured` while the gate is off, and sends nothing.
- `App/AppSession.swift` is unchanged, so the production service is still constructed with the default off. `canWriteOrdinaryRead` is unchanged.

## 2. Coop settlement `source=club`

Finding: `fix-parity2-merchant-coop` left `source=club` off `CoopFlowRead`.

- Core file: `Core/CooperationFlowService.swift`
- Hook: `CoopFlowRead.clubSettlementSummary(clubID:)`. Read only. Path `api/club/settlement/summary`, `usesGet == true`, query `clubId`. `clubID > 0`. No withdraw, no amount rewrite.
- `App/CooperationFlowFixtures.swift` gained one DEBUG fixture arm so the exhaustive `CoopFlowRead` switch still compiles. No App settlement screen was mounted; `CoopSettlementDetailModel` still reads finance / my-business only.
- Blocker: the work order and r6 table say GET. The served controller (`ApiClubSettlementController` `POST /summary`, body `{clubId}`) and the existing club readers (`ClubGovernanceRead.settlement`, `RePoint03ClubSettlement`, `PayoutReceiverClient`) are POST JSON. This new case follows the written GET and is not mounted, so production does not send it. A later mount should confirm the method before enabling it.

## 3. MKT-7-2 public home, public reviews, and bundle review

Findings: r6 `MKT-7-2` (`RetainedPublicMerchantReviewHost` still `enabled: false`; public list query has no `registrationId`) and r5 `MKT-7-2` (`UnavailableBundleReviewClient` because `/api/free-explore/bundle/review` does not exist). The three merchant routes are already `.liveInProduction`.

- Core file: `Core/MerchantPublicReviewHook.swift`
- Gate: `MerchantPublicReviewGate` default `enabled: false`. A disabled client throws `MerchantPublicReviewHookFailure.disabled` and does not touch the transport.
- Hooks on `MerchantPublicReviewClient` (a later mount calls these; the host and the bundle mount were not edited):
  - `publicHome(memberId:)` → `POST /api/merchant/public-home` JSON `{memberId}`. Returns the server `data.id` as `merchantRowId`.
  - `publicReviews(merchantRowId:registrationId:pageNum:pageSize:token:)` → `POST /api/merchant/reviews/public` with query `merchantRowId`, `registrationId`, `pageNum`, `pageSize`. `pageSize` must be 20.
  - `createReview(_:token:)` → `POST /api/merchant/reviews/create` JSON `{merchantRowId, registrationId, rating, content, imageUrls, requestId}`.
- Not edited: `App/RetainedPublicMerchantReviewHost.swift`, `App/BundleCommerceMount.swift`, `Core/BundleReviewClient.swift`, `Core/ChinaReviewedRouteCapability.swift`. `enabled: false` on the retained host stays. The hook does not call `/api/free-explore/bundle/review` and does not conform to `BundleReviewServing`.

## 4. FIN-11-4 `INVOICE_NOT_FOUND`

Finding: the original-request read mapped every non-200, including `INVOICE_NOT_FOUND`, to `InvoiceLaunchIssue.outcomeUnknown`, and a manual re-check then used the same copy for a transport failure.

- Core files: `Core/InvoiceLaunchContracts.swift` (`InvoiceLaunchIssue.notFound`), `Core/InvoiceLaunchService.swift`, `Core/InvoiceLaunchCoordinator.swift`.
- Mapping: only `api/invoice/request` with `errorCode == INVOICE_NOT_FOUND` throws `.notFound`. Title-receipt and command-receipt reads stay `.outcomeUnknown`. The rollback set is unchanged. Amounts, refunds, and payouts are unchanged.
- `readback` rethrows `.notFound` and does not clear the journal.
- `App/InvoiceLaunchPresentation.swift`: a manual re-check sets 暂未查到 only for `.notFound`. A transport failure stays the unknown copy. The apply-page `from()` maps `.notFound` onto the existing unknown phase, so no new string was added.
- C3 burn-down (existing tests, not edited): `InvoiceLaunchServiceTests.testOriginalNotFoundIsUnknownNotRollback` and `InvoiceLaunchCoordinatorTests.testOriginalApplyMismatchAndNotFoundKeepExactJournal` still expect `.outcomeUnknown` for this read.

## 5. CLB-detail-11 topic link

Finding: `pages/topic/index/index` was parsed with `id` only, so `sourceClubId` and `clubCode` were dropped. iOS attribution stays undecided.

- Core file: `Core/TopicClubShareLink.swift` (new). `MiniProgramPageLink` and the App link routers were not edited.
- Hook: `TopicClubShareLinkParser.parse(_:)`.
- Accepted shape: `pages/topic/index/index?id=&sourceClubId=&clubCode=`, also with a leading slash, an `https` URL, or `chein://mp/…`. Query keys must be exactly those three. `id` and `sourceClubId` are canonical positive decimals. `clubCode` is carried as data.
- `TopicClubShareLink.laterRegistrationField` is the string `sourceChannelCode`. The parser does not choose whether `sourceClubId` or `clubCode` becomes that value.

## Route table for P2

No new row. Do not edit `ChinaReviewedRouteCapability.swift` for this set. These paths are already `.liveInProduction`:

- `/api/im/read`
- `/api/club/settlement/summary` (see the GET vs POST blocker above; the table is path-keyed)
- `/api/merchant/public-home`
- `/api/merchant/reviews/public`
- `/api/merchant/reviews/create`

## Skipped

- r6 §1 server-field wishes (`CLB-customer-detail-06` `summary.lastInteractionText`, `JREPORT-5` `RUN_NOT_FOUND`).
- r6 §3 owner-gate rows.
- r5 `relation-P0b` (club post feed `scope=all`).
- Money movement: no withdraw, refund, payout, or amount change.
- No item was skipped for a port-owned file. None of ChapterStoryContracts, CastContracts, CastService, CastCoordinator, JourneyRoleView, PlayExperienceCoordinator, PlayExperienceService, PlayExperienceContracts, PlayContracts, PlayProgression, PlayDurableRecovery, PlayRecoveryStorage, PlayArrivalPolicy, PlayArrivalService, FreeExplorationStoryArchive, FreeExplorationVisitConfig, PlayStationImage, ChinaReviewedRouteCapability, PlayKitScreenContracts, PlayKitQuestoContracts, PlayAdvancedRuntime, PlayHelpLadder, PlayContentCompatibility, LetterPoolState, PlayKitWrongReply, PlayGameStage, TopicContracts, TopicChapterCards, TopicDepartNotes, ClubContracts, TicketWalletContracts, ContextualReviews, IMConversationReplyPolicy, ClubActivityReportSelection, or RegistrationUIForm was edited.

## Tests

New file only: `Tests/CoreTests/WiringR6ClientTests.swift`. Existing test files, `project.pbxproj`, `Localizable.xcstrings`, and `tools/current_ci_manifest.json` were not edited.

`swiftc` is not installed on this VM, so the changed Swift files were not parsed.
