# Receipt — components r1, lane C7 island+steps (`comp/r1-island-steps`)

Brief: `origin/design/handoff-r2:docs/briefs/components-r1.md`, section "Added 11-27" (R-island, R-steps).
Base: `origin/ui/combined-r7` (already contains `origin/comp/r1-live` and `origin/comp/r1-kit`; both merges were no-ops).
Apple components only (ActivityKit, App Intents, SF Symbols, system fonts, `Text(timerInterval:countsDown:)`,
`ProgressView`, `symbolEffect(.bounce)`, `.contentTransition(.numericText())`). No story-flow theme work.
**Nothing here was compiled**: there is no Xcode in the cloud, so the coordinator's `build_sim` is the first compile.

Gates (run before each push): `check_scaffold.py` PASS (structural, 19818 bilingual keys), `check_a11y_lint.py` PASS
(0 new), `contract_ratchet.py --check` (new 0), `check_appsession_ratchet.py` PASS (AppSession.swift not touched).

## R-island: shared invite / plan Live Activity

A **separate** `ActivityAttributes` type, so push-to-start can name it and the existing roam/play/story/event activity
(`QuestLiveActivityKind`) gains no new enum case. Without a new case, no existing `switch` needs updating.

- `Core/QuestPlanActivityContent.swift` (new; shared into the widget extension, `tools/generate_project.py:28`)
  - `:31` `QuestPlanContent` (ContentState). Fields: `headline` (the question, "一起组队？" / "Walk tonight?"), `note`
    (the taped-note line), `stickers` (≤2 SF Symbol names or single emoji, validated by `QuestPlanSticker`), `startsAt`,
    `done`/`total` (team progress), `tucked`, `joined`. Every field except `headline` is optional, so a server push may
    send less.
  - `:136` `QuestPlanActivityAttributes`. Fields: `kind` (`teamInvite`, `friendInvite`, `clubEvent`, `teamStatus`),
    `planKey`, `title`, `targetID`.
  - `:83` `QuestPlanLinks.join`. 加入 opens fixed, already-routed pages: `chein://mp/pages/team/detail/index?teamId=`
    (MP 查看队伍 / 加入方式), or club detail (`QuestWidgetBoard.club`). Status cards have no join link.
  - `:158` `QuestPlanTuckIntent`: 稍后 / **Tuck**, a `LiveActivityIntent`. It sets `tucked = true`. The expanded card
    then folds to headline-only, the bottom region (note, actions) disappears and the compact pill stays. The app
    remembers the tuck, so a refresh does not unfold the card again.
  - `:104` `QuestPlanActivityTokenRequest`: the request model for `POST /api/live-activity/token` (contract below).
- `LiveActivityWidget/QuestPlanLiveActivityWidget.swift` (new; registered in `QuestLiveActivityWidgetBundle.swift:12`)
  - **Expanded island.** Leading: sticker stack (two stickers turned ±7°). Center: eyebrow + headline. Trailing:
    `距开始 mm:ss` countdown or team `2/5`. Bottom: taped note (pale slip with a tape strip), team `ProgressView`,
    then 加入 (`Link`, accent capsule) and 稍后 (`Button(intent:)`).
  - **Compact.** Leading: sticker or glyph. Trailing: countdown, `2/5`, ✓ when joined, or an envelope.
  - **Minimal:** glyph.
  - **Lock Screen:** the same card on the dark surface (`activityBackgroundTint` black 0.82, `.colorScheme(.dark)`).
    Tucked, it is a single line.
  - Tint per kind: invites green, club accent, team status orange. Every glyph has a VoiceOver label; 稍后 has a hint.
- `App/QuestPlanActivityCenter.swift` (new). The ActivityKit owner.
  - `:34` `start()`, called from `App/QuestifyApp.swift:10`. It observes:
    - `Activity<QuestPlanActivityAttributes>.pushToStartTokenUpdates` (iOS 17.2+, `#available`), registered as
      `PUSH_TO_START`;
    - `activityUpdates` (push-started cards) and each activity's `pushTokenUpdates`, registered as `ACTIVITY`;
    - `activityStateUpdates` ended/dismissed, sent as `ENDED`.
  - `:52` `setRegistrar`: the signed-in sender, installed by `.questPlanTokenRegistration(session)` on `SessionRootView`
    (`App/QuestifyApp.swift`, both DEBUG and release branches).
    - Requests made while signed out wait in a queue (newest per scope and plan).
    - A failed register is re-queued; a failed `ENDED` is not.
    - The sender is `Core/QuestPlanActivityTokenService.swift`. It reuses `APIConfiguration`, `runtimeHTTPTransport`
      and the session token header, the same path as `TeamPoolService`.
  - `:108` `present` is the **local fallback**:
    - If a card for the same `planKey` exists (for example one the server started by push), it is updated, never
      duplicated.
    - Otherwise it calls `Activity.request(pushType: .token)` so the server can keep the local card in sync, and retries
      with `pushType: nil` when that is refused (no aps entitlement, push off).
    - At most 2 plan cards run at once. Everything is gated by `NativeR2Flags.island`.
- `Core/QuestPlanActivityMapping.swift` (new, pure). Builds local cards from data the app already reads. MP-first copy:
  - **Team / friend invites.** `teamInvites` reads `NativeFriendTeamOffer` rows. An offer shows when it is
    `WAITING_CONFIRM`, I am the recipient, and `canAct` is true. A `JOINED` offer shows 已加入 and then ends.
    - Copy: note "%1$@ 邀请你加入「%2$@」"; eyebrow MP 加入队伍 (`pages/team/join/index.json`).
    - Fed from `App/NativeFriendTeamInviteEntry.swift:97` (`.onChange(of: flow.offers)`).
    - `friendInvite` (MP referral headline 朋友邀请你一起玩, `subpackageJourney/utils/journey-view.js:317`) is only ever
      pushed by the server. The app has no friend-referral list to read, so it never starts that kind locally.
  - **Club event nudges.** `clubEvent` uses the first event in the club calendar that starts **today** (MP 即将开始). The
    calendar is day-granular, so there is no countdown; the card is stale at midnight.
    - Fed from `App/ClubEventCalendarView.swift:139`.
    - Wallet tickets with a time of day already get C1's "Starts in · 加入" activity, which is left as it is.
  - **Live team status.** `teamStatus` diffs the PLAYER team projection and names the member whose status changed last
    (`Lena` + the existing `playerTeam.status.*` copy, e.g. "Lena 已完成"). With no change it shows "n/m 人已完成", plus a
    progress bar.
    - Fed from `App/PlayPlayerTeamStatusView.swift` (`onChange(of: state, initial: true)`); scope is the run's
      `teamID` (`App/PlayPlayerAndCircleViews.swift:45`).
    - The PLAYER projection has no per-member stop. "reached stop 3" therefore needs the server push (the `note`
      field); locally the card names the status.

### Backend contract (`POST /api/live-activity/token`)

Auth is the usual `Authorization: <session token>`. The JSON body is sorted-keys:

```json
{
  "scope": "PUSH_TO_START" | "ACTIVITY" | "ENDED",
  "token": "<APNs hex>",            // absent for ENDED
  "attributesType": "QuestPlanActivityAttributes",
  "planKey": "offer:<uuid>" | "team-status:<teamId>" | "club-event:<eventId>" | "<server key>",   // absent for PUSH_TO_START
  "activityId": "<ActivityKit id>", // ACTIVITY / ENDED only, for dedupe
  "environment": "SANDBOX" | "PRODUCTION",
  "bundleId": "com.chengyinhub.chengyinApp",
  "locale": "zh_CN"
}
```

- **Reply.** Envelope `{code: 200}`. Idempotent by (account, scope, attributesType, planKey, activityId). The newest
  token replaces older ones.
- **Push-to-start** (APNs, `apns-push-type: liveactivity`, topic `<bundle>.push-type.liveactivity`):
  - `event: "start"`
  - `attributes-type: "QuestPlanActivityAttributes"`
  - `attributes: {kind, planKey, title, targetID}`
  - `content-state`: the `QuestPlanContent` fields
  - optional `alert`
  - Send it to every invited member's push-to-start token, using the **same `planKey`** for everyone.
- **Updates.** `event: "update"` / `"end"` to the per-activity tokens registered under that `planKey`. Do not send
  `tucked`: it is per viewer and the app owns it. If a push omits it, the app sets it back on its next refresh.
- **Copy.** Server copy should mirror the MP: 朋友邀请你一起玩, 一起来玩, 加入队伍, 距开始, 即将开始.

## R-steps: `CYStepChecklist`

- `App/NativeR2/Components/CYStepChecklist.swift` (new).
  - `CYChecklistStep` (`:4`): id, title, state (`done`/`current`/`todo`/`locked`), a `detail` used as the one-line
    summary when done or the live status ("生成中…") when current, `thumbnailSymbol`, and `startable`.
  - `CYStepChecklistMath`: done count, fraction, current id. Covered by tests.
  - **Header:** icon, title, "2 / 5 已完成" (`numericText`) and `CYRing` from the C3 kit.
  - **Current step:** highlighted, inline prominent 开始, live status with a mini `ProgressView`.
  - **Remaining steps:** bordered 开始.
  - **已完成 (n):** a collapsible section; each done row shows its summary or a symbol thumbnail.
  - 重置, and a result card (`CYStepChecklistResultCard`) once every step is done.
  - **Motion:** a spring on step changes (the ring fills), `symbolEffect(.bounce)` on the done checkmark, and a snappy
    collapse. All of it is off or opacity-only under Reduce Motion.
  - **Accessibility:** a VoiceOver value per row (当前 / 已完成 / 尚未开始 / 未解锁), and the 开始 label carries the step
    name. Includes a preview.
- Adoptions are in `App/NativeR2/Components/CYStepChecklistAdoptions.swift`; each host gets a one-line hunk.

| Where | Host hunk | Steps (MP source) |
|---|---|---|
| Publish activity wizard | `App/PublishingModesViews.swift:318` | 基本信息 / 活动内容 / 票务与合作, `ActivityPublishingWizard.progress` (MP `pages/publish/activity`, `buildProgress`). 开始 jumps to the step; a done step shows the activity name / ticket count. |
| Club setup | `App/ClubOperationsViews.swift:1150` (intro step only; the verified per-step header N-08 is untouched) | `ClubPlayerCopy.createTitle(1…4)`, 开始创建 (MP `pages/club/create`) |
| City-orientation run | `App/PlayExperienceView.swift:787`, above the legs list (legs and their `playx.node.*` ids kept for UI tests) | `PlayRouteMapPresentation.stops`: completed/current/available/locked; 继续 opens the punch sheet; "X / N 已完成" (MP `play-roadmap.js`) |
| First-roam onboarding | `App/RoamPreflightRulesView.swift:38` | The four 漫游怎么玩 rules read one by one with 知道了 → 出发吧. View state only: no consent or start, matching the view's contract. |
| Event check-in | `App/TicketWalletDetailView.swift:69` | 报名成功 → 到店核销 (开始 = 出示入场码, the existing pass) → 开始游玩 / 已通关 (MP order timeline `scene-member-order-detail`, wallet 已通关). |

Topic publish (`ProjectEditView`) is not adopted: the MP 创作 page is a single form with no steps, so there is nothing
to count.

## Strings

- App catalog: fragment `docs/port/strings/comp-r1-island-steps.json`, 48 keys (`plan.*`, `comp.steps.*`, per-adoption
  titles), merged into `Resources/Localizable.xcstrings`.
- Widget catalog: `docs/port/strings/comp-r1-island-widget.json`, 14 `plan.*` keys, merged into
  `LiveActivityWidget/Localizable.xcstrings`.
- All additions, no overrides.

## Tests

`Tests/AppUnitTests/QuestPlanActivityAndChecklistTests.swift`: invite mapping and link, answered/foreign invites, the
club "today" nudge, team-status diff note, sticker validation, tuck hides actions, token request hex/scope validation,
checklist math.

## Coordinator / owner actions

1. **Push Notifications capability.** `Config/Questify.entitlements` now carries `aps-environment = development`
   (export rewrites it to production).
   - Enable **Push Notifications** on App ID `com.chengyinhub.chengyinApp`.
   - Regenerate the two App Store profiles; this is the same step as C2's App Group.
   - If the capability is not ready by the build, drop that one key. The plan card then runs local-only: the
     `pushType: nil` fallback works, and push-to-start tokens never arrive.
2. **Backend.** Implement `POST /api/live-activity/token` and the push-to-start / update sender per the contract
   above, using APNs token auth (.p8) with the `liveactivity` push type.
3. **First compile.** Watch `CYStepChecklist`'s generic init and `extension … where Result == EmptyView`, the
   `Button(intent:)` in the widget, and `Activity.pushToStartTokenUpdates` behind `#available(iOS 17.2, *)`.
