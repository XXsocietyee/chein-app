# ui/h-popups-social — Social / Community / IM / Channels / Team / Friends Pop-up Parity

- Branch: `ui/h-popups-social`
- Base: `origin/ui/h-design-v1` (`5d652cc08`)
- Area: `club / community / IM / channels / team / friends / official / square / favorites`
- Parity audit: [`docs/parity/popups-social.csv`](../../../parity/popups-social.csv) (50 audited pop-up entries, all marked `DONE`)

## Scope Implemented

1. **DesignSystem enhancements**
   - `App/DesignSystem/CYConfirmSheet.swift`: Added optional `cancelTitle: String? = nil`, `confirmDisabled: Bool = false`, `onCancel: (() -> Void)? = nil`, and multi-line wrapping for sheet title; fixed cancel button rendering when `consequences` is empty.
   - `App/DesignSystem/CYSheetModal.swift`: Added `closeIdentifier` on `CYSheetContainer` and `CYOptionSheet`, `identifier` on `CYOptionSheetItem`, `cyAccessibilityID(id:)` helper, nullable `cancelTitle` on `CYModal` (supporting 1-button info alerts), AX vertical stacking on `CYModal`, and multi-line wrapping on `CYOptionSheet` item labels.

2. **Team & Friends**
   - `App/TeamComponents.swift`: `TeamReviewSheet` & `TeamInvitePreview` converted to `CYSheetContainer` + `.cyDomainSheet` + structured consequences (`team.consequence.*`), DesignSystem button styles, and `.cyToast` on invite copy/unavailable.
   - `App/NearbyTeamViews.swift`: `NearbyTeamReviewView` converted to `CYSheetContainer` + `.cyDomainSheet` + consequences (`nearby.consequence.reject.*`).
   - `App/TeamReportReasonSheet.swift`: Converted to `CYSheetContainer` + `.cyDomainSheet` + selectable reason rows and DesignSystem button styles.
   - `App/NativeFriendRemovalView.swift`: Replaced both `.confirmationDialog`s (removal and retry) with `.sheet` + `CYConfirmSheet` (`isDestructive: true`, `confirmDisabled`, consequences).
   - `App/NativeFriendHomeView.swift`: Converted `flow.actionReview` sheet to `CYSheetContainer` + `.cyDomainSheet`.

3. **IM & Channels**
   - `App/MessagingHistoryView.swift`: `IMChatMoreMenu` converted from `Menu` to `Button` + `CYOptionSheet` (`.cyDomainSheet`, `onDismiss` transition chaining); enriched `ChatSafetySheet.reviewing(_:)` with consequences.
   - `App/IMConversationSafetyViews.swift`: Converted `IMSafetyReviewView` `.reviewing` state to `CYConfirmSheet` with structured consequences (`.unblock`, `.report`, `.hide`, `.block`).
   - `App/MessageActionComposer.swift` & `App/OrdinaryIMSendReceiptRecoveryView.swift`: Converted `.alert` / `.confirmationDialog` confirmations to `.sheet` + `CYConfirmSheet` (`.cyDomainSheet(detents: [.peek, .half])`).
   - Converted 12 `NativeChannel*` pop-ups (`NativeChannelAppealEntry`, `NativeChannelChainView`, `NativeChannelCheckinView`, `NativeChannelMessageActionSheet`, `NativeChannelMessageConversationHost`, `NativeChannelMessageHostDestination`, `NativeChannelMessagePinsView`, `NativeChannelModerationEntry`, `NativeChannelNotificationConversationView`, `NativeChannelPersonalStateEntry`, `NativeChannelProgressPrivacyView`, `NativeChannelRoleEntry`) from native `.confirmationDialog`/`.alert`/`Form` to `CYOptionSheet` / `CYConfirmSheet` / `CYSheetContainer` / `CYModal`.

4. **Official, Favorites & Square**
   - `App/OfficialOrganizerConsoleView.swift`: Converted publish/pause/resume `.confirmationDialog` to `CYConfirmSheet` with consequences (`official.organizer.(schedule|pause|resume).c1..c3`).
   - `App/AccountCollectionFavoritesView.swift`: Replaced recommend note `.alert` with `CYModal` 1-button overlay.
   - `App/TopicUnlikeControls.swift`: Converted unlike `.alert` to `CYConfirmSheet` and added `.cyToast("topic.unlike.toast")` upon removal.
   - `App/SquareDetailView.swift`: Replaced block notice `.alert` with `CYModal` 1-button overlay and unwrapped `SquareDeletionConfirmView` from `NavigationStack`.
   - `App/SquareDeletionViews.swift`: Converted `SquareDeletionConfirmView` `List` to `CYConfirmSheet` with consequences (`square.delete.c1`, `square.delete.c2`).
   - `App/SquareCloudFeedViews.swift`: Converted `SquareCloudPostActions` from hardcoded `CYNight` / `.red` / dark `NavigationStack` to `CYOptionSheet` + `CYConfirmSheet` + `CYSheetContainer` empty state.
   - `App/SquareReportView.swift`: Converted discard `.confirmationDialog` to `CYConfirmSheet` and reason picker `List` to `CYSheetContainer`.
   - `App/SquareWorkspaceView.swift`: Replaced issue `.alert` with `CYModal` overlay, location withdrawal `.confirmationDialog` with `CYConfirmSheet`, and added `.cyToast("square.workspace.draftDeleted.toast")` after draft deletion.
   - `App/SocialActionViews.swift`: Converted discard `.confirmationDialog` to `CYConfirmSheet`.

5. **Club**
   - `App/ClubBadgeManagementView.swift`: Converted grant `.confirmationDialog` to `CYConfirmSheet` with 3 consequences and converted `createForm` to `CYSheetContainer`.
   - `App/ClubGovernanceCommandForm.swift`: Converted event cancel `.alert` to `CYConfirmSheet` with consequences (`clubOpsEvent.cancel.consequence1..2`).
   - `App/ClubOperationsViews.swift`: Converted discard `.confirmationDialog` to `CYConfirmSheet` / 3-option `CYSheetContainer` (`profileDraftEnabled`).
   - `App/ClubPostEditExitControl.swift`, `App/ClubProfileDraftRecoverySection.swift`, `App/ClubWelcomeNoteEditor.swift`, `App/ClubPayoutReceiverView.swift`, `App/ClubContextualViews.swift`: Converted `.confirmationDialog`s to `.sheet` + `CYConfirmSheet`.
   - `App/ClubMembersView.swift` & `App/ClubChannelMessagingView.swift`: Converted `.confirmationDialog` menus to `CYOptionSheet`.
   - `App/ClubOwnerRefundPanel.swift`: Converted `NavigationStack { Form }` refund review sheet to `CYSheetContainer` + `CYCard` evidence + 3 consequences + `CYDestructiveButtonStyle`.
   - `App/ClubCommunityViews.swift`: Converted `ClubCommunityReviewView` to `CYSheetContainer` + `CYCard` facts + `.cyToast` on pin/unpin/delete settlement.

6. **Localization**
   - Added bilingual (`en` + `zh-Hans`) translated keys to `Resources/Localizable.xcstrings`, `Resources/ClubBadge.xcstrings`, and `Resources/ClubOpsEvent.xcstrings` using mini-program Chinese copy for `zh-Hans`.
   - Preserved all existing test contract fragment keys untouched.

## DEBUG Fixtures

Added `#if DEBUG` previews in [`App/DesignFixtures/PopupsSocialFixtures.swift`](../../../App/DesignFixtures/PopupsSocialFixtures.swift), registered in `App/DesignFixtures/DesignFixtureRegistry.swift`:
- `popups-team-leave`
- `popups-team-disband`
- `popups-im-more`
- `popups-im-safety`
- `popups-official-pause`
- `popups-square-actions`
- `popups-favorites-unlike`
- `popups-club-refund`
- `popups-club-badge`
- `popups-club-channel-report`
- `popups-club-cancel-event`
- `popups-social-ax5`

## Verification (Mac Local)

- `python3 tools/generate_project.py`: `Generated Questify.xcodeproj: 3637 native sources, 217 catalogs` (exit `0`).
- `python3 tools/check_design_fixture_release_exclusion.py --write` & `--check`: `wrote App/DesignFixtures/DesignFixtureReleaseExclusionAudit.swift: 204 symbols`, `App target Release excludes 39 design-fixture sources. Release projection contains none of the audited fixture symbols.` (exit `0`).
- `python3 tools/check_scaffold.py`: `missing_keys: 0`, `untranslated_values: 0`, `key_identifier_mismatches: 0`, `gaps: 0`, `PASS structural checks: 4775 Swift source files, 16620 bilingual keys, references, scheme, read-only expected project equivalence` (exit `0`).
- `python3 tools/check_design_lint.py`: `PASS design lint: scanned 1635 App Swift files outside DesignSystem and Theme; allowlist 29 files (44 existing violations)` (exit `0`).
- `python3 tools/check_a11y.py`: `PASS accessibility lint: 10 scoped screens, helper checked, 2 range views left, 3106 other App views not scanned` (exit `0`).
- `python3 tools/check_missing_string_keys.py`: `missing_keys: 0`, `wrong_table: 0`, `incomplete_locales: 0`, `missing: 0` (exit `0`).
- `xcrun swiftc -parse` and `xcrun swiftc -parse -D DEBUG` on all 47 modified/added `.swift` files (`TOTAL_SWIFT_FILES=47 EXIT=0`):
  - `App/AccountCollectionFavoritesView.swift`: `parse=0 debug_parse=0`
  - `App/ClubBadgeManagementView.swift`: `parse=0 debug_parse=0`
  - `App/ClubChannelMessagingView.swift`: `parse=0 debug_parse=0`
  - `App/ClubCommunityViews.swift`: `parse=0 debug_parse=0`
  - `App/ClubContextualViews.swift`: `parse=0 debug_parse=0`
  - `App/ClubGovernanceCommandForm.swift`: `parse=0 debug_parse=0`
  - `App/ClubMembersView.swift`: `parse=0 debug_parse=0`
  - `App/ClubOperationsViews.swift`: `parse=0 debug_parse=0`
  - `App/ClubOwnerRefundPanel.swift`: `parse=0 debug_parse=0`
  - `App/ClubPayoutReceiverView.swift`: `parse=0 debug_parse=0`
  - `App/ClubPostEditExitControl.swift`: `parse=0 debug_parse=0`
  - `App/ClubProfileDraftRecoverySection.swift`: `parse=0 debug_parse=0`
  - `App/ClubWelcomeNoteEditor.swift`: `parse=0 debug_parse=0`
  - `App/DesignFixtures/DesignFixtureRegistry.swift`: `parse=0 debug_parse=0`
  - `App/DesignFixtures/DesignFixtureReleaseExclusionAudit.swift`: `parse=0 debug_parse=0`
  - `App/DesignFixtures/PopupsSocialFixtures.swift`: `parse=0 debug_parse=0`
  - `App/DesignSystem/CYConfirmSheet.swift`: `parse=0 debug_parse=0`
  - `App/DesignSystem/CYSheetModal.swift`: `parse=0 debug_parse=0`
  - `App/IMConversationSafetyViews.swift`: `parse=0 debug_parse=0`
  - `App/MessageActionComposer.swift`: `parse=0 debug_parse=0`
  - `App/MessagingHistoryView.swift`: `parse=0 debug_parse=0`
  - `App/NativeChannelAppealEntry.swift`: `parse=0 debug_parse=0`
  - `App/NativeChannelChainView.swift`: `parse=0 debug_parse=0`
  - `App/NativeChannelCheckinView.swift`: `parse=0 debug_parse=0`
  - `App/NativeChannelMessageActionSheet.swift`: `parse=0 debug_parse=0`
  - `App/NativeChannelMessageConversationHost.swift`: `parse=0 debug_parse=0`
  - `App/NativeChannelMessageHostDestination.swift`: `parse=0 debug_parse=0`
  - `App/NativeChannelMessagePinsView.swift`: `parse=0 debug_parse=0`
  - `App/NativeChannelModerationEntry.swift`: `parse=0 debug_parse=0`
  - `App/NativeChannelNotificationConversationView.swift`: `parse=0 debug_parse=0`
  - `App/NativeChannelPersonalStateEntry.swift`: `parse=0 debug_parse=0`
  - `App/NativeChannelProgressPrivacyView.swift`: `parse=0 debug_parse=0`
  - `App/NativeChannelRoleEntry.swift`: `parse=0 debug_parse=0`
  - `App/NativeFriendHomeView.swift`: `parse=0 debug_parse=0`
  - `App/NativeFriendRemovalView.swift`: `parse=0 debug_parse=0`
  - `App/NearbyTeamViews.swift`: `parse=0 debug_parse=0`
  - `App/OfficialOrganizerConsoleView.swift`: `parse=0 debug_parse=0`
  - `App/OrdinaryIMSendReceiptRecoveryView.swift`: `parse=0 debug_parse=0`
  - `App/SocialActionViews.swift`: `parse=0 debug_parse=0`
  - `App/SquareCloudFeedViews.swift`: `parse=0 debug_parse=0`
  - `App/SquareDeletionViews.swift`: `parse=0 debug_parse=0`
  - `App/SquareDetailView.swift`: `parse=0 debug_parse=0`
  - `App/SquareReportView.swift`: `parse=0 debug_parse=0`
  - `App/SquareWorkspaceView.swift`: `parse=0 debug_parse=0`
  - `App/TeamComponents.swift`: `parse=0 debug_parse=0`
  - `App/TeamReportReasonSheet.swift`: `parse=0 debug_parse=0`
  - `App/TopicUnlikeControls.swift`: `parse=0 debug_parse=0`
