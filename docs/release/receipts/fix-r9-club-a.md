# fix/r9-club-a receipt (round 2)

Audit: `origin/audit/parity-r9-club:docs/audit/parity-r9/club.md`, Claude App rows. Mini-program: `hengyin/chengyinhub-xcx/pages/club/*`.
Rules: MP-first (MP file:line in each commit and code comment), Apple components only (native-r2), money stays TEST-only (nothing here pays, refunds, settles or withdraws). No compiler in the cloud: `python3 tools/check_scaffold.py` printed `PASS structural checks` before every commit.

## Step 1: merge of `origin/ui/combined-r7`

`a25c7e159`. Cursor's `club-p0-nonmoney` (bb689268e) had carried CLB-G02 / G04 / G13a / detail-11 forward from this branch; its versions were taken and CLB-G06 + CLB-detail-35 were replayed onto the native quick-action `Section`. `Localizable.xcstrings` = key union (tip order, ours appended).

## Rows

| Row | Sev | Status | SHA | App file |
|---|---|---|---|---|
| CLB-G13a | P0 | fixed (carried by Cursor bb689268e) | b3a92db8c | App/ClubTopicDirectorOpsSections.swift |
| CLB-G04 | P0 | fixed (carried by Cursor bb689268e) | 6961de363 | App/ClubDetailR8Mounts.swift |
| CLB-G02 | P0 | fixed (carried by Cursor bb689268e) | 67de1cfe3 | App/ClubDetailQuickActions.swift |
| CLB-detail-11 | P0 | fixed, App half (Cursor did link + field) | b345a7690 | App/ClubEditionsShareSection.swift |
| CLB-detail-34 | P1 | fixed | 666d94a69 | App/ClubHomeView.swift |
| CLB-G06 | P1 | fixed | 76c7de342, replayed in a25c7e159 | App/ClubDetailView.swift (toolbar gear, settingsRoute), App/ClubDetailQuickActions.swift |
| CLB-detail-35 | P1 | fixed | 6936b9f64, replayed in a25c7e159 | App/ClubDetailView.swift (groupCodeQuickAction), App/ClubPublicActivityListView.swift |
| CLB-detail-09 | P1 | fixed | 892f6d4d3 | App/ClubManagedProjectsSection.swift, App/ClubDetailR8Mounts.swift (loadProjects, no 12 cap) |
| CLB-r7-A-04 | P1 | fixed (same commit as detail-09) | 892f6d4d3 | App/ClubManagedProjectsSection.swift (openTools / chooseTool / permissions.tools) |
| CLB-G13b | P1 | fixed | 9c917c011 | App/ClubGovernanceViews.swift (directorModel, sendDirector, directorEnd alert, 更多 → 结束活动) |
| CLB-G13c | P1 | fixed | 5a2c5bee1 | App/ClubTopicDirectorMount.swift (ClubTopicDirectorReadySection) |
| CLB-topic-detail-10 | P1 | partly | 7c4b8510b | App/ClubGovernanceViews.swift (topicCustomers 定向广播). Needs Core: `PlayDirectorProjection` does not expose `broadcastBlocker`, so the NO_RECIPIENT sentence cannot be shown; the generic 「只有本场进行中才能发送（当前 X）。」 is. |
| CLB-G15 | P1 | fixed | 01c216f2d | App/ClubOpsEventFormFields.swift (paymentNotice), App/ClubGovernanceCommandForm.swift (windowWarning on the receipt), App/ClubOpsEventView.swift (`.series where publishEmpty`) |
| CLB-group-code-06 | P1 | fixed | a2f6f5f38 | App/ClubGovernanceCommandForm.swift (issueGroupCode receipt by activityId) |
| CLB-group-code-05 | P1 | partly | ee0e1472a | App/ClubKit/ClubGroupCodeSessionStep.swift (ClubGroupCodeMissingLinkView, onOpenManage). Needs Core: `MiniProgramPageLink.swift:300` still drops a deep link with neither id. |
| CLB-notify-05 | P1 | fixed | e93c5b952 | App/ClubGovernanceCommandForm.swift (refreshCampaign, inline 刷新) |
| CLB-apply-05 | P1 | fixed | 35cb3f59b | App/ClubHostCertImagesSection.swift (PhotosPicker + api/common/uploadOSS, certImages comma-joined) |
| CLB-detail-30 | P1 | partly (App half) | 95c873bc9 | App/ClubKit/ClubWorkbenchKit.swift (ClubInviteShareLink), App/ClubMembersView.swift. Needs Cursor Core: https universal link for pages/club/detail (the share is still `chein://`). |
| CLB-detail-14 | P1 | partly | 0bcd0607d | App/ClubDetailView.swift: chat / IM / channel rows moved off 帖文 to 概览. Open: the feed is still pushed (`ClubCommunityEntry`); an inline List feed needs a rewrite of `ClubCommunityFeedView`'s ScrollView. |
| CLB-topic-detail-06 | P1 | blocked (Cursor Core) | — | Inline toggles that save on change need the governance journal to release the `saveTopicSettings` lock after an acknowledged save (`ClubGovernanceCoordinator.confirm` keeps it: "no generic receipt proves reconciliation"); a second toggle would be refused as outcomeLocked. |
| CLB-customer-detail-04 | P1 | blocked (Cursor Core) | — | Same lock for `saveCustomer`; the inline 保存/取消 editor would only save once. |
| CLB-topic-story-04 | P1 | blocked (Cursor Core) | — | `ClubStoryStop` has no lat/lng yet; `ClubGapStoryMapAddressRow` is mounted and waits for them. |
| CLB-r9-topic-detail-01 | P2 | fixed | b92b696e6 | App/ClubTopicMerchantContent.swift |
| CLB-topic-story-06 | P2 | fixed | b4d7d7052 | App/ClubGovernanceViews.swift, App/ClubStoryViews.swift (ContentUnavailableView) |
| CLB-r9-topic-story-01 | P2 | fixed | 333115610 | App/MPReviewedPageScreen.swift (topic-story without topicId) |
| CLB-event-ops-05 | P2 | fixed | 96e188c2e | App/ClubOpsEventView.swift |
| CLB-r7-A-07 | P2 | fixed | cef838d90 | App/ClubMembersView.swift (loadGovernGrant) |

## Native notes (no Apple equivalent → closest Apple control)

- MP 本场工具 / 选择场次 choice sheets → `confirmationDialog` / `.sheet` with `presentationDetents([.medium, .large])`.
- MP toasts on the project list and notify refresh → section footer / inline secondary text (native-r2 "inline results instead of pop-ups").
- MP `cy-club-director-end-confirm` (centred, no ✕) → `.alert` with 再想想 (cancel) / 结束活动 (destructive).
- MP `cy-upload` grid → `PhotosPicker` + List rows with swipe-to-delete.

## For Cursor Core

1. Release (or reconcile by re-read) the journal lock after an acknowledged `saveTopicSettings` / `saveCustomer`, so inline saves can repeat (topic-detail-06, customer-detail-04).
2. Expose `broadcastBlocker` on `PlayDirectorProjection` (topic-detail-10).
3. lat/lng on `ClubStoryStop` (topic-story-04).
4. https universal link for `pages/club/detail` (detail-30).
5. Let `pages/club/group-code/index` with neither id reach the route (group-code-05).
