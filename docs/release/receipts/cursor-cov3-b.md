# cursor/cov3-b

Base `6afe54b4acee8786a9f3f3cbe8cd85d90be1e35a` (`ui/combined-r7` at the start of this lane). The branch was cut from that SHA and was not moved when the combined tip changed. No rebase onto a later tip.

Mini-program: public `liboyang42-cpu/hengyin` folder `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`. Row source: `python3 -B tools/check_mp_contract_coverage.py --mp-root` on that tree. `docs/mp-contract-coverage.md` was not edited.

## Lane

Missing-endpoint rows only (Core symbol `MISSING`). Sorted by the `path:line` string. `n = 120`. This lane owns index `n//4` inclusive through `2*(n//4)` exclusive: 30 through 59.

| | |
|---|---|
| n | 120 |
| first owned row | `pages/merchant/team/index.js:715` |
| last owned row | `pages/topic/components/cy/node-npc-form/index.js:641` |
| endpoints added | 0 |
| rows left | 30 |

Rows left means owned rows that are still missing-endpoint after this change. All 30 are. Sorting the same 120 rows by path and then numeric line yields the same 30 rows and the same first and last row.

Checker before: `# total 1038 matched 779 missing_endpoint 120 missing_test 256`.

Checker after: `# total 1038 matched 779 missing_endpoint 120 missing_test 255`.

The published totals line in `docs/mp-contract-coverage.md` was left as it was. One owned row gained a test name. Its symbol stays `MISSING`, so matched and missing_endpoint do not move.

## One path literal

Three owned calls contain one `/api` path. Each path is already a Core literal, so no endpoint was added.

| MP file:line | method | path | literal names | existing Core literal | test counted |
|---|---|---|---|---|---|
| `pages/publishkit/components/topic-state-keys/index.js:307` | DELETE | `api/topic/state-keys` | topicId, scope, key (query; no body) | `NativeAttributeAuthorRequest.delete` | yes |
| `pages/roam/index.js:1801` | POST | `api/roam/session/records` | sessionId, clientSessionKey, records | `RoamPlayerExtrasService.sessionRecordsPath` | no |
| `pages/roam/index.js:1830` | POST | `api/roam/reveal` | sessionId, tiles, clientSessionKey | `RoamExperienceMutation.path` (`.reveal`) | no |

`Tests/CoreTests/ZzCov3LaneBContractPinTests.swift` quotes those three. The class name sorts after existing CoreTests classes.

The delete call builds `` `/api/topic/state-keys?${this._qs()}&key=${encodeURIComponent(key)}` ``. `_qs` writes `topicId` and, for merchant scope, `scope`. The checker keeps the path and marks it templated because the query is interpolated, then looks that path up only in the templated index. A fixed `api/topic/state-keys` literal is not stored there, so the symbol stays missing. The test is counted: method `DELETE` is quoted, and there is no body field list to satisfy. `topicId`, `scope`, and `key` are quoted in the test. No other row picked up that test.

The two roam calls pass one path string and `'POST'`. The data object spreads `clientSessionKey`. The checker treats that spread as clearing `url`, so the path and the method are dropped and the tests are not counted. `RoamExperienceMutation.reveal` stays disabled (`productionEnabled` is false). `RoamPlayerExtrasService` was not edited. Nothing is sent from the new tests.

## No single path

No path was invented for these 27. A ternary is two literals. A forwarded `url` was not followed.

| MP file:line | why |
|---|---|
| `pages/merchant/team/index.js:715` | ternary `api/merchant/operators/remove` or `api/merchant/operators/invite/revoke` (both already in `MerchantBusinessMutation`) |
| `pages/merchant/utils/voice-enrollment-journal.js:100` | local predicate `request(value.requestId)`, not HTTP |
| `pages/merchant/utils/voice-enrollment-journal.js:18` | local predicate `request(value.active)`, not HTTP |
| `pages/merchant/utils/voice-enrollment-journal.js:20` | local predicate `request(row.requestId)`, not HTTP |
| `pages/merchant/utils/voice-enrollment-journal.js:76` | local predicate `request(result.voiceRequestId)`, not HTTP |
| `pages/play/circle/index.js:12` | forwards `url` |
| `pages/play/components/advanced-game/index.js:89` | forwards `url` |
| `pages/play/index.js:336` | forwards `url` |
| `pages/play/merchant/index.js:16` | forwards `url` |
| `pages/play/utils/theme-backpack.js:372` | ternary `api/game/session/shared/preview` or `api/play/theme/gameplay-preview` |
| `pages/play/utils/theme-backpack.js:503` | ternary `api/game/session/command` or `api/play/theme/gameplay-action` |
| `pages/play/utils/theme-command.js:11` | forwards `options.url` |
| `pages/privacy/index.js:119` | forwards `url` |
| `pages/publish/activity/index.js:818` | ternary `api/merchant/access/me` or `api/publish/home` |
| `pages/publish/temp/index.js:3490` | ternary `api/template/draft` or `api/template/publish` |
| `pages/publish/temp/index.js:3560` | ternary `api/template/author-myinfo` or `api/template/author-info` |
| `pages/publish/utils/publish/publish-workflow.js:44` | injected `request(payload, settle)`, no path |
| `pages/publish/utils/publish/server-draft.js:477` | local `request('readback', ...)`, no path |
| `pages/publish/utils/publish/server-draft.js:491` | local `request('readback', ...)`, no path |
| `pages/publish/utils/publish/server-draft.js:535` | local `request('readback', ...)`, no path |
| `pages/publish/utils/publish/server-draft.js:559` | local `request('save', ...)`, no path |
| `pages/publish/utils/publish/server-draft.js:574` | local `request('readback', ...)`, no path |
| `pages/roam/index.js:210` | forwards `url` |
| `pages/search2/result/index.js:198` | forwards `request.url` |
| `pages/team/utils/team-invite-qr.js:26` | forwards `URL` (`const URL = '/api/team/invite-qrcode'` is not on the call; `PlayerGapRoutes` already posts that path) |
| `pages/templatedetail/templatedetail.js:331` | ternary `api/template/myinfo` or `api/template/info` |
| `pages/topic/components/cy/node-npc-form/index.js:641` | forwards `url` |

## Left unchanged

Money stays off. No payout, refund, withdrawal, registration pay, or pricing grant was enabled. `RoamExperienceMutation` was not edited.

`App/AppSession.swift` and `App/AppCompositionRoot.swift` were not edited. Ceilings were not raised. `Questify.xcodeproj/project.pbxproj` was not edited. `tools/check_mp_contract_coverage.py` and `tools/current_ci_manifest.json` were not edited. `swiftc` was not run.
