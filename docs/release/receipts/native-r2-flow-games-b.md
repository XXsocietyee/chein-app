# Receipt: native-r2/flow-games-b (games templates 4–6)

Branch: `native-r2/flow-games-b`, cut from `origin/ui/combined-r7` (`2446657fb`). Held until owner approval.
Spec: `docs/design/native-r2/games.md` on `design/native-r2-games` (`23fed2028`). Brief: `docs/briefs/native-r2.md` (EVERYTHING native).

No compiler in the cloud: every type, init and modifier was grepped in the repo or is a stock SwiftUI / VisionKit API available on the iOS 17 deployment target. `python3 tools/check_scaffold.py` prints `PASS structural checks`. Contract checks (`python3 -m unittest discover -s Tests/ContractChecks`): same failure set as the base (141 failures / 106 errors pre-existing); the one new failure (journey check mount name) was updated, see below.

## Shell

`native-r2/flow-games-a` (owner of `App/NativeR2/Games/NativeGameShell.swift`) did not exist on the remote while this pass ran. **No second shell type was created.** The B kits are written against a minimal host contract, `GamesBKitContext` (`App/NativeR2/Games/GamesBKitContext.swift`): segment, projection, `enabled`, `busy`, the shared selection and text bindings, `markDirty`, and the existing review outlet `prepare` (`PlayKitReviewRequest`). `PlayKitScreen.gamesBContext` builds it from the screen's existing state. When games-a's shell lands it only needs to host the same `content` switch; every B kit emits `Section`s, so it works in today's `ScrollView`/`VStack` container and in a `List` shell.

## Kits (same actions, payloads and scoring as before; UI only)

Kit grouping follows the spec (§0), not the brief's first draft: **hidden** and **blindtaste** were moved by the spec to Template 1 (Answer), which belongs to games-a; **predict** and **journey-check** moved into Chance; **bingo** into Story choice. Built here:

| Template | Kit | New view | Replaces | Action / payload (unchanged) |
|---|---|---|---|---|
| 4 Camera | photocheck | `PlayKitScreen.cameraPhotoCheckForm` + `CameraPhotoInput` | `photoCheckForm`, `PlayKitPhotoInput` | `SUBMIT_PHOTO_CHECK {imageUrl}` |
| 4 Camera | objectcard (photocheck `mode == CARD`) | `cameraObjectCardForm` + `CameraObjectCardRevealView` | `objectCardForm`, `PlayObjectCardRevealView` | same |
| 4 Camera | scan | `cameraScanForm` + `CameraScanInput` | `scanForm`, `PlayKitScanInput` | `SUBMIT_SCAN {code}` |
| 4 Camera | album | `CameraAlbumView` (in `PlayAdvancedView`) | `PlayKitAlbumView` | same `complete` / `close` closures |
| 5 Chance | coinflip | `ChanceCoinFlipKit` | `coinFace` | `FLIP_COIN` |
| 5 Chance | diceroll | `ChanceDiceRollKit` | `diceFaces` | `ROLL_DICE` |
| 5 Chance | random | `ChanceRandomKit` | `randomDeck` | `DRAW` |
| 5 Chance | predict | `ChancePredictKit` | `predictForm` | `SUBMIT_PREDICT {optionKey}` |
| 5 Chance | journey-check | `ChanceJourneyCheckView` (in `PlayExperienceView`, `JourneyContentFixtureSupport`) | `PlayJourneyCheckView` | `JourneyCheckCoordinator.prepare(.roll/.reroll/.settle)` |
| 6 Story | branch | `ChoiceBranchKit` | `branchForm` | `CHOOSE {optionId}` |
| 6 Story | musiccorner | `ChoiceMusicCornerKit` | `legacyBody` `.musicCorner` case | none (playback only, `PlatformAudioHost`) |
| 6 Story | dailysign | `ChoiceDailySignKit` | `dailySignForm`, `PlayKitDailySignTicket` | `CLAIM_DAILY_SIGN {text, photoUrl}` |
| 6 Story | bingo | `ChoiceBingoKit` | `bingoBoard` | none (read-only) |

Apple components used: `Section`, `LabeledContent`, `Label`, `GroupBox`, `Picker(.inline)`, `Grid`, `Gauge`, `TabView(.page)`, `ContentUnavailableView`, `ProgressView`, `.confirmationDialog`, `.sheet` + `.presentationDetents`, `.popover`, `ShareLink` + `ImageRenderer`, `.buttonStyle(.borderedProminent / .bordered / .borderless)` + `.controlSize(.large)`, SF Symbols (`die.face.N.fill`, `sun.max.circle.fill`, `moon.circle.fill`, `seal`, `checkmark.seal.fill`, …) with `.contentTransition(.symbolEffect(.replace))`, `.contentTransition(.numericText())`, `.symbolEffect(.pulse)` while the server works, `.sensoryFeedback(.impact / .success / .warning)`. Shake to roll/flip keeps `cyOnShake`. Big symbols use `@ScaledMetric` (Dynamic Type), no fixed font size.

Removed from these kits: `CYPillButton`, `CYChoiceRow`, `CYStatusChip`, `CYStepIndicator`, `CYNoteBanner`, `CYHeroHeader`, `CYSkeleton`, `CYScratchCard`, `CYHoldToRollButton`, `CYDiceTierStrip`, `DiceD20CanvasView`, `JourneyCheckDCTrack`, `.thinMaterial` cards, the dashed ticket dividers, the 3D album ring and `CYNight.glow`, the foil label chrome, `HapticsService` dice haptics (now `.sensoryFeedback`). Accessibility identifiers used by tests are kept (`journey.check.roll/reroll/settle/recover/close/reopen`, `playkit.dice.total`, `playCard.*`, `playkit.album.*`, `playkit.bingo.*`, …).

## Camera specifics

- **System camera:** the existing `PlayDeviceCaptureCoordinator.capture(.photo, cameraFrame:)` → `UIImagePickerController` (`PlayNativeCameraSheet`), with the MP outline as the existing overlay. Purpose and upload-review dialogs are unchanged.
- **Album pick:** the existing coordinator path `capture(.photo, usePhotoLibrary: true)` → system `PHPickerViewController` (`PlayKitNativePhotoLibrarySheet`). **Deviation:** SwiftUI `PhotosPicker` was not used because the coordinator (Core) has no entry point for externally picked bytes, and Core behaviour may not change. `PHPickerViewController` is the same Apple picker UI and needs no library permission.
- **Scan:** live VisionKit `DataScannerViewController` through the existing `NativeQRScanner` sheet (presented `.fullScreenCover`) when `DataScannerViewController.isSupported && isAvailable`; otherwise the existing still photo + `VNDetectBarcodesRequest` path. The first code goes to the same `SUBMIT_SCAN` review.
- **Denied camera:** `ContentUnavailableView("相机权限已关闭", camera.slash)` with "去设置" (`UIApplication.openSettingsURLString`) and the photo-library fallback.
- Preview + "重拍" (retake) + "上传" (upload) + "使用" (use), with a "第 n/3 步" footer instead of the step indicator.

## Deviations / flags for the coordinator

1. **predict and branch** now ask `.confirmationDialog` before calling `prepare`, as the spec and lane brief require. `prepare` still opens the shell's review sheet, so the player confirms twice until games-a's shell decides whether the review stays for no-right-answer kits.
2. **dailysign message field kept.** The spec proposes hiding it, but owner question 3 is open and the existing submit requires non-empty text; hiding it would block the claim. Tear and scratch became one "揭开今日签" reveal tap; save goes through `ShareLink` (system sheet → Save Image), no Photos permission prompt.
3. **random:** drawn cards are list rows (latest marked "本轮") and the new draw opens a `.medium` sheet with "就这张"; that button only closes the sheet (no new request: the MP accept has no server action in the app).
4. **journey-check:** hold-to-charge became one tap (owner question 2). The D20 shows the server total as numeric text; the DC track is a system `Gauge`.
5. **photocheck RECORD mode** ("不拍照，文字确认") is not wired in the app today (`PlayKitInputContract.recordAction` has no App caller); not added, since that would be a new request path.
6. **hidden / blindtaste** are left to games-a (spec Template 1). If games-a's brief excludes them, they are unbuilt.
7. **musiccorner "继续"**: the app never had a write for it; the shell's continue covers it.
8. Old views (`coinFace`, `diceFaces`, `randomDeck`, `predictForm`, `branchForm`, `dailySignForm`, `PlayKitDailySignTicket`, `bingoBoard`, `photoCheckForm`, `scanForm`, `objectCardForm`, `PlayKitPhotoInput`, `PlayKitScanInput`, `PlayKitAlbumView`, `PlayObjectCardRevealView`, `PlayJourneyCheckView`) are no longer dispatched but were left in place to avoid touching files games-a edits. They can be retired in a cleanup pass once both lanes are merged.

## Files

- New: `App/NativeR2/Games/GamesBKitContext.swift`, `ChanceKits.swift`, `ChoiceKits.swift`, `CameraKits.swift`.
- Dispatch only: `App/PlayKitScreen.swift` (case lines), `App/PlayAdvancedView.swift` (album), `App/PlayExperienceView.swift` + `App/JourneyContentFixtureSupport.swift` (journey check).
- `tools/generate_project.py`: adds `App/NativeR2/**/*.swift` (identical line to the other native-r2 flow branches); `Questify.xcodeproj` regenerated.
- Strings: 21 keys `nativeR2.gamesB.*` in `docs/port/strings/native-r2-games-b.json`, merged into `Resources/Localizable.xcstrings`.
- `Tests/ContractChecks/test_square_journey_chat_integration.py`: the journey mount assertion now names `ChanceJourneyCheckView(model: journey`.

## Not verified

No Swift build, simulator, UI test or screenshot was run (cloud has no Xcode). The coordinator should run `build_sim` and `JourneyContentFlowTests` after merging.
