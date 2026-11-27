# fix-r11 · lane club-b · club.md fix queue P2 rows (#12–#33)

Brief: `design/handoff-r2:docs/briefs/fix-r11.md`. Source: `audit/parity-r11-club:docs/audit/parity-r11/club.md` §3, rows 12–33.
Base: `origin/ui/combined-r7` @ `b9a9d4d29`. Branch: `fix/r11-club-b`. One commit per row.
None of these row ids had been fixed on `origin/ui/combined-r7` before this lane started.

Gates (run before each push): `check_scaffold.py` PASS structural checks; `check_a11y_lint.py` PASS (0 new);
`contract_ratchet.py --check` new 0 (192 failing = baseline 192). Contract checks `test_club_ops_governance` and
`test_club_ops_join_notify` pass after the GS restyle. **There was no compiler in the cloud.** Every type and member used
was checked with grep. Xcode still needs to build this branch.

| # | row id | status | SHA | app file:line |
|---|---|---|---|---|
| 12 | CLB-r9-gate-04 / CLB-r10-detail-01 | **blocked (needs a compiler pass)** | — | App/AppCompositionRoot.swift:3256-3281 |
| 13 | CLB-r11-topic-detail-02 | fixed | 412b3a79b | App/ClubGovernanceViews.swift:1839-1842 |
| 14 | CLB-r11-topic-detail-03 | fixed | 4eca44ac2 | App/ClubTopicDirectorMount.swift:333-430 |
| 15 | CLB-event-ops-05 | fixed | 5f0ffdf24 | App/MPReviewedPageScreen.swift:352-355 |
| 16 | CLB-r11-event-ops-01 | fixed | 36c295036 | App/ClubOpsEventInlineRoster.swift:22-33 |
| 17 | CLB-r11-edit-01 | fixed | 3d0410b79 | App/ClubOpsGovernanceSections.swift (`case .dissolve`); App/ClubGovernanceCommandForm.swift:514-521; App/ClubOperationsViews.swift:13-25, 509 |
| 18 | CLB-r9-create-04 (+nat-create-02) | **blocked (owner decision: MC-10 vs MP)** | — | App/ClubOperationsViews.swift `ClubCreateCityRow`; App/ClubKit/ClubCreateKit.swift:156-250 |
| 19 | CLB-r11-detail-01 | fixed | 01f26eeb8 | App/ClubDetailR8Mounts.swift:19, 30-45, 200, 279; App/MPGap/Club/ClubGapManageExtensions.swift (`onClubFinance`, `clubFinance(_:amount:)`); App/ClubDetailView.swift:444 |
| 20 | CLB-r11-workbench-01 | fixed | 362383d23 | App/MPReviewedPageScreen.swift:1158-1170 |
| 21 | CLB-r11-detail-02 | fixed | 97d922206 | App/MPGap/Club/ClubGapManageExtensions.swift:81, 100 |
| 22 | CLB-r11-settlement-02 | fixed | 8266be40b | App/PayoutReceiverBridge.swift:7-19; App/ClubFEReferenceSettlementHost.swift:5-6, 18; App/ClubPayoutReceiverView.swift:3-5 |
| 23 | CLB-r11-detail-03 | fixed | 81733c64f | App/MPGap/Club/ClubGapRound4Views.swift (type deleted) |
| 24 | CLB-r11-nat-group-code-04 | fixed | d5605eb55 | App/DesignSystem/CYClubGameCodeCard.swift (deleted; project regenerated) |
| 25 | CLB-r11-nat-settlement-01 | fixed | 698872d8b | App/WithdrawalSupportContactView.swift:34-61 |
| 26 | CLB-r10-nat-detail-03 | fixed | f0fe1b591 | App/ClubCommunityViews.swift (three Sections removed; `.refreshable` at :855, :1199, :1259) |
| 27 | CLB-r10-nat-detail-06 | **blocked (owner theme pause)** | — | App/ClubDetailView.swift:402, 409, 502-503 |
| 28 | CLB-r10-nat-detail-08 | fixed | a090cf292 | App/ClubActionPanel.swift:44-49, 119-135 |
| 29 | CLB-r10-nat-topic-story-03 | **blocked (UI-test rewrite needs a simulator)** | — | App/ClubGovernanceViews.swift:2505-2541 |
| 30 | CLB-r10-nat-topic-detail-04 | fixed | 7ea2f502d | App/ClubGovernanceViews.swift:809-811, 1771-1773 |
| 31 | CLB-r10-nat-event-ops-04 | fixed | 5922b41a6 | App/ClubOpsEventFormFields.swift:94-122; App/ClubGovernanceCommandForm.swift:202-206 |
| 32 | CLB-r10-nat-governance-03 | fixed | 6b1bebd8d | App/ClubOpsGovernanceSections.swift (35 × `.cyText`, 3 × `CYSpacing`) |
| 33 | CLB-r10-nat-edit-02 | fixed | 73c4def8c | App/ClubOperationsViews.swift:535-562 |

Totals: 18 fixed, 4 blocked, 0 merchant release.

## Notes per row

- **#12 blocked.** Neither of the two options suits a cloud lane without a compiler:
  - **Wiring the approvals** inside `if grantPlayerWrites` would make native send `api/club/post/operation/*`. The MP never sends that path, so this goes against MP-first.
  - **Deleting the dead branches** is the MP-first option, but it is not local. The approvals feed `AppSession.compositionClub{Post,Comment}OriginalApproval` (App/AppSession.swift:862-866), `ClubPostOriginalComposition` / `ClubCommentOriginalComposition`, the transport setters (ACR:709-710, 1829-1830), Core `ClubPostOriginalRuntime` / `Service`, `ClubCommunityPendingJournal`, `ClubGapClient`, CRC, and six test files.

  Hand it to a lane with Xcode: delete the two ACR branches, both approval vars and the original-publication resolvers together.
- **#14:** This reuses `PlayDirectorRecap.normalize` (the privacy allowlist) and `PlayDirectorCoordinator.exportRecap()`. The copy goes to `LocalPasteboard`, as on the director page. The page shows:
  - the first three metrics under 活动复盘;
  - the rest under 完成情况;
  - 榜单 rows, then 节点完成 rows with 到达/完成/兜底/打回 (MP director.js:295-305);
  - 显示/隐藏榜单, only with `SET_LEADERBOARD_VISIBILITY`;
  - 复制复盘数据, only when `exportAvailable`.

  Without a valid recap it shows 复盘尚未生成.
- **#17:** `ClubDissolvedReturn` is an environment value. The edit page sets it on the dissolve-blockers link, and the command form calls it 0.5 s after the acknowledged dissolve. Outside the edit page the form only dismisses itself.
- **#19:** The settlement read runs only for owners, inside `loadSettingsCounts`. On failure it shows 暂时读不到 (`club.settings.countUnavailable`). Tapping the row pushes the new `ClubDetailR8Route.settlement` → `ClubGovernanceReadView(.settlement)`.
- **#22:** Comments only. Club-a's CLB-r11-settlement-01 rewrites `allowsSettle`, and these lines sit next to it, so a merge may conflict there. If it does, keep club-a's code and either side's comment.
- **#25:** The UI test `WalletCommerceFlowTests` accepts `withdrawal.support.unconfigured` as a static text, so the orange `Label` still matches.
- **#27 blocked:** The row says it waits for the theme pause to lift. The owner paused design work on 11-26.
- **#29 blocked:** `Tests/AppUITests/ClubStoryFlowTests.swift` taps the chip buttons (`club.story.chapter.N`) through a pinned horizontal-scroll helper. Two contract checks pin that helper's text: `test_club_story_horizontal_query.py` and `test_club_story_adaptive_chapter_scroll.py`. Moving to the menu Picker means rewriting the UI test's chapter navigation and both checks, and that rewrite needs a simulator to confirm.
- **#30:** `.cyDomainSheet` is replaced by `.presentationDetents` plus `.presentationDragIndicator(.visible)`. The role-themed presentation goes with it.

## New strings

- `Localizable.xcstrings` (zh-Hans + en):
  - `club.topic.paidSessionsBlocked`
  - `club.director.recap.{title,completion,leaderboard,stations,pending,copy}`
  - `club.director.recap.{arrived,completed,fallback,rejected} %lld`
  - `club.settings.{businessSection,clubFinance}`
  - `club.workbench.{enterFailedDetail,backToClub}`
  - `club.coopPool.permissionTitle`
  - `club.coopPool.publishedBy %@`
- `ClubOpsGovernance.xcstrings`: `clubOpsGov.success.dissolve`.
