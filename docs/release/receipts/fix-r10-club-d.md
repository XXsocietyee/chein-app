# Receipt: fix-r10 lane club-d (2026-11-26)

Branch `fix/r10-club-d`, based on `origin/ui/combined-r7` (d9832ac50, merged again before push).
Slice: `docs/audit/parity-r10/club.md` §3 P1 rows, second half in queue order (12 rows: CLB-G15 … CLB-r10-nat-group-code-01).
No compiler in the cloud: every type/member used was grepped; no new files, no new string keys.

Several rows were already landed on `ui/combined-r7` by fix-r9 lanes before the r10 audit snapshot reached them
(the audit cites pre-r9 line numbers for those). They are marked **fixed (pre-existing)** with the landing SHA.

| row | status | SHA | app file:line | note |
|---|---|---|---|---|
| CLB-G15 | fixed | d9000e3a1 | App/ClubOpsEventView.swift:73, 120 | The extras hook's 发布主题 was a `{}` closure; it now pushes `pages/publish/fabu/index?clubId` (MP event-ops js:499-503). `paymentNotice` (App/ClubOpsEventFormFields.swift:25) and `windowWarning` (App/ClubGovernanceCommandForm.swift:454) and the empty 发布主题 state (`.series where publishEmpty`) were already fed. |
| CLB-apply-05 | fixed (pre-existing) | 35cb3f59b | App/ClubGovernanceCommandForm.swift:181; App/ClubHostCertImagesSection.swift:8 | `PhotosPicker` + uploadOSS on step 4, sent as `certImages`. Audit's "0 refs" was the parked MPGap section; the mounted one is ClubHostCertImagesSection. |
| CLB-notify-05 | fixed | 14407904f | App/ClubGovernanceCommandForm.swift:445 | Inline 刷新 button (no pushed page) was already there; adds the `ProgressView` with 刷新中… while the re-read runs (MP notify wxml:76-78). |
| CLB-customer-detail-04 | partly | a4e34092d | App/ClubOpsCustomerViews.swift:478-488 | Tags are plain rows with swipe-to-delete (`.onDelete`); add is `TextField` + `.onSubmit`; remark is `TextField(axis: .vertical)`. The editor still opens in the shared saveCustomer command-form sheet (GV `.cySheet(item: $editor)`) because the write goes through the review/confirm pipeline in ClubGovernanceCommandForm; inlining that form into the read page is a larger refactor. Dispatch in Release needs gate-05 (club-b). |
| CLB-group-code-06 | fixed (pre-existing) | a2f6f5f38 | App/ClubGovernanceCommandForm.swift:897-904; Core/ClubGovernanceGroupCode.swift:12 | Issued code validated by activityId; clubId only when known. Release dispatch still depends on gate-05 / CLB-r10-group-code-01 (club-b). |
| CLB-group-code-05 | fixed (pre-existing) | ee0e1472a | App/MPReviewedPageScreen.swift:358-361; App/ClubKit/ClubGroupCodeSessionStep.swift:109-131, 35 | Neither id → `ContentUnavailableView` 缺少路线或场次信息 + 进入俱乐部管理; picker `onOpenManage` wired. |
| CLB-r10-nat-topic-story-01 | fixed (pre-existing) | 892f6d4d3 | App/ClubStoryViews.swift:241-275 | Gameplay card is a plain row (thumbnail + title + meta) with system colours; no forced dark / gradient / `.white` remain. |
| CLB-r10-nat-badges-01 | fixed (pre-existing) | 5a223a87b | App/ClubBadgeManagementView.swift:17-31 | `List` + Sections, `ProgressView` loading, `ContentUnavailableView` + 重新加载 on error. |
| CLB-r10-nat-badges-02 | fixed (pre-existing) | 5a223a87b | App/ClubBadgeManagementView.swift (createForm) | `NavigationStack { Form { TextField(axis:) } }`, toolbar 取消 / 创建, validation in the Section footer. |
| CLB-r10-nat-badges-03 | fixed | 4c9008597 | App/ClubBadgeManagementView.swift:39, 64-76, 175-185 | 创建 moved to the toolbar primary action; 颁发 is also a trailing swipe action. The empty state keeps `ClubMPEmptyState` (round-4 MP empty art parity), not `ContentUnavailableView`. |
| CLB-r10-nat-badges-04 | fixed | fe15a7863 | App/ClubBadgeManagementView.swift:252-285 | Member picker was already `NavigationStack { List }`; the custom confirm sheet is now `.confirmationDialog` with the consequences as its message. |
| CLB-r10-nat-group-code-01 | fixed | dcdced85a | App/ClubGovernanceCommandForm.swift:419-426; App/ClubGroupCodePresentation.swift:25-38 | QR image in a plain Section row on a white quiet zone (scanner-safe in Dark Mode), session name as the Section header; the hex CYNight ink card + stroke is no longer used here. |

## Gates (before push)

- `python3 tools/check_scaffold.py`: PASS structural checks.
- `python3 -B tools/check_a11y_lint.py`: PASS (0 new).
- `python3 -B tools/contract_ratchet.py --check`: see push note below.
- `Tests/ContractChecks/test_club_group_code_page_ready.py`: OK.

Not run: Xcode build / simulator (no compiler in the cloud). Coordinator: please build-check the badges `.confirmationDialog(presenting:)` and the `ToolbarItem` with an `if` body.
