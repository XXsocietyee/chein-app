# Player launch lanes (owner 11-26 06:40 UTC: Claude does all of these, not Cursor)

Owner decisions 11-26 06:35 UTC: **money on** (already in the tip via 139e06853: payment, refund, host-cancel refund, payout and withdrawal open in Release when an API host is installed; virtual goods stay off until StoreKit products exist). **Design board approved.** **The owner signs and uploads TestFlight.**

Base: `origin/ui/combined-r7` (2446657fb or newer). Never push ui/*, main, master, ci/*. No production deploy. No secrets (repo is PUBLIC). Merge origin/ui/combined-r7 before every push.

## Lane G: player-release-gate → `claude/player-release-gate`
One flag, `PlayerLaunch.merchantCenterEnabled` (false in Release, true in DEBUG/TEST). In Release it hides every merchant-center, merchant-onboarding and coop entry: the Me tab rows, settings, deep links/universal links, push routes, search results and the page route table. A hidden deep link opens the player home and does not crash. Add a unit test that pins the hidden routes and a contract test (Python, `tests/`) that greps for unguarded entry points. Money stays on for player flows.

## Lane A1/A2: acceptance-player → `claude/acceptance-a1`, `claude/acceptance-a2`
Run 45738766534 NEW failures (not in baseline). Contract tests are Python and run in the cloud (`python3 -m pytest tests/<file>.py -q` or the repo's runner; see `.github/workflows/acceptance.yml` "Contract ratchet"). Fix the code or the test so it matches the current intended behaviour. Never weaken a safety assertion. Money assertions must now expect money ON per 139e06853. Merchant-only tests may go into the baseline file the ratchet uses, with the note `merchant release`. Core (Swift) tests: no Swift compiler in the cloud, so read the test and code and fix carefully.

A1 owns: club_*, merchant_*, coop_*, creator_*, template_*, public_template_*, workshop_*, wallet_*, w2_07, ClubOwnerRefundTests x4, MerchantCoop*, MerchantDecor*.
A2 owns: everything else below.

- test_activity_registration_parity_w2_06.ActivityDetailParityTests.test_meta_rows_follow_cancellation_and_precede_about
- test_appsec_review.AppSecReviewContractTests.test_5_local_data_protection_and_client_data_catalog
- test_bk_backend_sync.BackendSyncSourceTests.test_topic_like_direction_factory_wired_only_through_mp_favorite_host
- test_c02_world_party_character.C02WorldPartyCharacterContracts.test_sha256_manifest_covers_exclusive_sources
- test_club_attendance_correction_return.ClubAttendanceCorrectionReturnContracts.testBeforeAndAfterAwaitReadFencesBindRealPage
- test_club_case_submission_return.ClubCaseSubmissionReturnContracts.testReadCurrentFenceBeforeAndAfterAwaitRetainsOriginalContextChecks
- test_club_customer_clear_filters.ClubCustomerClearFiltersContracts.test_response_remembers_the_query_that_was_actually_read
- test_club_customer_permissions.ClubCustomerPermissionContracts.test_existing_production_fixture_changes_only_allow_evidence
- test_club_detail_page_ready.ClubDetailPageReadyContract.test_model_keeps_states_unknown_dash_and_debug_fixture
- test_club_leaderboard_member_navigation.ClubLeaderboardMemberNavigationTests.test_prior_customer_product_spans_are_exact_published_bytes
- test_club_leaderboard_member_navigation.ClubLeaderboardMemberNavigationTests.test_refresh_and_identity_invalidation_clear_selection
- test_club_occurrence_cancellation_return.ClubOccurrenceCancellationReturnContracts.test_readback_proof_binds_review_owner_context_and_visibility
- test_club_operations_contracts.ClubOperationsSourceChecks.test_all_literal_ui_keys_and_canonical_values_have_bilingual_copy
- test_club_operations_contracts.ClubOperationsSourceChecks.test_dormant_perform_requires_scope_and_durable_lock
- test_club_ops_governance.ClubOpsGovernanceContracts.test_ban_body_sends_duration_days_7_30_90
- test_club_topic_settings_return.ClubTopicSettingsReturnContracts.testExactReadFencesBeforeAndAfterAwaitNoOptimisticFlags
- test_coop_fixture_lifecycle_diagnostic.CoopFixtureLifecycleDiagnosticChecks.test_release_view_tokens_match_the_explicit_presentation_owner_increment
- test_creator_configuration.CreatorConfigurationChecks.test_source_wire_values
- test_creator_root_authoring.CreatorRootAuthoringChecks.test_root_serialization_preserves_root_only_configuration
- test_merchant_club_discovery.MerchantClubDiscoveryContracts.test_access_refresh_cannot_expire_a_new_scope_or_canceled_request
- test_merchant_club_discovery.MerchantClubDiscoveryContracts.test_app_session_reads_with_credential_and_scope_fences_without_expiring_optional_read
- test_merchant_station_submission_import.SubmissionImportContracts.test_exact_single_editor_inverse_preserves_every_other_hunk
- test_merchant_station_submission_import.SubmissionImportContracts.test_existing_services_commands_journal_and_scanners_unchanged
- test_mylike_page_ready.MyLikePageReadyContract.test_note_lists_missing_keys_and_leaves_the_view_alone
- test_native_repair_batch_integration.NativeRepairBatchIntegrationTests.test_new_catalog_keys_match_fragments
- test_ops_safety_contracts.OpsSafetyContracts.test_audit_tool_catalog_is_complete
- test_pages_address_address_page_ready.AddressListPageReadyContract.test_model_keeps_unknown_counts_as_em_dash
- test_public_template_composition.PublicTemplateCompositionContracts.test_catalog_unauthorized_side_effect_follows_viewer_and_loader_fences
- test_public_template_composition.PublicTemplateCompositionContracts.test_session_services_and_viewer_projection_stay_on_existing_fenced_path
- test_public_template_detail_freshness.PublicTemplateDetailFreshnessContracts.test_current_direct_read_still_expires_and_owner_forwards_callback
- test_public_template_detail_freshness.PublicTemplateDetailFreshnessContracts.test_expiration_callback_uses_captured_epoch_stamp_and_credential
- test_public_template_detail_freshness.PublicTemplateDetailFreshnessContracts.test_session_coordinator_defers_expiration_to_accepted_failure
- test_runtime_dependency_wiring.RuntimeDependencyWiringTests.test_network_capabilities_and_publisher_mutations_are_independent
- test_runtime_dependency_wiring.RuntimeDependencyWiringTests.test_strings_and_fake_tests_exist
- test_search_map_contracts.SearchMapSourceChecks.test_catalog_matches_fragment_and_has_no_language_based_region
- test_signed_in_content_details.SignedInContentDetailContracts.test_server_gate_and_response_identity_are_preserved
- test_square_detail_page_ready.SquareDetailPageReadyContract.test_note_lists_missing_keys_and_leaves_the_view_alone
- test_subpackage_member_invoice_titles_index.InvoiceTitlesPageReadyTests.test_missing_keys_are_listed_and_existing_title_keys_stay_translated
- test_template_authoring_contracts.TemplateAuthoringContracts.test_exact_template_endpoint_set
- test_template_metadata_selectors.TemplateMetadataSelectorChecks.test_category_projection_retains_exact_bytes_and_has_no_limit
- test_template_metadata_selectors.TemplateMetadataSelectorChecks.test_metadata_unauthorized_expiration_is_deferred_to_current_sheet
- test_template_preference_draft.PreferenceDraftContracts.test_remote_allowlist_matches_existing_serializer_fields
- test_w2_04_orders.W204OrderParityChecks.test_detail_source_sections_are_read_only_and_ordered
- test_w2_04_orders.W204OrderParityChecks.test_fragment_is_bilingual_and_merged
- test_w2_07_pricing_apply_parity.W207PricingApplyParity.test_merchant_apply_create_sends_source_dates
- test_w2_19_aiNPC.AINPCContracts.test_catalog_builder_is_reproducible
- test_w2_19_aiNPC.AINPCContracts.test_production_binding_is_read_only
- test_wallet_income_analysis_closure.WalletIncomeAnalysisClosureContracts.testNormalEntryUsesExistingIncomeGateAndSameReader
- test_workshop_paid_lifecycle_closure.PaidInstallLifecycleSourceContracts.test_paid_install_follows_the_money_switch
- QuestifyCoreTests.ClubOwnerRefundTests/testAcknowledgedCashProcessingIsNotPayoutSuccess
- QuestifyCoreTests.ClubOwnerRefundTests/testEveryDispatchedNonSuccessRetainsBothLocks
- QuestifyCoreTests.ClubOwnerRefundTests/testManualReviewMissingPointsRemainsUnknown
- QuestifyCoreTests.ClubOwnerRefundTests/testReadbackFailureDoesNotEraseAcknowledgedReceipt
- QuestifyCoreTests.MerchantCoopCoreTests/testFinanceAndCoopLinksMatchTheMiniProgramRules
- QuestifyCoreTests.MerchantCoopCoverageATests/testClubSettlementSummaryStaysPostClubId
- QuestifyCoreTests.MerchantDecorCoopGallerySaveProofTests/testGalleryWithoutApprovedRouteSendsNoWrite
- QuestifyCoreTests.MessagingSessionTests/testCancellationIgnoringTransportCannotReturnPrivateDataOrExpireSession
- QuestifyCoreTests.MiniProgramPageLinkTests/testCheinMiniProgramURLOpensEveryPage
- QuestifyCoreTests.MiniProgramPageLinkTests/testInternalPathAndPushTapOpenEveryPage
- QuestifyCoreTests.MiniProgramPageLinkTests/testVerifiedUniversalLinkOpensEveryPage
- QuestifyCoreTests.OPTTriageClosureTests/testCartCallSiteAbsenceCitesOWNOPT011
- QuestifyCoreTests.OwnerDecisionGuardTests/testOWND05cPayoutWritesSendNothingWhileClosedAndProductionRefusesThem

## Lane T: testflight-prep → `claude/testflight-prep`
- Release build settings: bundle id, marketing version, build number (CURRENT_PROJECT_VERSION), signing left to the owner (Automatic, team from the owner).
- `PrivacyInfo.xcprivacy`: complete the required-reason APIs and data types actually used (location, photos, camera, mic, contacts if any, UserDefaults, file timestamps, system boot time).
- Info.plist: `ITSAppUsesNonExemptEncryption = NO` (HTTPS only) and all usage-description strings in zh-Hans and en.
- StoreKit: list every virtual-goods product the MP sells as a table for the owner (product id proposal, type, price tier) in `docs/release/storekit-products.md`. Do not turn virtual goods on.
- Write `docs/release/testflight-upload-checklist.md` for the owner: archive in Xcode, signing, upload, export compliance answer, TestFlight internal group, what to test first.

> **Owner 11-26 11:46 UTC: first release = player side + clubs only.** Merchant center, merchant onboarding and coop stay hidden in Release (`PlayerLaunch.merchantCenterEnabled == false`) and ship in a later update. Do not spend time on merchant-only screens; keep every merchant entry behind that flag.
