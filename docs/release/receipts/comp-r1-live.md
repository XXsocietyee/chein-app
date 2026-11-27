# Receipt — components r1, lane C1 live (`comp/r1-live`)

Brief: `origin/design/handoff-r2:docs/briefs/components-r1.md` (lane C1). Base: `origin/ui/combined-r7`.
Scope: Live Activities + Dynamic Island only. Apple components only (ActivityKit, App Intents, SF Symbols,
system fonts, `Text(timerInterval:)`, `ProgressView`). No story-flow theme work. Nothing here was compiled
(no Xcode in the cloud) — the coordinator's `build_sim` is the first compile.

## What was added

### Content / attributes (extended compatibly)
- `Core/QuestLiveActivityContent.swift:11` — new kind `QuestLiveActivityKind.event`. Older encoded kinds still decode.
- `Core/QuestLiveActivityContent.swift:37` — new **optional** `ContentState` fields `deadline`, `arrived`, `score`,
  `rank`, `startsAt`; the memberwise init gains defaulted params at the end (existing call sites unchanged). Content
  encoded by an older build decodes (test `testContentEncodedByAnOlderBuildStillDecodes`).
- `Core/QuestLiveActivityContent.swift:63-80` — `deadlineInterval(now:)`, `startInterval(now:)` (both feed
  `Text(timerInterval:countsDown: true)`), `runToggle(kind:)` (pause / resume / hidden).
- `QuestLiveActivityText.rank(_:)` (`#3`), `QuestWidgetLinks.wallet` (`chein://mp/subpackageMember/signup/index`,
  票夹 — no ticket id in the activity), `liveActivity(.event) → wallet`.
- `Core/QuestLiveActivityContent.swift:215` — `QuestLiveActivityAttributes.place: String?` (optional; init default nil).
- `Core/QuestLiveActivityMapping.swift:8` — `QuestLiveActivityDescriptor.place` (defaulted).

### Event "Starts in mm:ss · 加入" countdown activity
- `Core/QuestLiveActivityMapping.swift:82-115` — pure `QuestLiveActivityMapping.event(tickets:now:)`: soonest wallet ticket
  (MP `usableTicket`, F13) not yet verified whose `usableFrom` (else owner `startDate`) **has a time of day** and lies in
  `[now − 30 min, now + 3 h]`. Date-only starts never count down. Nothing in the window ends the activity.
- `App/QuestLiveActivityCenter.swift:91` `eventCountdown(tickets:)` — fed from `App/TicketWalletView.swift:169` when the
  wallet read finishes (the point the app already has). `staleDate = startsAt`, so at the start the views read 已开始.
- `App/QuestLiveActivityCenter.swift:180` — relaunch keeps an event countdown still inside its window (runs are still
  ended as orphans, as before).
- Views: `LiveActivityWidget/QuestLiveActivityWidget.swift:371` `QuestLiveActivityJoinRow` ("距开始 mm:ss" + 加入 capsule
  `Link` to 票夹), clock / compact trailing count down with `Text(timerInterval:countsDown: true)`, venue in header and
  expanded centre, glyph `calendar.badge.clock`, accent tint.

### Navigation / orientation run
- Arrival: `App/NativeR2/CityOrientation/CityOrientationRunView.swift:104` passes the existing 50 m highlight
  (`PlayArrivalPolicy.stationHighlightMeters`, MP `STATION_HIGHLIGHT_METERS`) as `arrived`; the island shows
  "已到达 · <stop>", a green `checkmark.seal.fill` compact value and the 打卡 button.
- Next stop + distance: unchanged (native r2 M4), still shown.
- Deadline countdown: supported (`deadline` field, `QuestLiveActivityRunExtras` at
  `LiveActivityWidget/QuestLiveActivityWidget.swift:344`) but **not fed**: the MP has no orientation run deadline, and
  `PlayRouteResult.expiresAt` is documented "kept verbatim, never infer expiry from local parsing". Whoever gets a
  server deadline with a server clock can set it; the view is ready.

### Game runs (timer, score, rank)
- Timer: unchanged (count-up system timer).
- `Core/QuestLiveActivityMapping.swift:57` `play(…, score:, rank:)` (defaulted); `Core/PlayExperienceCoordinator.swift:120`
  passes `leaderboard?.me.score / rank` (`PlayCompanionLeaderboard.me`, MP orient leaderboard). The board is read after
  completion (`loadEndingAndLeaderboard`), so `Core/PlayExperienceCoordinator.swift:779` republishes and
  `App/QuestLiveActivityCenter.swift:240` `refreshEnded` re-ends the just-ended activity so its final Lock Screen card
  shows 得分 / 排名.

### Interactive buttons (App Intents)
- `Core/QuestLiveActivityIntents.swift` (new, shared into app **and** widget extension via
  `tools/generate_project.py:28`):
  - `QuestLiveActivityRunToggleIntent: LiveActivityIntent` — pause / resume a roam walk or orientation run (runs in the
    app process, no foreground).
  - `QuestLiveActivityCheckInIntent: AppIntent` (`openAppWhenRun = true`) — 打卡 opens the app on the current stop's
    punch sheet (scan / photo evidence stays in the app; nothing is submitted from the Lock Screen).
  - `QuestLiveActivityActionRouter` — the app installs the handler (`App/QuestLiveActivityCenter.swift:35`); an unhandled
    check-in waits until the run screen registers (`setCheckInHandler`, `App/QuestLiveActivityCenter.swift:50`).
- Actions call exactly the in-app paths: play `pauseRun` / `startRun` (`PlayExperienceView.cityRunPrimary`), roam
  `pause()` / `resume(purposeAccepted: true)` (`CityLiveOnMap`), guarded by phase and `canManageRun`.
- Run owners are attached on the existing AppSession lines (`App/AppSession.swift:1336`, `:6196`, same line — glue ratchet
  unchanged).
- Open: the event 加入 is a `Link`; runs keep `widgetURL` (roam tab / stay where the run is).
- `LiveActivityWidget/QuestLiveActivityWidget.swift:403` `QuestLiveActivityActionRow` — bordered buttons, keyline tint,
  VoiceOver labels; Lock Screen surface is dark high-contrast (`activityBackgroundTint`, `.colorScheme(.dark)`).

### Strings
- Widget catalog `LiveActivityWidget/Localizable.xcstrings`: `liveActivity.event.{title,startsIn,started,join}`,
  `liveActivity.play.{arrived,deadline,score,rank}`, `liveActivity.action.{checkIn,pause,resume}`, `liveActivity.intent.*`.
- App catalog `Resources/Localizable.xcstrings`: `liveActivity.intent.*` (intent metadata resolves in the app process).

### Tests
- `Tests/AppUnitTests/QuestLiveActivityComponentsTests.swift` — event window / date-only / verified / grace, old-content
  decode, run toggle, deadline interval, rank text, router pending rules.

## MP references
- 票夹 usable tickets and order: `subpackageMember/signup/index.js` (`usableTicket`, `walletOrder`, `startTag`) via
  `Core/TicketWalletContracts.swift`.
- Arrival highlight 50 m: MP `pages/play/utils/arrival-radius.js` (`STATION_HIGHLIGHT_METERS`).
- Orientation score / rank: `subpackageMember/orient-score` + play leaderboard (`PlayCompanionLeaderboard`).
- No run deadline in MP orientation pages (only the dispute-window deadline on the score page).

## Gates (before push)
- `python3 tools/check_scaffold.py` — PASS structural checks.
- `python3 tools/check_a11y_lint.py` — PASS, 0 new.
- `python3 tools/contract_ratchet.py --check` — new 0 (104 failing vs baseline 105, fixed 1 is pre-existing).
- `python3 tools/check_appsession_ratchet.py` — PASS (AppSession 7979, unchanged).
- `python3 tools/generate_project.py` — regenerated (intents file in both Questify and QuestifyLiveActivity source phases).

## Coordinator to-do
- **Compile + device check**: `build_sim`; on device confirm the 打卡 `AppIntent` with `openAppWhenRun` runs in the app
  process (if it runs in the extension, the router has no handler and nothing happens — fallback is to turn it into a
  `Link` with a `chein://` route).
- No new capability or profile needed for this lane (`NSSupportsLiveActivities` already set; App Intents need no
  entitlement). The App Group (lane C2) is unrelated to Live Activities.
- Event countdown and island behaviour stay behind the existing `nativeR2.island` flag.
- Lane overlap: `QuestLiveActivityCenter.swift` / `QuestLiveActivityWidget.swift` may also be touched by C2 / C6 — keep
  this lane's hunks; C6 can call `setPlayContext(…, arrived:)` / `setCheckInHandler` from its run HUD.
