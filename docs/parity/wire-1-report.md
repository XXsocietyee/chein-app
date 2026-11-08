# wire-1 report (branch cloud/wire-1, based on origin/wip/port-build)

NOTHING HERE WAS COMPILED OR TESTED (no Swift toolchain in the cloud run). Every hunk was written by reading neighbouring code and grepping the symbols it uses (`ClubGovernanceValue.string`, `ClubGovernanceFailure`, `ClubGovernanceMutation` cases, `dismiss`, `dirty`, `Theme.Color.textSecondary`). A local worker must build, then add the strings in `wire-1-new-strings.md` (Resources/xcstrings was not edited), otherwise the new rows show raw keys. No routes, leases, endpoints or gates changed; no existing test touched; no new test files (no new pure logic was added).

## Wired
| # | what | where |
|---|---|---|
| 1 | Leaderboard now folds through `ClubDetailRankingPort.fold` (top 3, "⋯ N hidden" row, tail), values via `oneDecimal`, duration sort via `durationText`, empty copy per sort via `emptyKey`. | `App/ClubPublicRosterView.swift` (this is where the club/detail leaderboard rows render; `ClubDetailView` itself only links to it) |
| 2 | `targetName` is passed for member and activity reports (display only; `ClubGovernanceFormDraft` filters the seed to anchor keys, so command anchors are unchanged). `reasonRequiredKey` hint renders under the reason field for ban / transfer / report / appeal once the user has edited the form and the reason is blank. | `App/ClubMemberReportView.swift`, `App/ClubActivityReportView.swift`, `App/ClubGovernanceCommandForm.swift` (the form lives there, not in ClubOpsGovernanceSections) |
| 3 | Topic-overview session rows use `ClubGroupCodePort.sessionLabel` (`name · M月D日 HH:mm`). Issue-group-code failures classified `.noPermission` (403 / 权限 / 无权) show a terminal "no permission" state with a back button instead of the generic error. | `App/ClubGovernanceViews.swift`, `App/ClubGovernanceCommandForm.swift` |
| 4 | `ClubTopicVerifySummarySection` embedded in the topic overview, gated by `ClubTopicDetailPort.showsVerify`. | `App/ClubGovernanceViews.swift` (topicOverview branch) |

## Not wired / limits
- (1) The viewer's own member id is not in the roster snapshot, so `fold(me:)` is called with `nil` (no viewer-neighbourhood widening). Member-strip "+N" (`memberStrip`) not wired: ClubDetailView shows only the count header, there is no avatar strip to attach it to. `ClubDetailRankingPort` durationText is minutes; I assumed `completionDuration` is minutes (matches the mini `durationMin`), unverified.
- (2) The two report screens already show a target card above the form, so the name now appears twice (card + form row). Reason-required hint is shown only after an edit, since showing it on a pristine form would be noise.
- (3) The no-permission "exit to club management" is `dismiss()` back to where the form was pushed from; no navigation to the management screen was added. Auto re-issue stays out (writes).
- (4) The verify card reads `canViewVerify` and the three counts from the topicOverview payload. In the app, those fields live in the `topicStats` read, and the overview payload is a sanitized public projection, so the card will most likely stay hidden until the overview host also loads topicStats (needs a second coordinator read; not added to avoid new read wiring). The primary footer button plan (`primary(...)`) is not wired.
- (5) IMInboxPort / IMChatPort: deliberately NOT wired.
  - `typedPreview` returns zh-only literals and bypasses the redacted-preview default; the existing `searchPreview` is already localized (`messaging.image` / `messaging.card`). Wiring it would regress English and the privacy default.
  - `readAllTargets` / `readAllOutcome`: `IMConversationReadAll` already freezes unread>0 rows and has per-item outcomes, so the port would be a duplicate.
  - `needsDivider`: `IMInboxTime.dividers` already implements the same 5-minute rule.
  - `sendableText`, `isConfirmedServerID`, `freshIDs`, `merge`: they belong to send/poll flows that stay dormant (no new endpoints). `cardIsTappable` / `genericCardTitle` would belong in `MessagingCardContent` (App/MessagingMessageDetailView.swift), which is outside the listed screens; left alone.

## Could not verify
Compilation, any test run, SwiftUI layout, `Text(LocalizedStringKey(...), tableName:)` key resolution, `Text("key \(Int)")` catalog entries.
