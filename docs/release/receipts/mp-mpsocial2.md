# mp-mpsocial2: clubs + community, second pass (layout side)

Branch `ui/mpsocial2`, base `origin/ui/main` (72d2eb9ec). Source of truth: `liboyang42-cpu/hengyin` `chengyinhub-xcx` (`pages/club/*`, `pages/square/*`, `subpackageB/pages/im/*`). Code-only; not compiled (the integrator builds). `tools/generate_project.py`, `tools/check_design_lint.py` and `tools/check_scaffold.py` pass.
Note: `ui/mpsocial` (first pass, `SquareDetailView` night ground / comment capsule / like spring) is not in `ui/main` yet. This branch also edits `SquareDetailView.swift` in other places (new state vars, the share button, the route card, and modifiers before `.alert`), so expect small textual conflicts when both merge. Keep both sides.

## Built (item 2: missing square pieces)
| mp component | native file | what |
|---|---|---|
| `square/components/cy/popover` (T5 capsule on avatar) | `App/DesignSystem/CYAnchoredMenu.swift`; wired in `SquareComponents.swift` (`SquarePostContent.avatarMenuItems/onAvatarPick`) + `SquareDetailView.swift` | Popover anchored to the avatar (compact adaptation keeps it a popover on iPhone): no dimming, no title, no ✕, dismissed by a tap outside. Items match the mini: **Follow** (only when the follow state is known and false, and the viewer is not the author) and **Visit profile**. Follow opens the existing reviewed `toggleFollow` editor; Visit pushes `SocialPublicProfileView`. The `social.viewAuthor` row is kept. |
| `square/utils/square-share.js` + detail `act-share` | `App/DesignSystem/CYSquareShareSheet.swift`; share button in `SquareDetailView.postActions` after like/comment/bookmark (owner 2026-11-09 order) | `CYSquareSharePayload` mirrors U-050: only PUBLIC + PUBLISHED posts share their own 28-char excerpt + first http(s) image; anything else becomes the generic `城瘾Hub` card with no post content. The half sheet shows that card, then the system share sheet (`ShareLink`) and Copy link. |
| `square/components/route-map` | `App/DesignSystem/CYSquareRouteMapCard.swift`; in `SquareDetailView` when `post.topicID > 0` | Numbered lantern markers plus one polyline (road geometry only when it is verified, otherwise stops are joined directly and the caption says so). Tap a marker to show its title. Renders nothing until the route is ready (mini `wx:if=routeReady`). Optional "View linked activity" link and a static snapshot mode. |
| `square/components/activity-picker` | `App/DesignSystem/CYSquareActivityPicker.swift`; entry in `SquareWorkspaceView` reference section (ACTIVITY type) | Sheet "Choose a completed activity". States: skeleton, load failure + retry, empty ("only completed activities are shown"), rows (cover, name, `done x/total · Cleared`, check). Unknown counts show an em dash. Selecting sets `draft.reference = ACTIVITY #id`. The mini's hidden-map snapshot upload is replaced by the live route card. |
| `square/components/cy/post-drafts` (T4 sheet) | `App/DesignSystem/CYSquarePostDraftsSheet.swift`; toolbar "Drafts" in `SquareWorkspaceView` | Large left title + round ✕, row-shaped loading skeleton, rows (avatar, name, date, 2-line summary, trash), "N drafts" footer, real empty state. Delete has no confirm: the row leaves at once and an undo bar stays 4 s; the draft is discarded only when that time runs out, on the next delete, or when the sheet closes (owner 2026-10-23). Drafts with a send in flight are locked. Uses the existing `coordinator.local`, `resume`, `discard`. The existing Local drafts section and its identifiers are kept. |

## Item 3: game code + director sheets
- `club/components/club-game-code-sheet`: built as `App/DesignSystem/CYClubGameCodeCard.swift` with loading ("Generating" in the code's footprint), ready (code on white inside an ink card) and error (a line of copy sized to its content plus Retry, never the empty code-sized box), and the topic name. `ClubGroupCodePresentation` now renders the ready code in this card. The identifier `club.gov.groupCode` and the expiry timer are kept.
  - **Save to Photos is built but not shown**: it appears only when the host passes `onSave`. `ClubGroupCodePresentation` is display-only by an existing rule ("No download, export…"), so I did not turn it on. This is an **owner/Cursor decision**: the mini says saving the code for print is the reason the sheet exists.
- Director sheets (`club-director-broadcast/chapter/end-confirm/incident/ready/recap/role/team`): **not player-reachable**. In `topic-detail` they mount only under `directorActive`, which is set by `startDirector()` when `canDirect` is true (owner/admin). They stay operator surfaces; nothing was built for players. Native operator equivalents live in `ClubTerminalSessionView` / `ClubGovernanceViews` (not restyled in this pass).

## Item 1: club pages, mini page → native mapping (states checked)
| mp page | native | result |
|---|---|---|
| `club/enroll` (roster) | `ClubEnrollmentView` | Matches: skeleton, denied, stale banner (`club.enroll.stale`), empty teams/tickets/registrants, refresh. No change. |
| `club/apply` | `ClubGovernanceViews` `.hostStatus` + `ClubGovernanceCommandForm` `.hostApply` + `ClubHostApplicationMaterials` | Matches: merchant-blocked state, done card (status + limit), intro, form with up to 2 certificate images. **Gap (layout, not done):** the mini is a 4-step wizard with a step bar (`step / 4`) and an intro CTA that morphs into the progress bar; native is one reviewed form. It needs step grouping of the command fields; deferred. |
| `club/create` | `ClubOperationsViews` (`ClubCreatePageModel`) + `ClubCreateHostApplicationLink` | States (sign-in, gate not confirmed, limit reached, become host first) are present. No change. |
| `club/edit` | `ClubProfileDraftVisit` / `ClubProfileDraftRecoverySection` / `ClubProfileMediaEditor` | Edit profile + discard-this-round recovery are present. No change. |
| `club/detail` | `ClubDetailView` (+ `ClubDetailTabBar`, `ClubStatsOverviewView`, `ClubAIDesignView`, `ClubCommunityViews`, `ClubInvitationFeedbackView`) | Contribution board, invitation intake, AI planning, stats overview, posts/comments empty states are present. The co-op pool (`合作池`) is a merchant/co-op operator surface and stays hidden. |
| `club/topic-detail` | `ClubTopicDetail+Port`, `ClubTopicMerchantContent`, `ClubTopicSettingsReturn` | Player sections present; director block is operator-only (see item 3). |
| `club/topic-story` | `ClubGovernanceViews` story view + `ClubStoryViews` | **Fixed:** added the mini `story-aigc` label "AI 生成 / AI-generated" (P0-14 explicit AIGC label). It shows when `publishMode` is `ai_simple`; if the read does not carry that field, it stays hidden. Route/Play tabs, no-chapters, no-stops, awaiting-merchants and answer states already match. |
| `club/group-code` | `ClubGovernanceEventView` → `ClubGroupCodePresentation` | Restyled into `CYClubGameCodeCard` (see item 3). Session picker, invalid and no-permission states are in governance. |
| `club/notify` | `ClubOpsJoinNotifyViews` / `ClubOpsNotifySections` / `ClubNotificationAudienceView` | Matches: no-permission (no retry), audience preview incl. empty segment. No change. |
| `club/join-requests` | `ClubOpsJoinNotifyViews` / `ClubOpsJoinRequestSections` | Matches: failed, stale, empty. No change. |
| `club/roles` | `ClubOpsRoleSection`, `ClubRoleAssignmentPicker`, role recovery sections | Present (assign, revoke with danger confirm). No change. |
| `club/governance` | `ClubOpsGovernanceSections` / `ClubGovernanceViews` | Present (ban/unban, report, appeal, transfer warning). No change. |
| `club/workbench` | `ClubManagementView` | Entry and failure state present. No change. |
| `club/checkin-detail` | `ClubCheckinRailView` (`ClubCheckinDetailRows`) | Present. Refund actions on it stay OFF (payments gate). No change. |
| `club/customers`, `customer-detail`, `settlement`, `badges`, `event-ops` | operator surfaces | Hidden / read-only as before; payout/withdrawal OFF. |

## Item 4: square + IM, behaviour by behaviour (gaps for Cursor)
Square (`square/detail`, `square/list`):
- Like: mini toggles at once with a burst. Native sends the like through the reviewed `SocialActionEditorView` sheet. Kept (safety), but this is a behaviour difference. **Cursor:** decide whether to allow a one-tap optimistic like.
- Bookmark: mini shows a filled star when `isBookmarked==1`. **Cursor:** `SquarePost` does not decode `isBookmarked`, so native can't show the filled state.
- Follow from the avatar: **Cursor:** decode `isFollowTheUser` into `SquarePost` and supply `SquareAuthorFollowStateProviding`. Until then the Follow item stays hidden.
- Share: **Cursor:** supply `SquarePostShareLinkProviding` (post deep link + generic feed link). Until then the share button stays hidden. Not added to feed cards (`SquareXcxPostCard`) yet.
- Route map: **Cursor:** supply `SquareRouteMapProviding` (topic `info-to-user` chapters → nodes, verified road geometry). Until then the card stays hidden; the post's MAP_SNAPSHOT still shows in the gallery.
- Activity picker: **Cursor:** supply `SquareCompletedActivityProviding` (`/api/play/my-completed?for_public_reference=true`). Until then the entry stays hidden.
- Comments: load, load more, reply, like, report, delete (with confirm), deleted placeholder, empty and error states: match. Report and block entries on post and comment: match. Pull to refresh: matches.
IM (`subpackageB/pages/im/chat`, `im/list`):
- More menu: report message, report user, block/unblock, hide conversation. These match (`IMChatMoreMenu`, `IMSafetyMenu`).
- Older history: load more with an inline error and retry. Matches (`MessagingHistoryView` earlierPhase).
- Cards: location, route and signup cards match (`IMCardPreviewViews`, `IMStaticLocationComposeView`, `IMRouteShareComposeView`). Image messages match.
- Inbox rows: open chat; delete, mute and mark-read swipe actions; muted badge style; invite strip. These match (`MessagingHomeView` swipe/context actions, `IMCoopInviteStripView`).
- **Gap, Cursor:** the mini shows sending and failed states on each bubble and resends on tap, for text and for card messages (msgType 3). Native has no pending outbox for these bubbles. It only has the reviewed composer, plus receipt recovery in the channel host (`OrdinaryIMSendReceiptRecoveryView`). A Core outbox model (`pending/failed` per client message ID) is needed before the bubbles can show these states.

## Binding stubs added (UI-only, for Cursor)
All are in `App/DesignSystem/CYSocialParityBindings.swift`. Each is an environment value that defaults to nil, and nil hides the feature: `squareShareLink`, `squareRouteMap`, `squareCompletedActivities`, `squareAuthorFollowState`. Models: `CYSquareRoutePreview`, `CYSquareCompletedActivity`.

## Copy
New table `Resources/SocialParity.xcstrings` with 40 keys, each in zh-Hans and EN.

## Rules kept
Accessibility identifiers are kept, and the new ones use the `square.*` / `club.gameCode.*` prefixes. No DEBUG fixtures were touched, and there is no mock data in production paths. Payments, payout and withdrawal were not touched. Safety gates are unchanged: follow, like and report still go through the reviewed editors, and the group-code export stays off. No screenshots were taken or shared.

## APP-ONLY (kept intact)
The message channel, City Monopoly (`CityGamePanel`) and the improved community are untouched.
