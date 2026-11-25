# cursor/cov4-tests-4

Branch `cursor/cov4-tests-4` cut from `ebf6c160ce73880807c07cf3cc10aa829e83d75e` and left there. Parent `465094a9fdfdec652688bdf9cd6128f73d81a0ce`. No rebase. `main`, `master`, `ui/main`, `ui/combined-r7`, `ui/combined-*`, and `ci/acceptance` were not pushed.

Mini-program: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`. Counts are from `tools/check_mp_contract_coverage.py` on that tree plus this branch's `Core/` and `Tests/CoreTests/`. The checker does not parse JavaScript. It was not edited. `docs/mp-contract-coverage.md` totals were not edited. `AppSession.swift`, `AppCompositionRoot.swift`, `project.pbxproj`, and `tools/current_ci_manifest.json` were not edited. No `swiftc`. No new endpoint. No new strings, so no string fragment.

## Checker

| | before | after |
|---|---:|---:|
| rows | 1038 | 1038 |
| matched | 792 | 834 |
| missing endpoint | 115 | 115 |
| missing test | 242 | 200 |

Endpoints added: 0.

## Tests added

32 functions in `Tests/CoreTests/ZzZzZzCov4Tests4PinTests.swift`. The class name sorts after `ZzZzCov3MemberContractPinTests`, so a path that already had a test keeps that test. 31 functions quote a path and a method. `testPayRefundPayoutWithdrawalPaidOrdersQuoteCreatePricingGiftSaveSkuReviewReportPosterAndStationStayOff` sends nothing and does not quote a method, so it pins no row.

The checker records a test only when the call has a path and a method. A `JSON.stringify(...)` body, a missing `data` key, or an empty object leaves the field list unread. Those tests still quote the keys written on the call.

| test | path | method | keys quoted |
|---|---|---|---|
| `testMapPlaceSearchPinsPostKeywordLongitudeLatitude` | `api/map/place-search` | POST | keyword, longitude, latitude |
| `testCoopCreditPinsPostMemberId` | `api/coop/credit` | POST | memberId |
| `testCoopReviewSummaryPinsPostToId` | `api/coop/review/summary` | POST | toId |
| `testCoopHandlePinsPostLiteralFields` | `api/coop/handle` | POST | id, status, message, handleReason, supplyStationId |
| `testCoopContactPinsPostId` | `api/coop/contact` | POST | id |
| `testCoopPerksListPinsPostInviteId` | `api/coop/perks/list` | POST | inviteId |
| `testCoopPerksAttachPinsPostInviteIdAndTemplateIds` | `api/coop/perks/attach` | POST | inviteId, templateIds |
| `testCoopReviewSavePinsPostLiteralFields` | `api/coop/review/save` | POST | topicId, toId, rating, comment |
| `testMerchantClubsPinsPostEmptyObject` | `api/merchant/clubs` | POST | none (`{}`) |
| `testCoopPoolReceivedPinsPostEmptyObject` | `api/coop/pool/received` | POST | none (`{}`) |
| `testCoopPoolMinePinsPostEmptyObject` | `api/coop/pool/mine` | POST | none (`{}`) |
| `testCoopCandidatesReceivedPinsPostScope` | `api/coop/candidates/received` | POST | scope |
| `testCoopPoolDeclinePinsPostApplyIdAndScope` | `api/coop/pool/decline` | POST | applyId, scope |
| `testCoopCandidatesConfirmPinsPostRegistrationIdAndScope` | `api/coop/candidates/confirm` | POST | registrationId, scope |
| `testCoopDepositStatusPinsPostInviteId` | `api/coop/deposit/status` | POST | inviteId |
| `testCityNodeListPinsPost` | `api/merchant/city-node/list` | POST | no data key |
| `testCityNodeClaimablePinsPost` | `api/merchant/city-node/claimable` | POST | no data key |
| `testCustomerListPinsPostLiteralFields` | `api/merchant/crm/customers/list` | POST | pageNum, pageSize, keyword, segment, tagId, sourceType, sourceStart, sourceEnd |
| `testAnalyticsBatchPinsPostEvents` | `api/analytics/events/batch` | POST | events |
| `testAuthorWriteReceiptPinsGetOperationAndRequestId` | `api/author-write/receipt` | GET | operation, requestId |
| `testRegistrationPayQuotesPostIdAndJsCodeAndSendsNothing` | `api/registration/pay` | POST | id, jsCode |
| `testGameSessionMerchantEntriesPinsGet` | `api/game/session/merchant/entries` | GET | no data key |
| `testGameSessionRecapExportPinsGetActivityId` | `api/game/session/recap/export` | GET | activityId |
| `testGameSessionReceiptPinsGetActivityIdAndRequestId` | `api/game/session/receipt` | GET | activityId, requestId |
| `testMarketingConsentsPinsGet` | `api/merchant/crm/marketing-consents` | GET | no data key |
| `testMapGeocodePinsPostAddressAndRegion` | `api/map/geocode` | POST | address, region |
| `testPublisherIdentityStatusPinsPostEmptyObject` | `api/publisher/identity/status` | POST | none (`{}`) |
| `testRoamShareSnapshotPinsGetToken` | `api/roam/share/snapshot` | GET | token |
| `testRoleInfoPinsPost` | `api/role/info` | POST | no data key |
| `testThemeCardPinsGetSessionId` | `api/play/theme/card` | GET | sessionId |
| `testThemeReplayPinsPostSessionId` | `api/play/theme/replay` | POST | sessionId |

`pages/coop/list/index.js:638` passes `JSON.stringify(data)` from `officialChannel.handlePayload`. That call has no literal keys. The keys in `testCoopHandlePinsPostLiteralFields` are the keys written on the other three `api/coop/handle` calls.

## Rows owned

152 missing-test rows on the base. 35 now name a test in this file. 117 stay missing-test because the checker has no path, no method, or both. No path or method was invented for those 117.

Not owned, and not listed below: a file path containing `/club/`, `pages/club/`, or `components/cy/club`; account-publish pages (`pages/publish/`, `pages/publishkit/`, `pages/gerenziliao/`, `pages/userinfo/`, `pages/address/`, `pages/addressinfo/`, `pages/shezhi/`, `pages/privacy/`, `pages/talent/`, `pages/team/`, `pages/crop/`, `pages/deregister/`, `pages/agreement/`, `pages/member/`); player-content pages (`pages/topic/`, `pages/activity/`, `pages/square/`, `pages/search2/`, `pages/searchmap/`, `pages/template/`, `pages/templatedetail/`, `pages/mylike/`, `pages/index/`, `subpackageA/`, `subpackageB/`, `subpackageP3/`); a checker path containing `/club/` or `creativesquare`; visit-config; project edit (`myproject`). `utils/publisher-identity.js` stays here because this lane owns `utils/`.

| MP file:line | method | path | checker fields | result |
|---|---|---|---|---|
| `app.js:374` | POST |  | code | still missing-test; checker has no path |
| `app.js:395` |  |  |  | still missing-test; checker has no path and no method |
| `app.js:421` |  |  |  | still missing-test; checker has no path and no method |
| `app.js:447` |  |  |  | still missing-test; checker has no path and no method |
| `components/cy/fe-reference-settlement/index.js:39` | GET |  |  | still missing-test; checker has no path |
| `components/cy/fe-reference-settlement/index.js:98` | POST |  |  | still missing-test; checker has no path |
| `components/cy/map-address-search/index.js:42` | POST | api/map/place-search | keyword, longitude, latitude | testMapPlaceSearchPinsPostKeywordLongitudeLatitude |
| `pages/coop/invite-detail/index.js:250` | POST | api/coop/credit |  | testCoopCreditPinsPostMemberId |
| `pages/coop/invite-detail/index.js:276` | POST | api/coop/review/summary |  | testCoopReviewSummaryPinsPostToId |
| `pages/coop/invite-detail/index.js:398` | POST | api/coop/handle |  | testCoopHandlePinsPostLiteralFields |
| `pages/coop/invite-detail/index.js:467` | POST | api/coop/contact |  | testCoopContactPinsPostId |
| `pages/coop/invite-detail/index.js:565` | POST | api/coop/perks/list |  | testCoopPerksListPinsPostInviteId |
| `pages/coop/invite-detail/index.js:600` | POST | api/coop/perks/attach |  | testCoopPerksAttachPinsPostInviteIdAndTemplateIds |
| `pages/coop/invite-detail/index.js:659` | POST | api/coop/review/save |  | testCoopReviewSavePinsPostLiteralFields |
| `pages/coop/invite/index.js:703` | POST | api/merchant/clubs |  | testMerchantClubsPinsPostEmptyObject |
| `pages/coop/list/index.js:391` | POST |  |  | still missing-test; checker has no path |
| `pages/coop/list/index.js:484` | POST | api/coop/pool/received |  | testCoopPoolReceivedPinsPostEmptyObject |
| `pages/coop/list/index.js:491` | POST | api/coop/pool/mine |  | testCoopPoolMinePinsPostEmptyObject |
| `pages/coop/list/index.js:539` | POST | api/coop/candidates/received |  | testCoopCandidatesReceivedPinsPostScope |
| `pages/coop/list/index.js:638` | POST | api/coop/handle |  | testCoopHandlePinsPostLiteralFields |
| `pages/coop/list/index.js:749` | POST | api/coop/pool/decline |  | testCoopPoolDeclinePinsPostApplyIdAndScope |
| `pages/coop/list/index.js:840` | POST | api/coop/candidates/confirm |  | testCoopCandidatesConfirmPinsPostRegistrationIdAndScope |
| `pages/coop/list/index.js:888` | POST | api/coop/deposit/status |  | testCoopDepositStatusPinsPostInviteId |
| `pages/coop/list/index.js:1041` | POST | api/coop/handle |  | testCoopHandlePinsPostLiteralFields |
| `pages/coop/list/index.js:1116` | POST | api/coop/handle |  | testCoopHandlePinsPostLiteralFields |
| `pages/coop/settlement-detail/index.js:232` | POST |  |  | still missing-test; checker has no path |
| `pages/merchant/aftercare/detail/index.js:105` | POST |  |  | still missing-test; checker has no path |
| `pages/merchant/citynode/create/index.js:434` | POST | api/merchant/city-node/list |  | testCityNodeListPinsPost |
| `pages/merchant/citynode/index.js:201` | POST | api/merchant/city-node/list |  | testCityNodeListPinsPost |
| `pages/merchant/citynode/index.js:270` | POST | api/merchant/city-node/claimable |  | testCityNodeClaimablePinsPost |
| `pages/merchant/components/cy/fe-reference-range/index.js:34` | GET |  |  | still missing-test; checker has no path |
| `pages/merchant/customer/index.js:471` | POST | api/merchant/crm/customers/list |  | testCustomerListPinsPostLiteralFields |
| `pages/merchant/decor/ai-npc/index.js:272` | POST |  |  | still missing-test; checker has no path |
| `pages/merchant/decor/index.js:367` | POST |  |  | still missing-test; checker has no path |
| `pages/merchant/index/index.js:1387` |  |  |  | still missing-test; checker has no path and no method |
| `pages/merchant/ledger/index.js:196` | POST |  |  | still missing-test; checker has no path |
| `pages/merchant/reviews/index.js:253` | POST |  |  | still missing-test; checker has no path |
| `pages/merchant/reviews/index.js:624` | POST |  |  | still missing-test; checker has no path |
| `pages/merchant/reviews/reply-recovery.js:67` |  |  |  | still missing-test; checker has no path and no method |
| `pages/merchant/reviews/reply-recovery.js:76` |  |  |  | still missing-test; checker has no path and no method |
| `pages/merchant/team/index.js:715` | POST |  |  | still missing-test; checker has no path |
| `pages/merchant/utils/voice-enrollment-journal.js:18` |  |  |  | still missing-test; checker has no path and no method |
| `pages/merchant/utils/voice-enrollment-journal.js:20` |  |  |  | still missing-test; checker has no path and no method |
| `pages/merchant/utils/voice-enrollment-journal.js:76` |  |  |  | still missing-test; checker has no path and no method |
| `pages/merchant/utils/voice-enrollment-journal.js:100` |  |  |  | still missing-test; checker has no path and no method |
| `pages/play/circle/index.js:12` |  |  |  | still missing-test; checker has no path and no method |
| `pages/play/components/advanced-game/index.js:89` |  |  |  | still missing-test; checker has no path and no method |
| `pages/play/index.js:336` |  |  |  | still missing-test; checker has no path and no method |
| `pages/play/index.js:420` |  | api/play/orient/session/current |  | still missing-test; checker has no method |
| `pages/play/index.js:421` |  | api/play/orient/session/prepare |  | still missing-test; checker has no method |
| `pages/play/index.js:422` |  | api/play/orient/session/start |  | still missing-test; checker has no method |
| `pages/play/index.js:423` |  | api/play/orient/session/abandon |  | still missing-test; checker has no method |
| `pages/play/index.js:424` |  | api/play/orient/session/receipt |  | still missing-test; checker has no method |
| `pages/play/index.js:427` |  | api/play/orient/session/task/{}/result |  | still missing-test; checker has no method |
| `pages/play/index.js:429` |  | api/orient/scoring/session/{} |  | still missing-test; checker has no method |
| `pages/play/merchant/index.js:16` | POST |  |  | still missing-test; checker has no path |
| `pages/play/utils/theme-backpack.js:372` | POST |  |  | still missing-test; checker has no path |
| `pages/play/utils/theme-backpack.js:503` | POST |  |  | still missing-test; checker has no path |
| `pages/play/utils/theme-command.js:11` |  |  |  | still missing-test; checker has no path and no method |
| `pages/roam/index.js:210` |  |  |  | still missing-test; checker has no path and no method |
| `pages/roam/index.js:1801` |  |  |  | still missing-test; checker has no path and no method |
| `pages/roam/index.js:1830` |  |  |  | still missing-test; checker has no path and no method |
| `subpackageJourney/utils/journey-api.js:11` |  |  |  | still missing-test; checker has no path and no method |
| `subpackageMember/components/cy/npc-chat/index.js:129` | POST |  | requestId, bizId, message | still missing-test; checker has no path |
| `subpackageMember/components/cy/profile/index.js:83` | POST |  |  | still missing-test; checker has no path |
| `subpackageMember/components/cy/profile/index.js:734` |  |  |  | still missing-test; checker has no path and no method |
| `subpackageMember/components/cy/profile/index.js:1095` |  | api/merchant/access/me |  | still missing-test; checker has no method |
| `subpackageMember/components/cy/profile/index.js:1126` |  | api/merchant/info |  | still missing-test; checker has no method |
| `subpackageMember/components/cy/profile/index.js:1277` |  | api/common/banner | showType | still missing-test; checker has no method |
| `subpackageMember/components/cy/profile/index.js:1300` |  |  | member_id | still missing-test; checker has no path and no method |
| `subpackageMember/components/cy/profile/index.js:1395` |  | api/play/growth |  | still missing-test; checker has no method |
| `subpackageMember/components/cy/profile/index.js:1395` |  | api/growth/center |  | still missing-test; checker has no method |
| `subpackageMember/components/cy/profile/index.js:1440` |  | api/play/my-completed |  | still missing-test; checker has no method |
| `subpackageMember/components/cy/profile/index.js:1459` |  | api/medal/wall |  | still missing-test; checker has no method |
| `subpackageMember/components/cy/profile/index.js:1491` |  | api/user/points/statistics |  | still missing-test; checker has no method |
| `subpackageMember/components/cy/profile/index.js:1492` |  | api/growth/leaderboard | metric, period, limit | still missing-test; checker has no method |
| `subpackageMember/components/cy/profile/index.js:1541` |  | api/registration/list | pageNum, pageSize, owner_type, status, is_online | still missing-test; checker has no method |
| `subpackageMember/components/cy/profile/index.js:1592` |  | api/merchant/chapter-application/mine |  | still missing-test; checker has no method |
| `subpackageMember/components/cy/profile/index.js:1620` |  | api/topic/list | is_my, pageNum, pageSize | still missing-test; checker has no method |
| `subpackageMember/components/cy/profile/index.js:1697` |  | api/points/result_list |  | still missing-test; checker has no method |
| `subpackageMember/components/cy/profile/index.js:1758` |  | api/user/follow/action | follow_member_id, follow | still missing-test; checker has no method |
| `subpackageMember/components/cy/profile/index.js:2156` |  | api/publish/home |  | still missing-test; checker has no method |
| `subpackageMember/components/cy/profile/index.js:2183` |  | api/user/balance/list | pageNum, pageSize | still missing-test; checker has no method |
| `subpackageMember/components/cy/scene-member-order-detail/index.js:658` | POST |  | id | still missing-test; checker has no path |
| `subpackageMember/components/cy/scene-member-order-history/index.js:425` | POST |  | id | still missing-test; checker has no path |
| `subpackageMember/components/cy/scene-route-content/index.js:260` |  |  |  | still missing-test; checker has no path and no method |
| `subpackageMember/components/cy/scene-route-content/index.js:521` | POST |  |  | still missing-test; checker has no path |
| `subpackageMember/components/scene-member-participation-detail/index.js:149` |  |  |  | still missing-test; checker has no path and no method |
| `subpackageMember/components/scene-member-participation-detail/index.js:636` | POST |  | id | still missing-test; checker has no path |
| `subpackageMember/free-explore/index.js:83` |  |  |  | still missing-test; checker has no path and no method |
| `subpackageMember/market/membership/index.js:17` |  |  |  | still missing-test; checker has no path and no method |
| `subpackageMember/market/membership/index.js:27` | GET |  |  | still missing-test; checker has no path |
| `subpackageMember/market/pass-order/index.js:13` |  |  |  | still missing-test; checker has no path and no method |
| `subpackageMember/market/passes/index.js:19` | GET |  |  | still missing-test; checker has no path |
| `subpackageMember/orient-score/index.js:91` | GET |  |  | still missing-test; checker has no path |
| `subpackageMember/orient-score/index.js:117` | GET |  |  | still missing-test; checker has no path |
| `subpackageMember/orient-score/index.js:155` | GET |  | kind, sessionId, idempotencyKey | still missing-test; checker has no path |
| `subpackageMember/orient-score/index.js:205` | POST |  | kind | still missing-test; checker has no path |
| `subpackageMember/orient-score/index.js:240` | POST |  | sessionId, idempotencyKey | still missing-test; checker has no path |
| `subpackageMember/orient-score/index.js:313` | POST |  |  | still missing-test; checker has no path |
| `subpackageMember/utils/user-invoice.js:81` |  | api/invoice/titles |  | still missing-test; checker has no method |
| `subpackageMember/utils/user-invoice.js:82` |  | api/invoice/titles/save |  | still missing-test; checker has no method |
| `subpackageMember/utils/user-invoice.js:83` |  | api/invoice/titles/save-request |  | still missing-test; checker has no method |
| `subpackageMember/utils/user-invoice.js:84` |  | api/invoice/titles/request |  | still missing-test; checker has no method |
| `subpackageMember/utils/user-invoice.js:85` |  | api/invoice/titles/delete |  | still missing-test; checker has no method |
| `subpackageMember/utils/user-invoice.js:86` |  | api/invoice/orders/eligible |  | still missing-test; checker has no method |
| `subpackageMember/utils/user-invoice.js:87` |  | api/invoice/apply |  | still missing-test; checker has no method |
| `subpackageMember/utils/user-invoice.js:88` |  | api/invoice/list |  | still missing-test; checker has no method |
| `subpackageMember/utils/user-invoice.js:89` |  | api/invoice/detail |  | still missing-test; checker has no method |
| `subpackageMember/utils/user-invoice.js:90` |  | api/invoice/request |  | still missing-test; checker has no method |
| `subpackageMember/utils/user-invoice.js:91` |  | api/invoice/cancel |  | still missing-test; checker has no method |
| `subpackageRoam/citystamp/index.js:29` | POST |  |  | still missing-test; checker has no path |
| `subpackageRoam/citystamp/index.js:291` |  | api/roam/stamp/create | picUrl, caption, idempotencyKey | still missing-test; checker has no method |
| `subpackageRoam/citystamp/index.js:300` |  | api/roam/stamp/exchange | givenStampId | still missing-test; checker has no method |
| `subpackageRoam/components/cy/scene-roam-stamp-album/index.js:66` | POST |  | pageNum, pageSize | still missing-test; checker has no path |
| `subpackageTools/utils/features/exploration-export.js:26` | POST |  |  | still missing-test; checker has no path |
| `utils/analytics.js:251` | POST | api/analytics/events/batch | events | testAnalyticsBatchPinsPostEvents |
| `utils/author-write-recovery.js:31` | GET | api/author-write/receipt | operation, requestId | testAuthorWriteReceiptPinsGetOperationAndRequestId |
| `utils/checkout/selfplay-xpay-pay.js:30` | POST | api/registration/pay | id, jsCode | testRegistrationPayQuotesPostIdAndJsCodeAndSendsNothing |
| `utils/club-post-repost.js:92` | POST |  |  | still missing-test; checker has no path |
| `utils/community-post-api.js:84` |  |  |  | still missing-test; checker has no path and no method |
| `utils/community-post-api.js:297` |  |  |  | still missing-test; checker has no path and no method |
| `utils/features/capsule-client.js:34` |  |  |  | still missing-test; checker has no path and no method |
| `utils/features/exploration-goals.js:63` |  |  |  | still missing-test; checker has no path and no method |
| `utils/game-session-client.js:299` | GET | api/game/session/merchant/entries |  | testGameSessionMerchantEntriesPinsGet |
| `utils/game-session-client.js:337` | GET | api/game/session/recap/export | activityId | testGameSessionRecapExportPinsGetActivityId |
| `utils/game-session-client.js:457` | GET |  | activityId | still missing-test; checker has no path |
| `utils/game-session-client.js:515` | GET | api/game/session/receipt | activityId, requestId | testGameSessionReceiptPinsGetActivityIdAndRequestId |
| `utils/marketing-consent-entry.js:58` | GET | api/merchant/crm/marketing-consents |  | testMarketingConsentsPinsGet |
| `utils/open-address.js:66` | POST | api/map/geocode | address, region | testMapGeocodePinsPostAddressAndRegion |
| `utils/post-feed-actions.js:53` | POST |  |  | still missing-test; checker has no path |
| `utils/publisher-identity.js:89` | POST | api/publisher/identity/status |  | testPublisherIdentityStatusPinsPostEmptyObject |
| `utils/roam-passport-read.js:55` | GET |  |  | still missing-test; checker has no path |
| `utils/roam-place-detail.js:9` | GET |  |  | still missing-test; checker has no path |
| `utils/roam-place-media.js:52` | GET |  |  | still missing-test; checker has no path |
| `utils/roam-presence-privacy.js:7` |  | api/roam/presence-visibility |  | still missing-test; checker has no method |
| `utils/roam-share-snapshot.js:22` |  |  |  | still missing-test; checker has no path and no method |
| `utils/roam-share-snapshot.js:136` | GET | api/roam/share/snapshot | token | testRoamShareSnapshotPinsGetToken |
| `utils/roleGuard.js:83` | POST | api/role/info |  | testRoleInfoPinsPost |
| `utils/team-event-command.js:90` |  | api/team/command/query |  | still missing-test; checker has no method |
| `utils/team-event-command.js:91` |  | api/team/command/cancel |  | still missing-test; checker has no method |
| `utils/team-event-command.js:92` |  | api/team/command |  | still missing-test; checker has no method |
| `utils/team-event-command.js:94` |  | api/official/signup-command/query |  | still missing-test; checker has no method |
| `utils/team-event-command.js:95` |  | api/official/signup-command/cancel |  | still missing-test; checker has no method |
| `utils/team-event-command.js:96` |  | api/official/signup-command |  | still missing-test; checker has no method |
| `utils/team-event-command.js:98` |  | api/official/command/query |  | still missing-test; checker has no method |
| `utils/team-event-command.js:99` |  | api/official/command/cancel |  | still missing-test; checker has no method |
| `utils/team-event-command.js:100` |  | api/official/command |  | still missing-test; checker has no method |
| `utils/theme-records.js:80` | GET | api/play/theme/card |  | testThemeCardPinsGetSessionId |
| `utils/theme-records.js:132` |  |  |  | still missing-test; checker has no path and no method |
| `utils/theme-records.js:152` | POST | api/play/theme/replay |  | testThemeReplayPinsPostSessionId |
| `utils/ui-state-request.js:4` |  |  |  | still missing-test; checker has no path and no method |

## Same shape outside this lane

The checker pins every call with the same path and method when the field list is unread. These seven rows are not owned. On this branch they name the test above. The class sorts last, so a test added for that row on its own lane replaces this name.

| MP file:line | method | path | test on this branch |
|---|---|---|---|
| `pages/shezhi/components/marketing-consent/index.js:30` | GET | `api/merchant/crm/marketing-consents` | `testMarketingConsentsPinsGet` |
| `pages/topic/merchantinfo/merchantinfo.js:2625` | POST | `api/merchant/clubs` | `testMerchantClubsPinsPostEmptyObject` |
| `pages/topic/merchantinfo/merchantinfo.js:2862` | POST | `api/coop/candidates/received` | `testCoopCandidatesReceivedPinsPostScope` |
| `pages/topic/merchantinfo/merchantinfo.js:2891` | POST | `api/coop/candidates/confirm` | `testCoopCandidatesConfirmPinsPostRegistrationIdAndScope` |
| `pages/topic/merchantinfo/merchantinfo.js:3096` | POST | `api/coop/contact` | `testCoopContactPinsPostId` |
| `pages/topic/merchantinfo/merchantinfo.js:3887` | GET | `api/game/session/merchant/entries` | `testGameSessionMerchantEntriesPinsGet` |
| `pages/topic/merchantinfo/merchantinfo.js:4402` | GET | `api/game/session/merchant/entries` | `testGameSessionMerchantEntriesPinsGet` |

`subpackageMember/components/cy/scene-member-order-detail/index.js:698` and `scene-member-order-history/index.js:462` stay on `ZzSubpackageMemberRestPinTests.testOrderDetailRegistrationPay`. That test quotes `id` and not `jsCode`.

## Money

`testRegistrationPayQuotesPostIdAndJsCodeAndSendsNothing` quotes `POST`, `id`, and `jsCode` for `utils/checkout/selfplay-xpay-pay.js:30`. `ReleaseMoneyWriteSwitch.testDerivation` is nil. `paymentEnabled` is false. `blocks("/api/registration/pay")` is true. `Adapt5HighRiskWriteSupplement.refuseRegistrationPay` throws `Adapt5PayRefusal.blocked` and does not build a request.

The stay-off test sets the same switch back to nil. Payment, payout, withdrawal, and refund are off. `PlayerContentMPContract.moneyEnabled` and `pricingGrantEnabled` are false. `registrationQuote`, `registrationCreate`, and `pricingConfirm` throw. `PlatformPass.moneyEnabled` is false. `quote`, `payProductOrder`, `payPassOrder`, `claim`, and `refundApplyPassOrder` throw `PlatformPassWriteRefusal.unreachable`. The transport recorded no request. `MerchantCoopLiveWrites.admits` is false for `saveSku` and review report. `api/merchant/city-node/poster-code` is not in `MerchantCityNodeWriteGate.paths`. `stationCommands` is false on `MerchantCityNPCParityGates.disabled` and `.mpFirst`.
