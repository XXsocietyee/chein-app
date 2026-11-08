# UIV-05 report: clubs and channels group (NOT COMPILED)

Branch `cloud/uiv-05` from `origin/ui/own-1`. Presentation only. No new strings (no `ui-strings-uiv-05.json` needed).

## Screens in scope
| iOS file | mini-program page | reference |
|---|---|---|
| ClubHomeView / ClubDirectoryView | pages/talent/list | player-e2e 021-clubs, 034-player-clubs; merchant-deep 002/003 |
| ClubDetailView, ClubChannelMessagingView | pages/club/detail | merchant-deep 004/005 |
| ClubActionPanel (join/apply/quit) | pages/club/detail | merchant-deep 006/007/008 |
| ClubEnrollmentView | pages/club/enroll | |
| ClubGovernanceViews, ClubGovernanceCommandForm | pages/club/topic-detail, governance, apply | |
| ClubOperationsViews | pages/club/create, edit | merchant-deep 010..019 |

## Fixed
- Join / apply / quit confirmation in `ClubActionPanel` is now a bottom sheet (`CYConfirmSheet`), destructive style for quit; was `confirmationDialog`. `accessibilityIdentifier` `club.action.confirm` kept on the confirm button.
- `ClubGovernanceCommandForm` discard confirmation is now `CYConfirmSheet` (destructive), was `confirmationDialog`.
- `CYConfirmSheet`: additive optional params `isDestructive` (default false) and `confirmIdentifier` (default nil). Existing call sites unaffected.
- Raw system colours replaced by tokens: Enrollment check-in status, Governance status/reject/dissolve, Operations dissolve and counter, ClubHome locality warning (`CYColor.successText/warningText/dangerText/textSecondary`).

## Left (not done)
- Full per-screen diff against the screenshots (layout order, type scale, skeleton/empty/error states, Dynamic Type) was NOT done; screenshots were not viewed in this run.
- Remaining `.foregroundStyle(.secondary)` uses (semantic styles, theme-safe) left as is.
- Other `confirmationDialog`s left: `ClubOperationsViews` discard (has a multi-action draft branch), `ClubChannelMessagingView` report-reason picker (an action list, not a yes/no confirmation), `ClubMembersView` choice, badge grant, series removal, welcome note save, `NativeChannel*` retry dialogs.
- Channel list / message row restyle (`NativeChannelMessageBubbleView` etc.) not touched.

## Compile / test risks
- `Tests/AppUITests/ClubActionFlowTests.swift` (~line 45-57) looks for `app.sheets.firstMatch` with label equal to the action title and a button in `dialog.buttons`. The new sheet keeps the button identifier, but the sheet's accessibility label/structure may differ. Coordinator should run that UI test and adjust (tests were not edited).
- `String(localized: String.LocalizationValue(key))` is used with runtime keys; keys must exist in the main catalog (they are the same keys the old dialog used).
- In `CYConfirmSheet.styled(_:)` uses `some View` parameter (Swift 5.7+).
