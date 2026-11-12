# App-wide press/tap fix (presstap)

Branch `ui/presstap` = `origin/ui/rbug` (e63a35879) + this work.

## Cause
`CYPressTracking` (App/DesignSystem/CYMotion.swift) installed
`simultaneousGesture(LongPressGesture(minimumDuration: 60, maximumDistance: 10))` to drive the press scale.
On the iOS 27 runtime that gesture swallows NavigationLink taps inside a `List`. ui/rbug only removed it from
`CYListRow`. The new Messaging test reproduces the same dead tap on the Messaging inbox before this fix
(`testInboxRowTapNavigatesToConversation` fails: row 901 tapped, conversation never pushed).

## Fix (at the source)
- `CYPressTracking` installs no gesture. It reads `\.cyIsPressed` from the environment and applies
  `cyPressEffect` (scale 0.97, Reduce Motion: dim). `cyPressHandled` short-circuit is kept.
- New `CYPressButtonStyle` (`.buttonStyle(.cyPressTracked)`) publishes `configuration.isPressed` to the label
  and draws nothing itself (disabled dims like `.plain`), so only the kit card scales.
- Call sites (all accessibility identifiers unchanged):
  - `CYListRow`: `cyPressTracking()` restored (now passive; List row highlight is the feedback in a List).
  - `ClubEnrollmentView` team header button: `.plain` -> `.cyPressTracked` (keeps the header press scale).
  - `ClubMembersView` member + report buttons: `.cyPressTracked` (keeps scale; these were `.borderless`).
  - `MessagingHomeView` inbox NavigationLink, `TicketWalletView` teams NavigationLink: modifier removed
    (List row highlight). Non-tappable wallet row: modifier removed (nothing to press).
  - `CYImageCard`, `SettingsAccountCard`: keep `cyPressTracking()`; they scale under `CYPressableStyle`/
    `.cyPressTracked` parents and fall back to the parent's own highlight (e.g. `.plain` dim) otherwise.

## UITests (Questify-iPhone17-Lane2, xctestrun from `build-for-testing`, run via XcodeBuildMCP test_sim)
| Suite | Before (rbug app + new tests) | After |
| --- | --- | --- |
| RoamExperienceFlowTests | 8/14 | 12/14 |
| EntryFlowTests | 7/7 | 7/7 |
| TicketWalletFlowTests | 6/6 | 6/6 |
| PageFlowGoldenPathTests | 1/1 | 1/1 |
| IMMessagingParityUITests/testInboxRowTapNavigatesToConversation (new) | 0/1 | 1/1 |
| SettingsNativeFlowTests/testSettingsRowTapsNavigate (new) | 1/1 | 1/1 |
| Total | 23/30 | 28/30 |

A first "after" attempt aborted with the test runner killed (signal kill, load ~41); the rerun above is clean.
Note: "before" for RoamExperience used the old tests; 4 of its 6 failures were fixed by test updates below,
not by the press fix (ui/rbug had already restored hub navigation).

## Triage of the 6 RoamExperience failures from roam-hub-tap.md
None is an app bug.
- testOfflineLiveExplicitStartPauseResumeAndConfirmedFinish, testOfflineLiveUnknownBootstrapIsRecoveredBeforeExplicitResume:
  test helper `acceptLocationPrimerIfShown` waited for `cy.permission.priming.primary`; the e5c priming view
  (CYStateKit) uses `permission.priming.allow`, so the primer stayed up and the roam never started.
  Fixed in Tests/AppUITests/FailureScreenshot.swift. Both pass.
- testCorruptHistoryIsErrorNotEmpty: copy is now "Your roam history couldn't be loaded. It has not been replaced."
  Assertion updated. Passes.
- testAlbumPageErrorKeepsAlreadyLoadedStamp: a failed later page now shows the continuation footer
  (`roam.experience.album.continuationRetry`, stamps kept) instead of the whole-page error. Assertion updated. Passes.
  (Side note for the album owner: "Load more" stays visible next to the retry footer.)
- testHistoryDistinguishesUnknownStatsAndShowsSession ("Saved local journey", line 23) and
  testAlbumHidesRejectedStampAndLabelsUnsubmittedReview ("Not submitted to automated review", line 59):
  STILL FAILING, recorded as test-data / product issues. Both labels (`roam.experience.savedRecord`,
  `roam.experience.reviewNotSubmitted`) were removed from RoamHistoryViews / RoamStampViews in the reviewed
  snapshot f9ca1f424; the strings remain in Localizable.xcstrings unused. Owner decision: restore the
  unsubmitted-review label (honesty) or drop the assertions.

## Checks
`check_design_lint.py` PASS, `check_scaffold.py` PASS. ContractChecks touching the edited files: 406 run,
same 4 failures + 6 errors as the untouched base (pre-existing, not introduced). Builds only under
`/private/tmp/design-build.lock`, arm64, `-jobs 4`, DerivedData `/private/tmp/dd-rbug`. Result bundles:
`/private/tmp/dd-rbug/presstap-before.xcresult`, `/private/tmp/dd-rbug/presstap-after.xcresult`.
