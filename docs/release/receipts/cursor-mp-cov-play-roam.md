# cursor-mp-cov-play-roam

Base `aee32a61f0f69b880bc9e33811463ccc73351bbe` (`origin/ui/combined-r7`). Branch `cursor/mp-cov-play-roam`. No pull request.

Coverage table and receipt: `origin/cursor/mp-contract-coverage` `569fca24195166bfb70cba51a8e2aedff27da2a3`. Mini-program: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`. Contract table: `docs/mp-contract-coverage/play-roam.md`.

The 16 pins on the coverage branch are not copied onto this branch. Member, club, and merchant-ledger rows are not taken. `subpackageMember/market/pass-order/index.js:114` (`subscribe.request(['refund'])`) is not a contract row.

No `swiftc`. The checker below is the script from `569fca241951`, run against this tree and `/tmp/hengyin/chengyinhub-xcx`.

## Counts

| count | value |
|---|---|
| play-roam rows taken | 22 |
| new Core path symbols (were MISSING) | 3 (`cancel`, `confirm`, `refund-apply`) |
| tests added | 22 |
| tests that name a row | 21 |
| rows the checker marks pinned | 6 |
| rows the checker still leaves missing a test | 16 |
| rows still missing an endpoint | 1 (`pages/roam/index.js:210`) |
| checker total | 102 |
| checker matched | 8 |
| checker missing endpoint | 39 |
| checker missing test | 94 |

The coverage commit reported total 102, matched 19, missing endpoint 42, missing test 82, with its 16 tests present. This branch does not contain those tests, so the absolute matched count is the two pins already on `ui/combined-r7` plus the six new pins: advanced receipt (`Stub.testAdvancedUnknownIsSettledByItsOwnReceipt`), passport history (`PlayRoamCoreContractTests.testPassportHistoryRequestMatchesMiniProgram`), capsule detail, capsule receipt, capsule delete, goal receipt, goal cancel, and refund-apply.

Missing endpoint falls by 3 because cancel, confirm, and refund-apply now have `PlatformPass` path literals. The other taken rows already had a Core path. `pages/roam/index.js:210` stays missing because `req` forwards `url`.

The checker pins a row only when the mini-program data argument parses to literal keys and one test function contains the path, the method, and every key. Start, action, run-session, photo, both consents, capsule create and list, and goal create, detail, and list are unparsed. Cancel and confirm pass no data, so their field list stays unknown. Those 15 tests quote the real keys anyway. Refund-apply parses (`reason`) and is pinned.

## Gates

`PlatformPass.moneyEnabled` is false. `writesReachable` stays false. `cancelOrder`, `confirmOrder`, and `refundApply` throw `PlatformPassWriteRefusal.unreachable` and leave the transport empty. Refund-apply is contract plus test only.

`JourneyLoopSource.giftClaim` still throws `JourneyRefusal.moneyOff` and sends nothing. `PlayStageAnalyticsGate.enabled` is still `false`. `MerchantCityNPCParityGates.disabled` keeps `storeDayProofWrites` and `storeDayConsentWrites` false. A default `PlayExperienceService` (empty capability set) throws `.disabled` before `startAdvanced` sends. `AppSession.playStoreDay` still constructs `PlayStoreDayService` with `gates: .disabled`.

`RuntimeLocationProjection` is not edited. No App screen is edited. The rank contract type is `JourneyRankBoardContract`. `JourneyRankBoard` in `App/JourneyReportViews.swift` is not edited.

`App/` was searched before adding `PlayRunSessionSave`. There was no such type. It lives on the existing `Core/PlayRuntimeGap.swift` next to `PlayRunSessionClear`. Nothing in `App/` calls `PlayRunSessionSave.save`. `PlayExperienceService.savePaused` stays multipart and is not the pin.

## App call sites (not edited)

Advanced start and action go through `PlayAdvancedCoordinator`, built in `App/AppSession.swift` `playAdvanced` and `playExperience(for:)`. `playExperience(for:)` enables the player write grant when that lease exists, otherwise only `.reads`. Screens: `App/PlayExperienceView.swift`, `App/PlayAdvancedView.swift`, `App/PlayKitScreen.swift`, `App/PlayAdvancedTeamViews.swift`, `App/ChapterStoryView.swift`, `App/NativeMotionReminderViews.swift`. Fixtures: `App/PlayExperienceFixtureSupport.swift`, `App/PlayCompareFixtureSupport.swift`, `App/NativePlatformFixtureHost.swift`, `App/DesignFixtures/NewFeatureFixtures.swift`, `App/DesignFixtures/E2CityFixtures.swift`.

`NativePlatformService` is constructed in `App/AppSession.swift` (step grant around the `actionPath` check) and `App/NativePlatformFixtureHost.swift`.

Run-session read: `Core/PlayExperienceCoordinator.swift` `restoreRun` calls `readPaused`. `App/PlayExperienceView.swift` calls `restoreRun`. Run-session clear: `App/PlayRuntimeGapProduction.swift` `clearRunSessionOnFinish`, called from `App/PlayRuntimeGapViews.swift`. No App call site for `PlayRunSessionSave`.

Store day: `App/AppSession.swift` `playStoreDay` (`gates: .disabled`), `App/PlayStoreDayMerchantView.swift`, `App/PlayStoreDayMerchantEntry.swift`, `App/FreeExplorationViews.swift`, fixture `App/PlayStoreDayMerchantFixtureHost.swift`.

Pass read: `App/MPParityPassSession.swift` `passOrderDetail`. No App call of `cancelOrder`, `confirmOrder`, or `refundApply`.

Private tools: `App/AppSession.swift` `roamPrivateToolsReader` constructs `RoamPrivateToolsService`. Screens: `App/RoamPassportPrivateToolsViews.swift` and the roam views that take `RoamPrivateToolsServing` (`App/RoamPassportToolsViews.swift`, `App/RoamExperienceHubView.swift`, `App/RoamExplorationExportView.swift`).

`App/PlayGameStageViews.swift` reads `PlayStageAnalyticsGate.enabled` and does not turn it on. No App call of `giftClaim`.

## Roam forwarder

`pages/roam/index.js:210` does not name one endpoint. `req(` call sites in that file:

`/api/ai/npc/profile`, `/api/ai/npc/event`, `/api/roam/shop/visitors`, `/api/preset/route/list`, `/api/official/active-for-roam`, `/api/roam/checkin`, `/api/roam/tiles/page`, `/api/map/nearby`, `/api/roam/pois`, `/api/roam/session`, `/api/roam/session/records`, `/api/roam/reveal`, `/api/official/events/{id}`, `/api/official/events/{id}/arrivals`, `/api/roam/finish`, `/api/roam/presence`, `/api/roam/nearby-runners`, `/api/im/start`, `/api/roam/poi/discover`, `/api/roam/nearby-exploreday`, `/api/roam/shop/visit`, `/api/official/events/{id}/complete`, `/api/creativesquare/action`, `/api/roam/entry/nearby`, `/api/team/nearby`, `/api/topic/list`.

These are call sites of the forwarder, not new coverage rows.
