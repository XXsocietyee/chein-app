# cursor/k7e-fixes

Parent `ebf6c160ce73880807c07cf3cc10aa829e83d75e` on `ui/combined-r7`. No rebase. Check `45550995140` was an older tree. A name was edited only when that defect was still in this tree.

`swiftc` and `xcodebuild` were not run. This receipt does not claim a parse. `App/AppSession.swift`, `App/AppCompositionRoot.swift`, `project.pbxproj`, and `tools/current_ci_manifest.json` were not edited. Ceilings were not raised. Money stays off: no sender was added, and no pay, gift, payout, or withdrawal path was opened.

These are not code defects and were not changed: AppUnit W2 git `SSL_ERROR_SYSCALL`, AppUnit Lane2 exceeding 25m, screenshots exceeding 30m, SimError 405, POSIX 3.

## Names

| Name | Result |
|---|---|
| `App/ObjectBadgeTileArtwork.swift:30` unlabeled image | already gone |
| `Tests/CoreTests/MPGap/G2OpsGapTests.swift:224`, `:226`, `:228` `async` inside an autoclosure | fixed |
| `Tests/CoreTests/PlayRoamCoreContractTests.swift:37` errors thrown from here are not handled | fixed |
| `Tests/CoreTests/PlayRoamMiniProgramContractPinTests.swift:340` missing argument `draft` | fixed |
| same file `:401` no member `cancelOrder`, `:414` no `confirmOrder`, `:431` no `refundApply` | fixed |
| `Tests/CoreTests/PlayRuntimePortTests.swift:103` main-actor initializer called from outside the actor | fixed |

### Unlabeled image — already gone

`BoundedMediaThumbnail` already builds `Image(uiImage: image).resizable().scaledToFit().accessibilityHidden(true)`. The hide sits after the last image modifier. The file was not edited. `tools/check_a11y_lint.py` `analyze` on `App/ObjectBadgeTileArtwork.swift` reports no finding. No string was added. `Resources/Localizable.xcstrings` was not merged.

### Autoclosure — fixed

`ClubScanClient.submit` is awaited into `invalidCodePosted`, `unauthorizedPosted`, and `governedPosted` before `XCTAssertFalse` / `XCTAssertTrue`. None of those locals is named `submit`. The three requests are unchanged: an invalid code and a scan without govern still send nothing; a governed group code still posts.

### Unhandled `try` — fixed

`testRankListQueryMatchesMiniProgram` is `async throws`, so `try XCTUnwrap(transport.requests.first)` is handled by the test. The rank read is still `GET /api/rank/list`. Gift claim was not touched.

### Missing `draft` — fixed

`RoamPrivateToolsService.goalReceipt(requestID:draft:token:)` now receives the receipt's `RoamGoalDraft`. That argument is the local echo check. The pin is still one `GET /api/exploration-goals/receipt` with `requestId`. `createGoal` was not called.

### Pass writes — fixed

The test calls the current methods `cancelPassOrder`, `confirmPassOrder`, and `refundApplyPassOrder`. Each still throws `PlatformPassWriteRefusal.unreachable` and returns `Never`. `PlatformPass` was not edited. `orderWriteTestDerivation` stays nil, so the default sends nothing. `sendCancelPassOrder`, `sendConfirmPassOrder`, and `sendRefundApplyPassOrder` were not added and are not called.

### Main-actor initializer — fixed

`FreeExplorationVisitConfigService` is `@MainActor`. The call that used the default read and write gates (`PlayRuntimePortTests.swift:103`) is now inside `await MainActor.run`, the same hop neighboring Core tests use for a main-actor initializer. The earlier call in that test, which passes `authorWrites: false` and `readsEnabled: false`, is the same initializer and is hopped the same way. The off read still must not send. The default service still loads an empty list. No write was added.
