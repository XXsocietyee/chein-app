# Sweep-2 Verification Receipt (`64b`)

- Branch: `ui/h-sweep-2` (based on `ui/h-sweep` `a17d8f27d`)
- Backend / mini-program reference: `hengyin integration/backend-app-r2` (`5c2017eef`), live TEST probe `https://8120-agqyfqxs5vwolymtoibzq3fhde.instabox.tech`

## Live TEST `8120` Probe
- `curl -s -X POST https://8120-agqyfqxs5vwolymtoibzq3fhde.instabox.tech/api/registration/payment-readiness`
  -> `{"msg":"登录状态已失效，请重新登录","code":401}` (route live and auth-enforcing).

## Row-by-Row Receipt (`row -> file:line -> test -> DONE/blocked reason`)

| Row / Surface | Implementation (`file:line`) | Verification / Test | Outcome |
|---|---|---|---|
| `OwnerDecisionFixtureHost` release guard | `App/OwnerDecisionFixtureHost.swift:1-48` | `python3 -m unittest Tests.ContractChecks.test_accessibility_hardening_wave` (30 tests OK) | `DONE` |
| `/api/registration/payment-readiness` | `Core/Sweep2Routes.swift:412`, `App/Sweep2Surfaces.swift:25`, `App/RegistrationSheetView.swift:592`, `Core/ChinaReviewedRouteCapability.swift:100,2569`, `App/ReviewedPlayerWriteLeases.swift:1536` | `Tests/CoreTests/Sweep2HttpClientTests.swift:30` + `Tests.ContractChecks.test_cb97_payment_gating` | `DONE` (money-gated via `ReviewedAreaSwitch.moneyPayments`: ON in TEST/DEBUG, closed on `www.chengyinhub.com`) |
| `/api/club/settlement/mine` | `Core/Sweep2Routes.swift:421`, `App/Sweep2Surfaces.swift:349`, `App/ClubGovernanceViews.swift:1443`, `App/ClubPayoutReceiverView.swift:65`, `Core/ChinaReviewedRouteCapability.swift:100,2572`, `App/ReviewedPlayerWriteLeases.swift:1542` | `Tests/CoreTests/Sweep2HttpClientTests.swift:49` + `Tests.ContractChecks.test_cb97_payment_gating` | `DONE` (payout-gated via `ReviewedAreaSwitch.payout`: ON in TEST/DEBUG, closed on `www.chengyinhub.com`) |
| `/api/audit/appeal`, `/api/audit/appeal/receipt` | `Core/Sweep2Routes.swift:451,464`, `App/Sweep2Surfaces.swift:110`, `App/CreatorContentViews.swift:120`, `Core/ChinaReviewedRouteCapability.swift:90-91`, `App/ReviewedPlayerWriteLeases.swift:1563-1579` | `Tests/CoreTests/Sweep2HttpClientTests.swift:69` + `Tests.ContractChecks.test_myproject_page_ready` | `DONE` |
| `/api/audit/guard/reference`, `/api/audit/guard/appeal`, `/api/audit/guard/appeal/receipt` | `Core/Sweep2Routes.swift:492,506,518`, `App/Sweep2Surfaces.swift:553,667`, `App/PlayGapMiscSurfaces.swift:16`, `Core/ChinaReviewedRouteCapability.swift:92-94`, `App/ReviewedPlayerWriteLeases.swift:1580-1603` | `Tests/CoreTests/Sweep2HttpClientTests.swift:106` | `DONE` |
| `/api/club-compensation/editions/empty-reason` | `Core/Sweep2Routes.swift:542`, `App/Sweep2Surfaces.swift:290`, `App/ClubGovernanceViews.swift:1592`, `Core/ChinaReviewedRouteCapability.swift:95`, `App/ReviewedPlayerWriteLeases.swift:1549` | `Tests/CoreTests/Sweep2HttpClientTests.swift:133` | `DONE` |
| `/api/club/lead/release-station`, `/api/club/lead/unlock-chapter-receipt` | `Core/Sweep2Routes.swift:553,563`, `App/Sweep2Surfaces.swift:463`, `App/PlayExperienceView.swift:932`, `Core/ChinaReviewedRouteCapability.swift:98-99`, `App/ReviewedPlayerWriteLeases.swift:1554-1562` | `Tests/CoreTests/Sweep2HttpClientTests.swift:142` | `DONE` |
| `/api/club-direct-merchant/club`, `/api/club-direct-merchant/merchant` | `Core/Sweep2Routes.swift:590`, `App/Sweep2Surfaces.swift:403`, `App/ClubGovernanceViews.swift:1444`, `App/MerchantHomeView.swift:359`, `Core/ChinaReviewedRouteCapability.swift:96-97`, `App/ReviewedPlayerWriteLeases.swift:1604-1611` | `Tests/CoreTests/Sweep2HttpClientTests.swift:159` + `Tests.ContractChecks.test_club_ops_customer` | `DONE` |
| `/api/club/personal-receiver/*`, `/api/merchant/payout-account`, `/api/merchant/*` WP-03, `/api/coop/invite/*`, `/api/coop/supply-stations`, `/api/creativesquare/delete`, `/api/im/*` | Already implemented & wired (`ClubPayoutReceiverView.swift:5`, `MerchantPayoutAccountView.swift:5`, `MerchantOpsWp03Panel.swift:5`, `CooperationFlowService.swift`, `SocialActionContracts.swift:198`, `AppSession.swift:2604`) | Existing tests (`WP04CoopSquareDeleteTests.swift`, `ReviewedPlayerWriteLeases.swift:8,1462`) | `DONE` (`personal-receiver/bind` uses mini-program handoff per `SUPPLEMENT.md` `OWN-D-05`) |
| `SettingsPrivacyLocationView.swift:45` (`presence.off`) | `App/ReviewedPlayerWriteLeases.swift:56` | `Tests/ContractChecks/test_player_write_grant.py:35,45` | `LOCKED` (`SUPPLEMENT.md` `OWN-D-07` `OPT-052`) |
| `MerchantStoreCharacterView.swift:522` (`aiNPC.voice.hold`) | `App/MerchantStoreCharacterView.swift:522` | `Tests/ContractChecks/test_w2_19_aiNPC.py:59-75` | `LOCKED` (preset sample mode active) |
| `SquarePostVideoViews.swift:159`, `SquareDeletionViews.swift:5`, `StoryRuleEditorView.swift:433,576`, `CooperationFlowEditors.swift:24`, `OrderLifecycleView.swift:332`, `FreeExploreCancelFactory.swift:8`, `Bundle*`, `MapCoreEntryHostRouter.swift:40-54` | `docs/release/sweep.md` §3 | `SquarePostVideoChainTests.swift:47`, `test_w2_07_square_parity.py`, `BNDMountGuardTests.swift`, `MapCoreEntryHostRouterTests.swift`, `5c2017eef` | `LOCKED / NO BACKEND / EXCLUDED` (see `docs/release/sweep.md` §3 & `SUPPLEMENT.md` `OWN-D-07`, `OWN-D-09`) |
| `/api/template/report-receipt`, `/api/getwxbindphone` | `Core/TemplateContentReportContracts.swift:11`, `ApiLoginController.java:322` | `5c2017eef` grep & controller inspection | `EXCLUDED` (`report-receipt` 404 on backend; `getwxbindphone` WeChat-only per `OWN-D-09`) |

## Gate Results on Final Files
- `python3 tools/generate_project.py`: PASS (`3618` native sources, `214` catalogs, `808` app-unit sources).
- `xcrun swiftc -parse` on all 14 new/modified Swift files: PASS (`exit 0`).
- `python3 tools/check_scaffold.py`: PASS (`4755` Swift source files, `16542` bilingual keys, `missing: 0`, `appsession ratchet` `4171 < 4184`).
- `python3 tools/check_design_lint.py`: PASS (`1625` App Swift files, zero new violations).
- Contract tests (`test_allowlist_routes_have_backend`, `test_cb97_payment_gating`, `test_player_write_grant`, `test_club_ops_customer`, `test_accessibility_hardening_wave`, `test_myproject_page_ready`, `test_w2_07_square_parity`, `test_w2_19_aiNPC`, `test_play_experience_contracts`, `test_play_gameplay_mode_separation`, `test_club_governance_contracts`, `test_club_story_runtime_boundary`): PASS.
- Load rule compliance: `xcodebuild`, `swift build`, and `swift test` were NOT run on this Mac (left for the integrator).
