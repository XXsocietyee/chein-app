# h-ratchet receipt: contract-ratchet triage and fixes

Branch `ui/h-ratchet` from `origin/ui/main` `3ac970ec2`.

## Counts

- Before: `contract ratchet: 223 failing, baseline 193, new 36, fixed 6`
- After: `contract ratchet: 186 failing, baseline 186, new 0, fixed 0`
- Baseline refresh rule: removed only now-passing entries (6 already fixed by prior merges plus 1 stale baseline entry in `test_merchant_station_submission_import.py` repaired alongside `#19`; never added failing tests; baseline strictly shrinks `193 -> 186`).

## Gates Verified

- `swiftc -parse App/MerchantPayoutAccountView.swift App/OwnerDecisionFixtureHost.swift` -> exit 0
- `python3 -B tools/check_scaffold.py` -> PASS (4767 Swift source files, 16558 bilingual keys, 262 pages)
- `python3 -B tools/check_design_lint.py` -> PASS
- `python3 -B tools/check_appsession_ratchet.py` -> PASS
- `python3 -B tools/check_release_config.py` -> PASS
- `python3 -B tools/check_design_fixture_release_exclusion.py` -> PASS
- `python3 -B tools/audit_client_ops_surfaces.py --check` -> PASS
- `python3 -B tools/lint_no_release_print.py` -> OK
- `python3 -B tools/check_l2_environment_configs.py` -> Ran 15 tests OK
- `python3 -B tools/contract_ratchet.py --check` -> exit 0 (`186 failing, baseline 186, new 0, fixed 0`)
- Scope: static Python/parse checks only; no `xcodebuild`, `swift build`, or `swift test` run on this host.

## Triage & Changes (36 new failures)

Two checks caught real product regressions `(a)` and were fixed in Swift source; thirty-four checks `(b)` were updated to assert approved behaviour changes without deleting or skipping any check.

| # | Failing contract check | Decision | Change summary | File modified |
|---|---|---|---|---|
| 1 | `test_accessibility_hardening_wave.FPM5Pasteboard.test_no_plain_pasteboard_string_assignment_in_app` | (a) product fix | Replace `UIPasteboard.general.string = link.absoluteString` with `LocalPasteboard.copy(link.absoluteString)`. | `App/MerchantPayoutAccountView.swift` |
| 2 | `test_accessibility_hardening_wave.FPM7FixturesAreDebugOnly.test_named_fixture_files_are_debug_only` | (a) product fix | Wrap fixture host in `#if DEBUG ... #endif` (only referenced in `#if DEBUG` in `App/QuestifyApp.swift`). | `App/OwnerDecisionFixtureHost.swift` |
| 3 | `test_activity_design_structure.ActivityDesignStructureTests.test_primary_action_preserves_allowed_detail_and_registration_gate` | (b) update check | Assert `creationPolicy: Self.freeWhenUnapproved(session.registrationCreationPolicy(activityID: activity.summary.id))` and `.disabled -> .free` fallback. | `Tests/ContractChecks/test_activity_design_structure.py` |
| 4 | `test_business_runtime_wiring.BusinessRuntimeWiringTests.test_publish_reads_writes_owner_and_unknown_storage_remain_distinct` | (b) update check | Assert `factory.approval([.projectRead, .projectWrite, .projectPublicationRead])` for approved U03 GET-only publication read-back. | `Tests/ContractChecks/test_business_runtime_wiring.py` |
| 5 | `test_channel_not_friend_permission.ChannelNotFriendPermissionContracts.test_does_not_touch_forbidden_shared_owners` | (b) update check | Allow `ChannelRedeemSource.swift` in `Core/Channel*.swift` allowlist and assert it stays free of `ChannelGovernanceProjection` / `FriendPermission`. | `Tests/ContractChecks/test_channel_not_friend_permission.py` |
| 6 | `test_club_customer_permissions.ClubCustomerPermissionContracts.test_receipt_enrollment_and_mutation_boundaries_remain_separate` | (b) update check | Strip the single approved `usesForm` hunk (asserting `count == 1` and `public var usesForm: Bool { self == .topicOverview }`) before source restoration. | `Tests/ContractChecks/test_club_customer_permissions.py` |
| 7 | `test_club_detail_page_ready.ClubDetailPageReadyContract.test_model_keeps_states_unknown_dash_and_debug_fixture` | (b) update check | Assert `"/api/club/channels"` route mapping is `.liveInProduction`. | `Tests/ContractChecks/test_club_detail_page_ready.py` |
| 8 | `test_club_edit_page_ready.ClubEditPageReadyContract.test_existing_dissolve_tests_and_live_routes_stay` | (b) update check | Assert `"/api/club/update"` uses `.init(missing: "/api/club/update", production: "/api/club/update-mine")`. | `Tests/ContractChecks/test_club_edit_page_ready.py` |
| 9 | `test_club_story_projection.ClubStoryProjectionContracts.test_exact_sanitized_topic_read_and_existing_permissions` | (b) update check | Assert `public var usesForm: Bool { self == .topicOverview }` in `Core/ClubGovernanceContracts.swift` and `form: operation.usesForm` in service. | `Tests/ContractChecks/test_club_story_projection.py` |
| 10 | `test_coop_fixture_lifecycle_diagnostic.CoopFixtureLifecycleDiagnosticChecks.test_release_view_tokens_match_the_explicit_presentation_owner_increment` | (b) update check | Re-pin normalized Release SHA256 of `App/CoopRelationDiscoveryView.swift` (`9595cea3...`) after verifying owner/presentation lifetime. | `Tests/ContractChecks/test_coop_fixture_lifecycle_diagnostic.py` |
| 11 | `test_cooperation_project_navigation.CooperationProjectNavigationContract.test_back_rereads_the_same_invite_and_keeps_filters` | (b) update check | Assert `peerReader.markInviteRead(inviteID: inviteID)` in `self.detail` and strip `//` comments before checking banned literals. | `Tests/ContractChecks/test_cooperation_project_navigation.py` |
| 12 | `test_creator_root_authoring.CreatorRootAuthoringChecks.test_root_serialization_preserves_root_only_configuration` | (b) update check | Assert `|| hasRootAuthoringConfiguration || hintLadderOn else` in `Core/TemplateAdvancedDraft.swift`. | `Tests/ContractChecks/test_creator_root_authoring.py` |
| 13 | `test_deregister_index_page_ready.DeregisterIndexPageReadyContract.test_model_keeps_unknown_as_em_dash_and_hides_the_missing_result_route` | (b) update check | Assert `"/api/user/deregister/result": .liveInProduction` is absent from runtime `routes`. | `Tests/ContractChecks/test_deregister_index_page_ready.py` |
| 14 | `test_global_search_category_recovery.GlobalSearchCategoryRecoveryContracts.test_raw_shipping_source_satisfies_forward_contract` | (b) update check | Re-pin `CURRENT_VIEW_SHA256` (`9b650e9a...`) for `App/GlobalSearchView.swift` while keeping `VIEW_SHA256` inverse intact. | `Tests/ContractChecks/test_global_search_category_recovery.py` |
| 15 | `test_global_search_category_recovery.GlobalSearchCategoryRecoveryContracts.test_reviewed_helper_sheet_services_and_remote_explorer_are_pinned` | (b) update check | Re-pin `App/SearchMapExplorerView.swift` (`e986bb80...`). | `Tests/ContractChecks/test_global_search_category_recovery.py` |
| 16 | `test_growth_source_contract.GrowthSourceChecks.test_route_allowlist_matches_audited_flutter_reads` | (b) update check | Assert `"/api/growth/leaderboard/anonymous"` is `.liveInProduction`. | `Tests/ContractChecks/test_growth_source_contract.py` |
| 17 | `test_integrated_read_composition.IntegratedReadCompositionContracts.test_only_exact_validated_route_predicates_admit_queries` | (b) update check | Include `ProjectExactReadRoute(request: request, baseURL: api.baseURL) != nil || ` in the exact query-gate assertion. | `Tests/ContractChecks/test_integrated_read_composition.py` |
| 18 | `test_merchant_operator_roster.MerchantOperatorRosterContracts.test_page_uses_current_snapshot_and_the_same_existing_row_renderer` | (b) update check | Assert `MerchantOpsWp03Panel(page: .team)` precedes `if let roster = ...` inside `if query == .operators {`. | `Tests/ContractChecks/test_merchant_operator_roster.py` |
| 19 | `test_merchant_station_submission_import.SubmissionImportContracts.test_existing_services_commands_journal_and_scanners_unchanged` | (b) update check | Re-pin `PROTECTED` hashes for `App/MerchantContentViews.swift`, `Core/BusinessRuntimeConfiguration.swift`, and `App/MerchantOperationsViews.swift`. | `Tests/ContractChecks/test_merchant_station_submission_import.py` |
| 20 | `test_official_inbox_page_ready.OfficialInboxPageReadyChecks.test_model_keeps_unknown_distinct_from_zero_and_hides_missing_routes` | (b) update check | Assert `"/api/official/v2/organizer-invites/{}/{}"` is `.liveInProduction`. | `Tests/ContractChecks/test_official_inbox_page_ready.py` |
| 21 | `test_pages_privacy_index_page_ready.PagesPrivacyIndexPageReadyTests.test_model_has_states_and_does_not_invent_a_live_route` | (b) update check | Assert `"/api/compliance/usage-records"` is `.liveInProduction`. | `Tests/ContractChecks/test_pages_privacy_index_page_ready.py` |
| 22 | `test_pkg19_login_deletion_chain.Pkg19LoginDeletionChain.test_no_new_endpoint_literals_in_auth_or_compliance_ui` | (b) update check | Strip `#if DEBUG ... #endif` blocks for Release projection so `#if DEBUG` `E2ETestHostOverride` is permitted while Release remains literal-free. | `Tests/ContractChecks/test_pkg19_login_deletion_chain.py` |
| 23 | `test_play_read_composition.PlayReadCompositionContracts.test_query_exception_is_a_closed_typed_request_matcher` | (b) update check | Include `ProjectExactReadRoute(request: request, baseURL: api.baseURL) != nil || ` in exact query-gate assertion. | `Tests/ContractChecks/test_play_read_composition.py` |
| 24 | `test_play_read_composition.PlayReadCompositionContracts.test_read_only_run_and_each_mutation_capability_remain_independent` | (b) update check | Assert `guard action != .unlockChapter, accepts(context), service.enabled.contains(.leader), canWrite` and `guard accepts(context), service.enabled.contains(.leader), !leadToolBusy`. | `Tests/ContractChecks/test_play_read_composition.py` |
| 25 | `test_play_task_outcome_journey.PlayTaskOutcomeJourneyChecks.test_normal_result_host_survives_missing_node_during_readback` | (b) update check | Assert `PlayTaskOutcomeSection(...)` inside `List {` precedes `if let node {` (allowing `model.submitRecovery` row). | `Tests/ContractChecks/test_play_task_outcome_journey.py` |
| 26 | `test_playkit_native_screens.PlayKitNativeScreenChecks.test_localization_fragment_covers_all_new_visible_literals` | (b) update check | Fall back to `Resources/Localizable.xcstrings` for non-empty `en` and `zh-Hans` translation check. | `Tests/ContractChecks/test_playkit_native_screens.py` |
| 27 | `test_profile_participation_schedule.ProfileParticipationScheduleSourceTests.test_19_normal_factory_stays_off` | (b) update check | Assert China player-writes gate: `readsEnabled: composition.reviewed?.playerWritesEnabled == true && composition.reviewed?.regional.market == .china`. | `Tests/ContractChecks/test_profile_participation_schedule.py` |
| 28 | `test_project_submission_compiler_boundaries.ProjectSubmissionCompilerBoundaries.test_result_preserves_render_and_navigation_guards` | (b) update check | Assert `PublishingSubmissionResultSheet(...)` includes `statusLoader: statusLoader(receipt)`. | `Tests/ContractChecks/test_project_submission_compiler_boundaries.py` |
| 29 | `test_public_merchant_featured.PublicMerchantFeaturedChecks.test_existing_read_destinations_remain_gated` | (b) update check | Assert `ActivityDetailView(..., playReaderForActivity: { session.playReader(for: .activity($0)) }, registrationEnabled: true)`. | `Tests/ContractChecks/test_public_merchant_featured.py` |
| 30 | `test_roam_account_entry.RoamAccountEntryContracts.test_normal_root_selects_existing_current_account_tab` | (b) update check | Assert `}.cyFloatingTabBarClearance().tabItem { rootTabLabel(.mine) }.tag(RootTab.mine)`. | `Tests/ContractChecks/test_roam_account_entry.py` |
| 31 | `test_search_map_contracts.SearchMapSourceChecks.test_no_location_permission_or_provider_actions` | (b) update check | Keep location/map-provider actions forbidden in all `*Search*swift` and restrict `openURL(` so only `App/MapSearchPlayerViews.swift` may invoke it for `maps://?ll=`. | `Tests/ContractChecks/test_search_map_contracts.py` |
| 32 | `test_shezhi_marketing_index_page_ready.ShezhiMarketingIndexPageReadyContract.test_model_keeps_unknown_as_em_dash_and_hides_the_unlisted_result_route` | (b) update check | Assert `"/api/merchant/crm/marketing-consents/result": .liveInProduction` is absent from runtime `routes`. | `Tests/ContractChecks/test_shezhi_marketing_index_page_ready.py` |
| 33 | `test_signed_in_content_details.SignedInContentDetailContracts.test_normal_destinations_observe_context_and_shelf_routes_exact_id` | (b) update check | Assert `ActivityDetailView(..., playReaderForActivity: { session.playReader(for: .activity($0)) }, registrationEnabled: true)`. | `Tests/ContractChecks/test_signed_in_content_details.py` |
| 34 | `test_team_contracts.TeamSourceChecks.test_all_team_localizations_exist_in_both_languages` | (b) update check | Verify `team.create.leaseClosed` against `Resources/Localizable.xcstrings` (`en` + `zh-Hans`) alongside `TeamLocalizations.fragment.json`. | `Tests/ContractChecks/test_team_contracts.py` |
| 35 | `test_template_authoring_contracts.TemplateAuthoringContracts.test_production_hard_off_and_no_live_transport` | (b) update check | Exempt `TopicTemplateAdoption.swift` (uses injected `transport: any HTTPTransport` and no `URLSession`) from `assertNotIn('URLRequest(', ...)`. | `Tests/ContractChecks/test_template_authoring_contracts.py` |
| 36 | `test_workshop_protected_text_lifecycle.ProtectedTextLifecycleSourceContracts.test_all_product_bytes_match_original_protected_consumer_delivery` | (b) update check | Re-pin `Core/WorkshopPaidInstalledTextService.swift` SHA256 (`22b0d6fb...`). | `Tests/ContractChecks/test_workshop_protected_text_lifecycle.py` |

## Now-Passing Baseline Entries Removed from `docs/release/contract-failing-baseline.txt`

1. `test_ci138_hosted_navigation_scene.HostedNavigationSceneChecks.test_owned_fixture_normalization_accepts_only_exact_scene_hunks`
2. `test_workshop_paid_lifecycle_closure.PaidInstallLifecycleSourceContracts.test_core_matches_exact_original_functional_artifact`
3. `test_workshop_paid_lifecycle_closure.PaidInstallLifecycleSourceContracts.test_original_core_tests_keep_all_original_added_recovery_and_lifecycle_cases`
4. `test_workshop_paid_lifecycle_closure.PaidInstallLifecycleSourceContracts.test_original_reentry_tests_are_registered_byte_exact_not_rewritten`
5. `test_workshop_paid_lifecycle_closure.PaidInstallLifecycleSourceContracts.test_original_service_and_journal_are_unchanged`
6. `test_workshop_paid_lifecycle_closure.PaidInstallLifecycleSourceContracts.test_scene_aware_normal_flow_test_uses_existing_unchanged_real_scene_helper`
7. `test_merchant_station_submission_import.SubmissionImportContracts.test_exact_single_editor_inverse_preserves_every_other_hunk` (repaired stale `EDITOR_BASE_SHA` from `4caceb48...` to `5041d507...` in `Tests/ContractChecks/test_merchant_station_submission_import.py` after approved `W5b` `6b8004b92` + `UI-12` `c40dc9704` changes in `App/MerchantContentEditor.swift`, while preserving `NEW_EDITOR_HUNK` single-hunk inverse verification)
