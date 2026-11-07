# Contract triage CT-2 (modules with sorted index % 3 == 1)

Baseline (wip/rc2-merged e391c3a6): 5634 tests, 575 failures + 115 errors (full suite).
After CT-2 edits: 5647 tests, 517 failures + 112 errors. No test that passed before fails now.
Owned scope: 111 failing modules / 214 failing tests at baseline -> 73 modules / 153 failing tests after
(counted from FAIL/ERROR lines). 38 modules went green. Nothing was compiled; Python checks only.

## (a) Source restored (contract intentionally pins it)
- App/MerchantBusinessEditor.swift: restored `Text("merchant.noteCorrection.append")` in note-correction review (test_merchant_note_correction_presentation, 2->1).
- App/ProfileParticipationScheduleSection.swift: restored `profile.participationSchedule.clockNote`.
- App/ProfileInviteRewardReviewSection.swift: restored `profile.inviteRewards.monthScope` (loaded-invitees-only disclosure).
- Resources/Localizable.xcstrings `discovery.publicSeconds`: restored "Duration (seconds)" / "时长（秒）" (UI shows raw seconds).
- docs/square-localizations.json: added `square.edit`, `square.report` copied from the catalog.
- Resources/MerchantFeaturedClearLocalizations.fragment.json: `merchant.featuredClear.inDraft` fragment resynced to the live catalog copy ("No featured item" / "暂无主推"); copy only.

## (b) Contract text stale, behavior preserved or stricter (test assertion updated)
Test harness: test_template_author_exit_guard / test_template_saved_library_flow / test_template_intro_experience / test_template_profile_override
  `not sys.argv[1].startswith('-')` -> `(Path(sys.argv[1])/'Core').is_dir()`: under `unittest discover` argv[1] is the word "discover", which was treated as a repo path. No assertion changed.
Others (old -> new; why behavior-preserving):
- activity_design_structure: `.buttonStyle(.borderedProminent)` -> `.questifyPrimary` (same primary button); `Text("activity.currencyUnconfirmed")` -> `appLocalized(...)` (same text via helper).
- city_point_selection: style-only `.foregroundStyle(.secondary)`; onDisappear gained `rulesSheet?.flow.cancel()` (extra cancel, originals kept); retry Button gained icon label.
- club_home_topic_navigation: `reader: session.topicReader` -> `topicReaderOverride ?? session.topicReader` (override optional).
- coupon_validity_parity: date pickers moved to App/CouponValidityRangeEditor.swift; test reads that file; timezone settings unchanged.
- im_expanded_integration: wiring moved into SessionMessagingHome; both locations now asserted.
- im_conversation_read_all: close button label is "cancel" while reviewing; same dismiss action.
- composed_session_invalidation: extra `invalidateInvoiceLaunch()` before existing invalidation; `private var` -> `var` access only.
- merchant_insight_cooperation_center, merchant_customer_contact_flow, merchant_customer_note_draft, merchant_review_loaded_pages(partial), merchant_station_optional_fallback (`permitsWrites` -> `permits(review.command)`, same fail-closed gate), merchant_template_hints / rule_steps (`nativeAlertAction` helper still queries alerts by identifier), official_private_parity_w2_06 (`.disabled(!model.canConfirm)`; canConfirm = coordinator.enabled && ownsPresentation && !busy && review != nil && receipt == nil), merchant_city_quota (fragment keys now merged: asserts catalog equals fragment, stronger than disjoint), non_cash_reward_slice(partial), merchant_operator_roster(partial; count pin 12->15), merchant_public_production(partial; var rename).
- social_presentation_revision, topic_creator_attribution (club name moved to TopicXcxHero, still shown), w2_07_pricing_apply_parity (literals externalized to keys; zh text asserted in catalog), workshop_creator_consent (guards stricter), settings_native (attribution section moved to SettingsAboutView.swift, partial).
- play_location_fidelity (zh wording only), owned_template_pagination (locked-state copy), participant_list_direct_actions (canPrepare is stricter), play_director_prefab_contracts, private_home_composition (checks moved to Core/PrivateHomeRequestBoundary, pins stricter), profile_self_projects (stricter), profile_self_edit_return, project_chapter_compiler_boundaries, project_edit_v2_contract (per-occurrence approval check keeps intent), project_owned_editor, project_submission_acknowledgment, public_merchant_review_filters (moved to PublicMerchantReviewRows), reference_chat_task, registration_waitlist_order_navigation, roam_live_contracts(teams), play_route_map(`playRoute.actionRead` is an a11y id, not a catalog key).

## (c) Left untouched (reason)
- Missing ref origin/migration/native-ios (clone artifact): c03_six_mechanism_projections, c11_ops_support_projections, parts of global_search_category_recovery, chapter_replacement_invitation.
- "Current club inputs were not authenticated" hash chain: branch_history_fixture_handshake, club_customer_keyword_debounce, project_edit_contracts, roam_route_replay, run129_project_editor_repairs, profile_read_failure_raw.
- Hash/byte pins on frozen files: merchant_aftercare_evidence_flow, merchant_business_fixture_ownership, run130_topic_media_source_adapter, social_guide_templates, workshop_protected_text_lifecycle, playkit_glb_security (re-pinning vendor hash would weaken supply-chain gate).
- Disclosure/safety copy rewritten (needs product decision): wallet_income_analysis_closure (no-payout/no-completeness labels), play_route_map explanation (lost "location not collected"), order_lifecycle_production (payment/refund wording), roam_experience_contracts, project_edit_rich_story, runtime_dependency_wiring, template_preference_draft, template_story_projection, workshop_paid_installed_text, merchant_insight_recent_visitors, native_repair_batch_integration, merchant_coop_capacity_clear (draftHint removed; possible disclosure regression), merchant_public_production (retryable fail-closed semantics changed).
- UI redesign/removal or behavior change: activity_design_structure(2), activity_registration_parity_w2_06, app_composition_root, c10_launch_issuer, club_customer_clear_filters, club_enrollment_contracts, club_management_return_state, club_member_profile_navigation, club_operations_contracts, club_ops_join_reason_notify, club_story_projection, coop_parity, journey_narrative_workflows, map_marker_density, city_fairness, merchant_npc_preset_avatar, merchant_operations_contracts, merchant_operator_roster, merchant_profile_benefits, merchant_store_industry, native_channel_notification_presentation, non_cash_reward_slice, official_detail_parity_w2_06, profile_case_portfolio, profile_draft_review_restore, project_topic_media_app, retained_shelf_ui_regressions, roam_live_contracts(share), route_total_count, search_map_date_presets, settings_native(3), template_branch_composition, template_image_crop, template_media_review_ui, template_profile_questions, template_saved_library_flow, w2_04_member_tools, w2_04_participation, w2_19_aiNPC, w2_19_gameNode, x01_existing_entry_ui_closeout, merchant_review_loaded_pages(hash).
