# Contract triage CT-3 (modules with sorted index % 3 == 2)

Baseline (full `unittest discover`, 5634 tests): 575 failures + 115 errors overall.
CT-3 owns 110 of 332 failing modules = 247 failing/erroring tests (about 43 need `origin/migration/native-ios`; ignored as clone artifacts).
After this batch, owned modules run one by one: 194 failures + 51 errors = 245 (the full-run baseline and per-module runs are not identical; `nearby_team_source` is not a `test_*.py` file and was not rerun). Two modules are now green: `test_club_story_walk_estimates`, `test_activity_reviews`.

Note: the full run left `Resources/StoreCharacter.xcstrings` modified (side effect of `test_w2_19_aiNPC`, which rewrites the file); it was reverted and not committed.

## (a) Source regressed -> Swift/catalog fixed
- `test_club_story_walk_estimates::test_estimate_display_is_in_real_stop_card_with_bilingual_caveat`: catalog key `topic.itinerary.estimateNotice` had been shortened to "Walking times are estimates" (commit f9ca1f42), dropping the straight-line / 80 m/min disclosure pinned by the contract and present in 090d8abd. Restored the original en and zh-Hans text in `Resources/Localizable.xcstrings`.

## (b) Contract text stale -> assertion updated (behavior preserved)
- `test_activity_reviews::test_reviews_are_read_from_allowed_detail_and_mounted_after_tickets`
  - old: `Button("context.review.title") { showsReview = true }`
  - new: `Button("context.review.title", systemImage: "square.and.pencil") { showsReview = true }`
  - why: f9ca1f42 added only an SF Symbol to the label; same action, same identifier.
- `test_activity_reviews::test_display_handles_unknowns_and_preserves_plain_text`
  - old: `assertNotIn('Image(', view)`
  - new: every `Image(` must be `Image(systemName:` (`AsyncImage` and network tokens still forbidden)
  - why: the only image is the static star-rating glyph with an accessibility label; no fetch, no write.

## (c) Not decided (left unchanged, with reason)
All other owned failing tests are left as-is; each needs per-test git archaeology that was not completed in this run. Grouped by observed pattern:
- Exact-hash / byte-for-byte "inverse" pins (e.g. `test_approved_release_recovery_migration`, `test_category_roam_registration`, `test_club_customer_directory_remote_admission`, `test_merchant_operator_invitation_receipt`, `test_merchant_project_browser`, `test_merchant_redemption_filter`, `test_merchant_station_submission_import`): pin historical file bytes; the file changed in the merged baseline. Need owner decision on whether to re-pin.
- Substring pins on SwiftUI source (`.onDisappear {...}`, `.task(id:)`, `.id(session...)`, `guard ...`), e.g. `test_account_collection_structure`, `test_club_feed_read_parity`, `test_manual_map_composition`, `test_merchant_customer_detail`, `test_merchant_field_stable_owner`, `test_im_history_bridge`: lifecycle/identity fences; changing either side without compiling risks weakening a fence, so undecided.
- Missing/renamed localization keys (`test_city_game_base`, `test_im_conversation_reply_policy`, `test_merchant_aftercare_progress`, `test_merchant_operator_invitation_receipt`, `nearby_team_source`, `test_growth_source_contract` `growth.board.link`/"Points and ranking"): user-visible strings; may be real regressions needing translated copy.
- `test_growth_source_contract::test_route_allowlist_matches_audited_flutter_reads`: source now reads `api/growth/leaderboard/anonymous`, which is outside the audited allowlist; this is a safety-relevant API surface change, not decided.
- Import/loader errors (`_FailedTest` modules: `test_club_customer_keyword_debounce`, `test_merchant_project_workspace_entry`, `test_project_edit_contracts`, `test_roam_route_replay`, `test_run129_navigation_diagnostics`, `test_run130_submission_evidence`, `test_template_author_exit_guard`): not investigated.
Full per-test list with first failing assertion: reproduce with the command in the task; nothing else was changed.
