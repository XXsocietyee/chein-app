# cursor/cov4-tests-2

Branch cut from `ebf6c160ce73880807c07cf3cc10aa829e83d75e` and left there. That commit was the tip of `ui/combined-r7` when this branch was created. No rebase. `main`, `master`, `ui/main`, `ui/combined-r7`, `ui/combined-*`, and `ci/acceptance` were not pushed.

Mini-program: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`. Counts are from `tools/check_mp_contract_coverage.py` (`collect`) on that tree plus this branch's `Core/` and `Tests/CoreTests/`. The checker does not parse JavaScript. It was not edited. `docs/mp-contract-coverage.md` was not edited. `AppSession.swift`, `AppCompositionRoot.swift`, `project.pbxproj`, and `tools/current_ci_manifest.json` were not edited. No `swiftc`. No new endpoint. The tests were not executed.

## Checker

| | before | after |
|---|---:|---:|
| rows | 1038 | 1038 |
| matched | 792 | 802 |
| missing endpoint | 115 | 115 |
| missing test | 242 | 232 |

Matched rises by 10 and missing test falls by 10. Eight of those rows are owned. Two are the same path, method, and empty field list on files this lane does not own. Endpoints added: 0.

## Rows owned

A missing-test row is owned when its mini-program file is account settings (`pages/shezhi/`, `pages/privacy/`), publish (`pages/publish/` outside `utils/` and `components/`), gerenziliao, project edit (`pages/publish/fabu/`), or visit-config (`pages/publish/fabu/theme-fe-visit.js`), and the path does not contain `/club/`. `pages/gerenziliao/` has no missing-test row on this SHA.

Eight calls already had a Core symbol. The checker now records a test because the function quotes the path and the method. JSON.stringify, `loadQuery`, and `saveBody` left the field list empty, so the checker did not require fields. The tests still quote the literal keys.

| MP file:line | method | path | literal fields | test |
|---|---|---|---|---|
| `pages/publish/fabu/index.js:8798` (payload `pages/publish/fabu/index.js:8786`) | POST | `api/template/adopt-draft` | originalTemplateId, requestId, sourceVersion, scope | `testAdoptDraftPinsPostAndLiteralFields` |
| `pages/publish/fabu/theme-d20-page.js:100` | PUT | `api/topic/play-setup` | topicId, scope, playWindow, prepItems | `testPlaySetupSavePinsPutAndLiteralFields` |
| `pages/publish/fabu/theme-fe-visit.js:39` | GET | `api/topic/free-explore/visit-config` | topicId (`pages/publish/utils/publish/fe-visit-config.js:51`, not owned) | `testVisitConfigReadPinsGetAndTopicId` |
| `pages/publish/fabu/theme-fe-visit.js:86` | POST | `api/topic/free-explore/visit-config` | nodeId, visitCheck, visitRadius (`fe-visit-config.js:55`) | `testVisitConfigSavePinsPostAndLiteralFields` |
| `pages/publish/fabu/theme-initial-carry.js:87` | POST | `api/topic/state-keys` | topicId, scope, keys | `testStateKeyCreatePinsPostAndLiteralFields` |
| `pages/publish/fabu/theme-route-names.js:77` | POST | `api/topic/state-keys/named` | topicId, scope, kind, label | `testNamedStateKeyPinsPostAndLiteralFields` |
| `pages/publish/fabu/theme-runtime-structure.js:361` (object `pages/publish/fabu/theme-runtime-structure.js:359`) | POST | `api/orient/task/alternative` | topicId, taskId, alternativeTaskType, promptText, enabled, answer | `testOrientAlternativePinsPostAndLiteralFields` |
| `pages/shezhi/shezhi.js:337` | POST | `api/logout` | none | `testAccountLogoutPinsPost` |

Paths quoted were already `TemplateAdoptionService.adoptPath`, `TopicCreatorEditorRoute.playSetup`, `FreeExplorationVisitConfigService.path`, `TopicCreatorEditorRoute.stateKeys`, `NativeAttributeAuthorRuntimeConfiguration.path(.legacyList)`, `TopicCreatorEditorRoute.namedStateKey`, `PlayerGapService.parityBPaths`, and `AuthEndpoint.logout`. `ReleaseMoneyWriteSwitch.kind(for:)` is nil for each. Nothing is sent.

Four more owned calls stay missing-test. The checker keeps no single path, or it keeps no method. The tests quote the literals that are written. They do not invent a path or a method, and they do not send.

| MP file:line | what is quoted | why the checker stays missing | test |
|---|---|---|---|
| `pages/publish/activity/index.js:818` | POST, `api/publish/home`, data `{}` | url is a ternary. The merchant arm is not quoted | `testActivityAccessQuotesPublishHomePost` |
| `pages/publish/temp/index.js:3490` | POST from the request object at `pages/publish/temp/index.js:3371`, `api/template/draft`, `api/template/publish` | `Object.assign` forwards `request` and `handlers`. The body is `JSON.stringify` of that forwarded value. No field list is invented | `testTemplateDraftAndPublishQuotePostPaths` |
| `pages/publish/temp/index.js:3560` | POST, `id`, `scope`, `api/template/author-myinfo`, `api/template/author-info` | url is a ternary, so the checker keeps no path | `testTemplateAuthorInfoQuotesPostIdAndScope` |
| `pages/privacy/index.js:119` | GET and POST from the callers. Literals: `/api/media/asset/list` (`:139`), `/api/media/asset/list?beforeId=` (`:178`), `/api/media/asset/` (`:203`, `:214`, `:227`, `:255`), `/retry` (`:203`), `/preview` (`:227`) | the row forwards `url` and `method` | `testPrivacyOwnMediaQuotesCallerMethods` |

`OwnMediaReadRoute.path` is already `api/media/asset/list`. `QuickPublishSimplePageContract.homePath` is already `api/publish/home`. `TemplateAdoptionService.authorMyInfoPath` and `authorInfoPath` are already those two author-info paths.

## Same shape, not owned

The checker matches path, method, and field names, not the file. These two rows now show an owned test. They were not given their own test.

| MP file:line | method | path | test |
|---|---|---|---|
| `pages/publish/utils/publish/template-adoption.js:60` | POST | `api/template/adopt-draft` | `testAdoptDraftPinsPostAndLiteralFields` |
| `pages/publishkit/components/topic-state-keys/index.js:254` | POST | `api/topic/state-keys` | `testStateKeyCreatePinsPostAndLiteralFields` |

## Not taken

`pages/publish/components/`, `pages/publish/utils/` (except the same-shape adopt-draft row above), `pages/publishkit/components/`, `pages/topic/`, creativesquare, `pages/merchant/`, roam, `pages/play/`, `utils/`, `components/`, and `app.js`.

`pages/publish/temp/index.js:3485` is `api/merchant/city-node/template/submit`. Merchant was not taken. The checker also keeps no method on that call.

`utils/publisher-identity.js:89` is the only missing identity row (`POST api/publisher/identity/status`). It stays under `utils/` and was not taken.

`pages/talent/`, `pages/team/`, and `subpackageA/pages/myproject/` were not taken. Team, talent, and the project list are outside account, publish, gerenziliao, identity, project edit, and visit-config.

No path containing `/club/` was taken.

## Money

`testQuoteCreatePayRefundPayoutWithdrawalAndPricingConfirmSendNothing` sets `ReleaseMoneyWriteSwitch.testDerivation` back to nil. Payment, payout, withdrawal, and refund stay off. `PlayerContentMPContract.moneyEnabled` and `PlatformPass.moneyEnabled` stay false. `PlatformPass.writesReachable` stays false.

Quote, registration create, and pricing confirm throw before a request exists (`Refusal.moneyDisabled`, `Refusal.pricingGrantDisabled`). `refuseRegistrationPay` throws `Adapt5PayRefusal.blocked`. Pass quote, pay, and refund-apply throw `PlatformPassWriteRefusal.unreachable`. The transport in that test records no request. Paid orders, payout, and withdrawal are not built.

## Tests added

Thirteen functions in `Tests/CoreTests/ZzZzCov4AccountPublishPinTests.swift`. The class name sorts after `ZzZzCov3MemberContractPinTests`, so a shared path keeps the test it already had.

No string catalog was edited. No `Resources/Localizable.xcstrings` merge.
