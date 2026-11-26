# acceptance-a3 — acceptance round 3 failures (56) on ui/combined-r7

Source: `origin/design/handoff-r2:docs/briefs/acceptance-r3-failures.md`. Branch `claude/acceptance-a3` from origin/ui/combined-r7 (c35619125+).
Result: `python3 -B tools/contract_ratchet.py --check` → 189 failing, baseline 189, new 0, fixed 0. `tools/check_scaffold.py` PASS, `tools/check_a11y_lint.py` PASS. Core test fixed in source (no swift toolchain here; verified by grep of the hit lines).
Legend: TEST = test follows the intended native-r2 shape (intent kept); CODE = real regression fixed in app/catalog; BASELINE = subject intentionally removed.

- QuestifyCoreTests.OPTTriageClosureTests/testCartCallSiteAbsenceCitesOWNOPT011 — TEST — cart hits only moved lines (819→905, 2638→2730); same content asserts, no new cart write call site.
- test_accessibility_hardening_wave…test_jump_pill_uses_tokens — TEST — jump pill is a system .borderedProminent capsule; 44pt min height and no accentColor/.white still asserted.
- test_accessibility_hardening_wave…test_badge_and_route_labels_use_tokens — TEST — IM tab label is a plain Text segment of a segmented picker; route-label token asserts unchanged.
- test_accessibility_hardening_wave…test_filter_chip_has_selected_trait_and_tokens — TEST — OrderFilterPill uses .borderedProminent/.bordered; isSelected trait kept.
- test_accessibility_hardening_wave…test_off_token_status_colours_replaced — CODE — merge re-introduced `.foregroundStyle(.red)` in ProjectEditView; restored CYColor.dangerText.
- test_account_collection_structure…test_catalog_is_complete_for_literal_and_computed_keys — TEST — added favorites.categories/.unknown rows (already in catalog) to docs/account-collection-localizations.json.
- test_account_collection_structure…test_distinct_scoped_models_and_shared_photo_card — TEST — native AccountCollectionFavoriteCard + shared QuestifyCardArtwork.safeURL gate; scope asserts unchanged.
- test_account_collection_structure…test_saved_post_tabs_default_posts_and_keep_real_scoped_destination — TEST — CYTabs → segmented Picker; scoped destination asserts unchanged.
- test_activity_design_structure…test_primary_action_preserves_allowed_detail_and_registration_gate — TEST — allowed branch gained flagged cityEventDetail; registration gate (registrationEnabled + guest sign-in) asserted on both paths.
- test_activity_reviews…test_reviews_are_read_from_allowed_detail_and_mounted_after_tickets — TEST — second mount in city event list; exactly one there, after tickets; classic order asserts kept.
- test_activity_topic_navigation…test_allowed_detail_only_and_exact_topic_identity — TEST — same branch; city list topic id from allowed detail only.
- test_cb212_official_detail_page_ready…test_string_catalog_is_bilingual_and_matches_existing_keys — CODE — merge 169f2904e lost r9 copy; catalog official.detail zh → 活动详情 restored.
- test_chapter_audio_current_selection…test_player_mount_also_rechecks_current_projection — CODE — story-flow mini player now rechecks audioURL ∈ currentAudioURLs at mount; test pins both mounts.
- test_design_system_component_contracts…test_app_outside_design_system_has_no_unratcheted_raw_color_hex_or_corner_radius — TEST — 14 new hits are Color(uiColor:) system colours (no hex/RGB); allowlisted per file with reason.
- test_design_token_unification_contract…test_no_stroke_borders_on_cards_or_secondary_buttons — TEST — CYOrderActionSecondaryLabel replaced by stock buttons; now asserts no strokeBorder in OrderLifecycleView (stricter).
- test_e2e_20261113_r12_r13…test_post_review_unavailable_note_follows_the_write_grant — TEST — anchors on club.community.confirm id; write-grant note still precedes Confirm.
- test_global_chrome_domain_contract…test_pinned_footer_bars_use_cy_footer_bar — TEST — 5 screens moved to .safeAreaInset .bar + .borderedProminent or toolbar .confirmationAction; disabled state and identifiers asserted.
- test_global_search_category_recovery…test_raw_shipping_source_satisfies_forward_contract — TEST — diff reviewed (restyle, cySheet, empty-submit toast with no request, merchant rows hidden for players); re-pinned sha; contract(view)==[].
- test_global_search_category_recovery…test_reviewed_helper_sheet_services_and_remote_explorer_are_pinned (SearchMapExplorerView) — TEST — diff reviewed (restyle, .searchable, offline bar, cySheet); re-pinned.
- test_global_search_category_recovery…test_reviewed_helper_sheet_services_and_remote_explorer_are_pinned (SearchMapFilterSheet) — TEST — diff reviewed (inline DatePicker still validated, 最近 sort only); re-pinned.
- test_native_channel_appeal_localization…testLengthAndLifecycleGuardsRemainExact — CODE — native-r2 dropped the live "n/500" counter; restored (red over limit).
- test_native_design_motion…test_navigation_scope_pagination_and_duplicate_rows_stay_explicit — TEST — wallet filter removed (bd9469fe3); offset identity still asserted.
- test_native_design_motion…test_optional_wallet_providers_do_not_create_unguarded_destinations — TEST — stricter owner gate `allowsOwnerActions(ticket)` now required before lifecycle/team destinations.
- test_native_ui_accessibility_semantics…test_essential_legal_source_notice_uses_adaptive_primary_contrast — CODE — legal footer .tertiary → .secondary; still forbids .tertiary/.opacity.
- test_native_ui_accessibility_semantics…test_receipt_and_disabled_pass_identifiers_target_semantic_leaves — TEST — ContentUnavailableView; title/description/container identifiers asserted.
- test_official_detail_parity_w2_06…test_new_identifiers_use_detail_prefix — TEST — leaf() no longer private (split helper); same prefix + no raw official.detail.* ids.
- test_official_detail_parity_w2_06…test_view_uses_core_presentation_in_source_order — TEST — rewards/collective moved to helper; call-site order + in-helper order asserted.
- test_official_event_contracts…test_activity_list_page_states_and_string_spec — CODE — catalog official.bucket.upcoming zh → 即将上线 restored (lost in merge).
- test_official_event_contracts…test_integrated_entry_scope_fixture_and_catalog — CODE — plus official.bucket.mine → Mine/我的 restored (4c6684d08).
- test_official_event_information_warning…test_original_bilingual_copy_makes_no_unsupplied_reason_claim — CODE — same catalog restore.
- test_order_lifecycle_contracts…test_bilingual_catalog_matches_owned_entries — TEST — 已退款 → 退款成功 is the intentional MP copy (e94c04b0d), only shown when payout completed; spec aligned.
- test_owned_coupon_lifecycle…test_close_callbacks_capture_appearance_and_scoped_model_identity — TEST — MKT-9-2 removed review sheet; issue() still gated on !appearance.isClosed and scoped presentation identity.
- test_owned_coupon_lifecycle…test_code_lifecycle_regressions_and_normal_offline_journey_are_authored — TEST — UI journey asserts issued counts 0→1, QR gone on back, no review button.
- test_pages_privacy_index_page_ready…test_existing_view_identifiers_stay_on_the_model — CODE — view used undeclared id; switched to model's privacy.page.guideUnavailable.
- test_pkg03_favorites_closure…test_posts_allowed_hides_posts_tab_… — TEST — segmented Picker; posts tab only under `if postsAllowed`, exactly once.
- test_pkg19_login_deletion_chain…test_sign_out_entry_requires_confirmation — TEST — MemberConfirmSheet via .cySheet; stronger: session.logout only inside the confirm action.
- test_player_release_gate…test_me_settings_and_home_entries_are_guarded — TEST — 承接审核 moved to 更多 sheet, still behind PlayerLaunch.merchantCenterEnabled (pinned).
- test_player_release_gate…test_no_unclassified_merchant_or_coop_entry_point — CODE — coop links in ClubTopicDirectorMount and AccountPublishR9Mounts were unguarded; added PlayerLaunch.merchantCenterEnabled; island source classified merchant-only.
- test_profile_self_edit_return…test_entry_only_exists_in_about_when_context_available — TEST — CYPillButton → Button; still only under selfEditContext and sole opener.
- test_project_edit_rich_story…test_all_added_keys_bilingual_and_present_in_catalog — TEST — accessibilityIdentifier strings no longer mistaken for catalog keys; real keys still checked.
- test_roam_account_entry…test_normal_root_selects_existing_current_account_tab — TEST — map home is a 2nd caller (signIn → selectedTab = .mine); system TabView Me tab pinned.
- test_search_map_contracts…test_catalog_matches_fragment_and_has_no_language_based_region — CODE — merge 169f2904e overwrote r9 search copy; 5 keys restored from docs/search-map-localizations.json.
- test_social_article_content…test_renderer_is_wired_only_to_existing_scoped_article_contents — TEST — ContentUnavailableView; scoped-read asserts unchanged.
- test_social_article_content…test_text_is_literal_and_has_no_resource_or_link_execution_surface — TEST — ContentUnavailableView/Label; ban on links/buttons/images/URLs/markdown unchanged.
- test_ticket_wallet_read_lifetime…test_every_retry_refresh_and_foreground_entry_captures_owned_presentation — TEST — `.task(id:` allowed only in TicketWalletOwnerProbe (sync, no reads, fail-closed default); forbidden elsewhere.
- test_topic_template_oversized_row…test_only_exact_fixture_cards_can_use_visible_intersection — BASELINE — e8d84a33f removed shelf-local topic search.
- test_topic_template_oversized_row…test_search_scope_maximum_text_and_no_adoption_assertions_remain — BASELINE — same; no-adopt still checked in PublicTemplate*FlowTests.
- test_topic_template_oversized_row…test_tap_is_inside_exact_element_region_and_not_a_generic_fallback — BASELINE — same; tap helper removed.
- test_ui_workbench_navigation…test_enrollment_ticket_identifier_does_not_replace_descendant_routes — TEST — .font(.headline); leaf id still on the title, not the row.
- test_view_literal_localization…test_every_plain_chinese_view_literal_has_a_distinct_english_translation — CODE — added catalog key 暂不能看可对接的活动 (en "You can't view activities open for cooperation yet").
- test_w2_04_member_tools.LocalizationChecks.test_fragment_is_bilingual_and_merged — TEST — fragment aligned to intentional MP copy (e94c04b0d).
- test_w2_04_orders…test_detail_source_sections_are_read_only_and_ordered — TEST — the only Task is the host-club follow in a separate struct; source sections keep full no-write ban; follow struct bans pay/refund/cancel/consent.
- test_w2_04_orders…test_fragment_is_bilingual_and_merged — TEST+CODE — fragment zh → 退款成功 (catalog, truthful for payout completed); en "Refund accepted" → "Refund completed" in catalog+fragment.
- test_w2_04_participation…test_fragment_bilingual_and_merged — TEST — fragment aligned to MP copy 服务暂不可用，请稍后重试.
- test_w2_04_ticket_wallet…test_full_failure_title_and_empty_hint_do_not_claim_partial_empty — TEST — .footnote/.secondary; partial lane never shows full-failure title.
- test_w2_04_ticket_wallet…test_hint_and_title_are_presentation_only — TEST — TicketWalletSubline pinned; no Button/Task/await/status.

Follow-ups: `tools/build_w204_member_tools_localizations.py` drifted from its fragment before this work (not run). `ClubGapTopicMoreMenu` is now unused and the release-gate test fails if it is re-mounted.
