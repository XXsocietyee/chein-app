# Components r1 — lane C2 widgets (`comp/r1-widgets`)

Base: `origin/ui/combined-r7`. Brief: `origin/design/handoff-r2:docs/briefs/components-r1.md` (C2 row). No compiler in the cloud: every API was grepped/checked by hand; needs one Xcode build of `Questify` + `QuestifyLiveActivity` before merge.

## 1. App Group fix (first)

| Change | Where |
|---|---|
| `com.apple.security.application-groups = [group.com.chengyinhub.chengyinApp]` on the app | `Config/Questify.entitlements` |
| New widget-extension entitlements (App Group only) | `Config/QuestifyLiveActivity.entitlements` |
| Widget target `CODE_SIGN_ENTITLEMENTS` (Debug + Release) | `tools/generate_project.py:143` → `Questify.xcodeproj` |
| `QuestWidgetStore.appGroup` constant; `sharedDefaults()` tries the entitled group first, then `group.<bundle id>` (Debug bundle id is the `invalid.example` placeholder) | `Core/QuestLiveActivityContent.swift:150-160` |
| Privacy manifest: UserDefaults reason `1C8F.1` (App Group defaults shared with the widget) next to `CA92.1` | `Resources/PrivacyInfo.xcprivacy` |
| Contracts updated to the new exact entitlement sets (still no associated domains, test targets set none) | `Tests/ContractChecks/test_entitlements_contract.py`, `test_sign_in_with_apple_flow.py`, `test_universal_link_associated_domains.py`, `test_app_store_privacy_launch_contracts.py`, `tools/archive_unsigned.py` (`check_apple_entitlement`, `REQUIRED_REASON_APIS`) |

The existing next-stop widget (`QuestNextStopWidget`) now gets data once the group is provisioned.

## 2. Widgets (Home / Lock / StandBy)

All in `LiveActivityWidget/QuestBoardWidgets.swift`, registered in `QuestLiveActivityWidgetBundle.swift`. Dark gradient surface via `containerBackground`, one accent per widget, system fonts and SF Symbols, `numericText` counters, VoiceOver labels on every value (grids are hidden, summarised in one label). systemSmall shows in StandBy.

| Widget (kind) | Families | Shows | Tap |
|---|---|---|---|
| `QuestEventCountdownWidget` (:83) | small, medium, rectangular, inline | next wallet ticket: title, place, "距开始" `Text(timerInterval:countsDown:true)`, "进行中" after the start, gone 3 h later; medium has the 加入 capsule | `chein://ticket/<id>` (ticket pass with the check-in code), else `pages/activity/list` |
| `QuestRoamStreakWidget` (:279) | small (5-week grid), medium (12-week grid + 开始漫游), circular, rectangular | current streak (counts until today ends), walked days in the window, Monday-first week columns, today outlined | `subpackageRoam/history/index` |
| `QuestCityProgressWidget` (:491) | small, medium, circular, rectangular | city-board lit share as a `Gauge` ring %, passport stamp counter | roam (ring) / passport (no ring yet) |
| `QuestCommunityWidget` (:676) | small, medium (two tappable tiles), circular, inline | IM unread total, club posts of the last 7 days + club name | `subpackageB/pages/im/list/index` / `pages/club/detail/index?id=` |

Timelines: no network; event entries at now / start-24 h / start / expiry; streak reloads at midnight; the rest `.never` (the app reloads a kind only when its stored bytes change).

## 3. iOS 18 controls

`LiveActivityWidget/QuestControlWidgets.swift`: `QuestStartRoamControl` (开始漫游 → `pages/roam/index`) and `QuestCheckInControl` (签到 → `pages/activity/list/index`, whose 我的 bucket holds joined activities and tickets). Both `@available(iOS 18.0, *)` and added under `if #available(iOS 18.0, *)` in the bundle.
Action: `Core/QuestWidgetControlIntent.swift` `QuestControlRouteIntent` (`openAppWhenRun`, not discoverable), compiled into both targets. In the app it calls `MPNotificationTapRouter.open(pagePath:)` through `handler` (installed in `QuestifyApp.init`); in the extension it parks the path in the App Group and `SessionRootView` opens it on `scenePhase == .active` (`App/QuestifyApp.swift:605`).

## 4. Data written by the app (existing read points, one line each)

Shared model: `Core/QuestWidgetBoard.swift` (sections under separate App Group keys; display-only: titles, counts, a start time, day stamps — no tokens, coordinates or account ids). Writer: `App/QuestWidgetBoardPublisher.swift`.

| Value | Call site | Source |
|---|---|---|
| next event | `App/SessionHomeFeedView.swift:348` | `reloadTodayTicket` → `HomeTodayCandidate.nextTicket` (wallet ticket within −3 h…+24 h) |
| roam days | `App/RoamLiveSessionView.swift:526` | `settledSessionChanged` → `finishedHistory.history()` `recordedAt` (merged with stored days, 84 kept) |
| city lit % | `App/CityKit/CityRoamRootView.swift:159` | `onChange(of: store.places)` → not-`.fogged` / all `CityPlace`s |
| stamps | `App/PassportView.swift:124`, `:143` | album `page.total`, else device count |
| unread | `App/IMInboxViews.swift:186` | `IMUnreadEntryBadge.load` `unreadTotal()` |
| club posts | `App/ClubCommunityViews.swift:205` | first `.posts(clubID, nil, _)` page, `createTime` (Beijing) within 7 days |
| sign-out / account switch | `App/QuestifyApp.swift:535` | clears every section + next stop |

MP references (`origin/mp-source:chengyinhub-xcx/app.json`): `pages/activity/list`, `subpackageRoam/history`, `subpackageP3/pages/stamp-album`, `subpackageB/pages/im/list`, `pages/club/detail`, `pages/roam/index`; all are on the `MiniProgramPageLink` allowlist (asserted in `Tests/CoreTests/QuestWidgetBoardTests.swift`).

Honest gaps:
- The app has no city-wide "revealed %" for the player (fog coverage is off; `FogCoverageReading` is fixture-only). The ring uses the lit share of the city board around the player (3 km window). Swap in a server figure when one exists.
- There is no per-viewer "new posts" count in the club API; the widget shows posts from the last 7 days ("本周动态") of the club last opened.
- The event countdown only knows wallet tickets within 24 h (same rule as Home 今日). Wall-clock start strings without a zone are skipped, as on Home.

## 5. Strings

Widget strings: `LiveActivityWidget/Localizable.xcstrings` (34 keys `widget.event.*`, `widget.streak.*`, `widget.city.*`, `widget.community.*`, `widget.control.*`, en + zh-Hans). Intent/control keys also in `Resources/Localizable.xcstrings` via `docs/port/strings/comp-r1-widgets.json`.

## 6. Tests and gates

- `Tests/CoreTests/QuestWidgetBoardTests.swift`: streak / window counts, dedupe + cap, clamps, links parse through `CheinDeepLink` / `MiniProgramPageLink`, event expiry.
- `check_scaffold.py` PASS structural; `check_a11y_lint.py` 0 new; `contract_ratchet.py --check` new 0 (it exits 1 only because one baseline entry, `test_profile_read_failure_remote_admission…test_raw_creator_positive_contract_is_independent_of_all_history`, now passes and is outside this lane's files; baseline left for the coordinator); `check_privacy_manifest.py` PASS; the five touched contract modules pass.

## 7. Coordinator / owner must do

1. **Register the App Group** `group.com.chengyinhub.chengyinApp` in the Apple Developer portal and enable it on both App IDs: `com.chengyinhub.chengyinApp` and `com.chengyinhub.chengyinApp.LiveActivity`.
2. **Regenerate the two App Store provisioning profiles** (app + widget extension) so they carry the App Group, then re-download them on the signing machine. Release archives fail to sign until then.
3. Privacy manifest now declares UserDefaults `1C8F.1` (App Group); `docs/release/app-privacy-answers.md` updated. `cb55-privacy.md` is a dated receipt and was left as is.
4. Build both targets once in Xcode (iOS 17 sim and iOS 18 sim for the controls) and add the widgets in the simulator to check layout.
