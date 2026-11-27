# debt-r3 receipt (round 3, 2026-11-27): contract ratchet 104 -> 54

Branch `debt/r3-contracts` from `origin/ui/combined-r7`. Brief: `docs/briefs/round3-1127.md` row `debt-r3`
(origin/design/handoff-r2). Static Python checks only; no Swift compile / XCTest in the cloud.

## Counts

- Before: baseline 104 rows (`docs/release/contract-failing-baseline.txt`).
- After: `contract ratchet: 54 failing, baseline 54, new 0, fixed 0` (50 rows cleared; no row added). Target <= 60 met.
- `python3 tools/generate_project.py` -> no project diff; `python3 tools/check_scaffold.py` -> PASS;
  `python3 -B tools/check_a11y_lint.py` -> PASS (0 new).

## Why most rows failed

Almost every non-merchant row was a change-scope proof of a historical patch: it rebuilt a frozen snapshot of the
repo through the club admission chain (`tools/club_customer_directory_admission.py` `_CLUB_E2B_SHA256`, run138
projections) or a byte-exact inverse of the original hunks, and failed first on
`Changed actual club product: .github/workflows/native-ios.yml` / `Unknown current feature-batch source`. These can
only pass on an unchanged repo, so they say nothing about current behavior. Each retired method is listed in a
`# Retired by debt-r3` comment block in its file with a one-line reason; every forward/behavior check in the same
module was kept and now runs on the live tree.

## Fixed (50 rows)

(a) = stale pin updated with a one-line reason, (b) = rewritten to read the live tree, (c) = obsolete proof retired,
(d) = real defect / product decision fixed (MP-first).

| Module | Rows | Action |
|---|---|---|
| `test_profile_read_failure_remote_admission` | 25 (one subtest row) | (a) `test_public_discovery_includes_all_thirteen_raw_checks`: 13 -> 11 raw checks and checker sha re-pinned (94c74f65b deleted two byte-provenance checks). (a) `test_raw_positive_gates_do_not_depend_on_historical_projection`: 20 -> 18, same reason; the raw `ProfileReadFailureContracts` + `MerchantDecorTagPickerContracts` suites still run with every historical inverse forbidden. (c) 21 admission-chain methods retired (whole classes `CompileRepairCombinedAdmission` ... kept where they still had passing drift/mutation checks). Module: 26 tests OK. |
| `test_project_editor_readiness` | 13 (subtest rows) | (c) byte inverse of 9 UI-test/pbxproj files + protected whole-file hashes (workflow, helpers, budget) via the run138 projection retired; the vacuous mutation test (inverse raises on any input) retired with them. Kept: form-bounded name reveal, max-type launch, fixture chrome, gesture geometry. |
| `test_run129_project_editor_repairs` | 5 | (b) `source()` reads the live file instead of the club-chain pre-receipt projection: ack reveal-before-existence and tap postconditions pass on current UI tests. (a) `FailureScreenshot.swift` sha re-pinned (old pin predated the 02c68098f import; 812314637 only appended `tapEditorMenuItem`). (c) two byte-exact whole-journey comparisons against frozen run129 originals retired. |
| `unittest.loader._FailedTest.test_roam_route_replay` | 1 | (b) dropped `load_tests` (redirected 4 methods to a frozen historical module, crashed at import). (a) detail markers re-pinned: 8cdcd1850 (P8 medals) also clears `selectedMedal` on the same read-key change, 03033d614 `cySheet` + `Group`; share privacy check now pins `silhouette: includeRoute ? sketch.track` (route off by default). (c) source inverses / prefix hash / catalog inverse retired; new forward `test_replay_keys_ship_bilingual` (7 keys, en + zh-Hans). Whole-file pins of store/reader/share replaced by "no replay in store/reader/share". `SOURCE_INVERSES` data kept because `test_category_roam_registration` imports it. |
| `test_run138_ui52_driver` | 5 | (c) byte inverses of `MerchantMarketingUITests.swift` / `ProjectStoryImageFlowTests.swift` and the club-chain protected-bytes check retired, plus 3 vacuous mutation tests. (b) story barrier check rewritten on the live file (second apply only, Chapter BackButton hittable, `replacementDismissed` once). Test-only module; no merchant feature code touched. |
| `test_ci138_version_row_source` | 1 | (d) Product call answered from the MP: `pages/publish/fabu/index.js` keeps `baseRevision` as hidden save state and no `.wxml` renders it. So the native editor shows no version row (it is not mounted; `draft.baseRevision` still travels with the save). `Tests/AppUITests/ProjectOwnedEditorFlowTests.swift` `assertMode` no longer waits for `projectRemote.version.value` (it now asserts it is absent; this journey would have failed on a simulator). Contract rewritten with mutation controls; `tools/tests/test_project_remote_version_accessibility.py` UI-assert check updated to match. |

No money/auth/privacy check was weakened: the profile read-failure raw suite, roam replay owner/lifetime guards and
detail read masks (with all their mutation controls), and the editor save path are still checked on current source.

## Left in the baseline (54 rows) and why

- **Merchant / coop (52 rows; out of scope by lane rules).** `test_merchant_*` (48), `test_c07_fulfillment_projections` (2,
  MerchantSupplyDryRun), `test_chapter_replacement_invitation` (1, `api/merchant/chapter-application/*`),
  `unittest.loader._FailedTest.test_merchant_project_workspace_entry` (1). Most are the same admission/inverse
  pattern and would clear the same way once merchant is back in scope.
- **Profile reload discard change-scope proofs (2 rows; kept on purpose).**
  `test_profile_reload_discard.test_exact_inverse_restores_the_entire_original_profile_view`,
  `...test_other_former_muse_paths_core_transports_catalog_and_existing_tests_unchanged`. Its 10 behavior checks
  (dirty-draft gate, cancel = no read, synchronous consume + recheck, owner/scene/session retirement, bilingual
  copy) pass; the two left are whole-file privacy-path pins that a reviewer of the profile save path should retire
  explicitly, as debt-contracts-b recommended.
- Rows that were in the 104 but are not in the merchant list above: none left.

## Follow-ups

- `App/ProjectRemoteVersionRow.swift` has no call site (MP shows no version). It is kept only because
  `tools/tests/test_project_remote_version_accessibility.py` still checks its AX shape; delete both together in a
  cleanup pass (needs `generate_project.py`).
- The club admission chain (`tools/club_customer_directory_admission.py`, `tools/run_targeted_native.py` historical
  blobs) is now only reached by merchant modules and some `tools/tests/*`; recommend retiring it as a whole once
  merchant contracts are in scope.
