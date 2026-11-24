# Play and roam contracts

Mini-program source: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`.

Coverage table and receipt read from `origin/cursor/mp-contract-coverage` at `569fca24195166bfb70cba51a8e2aedff27da2a3`. This file covers the play and roam rows that table left without a pinning test. It does not redo the 16 pins on that branch (play circle card, offers, join, create, record, answer, advanced state, leaderboard, roam presence, passport history, summary, record). It does not take member, club, or merchant-ledger rows.

`subpackageMember/market/pass-order/index.js:114` is `subscribe.request(['refund'])`. It is not an HTTP contract and is not in the table below.

`pages/roam/index.js:210` is `community.request` inside `function req(url, method, data, opts)`. The URL is an argument. No path is invented for that row. Concrete `req(` call sites are listed in the receipt.

## Contracts

Field lists are the keys the mini-program puts on the wire. `unparsed` means `tools/check_mp_contract_coverage.py` cannot see a closed object literal, so that tool still reports the test as missing even though the test quotes the keys.

| MP file:line | method | path | fields | content type | Core | test |
|---|---|---|---|---|---|---|
| `pages/play/components/advanced-game/index.js:164` | POST | `api/play/advanced/start` | `activityId`, `topicId`, `nodeId`, plus `declaration()` (`clientPlatform`, `clientVersion`, `supportedCapabilities`) | JSON | `PlayExperienceService.startAdvanced` | `testAdvancedStartPinsActivityTopicNodeAndDeclaration` |
| `pages/play/components/advanced-game/index.js:304` | POST | `api/play/advanced/action` | `sessionId`, `version`, `idempotencyKey`, `action`, `payload` | JSON | `NativePlatformService.actionPath` (sender `PlayExperienceService.advancedAction`) | `testAdvancedActionPinsSessionVersionKeyActionAndPayload` |
| `utils/play-run-session.js:131` | POST | `api/play/run-session/save` | `elapsedSeconds`, `savedAt`, and `activityId` or `topicId` | urlencoded | `PlayRunSessionSave.save` | `testRunSessionSavePinsElapsedSavedAtAndScope` |
| `utils/play-run-session.js:143` | POST | `api/play/run-session/clear` | `savedAt`, and `activityId` or `topicId` | urlencoded | `PlayRunSessionClear.clear` | `testRunSessionClearPinsSavedAtAndScope` |
| `utils/play-run-session.js:151` | GET | `api/play/run-session` | `activityId` or `topicId` | query | `PlayExperienceService.readPaused` | `testRunSessionReadPinsActivityOrTopic` |
| `pages/play/merchant/index.js:34` | POST | `api/play/photo` | `activityId` or `topicId`, `nodeId`, `picUrl` | urlencoded | `PlayStoreDayService.photoPath` / `photoContract` | `testPlayPhotoContractPinsSessionNodeAndPicture` |
| `pages/play/merchant/index.js:558` | POST | `api/compliance/consents` | `docType`, `scene`, `scopeType`, `scopeId`, `eventType`, `requestId` | JSON | checker names `RegistrationProductionService.path`; merchant body is `PlayStoreDayService.consentWriteContract` | `testMerchantOnsiteConsentWritePinsSubjectEventAndRequest` |
| `pages/play/merchant/index.js:580` | POST | `api/compliance/consents/latest` | `docType`, `scene`, `scopeType`, `scopeId` | JSON | `PlayStoreDayService.consentLatestPath` / `consentLatestContract` | `testMerchantOnsiteConsentLatestPinsSubject` |
| `utils/features/capsule-client.js:57` | POST | `api/capsules/create` | `requestId`, `body`, `photoUrl`, `unlockDate` | JSON | `RoamPrivateToolsRoute.capsuleCreate` | `testCapsuleCreatePinsRequestBodyPhotoAndUnlock` |
| `utils/features/capsule-client.js:75` | GET | `api/capsules/detail` | `id` | query | `RoamPrivateToolsRoute.capsuleDetail` | `testCapsuleDetailPinsId` |
| `utils/features/capsule-client.js:78` | GET | `api/capsules/receipt` | `requestId` | query | `RoamPrivateToolsRoute.capsuleReceipt` | `testCapsuleReceiptPinsRequestId` |
| `utils/features/capsule-client.js:84` | GET | `api/capsules/list` | `beforeId` (optional), `limit` | query | `RoamPrivateToolsRoute.capsuleList` | `testCapsuleListPinsBeforeIdAndLimit` |
| `utils/features/capsule-client.js:88` | POST | `api/capsules/delete` | `id` | urlencoded | `RoamPrivateToolsRoute.capsuleDelete` | `testCapsuleDeletePinsId` |
| `utils/features/exploration-goals.js:81` | POST | `api/exploration-goals/create` | `requestId`, `metric`, `target`, `startDate`, `endDateExclusive` | JSON | `RoamPrivateToolsRoute.goalCreate` | `testGoalCreatePinsRequestMetricTargetAndDates` |
| `utils/features/exploration-goals.js:101` | GET | `api/exploration-goals/receipt` | `requestId` | query | `RoamPrivateToolsRoute.goalReceipt` | `testGoalReceiptPinsRequestId` |
| `utils/features/exploration-goals.js:111` | GET | `api/exploration-goals/detail` | `id` | query | `RoamPrivateToolsRoute.goalDetail` | `testGoalDetailPinsId` |
| `utils/features/exploration-goals.js:116` | GET | `api/exploration-goals/list` | `limit`, `beforeId` (optional) | query | `RoamPrivateToolsRoute.goalList` | `testGoalListPinsLimitAndBeforeId` |
| `utils/features/exploration-goals.js:130` | POST | `api/exploration-goals/cancel` | `id` | urlencoded | `RoamPrivateToolsRoute.goalCancel` | `testGoalCancelPinsId` |
| `subpackageMember/market/pass-order/index.js:77` | POST | `api/platform-pass/orders/{orderNo}/cancel` | no body | JSON header, empty | `PlatformPass.cancelOrderPath` | `testPassCancelStaysUnsent` |
| `subpackageMember/utils/platform-pass-pay.js:84` | POST | `api/platform-pass/orders/{orderNo}/confirm` | no body | JSON header, empty | `PlatformPass.confirmOrderPath` | `testPassConfirmStaysUnsent` |
| `subpackageMember/market/pass-order/index.js:116` | POST | `api/platform-pass/orders/{orderNo}/refund-apply` | `reason` | JSON | `PlatformPass.refundApplyPath` | `testPassRefundApplyStaysUnsent` |
| `pages/roam/index.js:210` | (argument) | (argument) | (argument) | (argument) | none | none |

Scope for run-session and photo is `pages/play/index.js` `_sessionParams`: `activityId` when that id is present, otherwise `topicId`. Never both.

Merchant consent constants: `docType` `merchant_onsite_data_sharing`, `scene` `merchant_redeem`, `scopeType` `MERCHANT`, `scopeId` the node `merchantId`. The write adds `eventType` (`AGREE` or `REVOKE`) and `requestId`. Latest omits those two. `ComplianceSubject.merchantOnsite` already matches.

Capsule and goal create are JSON. Every other capsule or goal call is `application/x-www-form-urlencoded`. List sends `limit` 20 (`RoamCapsulePage.limit`, `RoamGoalPage.limit`) and `beforeId` when paging.

Cancel and confirm send no data object. Refund-apply sends JSON `{reason}`. The pass-order helper forces `content-type: application/json`.

## What the checker can mark pinned

A test pins a row only when one `Tests/CoreTests` function body contains the path, the quoted method, and every literal field, and the mini-program data argument parses. These six parse and are pinned on this branch:

- capsule detail, receipt, and delete
- goal receipt and cancel
- refund-apply

Start, action, run-session, photo, both consents, capsule create and list, and goal create, detail, and list stay unparsed (`Object.assign`, a variable, or an extra `++readEpoch` argument). Cancel and confirm have no data argument, so their field list stays unknown and the tool cannot pin them. The tests still quote the keys and the methods still refuse or send the body above.

The checker attributes `api/compliance/consents` to `RegistrationProductionService.path` because that signup writer assigns the same URL to a local named `path`. The merchant body is `PlayStoreDayService.consentWriteContract`. Signup consent is a different subject and is not this row.

The checker attributes advanced action to `NativePlatformService.actionPath` (`api/play/advanced/action`). `PlayExperienceService.advancedAction` sends the same five JSON keys.

## Live sender differences that stay

Advanced start field names match. `PlayClientCapabilities.startFields` still sends `supportedCapabilities` as an array of `key@version` strings and `clientPlatform` `ios-native`. The mini-program `declaration()` sends one comma-joined string and `clientPlatform` `wechat-miniprogram`, and always sends `clientVersion` (possibly empty). `declaration(_:)` is the comma-string helper. iOS keys are the existing set (no `role.views`; includes `answer.sensor`). The live array sender is unchanged.

`PlayExperienceService.savePaused` stays multipart and is not the run-session pin. `PlayRunSessionSave.save` is the urlencoded body `pages/play` `req` produces. Nothing in `App/` calls it.

`photo()` still adds action-context identity when proof writes are permitted. `photoContract` is the mini-program field set and does not send. `MerchantCityNPCParityGates` defaults `storeDayProofWrites` and `storeDayConsentWrites` to false. Production `AppSession.playStoreDay` passes `gates: .disabled`, so photo and consent send nothing.

Cancel, confirm, and refund-apply throw `PlatformPassWriteRefusal.unreachable` and do not touch the transport. `PlatformPass.moneyEnabled` stays false. `JourneyLoopSource.giftClaim` still throws `JourneyRefusal.moneyOff` and sends nothing. `PlayStageAnalyticsGate.enabled` stays false.

Rank rows stay on `JourneyRankBoardContract` in Core. The App screen type `JourneyRankBoard` is untouched. `RuntimeLocationProjection` is untouched.
