# Receipt: native-r2/flow-games-b (games templates 4–6)

Branch: `native-r2/flow-games-b`, cut from `origin/ui/combined-r7` (`2446657fb`). Held until owner approval.
Spec: `docs/design/native-r2/games.md` on `design/native-r2-games` (`23fed2028`). Brief: `docs/briefs/native-r2.md` (EVERYTHING native).

No compiler in the cloud: every type, init and modifier was grepped in the repo or is a stock SwiftUI / VisionKit API available on the iOS 17 deployment target. `python3 tools/check_scaffold.py` prints `PASS structural checks`. Contract checks (`python3 -m unittest discover -s Tests/ContractChecks`): no new failures against `origin/native-r2/flow-games-a` (base 142 failures / 106 errors, this branch 141 / 106; all pre-existing).

## Shell (uses games-a's `NativeGameShell`)

The first push (`a36533ee2`) was written before games-a existed, against a minimal host contract. games-a then pushed `native-r2/flow-games-a` (`878591d04`) with `NativeGameShell` and a `NativeGameKits.templateB` hook, so this branch **merged `origin/native-r2/flow-games-a`** and now draws every B kit inside that shell. No second shell type exists (no `NativeGameShellB`).

- `App/NativeR2/Games/NativeGameKitsB.swift`: `NativeGameKitsB.kinds` (photoCheck, scan, coinFlip, diceRoll, random, branch, musicCorner, dailySign, hiddenObject, blindTaste), `nativeControlsB` (dispatch) and `nativeKitSubmitB` (the shell's one bottom `.borderedProminent` button: flip, roll, draw, accept the daily sign, submit blindtaste).
- Three one-line hooks in games-a's `NativeGameScreenHost.swift`: `templateB` returns `NativeGameKitsB.kinds`; `nativeControls` and `nativeKitSubmit` fall through (`default:`) to the B members.
- `GamesBKitContext` stays as the small value the B structs read (segment, projection, `enabled`, `busy`, selection/text bindings, `markDirty`, and `nativePrepare` as the review outlet, so a fresh verdict opens the shell's result sheet).
- Everything is behind games-a's `NativeR2Flags.games`. Flag off: `PlayKitScreen.content` is untouched (old kit UI), and album / journey-check switch back to `PlayKitAlbumView` / `PlayJourneyCheckView` at their hosts.
- predict and bingo are drawn by games-a (its Template 1/2); the B versions were dropped. hidden and blindtaste, which games-a's receipt hands to half B, are built here.
- Inside a `List`, modifiers on a multi-row `Section`/`Group` apply to every row. Dialogs, `fullScreenCover`, `onAppear { model.cancel() }`, `cyOnShake` and haptics therefore sit on exactly one row per kit (capture/scan rows are one `VStack` row).

## Camera specifics

- **System camera:** the existing `PlayDeviceCaptureCoordinator.capture(.photo, cameraFrame:)` → `UIImagePickerController` (`PlayNativeCameraSheet`), with the MP outline as the existing overlay. Purpose and upload-review dialogs are unchanged.
- **Album pick:** the existing coordinator path `capture(.photo, usePhotoLibrary: true)` → system `PHPickerViewController` (`PlayKitNativePhotoLibrarySheet`). **Deviation:** SwiftUI `PhotosPicker` was not used because the coordinator (Core) has no entry point for externally picked bytes, and Core behaviour may not change. `PHPickerViewController` is the same Apple picker UI and needs no library permission.
- **Scan:** live VisionKit `DataScannerViewController` through the existing `NativeQRScanner` sheet (presented `.fullScreenCover`) when `DataScannerViewController.isSupported && isAvailable`; otherwise the existing still photo + `VNDetectBarcodesRequest` path. The first code goes to the same `SUBMIT_SCAN` review.
- **Denied camera:** `ContentUnavailableView("相机权限已关闭", camera.slash)` with "去设置" (`UIApplication.openSettingsURLString`) and the photo-library fallback.
- Preview + "重拍" (retake) + "上传" (upload) + "使用" (use), with a "第 n/3 步" footer instead of the step indicator.

## Deviations / flags for the coordinator

1. **branch** asks `.confirmationDialog` before calling `prepare` (spec + lane brief), so its confirm button stays inline in the kit and the shell's bottom bar is empty for branch. `prepare` still opens the review sheet, so the player confirms twice; drop one when the coordinator decides.
2. **dailysign message field kept.** The spec proposes hiding it, but owner question 3 is open and the existing submit requires non-empty text; hiding it would block the claim. Tear and scratch became one "揭开今日签" reveal tap; save goes through `ShareLink` (system sheet → Save Image), no Photos permission prompt.
3. **random:** drawn cards are list rows (latest marked "本轮"). The spec's drawn-card sheet with "就这张" was dropped: the shell's own result sheet opens after a draw, and two sheets would collide; "就这张" had no server action anyway.
4. **journey-check:** hold-to-charge became one tap (owner question 2). The D20 shows the server total as numeric text; the DC track is a system `Gauge`.
5. **photocheck RECORD mode** ("不拍照，文字确认") is not wired in the app today (`PlayKitInputContract.recordAction` has no App caller); not added, since that would be a new request path.
6. **blindtaste** has no hold-to-close-eyes ritual in the app today; the three steps are numbered `Label` rows.
7. **musiccorner "继续"**: the app never had a write for it; the shell's continue covers it.
8. Old views stay as the `NativeR2Flags.games == false` path (games-a's rule) and can be retired once the owner signs off.
9. Camera, scan, branch confirm and the journey-check buttons keep their primary action inside the kit (multi-step capture, a dialog, a coordinator outside `PlayKitScreen`); chance/dailysign/blindtaste use the shell's bottom bar.

## Files

- New: `App/NativeR2/Games/NativeGameKitsB.swift`, `GamesBKitContext.swift`, `ChanceKits.swift`, `ChoiceKits.swift`, `CameraKits.swift`.
- Hooks: `App/NativeR2/Games/NativeGameScreenHost.swift` (3 lines, games-a's file); flag switches in `App/PlayAdvancedView.swift` (album), `App/PlayExperienceView.swift` + `App/JourneyContentFixtureSupport.swift` (journey check). `App/PlayKitScreen.swift` is as games-a left it.
- `tools/generate_project.py` as on games-a (`App/NativeR2/**/*.swift`); `Questify.xcodeproj` regenerated.
- Strings: 17 keys `nativeR2.gamesB.*` in `docs/port/strings/native-r2-games-b.json`, merged into `Resources/Localizable.xcstrings`.

## Not verified

No Swift build, simulator, UI test or screenshot was run (cloud has no Xcode). The coordinator should run `build_sim` and `JourneyContentFlowTests` after merging.
