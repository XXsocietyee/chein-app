# Roam hub tap bug (rbug)

Branch `ui/rbug` = `ui/main` (3b319cbb9, includes pol2) + this fix.

## Cause
`CYListRow` applied `cyPressTracking()` to every row. That modifier adds a
`simultaneousGesture(LongPressGesture(minimumDuration: 60, maximumDistance: 10))`.
Inside a `List` `NavigationLink` on the iOS 27 simulator runtime that gesture swallows the tap, so no
Roam hub row (history, recovery, live, tiles, album, ...) navigated. It is a real, user-visible
regression (all `CYListRow` rows in a NavigationLink), not a test artefact.

Bisect (hub launched interactively on Lane2 with temporary `--rbug-*` launch flags, since removed):
- hero, passport overview, tools section, private links all off: tap still dead (not the culprit,
  `navigationDestination` inside the lazy List ruled out as the tap cause).
- history row label replaced by plain `Text`: push works (`history onAppear` logged).
- `CYListRow` without `cyPressTracking`: push works.

## Fix
`App/DesignSystem/CYListRow.swift`: drop `cyPressTracking()` from both branches. The enclosing
NavigationLink/Button provides the pressed highlight. Other `cyPressTracking()` call sites
(Settings, Messaging home, ticket wallet, club members, image card) are untouched and may share the
problem if they sit in a NavigationLink; not verified here.

## Before / after (RoamExperienceFlowTests, Questify-iPhone17-Lane2)
- Before: 0/14 pass (coordinator baseline); single-test repro `testAlbumHidesRejectedStampAndLabelsUnsubmittedReview`
  failed at the row tap (`open()`), nothing navigated.
- After: 8 pass / 6 fail of 14. Navigation now works in all tests; the 6 remaining failures are past
  the tap and are separate:
  - testHistoryDistinguishesUnknownStatsAndShowsSession: "Saved local journey" text missing (line 23)
  - testCorruptHistoryIsErrorNotEmpty: "Your roam history couldn't be loaded." copy (line 31)
  - testAlbumHidesRejectedStampAndLabelsUnsubmittedReview: "Not submitted to automated review" (line 59)
  - testAlbumPageErrorKeepsAlreadyLoadedStamp: `roam.experience.error` not found after "more" (line 64)
  - testOfflineLiveExplicitStartPauseResumeAndConfirmedFinish: `revealFixtureElement` for the consent button (line 108)
  - testOfflineLiveUnknownBootstrapIsRecoveredBeforeExplicitResume: "Needs a quick check" (line 138)
  Likely copy/fixture drift or live-screen reveal; to be triaged by the owner of those screens.

## Checks
`check_design_lint.py` PASS, `check_scaffold.py` PASS. contract_ratchet not run. No fixture symbols added.
Build/test ran only under `/private/tmp/design-build.lock`, arm64, DerivedData `/private/tmp/dd-rbug`.
Note: the Bash sandbox blocks the testmanagerd socket, so xcodebuild `build-for-testing` ran in Bash and
tests ran via XcodeBuildMCP `test_sim` with the generated xctestrun (not under the lock).
