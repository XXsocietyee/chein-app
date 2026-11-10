# Test triage 4 (code-only; no builds, no simulators, no test runs)

Base: origin/ui/main ee3ffb8d9 vs cloud-green rc/20261108 201bf147f. Core/ and Tests/ are untouched in that range; App changes are restyled views, DesignSystem kit, fixtures, and comment-only edits to RegionalLaunchConfiguration and Config/Release.xcconfig.

| class | verdict | action | SHA |
|---|---|---|---|
| MerchantReviewOriginalRecoveryEntryTests | pre-existing | Harness builds `APIConfiguration(baseURL: https://example.invalid)`, but Core/APIConfiguration.swift (unchanged since 47e484bb4, 2026-10-01) rejects `.invalid` hosts with `invalidConfiguration`, so all 13 tests throw in init. Fix belongs in the test host (use a non-.invalid https host such as example.test); not a UI change and Core/Tests are out of scope here. | none |
| NativeChannelTextReadOnlyPresentationTests | pre-existing | `invalidRequest` comes from the test wire when `NativeChannelTextRoute` (Core, untouched) returns nil. Exercised types (NativeChannelTextCoordinator, Journal, History model) are all in untouched Core/App files. Needs a run to see which request is rejected. | none |
| NativeChannelHistoryTextHTTPRecoveryTests | pre-existing | Same wire/route rejection as above; NativeChannelHistoryView and all other production types untouched. | none |
| NativeFriendRequestReviewHostingTests | pre-existing | NativeFriendHomeNavigation, NativeFriendFlow and related types untouched (Core/App not in diff). `InvalidTransition` is a hosting/state-machine issue, not copy. | none |
| NativeFriendDirectoryNavigationHostingTests | pre-existing | Same: NativeFriendDirectoryNavigation and NativeFriendDirectoryFlow untouched. | none |
| RoamPlaceDetailReadLifetimeTests | environment | Not in ui-failing-tests-serial.txt (passes on serial re-run); parallel timing flake. | none |
| RoamShareNativeLifetimeTests | environment | Passes serially. It references RoamHistoryShareView/RoamMedalShareView (restyled by us) but asserts only lifetime/ownership, not copy. | none |
| ProjectOwnedEditorTests | environment | Passes serially; ProjectEdit types untouched. | none |
| ProjectEditCompositionTests | environment | Passes serially. | none |
| PrivateHomeSystemKeychainTests | environment | Passes serially (Keychain contention under parallel run). | none |
| Adapt5PasswordLoginOffTests | ours | Source-grep test asserted the old LoginView gate strings. The e4 login restyle (2f15666a0, already in 201bf147f) routes the form through `showsPasswordForm` (DEBUG: `session.canUsePassword`; release: `false`). Updated expectations to the new gate and added assertions on the compile-time release `return false`; strictly stronger, no copy involved. | 158393ece |
| ApprovedReleaseOriginalRecoveryTests | pre-existing | Pure model test (ProjectEditSession, ApprovedTopicRelease*); no touched files. Needs a run for root cause. | none |

Not re-run (machine overload). Verdicts for pre-existing rows rest on the production files being unchanged in the range; they were not reproduced.
