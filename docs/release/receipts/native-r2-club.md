# Receipt: native-r2/club (2026-11-26)

Brief: `design/handoff-r2:docs/briefs/native-r2.md` (component rule, EVERYTHING-native, gates). Base: `origin/ui/combined-r7` (merged before every push).
Scope: only App files whose names start with Club, Group, Channel, NativeChannel, Social, Friend or Team (not TeamOrient*), 249 files and about 49k lines. 154 files were changed; the rest were already native or have no UI (glue, route state, journals, fixtures). No change to App/DesignSystem, CYDomainPalette, Theme, Core/ or tests.

## Gates
- `python3 tools/check_scaffold.py`: `PASS structural checks` on the pushed tree.
- There is no compiler in the cloud. Every non-SwiftUI API was grepped. The deployment target is iOS 17.0, so nothing iOS 18-only is used without `#available`.
- No `if let` shadows an `@State`. No signatures changed on declarations used from other files.
- `accessibilityIdentifier`: a diff of removed against added literal ids shows that every id is kept. The one exception is `club.directory.search`: the custom search field became `.searchable`, which cannot carry an id. No test referenced it.
- No new string keys, so no `docs/port/strings/native-r2-club.json` fragment was needed. Only existing keys are reused, for example `action.cancel`.
- Requests, Tasks, gating and money flows are unchanged. Refund, payout, owner funds and settlement keep the same gates and confirm steps; only the confirm UI is now native.

## What changed (by component rule)
- `CYPillButton` became `Button` with `.borderedProminent` / `.bordered` / `.borderless` and `.controlSize(.large)`, with one prominent button per screen. Row actions are plain `Button` rows, and destructive ones use `role: .destructive`.
- `CYEmptyState` / `ClubEmptyState` became `ContentUnavailableView`. `CYSkeleton` / `CYLoadingStateView` / `CYLoadSlot` became `ProgressView`.
- `CYListRow` / `CYFactRow` / `CYRowIcon` became `Label` / `LabeledContent` / `NavigationLink`. `CYStatusChip` / `CYChipRow` became secondary Text or a tinted `Label`.
- `CYHeroHeader` / `CYHeroBanner` became `.navigationTitle`, with MP images kept as a first-section row. `CYSectionHeader` became a `Section` header. `CYNoteBanner` became a footer or an `info.circle` Label.
- `CYConfirmSheet` / `CYModal` / `CYOptionSheet` became `.confirmationDialog` or `.alert`. Confirmations that list consequences became a `.sheet` with `NavigationStack` + `List` and Cancel/Confirm in the toolbar, at `.medium`/`.large` detents.
- Inputs moved into `Form` sections. Live character counters became footer hints and validation is shown in footers. The directory search and the create-wizard city picker use `.searchable`. Customer filters are a segmented `Picker`.
- Removed: card plates and "glass", the `RoundedRectangle` fills, `.listStyle(.plain)` + clear rows + page backgrounds, palette/hex colours, gradients (including the chat location/video cards), the row-reveal and title-rise animations, the join seal/burst, confetti and medal orbit, and `.preferredColorScheme(.dark)` (story and card fixtures). The NativeChannel shared modifiers (`nativeChannelScreen`, `nativeChannelPrimaryAction`, `nativeChannelNotice`, `NativeChannelSectionTitle`) now resolve to system styles. `cyHaptic` / `.sensoryFeedback` are kept.
- Smoother: compose moved to a toolbar `primaryAction`, the image picker gains `.swipeActions` delete, the invite is a `ShareLink`, the channel sidebar uses `.badge`, and inline join stays in the club list.

## Left custom (no Apple equivalent, or left for risk)
- `ClubDetailTabBar`: UI tests tap `club.detail.tab.<key>` and read `isSelected`. A segmented `Picker` cannot give each segment its own id, so this needs a decision on the test.
- The club calendar month grid (no system per-day event grid) now uses system colours only.
- The story chapter chips are a row of `.bordered` capsule buttons, because UI tests drag-scroll them.
- Chat transcript bubbles (channel chat, `ChatMessageBubble`, E3 chat cards) stay a Messages-style transcript, and the chat list keeps `.listStyle(.plain)` as Messages does. The channel top bar stays an in-content `.bar` row.
- Team seat strips (dashed and filled circles) are an MP visual. `ClubBadgeArt` is badge artwork, like Fitness awards.
- These are MP or cover art and are kept: `ClubMPEmptyState`, `ClubMPAvatar`, `ClubCloud14Banner`, `CYCoverArt`, `NativeChannelCoverBanner`, `QuestifyImageEntityCard` (club cover, `TeamCard`), `CYClubGameCodeCard`, and the QR code's white background, which keeps it scannable.
- `ClubPageEndActions` keeps a rounded container because `ClubActionPanel` hosts it in one zero-inset row that holds the confirm lifecycle.
- The create wizard and edit-save bottom bars stay as `.safeAreaInset` on `.bar` (two buttons plus failure text). `ClubRoleAssignmentPicker` DisclosureGroups and the `ClubSeriesOccurrenceBrowser` expand toggle stay, to protect selection and expand state.
- `TeamMeetingHandshakeSectionView` and `ClubGapSurfaces` keep their CYColor tokens because existing lint/contract checks ban `.red`/`.secondary` in those files.
- The shared DesignSystem pieces that are out of this lane's scope are still used: `ClubTabTagLine` children, `CYScreenOfflineWriteBanner`, `cyDomainScreen`/`cyDomainSheet`, `CYAvatarView`, and the `CYClubPhotoCard`/`CYClubRowCard` demo in `ClubCardFixtures`.

## Behaviour notes
- The join/apply reward animation and the team invite toast are gone. The status row and haptic appear immediately.
- The appeal and welcome-note live counters are gone; the limit is shown in the footer and validation is unchanged.
- ClubContextualViews: the ops-time confirm is an `.alert`, and the reviewed request is passed straight into `save` (the alert clears `review` on dismiss). `save` still checks `canSave`.
- `ClubPostImagePicker`: the replace and remove buttons are borderless, which fixes a whole-row tap that fired both.

## Python contract tests that pin the old custom UI (they need updating; the code follows the brief)
These tests assert the old source text: `test_accessibility_hardening_wave.test_jump_pill_uses_tokens`, `test_club_customer_clear_filters`, `test_club_detail_leaderboard_member` (`CYOptionSheet`), `test_club_story_runtime_boundary` (`.cyText(.sheetTitle)`), `test_team_invite_copy`, `test_e2e_20261113_r12_r13` (`CYPillButton("club.community.confirm")`), `test_merchant_club_accessible_controls`, `test_merchant_club_discovery` (`CYListRow("club.owned"`, `actionTitle: "action.retry"`), `test_club_invitation_terms` (`CYEmptyState`/`CYSkeleton()`), `test_club_notification_audience` (`.cyPressable`), `test_profile_self_edit_return` (`CYPillButton`), `test_native_channel_appeal_localization` (the `/500` counter), `test_social_article_content` (`CYEmptyState`/`CYStatusChip`), `test_ui_workbench_navigation` (`palette.textPrimary`) and `test_design_system_component_contracts` (raw `Color(`, mainly from the chat bubble files). Many other failures were already there on the base (frozen hashes and file lists).

## APIs to check first in Xcode (iOS 17)
- `ContentUnavailableView` as a List/Form row, and its `{ label } actions: { }` form without a description.
- `.confirmationDialog(..., presenting:)` with a computed Binding.
- `Button(role: cond ? .destructive : nil)`, `.font(cond ? .headline : .body)`, and `AnyShapeStyle` ternaries.
- `ToolbarItem` inside `if` in `.toolbar`, `.sensoryFeedback(trigger:) { _, _ in … }`, `.searchable(text:placement:prompt: Text)` and `Rectangle().fill(.bar)`.
