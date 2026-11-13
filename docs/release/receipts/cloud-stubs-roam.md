# Cloud stubs — roam settle address, passport cards, place extras

Branch `ui/cloud-stubs-roam`, parent `origin/ui/next` `bdd0a90b3b3c1abb52c767d2fe877effed428755`.

Stub text is `origin/ui/stub-ledger` `0ad3cefa5994debfd89f430f1481e58e5ed2aa89` `docs/release/stub-ledger.md`. That file is not edited. Rows 8–10 only. Journey, catalog, play-kit, tickets, `App/AppSession.swift`, and `App/AppCompositionRoot.swift` are untouched. No route was marked live. `RoamPlaceCommentClient.routeMarkedLive` stays false. The contract-failing baseline is not raised. No payment, quote, price, or cart field is sent.

This VM has no Swift compiler, so nothing was compiled. Core behavior is covered by `Tests/CoreTests/RoamCloudStubTests.swift`.

## Rows

| Row | What this branch does |
|---|---|
| #8 `RoamFinishReport.currentAddress` | `RoamFinishAddress` has no endpoint. `RoamLiveSessionView` snapshots the last confirmed POI that is still in the live `places` list when the controller reports `.finishing`, before archive clears the list. Name wins, then address. With no selection, location on is 当前位置 / Current location and location off is 尚未开启定位 / Location is off. Unknown, including a settle that never snapshotted a place, is `—`. Language follows `AppLanguage.interfaceIsChinese`. |
| #9 `RoamHomePassportView.collectionObjectDestination` | `RoamBrowserView.passportView` passes `{ AnyView(SessionObjectCardsView()) }`, the same screen `AccountView` already opens. No new cards screen. |
| #10 `RoamPlaceExtrasBinding` | `RoamPlaceExtrasProduction` is the roam-tab `\.roamPlaceExtrasProvider`. City facts come from the existing readers: `RoamSessionReader.roamNodeDetail` (`RoamService` `api/city/nodes/{id}`, the same call `CityPlayerValueNodeRuntime.detail()` makes) and `SearchMapSessionReader.cityNode` (`SearchMapService`). `CityPlayerValueNodeRuntime` itself needs a per-POI grant that is not on `AppSession`, and this branch does not add one. Merchant facts come from `roamMerchantDetail` (`api/merchant/public-detail`). Reviews are `api/comment/list` and `api/comment/add` with owner type 4, only when `showsRoute` already admits those paths. Publish mints one request id per draft. An unknown outcome, including a transport failure after the request is built and a 401, stays locked on that id in `RoamPlaceReviewLockStore`. A different draft does not send. A known reject or a request that was not built clears the lock. 401 also calls the existing `expireIfMatching`. |

Decoded city-node models do not carry `quotesJson`, `photoCredit`, `templateDesc`, `photoRequired`, or `badgeCode`. Quotes stay empty, photo credit stays nil, and the game detail stays nil. The quiz step is included only when `validationMethod == 3`. `completed` comes only from `RoamNodeDetail`. Charge type is omitted. No new decode fields were added.

## Checks

`python3 tools/generate_project.py` registered the new Swift files. Before push, `python3 tools/check_design_lint.py` passed (1545 App Swift files) and `python3 tools/check_scaffold.py` passed, including the AppSession ratchet, privacy, release config, page route table, and project equivalence. No Swift compiler is on this VM, so the new files were not compiled.
