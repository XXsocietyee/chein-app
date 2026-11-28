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
