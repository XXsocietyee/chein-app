# Acceptance A1 receipt (run 45738766534, lane A1)

Base `origin/ui/combined-r7` 2446657fb, then merged 6d0e53c13 (native-r2 round 2). Run 45738766534 checked ci/acceptance `ac509608a` (combined-r7 at 0c80591c0).
Contract tests re-run locally with `python3 -m unittest` and `tools/contract_ratchet.py --check`: no A1 id is NEW or NOW PASSING.
Core (Swift) tests were fixed by reading the code (there is no compiler here). The CI log tail did not include their assertion lines.

## Contract ratchet (Python)

- test_club_attendance_correction_return…testBeforeAndAfterAwaitReadFencesBindRealPage: fixed on the tip (passes at 2446657fb; failed at ac509608a before the 04c1d84f1/4df2d6204 merges)
- test_club_case_submission_return…testReadCurrentFenceBeforeAndAfterAwaitRetainsOriginalContextChecks: fixed on the tip (passes at 2446657fb)
- test_club_customer_clear_filters…test_response_remembers_the_query_that_was_actually_read: fixed on the tip (passes at 2446657fb)
- test_club_customer_permissions…test_existing_production_fixture_changes_only_allow_evidence: fixed (test). Strips the one additive Core test from 097702ffb (owner-approved non-money club writes), pinned by sha256, before restoring the P044 bytes. The restored hash is unchanged.
- test_club_detail_page_ready…test_model_keeps_states_unknown_dash_and_debug_fixture: fixed on the tip (passes at 2446657fb)
- test_club_leaderboard_member_navigation…test_prior_customer_product_spans_are_exact_published_bytes: fixed (test). Re-pinned one span. The only change is the one-line `Shared read.` doc comment from 4df2d6204.
- test_club_leaderboard_member_navigation…test_refresh_and_identity_invalidation_clear_selection: fixed on the tip (passes at 2446657fb)
- test_club_occurrence_cancellation_return…test_readback_proof_binds_review_owner_context_and_visibility: fixed on the tip
- test_club_operations_contracts…test_all_literal_ui_keys_and_canonical_values_have_bilingual_copy: fixed on the tip
- test_club_operations_contracts…test_dormant_perform_requires_scope_and_durable_lock: fixed on the tip
- test_club_ops_governance…test_ban_body_sends_duration_days_7_30_90: fixed (test). The code's guard is stricter: integer only, string day counts rejected. The 7/30/90 assertion is kept.
- test_club_topic_settings_return…testExactReadFencesBeforeAndAfterAwaitNoOptimisticFlags: fixed on the tip (4df2d6204 restored `load()`)
- test_coop_fixture_lifecycle_diagnostic…test_release_view_tokens_match_the_explicit_presentation_owner_increment: fixed (test). Re-pinned for 7ccdecd2f (MP empty art) and e79a8b061 (guest 登录 button). Presentation only; the owner/lifetime reversals are unchanged.
- test_creator_configuration…test_source_wire_values: fixed on the tip
- test_creator_root_authoring…test_root_serialization_preserves_root_only_configuration: fixed on the tip (b51a0756c)
- test_merchant_club_discovery…test_access_refresh_cannot_expire_a_new_scope_or_canceled_request: fixed (test). f967221a1 moved the readers into App/AppSession+DiscoveryReading.swift, so the test now reads both files. The assertions are unchanged.
- test_merchant_club_discovery…test_app_session_reads_with_credential_and_scope_fences_without_expiring_optional_read: fixed (test). Same move.
- test_merchant_station_submission_import…test_exact_single_editor_inverse_preserves_every_other_hunk: baselined, note `merchant release`. Byte freeze of merchant station editor files that later merchant parity work changed.
- test_merchant_station_submission_import…test_existing_services_commands_journal_and_scanners_unchanged: baselined, note `merchant release` (Core/MerchantContentService.swift byte freeze)
- test_public_template_composition (both): fixed on the tip (f967221a1 viewer fence)
- test_public_template_detail_freshness (all 3): fixed on the tip (f967221a1)
- test_template_authoring_contracts…test_exact_template_endpoint_set: fixed (test). Adds the C-T3c merchant city-node submit path from 2d605cc80, and asserts that `request` still refuses citynode drafts on the personal pipe.
- test_template_authoring_contracts…test_guide_roam_routes_to_actual_roam_tab_tag: tip regression, fixed (test). The native-r2 shell moved the home feed into `homeTab`.
- test_template_metadata_selectors (both): fixed on the tip
- test_template_preference_draft…test_remote_allowlist_matches_existing_serializer_fields: fixed (test). `MERCHANT` is a value, not a field (45f2b0991). `scope` is special-cased and asserted explicitly. The 40-field allowlist is unchanged.
- test_template_preference_draft…test_source_json_is_only_persisted_truth: tip regression, fixed (test). CYConfirmSheet became the system confirmationDialog (native-r2).
- test_template_author_exit_guard / test_template_intro_experience / test_template_saved_library_flow / test_template_choice_option_rows / test_template_hotspot_placement / test_template_sample_coverage (x2): tip regressions, fixed (test). Native-r2 publish groups 2/4/5 swapped to Apple controls with the same keys, actions and identifiers.
- test_w2_07_pricing_apply_parity…test_merchant_apply_create_sends_source_dates: fixed (test). The editor lists every missing field (`allMissing`, 104580afa).
- test_wallet_income_analysis_closure…testNormalEntryUsesExistingIncomeGateAndSameReader: fixed (test). 6afe54b4a passes the destination as an explicit argument. Same income gate and reader.
- test_workshop_paid_lifecycle_closure…test_paid_install_follows_the_money_switch: fixed (test). Money is ON per 139e06853: `openMoney` = host installed, so no host means no money. Virtual goods/StoreKit stay off via `virtualGoodsEnabled`. Merchant writes keep the production-closed opener.
- test_workshop_paid_professional…test_current_generic_draft_cas_reuses_real_reader_with_bounded_paging: tip-new, fixed (test). The MEMBER_TEMPLATE business type comes from 6009e19f3. Note: ci/acceptance `record-contract` appends this id as KNOWN_CONTRACT_FAILURE in record mode. Remove it there, because it now passes.
- test_workshop_protected_text_lifecycle…test_all_product_bytes_match_original_protected_consumer_delivery: tip-new, fixed (test). View re-pinned for native-r2 c068180c1 (presentation only). Controller and service bytes are unchanged.

### Regressions from the native-r2 round-2 merge (6d0e53c13), in A1 prefixes

- test_club_customer_clear_filters…test_normal_customer_inputs_keep_all_four_filters_and_explicit_search: fixed (test). Segmented Picker on the same binding; the keyword is the bar `.searchable` with an explicit `.onSubmit(of: .search)`.
- test_club_leaderboard_member_navigation…test_prior_customer_product_spans_are_exact_published_bytes: three spans re-pinned. The changes are ContentUnavailableView/ProgressView, the filter Picker, one dropped font token and the added ClubCustomerKeywordSearch modifier. Retry guards and identifiers are unchanged.
- test_merchant_club_discovery…test_locality_failure_is_inline_with_retry_not_an_empty_list / test_merchant_owned_joined_create_are_presentation_hidden_only: fixed (test). Uses the system retry Button and the Label row. The merchant-viewer hiding assertions are unchanged.
- test_merchant_club_accessible_controls…test_unavailable_title_does_not_override_retry_identifier: fixed (test). The title leaf and the retry button keep separate identifiers.
- test_club_invitation_terms…test_fresh_detail_loading_cannot_render_the_parent_list_target: fixed (test). ContentUnavailableView/ProgressView. The fences are unchanged.
- test_club_detail_leaderboard_member…test_row_opens_public_profile_and_owner_customer_choice: fixed (test). confirmationDialog uses `Text(..., tableName: "ClubPublicRoster")`.
- test_club_notification_audience…test_rows_use_current_stamp_and_borderless_hit_regions: fixed (test). The row press style was dropped (system List row). The stamp/disabled guards, contentShape and borderless retry are still asserted.
- test_club_story_runtime_boundary…test_gameplay_card_identifier_is_a_leaf_and_does_not_replace_title_identifier: fixed (test). `.font(.headline)` on a Group of one Text; the identifier still lands on the leaf.
- test_wallet_income_analysis_closure…testLocalLayoutReplacesMissingHistoricalHelpers: fixed (test). System LabeledContent replaces the local style. The historical helpers are still absent.
- The template_* tests touched by round 2 conflicted with this branch. Upstream's round-2 re-pins were taken, and they pass. test_template_preference_draft keeps this branch's scope/MERCHANT fix.

### Regressions from the 2aa2141f8 merge (fix/r9-club-a + native-r2 flows), in A1 prefixes

- test_club_detail_tabs…test_detail_view_gates_every_tab_section: fixed (test). CLB-detail-14 (0bcd0607d) moved the chat entry to 概览. The owner/member + signed-in gate is asserted.
- test_club_enrollment_contracts…test_additive_fragment_is_bilingual_and_covers_ui: fixed (code). Added `club.enroll.refreshing` to Resources/ClubEnrollmentLocalizations.fragment.json, with copy identical to Localizable.xcstrings.
- test_club_feed_read_parity…test_club_home_uses_existing_reader_without_inheriting_mutation_context: fixed (test). CLB-detail-34 (666d94a69) makes the feed open the same full club page as the list rows. The test pins the feed destination to the exact list-row construction (no extra context), and the reader/revision fences stay. **Owner review:** this deliberately reverses the earlier "feed never inherits the mutation context" rule.
- test_club_host_application_materials…test_normal_existing_host_apply_owns_the_material_model: fixed (test). CLB-apply-05 (35cb3f59b) mounts ClubHostCertImagesSection, which uses the shared uploader and sends `certImages`. The old rows stay unmounted.
- test_club_ops_event…test_every_table_key_is_bilingual: fixed (test). `MemberMissingLinkState(identifier: "clubOpsEvent.missingParam")` is an accessibility identifier, not copy, so it is stripped like message/action identifiers.

## Core (Swift)

- ClubOwnerRefundTests/testAcknowledgedCashProcessingIsNotPayoutSuccess: fixed upstream by 843dbf458. Run 30 had refund off, so `.disabled` became outcomeUnknown. The test now sets `testDerivation = {.refund}` and the coordinator keeps the acknowledged receipt.
- ClubOwnerRefundTests/testEveryDispatchedNonSuccessRetainsBothLocks: fixed by 843dbf458. With refund on, every scenario yields `.unconfirmed(message:)`, so a failure message exists.
- ClubOwnerRefundTests/testManualReviewMissingPointsRemainsUnknown: fixed by 843dbf458. With refund on, the manual receipt gives phase `.manualReview` and readback keeps it.
- ClubOwnerRefundTests/testReadbackFailureDoesNotEraseAcknowledgedReceipt: fixed by 843dbf458. A failed readback only sets `readbackUnavailable`.
- MerchantCoopCoreTests/testFinanceAndCoopLinksMatchTheMiniProgramRules: fixed (test). It passed the page's own fallback copy `这条结算批次不存在或已不可见` as a server message. The finance-detail-load rule is 404 or 记录不存在/记录不可见. The test now uses real server messages.
- MerchantCoopCoverageATests/testClubSettlementSummaryStaysPostClubId: fixed (test). `XCTAssertEqual(dict["personal"], .null)` compared nil to Optional(.null). The key is absent, so the test now uses XCTAssertNil.
- MerchantDecorCoopGallerySaveProofTests/testGalleryWithoutApprovedRouteSendsNoWrite: fixed (test). 4d89b402f (owner: merchant-coop non-money writes on) admits decor/save for any approval bound to the session. The proof now uses an approval for another account, which must send nothing.

## Notes for others

- tools/contract_ratchet.py accepts `<id>  # note` lines and keeps notes on `--update`.
- A2: `test_w2_19_aiNPC.test_catalog_builder_is_reproducible` runs tools/build_store_character_catalog.py, which rewrites Resources/StoreCharacter.xcstrings in place during a local ratchet run. Check `git status` after running it.
- Core run 30 crashed in OwnerDecisions1124Tests/testMerchantStaffApprovalMatchesTheAuditContractAndChecksPermission (index out of range), so later suites did not run (not A1).
