# Receipt: cursor/r8-player-content

- Branch: `cursor/r8-player-content`, cut from `origin/ui/combined-r7` at `f5f3006d781ac4d61c225a079ef74e2e2a86befd` (message starts "Integrate Cursor round 5"). Not rebased.
- Source: `origin/audit/parity-r8-player-content` `docs/audit/parity-r8/player-content.md`. Owner exactly "Cursor Core", then non-money owner-decision rows whose fix is a Core grant.
- Area: Core/, Tests/, `docs/port/strings/cursor-r8-player-content.json`. No App screen edits. No `AppSession.swift`. No `AppCompositionRoot.swift`. No `project.pbxproj`. No `tools/current_ci_manifest.json`.
- `WalletIncomeAnalysisReader` and `TopicClubShareLink.clubCode(trimmed)` are unchanged.
- `PlayerContentMPContract.broadcastRecoverPath(id:)` is unchanged. `OfficialEventService.recoverBroadcast` calls `broadcastRecoverPath(id: id)`.
- swiftc was not run. This receipt does not claim a parse.
- Money stays off. `pricingGrantEnabled` stays false. `POST api/registration/quote`, `POST api/registration/create`, and `POST api/topic/pricing/confirm` still throw and send nothing.

## Rows taken

| id | What landed in Core |
|---|---|
| R8-PC-B1-1 | Create stays refused. `PlayerContentMPContract.registrationCreate` still throws `Refusal.moneyDisabled` before a request exists. |
| R8-PC-B4-1 | `pricingConfirm` still throws `Refusal.pricingGrantDisabled`. `pricingGrantEnabled` stays false. |
| R7-PC-B2-1 | `MerchantContentWriteApproval` defaults node, NPC, cancel, audit, and circle review on. `permits` sends the existing command bodies for submit/audit node, save/enroll/reset NPC, cancel registration, audit application, and circle review. Chapter invite, respond, apply, and withdraw stay false. |
| R7-PC-B3-1 | `register` and `updateRegistration` default on. Same `permits` path. Chapter flags stay closed. |
| R7-PC-B1-2 | When a runtime session matches, `publisherGrants.ownership` and `.graduation` are an `OperationEndpointApproval` on the same base URL, namespace, and account, with `api/topic/beta/graduate` and `api/topic/transfer-to-club` added. Pricing, cancellation refunds, and creator application stay nil. Coordinator confirm for those two actions sends `PlayerContentMPContract.betaGraduate` / `transferToClub` (`application/x-www-form-urlencoded;`, `topicId` then `clubId`). |
| R7-PC-A1-3 | `TopicSummary` and `ActivitySummary` decode `clubName`, `merchantName`, `statusLabel` (only when the server sends text), and topic `productType`. `HomeFeedItem` exposes `categoryNames`, `feedTags` (first two), `productType`, `clubLabel`, `statusLabel`. No invented status. |
| R7-PC-B1-5 | `PlayerContentGapService.checkOrientSafety` posts JSON `{topicId}`. `PlayerOrientSafetyDecision.decide` proceeds on `ORIENT_DISABLED` / `ORIENT_NOT_ORIENTEERING`, retries with 网络异常，请重试 when code is not 200 or `allowed` is missing, and refuses with 按平台规则，现在不能开始这个主题。 otherwise. |
| R7-PC-B3-4 | `MerchantApplyXcx.allMissing` returns every validateForm failure: address, dates, a set-but-invalid `HH:mm-HH:mm` slot, description, photos. |
| R7-PC-C1-1 | `ActivityDetailAccess.cancelled(canViewOwnOrders:)` when a non-200 `api/activity/info` envelope has `errorCode == ACTIVITY_CANCELLED`. `canViewOwnOrders` is true only when the server bool is true. `ActivityDetailPagePhase.cancelled` maps it. |
| R7-PC-C1-8 | Code 200 with `data` null or missing throws `ActivityDetailFailure.notFound`. |
| R7-PC-C2-2 | Waitlist decode rejects only when `waitlistJoinAllowed` is true and eligibility is not `ELIGIBLE`. `ELIGIBLE` with join not allowed decodes. Optional `reservationState`. `hostReservation(ticketSoldOut:)` fills `ActivityHostReservationState`. `REQUESTED` and `REJECTED` are waitlist states. `canJoin` is still none / cancelled / expired. |
| R7-PC-C4-1 | `OfficialEvent.leaderboard` reads `e.leaderboard` when `enabled === true`. Rows keep rank > 0, name or 城瘾玩家, done/total, and the elapsed clock. Chip text is 暂列第 N 名, or 第 N 名 when `final === true`. |
| R7-PC-C6-2 | `OfficialEventService.recoverBroadcast(id:token:)` POSTs `broadcastRecoverPath(id: id)` with no body. `OfficialBroadcastStats.canRecoverInapp` is decoded. Scalar stat rows are unchanged. |
| R8-PC-C6-2 | `deliveryCounts` decodes `INAPP_STORED`, `CHANNEL_ACCEPTED`, `REJECTED`, `NOT_SUBMITTED`, `RETRYABLE`, `UNKNOWN`, `LEGACY_UNCONFIRMED`, `CAPPED`. `summaryLine` is the mini-program sentence. `failureLine` appends ，点一下重试. Nested objects stay out of `rows`. |
| R8-PC-A7-1 | Preview cards keep the Chinese `footText` / `checks` and add `footCopy` / `checkCopies` catalog keys. Fragment: `docs/port/strings/cursor-r8-player-content.json`. |
| R7-PC-A8-3 | `PublicTopicTemplateDetail.isOfficial` is true for JSON `true`, `1`, or `"1"`. |
| R7-PC-B1-21 | `TopicChapter.locked` is true only when the JSON bool is true. |
| R7-PC-B4-5 | `PublisherPricingPreview.productType` is decoded. Confirm stays refused. |
| R7-PC-C1-9 | `ActivityDetail.organizerShopLogo`. Host person reads `memberAvatar`. Registrant reads `avatar`. |
| R7-PC-D1-6 | `CreatorContentProject.latitude` / `longitude` accept a finite number or numeric string. |
| R7-PC-D3-3 | `PublicContentShareLink.information(id:)` returns a `https://www.chengyinhub.com` URL only when an existing parser accepts `/subpackageA/pages/infomationdetail/infomationdetail`. Otherwise nil, and `informationCopyText` is that path. Source spelling kept. |
| R7-PC-D9-2 | `CommunityMemberReportClient` `writesEnabled` defaults true. Body is still `api/community-trust/reports/submit` JSON (`targetType`, `targetId`, `reasonCode`, `policyVersion`, `description`, `requestId`). An explicit `writesEnabled: false` still throws `APIError.notConfigured` and sends nothing. |
| R7-PC-B1-1 | `TopicLikeHostController.likeGrantEnabled` defaults true. Nil transport still sends nothing. `miniProgramLikeRequest` builds `PlayerContentMPContract.like` (`id` then `type`, urlencoded). `TopicLikeOperationFactory` stays unreferenced outside `TopicLikeDirection.swift` because that factory is multipart, not the mini-program body. |

## Tests updated

- `MerchantApplyWriteGateTests.testRegistrationCreateAndUpdateAreNotPermittedOnTheDisabledService` — default approval permits register and update; chapter apply and withdraw stay closed; `permitsWrites` stays false.
- `RuntimeDependencyTests.testPublisherReadGrantDoesNotGrantPricingRefundOrOwnershipWrites` — ownership and graduation are issued; pricing, refunds, and creator application stay nil; the pricing preview read is unchanged.
- `PlayerContentMPContractTests.testTopicLikePinsIdAndTypeAndGrantStaysOff` — grant default is true; the like body pin is unchanged.
- `PlayerContentCoreContractTests.testCommunityTrustReportSubmitDefaultsOnAndMatchesTheSheetBody` — default submit sends; a closed client does not.
- `MPGapG1Tests.testTopicTemplatePreviewFromWireBuildsDeckAndChecks` — Chinese checks stay; catalog keys are asserted.
- `RegistrationWaitlistTests.testUnknownStatesAndContradictoryEligibilityFailClosed` — `ELIGIBLE` + join not allowed decodes and shows the host-reservation line; sold out hides it; `BLOCKED` + join allowed still throws.

## App call sites left for Claude

Do not treat this list as implemented. Core does not edit these screens.

1. `App/ActivityDetailView.swift` around the `switch access` (`.clubRequired` / `.allowed`). Add `.cancelled(let canViewOwnOrders)` and mount `ActivityCancelledStateView` (`App/MPGap/PlayerContent/PlayerContentRound2Views.swift`) with `onViewOrders` and `onBack`. Until that arm exists, this switch does not compile. `ActivityDetailFailure.notFound` should show 活动不存在 and return to the activity list.
2. `App/HomeFeedView.swift` 编辑精选 and feed tags: read `HomeFeedItem.clubLabel`, `statusLabel`, `feedTags`, `productType`. Do not invent a status when `statusLabel` is nil.
3. Play entry (`PlayRuntimeGapViews` / `TopicDetailView`): call `checkOrientSafety` and branch on `PlayerOrientSafetyDecision` before play. Keys `orient.safety.refused` and `orient.safety.retry`.
4. `App/MerchantContentEditor.swift` inline errors: show `MerchantApplyXcx.allMissing` messages instead of only the first missing field.
5. `App/PublisherLifecycleViews.swift` / `PublisherPricingView.beginConfirm`: when a pricing grant exists, call `coordinator.confirm` with scope and ticket prices. Do not send while `pricingGrantEnabled` is false. Hide 有人带 / 无人带 when `PublisherPricingPreview.productType == 2`.
6. Registration sheet (`RegistrationSheetView` / `ActivityRegistrationGapSections`): pass `RegistrationWaitlistStatus.hostReservation(ticketSoldOut:)` into the existing host-reservation section. Sold-out tickets stay on the waitlist card.
7. Official event detail: pass `OfficialEvent.leaderboard?.rows` to `OfficialEventLeaderboardSection` and show `chipText` (keys `official.leaderboard.provisional` / `official.leaderboard.final`).
8. `OfficialPrivateViews`: button 安全恢复原投递 calls `OfficialEventService.recoverBroadcast(id:token:)`, confirms with `official.broadcast.recover` / `official.broadcast.recover.body`, then re-reads stats. Show `OfficialBroadcastStats.summaryLine`. Prefer the server message via `failureLine`.
9. `App/TopicTemplateDeckPreviewView.swift`: render `footCopy` / `checkCopies` from `docs/port/strings/cursor-r8-player-content.json` instead of `footText` / `checks`.
10. `App/DiscoveryTemplateDetailView.swift`: pass `PublicTopicTemplateDetail.isOfficial` instead of `official: false`.
11. `App/TopicDetailView.swift` chapter lock: when `TopicChapter.locked` is true, show the lock and route to the paywall.
12. `App/ActivityPeopleSection.swift`: host avatar is `organizerShopLogo` when `organizerShopName` is present, otherwise `memberAvatar`. Registrants use `avatar`.
13. `App/MyProjectTabViews.swift`: drop the map pin on `CreatorContentProject.latitude` / `longitude` when both are present.
14. `App/SocialGuideViews.swift` share toolbar: use `PublicContentShareLink.information(id:)` and, when that is nil, `informationCopyText(id:)`.
15. `AppSession` composition (not edited here): construct `CommunityMemberReportClient` with the default write grant and present the MEMBER report sheet. `.imRead` is passed explicitly as `factory.permits(.imRead)` inside `AppSession`; turning that on is an AppSession change and was not done. Host cancel/refund stays on `ReviewedAreaSwitch.moneyPayments` and was not touched.
16. `App/TopicDetailView.swift` favorite: pass `isFavorited` / `onToggleFavorite` through `TopicLikeHostController` with a transport and `TopicLikeHostController.miniProgramLikeRequest`. The controller grant defaults on; a nil transport still sends nothing. `TopicDetailView` graduate / transfer still call `popupCloseActions.graduateBetaTopic` and `transferTopicToClub`. Point those at `PublisherLifecycleCoordinator.confirm` so the urlencoded grant path is what sends.
17. Self-play entry (`App/GlobalSearchLinksAndTemplates.swift` / the session create call): keep hiding or disabling create. Do not call `registrationCreate` while money is off.

## Left off on purpose

- `pricingGrantEnabled` false. Quote, create, and pricing confirm throw.
- Chapter invite, respond, apply, and withdraw default false.
- Coop finance and withdrawal stay TEST-only.
- `R7-PC-D9-1` im read grant lives in `AppSession` and was not switched on.
- Owner rows whose fix is an App ruling (merchant lane, guest read, editors, campaign, inbox tabs, banners, city menu, publish plus, registration sheet flag, notification mount) were not taken.
