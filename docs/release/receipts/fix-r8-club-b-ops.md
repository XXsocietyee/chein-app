# Receipt: fix-r8-club-b-ops (2026-11-25)

Branch `fix/r8-club-b-ops`: the ops forms and pages of the club area. It is merged into `fix/r8-club` together with
`fix/r8-club-a-topic`. Queue: `origin/audit/parity-r8-club:docs/audit/parity-r8/club.md` §3 (sections C and D), rows
owned by Claude App. MP: `hengyin/chengyinhub-xcx`.

Nothing here was compiled; this environment has no compiler. Every type, initializer and modifier used was grepped on
the tree first. `python3 tools/check_scaffold.py` prints `PASS structural checks`. Strings fragment:
`docs/port/strings/fix-r8-club-b.json`. Every key is also in `Resources/Localizable.xcstrings`, in en and zh-Hans.

## Round 5 (2026-11-25)

- Merged `origin/ui/combined-r7` @ f95850a46 (merge 627d8ff02). The only conflict was `Resources/Localizable.xcstrings`,
  resolved per key with a 3-way merge. Keys from both sides were kept. For club keys only this branch changed, this
  branch's copy won. For the 11 keys both sides changed (none of them club keys), the integration copy won.

| id | sev | status | where / MP source |
|---|---|---|---|
| CLB-create-02 (rest) | P1 | closed | MP create wxml:30, js:415: `status == 0` → 已重新提交，等待审核. `ClubOperationsReceipt.pendingReview` is decoded from `data.status` (number or numeric string) in `ClubOperationsService.decodeReceipt`. The post-create status line in `ClubOperationsViews` uses `club.ops.createdStatus.resubmitted`. Core test `testCreateReceiptCarriesPendingReviewStatus` |
| CLB-r7-C-03 | P2 | closed | MP roles/index.js:266-272. The roles re-read after a role action (`finishRoleManagementReturn`) calls `load(keepingOnFailure: true)`. On failure it keeps the list and toasts 列表没刷新成功，下拉重试 (`club.roles.refreshFailedToast`). First loads and pull-to-refresh still show the full error |
| CLB-apply-11 | P2 | closed | MP apply js:415, wxml:177: the submit receipt card shows 主理人 from the submitted draft's `leaderName` (`club.host.receipt.leader`) |
| CLB-r7-D-05 (+detail owner entry) | P2 | closed | workbench was already done. `pages/club/detail?owner=1` now also opens the only owned club on `tab` (MP detail/index.js:798-819 `resolveOwnerEntry`). Several clubs or a failed read show the owned list |

Already closed in earlier rounds of this branch (see the commits on `fix/r8-club-b-ops` and `fix-r8-club.md`): CLB-G17 /
settlement-02 (partial, money write TEST-only), CLB-r7-D-01, CLB-settlement-04, CLB-governance-03, CLB-roles-04,
CLB-r8-apply-01, CLB-r8-create-01, CLB-edit-01/-03/-05, CLB-r8-group-code-01/-02, CLB-r8-badges-01/-02,
CLB-r8-governance-01, CLB-r8-roles-01, CLB-r8-join-requests-01, CLB-join-requests-06, CLB-notify-04, CLB-enroll-02,
CLB-r8-enroll-01.

These were found already done on the integration tip: CLB-group-code-05 (`App/ClubKit/ClubGroupCodeSessionStep.swift`),
CLB-notify-05 (silent campaign re-read), CLB-G16 (memberId preselect), CLB-enroll-08 (link part).

## Still open

| id | why |
|---|---|
| CLB-apply-05 | MP apply/index.js:284-345 uploads cert images through upload-client (`bizType: image_free`) and joins them with `,` (:401). The app's only club uploader (`ClubProfileMediaService`) is scoped to an existing club's profile snapshot, and the apply flow has no club. Needs a Core upload client (below) |
| CLB-governance-01 | Merging records and the 对成员执行 picker into one page is a large layout change of `ClubGovernanceViews`. Not safe without a compiler pass |
| CLB-customer-detail-04 | Inline 保存/取消 would bypass the command-form review step that `test_club_topic_settings_return` pins. Needs an embeddable form |

## For Cursor

- **CLB-apply-05:** an apply-scoped `image_free` upload client on `ClubGovernanceAccess` (signed in, no club needed).
  It should return the uploaded URL per file, so the form can mount `ClubGapApplyCertImagesSection` and send
  `certImages` as a `,`-joined string.
- **CLB-group-code-06:** resolve the club from `activityId` before the group-code issue (unchanged from the audit).
- **CLB-settlement-06:** a personal funds-stage read (unchanged).
