# K31 · offline-errors (cursor/1128-offline-errors)

Base: `origin/ui/combined-r7` at `c4e43841afaddd576a72104f8bf8641af2060732`. Working tree was uncommitted on `97b4ef2c`, then the branch was moved onto this tip before any commit. No rebase, no force-push.

A player write that is not a proven success now keeps a non-empty server `msg` and the control that already retries that write. A missing or blank sentence stays the old unknown outcome. Merchant stays off. Money, security, and deletion switches were not flipped. Screen changes are the existing error line (or the sentence placed on an existing error surface). `App/AppSession.swift` was not edited (7977 lines). No `String(localized:)` literals. `RuntimeDependencyConfiguration.init` was not edited.

## Fixed

| Site | Fix |
|---|---|
| `Core/PlayerGapRoutes.swift` `PlayerGapReply.classify` | A non-empty trimmed `msg` on anything other than ok, 401, or a 4xx business code is `.retryable(message:)`. Code 500 with no sentence, a blank `msg`, and an empty HTTP 502 stay `.unknown`. `message` includes the retryable sentence. `offersRetry` is false for ok and unauthorized. |
| `ActivityPublishPrecheck.make` | `.retryable` becomes `.failed(message)`. The existing precheck gate already shows that text and `playerGap.retry`. |
| `OfficialSignupCommandFlow.send` | A non-ok signup write stores `failureMessage` from the reply and stays `.unknown`, so query, retry, and cancel still address the saved request id. `OfficialSignupCommandSection` shows the sentence above `playerGap.signup.unknown`. |
| `renameObjectCard` | `.unknown` still clears the message. `.retryable` is not that case, so a 500 with `msg` is `.failed(message:)`. |
| `postCityNodeFavorite` | The favorite POST returns `PlayerGapReply`. `toggleCityNodeFavorite` → `Bool?` is unchanged. City-favorites removal and the merchant-node star show the sentence, or the existing `removeFailed` / `node.failed` key when there is none. Swipe and the star stay the retry. |
| `Core/PlayCreatorTailFlows.swift` timeline load and appeal submit | `.retryable` sets `load = .failed(message)` or `note = .server(message)`. The existing appeal recover control stays. |
| `App/MarketingConsentOfferRow.swift` | `.retryable` sets `.failed(message)`. The existing retry button stays. |
| `App/FreeExploreReceiptResolveScreen.swift` | `.retryable` sets `.failed(message:)`. Reload stays. |
| `App/PlayerParityBViews.swift` circle submit | `.retryable` sets `errorText` to the sentence and does not dismiss. The save control stays. |
| `PlayCheckRuntime.markUnknown(message:)` | `disabledReason` is the trimmed server sentence when the receipt is not a proven check. The existing `play.check.recover` button still re-reads the same action. `CHECK_REJECTED` / `CHECK_BAD_REQUEST` are unchanged. |
| `PlayThemeGameplayExchange.action` | Unproven 200 and non-2xx with a sentence return `.notedUnknown`. No sentence stays `.unknown`. `PlayThemeGameplayFlow` and the zero-HP sync line show that sentence and keep the command for the same-action retry. |
| `PlayCoopHelp.send` | Non-2xx with a sentence is `.notedUnknown`. Transport loss stays `.unknown`. The flow keeps `.writeUnknown` (same request id) and puts the sentence on `serverMessage`, drawn on the existing issue line. |
| `PlayHelpReply.classify` and `PlayExperienceService.help` | Same sentence rule as `PlayerGapReply`. Use sets `.pendingNote`; skip sets `notice = .pendingNote`. The row stays pending, so the same request id is resent. `PlayHelpLadderPanel` and `NativeGameHintSheet` show the sentence on the existing problem and notice lines. |
| `PlayStoreDayService.dispatch` | HTTP 5xx or 408 with a sentence is `.notedUnknown`. Empty 503 and a thrown transport stay `.unknown`. Answer, arrive, proof, and consent show the sentence on the existing game error or `.server` notice, and still resolve by readback. |
| `PlayerOrientSafetyDecision.decide` | A retry uses the trimmed server sentence when one exists, otherwise the existing `retryLine`. `ORIENT_DISABLED` and `ORIENT_NOT_ORIENTEERING` still proceed. |
| Lead arrive, lead broadcast, host request, team invite QR | These already assign `reply.message` onto the existing line. `.retryable` now supplies that sentence. The original buttons stay the retry. |

Tests: `PlayerGapRoutesTests` (classify, signup sentence, favorite reply, rename 500), `PlayRuntimeGapTests` (check reason `busy`, coop `.notedUnknown`, gameplay `.notedUnknown`), `PlayHelpLadderTests` (classify and pending note), `PlayStoreDayTests` (503 with `msg`), `MPGapG1Tests` (orient safety sentence).

## Left — transport catch, no server sentence

These `catch` bodies return `.unknown` or `.notSent` because the transport threw. There is no body to read. The caller already treats that as retryable unknown. Left.

- `Core/PlayerGapRoutes.swift` `send` (~138), and the same `send` in `MemberGapService`, `MemberRound2Service`, `PlayRoamGapService`, `PlayRoamRound2Service`, `PlayerContentGapService`, `PlayerContentRound2Service`, `PlayerContentRound4Models`.
- `Core/PlayRuntimeGap.swift` `PlayRuntimeClient.send` throws `.unknown` on transport loss (~90). `PlayCoopHelp.send` catch (~379) returns `.unknown`.
- `Core/PlayStoreDayService.swift` `dispatch` catch (~216) returns `.unknown`.
- `Core/PlayExperienceService.swift` `help` request-build catch (~461) and transport catch (~467) return `.unknown`.
- `Core/TeamHTTPService.swift` 72 `.notSent`, 79 `.unknown`, 87 `.unknown`, 265 `.unknown`, 362 `.unknown`. A command receipt that is `REJECTED` already returns `.rejectedMessage` with the server text. A non-2xx acknowledgment stays `.rejected` / `.unknown` so the recovery card can retry the same operation id. The acknowledgment case has no message slot; filling one would change a terminal journal clear that the team contracts pin.
- `Core/ProjectEditHTTPService.swift` 177 `.notSent`, 191 / 246 / 259 `.unknown`.
- `Core/NearbyTeamService.swift` 83 `.notSent`, 85 / 108 `.unknown`. `NearbyTeamHTTPWriteAdapter.swift` 109 / 139 `.notSent`, 119 / 148 / 161 `.unknown`. The nearby write UI already stores `serverMessage` when the typed rejection carries one.
- `Core/PublishModesService.swift` 172 `.notSent`, 198 `.unknown`.
- `Core/ActivityEditing.swift` 289 `.notSent`, 299 `.unknown`.
- `Core/CreatorApplication.swift` 78 `.unknown`, 79 `.notSent`. `CreatorStudioContracts.swift` 415 / 422 `.unknown`.
- `Core/GameplayPresetClient.swift` 172 `.notSent`. `PlayThemeReplay.swift` 110 `.unknown`, 122 `false`.
- `Core/SquareCommunityActionAccess.swift` 191 `.notSent`. `SquareDeletionFlow.swift` 72 `.unknown` (deletion switch not flipped).
- `Core/ContextualReviews.swift` 129 `.unknown`. `CouponManagementContract.swift` 117 / 138 `.unknown`.
- `Core/ClubBadgeManagementService.swift` 96 `.unknown`. `ClubContextualOperations.swift` 113 `.unknown`. `ClubAIDesignFlow.swift` 83 `.notSent`. `ClubCustomerHistoryTopicRoute.swift` 79 `false`.
- `Core/TopicTemplateAdoption.swift` 505 `.unknown`. `Adapt3ClubBackendAdapters.swift` 203 `.unknown`. `Adapt3GroupCodeIssueAdapter.swift` 50 `.unknown`.
- `Core/PublisherLifecycleCoordinator.swift` 85 `.unknown`, 86 `.notSent`.
- `Core/RoamPlaceCommentClient.swift` 88 `.unknown`. `RoamPresenceVisibilityService.swift` 34 / 43 / 59 `nil` (reads).
- `Core/OrientScoreSettlementWriter.swift` 105 / 120 / 142 `.unknown`, 208 `false`. `OrientScoreReviewWriter.swift` 130 `false`. These are score writes whose unknown state is the existing re-read, not a silent success.
- `Core/PlatformPassGiftClaimSource.swift` 62 `.unknown`. `OrderPaymentVerifier.swift` 50 `.unknown` (money path, not flipped).
- `Core/RePoint07OfferWithdrawal.swift` 45 / 56 `.unknown`. `MerchantOfferWithdrawalOriginalFlow.swift` 74 `false`. `MerchantContentService.swift` 569 `nil`. `MerchantGameNodeService.swift` 303 `false`. Merchant stays disabled.
- `Core/WorkshopCommerceController.swift` 90 / 94 `false` (money).
- `Core/TicketWalletService.swift` 173 `false`. `OfficialActionProduction.swift` 60 `false`.
- `Core/ProfileAvatarFlow.swift` 44 `false`. `ProfileOrderEventHost.swift` 39 / 51 / 65 `nil`. `ParticipantCoordinator.swift` 178 `false`.
- `Core/IMFileContracts.swift` 57 `nil`. `IMVoiceContracts.swift` 50 / 76 / 81 `nil`.
- `Core/ExternalGameReviewClient.swift` 177 / 322 / 331 `nil`, 340 `false`. `CloudB3Readers.swift` 221 `nil`. `OfflinePackLifecycleFlow.swift` 192 `nil`.
- `Core/MyProjectMutations.swift` 182 / 192 `nil`. `MerchantTemplateCategorySelection.swift` 128 `nil`.
- `Core/RoamStampCaptureCoordinator.swift` 110 `false`. `ActivityCoverAuthoring.swift` 175 / 183 `false`. `ApprovedTopicReviewJournal.swift` 71 `false`. `BundleReviewModel.swift` 167 `false`.
- `Core/TeamSyntheticFixtures.swift` 98 `.unknown` (fixture).

`try?` used to decode JSON inside a service is tolerant parsing. The caller still returns unknown, malformed, or a fallback field. Left as a class; they are not a dropped player-write sentence.

## Left — empty `catch` (comment is the reason)

| Site | Why left |
|---|---|
| `Core/ClubActionCoordinator.swift:276` | Preserve UNKNOWN; the detail below is only current state. |
| `Core/JourneyAmbientCoordinator.swift:94` | Location denial never blocks the main task. |
| `Core/JourneyAmbientCoordinator.swift:129` | Ambient failure never interrupts navigation. |
| `Core/WorkshopCommerceController.swift:317` | Money. Unknown dispatch stays recoverable through the original server order. |
| `Core/OrderPaymentVerifier.swift:75` | Money. The winning read cancelled this timer. |
| `Core/NativeChannelTextCoordinator.swift:232` | Keep the original, block new sends; re-read retries cleanup. |
| `Core/ProfileEditCoordinator.swift:242` | Unknown transport fails closed. Profile edit already sets `remoteMessage` on known write errors. |
| `Core/MerchantNPCKnowledgeAuthorFlow.swift:151` | Merchant. The accepted ticket stays; a disk failure must not submit again. |
| `Core/ProfileFavoriteRemoval.swift:185` | The local result is inspected below the catch. |
| `Core/MerchantOperationsReading.swift:61` | Merchant. A journal failure must not submit again. |
| `Core/NativeAttributeAuthorCoordinator.swift:289` | The original pending record stays durable. |
| `Core/BundleReviewModel.swift:189` | Stays unknown on purpose. |
| `Core/BundleShelfModel.swift:55` | Rows already shown stay; the cursor remains so the caller can retry. |

## Left — discarded `try?` statements

| Site | Why left |
|---|---|
| `Core/OfficialActionService.swift:90` `reportClick` | Click telemetry. The comment says it must not block navigation. |
| `Core/MessagingReading.swift:55` | Read-cursor post. A failure must not block opening the thread. |
| `Core/PlayRuntimeGap.swift` `PlayRunSessionClear.clear` / `PlayRunSessionSave.save` | Comments say failure is silent. The local finished or paused run stays authoritative. There is no error surface on the caller, and adding one would be a new layout. |
| `Core/PlayRuntimeGap.swift:225` and `:234` `store.write` | Journal bookkeeping after the check outcome is already recorded. A failed clear leaves the pending row, which is the safer retry. |
| `Core/BankWithdrawalConsentReader.swift:68` | Money. Not flipped. |
| `Core/MerchantAuthoringService.swift:226` and `:370` | Merchant. Cancel-job and journal ack. Not enabled. |
| `Core/MerchantOfferWithdrawalCoordinator.swift:191`, `:193`, `:226` | Merchant / money withdrawal locks. |
| `Core/MerchantGameNodeService.swift:314` | Merchant journal remove. |
| `Core/MerchantBusinessCoordinator.swift:242` | Merchant journal complete. |
| `Core/MerchantGameNodeCoordinator.swift:247` | `Task.sleep` deadline. Not a write. |
| `Core/ClubCommunityService.swift:259`, `:467`, `:473`, `:479`, `:484` | Journal mark/release after the primary error is already thrown. |
| `Core/JourneyAmbientCoordinator.swift:102` | Local seen-set save. The main task continues. |
| `Core/SquareWorkspaceCoordinator.swift:83` | Local discard of a workflow entry. |
| `Core/MapPublicLayerService.swift:535` | Local layer set after the server outcome is already known. |
| `Core/PlayExperienceCoordinator.swift:1022` and `:1130` | Local clock start and story-archive cache. |
| `Core/ClubWelcomePresentation.swift:75` | Local seen mark. |
| `Core/ClientOperationID.swift:122`, `TeamFriendInviteFlow.swift:91`, `:113`, `:138` | Local journal / id persistence after the outcome. |
| `Core/BundleAppealModel.swift:141`, `BundleTransferModel.swift:253` and `:337`, `BundleReviewModel.swift:183`, `:210`, `:216`, `:218` | Local pending clear after a terminal state. |
| `Core/WorkshopUpgradeDraftStore.swift:72`, `:239`, `:243`, `:248`, `:252` | Local file cleanup. |
| `Core/RoamExportDeliveryLease.swift:172`, `:175` | Local file cleanup. |
| `Core/PlayContentManifest.swift:194`, `:201`, `:251` | Local cache cleanup / sync note. |
| `Core/TeamMeetingPendingJournal.swift:68` | Local file cleanup. |
| `Core/ExternalGameImport.swift:1167`–`:1211` | Local directory and protected-file setup. |
| `Core/AccountScopedPersistence.swift:214` | Local JSON encode. |
| `Core/RegistrationUIFlow.swift:539` | Building a quote request object. A throw is a not-sent quote, already shown. |
| `Core/ProjectEditD20Rules.swift:309` | Local draft read. |
| `Core/RoamPassportPrivateToolsReading.swift:304` | Receipt lookup; the read result is handled by the caller. |
| `Core/PlayAudioClipSensor.swift:159` | `Task.sleep`. Not a write. |
| `Core/TemplateAuthoringSyntheticFixtures.swift:47` | Fixture setup. |

## Gates

`python3 tools/check_scaffold.py` passed (appsession ratchet included; 7977 lines). `python3 tools/check_a11y_lint.py` passed (0 new). `python3 tools/contract_ratchet.py --check` is 46 failing, baseline 46, new 0, fixed 0. The store-day 5xx line still contains `status >= 500 || status == 408 { return .unknown }` for a body with no sentence; a sentence on that status returns `.notedUnknown` on the line above it.
