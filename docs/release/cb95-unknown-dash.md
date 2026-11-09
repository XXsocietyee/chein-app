# CB95 — unknown numbers stay unknown

Base: `origin/rc/20261108` `027e4985c53164127fd7bfd2b4845efbfc4c9e0b`.
Branch: `cursor/cb95`.

A missing number is unknown. It renders as an em dash (`—`, U+2014). A literal `0` stays `0`. This pass changes models and formatters only. Views were not restyled: no colors, type, spacing, or layout. `App/RoamItemDetailView.swift` still uses the same three `LabeledContent` rows; the value strings now come from `RoamPlayer` formatters so a missing stat can stay missing. `tools/current_ci_manifest.json` was not refreshed. `.github/workflows/ios-ci.yml` was not edited.

`swift`, `swiftc`, and `xcodebuild` are not on this machine. No Swift run is claimed. Existing tests were kept. Assertions that locked “unknown becomes 0” were updated, and new cases were added for the formatters that changed.

## Fixed (12 model / formatter sites)

| # | Site | Was | Now |
|---|---|---|---|
| 1 | `Core/ParticipationParity.swift` `pendingText` | `String(pending ?? 0)` | nil → `—`, `0` → `"0"` |
| 2 | `Core/ParticipationParity.swift` `verifiedText` | `String(verified ?? 0)` | nil → `—`, `0` → `"0"` |
| 3 | `Core/ParticipationParity.swift` `totalText` | `String(total ?? 0)` | nil → `—`, `0` → `"0"` |
| 4 | `Core/ClubDetailRankingPort.swift` `oneDecimal` | nil and the format of `0` → `"0.0"` | nil / non-finite → `—`, `0` → `"0.0"` |
| 5 | `Core/OfficialEventDetailPresentation.swift` participants fact | `String(event.participants ?? 0)` | `countText`, nil → `—`, `0` → `"0"` |
| 6 | `Core/OfficialEventDetailPresentation.swift` signed `myProgress` fact | `String(event.myProgress ?? 0)` | same `countText` |
| 7 | `Core/MerchantMarketingHome.swift` `heroValue` | `compact(signup ?? 0)` so a missing analytics block was `"0"` | missing stage → `—`, literal `0` → `"0"` |
| 8 | `Core/RoamSubpagePresentation.swift` `RoamRunCardPresentation.distanceText` | unread distance → `"0"` | unread → `—`, literal `0` → `"0"` |
| 9 | `Core/RoamContracts.swift` `RoamPlayer.explorePct` | missing decode → `0`, then `"0%"` | missing stays nil; `exploreText` is `—` or `"0%"` |
| 10 | `Core/RoamContracts.swift` `RoamPlayer.shops` | missing decode → `0` | missing stays nil; `shopsText` is `—` or `"0"` |
| 11 | `Core/RoamContracts.swift` `RoamPlayer.elapsedSec` | missing decode → `0` | missing stays nil; `walkingMinutesText` is `—` or `"0"` |
| 12 | `Core/ProjectEditContract.swift` ticket `teamSize` restore | missing integer → `"0"` in the editor field | missing → `""`, literal `0` → `"0"` |

A present negative `shops` or `elapsedSec`, and an `explorePct` outside `0...99`, still clamp the way they did. That is a present value, not a missing one.

`App/MerchantMarketingHomeSections.swift` already drew `—` when the SIGNUP stage was missing, and that view was left alone. `heroValue` now agrees with it.

## Leftover view sites (20)

The `0` is introduced in the view. These were not edited.

| # | Site | What shows `0` |
|---|---|---|
| 1 | `App/PlayAdvancedTeamViews.swift` rank | `row["rank"].integer ?? 0` |
| 2 | `App/PlayAdvancedTeamViews.swift` elapsed | `row["elapsedSeconds"].integer ?? 0` |
| 3 | `App/PlayAdvancedTeamViews.swift` score / units | `row[score or completedUnits].integer ?? 0` |
| 4 | `App/PlayAdvancedView.swift` remaining | `state.remainingSeconds(...) ?? 0` |
| 5 | `App/NearbyTeamMapViews.swift` `NearbyMineMembersText` | `joined ?? 0` in both member strings |
| 6 | `App/PrefabPreviewView.swift` skill row | `state.skills[key] ?? 0` |
| 7 | `App/PlayPrefabRuntimeView.swift` skill row | `scene.story.skills[key] ?? 0` |
| 8 | `App/TemplateCreatorRehearsalView.swift` goal | `fields["goal"]?.integer ?? 0` |
| 9 | `App/TemplateCreatorRehearsalView.swift` poem count | `raw.array?.count ?? 0` |
| 10 | `App/TemplateRootRehearsalView.swift` sample stepper | `sample.values[key] ?? 0` |
| 11 | `App/BundleWalletView.swift` unit counts | `balance.counts[key] ?? 0` |
| 12 | `App/PlaySharedPlanLifecycleView.swift` quantity field | `quantities[cost.itemID] ?? "0"` |
| 13 | `App/PlaySharedPlanLifecycleView.swift` proposal version | `row.version ?? 0` |
| 14 | `App/NativeFriendTeamInviteEntry.swift` offer summary | `review.body.peers?.count ?? 0` |
| 15 | `App/CoopListParitySections.swift` topic title | `row.topicID ?? 0` when the name is missing |
| 16 | `App/ModInstallationTemplateEditorView.swift` draft id | `original.installation.draftId ?? 0` |
| 17 | `App/ClubChannelMessagingView.swift` reply target | `replyTarget.senderID ?? 0` |
| 18 | `App/PrivateHomeFixtureHost.swift` recorder starts | `mapAdapter?.starts ?? 0` |
| 19 | `App/PlayKitLegacyViews.swift` silent timer | `segment["elapsedSeconds"].integer ?? 0` on appear |
| 20 | `App/WalletCommerceViews.swift` year-month label | `c.year ?? 0` and `c.month ?? 0` |

## Reviewed and not a rendered unknown zero

These were read and left.

- `Core/MerchantReviewSummaryPresentation.swift` `total = max(0, document.total ?? 0)`. A reviews document cannot be built without `total` (`mbInt` throws). The `?? 0` does not run for a document the header can show. Sibling metrics on `App/MerchantReviewSummaryHeader.swift` already use `—`.
- `Core/SquareXcxPresentation.swift` `participants ?? 0` only feeds an overflow chip that is hidden at `0`.
- `Core/SquareContracts.swift` like, comment, dislike, node, and level counts, `Core/ClubContracts.swift` `memberCount` / `level`, and `Core/MerchantContracts.swift` pending / signup / view counts still store a missing integer as `0`. Those `Int`s are also used as gates and counters. Changing the type would rewrite the views that print them. Not done here.
- `Core/PlayRPGPresentation.swift` stores `kept` / `total` / `dc` with `?? 0`. `App/PlayRPGComponents.swift` prints `D20 \(entry.kept)`. Left with the view.
- `Core/ClubOpsEventClock.pad` and `Core/RoamSubpagePresentation.dateLabel` fill a missing date component with `0`. Those components come from a `Date` that already parsed.
- `Core/ProjectEditDraft.swift` still seeds a new local ticket with `teamSize = "0"`. That is a blank editor, not a server omission. Only the restore path was changed.
- Cache keys and enablement checks (`accountID ?? 0`, `failedCount ?? 0` used only as `> 0`, pager `selectedIndex ?? 0` which displays as page 1) do not present a measured unknown as the digit 0.

## Checks

This machine has no `swift`, `swiftc`, or `xcodebuild`. No Swift test run is claimed.

`python3 Tests/ContractChecks/test_w2_04_participation.py` — 7 tests, OK. The literal-zero case is inside the existing `testStatisticsShowZeroForUnknownAndTwoSourceCells`, so the file still has 8 `func test` declarations.

`python3 Tests/ContractChecks/test_official_detail_parity_w2_06.py` fails on the source order of `App/OfficialEventDetailView.swift`. That view is not in this diff. The same failure happens with these edits stashed.

`python3 Tests/ContractChecks/test_bk_backend_sync.py` fails because `Core/ChinaReviewedRouteCapability.swift` contains `roam/share/snapshot`, and because a topic-like call site list does not match. Neither file is in this diff.

`PYTHONPATH=. python3 Tests/ContractChecks/test_project_edit_contracts.py` fails while authenticating a hash of `.github/workflows/native-ios.yml`. That workflow is not in this diff.
