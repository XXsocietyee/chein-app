# Mini-program delta 4 (2026-11-14)

Behavior, copy, and visual changes ported onto `ui/h-mp-delta-4` (continuing `origin/ui/cur-mp-delta-4` `e2a708154c504bdaf7999926e355f4e97eba97b2`, branched from `ui/h-design-v1` / `5d652cc08`). Round 3 is `docs/release/mp-delta-3.md` on `ui/cur-mp-delta-3` `2d6e8ff4b88fdfe755c06c037ef38ae892781632` (master tip `f7fd2a8728971e52ddde6943cb24bce5264b3ca8`). The two round-80 ports (unused self-play pass 「可使用」, settle rating `request_id`) are not redone.

Read over HTTPS from `liboyang42-cpu/hengyin`. Player pages are `chengyinhub-xcx`.

## Commits read

`master` tip read: `5149d4fcdb655f1f9275db76bd2cee18b2ba68ab` (2026-11-14 05:34 America/Los_Angeles). Two commits sit after `f7fd2a872`.

| SHA | When (America/Los_Angeles) | What |
|---|---|---|
| `316f717d1040af392647891dbe9a8b01a41b290f` | 2026-11-14 05:05 | #838. Squash of the 1114 waves (play, roam, maps, free-explore, template shelf). Player diff is on this commit. |
| `5149d4fcdb655f1f9275db76bd2cee18b2ba68ab` | 2026-11-14 05:34 | #839. Owner decision A. Cross-club and four-shop session cash settles to the organizer. Java and a RESULT note. No `chengyinhub-xcx` file. |

`fix/*` tips whose commit time is after `f7fd2a872` (2026-11-14 03:33 America/Los_Angeles):

| Branch | Round 3 tip | Tip read now | Note |
|---|---|---|---|
| `fix/play-wave-1114` | `550afadfd6cf1c15ede93cb6c3b2909645c68d98` | `eaf7d4f43dd2780191191a9ca0e1a9bcaca8616` | New commit is only `docs/delivery/questo-ui-20261109/play-wave-1114/RESULT.md`. Player source landed on master as #838. |
| `fix/fe-settlement-a-1114` | not named | `4dbd89d9054d88a1e85bda12b825808f5f878063` | Diverges from master after the squash. Unique files are settlement Java and `fe-settlement-a-1114/RESULT.md`. No player page. |
| `fix/free-explore-1114` | `d6698fc0a9035312988270db630475e63fca9044` | same | Already read in round 3. Player source is now on master as #838. |
| `fix/roam-frontend-1114` | `b3b6e67ecddf20142677b369d0a591ca7a7794e0` | same | Already read in round 3. Player source is now on master as #838. |
| `fix/master-ci-1114` | `022a50f7dc165a92d8f1075b7a85bd2e628b481b` | same | CI sync. No new player page. |

Other `fix/*` tips are at or before `f7fd2a872` and were not reopened (`fix/answers-checkout-1114`, `fix/roam-backend-1114`, `fix/maps-1114`, `fix/guest-catalog-place-1114`, `fix/prod-release-ddl`).

## Done

### From `e2a708154` (Cursor handoff) + parse fix

| Mini-program change | Native file | Screen | hengyin SHA |
|---|---|---|---|
| Whole-run clock uses `h:mm:ss` once the run reaches one hour (`mm:ss` under 1 h; short challenge timers unchanged). | `Core/PlayRunLifecycle.swift` (`PlayRunElapsedText`), `App/PlayExperienceView.swift` | Play run clock | `316f717d1040af392647891dbe9a8b01a41b290f` |
| Ticket expiry landing on China midnight counts as the previous playable day, matching 「可玩至」. | `Core/MoneyParityRules.swift` (`MoneyPassExpiry`), `Tests/CoreTests/MoneyParityRulesTests.swift` | Ticket wallet detail | `316f717d1040af392647891dbe9a8b01a41b290f` |
| Q&A rows draw the letter badge and strip matching author prefixes (`A `, `A.`, `（A）`), keeping original when strip would empty; picture options use the same strip while keeping `optionId`. Fixed missing quote on raw string in `Tests/CoreTests/PlayKitQuestoContractsTests.swift:100`. | `Core/PlayKitQuestoContracts.swift`, `App/PlayKitQuestionForms.swift`, `App/DesignSystem/CYCityKit.swift`, `Tests/CoreTests/PlayKitQuestoContractsTests.swift` | Play kit Q&A | `316f717d1040af392647891dbe9a8b01a41b290f` |
| Hangman title falls back to station question then place name; post-solve feedback prefers kit line then station `passText`; server judgement preserved. | `Core/PlayKitQuestoContracts.swift`, `Core/PlayContracts.swift`, `App/PlayKitQuestoViews.swift`, `App/PlayAdvancedView.swift`, `App/PlayExperienceView.swift` | Play kit hangman | `316f717d1040af392647891dbe9a8b01a41b290f` |
| Pass reveal: tap during animation and skip control both settle on the end state without closing the screen; primary CTA appears with end state. | `App/PassMembershipViews.swift` | Pass reveal | `316f717d1040af392647891dbe9a8b01a41b290f` |

### Completed on `ui/h-mp-delta-4` (`127f537a5`)

| Mini-program change | Native file | Screen | hengyin SHA |
|---|---|---|---|
| Finish report timing (`reportTiming`): `PostGameRunReport.decode` falls back `completedAt` to `endedAt` and derives `elapsedSeconds` from `startedAt`..`closeAt` (`1...7*24*3600` s); `PlayExperienceView.finishClockText(_:)` unified on `PlayRunElapsedText.format`. | `Core/PostGameReport.swift`, `App/PlayExperienceView.swift`, `Tests/CoreTests/PostGameReportTests.swift` (`testReportTimingDerivesElapsedAndFallsBackToEndedAt`) | Play finish report & result | `316f717d1040af392647891dbe9a8b01a41b290f` |
| `D-26` pack-skip (`pack-skip.js`): enabled tap during pack open/deal skips to dealt card after 300 ms guard (`PlayPackSkipPolicy`), cancels pending animation task, and cleans up on disappear. | `Core/PlayRunLifecycle.swift` (`PlayPackSkipPolicy`), `App/FreeExplorationViews.swift`, `Tests/CoreTests/PlayExperienceTests.swift` (`testPackSkipHonorsPlayingStateAnd300msGuard`) | Free explore pack open | `316f717d1040af392647891dbe9a8b01a41b290f` |
| Pass reveal press feedback (`pass-reveal` `.pr-tap`): simultaneous press gesture dims stage opacity to `0.8` while skipping/revealing. | `App/PassMembershipViews.swift` | Pass reveal | `316f717d1040af392647891dbe9a8b01a41b290f` |
| Photo/media states & permission Settings deep link: added judging label (`playkit.photo.judging`), kept-photo submit-fail banner (`playkit.photo.submitFailedKept`) with 「重新提交」 (`playkit.photo.resubmit`), upload-fail retake banner (`playkit.photo.uploadFailedRetake`), and Settings button (`playkit.media.openSettings` opening `UIApplication.openSettingsURLString`) across photo/scan/sensor inputs. | `App/PlayKitPersonalForms.swift`, `App/PlayKitSensorChallengeView.swift`, `Resources/Localizable.xcstrings` | Play kit photo, QR scan & sensor challenges | `316f717d1040af392647891dbe9a8b01a41b290f` |
| Challenge POI node parity (`A3.5` / `A3.6`): decoded `coverUrl` (`coverImg`, `coverUrl`, `imgUrl`, `iconUrl`, `img`, `cover`) preferred in `doneCard`; added out-of-range Apple Maps directions button (`playx.poi.navigate`) in `placeCard`; wired `onWriteCitySlip` / `RoamStampCameraView` sheet with 「写一张城市签」 (`playx.poi.writeCitySlip`) in `ChallengePOIHostView`. | `Core/ChallengePOI.swift`, `App/ChallengePOIView.swift`, `Tests/CoreTests/ChallengePOISubmissionTests.swift` (`testNodeDecodesCoverUrlFallback`), `Resources/Localizable.xcstrings` | Challenge POI overlay & sheet | `316f717d1040af392647891dbe9a8b01a41b290f` |
| Template shelf access-retry banner & staff read-only lock icon: added `merchantAccessError` + `onRetryMerchantAccess` clickable `CYNoteBanner` (`discovery.templateTab.accessRetry`, `.cyPressable()`); added `lock.fill` next to standalone `Text("discovery.templateTab.staffReadOnly")` without wrapping it (keeping `TemplateTabStaffFlowTests` AX lookup intact). | `App/DiscoveryTemplateBrowserView.swift`, `Resources/Localizable.xcstrings` | Template shelf tab | `316f717d1040af392647891dbe9a8b01a41b290f` |
| Template detail empty capability rows: replaced literal `"—"` (`template.cap.empty`) in both `TemplateCapabilityRows` and `DiscoveryTopicTemplatePreview` with `CYEmptyState(systemImage: "map", "template.cap.emptyState", messageIdentifier: "template.cap.empty")`. | `App/DiscoveryTemplateDetailView.swift`, `App/TemplateDetailXbChrome.swift`, `Resources/Localizable.xcstrings` | Template detail | `316f717d1040af392647891dbe9a8b01a41b290f` |

## Not done

| Mini-program change | SHA | Screen | Reason |
|---|---|---|---|
| #831 settle rating `request_id`, and unused self-play pass label 「可使用」. | `3ffd1201704bd99787b9653f4618dab2c4c874bd` | — | Already ported on `ui/cur-mp-delta-2`. Not redone. |
| Play location recovery 「开启定位」 / 「扫码到达」, 300 m start gate, story hint ladder, chapter-gate final values, finish archive for non-roam routes, ticket link `topicId`, route-session shown state, connection-failure retry split, China-zone finish date. | `316f717d1040af392647891dbe9a8b01a41b290f` | Play screen | Depends on server/session/location-gate flows or props not exposed on this native play surface without new backend contracts. |
| Hangman title `word-break: keep-all`. | `316f717d1040af392647891dbe9a8b01a41b290f` | Play kit hangman | CSS-specific Chinese line-break hint has no shared `CY*` SwiftUI equivalent token on this branch. |
| Roam entry map without a location fix, category pins, clustering, mystery pins, 「还差 N 米」, 「资料来源」, 「本城推荐」, nearby 「只显示离你最近的 N 处」. | `316f717d1040af392647891dbe9a8b01a41b290f` | Roam | Uses `RoamBrowserView` / `RoamSubpageParityViews` map/feed contracts not rewritten in this pass (`roamSub.w208.poi.dropStamp` unchanged). |
| Map style 白 / 黑 / 纸本 / 2077, and Tencent `takeSnapshot` share cards. | `316f717d1040af392647891dbe9a8b01a41b290f` | Map / Share | Tencent SDK layer styles and snapshot APIs have no shared `CY*` basemap tokens in `App/DesignSystem`. |
| Template shelf 「暂未开放」, 「用这个模板」, 15 s fresh window, request id on adopt (`TemplateTabPolicy` rewrite). | `316f717d1040af392647891dbe9a8b01a41b290f` | Template shelf | Deferred behind `TemplateTabPolicy` / template adoption write contracts. |
| Pricing 「平台服务费」, 「预计到手」, 「结算待处理」, 「已锁价，等待运营开售」, free-explore reservation write form, merchant 「套票到店」 / 「记未到店」. | `316f717d1040af392647891dbe9a8b01a41b290f` | Merchant / Free-explore checkout | Money and merchant write paths remain closed (`www.chengyinhub.com`); no StoreKit product id added. |
| Signup double-tap guard and earlier expiry/cancel toasts; ticket wallet 600 ms open lock & ticket id 0 guard. | `316f717d1040af392647891dbe9a8b01a41b290f` | Ticket wallet / Signup | No matching ticket-wallet open animation with that 600 ms lock on native; ticket id `0` contract left intact. |
| #839 organizer settlement for cross-club and four-shop sessions; `fix/fe-settlement-a-1114`; `fix/play-wave-1114` RESULT note; `fix/free-explore-1114`, `fix/roam-frontend-1114`, `fix/master-ci-1114`. | `5149d4fcdb655f1f9275db76bd2cee18b2ba68ab`, `4dbd89d9054d88a1e85bda12b825808f5f878063`, `eaf7d4f43dd2780191191a9ca0e1a9bcaca8616` | — | Backend Java/SQL/RESULT docs only or already landed in `#838`. |

## Verification

No `xcodebuild`, `swift build`, or `swift test` was run on the Mac (per task constraint).

### `xcrun swiftc -parse` on every changed `.swift` file (`git diff --name-only 5d652cc08..HEAD -- '*.swift'`)

```
PARSE=0 DEBUG_PARSE=0 App/ChallengePOIView.swift
PARSE=0 DEBUG_PARSE=0 App/DesignSystem/CYCityKit.swift
PARSE=0 DEBUG_PARSE=0 App/DiscoveryTemplateBrowserView.swift
PARSE=0 DEBUG_PARSE=0 App/DiscoveryTemplateDetailView.swift
PARSE=0 DEBUG_PARSE=0 App/FreeExplorationViews.swift
PARSE=0 DEBUG_PARSE=0 App/PassMembershipViews.swift
PARSE=0 DEBUG_PARSE=0 App/PlayAdvancedView.swift
PARSE=0 DEBUG_PARSE=0 App/PlayExperienceView.swift
PARSE=0 DEBUG_PARSE=0 App/PlayKitPersonalForms.swift
PARSE=0 DEBUG_PARSE=0 App/PlayKitQuestionForms.swift
PARSE=0 DEBUG_PARSE=0 App/PlayKitQuestoViews.swift
PARSE=0 DEBUG_PARSE=0 App/PlayKitSensorChallengeView.swift
PARSE=0 DEBUG_PARSE=0 App/TemplateDetailXbChrome.swift
PARSE=0 DEBUG_PARSE=0 Core/ChallengePOI.swift
PARSE=0 DEBUG_PARSE=0 Core/MoneyParityRules.swift
PARSE=0 DEBUG_PARSE=0 Core/PlayContracts.swift
PARSE=0 DEBUG_PARSE=0 Core/PlayKitQuestoContracts.swift
PARSE=0 DEBUG_PARSE=0 Core/PlayRunLifecycle.swift
PARSE=0 DEBUG_PARSE=0 Core/PostGameReport.swift
PARSE=0 DEBUG_PARSE=0 Tests/CoreTests/ChallengePOISubmissionTests.swift
PARSE=0 DEBUG_PARSE=0 Tests/CoreTests/MoneyParityRulesTests.swift
PARSE=0 DEBUG_PARSE=0 Tests/CoreTests/PlayExperienceTests.swift
PARSE=0 DEBUG_PARSE=0 Tests/CoreTests/PlayKitQuestoContractsTests.swift
PARSE=0 DEBUG_PARSE=0 Tests/CoreTests/PostGameReportTests.swift
```

### Python static checks on VPS `work` (`/data/workspace/appcheck-ui-h-mp-delta-4`, commit `127f537a5`)

- `python3 tools/check_scaffold.py` -> `EXIT=0` (`PASS structural checks: 4774 Swift source files, 16571 bilingual keys, references, scheme, read-only expected project equivalence`; includes `check_catalog_coverage.py`, `check_missing_string_keys.py`, `check_release_config.py`, `check_privacy_manifest.py`, `check_design_lint.py`, `check_a11y.py`, `check_appsession_ratchet.py`, `build_page_route_table.py --check`)
- `python3 tools/check_design_lint.py` -> `EXIT=0` (`PASS design lint: scanned 1634 App Swift files outside DesignSystem and Theme; allowlist 29 files (44 existing violations)`)
- `python3 tools/check_a11y.py` -> `EXIT=0` (`PASS accessibility lint: 10 scoped screens, helper checked, 2 range views left, 3096 other App views not scanned`)
- `python3 tools/contract_ratchet.py --check` -> `EXIT=0` (`contract ratchet: 186 failing, baseline 186, new 0, fixed 0`)
- `python3 tools/check_design_fixture_release_exclusion.py` -> `EXIT=0` (`App target Release excludes 38 design-fixture sources. Release projection contains none of the audited fixture symbols.`)
- `python3 tools/check_missing_string_keys.py` -> `EXIT=0` (`missing_keys: 0`, `wrong_table: 0`, `incomplete_locales: 0`, `missing: 0`)
- `python3 tools/lint_no_release_print.py` -> `EXIT=0`
- `python3 -B -m unittest tools.tests.test_current_ci tools.tests.test_current_native tools.tests.test_export_current_ui_audit` -> `EXIT=0` (`Ran 99 tests in 1.179s`, `OK`)
- `python3 tools/check_player_journey_screens.py` -> `EXIT=0`
- Pre-existing ledger/pinned-hash scripts not updated for `ui/h-design-v1`: `python3 -B tools/current_ci.py check` (`EXIT=1`, `Current source or test inventory changed without manifest audit`) and `python3 -B tools/run_static_checks.py` (`EXIT=1`, `Changed actual club product: .github/workflows/native-ios.yml`).
