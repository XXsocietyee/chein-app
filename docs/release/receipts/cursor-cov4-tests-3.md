# cursor-cov4-tests-3

Base `ebf6c160ce73880807c07cf3cc10aa829e83d75e`. Branch `cursor/cov4-tests-3` was created from that commit and was not moved. No rebase. `main`, `master`, `ui/main`, `ui/combined-r7`, and `ui/combined-*` were not pushed.

Mini-program: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`.

Checker: `python3 -B tools/check_mp_contract_coverage.py --mp-root` that tree, against this branch's `Core/` and `Tests/CoreTests/`. The checker does not parse JavaScript. It was not edited. `docs/mp-contract-coverage.md` was not edited. Its totals were not edited. No Core path was added. `AppSession.swift`, `AppCompositionRoot.swift`, `project.pbxproj`, and `tools/current_ci_manifest.json` were not edited. `swiftc` was not run. The tests were not executed. No user-facing string was added.

## Checker

| | total | matched | missing endpoint | missing test |
|---|---:|---:|---:|---:|
| before | 1038 | 792 | 115 | 242 |
| after | 1038 | 815 | 115 | 219 |

Endpoints added: 0.

## Owned rows

35 missing-test rows. Player-content paths are `pages/topic/`, `pages/activity/`, `pages/square/`, `pages/search2/`, `pages/searchmap/`, `pages/template/`, `pages/templatedetail/`, `pages/mylike/`, `pages/index/`, `subpackageA/`, `subpackageB/`, and `subpackageP3/`. This lane also owns creativesquare and square rows outside that set. It does not own a path that contains `/club/`, and it does not own account, publish, gerenziliao, utils, components, or `app.js`.

`pages/square/` has no missing-test row on this SHA. The only missing-test `api/creativesquare/*` rows are `subpackageMember/components/cy/profile/index.js:2056`, `:2215`, and `:2238`. Those are components and were not taken.

The checker records a test on 17 owned rows. Each of those calls already had a Core symbol. The test quotes the path, the method, and the literal fields. A `JSON.stringify` body or a call with no `data` key leaves the checker's field list unread, so the pin is the path and the method. The tests still quote the literal keys.

| MP file:line | method | path | literal fields | test |
|---|---|---|---|---|
| `pages/topic/merchantinfo/merchantinfo.js:984` | POST | `api/coop/offer/circle-supply/reconfirm-current` | offerId | `Tests/CoreTests/ZzZzCov4PlayerSquarePinTests.swift:26` |
| `pages/topic/merchantinfo/merchantinfo.js:1680` | POST | `api/merchant/chapter-application/invite/revoke` | applicationId, scope | `:38` |
| `pages/topic/merchantinfo/merchantinfo.js:1778` | POST | `api/merchant/chapter-application/withdraw` | applicationId | `:54` |
| `pages/topic/merchantinfo/merchantinfo.js:1827` | POST | `api/coop/offer/enroll` | chapterId, termsMode, circleSupplyProfile, perkTemplateId, quotaTotal, familyAccepted, familyPerkText, included, extraSpendText, reserveRequired, dailyCapacity, validStart, soldOutRuleText, storefrontImg, termsAgreed, perHeadFee | `:66` |
| `pages/topic/merchantinfo/merchantinfo.js:1858` | POST | `api/merchant/chapter-node/submit` | topicId, message, chapterId, templateId, name, address, longitude, latitude, xpValue | `:78` |
| `pages/topic/merchantinfo/merchantinfo.js:2197` | POST | `api/merchant/chapter-application/owner-list` | topicId, scope | `:89` |
| `pages/topic/merchantinfo/merchantinfo.js:2625` | POST | `api/merchant/clubs` | none (`{}`) | `:100` |
| `pages/topic/merchantinfo/merchantinfo.js:2682` | POST | `api/project/players` | topicId, scope | `:109` |
| `pages/topic/merchantinfo/merchantinfo.js:2862` | POST | `api/coop/candidates/received` | scope | `:120` |
| `pages/topic/merchantinfo/merchantinfo.js:2891` | POST | `api/coop/candidates/confirm` | registrationId, scope | `:131` |
| `pages/topic/merchantinfo/merchantinfo.js:3096` | POST | `api/coop/contact` | id | `:142` |
| `pages/topic/merchantinfo/merchantinfo.js:3222` | POST | `api/circle-theme/instance/review` | topicId, scope | `:154` |
| `pages/topic/merchantinfo/merchantinfo.js:3261` | POST | `api/circle-theme/instance/configure` | topicId, candidateCodes, scope | `:165` |
| `pages/topic/merchantinfo/merchantinfo.js:3335` | POST | `api/coop/finance` | none (`{}`) | `:176` |
| `pages/topic/merchantinfo/merchantinfo.js:3887` | GET | `api/game/session/merchant/entries` | none | `:185` |
| `pages/topic/merchantinfo/merchantinfo.js:4402` | GET | `api/game/session/merchant/entries` | none | `:185` |
| `subpackageB/pages/im/chat/index.js:1160` | GET | `api/audit/{}/detail` | none | `:196` |

The other 18 stay missing-test. The call forwards `url`, the url is a ternary, or the method is only on a helper the checker does not copy. No path or method was invented. The tests quote the method and the literal fields that are written.

| MP file:line | what is quoted | test | why it stays missing-test |
|---|---|---|---|
| `pages/activity/official-inbox/index.js:110` | POST, reason, and the three URL pieces on lines 103–105 | `:205` | forwards `url` |
| `pages/index/index.js:1057` | POST, and the caller fields `pageNum`, `pageSize`, `is_recommend`, `is_my`, `status`, `sort_type` on `api/topic/list` and `api/activity/list` | `:223` | forwards `url` and `params` |
| `pages/search2/result/index.js:198` | POST | `:240` | forwards `request.url` and `request.data`. The url literals are in `utils/discover-search.js`, which this lane does not own |
| `pages/templatedetail/templatedetail.js:331` | POST, id, scope, `api/template/info`, `api/template/myinfo` | `:247` | ternary |
| `pages/topic/index/index.js:13` | no method and no path | `:260` | `recordsRequest` forwards `url`, `method`, and `data` |
| `pages/topic/merchantapply/index.js:672` | POST and the `requestData` keys, including `id` | `:270` | ternary of `api/registration/merchant/update` and `api/registration/merchant/create`. `JSON.stringify`. Registration create is not built |
| `pages/topic/merchantinfo/merchantinfo.js:646` | POST, id, scope, `api/topic/info-to-merchant`, `api/topic/info-to-user` | `:283` | ternary |
| `pages/topic/merchantinfo/merchantinfo.js:959` | POST, `api/coop/offer/quota` (`offerId`, `quotaTotal`), `api/coop/offer/sale-pause` (`offerId`, `paused`) | `:297` | forwards `url`. `JSON.stringify` |
| `pages/topic/merchantinfo/merchantinfo.js:3368` | POST, id, `api/merchant/public-detail` | `:314` | ternary. The other arm contains `/club/` and was not quoted |
| `pages/topic/pricing/index.js:227` | same public-detail quote | `:314` | same ternary |
| `pages/topic/pricing/partner/index.js:205` | same public-detail quote | `:314` | same ternary |
| `subpackageA/pages/myproject/index.js:696` | POST, id, scope, expectedPublishStatus, expectedUserStatus | `:326` | forwards `url` (`api/activity/update_publish_status` or `api/topic/update_user_status`) |
| `subpackageA/pages/myproject/index.js:1130` | POST, id, scope, `api/activity/delete`, `api/topic/delete` | `:340` | forwards `url` |
| `subpackageA/pages/video-bounty/index.js:11` | GET, `api/video-bounty/submission/mine`, `api/video-bounty/accrual/mine` | `:353` | forwards `url` |
| `subpackageA/pages/video-bounty/index.js:20` | POST, campaignKey, topicId, platform, sourceUrl, originGroupKey, note | `:365` | forwards `url`. Appeal and cancel are concatenations |
| `subpackageP3/pages/badge-wall/index/index.js:245` | `api/medal/wall`, `api/badge/wall-v2`, and the helper's POST with `{}` | `:385` | `req` does not copy the helper method onto the row |
| `subpackageP3/pages/growthcenter/index/index.js:35` | POST, `{}`, `api/growth/center`, `api/play/growth`, `api/play/my-completed` | `:396` | forwards `url` |

## Same shape, not owned

The checker pins a row when one test contains the path and the quoted method. These six calls share a path and a method with an owned row, and the checker stored no field list, so the same test now records them. They were not taken as owned rows.

| MP file:line | path | test |
|---|---|---|
| `pages/coop/invite/index.js:703` | `api/merchant/clubs` | `testMerchantClubsPinsPostAndEmptyObject` |
| `pages/coop/list/index.js:539` | `api/coop/candidates/received` | `testCandidatesReceivedPinsPostAndScope` |
| `pages/coop/list/index.js:840` | `api/coop/candidates/confirm` | `testCandidatesConfirmPinsPostAndLiteralFields` |
| `pages/coop/invite-detail/index.js:467` | `api/coop/contact` | `testCoopContactPinsPostAndId` |
| `subpackageA/components/scene-merchant-profit/index.js:126` | `api/coop/finance` | `testCoopFinancePinsPostAndEmptyObject` |
| `utils/game-session-client.js:299` | `api/game/session/merchant/entries` | `testMerchantEntriesPinsGet` |

## Not taken

Components: `pages/topic/components/cy/node-npc-form/index.js:641`, `subpackageA/components/revenue-allocations/index.js:18`, `subpackageA/components/scene-member-invite-history/index.js:61`.

Utils: `pages/topic/utils/voice-enrollment-journal.js:18`, `:20`, `:76`, `:100`.

Account, publish, gerenziliao, and `app.js` were not taken.

## Stay off

`Tests/CoreTests/ZzZzCov4PlayerSquarePinTests.swift:410` sets `ReleaseMoneyWriteSwitch.testDerivation` and `PlatformPass.orderWriteTestDerivation` back to nil. `PlayerContentMPContract.moneyEnabled` and `pricingGrantEnabled` stay false. `PlatformPass.moneyEnabled` stays false. Pricing confirm throws `PlayerContentMPContract.Refusal.pricingGrantDisabled`. Quote and registration create throw `Refusal.moneyDisabled`. `refuseRegistrationPay` throws `Adapt5PayRefusal.blocked`. Pass quote, pay, refund-apply, and gift claim throw `PlatformPassWriteRefusal.unreachable`. The transport recorded no request. Payout and withdrawal stay off. No payout or withdrawal request is built.

Chapter invite, respond, apply, and withdraw stay off (`MerchantContentWriteApproval()`). The invite-revoke and withdraw tests quote the path and the fields and do not build those calls. `MerchantCityNPCParityGates.disabled.stationCommands` and `.mpFirst.stationCommands` stay false. No `submitNode`, `auditNode`, `cancelRegistration`, `auditApplication`, or station call was added.

## Tests added

32 functions in `Tests/CoreTests/ZzZzCov4PlayerSquarePinTests.swift`.
