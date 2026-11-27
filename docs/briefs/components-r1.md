# Components r1: widgets, Live Activities and in-app components across the player app (2026-11-27)

Owner 11-27: design is NOT paused — only the story-flow theme waits. Games, navigation, channel messages, community and components must all be done well. Reference set: tobiadonadon_'s iPhone widget sheet (countdown "Starts in 3:51 · Join", focus timer, progress, now-playing with waveform, streak grid, ring %, live counters +36 / 1.2k, accept/decline buttons, Dynamic Island pill).

Repo `https://github.com/XXsocietyee/chein-app`, base newest `origin/ui/combined-r7`. MP source of truth for content/behaviour: `origin/mp-source:chengyinhub-xcx/` (copy what the MP shows; never ask the owner when the MP answers). Deployment target iOS 17 (gate iOS 18 APIs with `#available`).

**Style:** Apple components only (WidgetKit, ActivityKit, App Intents, SF Symbols, system fonts, `.contentTransition(.numericText())`, `Text(timerInterval:)`, `ProgressView`, `Gauge`), Dynamic Type, Reduce Motion, VoiceOver labels. Dark, high-contrast surfaces like the reference; one accent per widget from the feature's existing tint. No story-flow theme work.

**What exists (don't rebuild):** `LiveActivityWidget/QuestLiveActivityWidget.swift` (roam/play/story Live Activity, Dynamic Island compact/minimal/expanded, count-up timer, stop + clue progress, media title), `QuestNextStopWidget.swift` (small/medium/lock-screen next stop), `Core/QuestLiveActivityContent.swift` (attributes + content state), in-app `IslandCenter` top pop-ups, `App/NativeR2/Motion/*`.

**Known gap to fix first (C2):** `Config/Questify.entitlements` has no App Group, so `QuestWidgetStore.sharedDefaults()` returns nil and home widgets show nothing. Add `com.apple.security.application-groups = group.com.chengyinhub.chengyinApp` to the app and widget entitlements and note in the receipt that the owner/coordinator must register the App Group and regenerate the two App Store profiles.

## Lanes

| Lane | Branch | Scope |
|---|---|---|
| C1 live | `comp/r1-live` | Live Activities + Dynamic Island: navigation/orientation (next stop, distance, deadline countdown `Text(timerInterval:countsDown:true)`, arrival), game runs (timer, score, rank), event/activity "Starts in mm:ss · 加入" countdown activity; interactive buttons via `LiveActivityIntent` (pause/resume run, check in, open). Extend `QuestLiveActivityAttributes` compatibly. |
| C2 widgets | `comp/r1-widgets` | App Group fix (above). Home/Lock/StandBy widgets: next event countdown, roam streak grid (days walked), city revealed ring %, passport stamps counter, club community (new posts) and channel unread counters; iOS 18 `ControlWidget` (start roam / check in) behind `#available`. Data written by the app into the shared store at the points the app already has. |
| C3 kit | `comp/r1-kit` | Reusable SwiftUI components in `App/NativeR2/Components/`: `CYCountdown`, `CYRing`, `CYLiveCounter` (numericText), `CYStreakGrid`, `CYWaveform` (audio level / static), `CYStatPill`, `CYJoinCountdownRow`. Previews + a11y. Then adopt them where the app shows these values today (event lists, game HUD, run panel, passport, wallet, club stats). |
| C4 games | `comp/r1-games` | Every game type in `NativeGameShell` / game views: HUD (timer, score, progress, hint count) with C3 components, start/countdown, result screens with the motion-r2 reward moments; MP game pages for content. |
| C5 social | `comp/r1-social` | Channel messages + community: native bubbles, voice-note waveform, unread badges/counters, reactions/like counters, typing/presence where MP has it, club community feed posts and comment threads; MP channel/club pages. |
| C6 nav | `comp/r1-nav` | Navigation / city orientation run: run HUD, next-stop card with distance + ETA, arrival confirmation, team progress, paused state; MP rules (no locate-me button, see fix-r11 decisions). |

Lanes touching the same file: keep hunks small, merge `origin/ui/combined-r7` before every push. C3 pushes its components early (first push within 30 min) so C4–C6 can adopt them; until then use local private helpers.

**No compiler in the cloud:** grep every API; traps in `COORDINATOR-HANDOVER.md` §4 plus: type set literals before calling methods, `self.` when init params shadow properties, no async in XCTAssert args, split long modifier chains into computed properties. New files → `python3 tools/generate_project.py`. Gates before every push: `check_scaffold.py`, `check_a11y_lint.py`, `contract_ratchet.py --check` (new 0). Strings in `Resources/Localizable.xcstrings` (zh-Hans + en; widget strings in `LiveActivityWidget/Localizable.xcstrings`).

**Receipt:** `docs/release/receipts/comp-r1-<lane>.md` — what was added, file:line, where adopted, MP references, anything the coordinator must do (capabilities, profiles). Trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Added 11-27 (owner references)

**R-island (@gdwwyn, "Dynamic Island as a shared space between friends"):** expanded Live Activity as a small invite/plan card — headline question ("一起漫游？" / "Walk tonight?"), a taped-note line, one or two SF-Symbol/emoji stickers, and actions 加入 / 稍后 ("Tuck" = end the expanded presentation, keep the compact pill). Uses: team/friend invites, club event "starts in" nudges, live team status during a run ("Lena reached stop 3"). Shared across members via ActivityKit push-to-start / push updates (app registers `pushToStartToken` + per-activity push tokens with the backend: `POST /api/live-activity/token`), with local fallback when push is unavailable. Content comes from existing invite/team/event data (MP-first copy).

**R-steps (@dimtri_G, step checklist card):** reusable `CYStepChecklist`: header (icon, title, "2 of 5 complete", progress ring), the current step highlighted with inline **开始/Start** and a live status ("生成中…"), remaining steps with secondary Start, a collapsible "已完成 (n)" section where each done step shows a one-line summary or thumbnail on the trailing side, Reset, and a final result card. Use it for: publish wizards (topic/activity/club setup), city-orientation run tasks (stops as steps), first-roam onboarding, event check-in. Motion: ring fills with a spring, completed row checkmark `symbolEffect(.bounce)`, section collapse animation; Reduce Motion respected.
