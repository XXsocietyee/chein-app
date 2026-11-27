# debt-contracts-b receipt: contract-debt lane B (second half of the baseline)

Branch `debt/contracts-b` from `origin/ui/combined-r7` `c24b7d96c`. Scope: lines 97–192 of
`docs/release/contract-failing-baseline.txt` (96 rows, file order). Static Python checks only; no
Swift compile/XCTest run in the cloud.

## Counts

- Before: `contract ratchet: 192 failing, baseline 192, new 0, fixed 0`
- After: `contract ratchet: 161 failing, baseline 161, new 0, fixed 0` (31 rows fixed and removed from the baseline; no rows added)
- `python3 tools/check_scaffold.py` -> PASS; `python3 -B tools/check_a11y_lint.py` -> PASS

## Fixed (31 rows)

(a) = stale check updated to current intended behavior, (c) = obsolete check deleted.

- test_workshop_paid_reentry_closure ...test_upgrade_button_matches_existing_single_request_guard_without_style_dependency: (a) re-pinned preimage hash; 225fd1fb8 diff is style-only (CYPillButton/cyText -> Button/.font); confirmedRequestId guard untouched.
- test_run129_map_button_role (4): (a) rewrote on current source; byte inverse via tools/map_readonly_inverse.py broke at 8f196dac0 (MapKit Markers) / f73e88a3e. Same markers (single .isButton, selected/disabled/label/id, app.buttons locator, timeout 5, 3 journeys) + same negative mutations.
- test_run130_topic_media_source_adapter (3 rewritten, 1 deleted): (a) chain reversal replaced by current mount checks; chapter-removal sources re-pinned (03033d614 .sheet->.cySheet only), guards kept. (c) deleted test_original_accessibility_and_unrelated_bytes_remain_exact: pinned the ProjectRemoteVersionRow mount, which is no longer in the editor.
- test_run130_version_label (5 + 1 vacuous passing): (c) module deleted; every check pins the run130 `.accessibilityLabel(Text(verbatim: model.draft.baseRevision))` / ProjectRemoteVersionRow line in App/ProjectEditView.swift, and the remote version row is no longer mounted in the editor (ProjectRemoteVersionRow has no call site). Follow-up: Tests/AppUITests/ProjectOwnedEditorFlowTests.swift assertMode still looks for projectRemote.mode / projectRemote.version.value.
- test_run130_route_fixture_inset (2): (a) fixture AFTER/BEFORE re-pinned (file unchanged since 02c68098f import; pins predate it), UI journey pin unchanged; helper whole-file hash replaced by its exact bounded-viewport line (812314637 appended tapEditorMenuItem; bound now from screen.maxY - 40).
- test_social_guide_templates (2): (a) byte-offset inverse replaced by current mount asserts (SocialGuideViews one optional templateReader + one section; account entry via ProfileGuideHost passes templateReader: session). PROTECTED 21-file hash list (AppSession, Settings, ...) was the original patch's change-scope proof and all files have since moved; now asserts the guide-template feature stays out of ticket wallet / discovery / social services (ticket contract keeps test_ticket_wallet_play_entry).
- test_template_controls_class_migration (2): (a) fixed-length byte slices of UI-test method bodies + shared helper hash replaced by: each migrated method declared once and only in its new class; both classes final XCTestCase with the same complete private helper set. Bytes moved in 812314637 (save-local into ⋯ menu); helper blocks had already diverged before it.
- test_run129_host_diagnostics (2): (a) Release-projection byte pin of WorkshopOwnedNavigationState replaced by: no synthetic code outside #if DEBUG, release selection guard kept, bounded counter (<=48, now 48), snapshot fields only SyntheticEvent+Bool, no print. Callback hosts now include WorkshopPurchasedNormalAccountTests (both DEBUG-only, print only snapshot flags/role).
- test_profile_avatar.test_original_pending_reconciliation_is_byte_exact: (a) strip exactly the Bool-result plumbing (@discardableResult -> Bool, return true/false) then compare to the original pending-save decision bytes; logic unchanged.
- test_topic_template_oversized_row (3): (c) module deleted; it pinned the shelf-local topic-name search card tap/oversize flow that e8d84a33f removed (shelf now has one global-search entry). No-adopt remains asserted in PublicTemplateDetailFlowTests / PublicPlayTemplatePresentationFlowTests.
- test_global_search_category_recovery (3 rows 190-192): (a) re-pinned CURRENT_VIEW_SHA256 (GlobalSearchView after f73e88a3e/d6893f6ae; forward contract() still returns []) and SearchMapFilterSheet (bb343b6ca inline DatePicker rows, 03033d614 cySheet) / SearchMapExplorerView (8691792a4 MP offline bar, 03033d614). Same h-ratchet re-pin pattern.
- test_run129_project_editor_repairs.test_original_201_bilingual_entries_are_shipped_and_referenced: (a) "shipped" now means present in Localizable.xcstrings with non-empty en + zh-Hans (catalog copy was rewritten by MP copy passes, so fragment != catalog row); five keys whose controls were already gone at the 02c68098f import listed in RETIRED_KEYS and must stay unreferenced.
- test_run129_project_editor_repairs.test_version_reads_the_existing_verbatim_value_with_contained_ax_identity: (c) deleted; it pinned the LabeledContent("projectRemote.version") row, which is no longer in the editor.

No money/auth/privacy/data-safety check was weakened: the paid-upgrade guard was re-pinned (style-only diff)
rather than dropped, the chapter-removal guards were re-pinned and kept, and the profile pending-save
reconcile logic is still compared byte for byte after stripping only the Bool-result plumbing.

## Left in the baseline (65 rows in this half) and why

- **Admission-chain / whole-repo snapshot checks (55 rows; left, not fixable by a narrow edit).** These authenticate the whole
  current repository against frozen historical SHA-256 sets (`tools/club_customer_directory_admission.py`
  `_CLUB_E2B_SHA256` covers hundreds of files; `test_category_roam_registration` `club_authenticate_current`;
  `tools/run138_editor_readiness.py` / `tools/ci138_followon_projection.py` / `tools/run138_current_source_projection.py`).
  They first fail on `Changed actual club product: .github/workflows/native-ios.yml` or `Unknown current feature-batch
  source`. Making them pass would mean re-pinning hundreds of hashes, with no current behavior behind them, and there
  is no repin tool. Recommend a dedicated decision to retire the admission framework as a whole. Rows:
  `test_profile_read_failure_remote_admission.*` (31), `test_project_editor_readiness.*` (13),
  `test_run129_project_editor_repairs.*` (5 left), `test_template_shelf_state_projection.*` (2),
  `test_project_edit_contracts`, `test_run129_navigation_diagnostics`, `test_run130_submission_evidence`
  (module crashes come from `run138_editor_readiness.validate_current`), `unittest.loader._FailedTest.test_roam_route_replay`.
- **Profile save-path change-scope proofs (4 rows; left on purpose, privacy/data safety).**
  `test_profile_avatar.test_four_shared_file_inverses_restore_exact_frozen19`,
  `test_profile_avatar.test_twenty_eight_protected_paths_are_unchanged`,
  `test_profile_reload_discard.test_exact_inverse_restores_the_entire_original_profile_view`,
  `test_profile_reload_discard.test_other_former_muse_paths_core_transports_catalog_and_existing_tests_unchanged`.
  The avatar save path has been generalized since (ProfileMediaUpload, `carriesUpload`), so most original hunks are gone.
  Rewriting them needs a real review of that path, not a re-pin. The behavior checks in both modules (19 + 10) pass.
- **Merchant-coupled (6 rows; skipped per lane rules).** `test_run138_ui52_driver.*` (5; four fail on
  `Tests/AppUITests/MerchantMarketingUITests.swift`, all go through the UI52 projection inverse),
  `unittest.loader._FailedTest.test_merchant_project_workspace_entry`.

## Follow-ups found

- `Tests/AppUITests/ProjectOwnedEditorFlowTests.swift` `assertMode` still waits for `projectRemote.mode` and
  `projectRemote.version.value`, but neither identifier is rendered anywhere in App/ (ProjectRemoteVersionRow has no call
  site). That UI journey will fail on a simulator. Needs a UI-test owner (not a Python contract).
- Deleting/rewriting test files does not touch hash pins elsewhere: the only other mention of
  `test_run129_map_button_role.py` is inside a historical string blob in `tools/run_targeted_native.py`, and the full ratchet shows new 0.

## Round 2 (2026-11-27): second half of the 117-row baseline

Branch `debt/contracts-b` with `origin/ui/combined-r7` `a0de1bd16` merged. After both lanes landed the baseline was
117 rows; the second half (rows 59–117, 59 rows) is the same set this lane left in round 1. Five more rows fixed:

- `test_project_edit_contracts.<module-crashed>`: (a) the module read a frozen run138 projection of the repo
  (`run138_current_source_projection.frozen_context`), which needs the club admission chain and crashed on
  `.github/workflows/native-ios.yml`. It now reads the live repo, so its 9 behavior checks (durable pending before
  submit, receipt-only unknown outcome, session guards after each await, known contract paths, default-off transport)
  run against current code and pass. Two stale pins fixed: UI test count 10 -> 9 (9 since the 02c68098f import);
  catalog check also accepts `projectEdit.*` keys that ship bilingual in `Resources/Localizable.xcstrings`
  (e.g. `projectEdit.nodes.empty`, 892f6d4d3), and treats every `.accessibilityIdentifier("…")` as an id, not copy
  (the hand-kept id list predates ~30 new ids).
- `test_run129_navigation_diagnostics.<module-crashed>`: (a) same frozen projection + `historical_source` inverse.
  Now asserts on current UI-test sources: each failure-only diagnostic exists once, the original assertion was replaced
  (image back / template back) or the later copy stays (coupon, count 1), and no extra waits or `try?`. Template back
  waits on the editor's Edit action (exists AND hittable, 5 s), in tree since 02c68098f. The six template planning rows
  must still name the shared helper and keep 900 s; the helper's whole-file sha256 pin was dropped (e9de23527 added
  `tapEditorMenuItem`).
- `test_run130_submission_evidence.<module-crashed>`: (a) live source. Six first receipt/history reads are now
  `revealFirst: true` (the later run129 ack-reveal layer); id, expected bytes, phase and swipes stay exact and the
  flip count is pinned at 6. (c) deleted `test_all_21_touched_sources_and_full_original_files_are_pinned` (whole-file
  sha256 of 21 sources) and `test_all_original_button_uniqueness_assertions_and_generic_helpers_stay_exact` (needs the
  inverse to the run130 originals); the hash/inverse half of the mutation test was vacuous (the inverse raises for
  every input), so only its presence asserts remain.
- `test_template_shelf_state_projection` (2): (a) catalog read no longer goes through `creator_catalog_input` (club
  chain). Projection/display sha256 pins replaced by the MP marketView mapping (origin/mp-source:
  `chengyinhub-xcx/subpackageMember/utils/template-market.js`: marketStatus 0 审核中 / 1 已上架 / 2 需重新提交 /
  3 已下架, unknown '—') plus the guards the digest used to bind (draft==0, marketPublishStatus decode, 1–19 digit
  identity). Count guard follows the normalized-row decode (`states.count == raw.count, facts.count == raw.count,
  originalRows.count == raw.count`). Display block follows 7d71f2209 (MP `subpackageA/pages/myproject/index.wxml`, one
  ⋯ menu): no `publishStatus` in the display, one `TemplateOwnShelfMarketPlan(state).action`, delete still opens its
  review with `templateOwnShelf.delete.irreversible`. LABELS re-pinned to the shipped copy. The whole-file BASE_*
  inverse (change-scope proof of the original patch) was removed. All 38 negative mutations still fail closed.

Still left in this half (54 rows), same reasons as round 1: profile read-failure admission chain (31), project editor
readiness exact inverses of UI suites / workflow / budget (13), run129 editor-repair journey byte pins (5), profile
save-path change-scope proofs (2, privacy/data safety, kept on purpose), merchant UI52 driver + merchant workspace entry
(6, merchant-only, skipped), `test_roam_route_replay` (club chain at import).

Follow-up: `templateShelfState.personal.approved` zh is 审核已通过 while MP `_statusText` says 个人审核通过 (copy owner).
