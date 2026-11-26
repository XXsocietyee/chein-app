# fix/r10-club-a receipt

Brief: `origin/design/handoff-r2:docs/briefs/fix-r10.md`, lane **club-a** ("club.md: every P0 row, first half in table order").
Source: `origin/design/handoff-r2:docs/audit/parity-r10/club.md` §3a. Base: `origin/ui/combined-r7` (d9832ac50).
MP source of truth: `hengyin/chengyinhub-xcx/pages/club/topic-detail/{index.wxml,director.js}` and
`pages/club/utils/generic-director-ops.js` (read through code search; the MP repo is not attached to this session).

## Slice

club.md §3a has three open P0 rows: CLB-r10-gate-05, CLB-r10-badges-01 and CLB-G13a. The Lanes table gives club-b
"the second half, then the gate-05 / badges-01 / group-code / notify release-dead rows". Those four rows are named
for club-b, so this lane took the one remaining P0 row, **CLB-G13a**, and left gate-05 and badges-01 to club-b so the
two lanes don't edit `ClubGovernanceProduction.swift` / `AppCompositionRoot.swift` at the same time.

## Rows

| Row | Sev | Status | SHA | App file:line |
|---|---|---|---|---|
| CLB-G13a | P0 | **fixed** (round 2: QUEST_GUIDE answer form + 开始离线记录) | 50ebf1367, 91251b38d | App/ClubTopicDirectorOpsSections.swift:7 (section), :52 (rows `.disabled(writeLocked)`), :73 (`open` → sheet); App/ClubTopicDirectorMount.swift:57 (`writeLocked` from the director phase, `onSubmitted` reloads); App/ClubTopicGenericOpsSheet.swift:14 (sheet), :56 (Form), :81 (footer 时间为北京时间 + ledger rows), :225 (submit); App/AppSession+PopupsClose.swift `submitSharedRunAction`; App/MPFirstClubApprovals.swift `sharedRunCommandPath`; Core/PlaySharedRunOps.swift:10 (port), :169 (body admission), :259 (submit) |
| CLB-r10-gate-05 | P0 | not taken: club-b (named in its slice) | — | — |
| CLB-r10-badges-01 | P0 | not taken: club-b (named in its slice) | — | — |

## CLB-G13a: what changed

- **Per-action sheet.** Each 通用玩法 row opens `.sheet { NavigationStack { Form } }` with the MP fields for that
  action (`genericOpsFields`: schemas, target fields, signedAction / reviewKind pickers, Beijing-time `DatePicker`s for
  `occurredAt`), the footer 时间为北京时间, and the toolbar 取消 / 确认并提交. The MANUAL_BEGIN / STAFF_MANUAL_SIGN /
  MANUAL_IMPORT / MANUAL_REVIEW forms read `shared/export` first, as MP `openGenericOps` does. They check that the
  revision and epoch match, fill the hashes or the next sequence, and list the ledger rows (签名 … · 序号 … · 已使用/待处理,
  会员 … · 操作 … · outcome).
- **Validation and confirm.** `PlaySharedRunOps.payload` ports `genericOpsPayload`, including its MP error messages.
  The confirm alert uses the MP `showDirectorModal` copy: 确认<title>, then 此操作不可撤销 or 将按本局规则核验并应用本次操作。,
  then 原因：… or 请确认现场凭证与输入准确。. Before submitting, the sheet reads control again. If the revision, the epoch or
  the offer has changed, it shows 场次状态已变化，请重新确认.
- **Submit.** `PlayExperienceService.submitSharedRunAction` sends `POST api/game/session/command`
  `{activityId, nodeId: null, expectedRevision, requestId, action, payload}`. This is the envelope `executeAction` uses,
  and the one `PLAN_FALLBACK` already uses. On APPLIED or PENDING the sheet closes, control is read again and the director reloads.
- **writeLocked.** The rows, the form and 确认并提交 are disabled while the director is loading, submitting or holding an
  unknown write (MP `writeLocked`).
- **Firewall.** `MPFirstClubWriteRoute.accepts` admits `api/game/session/command` only when the body is the exact
  shared-run envelope and the action is one of the 通用玩法 actions, ARRIVAL_ATTEST (signed) or PLAN_FALLBACK.
  Team-item bodies still go to the player lease. Without this, the Release China composition refused the write, and
  `PLAN_FALLBACK` was refused too. This half is Cursor Core's to review.
- **Tests.** `Tests/CoreTests/PlaySharedRunOpsTests.swift` covers the MP `tests/unit/generic-director-ops.test.js` vectors
  (offered filter, STAFF_MANUAL_SIGN nesting, target exclusivity, nonce, MANUAL_BEGIN list, MANUAL_REVIEW kinds) and the
  body admission.

## Round 2 (2026-11-26)

Merged `origin/ui/combined-r7` twice (33a8c47b8, a24822471). Conflicts resolved with both sides kept:
`MPFirstClubWriteRoute` keeps club-b's multipart/JSON content-type gate, badge paths and the exact
`api/club/members` `{"clubId": positive}` shape, and admits the CLB-G13a shared-run command under the JSON branch;
`ClubTopicGenericOpsSection` locks on `model.phase != "ready"` (club-b) and keeps `onSubmitted`; xcstrings by key union.

### CLB-G13a: finished (91251b38d)

- **QUEST_GUIDE answer form.** `PlaySharedRunOps.guideTask` / `guideFields` / `guideAnswers` port MP
  generic-director-ops.js (read through code search): basic (TYPE text; PICK → one toggle per option, joined ids),
  qa (TYPE → `{input}`, PICK → `{optionId}`, multi → `{optionIds}`), sort (`第 n 项` pickers → `{order}`, distinct),
  match (left item → right picker → `{pairs}`, distinct), classify (item → bin → `{placement}`), max 512, the four MP
  error sentences. With `control.guideTasks`, questKey is a picker over the task keys. QUEST_GUIDE is now a form action
  and a STAFF_MANUAL_SIGN signedAction (MP `choices.signedAction`). Payload `{reason, teamId, questKey, answers}`.
  Tests: the MP `guideCases` vectors, plain and nested in STAFF_MANUAL_SIGN, plus field/err cases
  (Tests/CoreTests/PlaySharedRunOpsTests.swift).
- **开始离线记录.** The OFFLINE_ANCHOR row asks the MP confirm (开始离线记录 / 先记下当前进度… / 开始记录 / 暂不开始), then
  `shared/export/anchor` in place (App/ClubTopicDirectorOpsSections.swift `startOfflineRecord`). A `GAME_*` refusal →
  离线记录未开始 + server sentence; any other reply is settled only by a control read carrying an anchor for the same
  epoch (MP `_reconcileOfflineAnchor`), else 离线记录结果待确认; tapping again re-checks instead of re-sending.

### Wider slice: P1 then P2

club-c / club-d receipts (origin, checked 16:11 / 15:59 UTC) mark every P1 parity and P1 native row fixed except
CLB-topic-detail-06 (blocked, Cursor Core journal lock), CLB-topic-detail-10 (partly) and CLB-customer-detail-04
(partly, refactor). This lane took the one that was blocked only on a wire key.

| Row | Sev | Status | SHA | App file:line / note |
|---|---|---|---|---|
| CLB-topic-detail-10 | P1 | **fixed** (completes club-c's partly) | 587a52700 | App/ClubGovernanceViews.swift 定向广播 Section: `canBroadcast` = BROADCAST offered && no `club.broadcastBlocker` (MP director.js, club-game-director-adapter.js); NO_RECIPIENT → 本场还没有可送达的玩家。等玩家报名进场后，这里才能发送。; other → 只有本场进行中才能发送（当前 …）。 |
| CLB-topic-detail-06 | P1 | not taken | — | Still needs the Cursor Core journal-lock change (club-c note). |
| CLB-customer-detail-04 | P1 | not taken | — | club-d partly; inlining the command form is a larger refactor. |
| CLB-r10-create-01 | P2 | fixed | 4ad6e2b73 | App/ClubOperationsViews.swift:544-545 comment matches the 去改名称 branch. |
| CLB-r10-nat-topic-detail-07 | P2 | fixed | ecb8ab943 | App/ClubTopicDirectorOpsSections.swift: generic-ops rows are system `Button` rows (no drawn chevron; they open sheets); plan-fallback footer shows the 1–500 rule, no n/500 counter. |
| CLB-r10-roles-01 | P2 | verified, no change | — | App/ClubGovernanceViews.swift:945-961 `finishRoleManagementReturn` keeps the list and sets `club.roles.rereadFailed` (列表没刷新成功，下拉重试) shown via `.clubIslandStatus` :382. |
| CLB-r10-apply-01 | P2 | merchant release | — | 切换到商家端 is inside `PlayerLaunch.merchantCenterEnabled` (GV:1502), off in Release. |
| CLB-r10-apply-02 | P2 | merchant release | — | Same branch (查看商家入驻). |
| CLB-r9-create-04 | P2 | blocked (owner) | — | MP is a TextField, but HANDOFF-R1 MC-10 (comment at App/ClubOperationsViews.swift:1267) made 城市 a picker row; needs an owner call. |
| CLB-r9-create-02 | P2 | open | — | Auto-push to apply from inside the create List needs programmatic navigation that can't be checked without a compiler (loop on back). |
| CLB-r9-event-ops-01 | P2 | open | — | Inline topic `Picker(.menu)` needs the topics read moved into the hub; not a one-file edit. |
| Other club.md P2 parity rows | P2 | already carry fix comments on the tip | — | topic-story-06, r9-topic-detail-01, r9-create-01, r8-badges-02, r9-native-02, r9-detail-03 and the rest were fixed in r8/r9 (see the `CLB-…` comments in the app); not re-done. |

## Gates (before push)

Round 2 (tip a24822471 + receipt): check_scaffold PASS; a11y lint PASS (0 new); contract_ratchet 192 failing, baseline 192, **new 0**.

Round 1:

- `python3 tools/generate_project.py`: run (new files App/ClubTopicGenericOpsSheet.swift, Core/PlaySharedRunOps.swift, Tests/CoreTests/PlaySharedRunOpsTests.swift).
- `python3 tools/check_scaffold.py`: PASS structural checks.
- `python3 -B tools/check_a11y_lint.py`: PASS (0 new).
- `python3 -B tools/contract_ratchet.py --check`: 193 failing against a baseline of 192 (new 1). The new one is
  `test_social_article_content…test_renderer_is_wired_only_to_existing_scoped_article_contents`, which expects
  `.onDisappear { loads.cancel(); … }` in `App/SocialAccountComponents.swift`. It **fails the same way on the base**
  `origin/ui/combined-r7` d9832ac50 (checked in a clean worktree). This lane does not touch that file, so the failure is
  pre-existing drift for the coordinator. This lane adds no new ratchet failures.
- Strings: 55 keys in `docs/port/strings/fix-r10-club-a.json`, merged into `Resources/Localizable.xcstrings` (zh-Hans + en).
