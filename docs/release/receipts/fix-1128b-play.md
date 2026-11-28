# fix/1128b-play — play fix worker, second wave (2026-11-28)

Base: `origin/ui/combined-r7` @3348aa51f. Plan: `origin/audit/1128-plan:docs/audits/1128-plan.md` gaps #5, #15, #16, #19,
#20, #21, #22 (journey domain rows J-03, J-05a/b, J-06d/f, J-07 #2/#3/#6/#7, J-09d/e/f/i, J-11a/b/c, J-12b, J-17, J-19).
Behaviour reference: MP `chengyinhub-xcx` (hengyin `origin/us/r3-functional`). Backend routes are those in
`ApiPlayProgressController.java` (`/api/play/ending` :96, `/leaderboard` :387, `/preference/{nodeId}` :220,
`/preference/{nodeId}/submit` :228, `/tag/{id}/confirm|correct|revoke` :236-252, `/os/{topicId}` :260, `/photo` :355).

Root cause, as the audit found: the features existed and matched the backend, but the Release composition never switched
them on. Each gap below switches the service on in the shipped China composition, keeps merchant routes off, and is
proved by `Tests/AppUnitTests/Fix1128bPlayReleaseCompositionTests.swift`, which builds
`RegionalLaunchConfiguration.shippedComposition` (→ `reviewedComposition` → `reviewedDeployment`).

No Swift compiler in this environment: the Swift tests are written, not run. The Swift-free gates are green (below).

## Gaps

| Gap | What changed | Files | Proof |
|---|---|---|---|
| **#5** Photo tasks (J-06d, J-12b, J-07 #3, J-11c) | `playConfiguration` passes `devices: [.photo, .scan, .location, .motion]` (`playDevices`); `.mediaUpload` joins `playCapabilities`; `api/common/uploadOSS` joins `playPaths` (via `playFinishAndProfilePaths`). The photo kind is now supported by `PlayNativeDeviceProvider`, `playDevice(...)` gets an uploader, and `POST api/play/photo {activityId\|topicId,nodeId,picUrl}` already matched. | App/ReviewedPlayerWriteLeases.swift (`playCapabilities`, `playDevices`, `playFinishAndProfilePaths`, `playConfiguration`) | `testReleasePlayConfigurationTurnsOnPhotoUploadPreferenceTagsAndArtwork` |
| **#15** Operator notes (J-19) | New `PlayerRuleText.strippingOperatorNotes` / `playerVisible`, a port of MP `utils/rule-steps.js` `stripOperatorNotes` (same regex). `PlayNode.playerRuleInstructions` and `PlayRandomDispatchedTask.playerRuleInstructions`. Every player rule render uses them: FreeExplorationViews (random task, merchant step, hero how-to), PlayExperienceView (random task, node rule), PlayNodeDetailView (task section), and the store-day `rule` (PlayStoreDayPresentation). Raw `ruleInstructions` stays for authoring/review screens. | Core/PlayerRuleInstructions.swift (new), App/FreeExplorationViews.swift, App/PlayExperienceView.swift, App/PlayNodeDetailView.swift, Core/PlayStoreDayPresentation.swift | Tests/CoreTests/PlayerRuleInstructionsTests.swift |
| **#16** Finish ending + ranking (J-05a/b, J-09f) | `api/play/ending` and `api/play/leaderboard` in `playPaths`. `loadEndingAndLeaderboard` is soft for both reads (MP mode 1 has no ending card; MP board shows `board.error` in place): a failure sets `leaderboardUnavailable` instead of `fail()`. Unauthorized / stale session still go through `fail` (sign-out). P30 finish screen: the ranking preview loads once on open (player row pinned, as before), a failure shows "榜单加载失败，本局成绩已保留" above the retry row; the record, metrics, share and Done stay. | App/ReviewedPlayerWriteLeases.swift, Core/PlayExperienceCoordinator.swift, App/NativeR2/CityOrientation/CityOrientationFinishSummaryView.swift, Resources/Localizable.xcstrings (`playx.leaderboard.unavailable`) | composition test (paths + live send of `ending`, `leaderboard`) |
| **#19** Templated play paths (J-06f, J-09d/e/i) | `RuntimeDependencyTransport.send` keeps the literal match and adds `RuntimeDependencyTransport.admits`: an approved `…/{}/…` path matches when the request fills each `{}` with a numeric/opaque id (`ChinaReviewedRouteCapability.normalized`, as `isPlayGrantPath`). Requests that spell braces, `.` or `..` never match. Added `api/play/preference/{}`, `…/{}/submit`, `api/play/tag/{}/confirm\|correct\|revoke`, `api/play/os/{}`; `.preference` and `.tags` capabilities. The composition lease admits the two bodiless tag writes (`isBodilessPlayTagWrite`, POST, empty body). | Core/RuntimeDependencyConfiguration.swift, App/ReviewedPlayerWriteLeases.swift | `testRuntimeTransportMatchesTemplatedPlayPathsOnly`, `testShippedRuntimeTransportSendsFinishPreferenceTagOSAndConsentRoutes` |
| **#20** Chapter finish error sheet (J-03, J-17) | The stage-settlement trigger now requires `narrativeModel(.stage).available` (= `readsEnabled` and a session). Release keeps journey reads off, so no sheet opens on a chapter finish. The story-flow theme itself is untouched (still paused). | App/PlayExperienceView.swift | static (view) |
| **#21** In-store (探店日) tasks (J-11a/b/c) | `PlayStoreDayService` is built with `MerchantCityNPCParityGates.playStoreDay` (proof + consent writes on, plus a player-only `storeDayPlayerEndpoints` allowlist: `api/play/checkin`, `arrive`, `photo`, `answer`, `api/compliance/consents`). Merchant gates (`mpFirst`) never set it. `api/compliance/consents` and `…/latest` joined `playPaths`. New `PlayStoreDayCapturingEvidenceSource` + `PlayStoreDayDeviceEvidence` (App) runs the scanner, or the camera + uploadOSS, on the player's tap (MP `scanCode` / `takePhoto` → `uploadProof`), then the existing confirm alert and write run; a cancelled capture is silent, a failed one shows the MP "no code / no photo" notice. Copy: the bottom 地址 control reads "导航去这里" / "Navigate here" (MP `mp-cta__ghost` aria-label). | Core/MerchantCityNPCParityGates.swift, Core/PlayStoreDayCoordinator.swift, App/PlayStoreDayDeviceEvidence.swift (new), App/AppSession.swift (2 lines changed, no growth), App/SessionPlayRuntimeView.swift, App/PlayStoreDayMerchantView.swift, Resources/PlayStoreDay.xcstrings (`playStoreDay.cta.navigateHere`) | `testStoreDayGatesOpenProofAndConsentWritesForThePlayerOnly` |
| **#22** Kit artwork (J-07 #2/#6/#7) | `artworkHosts` = bare hosts of `RetainedImageOrigin.configured(apiBase:extra: CYStampImageOrigins)`, the same origins as the avatar approval (`playArtworkHosts`; non-443 ports and plain http dropped). `CYStampImageOrigins` is now an Info.plist key fed by the owner placeholder `QUESTIFY_IMAGE_ORIGINS`. | App/ReviewedPlayerWriteLeases.swift, Config/Info.plist, Config/OwnerValues.xcconfig, docs/release/owner-values.md | composition test (`playArtworkHosts`) |

## Contract tests updated (deliberate behaviour changes)

- `Tests/ContractChecks/test_w2_19_playMerchant.py`: the store-day factory now builds `gates: .playStoreDay` (gap #21).
- `Tests/ContractChecks/test_fix_r8_mp_first_pc.py`: `playConfiguration` now passes devices and artwork hosts (gaps #5/#22).
- `Tests/ContractChecks/test_play_gameplay_mode_separation.py`: 5 children bound to a read lifetime (the store-day evidence device, gap #21).
- `Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift`: the pinned play capability set adds `.mediaUpload, .preference, .tags`.

## Gates

`python3 tools/generate_project.py`, `python3 tools/check_scaffold.py` (AppSession ratchet PASS),
`python3 tools/contract_ratchet.py --check` (new 0), `python3 tools/check_design_consistency.py`,
`python3 tools/check_a11y_lint.py` — results in the commit that adds this receipt.

## Owner actions

1. `QUESTIFY_IMAGE_ORIGINS` (Config/OwnerValues.xcconfig): add the OSS/CDN origin(s) uploadOSS returns, so photo proofs
   and kit artwork served from the bucket load. Until then only the API host (`www.chengyinhub.com`) is approved.
2. Device test on a CN build: a photo node (vm 2), the filter camera, and the 探店日 page scan → confirm → `api/play/checkin`,
   photo → uploadOSS → `api/play/photo`, consent agree/revoke.
3. Story-flow theme stays paused; journey reads stay off. If the owner later turns journey reads on, the stage-end sheet
   returns by itself (gap #20 gate).
4. Not done here (other lanes / not in this worker's list): sensors (`.acceleration`, `.microphone`), advanced
   state/leaderboard, puzzle hint, egg collect, club-lead routes, circle.
