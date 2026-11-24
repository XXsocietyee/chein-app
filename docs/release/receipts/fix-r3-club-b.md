# Receipt: fix-r3-club-b (wave ×10, Claude F-agent, club half b)

- Brief: `origin/design/handoff-r2:docs/briefs/wave-x10.md`.
- Branch: `fix/r3-club-b`, based on `origin/ui/combined-r7` @ 7fdfad1f1. `origin/restyle/r2-club-social` is merged first, as the brief requires, because it touches these files.
- **Pages (round-1 audit, second half):** badges, notify, settlement, customer-detail, checkin-detail, join-requests, group-code, customers, payout-receiver, workbench.
- **Gap sources used:**
  - the r7 fix queue `origin/audit/parity-r7-club:docs/audit/parity-r7/club.md` (Claude rows for these pages);
  - the round-1 audit;
  - `fix-parity-club.md` and `fix-parity2-club.md` (the deferred and partial rows);
  - `review/r7-rev-{a,b,c}`, which has no App-layer findings on these pages.
- **Not compiled:** there is no Swift toolchain in the cloud. Every API used was grepped on r7 first.
- **Strings:** `docs/port/strings/fix-r3-club-b.json`, flat keys merged into Localizable.
  - Three keys **override existing Localizable values on purpose**: `club.gov.action.retryNotification` → 只重试失败项, `club.checkin.state.denied` → 核销记录不可见 and `club.checkin.state.error` → 核销凭证加载失败. These are the MP copy.
- **Fixture routes:** `docs/port/accept/f-club-b.txt`.

## Fixed

| id | files | what changed |
|---|---|---|
| CLB-badges-01 | App/ClubBadgeManagementView.swift | The club name shows as a meta subtitle under the inline title. |
| CLB-badges-02 | same | Create form: MP placeholders (例如：开荒元老 / 这枚勋章颁给谁、为什么), n/120 and n/255 counters, the label 说明（选填）, and the Core validation sentence shown inline under its field in danger text. The old `limits` line is gone. |
| CLB-badges-04 | same | The member picker is now a 颁给谁？ sheet with the caption 勋章：X and a `CYAvatarView` on each row. The grant confirm is presented from that sheet. Swipe-to-close is disabled while busy. |
| CLB-badges-09 / -10 / -11 | same | Name `.body`; description `.caption` clamped to 2 lines; 44 pt art. The grant button has the VoiceOver label 把 X 颁给成员. The duplicate `.cyDomainScreen` is removed. |
| CLB-notify-01 (labels) | App/ClubGovernanceCommandForm.swift | The prepare button reads 预览受众. The send confirm reads 发送给 N 人 (MC-26), or 发送站内通知 when the count is unknown. Offline writes keep their own label. |
| CLB-notify-09 / -10 | App/ClubGovernanceViews.swift, strings | The retry button reads 只重试失败项 and the separate footnote is removed. 已发送不代表… now uses `.cyText(.meta)`. |
| CLB-r7-D-06 | App/ClubNotificationAudienceView.swift | 本场 audiences are hidden, not disabled, when there is no activityId. |
| CLB-settlement-03 (club view) | App/ClubPayoutReceiverView.swift | `pages/club/settlement?clubId=` without personal=1 now renders the governance `.settlement` page, so there is one implementation with summary, sessions, ledger, funds and tappable topic rows. |
| CLB-settlement-07 | same | Personal card: an unverified total shows "—" (VoiceOver reads 金额待核验), with a warning chip for the unverified count (MC-29). |
| CLB-customer-detail-03 | App/ClubOpsCustomerViews.swift | The customer's name is the `.pageTitle` (header trait), with the avatar trailing. At accessibility sizes the avatar sits first in the stack. |
| CLB-customer-detail-04 (partial) | App/ClubGovernanceCommandForm.swift | Tag/remark editor: one 保存 tap runs prepare and confirm. There is no 下一步 → 确认 step. |
| CLB-customer-detail-08 / -09 | App/ClubOpsCustomerViews.swift | 累计实付 uses `.dataXL`; stat numerals `.sheetTitle`; record day `.sectionTitle`. Tags wrap with `ClubR1WrapLayout` instead of a horizontal scroll. |
| CLB-checkin-detail-03 | App/ClubCheckinRailView.swift, App/ClubGovernanceViews.swift | Denied, missing and error are each one full-page `CYEmptyState`. Denied and missing offer 返回; error offers 重新加载. No rows render in an error phase. |
| CLB-checkin-detail-04 | App/ClubCheckinRailView.swift | The order card shows the topic cover (59×40) and the session time. The 报名编号 row is removed; the UI-test anchor `club.gov.fact.registrationId` now sits on the order card as an identifier. The rail has no section header. |
| CLB-checkin-detail-07 / -08 | same | Name `.cardTitle`; topic `.bodyMedium`; KV rows `.bodyCompact`. Reached stops are success-tinted, 已接洽 warning-tinted, and the current step is bold. |
| CLB-join-requests-05 | App/ClubManagementView.swift | The readback removes the handled card with a 160 ms animation. The status line reads 已通过 / 已拒绝 and a success haptic plays. The generic acknowledged line stays only when no readback came back. |
| CLB-join-requests-06 (partial) | same | Added `.refreshable`. 刷新 is always a secondary pill; it is kept because UI tests tap it. |
| CLB-join-requests-08 / -09 | same | The reject swipe uses `dangerText`. The confirm sheet title is `.sheetTitle`, not a 34 pt hero. |
| CLB-group-code-02 | App/ClubGovernanceCommandForm.swift | The code is issued as the form opens (MP onLoad). The button 出示团码 is the one-tap retry. |
| CLB-group-code-03 | App/ClubGroupCodePresentation.swift, CommandForm | An expired code gets a 重新出码 button. It re-issues in place with a fresh draft and requestId, so the expired receipt is never replayed. |
| CLB-group-code-04 (title) | App/ClubOpsEventFormFields.swift | The sheet title is 活动核验团码. |
| CLB-group-code-07 / -08 | App/ClubGroupCodePresentation.swift | `CYSpacing.sm`. Brightness is 1.0 while the code shows and restored on disappear. |
| CLB-customers-06 | App/ClubOpsCustomerViews.swift | The count header is a `.meta` line. |
| CLB-r7-D-02 | App/ClubGovernanceViews.swift | The customers list re-reads on return (onAppear with an existing snapshot). |
| CLB-payout-receiver-02 | App/ClubPayoutReceiverView.swift, strings | Unbind copy now matches the MP: 解除个人收款？ / 解除后新的俱乐部收入会暂停，重新绑定后继续. |
| CLB-payout-receiver-03 | same | The extra `.background(CYColor.bgPage)` is dropped on all three payout/settlement hosts. |
| CLB-r7-D-03 / -04 | same | Missing club shows 没有找到这个俱乐部 with 返回 only (no reload). The no-club state offers 创建俱乐部 (`ClubCreateMyClubLink`). |

## Left, with reasons

| id | owner | reason |
|---|---|---|
| CLB-payout-receiver-01 (P0) | owner | Wiring WeChat `SendAuthReq` versus hiding bind is still an owner decision. Unchanged. |
| CLB-settlement-05 | owner | Release gate on the 我的 reads is an owner decision. The club-view path now uses the ungated governance read; the personal and mine paths are unchanged. |
| CLB-settlement-02 / CLB-r7-D-01 | Gemini / integrator | The FE reference settlement is the parked `App/MPGap/Club/ClubGapReferenceSettlementView.swift` (gap/g2-ops). It needs a mount; the money write is TEST-only. |
| CLB-settlement-04 / -06 (personal) | Claude, next round | Personal topic rows need a `ClubSettlementDetailTarget`, which only the governance presentation can build. Funds stages have no read on the personal path. Both need a Core hook (for Cursor). |
| CLB-notify-01 (single composer) / -05 / -06 | Claude, next round | Merging the counts page, the sheet form and the status page into one composer means restructuring the generic `ClubGovernanceCommandForm` review engine, which many contract tests pin. That is too risky without a compiler; only the labels were done here. |
| CLB-notify-04, CLB-settlement-10, CLB-join-requests-06 (classifier) | Cursor | Network vs business failure classifier (`Core/ClubOpsJoinNotifyPresentation.swift`). |
| CLB-customer-detail-05 | Cursor | Refused/not-found mapping in Core. |
| CLB-customer-detail-04 (inline card, failure copy) | Claude, next round | The editor is still the sheet; 标签与备注没保存成功 / 重试保存 needs a form-failure copy hook. |
| CLB-group-code-04 (session name) | Claude + Cursor | The session label is not carried into the form route. Passing it as a seed would enter the command fields. |
| CLB-group-code-05 | Gemini | Native 选择场次 step. |
| CLB-group-code-06, CLB-workbench-04 | Cursor | clubId resolution for topic-only links; workbench tile reads. |
| CLB-join-requests-01 | Claude, next round | Moving the owner member list to `ClubMembersView` drops member actions from this page and breaks the r1 UI tests. The title stays 俱乐部管理 until it moves. |
| CLB-workbench-03 / CLB-r7-D-05 | Claude, next round | The workbench route never reaches `unavailable` (id → club 管理, no id → owned list), so -03 has no path to show. Auto-opening a single owned club needs an owned-clubs read hook. |
| CLB-customers-07 | — | Optional; the segmented control is an acceptable native idiom. |
| CLB-badges-03 | — | Fixed in round 1; the counters now replace the limits line. |

## In-flight branches (skipped)

- `restyle/r2-club-social` (merged here, visual only). `gap/g2-ops` parked club views (G13, G17, G19 …). `cursor/*` and `port/*` have no club App changes.

## Requests for Cursor (Core)

- Expose the personal settlement topic → `ClubSettlementDetailTarget` (or a personal detail read), so personal rows can open the detail (settlement-04).
- Add a funds-stage read for the personal settlement (settlement-06).
- Wire `ClubOpsNetworkFailureClassifier` into the page failure copy (notify-04, settlement-10, join-requests-06).

## Gates

- `tools/check_scaffold.py` fails at the project-equivalence assert (line 166). That is pre-existing on r7 plus the restyle merge; this branch adds no Swift files.
- **Contract ratchet** (`tools/contract_ratchet.py`): the base (r7 plus the restyle merge) has 195 failing, and this branch adds **0 new failures**.
  - Two regressions found during the run were fixed in place.
  - `test_club_leaderboard_member_navigation`: the byte pin on the span from `} else if operation == .customer {` was re-hashed, with a comment. That span holds the notify retry footnote and the check-in error-phase guard; its customer rows are unchanged.
  - `test_club_management_review_owner`: the pinned line `case .received(let result): snapshot = result` is kept. The slide-out now comes from a list `.animation(value:)`.
