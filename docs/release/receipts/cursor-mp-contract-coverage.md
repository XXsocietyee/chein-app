# cursor-mp-contract-coverage

Base `82388e4a5e7391e0c5a286735d6b30613a860ae8` (`origin/ui/combined-r7`). Branch `cursor/mp-contract-coverage`. No pull request.

Mini-program source: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`. Table: `docs/mp-contract-coverage.md`, from `tools/check_mp_contract_coverage.py`.

## Counts

| count | value |
|---|---|
| total requests | 102 |
| matched | 19 |
| missing endpoint | 42 |
| missing test | 82 |
| tests added | 16 |

`matched` means the row has both a Core symbol and a pinning test. One of those 19 is the pre-existing `Stub.testAdvancedUnknownIsSettledByItsOwnReceipt` on `pages/play/components/advanced-game/index.js:369` (`GET api/play/advanced/receipt`, fields `sessionId`, `idempotencyKey`). The 16 new tests are in `Tests/CoreTests/MiniProgramContractPinTests.swift`:

- `testPlayExperienceGatesDefaultOff`
- `testCircleCardPinsGet`
- `testCircleOffersPinsGet`
- `testCircleJoinPinsInviteCode`
- `testCircleCreatePinsTopicId`
- `testCircleRecordPinsSessionOfferAndNote`
- `testCircleAnswerPinsSessionStageAndValue`
- `testAdvancedStatePinsSessionId`
- `testAdvancedLeaderboardPinsActivityTopicAndNode`
- `testPresenceReadPinsSessionId`
- `testPresenceChangePinsSessionVisibleAndConsent`
- `testPassportHistoryPinsBeforeAndLimit`
- `testPassportSummaryPinsGet`
- `testPassportRecordPinsSessionId`
- `testPlatformPassOrderCreateStaysRefused`
- `testPlatformPassPayStaysUnsent`

Fifteen of them pin 19 call sites. `testPlatformPassPayStaysUnsent` pins `subpackageMember/utils/platform-pass-pay.js:76` and that row still has no Core endpoint, so it counts in missing endpoint and not in matched. `testPlayExperienceGatesDefaultOff` pins no row.

## Highest-traffic pages

- Home `pages/index/index.js` has no `request(` row. It has nine `sendRequest(` calls. `sendRequest(` and `req(` are not rows.
- Topic `pages/topic/index/index.js:1557` is `subscribe.request`. `pages/topic/utils/voice-enrollment-journal.js` uses `request` as a predicate on an id. No `/api` path. Left missing.
- Club `pages/club/detail/index.js:3821` is `subscribe.request`. Left missing.
- Play circle card, offers, join, create, record, and answer are pinned on `PlayExperienceService` (record and answer's path literal lives on `ChinaReviewedRouteCapability.playRuntimeOwnerGrant`). Advanced state and leaderboard are pinned. Advanced start and action stay unpinned: the body is `Object.assign` of a variable, so the field list is unparsed.
- Roam presence read and change, and passport history, summary, and record, are pinned. `pages/roam/index.js:210` is `community.request` inside `function req(url, method, data)`; the URL is a parameter. Capsule and exploration-goal calls are in the remainder.
- Orders: `POST api/platform-pass/orders` with `planCode`, `channel`, and `requestId` is refused. `PlatformPass.moneyEnabled` is false, `purchase` throws `PlatformPassWriteRefusal.unreachable`, and the recording transport stays empty. `POST api/platform-pass/orders/{}/pay` with `jsCode` is recorded as unsent and has no Core sender. Confirm, cancel, and refund-apply stay missing. No money write was enabled.

A default `PlayExperienceService` is constructed with an empty capability set. The pinning tests pass `.reads` or `.circle` only for that call. No new Core type was added. The requests go through `PlayExperienceService`, `RoamPresenceVisibilityContract`, `RoamPassportHistoryReadRoute`, and `PlatformPass`.

## Pinned by the new tests

| MP file:line | method | path | fields | Core symbol | test |
|---|---|---|---|---|---|
| `pages/play/circle/index.js:154` | `GET` | `api/circle-theme/session/{}/card` | (none) | `PlayExperienceService.circleCard` | `testCircleCardPinsGet` |
| `pages/play/circle/index.js:161` | `GET` | `api/circle-theme/instance/{}/offers` | (none) | `PlayExperienceService.circleOffers` | `testCircleOffersPinsGet` |
| `pages/play/circle/index.js:176` | `POST` | `api/circle-theme/session/join` | inviteCode | `PlayExperienceService.circleOpen` | `testCircleJoinPinsInviteCode` |
| `pages/play/circle/index.js:188` | `GET` | `api/circle-theme/session/{}/card` | (none) | `PlayExperienceService.circleCard` | `testCircleCardPinsGet` |
| `pages/play/circle/index.js:199` | `POST` | `api/circle-theme/session` | topicId | `PlayExperienceService.circleOpen` | `testCircleCreatePinsTopicId` |
| `pages/play/circle/index.js:209` | `GET` | `api/circle-theme/session/{}/card` | (none) | `PlayExperienceService.circleCard` | `testCircleCardPinsGet` |
| `pages/play/circle/index.js:349` | `POST` | `api/circle-theme/session/record` | sessionId, offerId, note | `ChinaReviewedRouteCapability.playRuntimeOwnerGrant` | `testCircleRecordPinsSessionOfferAndNote` |
| `pages/play/circle/index.js:431` | `POST` | `api/circle-theme/session/answer` | sessionId, stage, value | `ChinaReviewedRouteCapability.playRuntimeOwnerGrant` | `testCircleAnswerPinsSessionStageAndValue` |
| `pages/play/circle/index.js:486` | `GET` | `api/circle-theme/session/{}/card` | (none) | `PlayExperienceService.circleCard` | `testCircleCardPinsGet` |
| `pages/play/components/advanced-game/index.js:152` | `GET` | `api/play/advanced/state` | sessionId | `PlayExperienceService.advancedState` | `testAdvancedStatePinsSessionId` |
| `pages/play/components/advanced-game/index.js:533` | `GET` | `api/play/advanced/leaderboard` | activityId, topicId, nodeId | `PlayExperienceService.advancedLeaderboard` | `testAdvancedLeaderboardPinsActivityTopicAndNode` |
| `pages/play/components/advanced-game/index.js:579` | `GET` | `api/play/advanced/state` | sessionId | `PlayExperienceService.advancedState` | `testAdvancedStatePinsSessionId` |
| `subpackageMember/utils/platform-pass-pay.js:23` | `POST` | `api/platform-pass/orders` | planCode, channel, requestId | `PlatformPass.passOrdersPath` | `testPlatformPassOrderCreateStaysRefused` |
| `subpackageMember/utils/platform-pass-pay.js:76` | `POST` | `api/platform-pass/orders/{}/pay` | jsCode | `MISSING` | `testPlatformPassPayStaysUnsent` |
| `utils/roam-passport-read.js:73` | `GET` | `api/roam/passport/history` | before, limit | `ChinaReviewedRouteCapability.wiredPatterns` | `testPassportHistoryPinsBeforeAndLimit` |
| `utils/roam-passport-read.js:85` | `GET` | `api/roam/passport/summary` | (none) | `ChinaReviewedRouteCapability.wiredPatterns` | `testPassportSummaryPinsGet` |
| `utils/roam-passport-read.js:91` | `GET` | `api/roam/passport/record` | sessionId | `ChinaReviewedRouteCapability.wiredPatterns` | `testPassportRecordPinsSessionId` |
| `utils/roam-presence-privacy.js:21` | `GET` | `api/roam/presence-visibility` | sessionId | `RoamPresenceVisibilityContract.path` | `testPresenceReadPinsSessionId` |
| `utils/roam-presence-privacy.js:26` | `POST` | `api/roam/presence-visibility` | sessionId, visible, consentVersion | `RoamPresenceVisibilityContract.path` | `testPresenceChangePinsSessionVisibleAndConsent` |

## Remainder

These 82 rows still have no pinning test. `unparsed` means the data argument is not a closed object literal; the tool does not infer its keys.

| MP file:line | method | path | fields | Core symbol |
|---|---|---|---|---|
| `app.js:374` | `POST` | `-` | code | `MISSING` |
| `app.js:395` | `-` | `-` | unparsed | `MISSING` |
| `pages/activity/baoming/baoming.js:1761` | `-` | `-` | unparsed | `MISSING` |
| `pages/club/detail/index.js:3821` | `-` | `-` | unparsed | `MISSING` |
| `pages/coop/invite/index.js:760` | `-` | `-` | unparsed | `MISSING` |
| `pages/merchant/ledger/index.js:292` | `POST` | `api/merchant/events` | unparsed | `MerchantService.events` |
| `pages/merchant/ledger/index.js:324` | `POST` | `api/merchant/finance/redemptions` | unparsed | `MerchantFinanceRedemptionList.request` |
| `pages/merchant/ledger/index.js:360` | `POST` | `api/merchant/aftercare/list` | unparsed | `MISSING` |
| `pages/merchant/ledger/index.js:490` | `POST` | `api/merchant/finance/overview` | unparsed | `MerchantBusinessQuery.request` |
| `pages/merchant/ledger/index.js:492` | `POST` | `api/merchant/finance/settlement-entries` | unparsed | `MerchantBusinessQuery.request` |
| `pages/merchant/ledger/index.js:496` | `POST` | `api/merchant/finance/public-transfer-batches` | unparsed | `MerchantBusinessQuery.request` |
| `pages/merchant/ledger/index.js:547` | `POST` | `api/merchant/finance/redemptions` | unparsed | `MerchantFinanceRedemptionList.request` |
| `pages/merchant/ledger/index.js:549` | `POST` | `api/merchant/finance/settlement-entries` | unparsed | `MerchantBusinessQuery.request` |
| `pages/merchant/ledger/index.js:551` | `POST` | `api/merchant/finance/public-transfer-batches` | unparsed | `MerchantBusinessQuery.request` |
| `pages/merchant/ledger/index.js:799` | `POST` | `-` | unparsed | `MISSING` |
| `pages/merchant/relation/index.js:388` | `-` | `-` | unparsed | `MISSING` |
| `pages/merchant/reviews/reply-recovery.js:67` | `-` | `-` | unparsed | `MISSING` |
| `pages/merchant/reviews/reply-recovery.js:76` | `-` | `-` | unparsed | `MISSING` |
| `pages/merchant/utils/voice-enrollment-journal.js:18` | `-` | `-` | unparsed | `MISSING` |
| `pages/merchant/utils/voice-enrollment-journal.js:20` | `-` | `-` | unparsed | `MISSING` |
| `pages/merchant/utils/voice-enrollment-journal.js:76` | `-` | `-` | unparsed | `MISSING` |
| `pages/merchant/utils/voice-enrollment-journal.js:100` | `-` | `-` | unparsed | `MISSING` |
| `pages/mylike/mylike.js:187` | `POST` | `api/creativesquare/list` | favorite_only, pageNum, pageSize | `CreativeSquareAuthorDelete.listPath` |
| `pages/mylike/mylike.js:619` | `POST` | `api/creativesquare/bookmark` | id, bookmark, request_id | `ProfileFavoriteRemovalApproval.paths` |
| `pages/play/components/advanced-game/index.js:164` | `POST` | `api/play/advanced/start` | unparsed | `PlayExperienceService.startAdvanced` |
| `pages/play/components/advanced-game/index.js:304` | `POST` | `api/play/advanced/action` | unparsed | `NativePlatformService.actionPath` |
| `pages/play/merchant/index.js:34` | `POST` | `api/play/photo` | unparsed | `PlayStoreDayService.photoPath` |
| `pages/play/merchant/index.js:558` | `POST` | `api/compliance/consents` | unparsed | `RegistrationProductionService.path` |
| `pages/play/merchant/index.js:580` | `POST` | `api/compliance/consents/latest` | unparsed | `PlayStoreDayService.consentLatestPath` |
| `pages/publish/fabu/index.js:7024` | `-` | `-` | unparsed | `MISSING` |
| `pages/publish/utils/publish/publish-workflow.js:44` | `-` | `-` | unparsed | `MISSING` |
| `pages/publish/utils/publish/server-draft.js:477` | `-` | `-` | unparsed | `MISSING` |
| `pages/publish/utils/publish/server-draft.js:491` | `-` | `-` | unparsed | `MISSING` |
| `pages/publish/utils/publish/server-draft.js:535` | `-` | `-` | unparsed | `MISSING` |
| `pages/publish/utils/publish/server-draft.js:559` | `-` | `-` | unparsed | `MISSING` |
| `pages/publish/utils/publish/server-draft.js:574` | `-` | `-` | unparsed | `MISSING` |
| `pages/roam/index.js:210` | `-` | `-` | unparsed | `MISSING` |
| `pages/square/components/cy/post-compose/index.js:641` | `POST` | `api/creativesquare/action` | unparsed | `SocialActionRequestBuilder.path` |
| `pages/square/detail/index.js:213` | `POST` | `api/comment/add` | owner_type, owner_id, rating, contents, reply_id, img_arr | `RoamPlaceCommentClient.addPath` |
| `pages/square/detail/index.js:290` | `POST` | `api/comment/add` | owner_type, owner_id, rating, contents, reply_id, img_arr | `RoamPlaceCommentClient.addPath` |
| `pages/square/detail/index.js:493` | `POST` | `api/creativesquare/like` | id, type | `SocialActionRequestBuilder.path` |
| `pages/square/detail/index.js:534` | `POST` | `api/creativesquare/bookmark` | id, bookmark, request_id | `ProfileFavoriteRemovalApproval.paths` |
| `pages/square/detail/index.js:624` | `POST` | `api/comment/like` | id | `SocialActionRequestBuilder.path` |
| `pages/square/detail/index.js:680` | `-` | `-` | unparsed | `MISSING` |
| `pages/square/detail/index.js:754` | `POST` | `api/creativesquare/delete` | id | `CreativeSquareAuthorDelete.path` |
| `pages/square/detail/index.js:851` | `-` | `-` | unparsed | `MISSING` |
| `pages/square/detail/index.js:902` | `-` | `-` | unparsed | `MISSING` |
| `pages/square/detail/index.js:984` | `POST` | `api/creativesquare/info` | id | `ProfileFavoriteDetailRoute.paths` |
| `pages/square/detail/index.js:1146` | `POST` | `api/comment/list` | owner_type, owner_id, pageNum, pageSize | `RoamPlaceCommentClient.listPath` |
| `pages/talent/list/index.js:209` | `-` | `-` | unparsed | `MISSING` |
| `pages/topic/index/index.js:1557` | `-` | `-` | unparsed | `MISSING` |
| `pages/topic/utils/voice-enrollment-journal.js:18` | `-` | `-` | unparsed | `MISSING` |
| `pages/topic/utils/voice-enrollment-journal.js:20` | `-` | `-` | unparsed | `MISSING` |
| `pages/topic/utils/voice-enrollment-journal.js:76` | `-` | `-` | unparsed | `MISSING` |
| `pages/topic/utils/voice-enrollment-journal.js:100` | `-` | `-` | unparsed | `MISSING` |
| `subpackageA/components/scene-member-invite-history/index.js:244` | `POST` | `api/user/invite_list` | pageNum, pageSize | `SocialAccountService.invitations` |
| `subpackageA/components/scene-member-invite-history/index.js:250` | `POST` | `api/user/points/list` | pageNum, pageSize | `SocialAccountService.rewards` |
| `subpackageB/pages/im/list/index.js:246` | `-` | `-` | unparsed | `MISSING` |
| `subpackageMember/components/cy/coop-invite-sheet/index.js:215` | `-` | `-` | unparsed | `MISSING` |
| `subpackageMember/components/cy/profile/index.js:83` | `POST` | `-` | unparsed | `MISSING` |
| `subpackageMember/components/cy/profile/index.js:914` | `POST` | `api/merchant/public-home` | unparsed | `PublicMerchantHomeHTTPReader.home` |
| `subpackageMember/components/cy/profile/index.js:1789` | `POST` | `api/im/start` | target_member_id | `SocialActionRequestBuilder.path` |
| `subpackageMember/components/cy/scene-member-order-detail/index.js:647` | `-` | `-` | unparsed | `MISSING` |
| `subpackageMember/components/cy/scene-member-order-history/index.js:394` | `-` | `-` | unparsed | `MISSING` |
| `subpackageMember/components/scene-member-participation-detail/index.js:609` | `-` | `-` | unparsed | `MISSING` |
| `subpackageMember/market/pass-order/index.js:77` | `POST` | `api/platform-pass/orders/{}/cancel` | unparsed | `MISSING` |
| `subpackageMember/market/pass-order/index.js:114` | `-` | `-` | unparsed | `MISSING` |
| `subpackageMember/market/pass-order/index.js:116` | `POST` | `api/platform-pass/orders/{}/refund-apply` | reason | `MISSING` |
| `subpackageMember/utils/platform-pass-pay.js:84` | `POST` | `api/platform-pass/orders/{}/confirm` | unparsed | `MISSING` |
| `utils/features/capsule-client.js:57` | `POST` | `api/capsules/create` | unparsed | `RoamPrivateToolsRoute.capsuleCreate` |
| `utils/features/capsule-client.js:75` | `GET` | `api/capsules/detail` | id | `RoamPrivateToolsRoute.capsuleDetail` |
| `utils/features/capsule-client.js:78` | `GET` | `api/capsules/receipt` | requestId | `RoamPrivateToolsRoute.capsuleReceipt` |
| `utils/features/capsule-client.js:84` | `GET` | `api/capsules/list` | unparsed | `RoamPrivateToolsRoute.capsuleList` |
| `utils/features/capsule-client.js:88` | `POST` | `api/capsules/delete` | id | `RoamPrivateToolsRoute.capsuleDelete` |
| `utils/features/exploration-goals.js:81` | `POST` | `api/exploration-goals/create` | unparsed | `RoamPrivateToolsRoute.goalCreate` |
| `utils/features/exploration-goals.js:101` | `GET` | `api/exploration-goals/receipt` | requestId | `RoamPrivateToolsRoute.goalReceipt` |
| `utils/features/exploration-goals.js:111` | `GET` | `api/exploration-goals/detail` | unparsed | `RoamPrivateToolsRoute.goalDetail` |
| `utils/features/exploration-goals.js:116` | `GET` | `api/exploration-goals/list` | unparsed | `RoamPrivateToolsRoute.goalList` |
| `utils/features/exploration-goals.js:130` | `POST` | `api/exploration-goals/cancel` | id | `RoamPrivateToolsRoute.goalCancel` |
| `utils/play-run-session.js:131` | `POST` | `api/play/run-session/save` | unparsed | `ChinaReviewedRouteCapability.wiredPatterns` |
| `utils/play-run-session.js:143` | `POST` | `api/play/run-session/clear` | unparsed | `PlayRunSessionClear.clear` |
| `utils/play-run-session.js:151` | `GET` | `api/play/run-session` | unparsed | `PlayExperienceService.readPaused` |

## Not claimed

No `swiftc` run. The tool does not parse JavaScript or Swift concatenation. Unknown paths, methods, and field lists stay unknown. Run-session save, clear, and read, merchant photo and consents, and advanced start and action are in that set.
