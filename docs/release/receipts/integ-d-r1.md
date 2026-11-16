# ui/h-integ-d-r1 · design r1 + acceptance fixes integration receipt (2026-11-16)

Base `origin/ui/main` 15205f9bc. Merged in order, no squash, each as a `--no-ff` merge commit:

| # | branch | tip | merge commit |
|---|---|---|---|
| 1 | `ui/h-acceptance-a5` (scan check-in sends nodeId) | 8b27c6544 | d8615000a |
| 2 | `ui/h-acceptance-r2` (F-01..F-18) | bcd955baf | 2b4c38ae1 |
| 3 | `ui/d-r1-foundation-player` (shared kit + player pages) | 26c401ddc | 1010d35c5 |
| 4 | `ui/d-r1-config` (Editor kit, topic editor, gameplay config, publish) | 1f125ffc4 | 3588fd567 |
| 5 | `ui/d-r1-club-merchant` (club, member, merchant, creator) | 51a784d1e | 1aaaab431 |

Mac only: Xcode 27, simulator Questify-iPhone17-Lane2 (2337B386), arm64 (`ONLY_ACTIVE_ARCH=YES`), indexing off, one
DerivedData (`Questify-integ-d-r1`), every build and simulator session under `lockf /private/tmp/design-build.lock`.

## Merge conflicts and resolution

| file | sides | resolution |
|---|---|---|
| `App/ClubActionPanel.swift` | acceptance-r2 F-08 moved the panel's lifecycle (`onChange`/`onDisappear` → `reset()`) from the Section onto the section header, and the confirmation `.sheet` onto the tapped membership row (Section modifiers apply to every row; the transient 处理中 row's `onDisappear` cancelled the confirmation). design r1 MC-20 added `.pageEnd` placement (退出 / 举报 rows at the end of 概览) and kept the old Section-level sheet + lifecycle on a wrapping `Group`. | Both kept. Header placement keeps the F-08 structure exactly. The page-end placement is a single-row Section, so the same `confirmationPresented` sheet and the same lifecycle sit on that one row (`ClubPageEndActions`). The two placements are exclusive branches of one panel instance, so each instance still has one presenter. |
| `Tests/ContractChecks/test_acceptance_r2_club_chat.py` | F-08 contract asserted exactly one `.sheet(` in the file | Deliberate update: two (one per placement); the contract also asserts the page-end presenter and lifecycle sit on the page-end row and that it has no progress row. |
| `Questify.xcodeproj/project.pbxproj` (2 merges) | each branch registered new string catalogs and test files | Union: `DesignR1.xcstrings`, `EditorKit.xcstrings`, `DesignR1Club.xcstrings`, `DesignR1Merchant.xcstrings`, `DesignR1FoundationTests`, `DesignR1ClubKitTests`, `DesignR1MerchantKitTests` (file refs, build files, group and phase entries). `plutil -lint` OK. |
| `QuestifyAppUnitTests-Shard02/03/04.xctestplan` | skip lists | Union of the skip lists, so each new test class still runs in exactly one shard. |

Auto-merged files that both an acceptance and a design branch touched (`PlayExperienceView`, `RegistrationSheetView`,
`MerchantPayoutAccountView`) were checked line by line: every line either branch added is present.

## HANDOFF-R1 stand-ins replaced (7d58fa6bf)

All nine `// HANDOFF-R1: replace with DS component …` stand-ins are gone and their types deleted:

| stand-in | replaced by |
|---|---|
| `ClubR1PillButtonStyle` | `CYPillButtonStyle(.secondary)`; destructive → `CYDestructiveButtonStyle(isFullWidth:, isPill: true)` |
| `ClubR1StatusTag` / `ClubR1Status` tone+icon | `CYStatusTag(verbatim:state:)`; `ClubR1Status.tagState` maps 进行中→live, 待处理→warning, 已结束→neutral, 未通过→failed |
| `ClubR1SheetHeader` + `clubR1Sheet`/`ClubR1SheetStyle`/`ClubR1SheetSize` | `CYResizableSheet(kind: .pickerLong, title:)` (consequence sheet, city picker) |
| `MerchantR1ButtonStyle` | `CYPillButtonStyle(.secondary)` |
| `MerchantR1StatusTag` / `MerchantR1Status` tone+icon | `CYStatusTagState` mapping (`tagState`); the unused tag view is deleted |
| `MerchantR1Chip` | deleted (no call site) |
| `EditorKitPillButtonStyle` | `.editorPrimary` / `.editorSecondary` now return `CYPillButtonStyle` |
| `EditorSheetHost` (local detent engine) | rebuilt on the shared engine: `CYSheetSize` (from the Core family table), `CYResizableSheet.fitHeight` / `.scrollEnabled`, `CYSheetMetrics.fitCap`, `CYMotion.sheetDetent`, settle-only `.selection` haptic. It keeps its `NavigationStack` root because editor sub-pages push inside the sheet (CF-12) and `CYResizableSheet` owns its own header and scroll view. |

Shared kit change: `CYStatusTagState` gains `.failed` (danger, `xmark.octagon`) for 未通过 / failed; icons stay unique.
`test_design_r1_club_merchant_kits.py` now asserts that the stand-ins are gone, not that they are marked.

## Build

`build_sim`, scheme Questify, Debug, Lane2, `OTHER_SWIFT_FLAGS=$(inherited) -disable-sandbox`: **BUILD SUCCEEDED on the
first build of the merged tree, 0 errors.** Branches 3–5 were written without a compiler; no compile fix was needed.
The app also built inside every AppUnit `test_sim` run and in `build_run_sim`.

## Gates

| gate | result |
|---|---|
| `python3 -B tools/check_scaffold.py` | PASS (4893 Swift files, 16727 bilingual keys, project equivalence) |
| `tools/check_design_lint.py` | PASS (0 violations) |
| `tools/check_a11y.py`, `tools/check_missing_string_keys.py` | PASS / 0 missing |
| `python3 -B tools/contract_ratchet.py --check` | 185 failing, baseline 184, **1 "new": `test_workshop_paid_professional…test_current_generic_draft_cas_reuses_real_reader_with_bounded_paging`. This one is already red on `ui/main`, not caused by this merge.** Neither its source (`Core/WorkshopPaidProfessionalPreparation.swift`) nor the test differs from `ui/main`; test-burndown 6009e19f3 replaced the `"TOPIC"` literal the test pins with `WorkshopPaidInstallTarget.businessTypeValue`. It is left for its owner (workshop paid flow). |

## Tests

### Core (`swift test --disable-sandbox`)

| tree | tests | unique failing |
|---|---:|---:|
| `ui/main` (test-burndown batch 2 receipt) | 16926 | 27 |
| `ui/h-integ-d-r1` first run | 16969 | 29 |
| after a6d5f1654 | 16969 | **27** (the two below fixed; their classes re-run green: 69/69) |

The two failures came from deliberate merged changes, so the tests were updated:
- `PlayArriveAccuracyContractTests.testScanCompletionCarriesNoLocationMetadata`: A5 makes scan check-in always send
  the reviewed `nodeId` (the backend scopes every checkin by it). The test forbade `nodeId`. It now forbids only
  location metadata and asserts `nodeId=701` is sent.
- `OPTTriageClosureTests.testCartCallSiteAbsenceCitesOWNOPT011`: acceptance-r2 F-14 inserted two lines in
  `ChinaReviewedRouteCapability.swift`, so the cart call-site pins moved 817→819 and 2636→2638 (same lines, same content).

### AppUnit (4 shards, XcodeBuildMCP `test_sim`, Lane2)

Baseline names come from the test-burndown batch-2 result bundles on this Mac (DES-ag9, 2026-11-16 05:30–05:34Z,
7+16+26+24 = 73).

| shard | baseline tests / failing | integ tests / failing | new vs baseline |
|---|---|---|---|
| 1 | 1837 / 7 | 1855 / 6 | 0 |
| 2 | 1964 / 16 | 1966 / 15 | 0 |
| 3 | 2031 / 26 | 2057 / 29 | 3 × `OwnAccountRefreshOrderingTests` "Crash: Questify" (see below) |
| 4 | 2016 / 24 | 2018 / 24 | 0 |
| total | 7848 / 73 | 7896 / 74 | 0 real |

- The three shard-3 entries are the known runtime abort in `OwnAccountRefreshOrderingTests` ("freed pointer was not
  the last allocation", recorded as open in the test-burndown receipt). Re-running the class alone: the three pass, and
  a different method (`testOlderSameRoleResponseCannotOverwriteNewerNickname`) crashes instead. Nothing in this
  branch touches that class or its code.
- Two baseline failures now pass: `RoamNearbyOwnedStateRecoveryTests.testActualOriginalJoinedDetailPush…` and
  `RoamAnniversaryReadIntentTests.testActualReplacementReaderRetiresOldHeldResponse…` (hosted-AX family, flaky).
- All new tests pass: `DesignR1FoundationTests`, `DesignR1ClubKitTests`, `DesignR1MerchantKitTests`, the
  `AcceptanceR2*` app tests.
- No money, security or deletion test was changed.

## Screenshots (Lane2, kept local, not committed)

`/Users/fanning/chengyin-refs/integ-d-r1-shots/` with contact sheet `index.md`. 25 PNGs: welcome; the 5 tab roots
(TEST backend, signed-in player); live roam; topic detail; activity detail; ticket/registration sheet; lobby
hold-to-start; topic editor (路线编辑器); gameplay config editor (信息 + 玩法 sections); 发布活动 (TEST and fixture);
创建俱乐部 step 1 cards and step 2 direction chips (fixture), plus the TEST create-limit state; club detail and 概览 page
end (TEST); club members (fixture), plus the TEST members load failure; merchant workbench; merchant onboarding step 4
(预览确认).

Findings from the screenshots, for the coordinator:
- The club tab's top tabs read "Posts / Clubs" in English in the zh UI (04).
- 创建者 role chips are blue on the club list and member list (04, 17). MC-35 says blue is not used for status or tags.
- On TEST, club 7003 查看成员 shows "俱乐部加载失败" and retry fails too (17b), so the member ⋯ menu (MC-20) could not be
  captured with live data. The fixture viewer has no governance, so it shows no menu either. Not investigated here.
- On TEST, 发布 → 我的项目 says "列表没加载出来。网络没连上" (the topic editor screenshot uses the fixture).
- The MC-25 roster card is built but, per design-r1-C, not wired into any screen yet.

## Left

- `ui/main` not fast-forwarded (coordinator reviews the screenshots first).
- The ratchet's workshop pin and the `OwnAccountRefreshOrderingTests` runtime abort are pre-existing and left to their owners.
- The four screenshot findings above.
