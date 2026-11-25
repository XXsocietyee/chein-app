# cursor-cov3-tests-2

Base `6afe54b4acee8786a9f3f3cbe8cd85d90be1e35a`. Branch `cursor/cov3-tests-2` stays on that SHA. Mini-program: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`.

`python3 -B tools/check_mp_contract_coverage.py --mp-root` on that tree, before and after this lane:

`# hengyin 25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`

`# total 1038 matched 779 missing_endpoint 120 missing_test 256`

The two runs print the same rows. `docs/mp-contract-coverage.md` was not edited. The checker was not edited.

## Slice

Missing-test rows only, and only under `pages/roam/`, the city-stamp camera, the stamp album, and official-event share. Play, member, and merchant rows were not taken. `utils/roam-share-snapshot.js:136` is a roam share snapshot (`GET api/roam/share/snapshot`, field `token`). It is not official-event share, so it was left.

| | |
|---|---|
| owned missing-test rows | 7 |
| endpoints added | 0 |
| test functions added | 7 (`Tests/CoreTests/ZCov3RoamContractPinTests.swift`) |
| rows the checker newly marks pinned | 0 |

`ZCov3RoamContractPinTests` sorts after pins that already cover a narrower field list. No other row changed its test name.

## Already pinned, not owned

These are in the slice and already have a test, so this lane does not take them.

| MP file:line | test |
|---|---|
| `subpackageP3/pages/stamp-camera/index/index.js:389` | `PlayerContentBContractPinTests.testPinsCreateAt389` |
| `subpackageP3/pages/stamp-album/index/index.js:109` | `PlayerContentBContractPinTests.testPinsListAt109` |
| `subpackageRoam/components/cy/share-card/index.js:131` | `YPlayRoamCov2PinTests.testOfficialEventShareCodeQuotesPost` |

Official-event share is the third row. `POST api/official/events/{id}/share-code`. No data fields. `OfficialEventShareCodeRoute.path` already returns the path and does not send.

## Tests

Each quote test names the path, the method literal, and the literal field names written on that call. Citations are `chengyinhub-xcx` at `25eb6a0c`.

| test | MP file:line | method | fields |
|---|---|---|---|
| `testSessionRecordsQuotesPostAndFieldsAt1801` | `pages/roam/index.js:1801` | POST | `sessionId`, `clientSessionKey`, `records` |
| `testRevealQuotesPostAndFieldsAt1830` | `pages/roam/index.js:1830` | POST | `sessionId`, `tiles`, `clientSessionKey` |
| `testCityStampCreateQuotesPostAndFieldsAt291` | `subpackageRoam/citystamp/index.js:291` | POST at line 30 | `picUrl`, `caption`, `idempotencyKey` |
| `testCityStampExchangeQuotesPostAndFieldAt300` | `subpackageRoam/citystamp/index.js:300` | POST at line 30 | `givenStampId` |
| `testStampAlbumQuotesBothListPostsAt66` | `subpackageRoam/components/cy/scene-roam-stamp-album/index.js:66` | POST | `pageNum`, `pageSize` |
| `testForwardedRoamAndCityStampCallsStayWithoutAPath` | `pages/roam/index.js:210`, `subpackageRoam/citystamp/index.js:29` | POST on the city-stamp forwarder | none |
| `testGiftClaimThrowsMoneyOffAndSendsNothing` | — | — | gate lock |

`createStamp` and `exchangeStamp` already exist on `RoamExperienceMutation`. The tests read `path` and `fields()` and do not call `execute`. `RoamPlayerExtrasService.sessionRecordsPath`, `RoamAlbumMetadataReadRoute.path`, and `RoamReceivedStampReadRoute.path` were already those strings. No path was added.

## Why the checker still says missing

The checker pins a row only when that row keeps one path and one method literal, and one test function contains the path, the quoted method, and every recorded field. These seven calls do not keep both.

Forwards `url`, so the row has no path. No path was invented.

- `pages/roam/index.js:210` — `community.request` forwards `url`, `method`, and `data`, then spreads `opts`.
- `subpackageRoam/citystamp/index.js:29` — `sendRequest` forwards `url` and `data`. The method literal is `POST`.

A spread in the data object drops the positional path and the positional `POST` before the checker keeps them. Both path strings were already in Core. The quote tests name them.

- `pages/roam/index.js:1801` — `req('/api/roam/session/records', 'POST', { sessionId, ...(clientSessionKey), records: JSON.stringify(records) })`.
- `pages/roam/index.js:1830` — `req('/api/roam/reveal', 'POST', { sessionId, tiles, ...(clientSessionKey) })`.

`req(path, fields)` does not write a method literal. The quote tests name the path, the fields, and the `POST` written by `req` at `subpackageRoam/citystamp/index.js:30`. The checker does not record that method on lines 291 and 300, so the test column stays missing. The symbol stays `RoamExperienceMutation`.

- `subpackageRoam/citystamp/index.js:291` — `api/roam/stamp/create`
- `subpackageRoam/citystamp/index.js:300` — `api/roam/stamp/exchange`

Two path literals, so the checker keeps neither. Both strings were already in Core. The quote test names them.

- `subpackageRoam/components/cy/scene-roam-stamp-album/index.js:66` — `api/roam/stamp/received` or `api/roam/stamp/list`, `POST`, fields `pageNum`, `pageSize`.

## Gates

Not edited. `PlayStageAnalyticsGate.enabled` is `false`. `JourneyLoopSource.giftClaim` still throws `JourneyRefusal.moneyOff` and sends nothing. `App/AppSession.swift` and `App/AppCompositionRoot.swift` were not edited. `Questify.xcodeproj/project.pbxproj` was not edited. No `swiftc` run. This receipt does not claim a parse.
