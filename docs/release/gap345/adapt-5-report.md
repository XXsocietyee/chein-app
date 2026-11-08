# ADAPT-5 report (branch `cloud/adapt-5`, base `origin/wip/wave4-final`)

Nothing compiled or run for Swift (no toolchain). Python contract checks only. Backend read from `hengyin@4ac8c249` (fetched into a detached worktree; the provided checkout lacked the commit; nothing pushed to hengyin). All results are source-level; production version unverified.

## Job A: password login unreachable in release — DONE (unverified by compile)
- `App/AppSession.swift`: new `static passwordLoginCompiledIn` (`#if DEBUG`), `canUsePassword` is `false` outside DEBUG, `AuthService` is not constructed for password outside DEBUG (`service=nil`), `login(username:password:)` returns `auth.notConfigured` first when the switch is off.
- Not changed: `LoginView` (its Section and `submit()` already follow `canUsePassword`), `AuthService`/`AuthEndpoint.password`, all existing tests. Debug/test builds behave as before (still capability-gated, `false` by default).
- Entry points covered (doc §6 rows 1-8): #1 untouched code retained; #2, #3, #4 gated; #5-#7 follow #4; #8 only navigates.
- Tests: `Tests/AppUnitTests/Adapt5PasswordLoginOffTests.swift` (structural, plus build-config flag; phone/WeChat/Apple entries asserted present); `Tests/ContractChecks/test_adapt5_password_login_off.py` (ran, passes).
- Limit: tests run in Debug, so the release behavior is proven by source markers, not by a release-build run.

## Job B: ADAPTABLE rows (3)
| Row | Re-verified | Result |
|---|---|---|
| `/api/ugc/report` (label) | `ApiCommunityTrustController` `POST /api/community-trust/reports/submit`, JSON body, token, 401 `请先登录`, 400 `缺少举报参数` | DONE: default `ugcReportEndpoint` string changed; readiness check untouched. `/api/ugc/block` left (PARTIAL). No HTTP call added. Test: `Adapt5ModerationEndpointTests.swift` |
| `/api/user/sms/send` | real route `POST /api/sms/send`, param `phone`, anonymous | DONE (additive): `Core/Adapt5HighRiskWriteSupplement.swift` |
| `/api/pay/create` | real routes `POST /api/registration/pay`, `/pay/app`, param `id`, token, consent gate, 410 on expired | DONE (additive): same type. Test: `Tests/CoreTests/Adapt5HighRiskWriteSupplementTests.swift` |

Deviation from doc §4: the doc says to add cases to `RegionalHighRiskWriteRoute`. An existing test pins that enum's exact 6-path set, so the original enum was NOT edited; a new supplement type holds the additions. It is not yet consulted by `RegionalEndpointAllowlistAudit.audit` (wiring into the audit would change pinned report behavior). Left for a follow-up decision.

## Not done (by design)
All `/api/friend/*` rows (no friend system; follow is not a friend request), PARTIAL and MISSING rows. No gates, approvals, `reviewed:`, AppSession/CompositionRoot/QuestifyApp wiring, resources, or mock data touched.

## Unverified
Swift compile and all Swift tests; production backend version; form-vs-query wire encoding noted in the source doc.
