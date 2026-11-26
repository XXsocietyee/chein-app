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
| CLB-G13a | P0 | **partly** (13 of the 14 offered actions; QUEST_GUIDE answer form not ported) | 50ebf1367 | App/ClubTopicDirectorOpsSections.swift:7 (section), :52 (rows `.disabled(writeLocked)`), :73 (`open` → sheet); App/ClubTopicDirectorMount.swift:57 (`writeLocked` from the director phase, `onSubmitted` reloads); App/ClubTopicGenericOpsSheet.swift:14 (sheet), :56 (Form), :81 (footer 时间为北京时间 + ledger rows), :225 (submit); App/AppSession+PopupsClose.swift `submitSharedRunAction`; App/MPFirstClubApprovals.swift `sharedRunCommandPath`; Core/PlaySharedRunOps.swift:10 (port), :169 (body admission), :259 (submit) |
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

## Still open (why "partly")

- **QUEST_GUIDE (工作人员指导完成) and a signed QUEST_GUIDE.** The MP answer form (`guideFields` / `guideAnswers` over
  `control.guideTasks`: TYPE / PICK / multi / sort / match) is not ported. That row still pushes the director page, and
  QUEST_GUIDE is left out of the STAFF_MANUAL_SIGN signedAction picker.
- **OFFLINE_ANCHOR** still opens the director page. Its confirm already exists in `SharedRunControlSection`.
- **Not verified on a device.** No compiler in the cloud. Every type and member was grepped before use; the coordinator
  build is the first compile.

## Gates (before push)

- `python3 tools/generate_project.py`: run (new files App/ClubTopicGenericOpsSheet.swift, Core/PlaySharedRunOps.swift, Tests/CoreTests/PlaySharedRunOpsTests.swift).
- `python3 tools/check_scaffold.py`: PASS structural checks.
- `python3 -B tools/check_a11y_lint.py`: PASS (0 new).
- `python3 -B tools/contract_ratchet.py --check`: 193 failing against a baseline of 192 (new 1). The new one is
  `test_social_article_content…test_renderer_is_wired_only_to_existing_scoped_article_contents`, which expects
  `.onDisappear { loads.cancel(); … }` in `App/SocialAccountComponents.swift`. It **fails the same way on the base**
  `origin/ui/combined-r7` d9832ac50 (checked in a clean worktree). This lane does not touch that file, so the failure is
  pre-existing drift for the coordinator. This lane adds no new ratchet failures.
- Strings: 55 keys in `docs/port/strings/fix-r10-club-a.json`, merged into `Resources/Localizable.xcstrings` (zh-Hans + en).
