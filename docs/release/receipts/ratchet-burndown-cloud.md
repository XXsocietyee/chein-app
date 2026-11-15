# Ratchet burn-down (cloud run) — receipt

Branch `ui/h-r6-ratchet-cloud` from `origin/ui/h-newfeat-tests` `04ebdd17`. Run date 2026-11-15.
Host: Linux. There is no Swift toolchain on this host, so no Swift was compiled. Python contract checks only.

## Counts

| | Value |
|---|---|
| Baseline before | **186** entries (`contract ratchet: 186 failing, baseline 186, new 0, fixed 0`) |
| Baseline after | **186** entries (no change) |
| Fixed at root cause | 0 |
| Contract tests updated | 0 |

**Nothing was burned down.** The task rules allow two kinds of fix: a fix to the root cause, or a test update when the owner deliberately changed the pinned behaviour. Only these five changes count as deliberate: the 5 tabs (首页/漫游/发布/俱乐部/我的), the new game types, free retries with `qa.maxTries=0`, the single 积分 currency, and City Monopoly being app-only.

None of the 186 baseline failures touches those changes. I grepped every failing module and every traceback for `RootTab`, `maxTries`, `Monopoly`, `积分`, `currency`, `jigsaw`, `imageGuess`, `trueFalse`, `scratch` and `audioClip`, and nothing matched. So no failure qualifies for a test update.

Every failure is a byte-freeze or snapshot check. Each one fails because of ordinary product, CI or copy work done since the snapshot was taken. A root-cause fix would mean reverting that work. That would undo product changes nobody approved undoing, so I did not do it either.

I did not re-pin any hash or rewrite any freeze. Doing that would make the baseline look smaller without the checks having been fixed.

## Root-cause groups (all left in the baseline)

### A. Whole-repo "club product" freeze — 85 entries
Gate: `CLUB_PRODUCT_SHA256` and `_club_authenticate_full`, in `tools/club_customer_directory_admission.py` and `Tests/ContractChecks/test_category_roam_registration.py`. It pins the SHA-256 of **700 files** across `App/`, `Core/`, `Tests/`, `tools/` and `.github/`. The constants are stored base85/zlib-obfuscated and check their own hash.

- The snapshot matches `.github/workflows/native-ios.yml` at `f329ff51` (2026-10-12). Since then, **245 of the 700 pinned files have changed** through about a month of merged work, for example `ab2d3905` and `35ee6085`.
- The four `<module-crashed:IndexError>` entries also belong to this group: `test_club_customer_keyword_debounce`, `test_project_edit_contracts`, `test_run129_navigation_diagnostics` and `test_run130_submission_evidence`. Each module raises `Current club inputs were not authenticated: Changed actual club product: .github/workflows/native-ios.yml` at import, and the worker then prints no JSON.

Modules in this group: `test_profile_read_failure_remote_admission` (31), `test_category_roam_registration` (13), `test_global_search_category_recovery` (10), `test_club_customer_directory_remote_admission` (7), `test_run129_project_editor_repairs` (7), `test_run138_ui52_driver` (5), `test_approved_release_recovery_migration` (2), `test_branch_history_fixture_handshake` (2), `test_merchant_review_draft_return` (2), `test_template_shelf_state_projection` (2), plus the four crashed modules above.

### B. Feature-batch source registry — 19 entries
Message: `Unknown current feature-batch source: App/QuestifyDensityMap.swift` or `App/ProjectEditView.swift` (`Unreviewed current editor availability bytes`), raised from `tools/run138_current_source_projection.py`. Those files have changed since they were registered.

Modules: `test_ci138_map_readonly_enabled` (4), `test_run129_map_button_role` (4), `test_run130_topic_media_source_adapter` (4), `test_run130_version_label` (5), `test_ci138_version_row_source` (2).

### C. Single-file byte or hash inverses — about 60 entries
Each of these modules pins exact SHA-256 values or exact inverse hunks for specific App/Core/UI-test files. Those files have since changed.

Modules: `test_merchant_business_access_lifetime` (25, via `merchant_customer_empty_inverse.py`: "Unknown customer-empty source"), `test_project_editor_readiness` (13), `test_merchant_store_industry` (5), `test_merchant_operator_invitation_receipt` (3), `test_profile_avatar` (3), `test_merchant_aftercare_evidence_flow`, `test_merchant_business_fixture_ownership`, `test_merchant_station_live_code`, `test_profile_reload_discard`, `test_run129_host_diagnostics`, `test_run130_route_fixture_inset`, `test_social_guide_templates`, `test_template_controls_class_migration` (2 each), and `test_merchant_aftercare_decision_change`, `test_merchant_customer_empty_recovery`, `test_merchant_discovery_redemption_contracts`, `test_merchant_project_browser`, `test_merchant_redemption_filter`, `test_owned_template_pagination`, `test_retained_shelf_ui_regressions`, `test_workshop_paid_reentry_closure` (1 each).

Some of these changes are behaviour changes outside the five approved ones. Each needs an owner decision before its test can be updated:
- `test_merchant_store_industry`: the industry picker is now multi-select (`selectIndustries`, `selectedOrder`, `limit`), where the check expects single `categoryID`.
- `test_run129_project_editor_repairs`: copy was rewritten across 37 project-editor strings, and the hints `projectRemote.chooseOwned`, `readback` and `freshSource` were removed in snapshot `f9ca1f42`.
- `test_c10_launch_issuer`: the H5 launch now fails closed (`serverIssuedLaunchUnavailable`, `IssuedOrigin` removed in `f9ca1f42`).

### D. Branch-scope git-diff checks — 4 entries
`test_c07_fulfillment_projections` (2), `test_c11_ops_support_projections` and `test_chapter_replacement_invitation` compare against a feature-branch base. `test_c11` diffs `origin/migration/native-ios`, which no longer exists; it now lives only as `archive/20261106/.../migration/native-ios`.

I tried a minimal fix for `test_c11`: skip the missing ref and keep the PINNED byte comparison. It would still fail, because `App/AppSession.swift`, `App/AppCompositionRoot.swift` and `project.pbxproj` have legitimately changed since PINNED `76ce1b31`. So I did not apply it.

### E. Nested or stale ids — 4 entries
These ids are produced from inside group-A modules, which load sub-suites:
- `profile_read_failure_raw.*` (2)
- `unittest.loader._FailedTest.test_merchant_project_workspace_entry`
- `unittest.loader._FailedTest.test_roam_route_replay`

They go away only once group A is resolved.

## Fixed vs updated-test list
- Fixed at root cause: none.
- Contract test updated: none.

## Recommendation for the owner
The baseline cannot shrink much until the owner decides how to handle the freeze gates, above all group A, where one decision covers 85 entries.

The options are:
1. Formally retire the whole-repo snapshot gates, deleting them with a recorded reason.
2. Approve a one-time re-pin of every snapshot to the current tree. That means regenerating the obfuscated constants with the tool that wrote them, which is not in this repo.

Once that is decided, group B and the single-file inverses in group C can be re-pinned in batches of about 20, as this task intended.

## Gates run
- `python3 -B tools/contract_ratchet.py --check` → `186 failing, baseline 186, new 0, fixed 0` (exit 0)
