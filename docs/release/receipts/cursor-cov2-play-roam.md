# cursor-cov2-play-roam

Base `0e1cf578a0e710803d49e6bc1151a53b4a8dfe24` (`origin/ui/combined-r7`, "Integrate Cursor round 4"). Branch `cursor/cov2-play-roam`. No pull request. The tip was still that commit. No rebase.

Mini-program: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`.

Owned prefixes: `pages/play/`, `pages/roam/`, `subpackageRoam/`, `subpackageJourney/`, `subpackageTools/`. `utils/`, `app.js`, and `components/` are not taken. `docs/mp-contract-coverage.md` is not edited. The totals below are the checker run, not a hand edit of that file.

`YPlayRoamCov2PinTests` sorts after pins that already cover a narrower field list, so those rows keep their existing test name.

## Counts

| count | value |
|---|---|
| owned rows | 145 |
| rows left alone (Core symbol and test already present) | 29 |
| Core paths added | 1 (`OfficialEventShareCodeRoute.path`) |
| test functions added | 90 |
| quote tests | 89, covering 107 rows |
| gate lock | 1 |
| owned rows the checker newly marks pinned | 30 |
| owned rows still missing an endpoint | 14 |
| owned rows still missing a test | 86 |
| checker total | 1038 |
| checker matched | 203 |
| checker missing_endpoint | 129 |
| checker missing_test | 834 |

Before this change the same checker run was total 1038, matched 167, missing_endpoint 130, missing_test 870. Matched rises by 36 and missing_test falls by 36. missing_endpoint falls by 1: share-code now has a symbol and still has no pinning test, because the call has no `data` key and the field list stays unknown. Of the 36 new pins, 30 are owned. Six are the same path, method, and field list on pages outside this slice:

- `pages/index/index.js:1132` `POST api/topic/list` `pageNum`, `pageSize`, `sort_type`
- `pages/square/detail/index.js:1146` `POST api/comment/list` `owner_type`, `owner_id`, `pageNum`, `pageSize`
- `subpackageMember/components/cy/scene-member-order-detail/index.js:835` `POST api/registration/explore-completion` `id`
- `subpackageMember/components/cy/scene-roam-poi-detail/index.js:622` `POST api/comment/list` `owner_type`, `owner_id`, `pageNum`, `pageSize`
- `subpackageMember/signup/index.js:383` `POST api/verify/dyncode/issue` `registrationId` (the play call also quotes `seatNo`)
- `subpackageP3/pages/stamp-album/index/index.js:109` `POST api/roam/stamp/list` `pageNum`, `pageSize`

## Endpoint added

`POST api/official/events/{id}/share-code` (`subpackageRoam/components/cy/share-card/index.js:131`). No data fields. `OfficialEventShareCodeRoute.path` returns the path and does not send. The checker records `OfficialEventShareCodeRoute.path`. The test quotes the path and `"POST"`. The field list stays unknown, so the test column stays missing.

## Still missing an endpoint

These calls do not keep one path literal, so a new Core string would not bind. No path was invented.

Forwards `url`:

- `pages/play/circle/index.js:12`
- `pages/play/components/advanced-game/index.js:89`
- `pages/play/index.js:336`
- `pages/play/merchant/index.js:16` (method is the literal `POST`; `url` is forwarded)
- `pages/play/utils/theme-command.js:11` (`options.url`)
- `pages/roam/index.js:210`
- `subpackageJourney/utils/journey-api.js:11`
- `subpackageRoam/citystamp/index.js:29` (method is the literal `POST`; `url` is forwarded)
- `subpackageTools/utils/features/exploration-export.js:26` (`url` is forwarded). `send` is called with `/api/personal-exploration-export/prepare` and `/api/personal-exploration-export/page`. Those strings already exist on `RoamPassportPrivateToolsReading`. They are not this row.

Two literals, and the checker keeps neither. Both strings were already in Core:

- `pages/play/utils/theme-backpack.js:372` `api/game/session/shared/preview` or `api/play/theme/gameplay-preview`
- `pages/play/utils/theme-backpack.js:503` `api/game/session/command` or `api/play/theme/gameplay-action`
- `subpackageRoam/components/cy/scene-roam-stamp-album/index.js:66` `api/roam/stamp/received` or `api/roam/stamp/list`

A spread in the data object drops the path literal before the checker keeps it. The path string was already in Core. The quote test names it:

- `pages/roam/index.js:1801` `POST api/roam/session/records` (`sessionId`, `clientSessionKey`, `records`) — `RoamPlayerExtrasService.sessionRecordsPath`
- `pages/roam/index.js:1830` `POST api/roam/reveal` (`sessionId`, `tiles`, `clientSessionKey`) — `RoamExperienceMutation`

## Tests the checker still leaves missing

86 owned rows stay missing a test. Nine of those forward `url` and have no path to quote. The other 77 have a quote test. The checker pins a row only when the call's method is a literal and the data argument is a closed object literal, and one test function contains the path, that method, and every key. A trailing `true`, `JSON.stringify`, `Object.assign`, a spread, or a variable data argument leaves the field list unknown. Quoting the keys in a test does not change that. This is not a parse.

`subpackageRoam/citystamp/index.js:291` and `:300` call `req(path, fields)`. That call does not write a method literal. The quote tests name the path and the fields and do not invent `"POST"`. The `sendRequest` at `:29` is the forwarder that sets `POST`.

## Gates

Not edited. `PlayStageAnalyticsGate.enabled` is `false`. `MerchantCityNPCParityGates.disabled` keeps `storeDayProofWrites` and `storeDayConsentWrites` false. `JourneyLoopSource.giftClaim` still throws `JourneyRefusal.moneyOff` and sends nothing. `PlatformPass` `cancelPassOrder`, `confirmPassOrder`, and `refundApplyPassOrder` still throw `PlatformPassWriteRefusal.unreachable` and send nothing. `RuntimeLocationProjection` is not edited. `AppSession.swift` is not edited. The checker is not edited. `project.pbxproj` and `tools/current_ci_manifest.json` are not edited.

## Not claimed

No `swiftc`. The checker does not parse JavaScript. `subscribe.request` is not a row. No mini-program screenshots.
