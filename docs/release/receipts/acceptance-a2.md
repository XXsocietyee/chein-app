# Lane A2 acceptance receipt (run 45738766534, base origin/ui/combined-r7 2446657fb)

One line per test. "fixed" = changed on this branch; "passes on tip" = failed at ac509608a, already green on the base with no change here.

- test_activity_registration_parity_w2_06.ActivityDetailParityTests.test_meta_rows_follow_cancellation_and_precede_about: passes on tip (later merges fixed the source); no change.
- test_appsec_review.AppSecReviewContractTests.test_5_local_data_protection_and_client_data_catalog: passes on tip (MPFirstClubApprovals / MerchantLedgerSettlementOverview stores now catalogued); no change.
- test_bk_backend_sync.BackendSyncSourceTests.test_topic_like_direction_factory_wired_only_through_mp_favorite_host: fixed test; host builds the MP body via TopicLikeHostController.miniProgramLikeRequest (104580afa), lease gate and single wiring point still pinned, plus a new pin that no other App file uses it.
- test_c02_world_party_character.C02WorldPartyCharacterContracts.test_sha256_manifest_covers_exclusive_sources: fixed; manifest hash refreshed for Core/CharacterCardReadback.swift after the delegating-init build fix (04c1d84f1).
- test_mylike_page_ready.MyLikePageReadyContract.test_note_lists_missing_keys_and_leaves_the_view_alone: passes on tip; no change.
- test_native_repair_batch_integration.NativeRepairBatchIntegrationTests.test_new_catalog_keys_match_fragments: fixed; ObjectCardLocalizations fragment synced to the catalog's MP copy (objects.title 藏品 / Collectibles, ec69c20dd).
- test_ops_safety_contracts.OpsSafetyContracts.test_audit_tool_catalog_is_complete: passes on tip; no change.
- test_pages_address_address_page_ready.AddressListPageReadyContract.test_model_keeps_unknown_counts_as_em_dash: passes on tip; no change.
- test_runtime_dependency_wiring.RuntimeDependencyWiringTests.test_network_capabilities_and_publisher_mutations_are_independent: fixed test to the r8 code + RuntimeDependencyTests pin (4851569b4): reads/ownership/graduation only; pricing, refunds and creator application must stay absent (stricter). OWNER CHECK: R7-PC-B4-1 (131300ff6) had issued the pricing grant; r8 dropped it.
- test_runtime_dependency_wiring.RuntimeDependencyWiringTests.test_strings_and_fake_tests_exist: fixed; NearbyMerchantCoordinatorTests count 18 -> 19 (testRefreshFailureKeepsPreviousRows, 4d89b402f).
- test_search_map_contracts.SearchMapSourceChecks.test_catalog_matches_fragment_and_has_no_language_based_region: fixed; docs/search-map-localizations.json synced to the catalog and searchMap.needKeywordOrCategory added (also fixes test_standalone_structural_checks).
- test_signed_in_content_details.SignedInContentDetailContracts.test_server_gate_and_response_identity_are_preserved: fixed test; envelope.access unwrap, id identity check and malformedResponse still pinned.
- test_square_detail_page_ready.SquareDetailPageReadyContract.test_note_lists_missing_keys_and_leaves_the_view_alone: fixed; im.reportPeer.pickHeader (IM sheet) listed as unrelated; medalGold/Silver/Bronze decoded since r8 (45f2b0991), removed from missing fields and noted in the page-ready doc.
- test_subpackage_member_invoice_titles_index.InvoiceTitlesPageReadyTests.test_missing_keys_are_listed_and_existing_title_keys_stay_translated: fixed test; native-r2 ContentUnavailableView with the same noTitles / InvoiceLaunchUI key (da7f2c201).
- test_w2_04_orders.W204OrderParityChecks.test_detail_source_sections_are_read_only_and_ordered: fixed test; no-await check scoped to the source sections; ProfileOrderConsentSection pinned to the marketing list GET only (no setMarketing/consent/recover, no Button/Toggle).
- test_w2_04_orders.W204OrderParityChecks.test_fragment_is_bilingual_and_merged: fixed; fragment synced and zh pins updated to the R7-MEM-16-3 MP copy (4c2d9284a).
- test_w2_19_aiNPC.AINPCContracts.test_catalog_builder_is_reproducible: fixed; builder rows gained the six voice-clear keys; regenerated StoreCharacter.xcstrings is JSON-identical (key order only).
- test_w2_19_aiNPC.AINPCContracts.test_production_binding_is_read_only: fixed test; StoreCharacterOperationsReader(reader: reader, voice: writer), gates .mpFirst and no offline harness still pinned.
- QuestifyCoreTests.MessagingSessionTests/testCancellationIgnoringTransportCannotReturnPrivateDataOrExpireSession: fixed test; since 82a8c6126 the transport runs inside InFlightReadCoalescer's own Task, so the test now cancels the caller task; same assertions (CancellationError, 0 expirations). Not compiled here.
- QuestifyCoreTests.MiniProgramPageLinkTests/testCheinMiniProgramURLOpensEveryPage: fixed test; explicit group-code row (activityId=7). The generated bare row is rejected by the activityId-or-topicId rule (537bfd65a). Not compiled here.
- QuestifyCoreTests.MiniProgramPageLinkTests/testInternalPathAndPushTapOpenEveryPage: same fix as above.
- QuestifyCoreTests.MiniProgramPageLinkTests/testVerifiedUniversalLinkOpensEveryPage: same fix as above. No Release-only exclusion needed (player-release-gate not merged yet).
- AppUnit DesignR1FoundationTests/testSelectedTabIsNeutralInkWithA12PercentCapsule, testPlayerPrimaryIsAWhitePillAndSecondaryADarkPill and DesignSystemTokenMappingTests (actionPrimary, tab tint, selected chip): updated from the old dark player to native r2 (82bcf2c2d): system accent + white label, adaptive secondary tokens; game stage still forced dark. Not compiled here.

Not in the brief's list but now failing on the tip (native-r2 sweeps merged after the run; not A1 prefixes): see the commit message / follow-up.
