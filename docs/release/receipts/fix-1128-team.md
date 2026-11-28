# fix/1128-team — P0-8 team writes (receipt)

Base: `origin/ui/combined-r7`. Audit: `origin/audit/1128-functions:docs/audits/1128-functions.md` P0-8.
Behaviour reference: MP `chengyinhub-xcx/pages/team/detail`, `pages/team/join`, `subpackageMember/signup` (我的队伍 → `goMyTeam`).
Backend: hengyin `origin/us/r3-functional` `ApiPlayTeamController` (`/api/team/*`, all `POST` JSON).
No Swift compiler here: Swift tests are authored, not run (NOT_RUN). Python gates were run (below).

## P0-8 — Team writes are dead → closed

| Step | Evidence |
|---|---|
| Service: `makeTeamCoordinator()` builds `TeamHTTPService` (not `TeamReadOnlyService`) when the reviewed membership write lease is issued; the read lease and the fresh-membership rule on ID reads are kept | `App/AppSession.swift:5342`, `App/TeamMembershipWriteComposition.swift` (`TeamMembershipWriteComposition.service`), `Core/TeamHTTPService.swift` init (`readApproval`, `requiresIDMembership`) |
| Lease: `api/team/{join,quit,kick,disband,join-mode}`, CN player / club / merchant, only with the reviewed production gates (same as the nearby apply / handle lease) | `App/ReviewedPlayerWriteLeases.swift:1278` `teamMembershipWrite`, `AppCompositionRoot.teamMembershipWriteApproval` in `App/TeamMembershipWriteComposition.swift` |
| Firewall: only the exact bodies the adapter sends pass the composition transport | `App/ReviewedProductionRoutes.swift:9` `ReviewedTeamMembershipWriteRoute`; branch `App/AppCompositionRoot.swift:3595` |
| Wire = backend fields | join `{"inviteCode"}` (trimmed), quit / disband `{"teamId"}`, kick `{"memberId","teamId"}`, join-mode `{"joinMode":1\|2,"teamId"}` — `Core/TeamContracts.swift` `TeamWriteContract`; backend `ApiPlayTeamController.join/quit/kick/disband/updateJoinMode` |
| Before sending: journal entry first, fresh `/api/team/info` re-read, `TeamAction.isAllowed` (captain-only kick / disband / join-mode, member-only quit, non-member join on a recruiting team) | `Core/TeamHTTPService.swift` `submit`, `Core/TeamCoordinator.swift` `confirm` |
| Confirmations (MP `danger-actions` dcQuit / dcKick / dcDisband): review sheet with consequences for leave / kick / disband, red confirm, 改为退出 alternative on disband; join confirms in place like MP join | `App/TeamComponents.swift` `TeamReviewSheet`, `App/TeamHomeView.swift` `joinDirectly` |
| Server-confirmed result: ack decoded (`code==200`; join-mode must echo the requested `joinMode`), `errorCode` rejections stay coded, others show the MP fallback 操作没有完成，请刷新后重试 | `TeamHTTPService.decodeAcknowledgment`; `team.rejected` copy (was "simulated request was rejected") |
| Success copy = backend messages: 已加入队伍 / 已退出队伍 / 成员已移出 / 队伍已解散 / 组队方式已更新 | `Core/TeamContracts.swift` `TeamAction.confirmedKey`, `Core/TeamCoordinator.swift:322` |
| Refresh team detail: after a confirmed kick / join-mode the page re-reads `/api/team/info` and only a successful read releases the lock (failed read keeps the lock + 刷新失败 banner; pull-to-refresh retries the read-back) | `Core/TeamCoordinator.swift:389` `readBackConfirmedWrite`; `App/TeamHomeView.swift:493` `TeamConfirmedWriteFollowUp`, `:463` reload |
| Quit / disband (MP `terminal`: toast + `navigateBack` to 我的队伍): the team is retired, the result shows, the page returns; 我的队伍 re-reads `/api/team/my` on appear. A retired team no longer shows the "team unavailable" error page | `App/TeamHomeView.swift:305` `followUpConfirmedWrite`; `Core/TeamPagePresentation.swift:137` |
| Join by code (MP join): 加入码 entry → invitation read → 加入队伍 → 查看队伍 (membership-required read) | `TeamInvitationEntryView`, `App/TeamHomeView.swift` `invitationActions` |
| Ticket / registration 我的队伍 (MP signup `goMyTeam` → `pages/team/detail`): the ticket team roster now opens the full team detail (with these writes) and re-reads my teams when the player returns | `App/TicketWalletTeamView.swift:69,226` |
| Apply / applications / handle / my-applications / withdraw / nearby: already live behind the reviewed nearby leases (`ReviewedNearbyTeamWriteRoute`, `ReviewedNearbyTeamReadRoute`); the captain's 入队申请 block on the detail page uses `TeamDetailApplicantsHost` (`api/team/applications` + `api/team/command` handle) and reloads after each decision. Unchanged here | `App/ReviewedProductionRoutes.swift` `ReviewedNearbyTeamWriteRoute`, `App/MPGap/AccountPublish/AccountPublishR8Mounts.swift:60` |
| Haptics: typed `TeamWriteResultHaptics` unchanged; success fires on the `.acknowledged` render before the read-back moves the state to idle | `App/TeamHomeView.swift` |

### Tests (authored; Swift NOT_RUN)
- `Tests/CoreTests/TeamMembershipWriteTests.swift`: exact request bodies for kick / join-mode / disband / quit / join; read-back roster and mode; mismatched join-mode echo stays unknown and locked; disband retires with no error page; coded/uncoded rejection terminal; failed read-back keeps the lock; a path outside the lease is never sent; every action has confirmed copy.
- `Tests/AppUnitTests/TeamMembershipWriteRouteTests.swift`: every `TeamHTTPService` request passes `ReviewedTeamMembershipWriteRoute` only with its own token; near-miss bodies, other team routes, GET, query strings and other hosts are refused; lease paths are exactly the five writes.
- Contract checks updated: `test_operation_http_adapters.py` (adapter built only by the composition helper behind both leases), `test_ticket_wallet_team.py` (one explicit link to the team detail).

### Gates
`python3 tools/generate_project.py` ✓ · `python3 tools/check_scaffold.py` ✓ (glue-file line ratchets unchanged) · `python3 tools/contract_ratchet.py --check` new 0 ✓ · `python3 tools/check_design_consistency.py` ✓ (untyped haptic 0) · `python3 tools/check_a11y_lint.py` ✓.

### Strings (en + zh-Hans)
`team.done.join|leave|remove|disband|joinMode`, `ticketTeam.manage`; `team.rejected` reworded. In `Resources/Localizable.xcstrings` and the team / ticket-team fragments.

### Not in this branch
- Live check on a device against the CN backend needs the reviewed deployment with production gates (no deploy from here).
- US market team writes follow the US read lease (none today; P1-25).
- The post-join detail opened from the invitation page stays read-only by design (`loadPostJoinDetail`); 我的队伍 opens the full page.
