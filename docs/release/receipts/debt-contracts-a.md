# debt/contracts-a — contract-debt lane A (first half of the ratchet baseline)

Base: `origin/ui/combined-r7` @ c24b7d96c. Scope: lines 1–96 of
`docs/release/contract-failing-baseline.txt` (file order), skipping merchant/coop-only rows.

## Gate

| check | before | after |
|---|---|---|
| `python3 -B tools/contract_ratchet.py --check` | 192 failing, new 0 | **148 failing, new 0, fixed 0** |
| `python3 tools/check_scaffold.py` | — | PASS |
| `python3 -B tools/check_a11y_lint.py` | — | PASS (0 new) |

44 baseline rows removed. No Swift app code changed. Nothing was compiled or run on Apple; these are Python source checks only.

Most of these rows were self-hashing provenance chains: they rebuilt a historical file by applying inverse patches to the current file and compared the result with a pinned SHA-256. They also hashed unrelated files such as `.github/workflows/native-ios.yml`. Once those files changed (in the 02c68098f import, then the native-r2 / r9–r11 lanes), the checks could never pass again, and none of them checked current behavior. Where a test also had real behavior checks, I kept those and ran them against the live source. Where a test only checked bytes, I deleted it.

## (a) Stale checks rewritten to the current intended behavior

- `test_c10_launch_issuer…test_platform_issues_the_held_https_host_and_a_new_nonce`: 02c68098f made `Core/H5LaunchIssuer.swift` a fail-closed facade. It issues no launch without a server ticket and mints no client nonce. The check now asserts that: https/host guards, `fail(.serverIssuedLaunchUnavailable)`, no `UUID()`, no `URLRequest(` in `issue(baseURL:)`, ACTIVE-only license, and owned≠author request id. It also asserts that advanced/start and native-context are refused and that page/JS self-report clears are rejected. All the old negative asserts are kept. The shell view and load files added later must not construct the issuer. This check is stricter than before.
- `test_club_customer_keyword_debounce` (module crash): the module now reads the live tree instead of the frozen `club_keyword_context` snapshot, which crashed at import. The asserts follow 5a223a87b: the keyword lives in `ClubCustomerFilters` and the system `.searchable` bar (CLB-customers-07). Kept: 300 ms delay, revision/cancel, stale-response retirement before the wait, context/identity/filter/keyword fences, cancel on disappear/load/invalidate, the `filter`/`keyword` payload, and `context.accepts(result)`.
- `test_ci138_map_readonly_enabled` ×4: replaced the BEFORE/AFTER/UI-file hashes and the feature-batch projection with structural checks on the live `App/QuestifyDensityMap.swift`. The source moved on in 8f196dac0 and the UI file in f73e88a3e. `.disabled(onSelect == nil)` must follow the identifier and wrap the whole AX row, and the old order is rejected. Label, value, hint, `.isButton`, `.isSelected`, the stale-input gate and `gate.consume` must each appear exactly once in the list row. UI68 asserts, `app.buttons[id]`, timeout ≤ 5 and swipes ≤ 20 are kept, CRLF is rejected, and every original mutation still fails.
- `test_global_search_category_recovery…test_recovery_does_not_reset_selected_query_or_recreate_filter_drafts`: dropped the byte equality with the pre-category `applyFilter`/`search` bodies, which changed with PC-A-3-3 empty-submit. The check now asserts that neither body touches `categoryRecovery`, `retryCategories` or `updateCategoryPresentation`. The sheet-draft asserts are kept.
- `…test_ci_discovers_this_public_gate_without_private_source`: since 02c68098f, `native-ios.yml` no longer calls `tools/run_static_checks.py`. The contract suite is now inventoried as portable methods by `tools/current_ci.py:239`, which the workflow runs. The check asserts that path.
- `…IndependentRemoteCategoryContracts.test_raw_helper_sheet_semantic_contracts_and_negative_controls`: removed only the step that rebuilt the old source. All semantic and negative-control asserts are kept.
- `test_club_customer_directory_remote_admission…test_no_change_to_write_selector_or_non_directory_reads`: this check guards permissions, so I rewrote it instead of deleting it. It now asserts the `permission` switch directly: `club:member:list:read` for checkin/topicCustomers/registrations, `CUSTOMER_DIRECTORY` exactly once (local preflight), finance/manage/OWNER rows, and `saveCustomer` as the only write using `CUSTOMER_DIRECTORY`. Removed: whole-file hashes of the club commands/service/views/form and `.gitleaksignore`.
- `…test_pbx_package_and_spm_discovery_are_exactly_unchanged`: dropped the whole-file hashes of the shared `project.pbxproj` and `Package.swift`. The registration, SPM path and Swift-test facts are kept.

## (c) Obsolete byte-pin methods deleted

- `profile_read_failure_raw` (`tools/check_profile_read_failure_contract.py`) `test_strict_current_stage_recovers_exact_original_bytes` and `test_current_gate_rejects_baseline_but_historical_gate_accepts_it`: these recovered the pre-P107 `ProfileEditCoordinator` bytes. The privacy guard is unchanged: `errors()` passes on the live file, and the live tests for gated presentation, debug/blank/rewritten messages and removed sites remain. `test_profile_avatar` and `test_profile_reload_discard` give the same results before and after.
- `test_approved_release_recovery_migration` ×2: SHA of UI-test method bodies and helpers from before run129/run130. The discovery and budget tests remain.
- `test_branch_history_fixture_handshake` ×2: protected-baseline and release-view SHA. The release-leak and button-count tests remain.
- `test_c11_ops_support_projections…test_forbidden_files_untouched`: required AppSession/AppCompositionRoot/pbxproj to equal a removed ref (`origin/migration/native-ios`), so it could never pass after integration.
- `test_ci138_version_row_source…test_original_ui_and_shared_helper_remain_byte_exact`: SHA of two UI-test files.
- `test_category_roam_registration` ×13: historical contract/scanner/catalog inverses and the "club product" hashes (native-ios.yml). The module does no behavior assertion. The helpers imported by other modules are kept.
- `test_club_customer_directory_remote_admission` ×5: P044 inverses (three product sources, whole contract, scanner, 11 physical inputs, mixed baseline domain).
- `test_global_search_category_recovery` ×7: prior-view projection and XOR-byte-drift inverses (3), the source-inverse drift test, and the run138 contract/central-floor inverses (3).

## Left in the baseline

- Merchant/coop-only, skipped: every `test_merchant_*` row, `test_c07_fulfillment_projections` ×2 (MerchantSupplyDryRun) and `test_chapter_replacement_invitation` (merchant content / cooperation).
- `test_ci138_version_row_source…test_only_exact_component_and_mount_are_accepted`: possible real defect. `App/ProjectRemoteVersionRow.swift` exists but is not mounted anywhere, and `Tests/AppUITests/ProjectOwnedEditorFlowTests.swift:33` still expects `projectRemote.version.value`. Someone needs to decide whether to mount the row in `ProjectEditView` or retire the row and the UI assert. I did not want to add a screen element without that decision. Annotated in the baseline.

## Notes

- `python3 -B tools/current_ci.py check` already fails on the base ("Current source or test inventory changed without manifest audit"). It is not part of this lane's gate, and its manifest was not refreshed here.
