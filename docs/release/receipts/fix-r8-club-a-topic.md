# Receipt: fix-r8-club-a-topic (round 5, 2026-11-25)

Branch `fix/r8-club-a-topic` (topic-detail, topic-story and event-ops part of the r8 club queue,
`origin/audit/parity-r8-club:docs/audit/parity-r8/club.md` §3, rows owned by Claude App). The combined club receipt for rounds 1-4 is
`docs/release/receipts/fix-r8-club.md` on `fix/r8-club`.

Nothing here was compiled; there is no compiler in the cloud. Every type, initializer and property used was grepped on the tree first.
`python3 tools/check_scaffold.py` prints `PASS structural checks`.

## Step 1: merge `origin/ui/combined-r7` (f95850a46) → 1172a4e14

- `Resources/Localizable.xcstrings`: 3-way merge by key. The integration side was kept for every key it changed. This branch's 13 new keys and
  its 31 MP-copy overrides (fix-r3-club-a/b fragment values, applied in 554f2f385) were re-applied. Neither side deleted a key.
- `Tests/ContractChecks/test_club_leaderboard_member_navigation.py`: both comments kept. The customer-filter span hash was re-pinned on the
  merged `App/ClubGovernanceViews.swift`, which carries this branch's MP chip row and the integration side's round-4 check-in / 编辑 changes.
  The other three span hashes are the integration values and still match.
- No conflict markers. No new top-level duplicate type names across the two sides.

## Step 2: rows

| id | sev | status | where |
|---|---|---|---|
| CLB-topic-story-05 | P1 | closed (needs a device check) | MP `pages/club/topic-story/index.js:157-162, 271-285`: a merchant link has `scope` and no `clubId`, so answers post `api/topic/host-node-answer` `{topicId, nodeId, scope}` (JSON). `App/MPReviewedPageScreen.swift` passes the link's `scope` (only when there is no clubId) through `\.clubStoryHostAnswer`. `ClubGovernanceStoryView` builds `ClubStoryPresentation(snapshot:hostScope:)`, so a clubless story renders instead of 来源不可用. 查看答案 on an answerable play opens `ClubStoryHostAnswerSheetContent` (App/ClubStoryHostAnswer.swift), which reads through `ClubRemainingGapClient.fetchHostNodeAnswer` on the session transport. The route must be shown (`showsRoute("/api/topic/host-node-answer")`, liveInProduction). A sign-out mid-request drops the answer, and a 401 expires the matching session. The club entry keeps its `.nodeAnswer` read unchanged. |
| CLB-topic-detail-07 | P2 | already closed on the integration branch | `sessionPickerVisible` / `topicSessionPicker` in ClubGovernanceViews |
| CLB-group-code-05 / CLB-group-code-04 deep link | P1/P2 | already closed on the integration branch (fix-r3-club-b round 4) | `ClubGroupCodeSessionStep` and the `activityName` label in MPReviewedPageScreen |
| CLB-topic-detail-06 | P1 | open | MP saves the three switches on change with rollback (`index.js:1268+`). In the app, topic settings run through the command-form review/return state machine (`ClubTopicSettingsReturn`, pinned by test_club_topic_settings_return). Changing it to inline auto-save is not safe without a compiler pass. |
| CLB-event-ops-09 | P2 | open | needs a visual check on a device |

## For Cursor

- `ClubStorySelection` (Core/ClubStoryPresentation.swift) builds `ClubStoryPresentation(snapshot:)` without `hostScope`, so on the merchant
  (clubless) story 看看模板 shows 模板暂不可用. The MP shows 看看模板 for merchants too (`index.js:231-240`). It needs the host scope threaded into
  the selection.
- `ClubHostNodeAnswer` decodes only `question` / `answerReveal`. If `api/topic/host-node-answer` also returns `hints` / `feedbackText` like the
  club endpoint, add them, and the host sheet will show them through `ClubNodeAnswerContent`.
