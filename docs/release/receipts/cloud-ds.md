# Cloud DS (U8 / L9)

Base: `ui/main` `72d2eb9ec498de21ded7cf9215f2638d7195786f`. Branch: `ui/cloud-ds`.

The host screens are unchanged. A primer screen is inserted before each system permission prompt, and a per-card theme edge is mounted on the chapter story cards and the locked chapter gate.

## Primer before each system prompt

`CYPermissionPrimerScreen` (`App/DesignSystem/CYPermissionPrimer.swift`) is the dark player screen. It shows `CYPermissionPrimer` for location, camera, or notification, in English and zh-Hans. Continue is the only path to the system prompt. Not now returns without asking the OS.

`CYPermissionSystemPrompt.precede` presents that screen once per kind. The XCTest host cannot tap it, so that host skips the screen and keeps the existing request. A shipping launch shows the screen first.

| System prompt | Preceded by | Where the call sits |
|---|---|---|
| Location, When In Use | `CYPermissionPrimerScreen(kind: .location)` | Roam first GO sheet in `App/RoamLiveSessionView.swift` (marks the kind primed, then start). `App/RuntimeNativeLocationProvider.swift` `currentFix` before `requestWhenInUseAuthorization`. `App/PlayNativeDeviceProvider.swift` location capture. `App/PlayKitNativeSensorProvider.swift` heading. `App/PersonalLocationShareHost.swift` before `requestForegroundAuthorization`. |
| Camera | `CYPermissionPrimerScreen(kind: .camera)` | Stamp capture sheet in `App/RoamStampCameraView.swift`, then again at `requestAccess` if the sheet did not already continue. `App/PlayKitCameraPresentation.swift`. `App/PlayKitSpatialRevealView.swift`. `App/PlayNativeDeviceProvider.swift` photo and scan. `App/NativeQRScanner.swift` `requestPermission`. Merchant evidence and club profile camera pickers call `precede(.camera)` before `UIImagePickerController` when camera access is still not determined. |
| Notifications | `CYPermissionPrimerScreen(kind: .notification)` | `App/NativeNotificationPermissionAdapter.swift` `requestFromUserAction` before `requestAuthorization`. `App/AppleLocalReminderProvider.swift` `requestPermission` before `requestAuthorization`. |

Location copy is the existing draft (light up where you walk / 点亮你走过的地方). Camera and notification cards say what the prompt is for, in English and zh-Hans. Lantern gold and violet are not used on the primer.

## CYThemeLook

`App/DesignSystem/CYThemeLook.swift`. Mood on a segment picks the edge: ink (DEFAULT and unknown), tide (BLUE / NIGHT), seal (RED / NEON), archive (YELLOW / ARCHIVE), paper (WHITE). Archive uses the muted tile orange, not lantern gold. Violet is not used.

Mounted in `App/ChapterStoryView.swift`:

- Each story segment card: `.cyThemeLook(CYThemeLook.resolve(mood: segment.mood), odd: segment.odd)` on the segment body. The segment identifier `chapterStory.segment.<id>` stays on the outer frame.
- The locked chapter gate: `ChapterGate` wraps the existing unavailable empty state and mounts `.cyThemeLook(.ink, odd: 0)`. Identifier `chapterStory.gate`. `chapterStory.body` is unchanged.

An odd level above 0 pulses the edge. Reduce Motion keeps the resting stroke and does not pulse.

`python3 tools/check_design_lint.py` PASS. `python3 tools/check_scaffold.py` PASS. RegionalLaunchConfiguration grants, money, and password were not edited.
