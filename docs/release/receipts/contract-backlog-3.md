# Contract-test backlog, chunk 3 of 5

Branch `ui/e3k` from `origin/rc/20261108` (`87a8b3de2`; `origin/ui/main` was `cd17d0d99`, not the rc). Source list: `contract-chunk-3.txt` (141 FAIL/ERROR entries in 74 modules).

Commits: part1 `3a6bf530f`, part2 `037122880`, part3 `666a2ce50`, part4 `3eecd7daf`. Verified with `python3 -m unittest <module>` in `Tests/ContractChecks` (plus `tools/check_*.py` for the tools modules), `check_scaffold.py` and `check_design_lint.py` PASS.

## Counts

- Before: 141 failing/erroring entries.
- After: 26 still failing (115 fixed, no new failures anywhere in the 71 rerun modules).
  - 23 in `Tests/ContractChecks`: 8 ENV (missing mini-program `ui-strings` inventories), 6 admission-chain import errors, 3 whole-file hash chains (merchant_review_draft_return 2, merchant_customer_empty_recovery 1), 6 REAL (below).
  - 3 in tools: `profile_read_failure_raw` 2, `CreatorFixed45TestPreservation` 1 (frozen byte chains).

## Table

| module | tests | verdict | action | SHA |
|---|---|---|---|---|
| test_account_marketing_entry_integration | 1 | stale | AppSession now takes `composition.merchantMarketingGates`; re-pinned and added a check that the composition gate stays closed unless production gates + China (`.init()`). | 3a6bf530f |
| test_activity_design_structure | 8 | stale | Detail restyle (hero + tiles, ticket cards, collapsed more-info) and empty/error ids passed as component params; re-pinned order, gate, ids, motion (only `CYMotion.resolve` animations), date display. | 3a6bf530f |
| test_activity_detail_page_ready | 4 | obsolete (ENV) | `docs/release/ui-strings-*.json` mini-program inventory is absent in this repo; setUp now skips with reason. | 3a6bf530f |
| test_activity_parity_w2_06_p2 | 1 | stale | Topic link guard now also checks `topicScope`; re-pinned. | 3a6bf530f |
| test_auth_entry_parity | 3 | stale | `tools/build_auth_entry_catalog.py` regenerated from the reviewed catalog (brand/copy QA + 2 new keys); ids no longer counted as keys; `.disabled(working || !consentGranted)`. | 3a6bf530f |
| test_c10_launch_producer | 1 | stale | H5 platform shell/load files were restored by e5; producer still never presents/loads them, only the parent flow does. | 3a6bf530f |
| test_cb212_official_detail_page_ready | 2 | stale 1 / obsolete 1 | Fixture `token` hit was a doc comment (strip comments). 1 test needs missing `ui-strings-pages-activity-official-detail-index.json` (ENV, still failing). | 3a6bf530f |
| test_cb219/cb220/cb224/cb231, test_myproject_page_ready, test_object_badge_3d_preview | 8 | obsolete (ENV) | Each needs a `docs/release/ui-strings-subpackage*/pages-*.json` mini-program inventory that does not exist in this layout; not skipped (module still runs other tests). | - |
| test_template_authoring_page_readiness | 1 | obsolete (ENV) | Whole module reads the missing inventory at import; now skips in `setUpModule` with reason. | 3a6bf530f |
| test_city_point_selection | 1 | stale | Empty state is `CYEmptyState`; re-pinned. | 3a6bf530f |
| test_club_customer_clear_filters | 3 | stale | `club.gov.customers.showAll`, search via keyboard submit (button retired), `.task(id: readContext) { synchronizeReadContext() }` and the stronger debounce/reset fences. | 3a6bf530f |
| test_club_group_code_page_ready | 1 | stale | Group-code page is now projected in the club-ops host; still absent from player entry (welcome/root/home). | 3a6bf530f |
| test_club_invitation_terms | 1 | stale | `CYEmptyState`/`CYSkeleton` replace Text/ProgressView. | 3a6bf530f |
| test_club_ops_event | 3 | stale | Hub reached from the `club.gov.section.customers` section; hero header; ids passed as params not keys. | 3a6bf530f |
| test_club_ops_join_reason_notify | 1 | stale | `audienceCount(option)`: unknown count renders "—" (not 0). | 3a6bf530f |
| test_club_review_refresh | 1 | stale | Confirmation owned by `reviewOwner.current(item, context:, active:)` + `contextMatches`. | 3a6bf530f |
| test_contextual_publishing_groupb | 1 | stale | AI sheet opened by `QuickPublishingJourneyOwner`; client only used when `client.session == account`. | 3a6bf530f |
| test_coop_fixture_lifecycle_diagnostic | 1 | stale | Frozen Release-token hash re-pinned after e3/UI-CLOUD-16 restyles of CoopRelationDiscoveryView. | 3a6bf530f |
| test_creator_content_contracts | 2 | stale | Issue id placement; the old "read-only" banner was retired with the list/create restyle (row open stays scope-guarded). | 3a6bf530f |
| test_explore_completion_read | 1 | stale | `CYEmptyState` for missing topic. | 3a6bf530f |
| test_i03_notification_blacklist_closeout | 7 | stale 5 / REAL 2 | 5 re-pinned (revision-fenced refresh, `CYPillButton`, settings owners). 2 REAL: see defects (blacklist original identities / "historical" copy not rendered). | 3a6bf530f |
| test_localization_key_catalog_contract | 1 | stale (tool) | `tools/localization_usage_audit.py` no longer flags `zh ? "中文" : "English"` bilingual ternaries. | 037122880 |
| test_merchant_business_status | 1 | stale | Decor groups table. | 037122880 |
| test_merchant_customer_empty_recovery | 1 | obsolete | Frozen byte-exact inverse of the whole `MerchantBusinessViews.swift` (POST_SHA256); unusable after restyle without regenerating `merchant_customer_empty_inverse`. | - |
| test_merchant_insight_cooperation_center | 1 | stale | `CYPillButton`. | 037122880 |
| test_merchant_npc_knowledge_author_flow | 4 | stale | Files are now registered in pbxproj (must compile); session/composition still must not wire them. | 037122880 |
| test_merchant_onboarding_hours_editor | 1 | stale | Fragment file synced to the copy-QA catalog values. | 037122880 |
| test_merchant_review_draft_return | 5 | stale 3 / obsolete 2 | Re-pinned lifecycle ids, cancel route, 24->39 Swift tests. Remaining: whole-file sha pins of 13 churned files (AppSession/Localizable/pbxproj...) and `Tests.ContractChecks` historical-chain import. | 037122880 |
| test_merchant_template_metadata | 1 | REAL | `scopeHint`/`omissionHint` copy no longer rendered (see defects). Left failing. | - |
| test_native_channel_appeal_localization | 5 | stale 3 / REAL 2 | Re-pinned guards, tooLong, copy. 2 REAL: see defects. | 037122880 |
| test_ops_safety_contracts | 1 | stale | 5 UserDefaults stores were uncatalogued: added purpose/retention/deletion entries to `docs/ops-safety/client-data-catalog.json`. | 037122880 |
| test_owner_draft_browser | 1 | stale | `currentAccount(token:loginFallbackRole:)`. | 037122880 |
| test_p02_editor_presentation_closeout | 1 | stale | `.cyHeroScreen()`. | 037122880 |
| test_play_experience_contracts | 1 | stale | `playx.resync` authored in the shared catalog (accepted there with both languages). | 037122880 |
| test_play_gameplay_mode_separation | 3 | stale | Leaf ids on kit text, `blocksReadRebinding` superset, id on the concrete list, store game/redemption placeholder notices retired on purpose. | 037122880 |
| test_profile_draft_review_restore | 4 | stale | Return-typed save, receipts, restore function, `payload.casePics` counts. | 037122880 |
| test_profile_self_edit_return / test_profile_self_medals | 4 | stale | `CYPillButton`; medal restriction clears rows, other failures retain+label. | 037122880 |
| test_project_draft_story_preview | 1 | stale | `CYEmptyState` for empty. | 666a2ce50 |
| test_public_play_template_presentation | 2 | stale | Use count unknown is "—"; adoption via `DiscoveryTemplateAdoptionDestination`. | 666a2ce50 |
| test_qmod_archive_inspection | 2 | stale | `CYPillButton` pickers; local "not a server submission" text is `report.outcomeText`. | 666a2ce50 |
| test_reference_chat_task | 2 | stale | NPC page uses own `NPCChatBubble`; AI disclosure key retained. | 666a2ce50 |
| test_reference_map_layouts | 2 | stale | Arrival boundary lives in the summary only (steps page keeps safety line); show-map button sets camera area. | 666a2ce50 |
| test_review_presentation | 2 | stale | Blocked review keeps primary look, ignores tap, announces reason. | 666a2ce50 |
| test_roam_live_contracts / test_roam_merchant_detail_retry | 3 | stale | Share via `CYShareComposer` + explicit system share sheet; `suspendReads()` cancels retry. | 666a2ce50 |
| test_roam_private_tools | 1 | stale | `tools/build_roam_private_tools_localizations.py`: `roam.private.new` zh `新`. | 666a2ce50 |
| test_runtime_dependency_wiring | 3 | stale | `failurePhase`, nearby home selection, Swift test counts (18/17), fragment synced to copy QA. | 3eecd7daf |
| test_shop_npc_interruption | 4 | stale 3 / REAL 1 | 3 re-pinned. 1 REAL: `pauseNotice`/`retryNotice` copy lost the "restoring never sends / may not have been cancelled" caveats and now promises "won't send twice". | - |
| test_square_structure | 1 | stale | Governance fragment synced; catalog-only keys accepted. | 3eecd7daf |
| test_team_contracts / test_team_invite_copy | 3 | stale | `ShareLink` for the invite code (only in invitation preview) and `LocalPasteboard` (local-only, expiring). | 3eecd7daf |
| test_template_author_exit_guard / test_template_authoring_contracts | 2 | stale | `CYPillButton`; ids not keys; central-catalog keys. | 3eecd7daf |
| test_template_intro_experience | 5 | stale | Mini-parity intro: one primary action (skip retired), 150pt covers, 4 rendered keys. | 3eecd7daf |
| test_w2_04_member_tools / test_w2_04_ticket_wallet | 4 | stale | Complaint write appended to the same Core file (read part stays read-only); copy QA. | 3eecd7daf |
| test_wallet_commerce_integration | 1 | REAL (fixed) | `String(localized:)` for the wallet "Analysis" row ignored the in-app language; now `walletRow("wallet.analysis.title")` (identical copy exists in Localizable). | 3eecd7daf |
| test_workshop_creator_pending | 2 | stale | `CYListRow(verbatim:)`; "earlier declaration… not currently approved" copy. | 3eecd7daf |
| test_club_customer_keyword_debounce, test_merchant_project_workspace_entry, test_project_edit_contracts, test_roam_route_replay, test_run129_navigation_diagnostics, test_run130_submission_evidence | 6 | obsolete | Import/authenticate the admission chain (`tools/club_customer_directory_admission`); fails with `Changed actual club product: .github/workflows/native-ios.yml` (chain of frozen CI/product bytes) and need repo root on `sys.path`. | - |
| tools: check_nearby_team_module (nearby_team_source) | 1 | stale | Map-discovery table keys/ids. | 3eecd7daf |
| tools: check_merchant_template_assist | 1 | stale | Template destinations moved to browser + handoff view. | 3eecd7daf |
| tools: check_profile_read_failure_contract (profile_read_failure_raw) | 6 | stale 4 / obsolete 2 | Fences with `return nil`, `@discardableResult reconcile`. 2 remain: whole-file SHA of ProfileEditCoordinator. | 3eecd7daf |
| tools: club_customer_directory_admission (CreatorFixed45TestPreservation) | 1 | obsolete | Embedded frozen historical test bytes; chain gate. | - |

Verdicts: *stale* = re-pinned to current source keeping the protection; *REAL* = production property missing; *obsolete* = frozen-hash/git-chain/ENV, left failing (no deletes; skips only for the two modules that cannot run at all).

## REAL DEFECTS found (not re-pinned)

1. **Blacklist original identities not shown** (`App/NativeBlacklistView.swift`, tests `testBlacklistOriginalIdentitiesRemainFullAndSelectable`, `testBlacklistExplicitRecoveryAndHistoricalMeaningRemain`): the pending original command shows only `blacklist.unknown`; `review.expectedBlockID`, request UUID, `original.peerID`, `result.requestID` and the `blacklist.historical` copy (defined in `NativeBlacklist.xcstrings`) are never rendered, and never were on rc (absent already at snapshot `f9ca1f424`).
2. **Channel appeal safety copy unrendered** (`App/NativeChannelAppealEntry.swift`, tests `testAllDirectDynamicAndFactKeysResolveInBothLanguages`, `testAccessibilityIdentifiersAndOriginalDetailsRemainAvailable`): catalog keys `result.acceptedNotReversed`, `result.currentSeparate`, `input.explanation` (500-char/no-media note), `progress.actionID`, `channel.actionFacts.reasonCode/scopeType/scopeID/unknown`, `input.required` are defined but not used; `flow.locatorUnavailable` is not surfaced. The "receipt does not mean the action was reversed" disclosure is therefore not visible.
3. **Template metadata hints dropped** (`App/MerchantOperationsEditor.swift`, `test_merchant_template_metadata`): `merchant.templateMetadata.scopeHint` ("not a venue capacity limit") and `omissionHint` ("does not clear") were removed from the editor in snapshot `f9ca1f424`; keys remain in the catalog.
4. **Shop NPC retry copy over-promises** (`test_shop_npc_interruption.test_six_additive_bilingual_keys...`): catalog `shopNPC.retryNotice` now says "Trying again won't send it twice" and `pauseNotice` no longer says restoring never sends; the reviewed copy said the server may have received it and a retry does not prove the earlier request was cancelled. Needs a copy/product decision.
5. **Fixed in this chunk**: Wallet "Analysis" row used `String(localized:)` (system language) instead of the in-app language (`App/WalletCommerceViews.swift`).

Not defects but worth noting: `ActivityListCard` clamps title/meta to two lines (home-card rule); activity time display now goes through the shared card formatter with the environment time zone; team invite code is now shareable via `ShareLink` (the old test forbade it).

Env/obsolete detail: the 8 ENV tests need `docs/release/ui-strings-*.json` (present only on mini-program branches, e.g. `13d8e3843`, `4fd34154c`); the six admission-chain modules and `profile_read_failure` SHA gates validate frozen bytes of `.github/workflows/native-ios.yml`, `ProfileEditCoordinator.swift` etc.
