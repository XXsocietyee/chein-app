# mp-mine-b r3 receipt (B lane: `mp/r3-mine-b`, bottom-up over `mp-mine-r3.md`)

Rules: round3-1127 brief, "B lanes" section. One row per A-receipt row finished here, quoting that row. The A receipt is never edited from this branch.

## Run 1 (11-28, hourly)

Branched from `origin/mp/r3-mine` (1a0c9447f). Bottom-up scan of the A receipt's open rows:

- `CharacterCardReadbackView` byte pin (continue 18–38): still pinned (`docs/issue5-hunks/C02-ios-pbx.rnhunk.md:130`, `test_c02_world_party_character.py`). Skipped: needs the pin owner.
- P2-5c (participants +1 regex, US legal copy): backend / legal owner. Skipped.
- P2-5b (Apple full name): closed upstream by `1b9caf4ee` (A continue 35). Nothing to do.

| A-receipt row | MP | Native file | Level | Fixed now |
|---|---|---|---|---|
| `components/cy/ai-chat-records` … "Not done: MP clear toast names the count (已清除 N 条对话 / 没有需要清除的对话); `clearNPCChatLogs` returns no count" | `subpackageMember/components/cy/ai-chat-records/index.js:64-68` `dc.done(deleted > 0 ? '已清除 ' + deleted + ' 条对话' : '没有需要清除的对话')` | `App/NPCChatDataReadSettingsEntry.swift` (clear sheet `.deleted(let count)`, new `clearedMessage(count:locale:)`) | C | **Fixed.** `clearNPCChatLogs` already returns the server-confirmed `deleted` count (`NPCChatLogDeletionOutcome.deleted(count:)`). The toast now reads 已清除 N 条对话 / "Cleared N chat records" (1 → "Cleared 1 chat record"), and a confirmed zero reads 没有需要清除的对话 / "No chat records to clear" with the info tone. Unknown / unavailable toasts unchanged. Test: `Tests/ContractChecks/test_mine_b_ai_chat_clear_count.py`. |
| `components/cy/scene-share-invite` + profile 关于 `探索与更多` … "Not done: the MP share card copy (一起探索城市里的新玩法, 分享链接) on the code page" | `subpackageMember/components/cy/scene-share-invite/index.wxml:23-28`: under the code, 邀请好友一起探索城市 · 分享城瘾给你的好友，一起发现城市里的新玩法。 then the 分享链接 button | `App/PlayerGapViews.swift` `PlayerCodeAndJoinSection.inviteCopy`; `Resources/Localizable.xcstrings` | B | **Fixed.** The 邀请好友 page now has the MP copy block under the code (`.headline` title, `.subheadline` secondary description, both languages) and a full-width `.bordered` `ShareLink` 分享链接 / "Share link" (id `gap.playerCode.share`) that shares the personal code once it has loaded (hidden while loading / failed, so no dead control). New keys `playerGap.invite.title`, `.description`, `.share`. Test: `Tests/ContractChecks/test_mine_b_share_invite_copy.py`. |

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 52 failing / baseline 52 / **new 0**.

Reviewed bottom-up and left open (not started here, so the A lane can still take them):
- `scene-member-order-detail` "Not done: MP note 场次已开始，只能建仅邀请队伍": `ProfileOrder.startDate` exists, so `teamStarted = teamOpen && start <= now` is computable, but honouring it needs `TeamCreateView` to force invitation-only (MP passes joinMode 1 when started, `index.js:591`). `TeamCreateView` is a `pages/team/*` file (mp-activity). Showing the note without enforcing it would be untrue, so it is listed under For other lanes.
- `pass-unlock` (gated purchase reveal), the en four-tab menu fallback (owner call), `ParticipationDetailView` in-place cancel and the invoice / coupon-qr shared-pending rows (Core coordinator): unchanged reasons from the A receipt.

For other lanes:
- mp-activity: `App/TeamCreateView.swift` — add an `invitationOnlyLocked` input (true when the order's session has started); when set, keep `inviteOnly = true`, replace the toggle with the MP note 场次已开始，只能建仅邀请队伍 / "The session has started, so only invite-only teams can be created". mp-mine-b will then pass it from `ProfileOrderTeamSeatClubSection`.

## Run 2 (11-28, hourly)

Merged `origin/mp/r3-mine` (A continue 40, 43c88a665). A receipt read first: its open rows are the `CharacterCardReadbackView` byte pin (blocked, pin owner) and the continue 40 post-governance `pendingUnknown` warning (bottom-most, not started by A). Taken here.

| A-receipt row | MP | Native file | Level | Fixed now |
|---|---|---|---|---|
| `pages/shezhi/components/post-governance` (帖文处置与申诉) … "Not done: the MP `pendingUnknown` warning (上次申诉的提交结果未确认…) needs the local pending-appeal store the MP keeps" | `index.js` `_withPending` (pending intent ∧ `canAppeal` ∧ status unknown), `unknown()` read-back; `index.wxml` `pg-warn` after 复核说明, before 提交申诉 | `Core/SquareGovernanceCoordinator.swift` (new read-only `appealOutcomeUnconfirmed(enforcementID:snapshot:)`), `App/SettingsPostGovernanceView.swift` `rowView` / `submit`, `Resources/Localizable.xcstrings` | C | **Fixed.** The local store already exists: `SquareGovernanceJournal` persists `appeal:<id>` per account before dispatch and never unlocks. A row that still offers an appeal while its key is in the journal now shows the MP `pg-warn` line in MP position (footnote, orange `exclamationmark.triangle`, id `settings.postGov.pending.<id>`) **in place of** 提交申诉, because the journal makes a second submit throw `outcomeLocked` (a dead control). The MP's "可以再次提交（不会重复提交）" is not true natively (no reused requestId), so the copy uses the MP's other unknown-branch wording: 上次申诉的提交结果未确认，请稍后下拉刷新确认 / "The result of your last appeal is not confirmed yet. Pull down to refresh later." An unknown submit now follows MP `unknown()`: notice 提交结果未确认，正在确认… → read back → row no longer appealable = submitted (form closes, no notice, as MP `done('', true)`), else 提交结果暂未确认，请稍后刷新确认. The old `mpd.postGov.unknown` ("can submit again") is no longer shown. Tests: `Tests/CoreTests/SquareGovernanceAppealPendingTests.swift`, `Tests/ContractChecks/test_mine_b_post_governance_pending.py`. |

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 46 failing / baseline 46 / **new 0**.

For other lanes / Core owner: `SquareGovernanceJournal` claims `appeal:<id>` before dispatch and never releases it, so a definite rejection (4xx) also locks the row on this device; the MP settles the intent as `rejected` and allows a new appeal. Releasing the key on a definite 4xx (not 408/409) in `SquareGovernanceService.dispatch` would match the MP. Not changed here (shared Core write path).

## Run 3 (11-28 ~15:50 UTC, hourly)

Merged `origin/mp/r3-mine` (A continue 42, f2e8bbf20). Per the coordinator's 15:45 collision fix the run 2 row above (post-governance `pendingUnknown`) was a duplicate of A continue 41; the merge keeps A's side (`App/SettingsPostGovernanceView.swift`, `Core/SquareGovernanceCoordinator.swift`, xcstrings) and drops B's `appealOutcomeUnconfirmed` and its two tests. Run 2's row counts as A's.

Half split (fixed at run start; A receipt open rows in file order): 1 `CharacterCardReadbackView` byte pin (continue 18, blocked) · 2 `scene-member-order-detail` 场次已开始 note (waits on mp-activity `TeamCreateView`) · 3 `pass-unlock` gated reveal | 4 P2-5c participants +1 / legal copy (backend + legal owner) · 5 post-governance refusal shows the server `msg` (continue 42 Not done). (The continue 27 我的项目 empty row was closed by A continue 28.) **B half = 4–5**, taken bottom-up.

| A-receipt row | MP | Native file | Level | Fixed now |
|---|---|---|---|---|
| Continue 42 "Not done: The refusal notice is the fixed 申诉未提交 copy; the MP shows the server `msg` (`requestError`), which needs the failure to carry it." | `pages/shezhi/components/post-governance/index.js:11-13,138-147` `done(requestError(res, '申诉未提交'))` → `app.getRequestErrorMessage` → `utils/transport/safe-user-message.js` `safeUserMessage` | `Core/SquareGovernanceContracts.swift` (new `appealRefused(message:)`), `Core/SquareGovernanceService.swift` (`dispatch` `.rejected` branch, new `refusalMessage(_:)`), `Core/SquareGovernanceSyntheticFixtures.swift` (`mutationMessage`), `App/SettingsPostGovernanceView.swift` (`refusalNotice`, `submit`) | C | **Fixed.** A definite appeal refusal still releases the row first (continue 42), then throws `appealRefused(message:)` with the server `msg` / `message` filtered like the MP `safeUserMessage` (empty, > 60 chars, multi-line, auth / timeout / SQL / Java / URL / path / token / id / phone / email text, and one-phrase developer messages such as 参数错误 → nil). The sheet shows that sentence as the notice with the form still open (MP `done(notice)`), else the fixed 申诉没有提交成功，请重试. English keeps the fixed copy (server text is Chinese; no mixed-language notice). 401 / 403 refusals stay `signedOut` / `forbidden`. Tests: `Tests/CoreTests/SquareGovernanceAppealRefusalMessageTests.swift`, `Tests/ContractChecks/test_mine_b_post_governance_refusal_msg.py`; `SquareGovernanceTests.testDefiniteAppealRefusalReleasesTheRowLikeTheMP` now expects `.appealRefused(message: nil)`. |

Row 4 (P2-5c, participants +1 regex and US legal copy): still backend / legal owner, nothing app-side to change. Skipped.

**Half done** (B half 4–5: 5 fixed, 4 blocked on backend / legal). Run stops here per the 15:45 split rule.

## Run 4 (11-28, hourly)

Merged `origin/mp/r3-mine` (A continue 44, 511b2f751). Fetched every branch: no `docs/release/receipts/cursor-k50-p*.md` exists yet, so there are no K50 `lane-layout` rows for mp-mine. The sweep is unchanged (build c4e43841a, already checked by A continue 44), and the brief has no mp-mine coordinator rows after 13:15 (that ticket-wallet glyph row was closed by A continue 44).

Half split (fixed at run start; A receipt open rows in file order): 1 `CharacterCardReadbackView` byte pin (pin owner) · 2 `pass-unlock` rest (`MPCommerceGate.purchasesEnabled` off) | 3 P2-5c participants +1 / US legal copy (backend + legal owner). **B half = row 3**, still blocked with nothing to change app-side. Skipped.

**Half done** (B half: row 3 blocked). Run stops here per the 15:45 split rule.

## Run 5 (11-28, hourly)

Merged `origin/mp/r3-mine` (A continue 46, 928c405df). Every remote branch checked: still no `docs/release/receipts/cursor-k50-p*.md`, so no K50 `lane-layout` rows for mp-mine. Sweep unchanged (build 2fc0feb24, checked by A continue 46); the brief has no new mp-mine coordinator rows.

Half split (fixed at run start; A receipt open rows in file order): 1 `CharacterCardReadbackView` byte pin (pin owner) · 2 `pass-unlock` rest (`MPCommerceGate.purchasesEnabled` off) | 3 P2-5c participants +1 / US legal copy. **B half = row 3**. Re-checked app side: the remaining mainland-only phone checks (`Core/JourneyLoopSource.swift:408`, `Core/MPGap/AccountPublish/AccountPublishGapModels.swift:490`, `App/JourneySeatTransferSheet.swift`, `App/ClubTopicDetailRows.swift:24`) are journey / activity / club files, not mp-mine, and the participant regex itself is the backend's. Nothing to change in this area. Skipped.

For other lanes: mp-activity / mp-journey — once the backend accepts +1 E.164 participants (P2-5c), `AccountPublishGapModels.swift:490` and `JourneyLoopSource.swift:408` still reject `+1…` numbers on the client.

**Half done** (B half: row 3 blocked on backend + legal). Run stops here per the 15:45 split rule.

## Run 6 (11-28, hourly)

Merged `origin/mp/r3-mine` (A continue 48, 75170fb87). The new K50 receipts (`cursor-k50-r01`, `-r03`, `-r08`) have no mp-mine / `lane-layout` rows; the brief has no mp-mine coordinator rows after 13:15 (the 18:30 sweep covers mp-club / mp-journey).

Half split (fixed at run start; A receipt open rows in file order): 1 `CharacterCardReadbackView` byte pin (pin owner) · 2 `pass-unlock` rest (`MPCommerceGate.purchasesEnabled` false) | 3 P2-5c participants +1 / US legal copy (backend + legal owner). **B half = row 3**, still blocked with nothing to change app-side in this area. Skipped.

**Half done** (B half: row 3 blocked on backend + legal). Run stops here per the 15:45 split rule.
