# Fix r11 · lane roam — receipt

Brief: `origin/design/handoff-r2:docs/briefs/fix-r11.md`. Slice: `origin/audit/parity-r11-play-roam:docs/audit/parity-r11/play-roam.md` §4 fix queue (all rows).
Branch `fix/r11-roam` from `origin/ui/combined-r7` (`b9a9d4d29`). Not compiled (no Swift toolchain in the cloud). Every type and member was grepped before use.

Gates at the last push: `check_scaffold.py` PASS structural checks · `check_a11y_lint.py` PASS (0 new) · `contract_ratchet.py --check` new 0 (see the final push note at the end).

## P1

| id | status | SHA | app file:line | note |
|---|---|---|---|---|
| JLAND-r11-1 | fixed | `ca17ffc3e` | App/MPParityKit.swift:14 (`seatClaimsEnabled`); App/PlayerJourneyReadBindings.swift:95 (`claimAllowed`); App/JourneyLandingViews.swift:354 | Seat claim and the seat 查询领取结果 re-check are live; the saved request id is reused. |
| CAP-r11-1 | fixed | `099b071d7` | Core/PlayContentCompatibility.swift:91, :104 | `branch`, `line`, `role.views` declared; 4 tests flipped to assert presence (PlayClientCapabilitiesTests, HangmanPoolTests, PlayFullStoryH3Tests). |
| START-r11-1 | fixed (default run path) | `90991d5c2` | App/NativeR2/CityOrientation/CityOrientationPunchSheet.swift:109, :332; Core/PlayArrivalService.swift (`startChoices`, `arrive(…start:)`); Core/PlayExperienceCoordinator.swift (`runStartModesAvailable`, `review(…start:)`); Core/PlayRecoveryStorage.swift (`PlayCompletionIntent.startFields`); Core/PlayExperienceService.swift (`completionRequest(…start:)`) | 换个方式开局 `confirmationDialog` after a refused start: 改在「X」开局 per alt station, then 桌面完成 with the 不用到现场… alert. `startMode`/`altStationId` are journaled on the intent (old journals decode nil, request unchanged) and merged only into `/api/play/arrive`. DESK sends no fix; ALT skips the local 300 m precheck (server judges the alt radius). Offered on the default `CityOrientationRunView` punch sheet; the legacy flag-off `PlayArrivalControl` path does not show it. |
| BGPAUSE-r11-1 | fixed | `8d88ee468` | App/PlayExperienceView.swift:298 | scenePhase pause removed. `PlaySessionLocationHold` unchanged (foreground-only hold). The run clock anchors on `systemUptime`, which does not advance while the device sleeps; server time stays authoritative. |
| JREF-r11-1 | fixed | `f4e46b23b` | Core/JourneyLoopSource.swift (`issueReferralToken`); Core/ChinaReviewedRouteCapability.swift (`journeyReferralOwnerGrant`); App/PlayerJourneyReadBindings.swift:437, :665; App/JourneyReportViews.swift (`JourneyIssuedShareButton`) | Issued only on the share tap, `{targetType, targetId}`; follows `ReleaseMoneyWriteSwitch.payoutEnabled` (money ON). The share button then opens the system share sheet with the `k=r&t=` landing link, or the topic link if the issue fails. The legacy sync `issueReferral` still throws (tests pin it). |
| ZEROHP-r11-1 | fixed (STEPS: owner) | `ca0f3dae2` | App/PlayThemeBackpackView.swift:466 (auto-sync), `zeroRecovery`, `syncZeroHP`; Core/PlayThemeBackpack.swift (`ZeroHP.canSync/deadlineAt/secondsLeft`); Core/PlayRuntimeGap.swift (`zeroHPSyncCommand`) | 同步恢复状态 `Button` + `TimelineView` countdown (预计) + one auto-sync at the deadline. Unknown result resends the kept command. STEPS (WeRun) is WeChat-only: policy text only, owner/server decision. |
| ROAM-r11-2 | fixed | `e696328d5`, `bf25b944c` | Core/RoamOfficialTasks.swift (load); Core/OfficialEventService.swift:41; Core/OfficialEventReading.swift:37; Core/OfficialPublicEventReadSource.swift; App/GlobalSearchLinksAndTemplates.swift:414 | 全部 reads `GET api/official/active-for-roam`, guests included; 我的 only with a session, filtered to the roam list (MP index.js:51-52). Tests updated: RoamOfficialTasksLifetimeTests, OfficialPublicEventReadRouteTests, OfficialPublicEventCompositionTests. |
| ROAM-r11-3 | partly | `94460e6a3`, `718f9b53c` | App/RoamLiveSessionView.swift:244, :1386; Core/RoamContracts.swift (`RoamPlace.nodeLevel`) | Non-fog live map draws the session's places as `Marker`s with a level symbol + tint; tapping one raises the sheet and expands 附近. Photo pins (`Annotation` with the cover) not added: remote cover images go through the app's media allowlist, left for a follow-up. |
| PLAY-r11-1 | open | — | App/PlayExperienceView.swift:68 (`playBGMOn`) | Not done. The app's audio path (`PlatformAudioPlayback` + `NativePlatformAudioDriver`) has no loop, volume or duck control, and plays only approved-origin, consented sources. Theme/station BGM needs a driver extension (loop, 0.25/0.35 volume, duck to 0.1/0.14 under narration) — M, next round. |
| VIDEO-r11-1 | open | — | — | Not done. Needs `videoUrl`/`videoPosterUrl` decode + AVKit `VideoPlayer` cover with the media allowlist; M, next round. |
| ROAM-r11-1 | open | — | App/OfficialActionViews.swift:356; App/OfficialOrganizerConsoleView.swift:539-543 | Not done (L, split routing + in-roam arrival list). |

## P2

| id | status | SHA | app file:line | note |
|---|---|---|---|---|
| PLAY-r11-2 | fixed | `50938b66e` | App/MPGap/PlayRoam/PlayToolsAndLeadSheetView.swift:146; Core/PlayExperienceContracts.swift:221 | 证据卡 `NavigationLink` → `List` (station name + passText of finished stations) in the 游玩工具 sheet. |
| PLAY-r11-3 | fixed | `6151d0441` | Core/PlayGameStage.swift:109; App/PlayGameStageViews.swift:163 | `PlayStageAnalyticsGate.enabled = true`; 已记录 toast. Pinned tests flipped (6 Swift files + test_roam_entry_nearby_production.py). |
| JLAND-r11-2 | fixed | `972da8ea2` | Core/JourneyLoopSource.swift:255 (`giftClaimLive`); App/MPParityKit.swift:18; App/PlayerJourneyReadBindings.swift:116 | Same `/api/marketing/product/gifts/claim {token, requestId}` as the market gift page (owner rule 2026-11-25: not money); request id kept for 查询领取结果. `MPCommerceGate.claimsEnabled` stays false for the other surfaces. |
| JPROMO-r11-1 | fixed | `e9f5e2efa` | App/JourneyLandingViews.swift:1027 | Footer removed. |
| OCARDS-r11-1 | fixed | `a53b96a66` | App/ObjectCardViews.swift:178, :369; App/ObjectCardPileView.swift | Session-wide `ObjectCardTitleOverrides` feeds the tile and pile; 已改名 toast. |
| SCAM-r11-1 | fixed | `e8039431d` | App/RoamStampCameraView.swift:173 | On the P3 route (no exchange) a created stamp toasts 已入册 and pushes the album after 600 ms (push, not a stack replace). |
| TGOALS-r11-1 | fixed | `1da45f274`, `cc829efab` | App/RoamPassportPrivateToolsViews.swift:841 | Create writes at once; cancel message adds 此操作不可撤销. `tools/check_roam_private_tools.py` updated with the MP citation. |
| RPOI-r11-1 | fixed | `7cd8ea68e` | App/RoamItemDetailView.swift:551 | New key `roam.detail.title` (据点详情 / Spot details); `roam.detail` (据点) unchanged elsewhere. |
| N-r11-1 | fixed | `797e3615f` | App/PlayExperienceView.swift:2047 (`PlaySystemConfirm`) | The four play confirms are system `.alert`s; identifiers kept. |
| ROAM-r11-4 | open | — | App/MPGap/PlayRoam/RoamSessionToolsSheetView.swift:66-94 | Not reached. |
| ROAM-r11-5 | open | — | App/RoamLiveSessionView.swift:323, :342 | Not reached; needs a `POST /api/roam/presence-visibility` client (only the offline-queue entry exists). |
| ROAM-r11-6 | open | — | — | Not reached; which native local roam stores map to the MP `roamMemory.clearLocal` needs a Core decision (risk of dropping unsynced writes). |
| ROAM-r11-7 | open | — | — | Not reached. |
| ROAM-r11-8 | open | — | — | Not reached. |
| ROAM-r11-9 | open | — | — | Not reached. |
| ROAM-r11-10 | blocked (device) | — | App/RoamHistoryViews.swift | Needs on-device verification. |
| N-r11-2 | blocked (owner) | — | — | Owner decision on `MapUserLocationButton` / pinned `test_map_camera_controls`. |
| N-r11-3 | open | — | — | Not reached. |
| N-r11-4 | open | — | — | Not reached. |
| N-r11-5 | open | — | — | Not reached. |
| N-RSESS | blocked | — | App/RoamHistoryShareView.swift:49 | Design-system follow-up (coordinator), with ROAM-r11-9. |

No row in this slice is merchant-only.

## Compile risks to check first

- `CityOrientationStartModeDialogs` (`ViewModifier`, `@MainActor`) in CityOrientationPunchSheet.swift; `PlayCompletionReview.init(…startFields:)` default param.
- `Map(initialPosition:selection:)` with `ForEach` + `if let` + `.tag(place.id)` in RoamLiveSessionView.swift.
- `JourneyIssuedShareButton` / `JourneyActivityShareSheet` (UIKit) in JourneyReportViews.swift; `onIssueShare: (@MainActor () async -> URL?)?` memberwise params.
- `PlaySystemConfirm` memberwise init argument order (isPresented, title, message, cancelTitle, confirmTitle, isDestructive, confirmIdentifier, onCancel, onConfirm).
- `ObjectCardTitleOverrides` (`@Observable` without `import Observation`, same as App/AccountCollectionFixtureSupport.swift).
