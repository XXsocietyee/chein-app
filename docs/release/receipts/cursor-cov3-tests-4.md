# cursor/cov3-tests-4

Branch cut from `6afe54b4acee8786a9f3f3cbe8cd85d90be1e35a` and left there. That commit was the tip of `ui/combined-r7` when this branch was created. No rebase. `main`, `master`, `ui/main`, and `ui/combined-*` were not pushed.

Mini-program: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`. Counts are from `tools/check_mp_contract_coverage.py` (`collect`) on that tree plus this branch's `Core/` and `Tests/CoreTests/`. The checker does not parse JavaScript. It was not edited. `docs/mp-contract-coverage.md` was not edited. `AppSession.swift`, `AppCompositionRoot.swift`, and `project.pbxproj` were not edited. No `swiftc`. No new endpoint.

## Checker

| | before | after |
|---|---:|---:|
| rows | 1038 | 1038 |
| matched | 779 | 784 |
| missing endpoint | 120 | 120 |
| missing test | 256 | 251 |

`pages/merchant/` has 139 rows. Missing test was 24 and is 19.

## Rows owned

Five calls already had a Core symbol. The checker now records a test because the function quotes the path and `"POST"`. Each body is `JSON.stringify(...)`, so the checker stored no field list and did not require one. The tests still quote the literal keys from the object that call stringifies. They build an existing descriptor or quote an existing `MerchantWriteRoute` and do not send.

| MP file:line | method | path | literal fields | test |
|---|---|---|---|---|
| `pages/merchant/apply/index.js:681` | POST | `api/merchant/merchant_registration` | id, name, categoryIds, phone, address, locationLat, locationLng, businessTime, description, businessLicense, derivatives | `testApplyRegistrationPinsPostAndLiteralFields` |
| `pages/merchant/customer/detail/index.js:227` | POST | `api/merchant/crm/customers/{}/notes/hide` | noteId, expectedVersion, requestId | `testCustomerNoteHidePinsPostAndLiteralFields` |
| `pages/merchant/customer/detail/index.js:259` | POST | `api/merchant/crm/customers/{}/tags` | tagName, tagColor, requestId | `testCustomerTagAssignPinsPostAndLiteralFields` |
| `pages/merchant/customer/detail/index.js:297` | POST | `api/merchant/crm/customers/{}/tags/remove` | tagId, requestId | `testCustomerTagRemovePinsPostAndLiteralFields` |
| `pages/merchant/customer/index.js:713` | POST | `api/merchant/crm/customers/tags/batch` | customerMemberIds, tagName, requestId | `testCustomerTagBatchPinsPostAndLiteralFields` |

Batch tag does not send `tagColor`. The test asserts that key is absent.

Two more write calls stay missing-test. The checker keeps no path: `requestJson` and `_request` forward `url`. The tests quote `POST` and the literal fields of the write callers. They do not send.

| MP file:line | call | literal fields | test |
|---|---|---|---|
| `pages/merchant/reviews/index.js:624` | `requestJson`, POST. Create caller is line 426; draft keys are `pages/merchant/reviews/view-model.js:172` | rating, content, imageUrls, merchantRowId, registrationId, requestId | `testReviewCreateJsonPinsPostAndLiteralFields` |
| `pages/merchant/decor/ai-npc/index.js:272` | `_request`, POST. Write callers 533, 744, 942, 1150 | decor save: locationLat, locationLng, address. npc save: name, greeting, persona, knowledge, avatar, personality. voice enroll: voiceSample, voiceConsent, voiceRequestId, voicePreviousIntentId, voiceDuplicateChargeConsent. voice reset: none | `testAiNpcRequestPinsPostAndWriteLiteralFields` |

Report callers of `requestJson` (`reviews/index.js:616` and `:618`) are not built.

## Not taken

Merchant reads, including POST loads: `aftercare/detail/index.js:105`, `citynode/create/index.js:434`, `citynode/index.js:201`, `citynode/index.js:270`, `components/cy/fe-reference-range/index.js:34` (GET), `customer/index.js:471`, `decor/index.js:367`, `reviews/index.js:253`, `ledger/index.js:196`.

`utils/voice-enrollment-journal.js:18`, `:20`, `:76`, and `:100` are an id check named `request`, not an HTTP write.

`reviews/reply-recovery.js:67`, `reviews/reply-recovery.js:76`, and `team/index.js:715` already have quoting tests on this SHA. The checker still has no path on those calls. They were not duplicated.

`index/index.js:1387` forwards `options`. One caller is `api/registration/scan_qr_code_station`. That row was not taken.

No play, roam, or member row was pinned. `api/merchant/decor/save` stays on `ZzMerchantCoopLaneBContractTests.testDecorGallerySavePinsGallery`. `api/merchant/crm/customers/{}/notes` stays on `MerchantBusinessProductionTests.testProductionCRUDUsesExactCustomerPath`. Poster code stays on `MerchantCoopCoverageATests.testCityNodePosterCodePinsPoiId`.

## Stay off

`testPayRefundPayoutWithdrawalPaidOrdersSaveSkuReviewReportPosterAndStationStayOff` sets `ReleaseMoneyWriteSwitch.testDerivation` back to nil. Payment, payout, withdrawal, and refund are off. `PlayerContentMPContract.moneyEnabled` and `PlatformPass.moneyEnabled` stay false. `MerchantCoopLiveWrites.admits` is false for `saveSku` and review report. `api/merchant/city-node/poster-code` is not in `MerchantCityNodeWriteGate.paths`. `stationCommands` is false on `MerchantCityNPCParityGates.disabled` and `.mpFirst`. That test sends nothing.

## Tests added

Eight functions in `Tests/CoreTests/ZzZCov3MerchantWritePinTests.swift`. The class name sorts after `ZzMerchantCoopLaneBContractTests`, so a shared path keeps the test it already had.

Paths quoted were already on `MerchantWriteRoute`, `MerchantBusinessMutation.request`, or `MerchantCityNPCParityGates.mpFirstChinaEndpoints`.
