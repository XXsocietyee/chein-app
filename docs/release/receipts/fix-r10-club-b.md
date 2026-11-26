# fix-r10 · lane club-b receipt (2026-11-26)

Branch `fix/r10-club-b` from `origin/ui/combined-r7` (d9832ac50). Slice: club.md P0 second half (CLB-G13a), then the
release-dead rows gate-05 / badges-01 / group-code-01 / notify-01. No compiler in the cloud: every type and member was
grepped before use. Not built on a simulator.

| Row | Status | SHA | App / Core file:line |
|---|---|---|---|
| CLB-r10-gate-05 | **fixed** | 193356907, a22f25659 | Core/ClubGovernanceProduction.swift:31-40 (`clubOps`: sendNotification, retryNotification, issueGroupCode, saveCustomer, createSeries, updateSeries, correctAttendance, saveTopicSettings, chapterRecruit, chapterFinish joined to `governance`); App/MPFirstClubApprovals.swift:89-127 (write + review-read paths on `governancePaths`; multipart `formPaths` for chapter recruit/finish). cancelOccurrence, endTopic, reportHours, submitEvidence stay out (money). Tests: Tests/CoreTests/ClubGovernanceProductionTests.swift `testMPFirstClubOpsDispatchInChina` (each of the 10 has a production service in China); Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift (Release China composition's `clubGovernanceApproval.liveOperations ⊇ clubOps`). Contract pin re-hashed with a comment: Tests/ContractChecks/test_club_customer_permissions.py:114-118. |
| CLB-r10-badges-01 | **fixed** | 704e52991 | Core/ClubBadgeManagementModels.swift:66-87 (`init(mpFirstEndpoints:)`, `anyClub`; reads + create + grant); App/MPFirstClubApprovals.swift:38-49 (`badges(_:)`, one approval per session identity so the revision is stable); App/AppCompositionRoot.swift:173 (`private(set) var`), :609 (set inside `grantPlayerWrites`); firewall App/MPFirstClubApprovals.swift:100, 126. Tests: ClubBadgeHostDefaultTests `testMPFirstBadgeApprovalInChina`; ReviewedChinaLaunchCompositionTests asserts non-nil in Release China. The unconfigured-composition nil test is kept (still true). |
| CLB-r10-group-code-01 | **fixed** | 193356907, 7c201f047 | issueGroupCode is in `clubOps` (gate-05); its multipart review read `api/topic/info-to-user` joins `formPaths` (App/MPFirstClubApprovals.swift:103). CLB-group-code-06 (receipt checked by activityId, no clubId) was already on the base: App/ClubGovernanceCommandForm.swift:892-899. |
| CLB-r10-notify-01 | **fixed** | 193356907, fabccf0a7 | send/retry in `clubOps`; paths + preview/status reads on the firewall. Firewall test: Tests/AppUnitTests/MPFirstClubWriteRouteR10Tests.swift (admits the r10 club POSTs, chapter multipart, badges; refuses cancel/end/hours and money keys). |
| CLB-G13a | **partly** | 6428e0c58 | App/ClubTopicDirectorOpsSections.swift:10, 48; App/ClubTopicDirectorMount.swift:56-57: 通用玩法 rows are disabled while the director phase is not `ready`. **Blocked:** the per-action sheet (fields, 时间为北京时间, ledger rows, 确认并提交). MP `pages/club/topic-detail/index.wxml:204-236` and its JS are not in this repo and `chengyinhub-xcx` is not reachable from this session, so the per-action payloads for `api/game/session/command` can't be ported MP-first. parity-b receipt also notes the director manual actions are outside the player grant. Needs the MP source (or a Core payload spec) before an App sheet. |

## Gates (last run before push)

- `python3 tools/check_scaffold.py`: PASS structural checks.
- `python3 -B tools/check_a11y_lint.py`: PASS (0 new).
- `python3 tools/check_appsession_ratchet.py`: PASS (AppCompositionRoot kept at 4175 lines).
- `python3 -B tools/contract_ratchet.py --check`: the only new failure is `test_social_article_content…test_renderer_is_wired_only_to_existing_scoped_article_contents`. It fails the same way on the untouched base `origin/ui/combined-r7` (d9832ac50), so this lane didn't cause it.
- New file → `python3 tools/generate_project.py` run.

## Notes for the coordinator

- club-a's slice ("P0 first half") also names gate-05/badges-01. If club-a pushed the same rows, keep one side. These hunks are small: Core/ClubGovernanceProduction.swift:31-40, App/MPFirstClubApprovals.swift, AppCompositionRoot.swift:173/609.
- `MPFirstClubWriteRoute.accepts` now checks Content-Type per path (JSON for the existing paths, multipart only for the three `formPaths`). The JSON paths behave as before.
