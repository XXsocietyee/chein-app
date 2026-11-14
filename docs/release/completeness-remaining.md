# Completeness Remaining Work Packages (refresh 4)

Base: `origin/ui/main` `3ac970ec2` × hengyin `integration/backend-app-r2` `5c2017eef`.

Every row in `docs/release/completeness-matrix.csv` whose status is not `DONE` or `PENDING-MERGE` is listed below (`11` rows total out of `1247`, after closing `RM-02` 10/10 rows on `ui/h-rm-02`):

| bucket | count |
|---|---:|
| `DONE` | 1236 |
| `PENDING-MERGE` | 0 |
| `IN-PROGRESS` | 11 |
| `MISSING` | 0 |
| **Remaining (`IN-PROGRESS` + `MISSING`)** | **11** |

The `11` remaining open rows are in **RM-01** (`RM-02`'s `10` rows are all `DONE` on `ui/h-rm-02` + hengyin `feature/rm-02-backoffice` `fc94317ce` bundled at `/tmp/rm-02.bundle`).

## Package list

- **RM-01** (11 rows, all `IN-PROGRESS`): Native page-map parity close-out (4 WP-03/04 pages) & `OWN-OPT-*` explicit citation tests (7 mapped rows).
- **RM-02** (10 rows — **CLOSED / DONE** on `ui/h-rm-02`): `API-/api/registration/pay`, `OWN-OPT-072`, `OWN-25.1`, `OWN-READ-全队共享提示-跳过-计时-团队总分`, `OWN-OPT-090..092`, and NX-02 Vue back-office `OWN-E`, `OWN-U03-04`, `OWN-UG-12`.

---

## RM-01 — Native page-map parity & OWN-OPT citation tests (11 rows)

All 11 rows already have underlying implementation and wired endpoints on `3ac970ec2` (`100%` of endpoints on the 4 pages are `DONE`, and all 7 `OWN-OPT-*` rows have their mapped WP-02/03/06/09 code landed). Closing `RM-01` requires finishing page-map parity (`partial`/`gated` → `exists` or documented `gated` sign-off with caller/read tests) and adding explicit `OWN-OPT-*` citation assertions in `Tests/CoreTests/OPTTriageClosureTests.swift` (or the corresponding WP test suites).

| # | requirement id | status | native screen / mapped WP | open gap on `3ac970ec2` |
|---:|---|---|---|---|
| 1 | `PAGE-pages/merchant/decor/index` | `IN-PROGRESS (screen on 3ac970ec2, not finished)` | App/MerchantOperationsViews.swift — 品牌中心 (门店装修与经营设置) | 3ac970ec2: App/MerchantOperationsViews.swift:30 (MerchantOpsWp03Panel(page: .decor)); page-map status=partial (helper-only home-state coverage; page APIs 15/15 DONE). Was: MISSING. |
| 2 | `PAGE-pages/merchant/decor/ai-npc/index` | `IN-PROGRESS (screen on 3ac970ec2, not finished)` | App/MerchantStoreCharacterView.swift — AI 店铺角色配置 | 3ac970ec2: App/MerchantStoreCharacterView.swift:36 (MerchantOpsWp03Panel(page: .npc)); page-map status=gated (voice/photo upload still gated; page APIs 13/13 DONE). Was: MISSING. |
| 3 | `PAGE-pages/merchant/relation/index` | `IN-PROGRESS (screen on 3ac970ec2, not finished)` | App/CoopRelationDiscoveryView.swift — 商家合作发现页 | 3ac970ec2: App/CoopRelationDiscoveryView.swift:109 (CreativeSquareAuthorDeleteSection); page-map status=partial (CoopRelationPostFeedFactory.make lacks production caller; page APIs 21/21 DONE). Was: MISSING. |
| 4 | `PAGE-pages/topic/merchantinfo/merchantinfo` | `IN-PROGRESS (screen on 3ac970ec2, not finished)` | App/MerchantContentViews.swift — 主题商家视角与章节承接 | 3ac970ec2: App/MerchantContentViews.swift:15,383 (MerchantOpsWp03Panel(page: .chapter)); page-map status=partial (no cited scope=MERCHANT read test; page APIs 52/52 DONE). Was: MISSING. |
| 5 | `OWN-OPT-014` | `IN-PROGRESS (code on 3ac970ec2, not finished)` | — | 3ac970ec2: mapped to WP-03/WP-06 (merchant coupon & invoice apply code/routes DONE on 3ac970ec2); explicit OWN-OPT-014 citation test in Tests/ missing; see docs/owner-handover/SUPPLEMENT.md:58-82 & docs/release/completeness-next.md. Was: MISSING. |
| 6 | `OWN-OPT-022` | `IN-PROGRESS (code on 3ac970ec2, not finished)` | — | 3ac970ec2: mapped to WP-02 (author club moderation/report code/routes DONE on 3ac970ec2); explicit OWN-OPT-022 citation test in Tests/ missing; see docs/owner-handover/SUPPLEMENT.md:58-82 & docs/release/completeness-next.md. Was: MISSING. |
| 7 | `OWN-OPT-032` | `IN-PROGRESS (code on 3ac970ec2, not finished)` | — | 3ac970ec2: mapped to WP-09 (gameplay preset/team after-sale code/routes DONE on 3ac970ec2); explicit OWN-OPT-032 citation test in Tests/ missing; see docs/owner-handover/SUPPLEMENT.md:58-82 & docs/release/completeness-next.md. Was: MISSING. |
| 8 | `OWN-OPT-043` | `IN-PROGRESS (code on 3ac970ec2, not finished)` | — | 3ac970ec2: mapped to WP-06 (stamp-album/stamp-camera/citystamp/history code/routes DONE on 3ac970ec2); explicit OWN-OPT-043 citation test in Tests/ missing; see docs/owner-handover/SUPPLEMENT.md:58-82 & docs/release/completeness-next.md. Was: MISSING. |
| 9 | `OWN-OPT-060` | `IN-PROGRESS (code on 3ac970ec2, not finished)` | — | 3ac970ec2: mapped to WP-03 (merchant team/claims/commerce-order code/routes DONE on 3ac970ec2); explicit OWN-OPT-060 citation test in Tests/ missing; see docs/owner-handover/SUPPLEMENT.md:58-82 & docs/release/completeness-next.md. Was: MISSING. |
| 10 | `OWN-OPT-062` | `IN-PROGRESS (code on 3ac970ec2, not finished)` | — | 3ac970ec2: mapped to WP-03 (merchant chapter invite/revoke code/routes DONE on 3ac970ec2); explicit OWN-OPT-062 citation test in Tests/ missing; see docs/owner-handover/SUPPLEMENT.md:58-82 & docs/release/completeness-next.md. Was: MISSING. |
| 11 | `OWN-OPT-082` | `IN-PROGRESS (code on 3ac970ec2, not finished)` | — | 3ac970ec2: mapped to WP-06 (simple publish AI draft code/routes DONE on 3ac970ec2); explicit OWN-OPT-082 citation test in Tests/ missing; see docs/owner-handover/SUPPLEMENT.md:58-82 & docs/release/completeness-next.md. Was: MISSING. |

**Acceptance test (`RM-01`):**
1. In `docs/parity/page-map.csv`, verify the 4 pages (`pages/merchant/decor/index`, `pages/merchant/decor/ai-npc/index`, `pages/merchant/relation/index`, `pages/topic/merchantinfo/merchantinfo`) have production callers (`CoopRelationPostFeedFactory.make`), `scope=MERCHANT` read coverage (`topic/merchantinfo`), and voice/photo parity/gating tests so all 4 reach `status=exists` (and update `PAGE-map` checks via `python3 tools/check_page_map_gated.py` and `python3 tools/check_merchant_business.py`).
2. Add explicit citation tests for `OWN-OPT-014`, `OWN-OPT-022`, `OWN-OPT-032`, `OWN-OPT-043`, `OWN-OPT-060`, `OWN-OPT-062`, and `OWN-OPT-082` in `Tests/CoreTests/OPTTriageClosureTests.swift` linking each ID to its verified WP-02/03/06/09 implementation & tests; run the Swift Core/AppUnit suite (`swift test --filter OPTTriageClosureTests` + `WP03`/`WP04` unit tests) on an Xcode runner and confirm 0 failures.

---

## RM-02 — Runtime/release gates, RequestReference coverage & out-of-scope dependencies (10 rows)

Contains the remaining `4` `IN-PROGRESS` runtime/wiring gaps (`API-/api/registration/pay`, `OWN-OPT-072`, `OWN-25.1`, `OWN-READ-全队共享提示-跳过-计时-团队总分`), `3` `MISSING` release validation/TestFlight rows (`OWN-OPT-090..092`), and `3` `MISSING` hengyin Vue back-office rows (`OWN-E`, `OWN-U03-04`, `OWN-UG-12`, NX-02 out of native iOS scope).

| # | requirement id | status | native screen / module | open gap on `3ac970ec2` |
|---:|---|---|---|---|
| 1 | `API-/api/registration/pay` | `IN-PROGRESS (production off; TEST payment-readiness false)` | Core/RegistrationCheckoutPresentation.swift (call site) | 3ac970ec2: Core/OrderLifecycleDormantAdapter.swift:16; backend 5c2017eef ApiRegistrationController POST; grant=no:forced-off(virtual-goods); payment-readiness returns false on TEST so live E2E pay remains blocked. Was: BLOCKED (ui/wp-0105). |
| 2 | `OWN-OPT-072` | `IN-PROGRESS (code on 3ac970ec2, not finished)` | — | 3ac970ec2 (ui/wp-11 merged): Core/RequestReference.swift:9 + Core/AuthService.swift + App/RequestReferenceRow.swift:6 wired only on App/PlayExperienceView.swift:880 (/api/play/); non-play unknown-result/error surfaces still open per docs/release/receipts/wp-11.md. Was: IN-PROGRESS (code on ui/wp-11, Swift tests pending integrator run). |
| 3 | `OWN-25.1` | `IN-PROGRESS (code on 3ac970ec2, not finished)` | — | 3ac970ec2+5c2017eef: backend ApiPlayHelpController (/api/play/help/shared) served; native Core/PlayTeamBackpack.swift:89 (PlayCoopHelpFlow) + App/PlayTeamBackpackView.swift:196 (PlayCoopHelpSheet) + Tests/CoreTests/PlayGapPartialsTests.swift:119 + Tests/CoreTests/PlayRuntimeGapTests.swift:159 wired; shared team timer/total-score sync & explicit citation test remain open. Was: MISSING. |
| 4 | `OWN-READ-全队共享提示-跳过-计时-团队总分` | `IN-PROGRESS (code on 3ac970ec2, not finished)` | — | 3ac970ec2+5c2017eef: backend ApiPlayHelpController (/api/play/help/shared) served; native Core/PlayTeamBackpack.swift:89 (PlayCoopHelpFlow) + App/PlayTeamBackpackView.swift:196 (PlayCoopHelpSheet) + Tests/CoreTests/PlayGapPartialsTests.swift:119 + Tests/CoreTests/PlayRuntimeGapTests.swift:159 wired; shared team timer/total-score sync & explicit citation test remain open. Was: MISSING. |
| 5 | `OWN-OPT-090` | `MISSING` | — | 3ac970ec2: multi-identity E2E rerun not executed on 3ac970ec2; unmerged ui/h-e2e-flows (2295579ec) and ui/h-e2e-ids (25db611f6) hold Maestro flow/ID prep only. Was: MISSING. |
| 6 | `OWN-OPT-091` | `MISSING` | — | 3ac970ec2: real-device matrix requires physical iOS hardware (none available in automated simulator/headless environment). Was: MISSING. |
| 7 | `OWN-OPT-092` | `MISSING` | — | 3ac970ec2: layered release sign-off, TestFlight archive & readback open; unmerged ui/h-testflight-prep (2af67b58f) and ui/cur-appstore (4a28a6e4f) hold scripts/metadata only. Was: MISSING. |
| 8 | `OWN-E` | `MISSING` | — | 3ac970ec2: out-of-native-scope (hengyin Vue back-office admin console, NX-02). Was: MISSING. |
| 9 | `OWN-U03-04` | `MISSING` | — | 3ac970ec2: out-of-native-scope (hengyin Vue back-office admin console, NX-02). Was: MISSING. |
| 10 | `OWN-UG-12` | `MISSING` | — | 3ac970ec2: out-of-native-scope (hengyin Vue back-office admin console, NX-02). Was: MISSING. |

**Acceptance test (`RM-02`):**
1. `OWN-OPT-072`: mount `App/RequestReferenceRow.swift` on non-play unknown-result/error failure banners (`Core/RequestReference.swift` + `Core/AuthService.swift`) and assert non-play failure paths render `x-request-id` in an AppUnit/UI test.
2. `OWN-25.1` & `OWN-READ-全队共享提示-跳过-计时-团队总分`: extend `Core/PlayTeamBackpack.swift` (`PlayCoopHelpFlow`, `/api/play/help/shared`) + `App/PlayTeamBackpackView.swift` (`PlayCoopHelpSheet`) with shared team timer/total-score sync coverage and add explicit `OWN-25.1` assertions in `Tests/CoreTests/PlayRuntimeGapTests.swift` / `PlayGapPartialsTests.swift`.
3. `API-/api/registration/pay` & `OWN-OPT-090..092`: enable payment-readiness on TEST / verify virtual-goods gating decision, merge/run Maestro multi-identity E2E flows (`ui/h-e2e-flows` + `ui/h-e2e-ids`) on simulator (`OWN-OPT-090`), complete physical iPhone hardware pass (`OWN-OPT-091`), resolve `python3 tools/contract_ratchet.py`, and complete TestFlight archive + owner readback (`ui/h-testflight-prep` + `ui/cur-appstore`) (`OWN-OPT-092`).
4. `OWN-E`, `OWN-U03-04`, `OWN-UG-12`: verify hengyin Vue admin back-office routes against `integration/backend-app-r2` (`NX-02`; no native iOS code required).

---

## Unmerged branch audit (`PENDING-MERGE = 0`)

All 29 unmerged branches listed in the task were inspected against `origin/ui/main` (`3ac970ec2`). Note: `ui/cur-fixtures-4` (`ffa4129c4`) is already merged into `origin/ui/main`. None of the 29 unmerged branches modify `docs/parity/page-map.csv`, close `OWN-OPT-072` / `OWN-25.1` / the 7 `OWN-OPT-*` citation gaps, unblock `/api/registration/pay`, or execute the E2E/device/TestFlight sign-off runs:

| branch | tip SHA | merge-base | ahead | files | scope & why `PENDING-MERGE = 0` |
|---|---|---|---:|---:|---|
| `origin/ui/cur-fixtures-2` | `be7503e72` | `9209d33cb` | 2 | 5 | `#if DEBUG` UI fixtures only |
| `origin/ui/cur-fixtures-3` | `dc06e8886` | `9209d33cb` | 2 | 5 | `#if DEBUG` workshop/video UI fixtures only |
| `origin/ui/cur-fixtures-5` | `c50264f57` | `6feee423a` | 3 | 5 | `#if DEBUG` WP-06/09/10 fixtures only |
| `origin/ui/cur-fixtures-6` | `e18da8f48` | `3ac970ec2` | 7 | 57 | Combines `cur-errors`/`permissions`/`compliance`/`search` + DEBUG fixtures |
| `origin/ui/cur-tests` | `4ce602883` | `a2a9d82e7` | 1 | 8 | Stub transport tests for already-DONE Core requests |
| `origin/ui/cur-a11y` | `ea98e8405` | `a2a9d82e7` | 1 | 17 | VoiceOver, Dynamic Type & 44pt tap targets on DONE pages |
| `origin/ui/cur-visual-parity` | `d1d184938` | `9209d33cb` | 2 | 6 | Home & discovery copy/empty-state parity |
| `origin/ui/cur-visual-parity-2` | `dc783bd16` | `9209d33cb` | 1 | 13 | Topic/club/post/IM copy alignment |
| `origin/ui/cur-appstore` | `4a28a6e4f` | `9209d33cb` | 2 | 8 | App Store privacy/StoreKit/review prep docs (`OWN-OPT-092` remains unexecuted) |
| `origin/ui/cur-appearance` | `73d8e7c22` | `9209d33cb` | 1 | 8 | Dark mode & Dynamic Type CY token polish |
| `origin/ui/cur-push` | `85f5b3fe8` | `9209d33cb` | 1 | 7 | Push deep-link routing to DONE pages |
| `origin/ui/cur-analytics` | `875e274ee` | `9209d33cb` | 1 | 17 | Analytics event calls on DONE actions |
| `origin/ui/cur-errors` | `28ffaab46` | `6feee423a` | 1 | 9 | Localized backend error mapping (no `RequestReferenceRow` mount or `page-map` change) |
| `origin/ui/cur-permissions` | `8faf4e06f` | `6feee423a` | 1 | 11 | Permission pre-prompt & Settings link polish |
| `origin/ui/cur-compliance` | `6f78a9eef` | `6feee423a` | 1 | 21 | Compliance/account UI alignment |
| `origin/ui/cur-search` | `d5751e50a` | `6feee423a` | 1 | 13 | Search/discovery sort & filter alignment |
| `origin/ui/cur-copy` | `1571b5cb0` | `9209d33cb` | 1 | 10 | Simplified Chinese player copy alignment |
| `origin/ui/cur-states` | `10f205e70` | `9209d33cb` | 1 | 13 | Em-dash unknown display & retry polish |
| `origin/ui/cur-deeplinks-2` | `71ca5fbef` | `9209d33cb` | 1 | 8 | Deep-link table wiring to DONE native screens |
| `origin/ui/cur-perf` | `9e62e761f` | `3e2dca3ec` | 1 | 21 | Lazy lists, image downsampling & off-main JSON decode |
| `origin/ui/cur-uitests` | `cbc7c6a36` | `6feee423a` | 1 | 3 | Offline XCUITest golden paths for 13 journeys |
| `origin/ui/cur-uitests-2` | `515ce51db` | `3ac970ec2` | 1 | 5 | DEBUG fixture XCUITest paths |
| `origin/ui/h-offline` | `46497191b` | `6feee423a` | 1 | 22 | Package 63 offline idempotent queue + offline banners (`PKG-63-*` non-matrix rows) |
| `origin/ui/h-offline-2` | `d65e6f51` | `6feee423a` | 2 | 44 | Package 63b opt-in offline sync status (`h-offline` follow-up) |
| `origin/ui/h-sweep` | `a17d8f27d` | `6feee423a` | 1 | 19 | Pre-WP0105 Package 64 sweep (POI challenge, myproject mutations, `#if DEBUG` fixture host) |
| `origin/ui/h-sweep-2` | `1fa9c019a` | `6feee423a` | 2 | 34 | Pre-WP0105 Package 64b sweep; overlaps already-merged WP-01/02/05 routes |
| `origin/ui/h-testflight-prep` | `2af67b58f` | `3ac970ec2` | 1 | 8 | TestFlight archive/preflight scripts & runbook (`OWN-OPT-092` unexecuted) |
| `origin/ui/h-e2e-flows` | `2295579ec` | `3ac970ec2` | 1 | 26 | Prepared 18 Maestro flows, SMS bridge & runner (`OWN-OPT-090` unexecuted) |
| `ui/h-e2e-ids` (local) | `25db611f6` | `3ac970ec2` | 2 | 38 | Accessibility identifiers on top of `ui/h-e2e-flows` (`OWN-OPT-090` unexecuted) |
