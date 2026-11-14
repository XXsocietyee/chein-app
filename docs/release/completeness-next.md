# Completeness: next packages (from the proposed owner decisions and OPT triage)

Source: `docs/owner-handover/SUPPLEMENT.md` §Refresh 3, against `completeness-missing.md` (app `e3264af9f`, hengyin `067da9748`, mini-program `1ca6d3215`). That file left 62 rows that a native worker could not take: NX-01 (21), NX-03 (17), NX-04 (19) and WP-R (5). This file turns them into packages. **The decisions behind these packages are PROPOSED - owner may override.** If the owner overrides one, change only the rows that cite it.

`mp:` means a path under `chengyinhub-xcx/` at `1ca6d3215`. Row ids with a letter suffix (`OWN-D-01.a`) are build steps under one matrix row. That matrix row (`OWN-D-01`) closes when all of its steps are done and a test cites the bare id.

| package | rows | source rows | native worker |
|---|---|---|---|
| [WP-10](#wp-10) Owner-decision guards: points, dues, content chain, ending, payout, AI, creator revenue | 16 | D-01…D-06, D-08, D-10, OPT-010 | yes |
| [WP-11](#wp-11) Session-scoped background location, device lifecycle, content compatibility, release validation | 16 | D-07, 10.3, OPT-042, OPT-072, OPT-090, OPT-091, OPT-092 | yes |
| [CL-01](#cl-01) OPT close-out: ALREADY-DONE citation tests and DROP absence checks | 22 | NX-03 / NX-04 rows triaged ALREADY-DONE (18) or DROP (4; OPT-052 closes in WP-11) | yes (tests only) |
| [CL-02](#cl-02) Condition packages, D-09 and roll-ups close-out | 16 | EXT-01…09, EXT-11, D-09, WP-R (5) | yes (tests and the evaluator rule) |
| total | 70 | | |

Rows that feed packages which already exist (no new rows; the existing package's acceptance covers them):

| source row | goes to | what changes |
|---|---|---|
| `OWN-D-05` | WP-01 | `API-/api/club/personal-receiver/bind` is a hand-off to the mini-program. Bind needs a `wx.login` code (`mp:pages/club/payout-receiver/index.js:1-3`) that iOS cannot produce. Native keeps status, unbind and settlement. WP-10 D-05.a carries the native half. |
| `OWN-OPT-014` | WP-03, WP-06 | The coupon claimed, sold-out and unconfirmed states are on `subpackageMember/coupon/coupon` (WP-03) and `couponInfo` (WP-06). |
| `OWN-OPT-022` | WP-02 | The audit appeal and guard appeal routes. Community-trust is DONE. |
| `OWN-OPT-032` | WP-09 | The preset versions (21.1, 21.2, U02-04). Adoption is DONE. |
| `OWN-OPT-043` | WP-06 | Stamp album, stamp camera and citystamp. |
| `OWN-OPT-060` | WP-03 | Merchant claim routes. |
| `OWN-OPT-062` | WP-03 | `PAGE-pages/merchant/team/index` (staff permissions). |
| `OWN-OPT-082` | WP-06 | `PAGE-pages/publish/simple/index` (AI draft). |
| `OWN-22.1`, `OWN-22.2`, `OWN-十三`, `OWN-十一`, `OWN-十四` | WP-07, WP-08, WP-09 | These close when their children close, under CL-02.R. |

How to close a row: as in `completeness-missing.md`. Land the change, re-run the evaluator, and add a test that cites the id. A row is not closed by a report alone.

## WP-10

**Owner-decision guards: points, dues, content chain, ending, payout, AI, creator revenue** — 16 rows.

- Native files to touch: Core/WalletCommerceContracts.swift (`WalletPointsTask`), App/PassMarketPointsDestination.swift, App/RegistrationSheetView.swift, Core/RegistrationCheckoutPresentation.swift, App/SquareDetailView.swift, Core/SquareGovernanceService.swift, Core/PlayExperienceService.swift, new App/ClubPayoutReceiverView.swift + App/MerchantPayoutAccountView.swift (shared with WP-01), App/PublishingModesViews.swift, Core/PublishModesDomain.swift, App/ClubGovernanceViews.swift, App/WalletCommerceViews.swift; new Tests/CoreTests/OwnerDecisionGuardTests.swift
- Backend route: ApiPointsController (`/api/points/result_list`), ApiRegistrationController (quote), ApiClubController (`personal-receiver/status`, `unbind`), ApiMerchantPayoutAccountController, ApiAiController (`theme/draft/quota`), ApiMarketingController (`revenue/author/mine`). No new routes.
- Mini-program page: subpackageMember/components/cy/profile (points rules), pages/activity/baoming/baoming, pages/square/detail/index, pages/play/index (ending), pages/club/payout-receiver/index, pages/merchant/payout-account/index, pages/publish/simple/index, pages/club/topic-story/index, subpackageA/components/revenue-allocations
- Acceptance test: `OwnerDecisionGuardTests` cites `OWN-D-01`, `-02`, `-03`, `-04`, `-05`, `-06`, `-08`, `-10` and `OWN-OPT-010`, one assertion group per row. On TEST 8120, signed in as the SMS fixture player: the points rules show an 「积分消耗」 group, and a sign-up for a ticket with points disabled shows 「该票不支持积分抵扣」. Signed in as club 9003's owner, the receiver page shows status and unbind but no bind button. Every payout write stays refused while `ReleaseMoneyWriteSwitch.payoutEnabled` is false.

| row | status | what is open |
|---|---|---|
| `OWN-D-01.a` | MISSING | Points rules: split earn and spend. `isEarnTask` drops eventType 14 entirely (`Core/WalletCommerceContracts.swift:205`). Show those rows as 「积分消耗」, and drop rows with `delFlag≠0`, as `mp:subpackageMember/components/cy/profile/points-rules.js:18,36-50` does. |
| `OWN-D-01.b` | MISSING | Sign-up: when the quote returns `pointsDeductYuan == 0` with the toggle on, turn the toggle off and say 「暂无可用积分」 (balance 0) or 「该票不支持积分抵扣」 (ticket refuses points), as `mp:pages/activity/baoming/baoming.js:1238-1243` does. Native shows one `insufficientPoints` line for both (`App/RegistrationSheetView.swift:566`). |
| `OWN-D-01.c` | MISSING | Guard test: no client point-to-yuan rate constant. An absence check over `App Core` finds no rate literal. The order detail shows the snapshot `pointUsed` (`mp:subpackageMember/components/cy/scene-member-order-detail/index.wxml:90`) and never recomputes it. |
| `OWN-OPT-010` | MISSING | Closes with D-01.a–c. The test cites `OWN-OPT-010`. |
| `OWN-D-02` | MISSING | Absence check: no `api/club/membership*` call site and no dues screen in `App Core`, excluding the `UnifiedOPT*` and `Legacy52*` contract records. The test cites `OWN-D-02`. |
| `OWN-D-03.a` | MISSING | A surface-to-chain table in Core: feed, notifications, enforcements, appeals, capabilities and reports on `/api/v1/community`; square compose, detail, like, bookmark, report and delete on `/api/creativesquare/*` (`mp:utils/community-post-api.js:6`, `mp:pages/square/detail/index.js:581-1076`). A test asserts each surface's client uses its chain. |
| `OWN-D-03.b` | MISSING | No code path flips a whole surface between chains (no B-stack switch). Absence check plus a test. Square delete itself is WP-04. |
| `OWN-D-04` | MISSING | Render-only ending: a test that the ending view's content comes only from `/api/play/ending` / `/api/play/journey/ending` fragments (`mp:pages/play/index.js:8446,8476`) and that no client type picks or reorders endings. |
| `OWN-D-05.a` | MISSING | Club personal receiver: native status read (`/api/club/personal-receiver/status`) and unbind with the mini-program's confirm copy (`mp:utils/danger-actions.js:56-62`). Bind shows 「请在小程序完成绑定」 with a copyable path and sends no request. This replaces the native bind in WP-01. |
| `OWN-D-05.b` | MISSING | Merchant payout account: read-only, shown only when `access/me` grants `FINANCE_READ` (`mp:pages/merchant/payout-account/index.js:1-2`). It renders the server facts and a copyable signing link, with no edit and no withdraw. |
| `OWN-D-05.c` | MISSING | A unit test proves that unbind, and any payout-account write, sends nothing while `ReleaseMoneyWriteSwitch.payoutEnabled` is false, and that the China production host refuses it. |
| `OWN-D-06` | MISSING | A test that no dues product exists and that platform-pass purchase is reachable only through `MPCommerceGate` (`App/MPParityKit.swift:11`). No WeChat Pay for digital goods on iOS. |
| `OWN-D-08.a` | MISSING | AI unavailable state: when `/api/ai/theme/draft/quota` or the config read fails or is incomplete, the AI entry shows unavailable, never mock text, and spends no quota. Test covers `Core/QuickPublishValidation.swift:153` and `Core/PublishingAIDraftFlow.swift`. |
| `OWN-D-08.b` | MISSING | AI label: ai_simple story shows 「AI 生成」 (`App/ClubGovernanceViews.swift:1739`, `mp:pages/club/topic-story/index.wxml:11`). An AI draft keeps `aiTraceId` (`Core/PublishModesDomain.swift:94`) and appends the 「[AI 辅助生成]」 mark (`mp:pages/club/utils/aiPlanToDraft.js:33`). An adopted template shows the author's name only (`mp:pages/templatedetail/utils/topic-adoption.js:119`). One test for all three. |
| `OWN-D-08.c` | MISSING | Absence check: no long-term NPC memory, no paid memory slot, and no AI feature that is on by default. This also closes the build side of `OWN-EXT-07`. |
| `OWN-D-10` | MISSING | Author revenue tab: hidden when the list is empty or the user is not a participant. When the read fails it shows 「收益暂不可用」, not 0 (`mp:subpackageA/components/revenue-allocations/index.js:1-3`). Test on `App/WalletCommerceViews.swift:71`. |

## WP-11

**Session-scoped background location, device lifecycle, content compatibility, release validation** — 16 rows.

- Native files to touch: new App/SessionBackgroundLocationTracker.swift (a reference-counted owner table, ported from `mp:utils/location/bg-tracker.js`), App/RoamLiveSessionView.swift, App/RuntimeNativeLocationProvider.swift, App/PlayNativeDeviceProvider.swift, App/PrivacyProtectionView.swift, App/PersonalLocationShareHost.swift (approvals stay nil), App/NativeAudioLifecycleObservation.swift, Core/PlayExperienceCoordinator.swift, Core/PlayContentCompatibility.swift, Info.plist build settings (`UIBackgroundModes` = `location`; When-In-Use only, no Always key); docs/release/release-checklist.md, docs/release/e2e/
- Backend route: none new. `/api/play/nodes` (`compatibility`), `/api/play/arrive`, `/api/roam/checkin`, and server time from the session reads.
- Mini-program page: pages/play/index, pages/roam/index, pages/privacy/index, pages/shezhi/components/privacy-sheet
- Acceptance test: Unit tests cite `OWN-D-07`, `OWN-10.3`, `OWN-OPT-042` and `OWN-OPT-072`. On the Lane2 simulator with a GPX route, a running roam session keeps getting fixes after Home, and the blue indicator shows. Ending the session, exiting, or switching account stops updates within one callback. With no session, backgrounding never starts updates. `OWN-OPT-090`, `-091` and `-092` close on a dated report under docs/release/e2e/ plus a signed checklist.

| row | status | what is open |
|---|---|---|
| `OWN-D-07.a` | MISSING | `SessionBackgroundLocationTracker`: reference-counted per session key, and it stops only when the count reaches 0, as in `mp:utils/location/bg-tracker.js:1-13`. It sets `allowsBackgroundLocationUpdates` and `showsBackgroundLocationIndicator` only while held. Add `UIBackgroundModes: location`. Permission stays When-In-Use. |
| `OWN-D-07.b` | MISSING | The play session holds the tracker from start to finish or exit (`mp:pages/play/index.js:10`). |
| `OWN-D-07.c` | MISSING | The roam live session holds the tracker (`mp:pages/roam/index.js:99`, `App/RoamLiveSessionView.swift`). |
| `OWN-D-07.d` | MISSING | Stop rules: finish, exit, leaving the page or switching account releases the hold. Going to the background does not (bg-tracker header comment). Unit test with a fake `CLLocationManager`. |
| `OWN-D-07.e` | MISSING | The privacy page shows which purposes hold location now, with a revoke action (`mp:pages/privacy/index.js:396`, `mp:pages/shezhi/components/privacy-sheet/index.js:12`). |
| `OWN-D-07.f` | MISSING | No location sharing: a test that the `PersonalLocationShareHost` read, write and capture approvals stay nil in production composition (`App/PersonalLocationShareHost.swift:6-12`). This closes the native side of `OWN-OPT-052`. |
| `OWN-OPT-042.a` | MISSING | Audio interruption: after a call or alarm, resume only audio that was playing before. Never auto-resume on return from background (mini-program PR #13 MP-02). Test on `App/NativeAudioLifecycleObservation.swift`. |
| `OWN-OPT-042.b` | MISSING | On foreground after lock or a call, the countdown re-syncs with the server session time, not the local clock. |
| `OWN-OPT-042.c` | MISSING | A late response after leaving play or switching session does not overwrite the new session (epoch guard). Test in `Core/PlayExperienceCoordinator.swift`. |
| `OWN-10.3.a` | MISSING | Test citing `OWN-10.3`: `PlayContentCompatibility.Verdict.unconfirmed` (no or malformed declaration) does not block starting a session (`mp:pages/play/index.js:4431` plays with no declaration). |
| `OWN-10.3.b` | MISSING | Test: `.unsupported(missing)` blocks starting only that content and shows the missing keys as the reason. It never says "degraded to an alternative" (there is no `availableFallback`). |
| `OWN-10.3.c` | MISSING | `content-schema.v1.json` stays a test resource. An absence check finds no runtime schema loader and no "validated by schema" copy. `outcomeRules.pass/fail` feedback round-trips in `ContentContractV1Tests`. |
| `OWN-OPT-072` | MISSING | An unknown-result or server-error state shows a copyable, non-sensitive request reference (requestId or server trace id, no token or PII). Native has this only in the AI flows (`Core/PublishingAIDraftFlow.swift`). |
| `OWN-OPT-091` | MISSING | Real-device matrix for native: lock screen, call, low GPS accuracy, denied location and camera, background location (D-07), and audio interruption. Each item gets a result: supported, unsupported or degraded. The report goes under docs/release/e2e/. |
| `OWN-OPT-090` | MISSING | Multi-identity E2E rerun (player, creator, club owner 9003, merchant 9002) after WP-01…WP-11, based on `E2E-20261113b`. Record HTTP, business code and identity scope separately. |
| `OWN-OPT-092` | MISSING | Release-candidate sign-off in layers on `docs/release/release-checklist.md`: code, PR, merge, TestFlight build, real-entry readback. The candidate SHA must equal the tested SHA. Production money stays a separate owner sign-off. |

## CL-01

**OPT close-out: ALREADY-DONE citation tests and DROP absence checks** — 22 rows.

- Native files to touch: new Tests/CoreTests/OPTTriageClosureTests.swift (one test per id, each asserting the evidence named below still exists), plus absence-check greps written into the matrix rows
- Backend route: none
- Mini-program page: none (evidence only)
- Acceptance test: `OPTTriageClosureTests` cites every ALREADY-DONE id below and asserts that its cited type or route constant exists. The evaluator re-runs, and each DROP row turns DONE by a reproducible absence check (the §12 ban rule in `completeness-matrix.md`), with the grep written in the row. `Core/UnifiedOPT*` and `App/UnifiedOPT*SectionView.swift` are excluded from the greps because they are contract records.

| row | status | what is open |
|---|---|---|
| `OWN-OPT-001` | MISSING | ALREADY-DONE. Add a citation test. Evidence: `completeness-matrix.md` §Sources read pins the SHAs and TEST 8120. |
| `OWN-OPT-003` | MISSING | ALREADY-DONE. Add a citation test. Evidence: `SUPPLEMENT.md` §Refresh 3 NX-01 table. |
| `OWN-OPT-070` | MISSING | ALREADY-DONE. Add a citation test. Evidence: `Tests/CoreTests/ContentContractV1Tests.swift:282`, `Core/PlayExperienceService.swift:366`. |
| `OWN-OPT-071` | MISSING | ALREADY-DONE. Add a citation test. Evidence: `App/ReviewedAreaSwitch.swift:78`, `Core/ChinaReviewedRouteCapability.swift:2413`. |
| `OWN-OPT-012` | MISSING | ALREADY-DONE. Add a citation test. Evidence: `/api/registration/cancel-refund` in `Core/OrderLifecycleCoordinator.swift`. |
| `OWN-OPT-013` | MISSING | ALREADY-DONE. Add a citation test. Evidence: `App/MerchantSettlementProgressView.swift:51`, `App/MerchantBusinessViews.swift:295`. |
| `OWN-OPT-061` | MISSING | ALREADY-DONE. Add a citation test. Evidence: `App/MerchantHomeView.swift:216`, `App/MerchantPredictionInboxView.swift:165`. |
| `OWN-OPT-020` | MISSING | ALREADY-DONE. Add a citation test. Evidence: `App/AppCompositionRoot.swift:2574` (`/api/v1/community`). |
| `OWN-OPT-021` | MISSING | ALREADY-DONE. Add a citation test. Evidence: `Core/SquareGovernanceService.swift:87,92`. |
| `OWN-OPT-030` | MISSING | ALREADY-DONE. Add a citation test. Evidence: `App/ProjectEditView.swift:269`. |
| `OWN-OPT-031` | MISSING | ALREADY-DONE. Add a citation test. Evidence: fabu page DONE; ending is server-only (WP-10 `OWN-D-04`). |
| `OWN-OPT-033` | MISSING | ALREADY-DONE. Add a citation test. Evidence: `App/WalletCommerceViews.swift:71`, `OWN-十六-09` DONE. |
| `OWN-OPT-040` | MISSING | ALREADY-DONE. Add a citation test. Evidence: `Core/PlayExperienceService.swift:303,385-409`, `Core/PlayExperienceCoordinator.swift`. |
| `OWN-OPT-041` | MISSING | ALREADY-DONE. Add a citation test. Evidence: `Core/PlayExperienceService.swift:19-25`. |
| `OWN-OPT-051` | MISSING | ALREADY-DONE. Add a citation test. Evidence: `App/OfficialOrganizerConsoleView.swift:3`, `App/OfficialEventDetailView.swift:68`. |
| `OWN-OPT-053` | MISSING | ALREADY-DONE. Add a citation test. Evidence: `App/ClubOpsNotifySections.swift:3`, `App/OfficialPrivateViews.swift:20`. |
| `OWN-OPT-080` | MISSING | ALREADY-DONE. Add a citation test. Evidence: `Core/PublishingAuxiliaryService.swift:33`. The no-mock test is WP-10 D-08.a. |
| `OWN-OPT-081` | MISSING | ALREADY-DONE. Add a citation test. Evidence: `Core/NPCChatLogDeletion.swift:20`, `Core/NPCChatData.swift:55`. |
| `OWN-OPT-002` | MISSING | DROP. Close as not native: the 509-lead review is backend and mini-program triage. Native register: `docs/release/cb70-gap-register.md`. |
| `OWN-OPT-011` | MISSING | DROP. Absence check: `grep -rnE '"/?api/cart/(add|settlement|submit)' App Core` finds no live call site outside the refusal list (`Core/WalletCommerceSafety.swift:323`). The mini-program has no `/api/cart`. |
| `OWN-OPT-023` | MISSING | DROP. Content-chain migration is backend work. WP-10 `OWN-D-03.b` is the client guard. |
| `OWN-OPT-050` | MISSING | DROP. Same absence check as WP-10 `OWN-D-02`. |

`OWN-OPT-052` (DROP) closes with WP-11 `OWN-D-07.f`, so it is not repeated here.

## CL-02

**Condition packages, D-09 and roll-ups close-out** — 16 rows.

- Native files to touch: new Tests/CoreTests/ConditionPackageClosureTests.swift; the roll-up rule in the evaluator (`completeness-matrix.md` §Status rules)
- Backend route: none
- Mini-program page: none (evidence only)
- Acceptance test: `ConditionPackageClosureTests` cites `OWN-EXT-04`, `-05`, `-06` and `OWN-D-09` and asserts the kept parts exist. The seven DROP rows close through absence checks written in the matrix. The evaluator applies rule CL-02.R, then re-computes the five roll-ups after WP-07, WP-08 and WP-09.

| row | status | what is open |
|---|---|---|
| `OWN-D-09` | MISSING | Citation test. Native scope = mini-program `app.json` minus WeChat-only. Flutter is absent (EXT-10 is already DONE by absence). |
| `OWN-EXT-01` | MISSING | DROP. Absence check: no role-room or host-transfer type (`grep -rnE 'RoleRoom|HostTransfer|hostAuthority' App Core` = 0). Evidence: `mp:pages/publish/temp/r5-editor.js:7`. |
| `OWN-EXT-02` | MISSING | DROP. Absence check: no offline map tile store (`grep -rnE 'MKTileOverlay|offlineMap|OfflineMapPack' App Core` = 0). |
| `OWN-EXT-03` | MISSING | DROP. Absence check: no stored value or member card (`grep -rnE 'storedValue|StoredValue|储值' App Core` = 0). Evidence: `mp:utils/discover-store-card.js:4`. |
| `OWN-EXT-04` | MISSING | Keep the single-buyer gift (ALREADY-DONE: `App/PassMarketViews.swift:151`), with a citation test. Crowdfunding is dropped: `grep -rnE 'crowdfund|众筹' App Core` = 0. |
| `OWN-EXT-05` | MISSING | Keep the signed referral token (ALREADY-DONE: `Core/JourneyLoopSource.swift:518`), with a citation test. No multi-level distribution, and attribution is never read from a query parameter. |
| `OWN-EXT-06` | MISSING | Keep the pass library, pricing and author revenue (ALREADY-DONE: `App/PassMembershipViews.swift:64`, `App/PublisherLifecycleViews.swift:24`), with a citation test. Derivative licensing is dropped. Workshop paid install stays in WP-05. |
| `OWN-EXT-07` | MISSING | DROP. Closes with WP-10 `OWN-D-08.c`. |
| `OWN-EXT-08` | MISSING | DROP. Absence check: no embedded script engine (`grep -rnE 'JSContext|WKWebView.*engine|import JavaScriptCore' App Core` = 0 outside legal and web pages). |
| `OWN-EXT-09` | MISSING | DROP. Absence check: no point expiry (`grep -rnE 'pointsExpire|expiringPoints|积分.*过期' App Core` = 0). |
| `OWN-EXT-11` | MISSING | DROP. Absence check: no external API client or CRDT (`grep -rnE 'CRDT|Automerge|openapi/' App Core` = 0). |
| `OWN-22.1` | MISSING | Roll-up. Closes when WP-07 (十六, 十七), WP-08 (十八, 20.1, 20.2) and WP-09 (21.1, 21.2) close, under CL-02.R. |
| `OWN-22.2` | MISSING | Roll-up of 22.1. |
| `OWN-十三` | MISSING | Roll-up. Closes when WP-09 (十三-02, -03), WP-07 (-08, -09) and WP-08 (-10, -11) close, under CL-02.R. |
| `OWN-十一` | MISSING | Roll-up of 十三. |
| `OWN-十四` | MISSING | Roll-up of 十三. |

**CL-02.R (evaluator rule, PROPOSED).** For roll-ups, a child that is `IN-PROGRESS (production off)` counts as satisfied. That status means the call site and the route exist, and only `forcedOff` / `ReleaseMoneyWriteSwitch` keeps them off on purpose. A child that is `screen/code on …, not finished` does not count. Without this rule, 22.1 and 十三 can never close while 十六-12 (host tip) and 十六-13 (OTA code) stay off in production on purpose.
