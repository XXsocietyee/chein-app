# cursor/cov2-merchant-coop-a

Base `origin/ui/combined-r7` `0e1cf578a0e710803d49e6bc1151a53b4a8dfe24` (`Integrate Cursor round 4`). Tip was still that commit after fetch. No rebase. Branch `cursor/cov2-merchant-coop-a`. No pull request. `docs/mp-contract-coverage.md` global totals were not edited. The checker, `AppSession.swift`, `project.pbxproj`, and `tools/current_ci_manifest.json` were not edited. No `swiftc`. This note does not claim a JavaScript or Swift parse.

Mini-program: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`. Counts below are from `tools/check_mp_contract_coverage.py` on that tree plus this branch's `Core/` and `Tests/CoreTests/`.

## Split

Merchant-coop set: MP path starts with `pages/merchant/` or `pages/coop/`. 175 rows, sorted by the full locator `pages/.../file.js:line`. This half is the first 88. `pages/merchant/utils/` is lane b (those four locators sort after `pages/merchant/decor/`). Not `app.js`. Not `api/creativesquare/list` (none in this half).

The first pass on this branch dropped `components/` as well as `utils/` and covered 83 rows. That drop was wrong for `pages/merchant/components/`. Those five locators sort before `pages/merchant/decor/` and are in this 88. This note covers them. `pages/merchant/utils/` stays out.

| | locator |
|---|---|
| last row in this lane | `pages/merchant/decor/ai-npc/index.js:314` |
| first row left for lane b | `pages/merchant/decor/coop-setting/index.js:117` |

## Counts for this half

| | before any of this branch | after the 83-row pass | after these five |
|---|---|---|---|
| rows | 88 | 88 | 88 |
| matched (symbol and test) | 1 | 15 | 15 |
| missing endpoint | 8 | 7 | 7 |
| missing test | 87 | 73 | 73 |

The five component rows were already inside the 88. The 83-row pass had not touched them, so its "before" column above is the 88 with only that pass applied, not a set that excludes them. The one row that already had both a symbol and a test, `pages/merchant/apply/index.js:451` (`api/category/list`), was left as it was.

The one row that already had both a symbol and a test, `pages/merchant/apply/index.js:451` (`api/category/list`), was left as it was.

Endpoints added in the 83-row pass: 1. `api/merchant/recruit-routes` on `MerchantCoopCoverageA.recruitRoutesPath`. POST, no page header, so the builder uses `application/x-www-form-urlencoded;` and `pageNum` then `pageSize`. It returns a request and does not send. The component pass added one more path, `api/fe/reference-settlement/merchant/export`, recorded in the section below. The checker does not attach it to the row.

Test functions added: 16, in `Tests/CoreTests/MerchantCoopCoverageATests.swift`. The checker newly records 14 owned rows (the two `api/topic/list` calls share one recorded function name, the alphabetically first of the two functions that quote that shape).

| MP file:line | method | path | fields the checker already had | recorded test |
|---|---|---|---|---|
| `pages/coop/invite/index.js:472` | POST | `api/topic/list` | is_my, scope, invite_target, pageNum, pageSize | `testCoopInviteSupplyTopicTypePinsIsMyScopeInviteTargetPageNumAndPageSize` |
| `pages/coop/invite/index.js:560` | POST | `api/topic/list` | same | same |
| `pages/coop/invite/index.js:603` | GET | `api/coop/supply-stations` | topicId, merchantMemberId | `testSupplyStationsPinsTopicIdAndMerchantMemberId` |
| `pages/coop/nearby/index.js:323` | POST | `api/merchant/nearby` | longitude, latitude, radius, limit | `testNearbyMerchantsPinsLongitudeLatitudeRadiusAndLimit` |
| `pages/merchant/bundle-reservations/index.js:92` | GET | `api/free-explore/bundle/merchant/reservations` | from, to | `testBundleReservationsPinsFromAndTo` |
| `pages/merchant/bundle-reservations/index.js:122` | POST | `api/free-explore/bundle/merchant/reservation/{}/no-show` | (none) | `testBundleNoShowPinsPostEmptyObject` |
| `pages/merchant/citynode/create/index.js:396` | POST | `api/merchant/city-node/save` | templateId, lat, lng, radius, name, address | `testCityNodeSavePinsTemplateIdLatLngRadiusNameAndAddress` |
| `pages/merchant/citynode/index.js:317` | POST | `api/merchant/city-node/claim` | poiId | `testCityNodeClaimPinsPoiId` |
| `pages/merchant/citynode/index.js:359` | POST | `api/merchant/city-node/claim/cancel` | poiId | `testCityNodeClaimCancelPinsPoiId` |
| `pages/merchant/citynode/index.js:404` | POST | `api/merchant/city-node/poster-code` | poiId | `testCityNodePosterCodePinsPoiId` |
| `pages/merchant/citynode/index.js:482` | POST | `api/merchant/city-node/offline` | poiId, status | `testCityNodeOfflinePinsPoiIdAndStatus` |
| `pages/merchant/citynode/index.js:516` | POST | `api/verify/citynode/redeem` | code | `testCityNodeRedeemPinsCode` |
| `pages/merchant/citynode/index.js:550` | POST | `api/verify/citynode/receipt` | code | `testCityNodeReceiptPinsCode` |
| `pages/merchant/coop-center/index.js:173` | POST | `api/merchant/recruit-routes` | pageNum, pageSize | `testRecruitRoutesPinsPageNumAndPageSize` |

`testCoopInviteTopicListPinsIsMyScopeInviteTargetPageNumAndPageSize` quotes the same topic-list shape. The checker keeps the alphabetically first match.

Two rows outside this set also match that topic-list function, because their field lists are a subset (`is_my`, `scope`, `pageNum`, `pageSize`) and the checker does not require the test to be exclusive: `subpackageMember/components/cy/coop-invite-sheet/index.js:141` and `subpackageMember/utils/coop-publisher-access.js:16`. No endpoint was added for them.

## Five component rows

These five were skipped in the first pass. Each missing test now has a function in `MerchantCoopCoverageATests.swift` that quotes the path, the method, and the literal field names. The checker still records every one of them as missing a test: `fields` is unset (`JSON.stringify`, no `data`, or a function call), and a test is recorded only when that list is present. No payout, refund, or withdrawal sender was added. None of these five send.

| MP file:line | what was added |
|---|---|
| `pages/merchant/components/cy/club-pool-cards/index.js:29` | No new path. `CoopFlowRead.pool` is already `api/coop/pool/list`. `testClubPoolCardsPinsPostEmptyObject` quotes `POST` and that path. The page body is `JSON.stringify({})`, so there are no field names. The test asserts the existing body is an empty object and does not send. |
| `pages/merchant/components/cy/fe-reference-range/index.js:34` | One new path: `MerchantCoopCoverageA.referenceSettlementMerchantExportPath` = `api/fe/reference-settlement/merchant/export`. GET. Optional query `from` and `to`, included only for `YYYY-MM-DD`, swapped when reversed, matching `rangeQuery`. The builder returns a request and does not send. The same call's payer branch is the existing literal `api/fe/reference-settlement/payer/export` on `ClubFEReferenceExportClient`; that string was not copied. `testReferenceSettlementMerchantExportPinsGetFromAndTo` quotes `GET`, the merchant export path, the payer export path, and `from` / `to`. The checker still has no symbol for this row: the page `url` is a ternary plus `'/export'`, so it keeps no path. |
| `pages/merchant/components/merchant-claim-sheet/index.js:37` | No new path. `MerchantOpsWp03Catalog.claimsStatus` is already `api/merchant/claims/status`. `testMerchantClaimSheetStatusPinsGet` quotes `GET` and that path. The call has no `data`, so there are no field names. It does not send. |
| `pages/merchant/components/merchant-claim-sheet/index.js:78` | No new path. `PlayerContentMPContract.merchantListPath` is already `api/merchant/list`. `testMerchantClaimSheetSearchPinsPostName` calls `searchMerchantList` with `name` and no `categoryID`, and quotes `POST`, that path, and `name`. The page body is `JSON.stringify({ name })` with `Content-Type: application/json`. The test does not send. |
| `pages/merchant/components/merchant-claim-sheet/index.js:125` | No new path. `MerchantRound4Client.submitClaim` is already `api/merchant/claims/submit`. `testMerchantClaimSheetSubmitQuotesPostFields` quotes `POST`, that path, and the object keys in `buildSubmitBody`: `merchantId`, `requestId`, `contactName`, `contactPhone`, `statement`, `proofs`, `proofType`, `assetId`. The call itself is `JSON.stringify(claim.buildSubmitBody(form))`, so the checker did not keep those names. The test builds that JSON and does not send it. |

## Still missing in this half

Missing endpoint, 7. The reference-settlement export row is the seventh: a Core literal was added, and the checker still keeps no path for that call. No path was invented for a call that only forwards `url`.

| MP file:line | why the checker still has no symbol |
|---|---|
| `pages/coop/list/index.js:391` | `url` is a ternary of `/api/merchant/chapter-application/owner-mine` and `/api/merchant/chapter-application/mine`. The checker keeps no single path. Both literals already exist. |
| `pages/coop/settlement-detail/index.js:232` | `url` is a ternary of `/api/club/settlement/summary`, `/api/coop/finance`, and `/api/coop/mybiz`. The checker keeps no single path. |
| `pages/merchant/aftercare/detail/index.js:105` | `url` is a ternary of two template URLs (`manual-case-detail`, `detail`). The checker keeps no single path. |
| `pages/merchant/aftercare/detail/index.js:285` | Path text is `api/merchant/aftercare/respond`, but the query template makes the row templated, and the normalized key has no `{}`. The exact literal already in Core is not consulted. |
| `pages/merchant/aftercare/index.js:115` | Same for `api/merchant/aftercare/list` (`?bucket=` / `pageNum` / `pageSize` in the template). Exact literal already in Core. |
| `pages/merchant/components/cy/fe-reference-range/index.js:34` | `url` is `(kind === 'payer' ? payer : merchant) + '/export'`. The checker keeps no single path. The merchant export literal is now in Core. The payer export literal was already there. |
| `pages/merchant/decor/ai-npc/index.js:272` | `_request(url, data)` forwards `url`. No path invented. |

Missing test, 73. All 73 are rows whose field list the checker left unset (not a closed object literal). A pinning test is recorded only when that list is present, so these stay missing. That includes `JSON.stringify(...)`, calls with no `data` object, the seven rows above, and the five component rows. This lane did not fill in a field list for them. The five component tests quote the path, the method, and the literal field names anyway.

`testClubSettlementSummaryStaysPostClubId` and `testPoolWithdrawAndRefundRetryStayUnsent` quote the settlement, pool-withdraw, and refund-retry paths. Those three rows stay missing because the checker did not keep a closed field list (settlement also keeps no single path).

## Switches

- `ReleaseMoneyWriteSwitch.payoutEnabled`, `withdrawalEnabled`, and `refundEnabled` are false when `testDerivation` is nil. The test sets that to nil and does not install a derivation.
- Default `CoopFlowService.perform(.withdraw)` throws `CoopFlowFailure.disabled` and the transport stays empty.
- `api/coop/deposit/refund/retry` is still only the existing path constant. No sender was added.
- Aftercare respond was not given a new sender. Its existing permit stays off.
- Club settlement summary stays `POST`. Body is `{clubId}` unless `personal` is set, and `MerchantSettlementDetailLink` sets that only when `personal` is `1`. It was not changed to GET.
- This half has no `api/im/read` row. Neither mark-read switch was opened.
