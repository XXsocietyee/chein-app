# Receipt · native r2 motion r2 (`native-r2/motion-r2`)

Brief: `origin/design/handoff-r2:docs/briefs/native-r2-motion-r2.md` (R1–R18), with `native-r2-motion-r1.md`,
`components-r1.md` and `COORDINATOR-HANDOVER.md` §4. Base: `origin/ui/combined-r7`.
Owner 11-27: design is not paused except the story-flow theme → **R15 skipped** (it restyles the story chapter covers).

Gate: `NativeR2Flags.motion2` = `isEnabled("nativeR2.motion2")` (`App/NativeR2/Motion/MotionR2Core.swift:11`).
`-nativeR2.motion2 NO` turns every moment off and leaves the screens as they were. Every moment checks
`accessibilityReduceMotion` (static or fade version) and is either announced to VoiceOver or a labelled element;
pure decoration (edge glow, snow, sheen) is `accessibilityHidden`. Strings: `docs/port/strings/native-r2-motion-r2.json`
(27 keys, en + zh-Hans) merged into `Resources/Localizable.xcstrings`.

**No compiler in the cloud.** Every API was checked against existing use in the repo or the iOS 17 SDK surface; iOS 18
APIs (`MeshGradient`, `.symbolEffect(.wiggle)`) are behind `#available(iOS 18, *)` with iOS 17 fallbacks
(`LinearGradient`, a `keyframeAnimator` wobble). **Needs a coordinator `build_sim`.**

## Shared pieces (`App/NativeR2/Motion/`)

| Piece | File:line | Notes |
|---|---|---|
| Flag + `MotionR2.live/announce/spring/press` | `MotionR2Core.swift:9`, `:18` | one flag; `announce` posts `AccessibilityNotification.Announcement` |
| `MotionR2Tilt` (R2/R13 helper) | `MotionR2Core.swift:51` | uses the one shared `CYTilt` CoreMotion source (30 Hz attitude), clamped ±12°; `cyTiltHold(live)` **releases the motion manager on disappear** and when Reduce Motion / Low Power / flag turns it off |
| `MotionR2HoloSheen` (R2) | `MotionR2Core.swift:79` | moving `LinearGradient` band driven by roll; reward/success only |
| `MotionR2EdgeGlow` (R8) | `MotionR2Core.swift:107` | blurred `AngularGradient` stroke on the display corner radius, 0.2 s in + 0.6 s hold + 0.35 s out; Reduce Motion = none |

## R1–R18

| # | Component | File:line | Adopted at |
|---|---|---|---|
| R1 stamp press + outline | `MotionR2StampPress`, `MotionR2ContourShape` | `MotionR2Rewards.swift:44`, `:10` | `NativeStampCaptureView.swift:134` (stamp created). Ink-press spring + `.sensoryFeedback(.impact(weight: .heavy))`, outline `trim` draw-on 1.2 s. The coordinator has no district polygon, so the outline is a contour seeded by place (stable); a real boundary can be passed as normalized points. |
| R2 spin → holo card | `MotionR2RewardReveal` | `MotionR2Rewards.swift:123` | Component ready (drag/tap spin, flip, holo + tilt). Sheen adopted on the scratch-card prize `NativeGameKitsC.swift:358` and unlocked badge detail `ProfileBadgesView.swift:105`. **Follow-up:** once `comp/r1-games` lands, wrap its `NativeGameRewardBadge` pass state in `MotionR2RewardReveal` (one line in `NativeGameHUD.swift`). |
| R3 scratch-to-win | `MotionR2ScratchTiles`, `MotionR2ScratchCoverage` | `MotionR2Games.swift:31`, `:8` | Kit: 3 `Canvas` tiles erased by `DragGesture`, `.selection` per tile, auto-complete at 60 %, VoiceOver action per tile. Existing G-004 scratch kit gets a `.selection` tick per quarter (`NativeGameKitsC.swift:340`). No 3-prize payload exists yet; the tiles are ready for one. |
| R4 snow globe | `MotionR2SnowGlobe` | `MotionR2Games.swift:125` | `NativeGameSensorKit.swift:155` ball-shake board: every CoreMotion hit (`stage.ball.hits`) stirs; flakes settle in 2.4 s; `TimelineView(.animation(paused:))` + `Canvas`, paused once settled. `stirsOnShake` uses `cyOnShake` for a gift globe. **App Clip: plan only** (below). |
| R5 tab bounce | `MotionR2TabLabel` | `MotionR2Flows.swift:11` | `QuestifyApp.swift:820` `rootTabLabel` (iOS 17 path). Behind sub-flag `nativeR2.motion2.tabBounce` **default off**: the system tab bar renders label images itself and may drop symbol effects; turn on after a simulator check. iOS 18 `Tab(…)` path unchanged. |
| R6 gift box | `MotionR2GiftBox` | `MotionR2Rewards.swift:227` | `NativeStampCaptureView.swift:212` stamp received in exchange (投一张换一张). `.symbolEffect(.wiggle)` iOS 18 / keyframe wobble iOS 17; stickers pop in. |
| R7 resizing sheet | `MotionR2PermissionSheetHost` | `MotionR2Flows.swift:36` | `CYPermissionPrimer.swift:323` — every location/camera/notification/photos priming now opens one sheet that grows from a welcome card (`.height(260)`) to the full existing primer (`.large`) via `presentationDetents(selection:)`; same copy, buttons, identifiers, continuation. |
| R8 edge glow | `motionR2EdgeGlow(when:)` / `…OnAppear` | `MotionR2Core.swift:158` | punch success `CityOrientationPunchSheet.swift:80`; payment success `PaymentProviderReturnSheet.swift:33`; finish line `CityOrientationFinishSummaryView.swift:131` |
| R9 confirm → pill | `MotionR2ConfirmPill` | `MotionR2Flows.swift:119` | `PaymentProviderReturnSheet.swift:19` (paid / registration accepted): card → top pill with `matchedGeometryEffect`, then `IslandCenter.status(.success)` when the sheet closes. |
| R10 checklist | `MotionR2Checklist`, `MotionR2ChecklistSection` | `MotionR2Flows.swift:218`, `:249` | Passport tab `AccountView.swift:54`. `Gauge(.accessoryCircular)` + rows that collapse when done. Local only (UserDefaults), marked at: punch `CityOrientationPunchSheet.swift:78`, stamp `NativeStampCaptureView.swift:82`, club join `ClubHomeView.swift:367`, story stage completed `NR2StageResultSheet.swift:103` (a mark call only; no story styling). |
| R11 mood gradient | `MotionR2MoodGradient`, `MotionR2MoodHero` | `MotionR2Metrics.swift:27`, `:63` | Finish summary hero `MotionR2Hooks.swift:8` → `CityOrientationFinishSummaryView.swift:54`. `MeshGradient` iOS 18, `LinearGradient` fallback, `.numericText`. |
| R12 flame fill | `MotionR2FillGauge` | `MotionR2Metrics.swift:99` | same finish hero: route completion fills `flame.fill` (`Canvas` masked by the symbol). |
| R13 tilt | `motionR2Tilt()` | `MotionR2Core.swift:148` | stamp detail `RoamStampViews.swift:543`, badge detail `ProfileBadgesView.swift:106`; reward card. |
| R14 rank change | `MotionR2RankText`, `motionR2RankMoves` | `MotionR2Metrics.swift:162`, `:194` | finish ranking `CityOrientationFinishSummaryView.swift:204`, `:226` (rank rolls + ↑/↓, rows move with the spring). Passport has no friends-by-places read; nothing new was requested. |
| R15 magazine stack | — | — | **Skipped**: story-flow theme is paused (owner 11-27). |
| R16 capture menu | `MotionR2CaptureMenu` | `MotionR2Flows.swift:308` | punch sheet task section `CityOrientationPunchSheet.swift:262` (photo / scan / task — the entries the stop already offered; nothing new is sent). |
| R17 clean load | `motionR2LoadIn(loading:)` | `MotionR2Metrics.swift:230` | passport overview `PassportView.swift:101` (redacted skeleton → fade). No Swift Charts in the player flows to animate. |
| R18 plan morph | `MotionR2PlanSymbol` | `MotionR2Metrics.swift:237` | membership card `PassMembershipViews.swift:243` (`.contentTransition(.symbolEffect(.replace))` by plan position). |

## R4 App Clip — plan only (owner: build after the player launch)

1. New target `ChengyinClip` (bundle `<app id>.Clip`), shares `Core/` read-only sources; 15 MB (iOS 17) limit, no
   merchant code. Associated domain `appclips:<host>`; App Clip experiences registered in App Store Connect for
   `https://<host>/clip/invite/<code>` and `https://<host>/clip/stop/<id>`.
2. **Team invite accept:** the clip opens on the invite URL, signs in with Sign in with Apple (ephemeral), calls the
   existing invite accept endpoint, shows the team + "Get the full app" (`SKOverlay.AppClipConfiguration`).
3. **Stop / venue QR check-in:** QR at a stop opens `…/clip/stop/<id>`; the clip reads location once
   (`APActivationPayload.confirmAcquired(in:)` for the region) and calls the existing arrival endpoint; result card
   + island-style success.
4. Hand-off: the full app reads the clip's App Group container (`group.com.chengyinhub.chengyinApp`, the C2 group)
   for the session token and the pending invite.
5. Coordinator/owner: App ID + App Clip capability, App Group, associated domains file on the host, App Store
   Connect experiences, provisioning profiles. Separate post-launch lane.

## Strings
`docs/port/strings/native-r2-motion-r2.json` → `Resources/Localizable.xcstrings` (+27, `motion2.*`, en + zh-Hans).

## Gates
`python3 tools/generate_project.py` run for the 6 new files. `check_scaffold.py` PASS structural checks;
`check_a11y_lint.py` PASS (0 new); `contract_ratchet.py --check`: see the commit message.

## Compile risks to look at first
- `MotionR2PermissionSheetHost`: `.sheet(isPresented:)` presented from the root of a fresh `UIHostingController`
  window (clear background when the flag is on).
- `MotionR2GiftBox.box`: `if #available(iOS 18, *), live { … .symbolEffect(.wiggle, value:) }`.
- `MotionR2MoodGradient.mesh`: `MeshGradient(width:height:points:colors:)` with `[SIMD2<Float>]`.
- `MotionR2CaptureAction(...) { … }` trailing closure for the memberwise `perform`.
- `ClubHomeView.joinInline` Task calls `MotionR2Checklist.shared.mark` (`@MainActor`) — fine if the view is main-actor
  isolated (Xcode 16 SDK `View`); otherwise add `await`.
