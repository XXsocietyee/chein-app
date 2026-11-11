# Contract-test backlog, chunk 2 of 5

Branch `ui/e2k` from `origin/rc/20261108` (87a8b3de2). `origin/ui/main` (cd17d0d99) differs from the
named rc 07eb6a5d1, and 07eb6a5d1 is not an ancestor of either, so the brief's fallback
(`origin/rc/20261108`) was used.
Code only: no xcodebuild or simulator. `python3 tools/check_scaffold.py` and
`python3 tools/check_design_lint.py` PASS before each push.

Run: `cd Tests/ContractChecks && PYTHONPATH=../.. python3 -m unittest <module>`
(the chunk list was produced with the repo root on `PYTHONPATH`).

## Counts

| | failing entries (63 modules) |
|---|---|
| before (chunk list) | 145 |
| after | 67 (18 modules) |
| 78 fixed in 45 modules | 76 stale pin, 2 real defects fixed in production (see below) |
| new failures introduced | 0 |

All 67 remaining are class (c) OBSOLETE/ENV, listed below. None is a real defect.
No assertion was weakened: each re-pin points at the current source for the same protection, or
asserts more. SHAs: part 1 = d1c5378e4, part 2 = 4bb11befa.

## Fixed (stale pin unless noted)

| module | tests | verdict | action | SHA |
|---|---|---|---|---|
| club_detail_events_section | 1 | stale | `task(id:)` now keyed on `ReadTrigger(context: readContext…` | d1c5378e4 |
| club_owner_refund_contracts | 1 | stale | confirm gate is `.disabled(!model.confirmEnabled)` (= canDispatch && !inFlight) | d1c5378e4 |
| cooperation_project_navigation | 1 | stale | disabled pay button replaced by back-to-list; pin now asserts NO `deposit.pay` button | d1c5378e4 |
| im_conversation_row_actions | 1 | stale | close button is `LocalizedStringKey("action.close")` | d1c5378e4 |
| integrated_read_composition | 3 | stale | China launch intentionally lists manualMap/playNodes only inside the admitsShippedChina branch (unconfigured default kept); fence count 6→26; query admission guard grew more exact route predicates | d1c5378e4 |
| map_visual_foundation | 1 | stale | accent palette restyled; new RGB and contrast ratios re-asserted > 4.5 | d1c5378e4 |
| merchant_city_claim_withdrawal | 1 | stale | gate is stricter `service.permits(review.command)` | d1c5378e4 |
| merchant_customer_detail | 2 | 1 stale, 1 REAL | onDisappear grew `pendingMutationEditorID`; REAL: refund-time boundary note dropped by restyle, restored in `App/MerchantCustomerDetailSections.swift` | d1c5378e4 |
| merchant_insight_navigation | 1 | stale | fragment synced to restyled catalog copy | d1c5378e4 |
| native_presentation_reuse | 4 | stale | fragment synced; camera priming sheet allowed (camera still full-screen); custom framing camera cancel pin; skeleton busy indicator; language owner `AppLanguage.storageKey`; attributions moved to SettingsAboutView | d1c5378e4 |
| native_repair_batch_integration | 1 | stale | 3 fragments synced to catalog | d1c5378e4 |
| community_media_integration | 1 | stale | docs catalog PublicMerchantHome synced | d1c5378e4 |
| template_choice_option_media | 1 | stale | tools json synced to catalog | d1c5378e4 |
| club_detail_tabs | 2 | 1 stale, 1 REAL | REAL copy defect (below); marker `ClubDetailEventsSection(`; help copy removed | d1c5378e4 |
| club_ops_governance | 2 | stale | 3 zh strings shortened by restyle re-pinned; review section is `if let review {` | d1c5378e4 |
| club_story_runtime_boundary | 1 | stale | identifier leaves re-pinned against CYTypography chain | d1c5378e4 |
| city_fairness | 3 | stale | view uses `table` constant + shared components; facts missing renders "—"; pbxproj now registers the screen (host files still untouched) | d1c5378e4 |
| walking_navigation_contracts | 1 | stale | 4 zh/en strings restyled (fragment and test dict synced) | d1c5378e4 |
| template_own_shelf_read_state | 1 | stale | English is a real translation now; fragment merged into catalog | d1c5378e4 |
| template_controls_ui_acceptance | 1 | stale | XCUITest copy updated to catalog (`Each step can be up to 60 characters…`, `Example run finished…`) | d1c5378e4 |
| template_own_shelf_host_flow | 3 | stale | delete review is `templateOwnShelf.delete.*`; card no longer renders the undispatchable plan; XCUITest status copy | d1c5378e4 |
| template_shelf_read_bridge | 3 | stale | prepare guard grew busy/keyword terms (still blocks on refresh snapshot); `TemplateAuthoringEntryDestination` | d1c5378e4 |
| topic_template_name_search | 1 | stale | load moved into topics state object, same request/unauthorized hook | d1c5378e4 |
| ui_workbench_navigation | 1 | stale | ticket id still a leaf on title, new modifiers | d1c5378e4 |
| w2_04_orders | 2 | stale | unknown order code renders "—"; `CYLoadSlot(label:)` | d1c5378e4 |
| walking_camera_controls | 2 | stale | expiry via shared `isLive(target)`; controls hidden when no snapshot | d1c5378e4 |
| profile_case_picture_removal | 6 | stale | partial-subset feature added; tokens extended (`casePictureSubset`), sheet takes optional read-only preview reader | 4bb11befa |
| object_badge_wall_layout | 4 | stale | segmented picker, CYCollectionGrid, detail hash re-pinned, lineLimit scoped to tile label | 4bb11befa |
| merchant_npc_recovery | 2 | stale | projection also gated on `gameDispatchDenial == nil` and `outcomeAllowsRetry` (stricter) | 4bb11befa |
| merchant_operations_contracts | 2 | stale | card moved to editor; template browser paged (`MerchantTemplatePage.pageSize`) | 4bb11befa |
| merchant_profile_benefits | 1 | stale | benefits edited through `MerchantStoreFieldEntry` | 4bb11befa |
| merchant_public_production | 1 | stale | `reply.outcomeStatus != "PROCESSING" && !reply.canRetry` | 4bb11befa |
| merchant_template_categories | 1 | stale | UI test uses `.firstMatch` for duplicated alert ids | 4bb11befa |
| merchant_store_field_editing | 3 | stale | `viewDisappeared()`; test inventory 22→39; exact `"merchant.operations.confirm"` id | 4bb11befa |
| merchant_aftercare_decision_change | 1 of 2 | stale | review button now conditional label | 4bb11befa |
| pkg19_login_deletion_chain | 2 | stale | DEBUG blocks in SettingsView/AccountComplianceViews are design-fixture only (verified; deletion path release-reachable); sign-out via `CYConfirmSheet` | 4bb11befa |
| pages_shezhi_shezhi | 1 | stale | market text via `SettingsHomePage.marketText` (nil → "—") | 4bb11befa |
| official_detail_parity_w2_06 | 1 | stale | cards now precede story detail; date range uses injectable `displayTimeZone` | 4bb11befa |
| non_cash_reward_slice | 1 | stale | `scheduleRefresh` now guards first (stronger) | 4bb11befa |
| project_edit_starter | 1 | stale | leave()/restore lifecycle tokens | 4bb11befa |
| project_remote_immutable_fixture | 2 | stale | `ProjectEditPending` gained 3 fields; Swift CAS test now carries them (`ProjectEditRemoteTests.swift`) so the replacement differs only in payload | 4bb11befa |
| project_topic_media_app | 1 | stale | video caption deliberately removed ("hidden entirely") | 4bb11befa |
| roam_account_entry | 1 | stale | slice narrowed to the account button block | 4bb11befa |
| roam_share_route_privacy | 4 | stale | composer rebuilt on `CYShareCardRenderer`; route/place still opt-in default off | 4bb11befa |
| square_detail_page_ready | 1 | stale | unrelated key `ui.cloud05.admission.more` shares the words 更多操作; excluded | 4bb11befa |
| team_pkg07_acceptance | 1 | stale | copy via local-only expiring `LocalPasteboard.copy` | 4bb11befa |

## REAL DEFECTS found

1. **Refund time shown without its boundary note** (`merchant_customer_detail`).
   `merchant.customerDetail.refundTimeBoundary` ("Refunded is a registration status; the record time is
   not a refund completion or arrival time") was dropped from `MerchantCustomerDetailSections` by
   the UI-F05 restyle (ec2252c10/343fba152 line). The record time next to "Refunded" could be read as a
   refund-complete time. **Fixed**: note restored in both the latest-event block and event facts.
2. **Unavailable shown as empty** (`club_detail_tabs`). When community or governance is not available,
   the club detail showed "No posts yet" / "No activities yet" (catalog values of
   `club.detail.posts.unavailable` / `club.detail.events.unavailable`), which presents unknown as empty.
   **Fixed** in `Resources/Localizable.xcstrings`: restored the "unavailable in this build" copy (en + zh).

Watch items, not defects: `walking.saved.notice` lost its "no route or travel history is saved" sentence
(copy only); order state codes now show "—" while the doc comment in `ProfileOrdersView.swift:505` still
says raw codes stay visible; official event dates use viewer time zone instead of Asia/Shanghai.

## OBSOLETE / ENV (67 tests, left untouched, not deleted, no skip added)

| module | tests | why |
|---|---|---|
| activity_publishing_page_readiness, club_detail_page_ready (2), growth_center_index_page_ready, growth_leaderboard_page_ready (4), official_inbox_page_ready, play_poi_challenge_page | 10 | `docs/release/ui-strings-*.json` registries no longer exist in the repo layout (setUpClass FileNotFoundError) |
| c03_six_mechanism_projections | 4 | `git diff origin/migration/native-ios` (ref absent) |
| c07_fulfillment_projections | 2 | git-diff whitelist vs native_ios baseline and "forbidden files untouched" (files since changed by later work) |
| c09_notify_webhook_projections | 5 | git-diff baseline vs `origin/migration/native-ios`; "not integrated" assertions (pbxproj now contains the page actions, tests carry `@MainActor`) |
| ci138_version_row_source, run129_project_editor_repairs (7), run130_version_label (5) | 14 | historical CI snapshot verifiers (feature-batch source chain, `.github/workflows` identity, byte-exact old UI) |
| merchant_business_access_lifetime | 25 | patch-inversion chain ("Unknown customer-empty source or changed existing boundary") against a historical file state |
| merchant_aftercare_decision_change (1), merchant_aftercare_evidence_flow (2) | 3 | exact-inverse of an old hunk list / baseline SHA256 of `MerchantBusinessEditor.swift` and shared root files |
| merchant_business_fixture_ownership (2), merchant_project_browser (1), workshop_protected_text_lifecycle (1) | 4 | SHA256 "byte-identical to original delivery" pins of files that were restyled afterwards |

Recommend retiring these or regenerating them from the current baseline in a dedicated change.
