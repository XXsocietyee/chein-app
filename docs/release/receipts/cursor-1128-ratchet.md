# cursor/1128-ratchet — contract ratchet burn-down

Base: `origin/ui/combined-r7` at `70abd6e5dbb6448a6f23a9f7f90faf5393cfdf5c` (contains pin `882fca768`).

`python3 tools/contract_ratchet.py --check` started at **52** baseline failures, **0** new, **0** already passing. Ending baseline: **46**. Fixed: **6**. The six were stale expectations. The product code they describe was already the current behavior. Money, security, and deletion assertions were not edited and were not re-pinned.

No deletion failure is in the baseline.

## Fixed (removed from the baseline)

| Test | Why the expectation was stale |
|---|---|
| `test_merchant_store_industry...test_apply_is_single_use_and_changes_only_existing_category_id` | `MerchantStoreIndustrySelection.apply()` no longer assigns one `categoryID`. It calls `selectIndustries(selectedIDs, catalog:)` on the local decor buffer, then `cancel()`. Saving still does not happen in that function. The check now requires the 1–5 bound and still forbids `save(`, `owner.edit(`, and a `categoryID` write inside `apply()`. |
| `test_merchant_store_industry...test_unavailable_source_is_retained_without_automatic_selection_or_clear` | The buffer is seeded with `selectedIDs = original.selectedCategoryIDs`. `reload()` still does not assign the selection. An empty set cannot apply (`canApply` is 1–5). The unreadable-source line is `merchant.industry.sourceUnreadable`, not the old `noClear` string. |
| `test_merchant_store_industry...test_new_industry_field_can_make_an_otherwise_empty_decor_draft_valid` | Empty decor now keys off `selectedCategoryIDs.isEmpty`. `fields()` writes `categoryIds` only for an explicit replacement and does not send `"categoryId"`. |
| `test_merchant_store_industry...test_ui_has_load_empty_retry_buffer_and_clear_boundary` | The visible copy is `orderedHint`, `reviewOrdered`, `sourceUnreadable`, `selectionInvalid`, and `limit`. Load, empty, retry, reload, cancel, and apply are still required. Apply stays disabled unless `canApply`. |
| `test_merchant_store_industry...test_bilingual_fragment_and_interpolation_are_complete` | `MerchantStoreIndustryLocalizations.fragment.json` is still the old 22-key single-select snapshot. The ordered-picker strings, including `merchant.industry.currentID %lld`, are in `Resources/Localizable.xcstrings` with non-empty `en` and `zh-Hans`. The fragment’s own entries stay bilingual. |
| `test_chapter_replacement_invitation...test_shared_files_untouched_by_this_line` | The check diffed `7ad0b638`, the C9 feature-branch base. On this integration branch that diff is the whole tree. The invitation type still does not appear in `Core/MerchantContentDomain.swift` or `Core/MerchantContentCoordinator.swift`. The money check in the same file (`test_no_auto_accept_supply_or_money_actions`) was not changed and still passes. |

`App/AppSession.swift` was not edited (7977 lines). No `String(localized:)` literals were added.

## Left on purpose — money

These stay red. Their assertions were not weakened.

- `test_c07_fulfillment_projections.C07FulfillmentProjectionContracts.test_forbidden_files_untouched` — byte-identity of payment, settlement, redemption, and order-lifecycle files against `76ce1b31`.
- `test_c07_fulfillment_projections.C07FulfillmentProjectionContracts.test_git_diff_names_equal_whitelist` — same C07 isolation diff. Widening the whitelist would stop guarding those files.
- `test_merchant_aftercare_decision_change.MerchantAftercareDecisionContracts.test_exact_inverse_preserves_note_correction_review_and_other_editor_code` — refund decision editor (`case .refund`) byte inverse.
- `test_merchant_aftercare_evidence_flow.MerchantAftercareEvidenceContracts.test_exact_inverse_preserves_frozen_decision_filter_note_and_all_other_shared_file_bytes` — aftercare / refund evidence byte inverse.
- `test_merchant_business_access_lifetime.MerchantBusinessAccessLifetimeChecks.test_aftercare_adapter_rejects_mutation_duplication_missing_block_and_home_edits`
- `test_merchant_business_access_lifetime.MerchantBusinessAccessLifetimeChecks.test_aftercare_exact_inverse_leaves_home_and_all_other_code_unchanged`
- `test_merchant_business_access_lifetime.MerchantBusinessAccessLifetimeChecks.test_settlement_exact_inverse_preserves_both_existing_layers`
- `test_merchant_business_access_lifetime.MerchantBusinessAccessLifetimeChecks.test_settlement_inverse_rejects_missing_duplicate_changed_gate_and_unrelated_edits`
- `test_merchant_discovery_redemption_contracts.MerchantDiscoveryRedemptionContracts.test_normal_search_and_permission_checked_workbench_entries` — redemption workbench. It dies in the shared customer-empty source gate before its own assertion.
- `test_merchant_redemption_filter.MerchantRedemptionFilterContracts.test_exact_picker_hunk_preserves_every_other_merchant_view_byte`
- `test_merchant_business_fixture_ownership.MerchantBusinessFixtureOwnershipChecks.test_all_ten_existing_ui_methods_remain_byte_identical` — freezes `MerchantBusinessFlowTests`, which still contains `testAftercareSeparatesOpinionFromRefund`, `testScanOnlyClassifiesWithoutCameraOrRedemptionButton`, and `testBatchDetailKeepsNegativeAdjustments`.
- `test_merchant_station_submission_import.SubmissionImportContracts.test_exact_single_editor_inverse_preserves_every_other_hunk` — the import hunk is still unique, but `MerchantContentEditor.swift` has later pricing and settlement-return edits. Re-pinning the inverse would bless those edits. Left with the `# merchant release` note.

The other 21 `test_merchant_business_access_lifetime` rows are the access/security gate (below) and also sit on the settlement / redemption / aftercare home source. They were not re-pinned either.

## Left on purpose — security

All 25 access-lifetime rows fail in `before_customer_empty_source` with `Unknown customer-empty source or changed existing boundary` before their own assertions. That gate is the access, grant, and admission inverse. It was not rewritten.

- `test_merchant_business_access_lifetime.MerchantBusinessAccessLifetimeChecks.test_cancelled_late_entry_is_rejected_before_all_load_mutation`
- `test_merchant_business_access_lifetime.MerchantBusinessAccessLifetimeChecks.test_context_drift_finish_does_not_retire_visible_appearance_before_change`
- `test_merchant_business_access_lifetime.MerchantBusinessAccessLifetimeChecks.test_customer_exact_inverse_preserves_all_existing_layers`
- `test_merchant_business_access_lifetime.MerchantBusinessAccessLifetimeChecks.test_customer_inverse_rejects_missing_duplicate_and_unrelated_edits`
- `test_merchant_business_access_lifetime.MerchantBusinessAccessLifetimeChecks.test_exact_inverse_preserves_all_business_source_outside_home`
- `test_merchant_business_access_lifetime.MerchantBusinessAccessLifetimeChecks.test_existing_bilingual_keys_are_reused`
- `test_merchant_business_access_lifetime.MerchantBusinessAccessLifetimeChecks.test_fence_mutations_and_unknown_source_fail_closed`
- `test_merchant_business_access_lifetime.MerchantBusinessAccessLifetimeChecks.test_live_projection_does_not_reuse_stale_grants`
- `test_merchant_business_access_lifetime.MerchantBusinessAccessLifetimeChecks.test_no_new_endpoint_mutation_journal_or_privacy_side_effect`
- `test_merchant_business_access_lifetime.MerchantBusinessAccessLifetimeChecks.test_one_view_owned_task_consumes_captured_request`
- `test_merchant_business_access_lifetime.MerchantBusinessAccessLifetimeChecks.test_original_entry_permissions_labels_and_queries_remain`
- `test_merchant_business_access_lifetime.MerchantBusinessAccessLifetimeChecks.test_queued_refresh_has_full_admission_before_clearing_new_owner`
- `test_merchant_business_access_lifetime.MerchantBusinessAccessLifetimeChecks.test_retired_appearance_never_reactivates`
- `test_merchant_business_access_lifetime.MerchantBusinessAccessLifetimeChecks.test_review_pages_exact_inverse_preserves_all_previous_layers`
- `test_merchant_business_access_lifetime.MerchantBusinessAccessLifetimeChecks.test_review_pages_inverse_rejects_missing_duplicate_moved_or_unrelated_bytes`
- `test_merchant_business_access_lifetime.MerchantBusinessAccessLifetimeChecks.test_roster_exact_inverse_preserves_all_four_existing_layers`
- `test_merchant_business_access_lifetime.MerchantBusinessAccessLifetimeChecks.test_roster_inverse_rejects_missing_duplicate_and_unrelated_edits`
- `test_merchant_business_access_lifetime.MerchantBusinessAccessLifetimeChecks.test_route_retains_original_dependencies_and_current_context`
- `test_merchant_business_access_lifetime.MerchantBusinessAccessLifetimeChecks.test_stable_destination_host_is_outside_conditional_access_rows`
- `test_merchant_business_access_lifetime.MerchantBusinessAccessLifetimeChecks.test_stale_disappearance_cannot_clear_replacement`
- `test_merchant_business_access_lifetime.MerchantBusinessAccessLifetimeChecks.test_success_error_and_cleanup_use_same_ticket_context_and_owner`
- `test_merchant_aftercare_evidence_flow.MerchantAftercareEvidenceContracts.test_existing_services_grants_journals_picker_and_root_config_are_unchanged`
- `test_merchant_business_fixture_ownership.MerchantBusinessFixtureOwnershipChecks.test_production_home_owns_its_access_model_and_route_guards_remain_exact` — access-model SHA.
- `test_merchant_customer_empty_recovery.MerchantCustomerEmptyRecoveryContracts.test_exact_inverse_preserves_all_previous_product_bytes` — `POST_SHA256` of `MerchantBusinessViews.swift`, the same source boundary the access-lifetime inverses refuse to cross.
- `test_merchant_operator_invitation_receipt.OperatorInvitationReceiptContracts.test_coordinator_inverse_preserves_entire_original_dispatch_and_journal`
- `test_merchant_operator_invitation_receipt.OperatorInvitationReceiptContracts.test_services_authority_mutations_recipients_and_editors_unchanged`
- `test_merchant_operator_invitation_receipt.OperatorInvitationReceiptContracts.test_view_inverse_preserves_every_other_merchant_hunk`
- `test_merchant_project_browser.MerchantProjectBrowserSourceTests.test_existing_read_path_and_authorization_remain_byte_exact`
- `test_merchant_station_live_code.MerchantStationLiveCodeContracts.test_exact_two_shared_file_inverse_proves_no_unrelated_edits` — signed live-code hunk inverse.
- `test_merchant_station_live_code.MerchantStationLiveCodeContracts.test_existing_requests_grants_writes_journal_and_other_authors_are_byte_exact`
- `test_merchant_station_submission_import.SubmissionImportContracts.test_existing_services_commands_journal_and_scanners_unchanged` — journal, commands, and scanner bytes. `# merchant release`.
- `test_merchant_review_draft_return.ReviewDraftReturnContracts.test_core_journal_transport_and_sensitive_features_unchanged`
- `test_merchant_review_draft_return.ReviewDraftReturnContracts.test_exact_existing_file_inverses_preserve_invitation_gallery_and_other_forms` — dies in club-product authentication (`Changed actual club product: .github/workflows/native-ios.yml`) before the inverse.
- `unittest.loader._FailedTest.test_merchant_project_workspace_entry` — `load_tests` calls `_club_authenticate_raw` and then refuses the historical grant / `AppSession` hashes. The module never loads, so its authorization checks were not bypassed.

## Left on purpose — deletion

None.

## Left on purpose — product looked wrong

None. The six updates above match the product that is already in the tree. Hash pins that could not be shown to be a stale copy pin, or that cover payment, grants, or account authority, were left red.

## Counts

| | |
|---|---|
| Starting baseline | 52 |
| Fixed | 6 |
| Ending baseline | 46 |
| Money rows left (named above, including the four access-lifetime aftercare/settlement rows) | 12 |
| Other access-lifetime rows (security; also sit on that home source) | 21 |
| Other security rows | 13 |
| Deletion rows | 0 |
| 12 + 21 + 13 | 46 |
