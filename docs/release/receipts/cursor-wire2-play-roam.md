# cursor-wire2-play-roam

Base `origin/ui/combined-r7` `b0ac0108d0a5a9739ababecbbc61284cae5a8043` (message starts "Integrate F-agent round 2"). Tip had not moved. No rebase. Branch `cursor/wire2-play-roam`. No pull request.

Source: `docs/release/receipts/cursor-mp-cov-play-roam.md` and `docs/mp-contract-coverage/play-roam.md`. The App call sites that receipt names already go through the contracts on this base. Zero call sites moved. The 22 pinning tests were not edited. No endpoint was added.

`pages/roam/index.js:210` stays a forwarder (`req` takes `url`). No path was invented for it. The concrete `req(` URLs in that file stay call sites of the forwarder, not new rows. `subscribe.request` is not a contract row.

No `swiftc` run. This receipt does not claim a parse. `project.pbxproj` and `tools/current_ci_manifest.json` were not edited. No secret and no mini-program screenshot.

## Sites checked

| Site on this base | Already calls | Contract | Moved |
|---|---|---|---|
| `App/AppSession.swift:1304` `playExperience(for:)` | `PlayExperienceService` with the player write grant when that lease exists, otherwise `.reads` | `startAdvanced` / `readPaused` only when the enabled set contains the capability | no |
| `App/AppSession.swift:3123` `playAdvanced` | `PlayAdvancedCoordinator` on that service | `PlayExperienceService.startAdvanced` / `advancedAction` | no |
| `App/PlayAdvancedView.swift:45` start, `:232` and `:293` `submit` | `model.start()` / `model.submit` | `startAdvanced`; `advancedAction` (`sessionId`, `version`, `idempotencyKey`, `action`, `payload`) | no |
| `App/PlayKitScreen.swift:132` | `model.submit` | `advancedAction` | no |
| `App/PlayAdvancedTeamViews.swift:72` | `model.submitTeamReview` | `advancedAction` (`ASSIGN_ROLE` / `COMPLETE_UNIT`) | no |
| `App/ChapterStoryView.swift:481` and `:484` | `advanced.start()` | `startAdvanced` | no |
| `App/PlayExperienceView.swift:227` and `:233` | `model.restoreRun()` | `PlayExperienceService.readPaused` (`GET api/play/run-session`, `activityId` or `topicId`) | no |
| `App/NativeMotionReminderViews.swift:44` and `:308` | `runtime.stepModel` and `runtime.service.timeWindow` | `NativeStepCoordinator` calls `NativePlatformService.action` (`actionPath`); reminders are `GET api/play/advanced/time-window` | no |
| Fixtures `PlayExperienceFixtureSupport.swift:137`, `PlayCompareFixtureSupport.swift:55`, `NewFeatureFixtures.swift:253`, `E2CityFixtures.swift:191` | `PlayAdvancedCoordinator` | same start/action methods | no |
| `App/AppSession.swift:3246` and `:3253` | step grant checks `NativePlatformService.actionPath`, then constructs `NativePlatformService` | `POST api/play/advanced/action` | no |
| `App/NativePlatformFixtureHost.swift:95` | `NativePlatformService(...)` | same `actionPath` | no |
| `App/PlayRuntimeGapProduction.swift:40` `clearRunSessionOnFinish` | `PlayRunSessionClear.clear` | `POST api/play/run-session/clear` urlencoded `{savedAt, activityId \| topicId}` | no |
| `App/PlayRuntimeGapViews.swift:131` | `clearRunSessionOnFinish` when the run is finished | same clear | no |
| `App/AppSession.swift:1399` `playStoreDay` | `PlayStoreDayService(..., gates: .disabled, readsEnabled: true)` | photo and consent send nothing | no |
| `App/PlayStoreDayMerchantEntry.swift:11`, `App/FreeExplorationViews.swift:318`, `App/PlayStoreDayMerchantView.swift:391` | `PlayStoreDayCoordinator` (`preparePhoto` / consent) | `photo` uses `photoPath`; `consent` / `latestConsent` use `consentWriteContract` / `consentLatestContract` | no |
| `App/PlayStoreDayMerchantFixtureHost.swift` | fixture host for the same view | writes stay on the disabled gates | no |
| `App/MPParityPassSession.swift:745` `MPParityPassOrderModel.reload` | `PlatformPass.passOrderDetail` | `GET api/platform-pass/orders/{orderNo}` | no |
| `App/AppSession.swift:6314` `roamPrivateToolsReader` | `RoamPrivateToolsSessionReader` / `RoamPrivateToolsService` | `RoamPrivateToolsRoute` capsule and goal paths | no |
| `App/RoamPassportPrivateToolsViews.swift` | capsule and goal coordinators (`createCapsule`, `deleteCapsule`, `capsules`, `cancelGoal`, list/detail/receipt) | JSON create; urlencoded delete/cancel; GET detail, receipt, list | no |
| `App/RoamPassportToolsViews.swift`, `App/RoamExperienceHubView.swift:14`, `App/RoamExplorationExportView.swift:11` | `RoamPrivateToolsServing` | same reader | no |
| `App/PlayGameStageViews.swift:164` | reads `PlayStageAnalyticsGate.enabled` | gate stays `false`; the issue menu stays hidden | no |

`PlayExperienceCoordinator.restoreRun` (`Core/PlayExperienceCoordinator.swift:885`) calls `readPaused` at `:903`. That Core method was not edited.

## Not given a call site

- `PlayRunSessionSave.save` still has no App caller. `PlayExperienceView` pause (`:262`, `:722`) and end (`:164`) stay on `pauseRun` / `endRun`, which dispatch `PlayExperienceService.savePaused` / `clearPaused`. That sender stays multipart. It is not the run-session pin.
- Cancel, confirm, and refund-apply have no App call. `PassOrderDetailView` still shows `mp.passOrder.gated` for resume, cancel, and refund (`App/PassMarketViews.swift:1033`). `PlatformPass.cancelPassOrder`, `confirmPassOrder`, and `refundApplyPassOrder` throw `PlatformPassWriteRefusal.unreachable` and do not send. The path literals are `cancelOrderPath`, `confirmOrderPath`, and `refundApplyPath`. The coverage test names `cancelOrder` / `confirmOrder` / `refundApply`; those instance methods are not on this base after the member merge. The tests were not rewritten, and App was not pointed at a missing symbol.
- `JourneyLoopSource.giftClaim` still throws `JourneyRefusal.moneyOff` and sends nothing. `App/PlayerJourneyReadBindings.swift` reaches it only while `MPCommerceGate.claimsEnabled` is true. That flag is `false`. That file is not in the coverage call-site list and was not edited.

## Left as they were

- `PlatformPass.moneyEnabled` and `writesReachable`.
- `PlayStageAnalyticsGate.enabled` (`false`).
- `MerchantCityNPCParityGates.disabled` (`storeDayProofWrites` and `storeDayConsentWrites` false). `photo()` still adds the action-context identity only when proof writes are permitted. `photoContract` does not send. Production `playStoreDay` still passes `gates: .disabled`.
- `PlayClientCapabilities.startFields` (array of `key@version`, `clientPlatform` `ios-native`). `declaration(_:)` stays the comma-string helper.
- `RuntimeLocationProjection` (the 100–200 m WGS-84 behavior).
- Signatures of `SettingsView`, `MerchantVerifyRecordsSections`, `PlatformConsumerSessionOwner`, `RoamPOIActions` (pending journal kept), `JourneyReportViews`, `TeamHomeView`, `TicketWalletView`, `TopicXcxSections`, `ClubDetailView`, and `ClubWorkbenchKit`.
