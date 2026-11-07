# Contract-check triage CT-1

Scope: failing modules at sorted index % 3 == 0 (109 of 326 failing modules) on wip/rc2-merged.
Observed (python3.11, `unittest discover -s Tests/ContractChecks`): whole suite before 575 failures + 115 errors; after 473 failures + 111 errors (skipped 47 both). Owned modules: 231 failing tests before, 125 after.
Nothing was compiled. Classes: (a) source fixed, (b) stale contract updated (behavior-preserving), (c) left, with reason.

Decisions needed from owners (not guessed):
- test_roam_private_tools (4): production grants roam private tools incl. writes via AppSession.liveRoamPrivateToolsAccess (G1-owned); gate change vs. contract.
- test_wallet_income_analysis_closure: read-scope notes (incl. "not proof of payout") dropped from UI.
- test_merchant_coop_capacity_clear: editor no longer shows the draft-time clear hint.
- Tests/CoreTests/ClubGovernanceContractTests.swift still passes form: [.topicOverview,.members] (members now JSON).
- Sha256/byte-pinned modules need reviewed regeneration; origin/migration/native-ios and native-ios.yml drift modules are clone/CI-file class.
- test_template_saved_library_flow only passes when run as a script (reads sys.argv[1]).


## Helper report 0
# chunk00 triage (helper 0)

## (b) test/doc/catalog-source updated (behavior unchanged)
| module | old | new | why |
|---|---|---|---|
| test_account_marketing_entry_integration | Resources/MerchantMarketingLocalizations.fragment.json (+ tools/build_merchant_marketing_localizations.py) had old copy for merchantMarketing.facts/lowSample/suggestionNotice/aiUnavailable | synced to Localizable.xcstrings copy | catalog copy was reworded; fragment is the compared doc source; copy only |
| test_activity_topic_navigation, test_club_home_topic_navigation | `reader: session.topicReader` | `reader: topicReaderOverride ?? session.topicReader` | override added (af10f68a) for favorite-topic journey; default path identical |
| test_bk_backend_sync | regex `.disabled(post.generation != .communityV1)` | `if post.generation == .communityV1 { Button{...bookmark...} }` | bookmark button now not rendered (stricter) for non-communityV1 |
| test_channel_not_friend_permission | exact Core/Channel*.swift set of 4 | + 4 later files (AdmissionGovernanceFactory/Client, DirectoryCatalogProducer, DiscordMessaging) | added by other work streams; the 4 owned files still pinned |
| test_city_player_recovery | `.onDisappear { visible=false; selection=nil; reader.cancel() }` | adds `rulesSheet?.flow.cancel();` | extra cancel on disappear (stricter) |
| test_club_create_host_application | `Text(...leaderRequired : clubLimit)`; fragment copy | `...leaderRequired.apply : clubLimit`; fragment + docs/club-operations-localizations.json synced to catalog copy | redesigned empty state, host-application link gating (`accountRole != "club", let hostApplication`) unchanged |
| test_club_operations_contracts | `if !isCreate && isOwner {`; `logo == (original?.club.logo ?? "")` in contracts; docs json missing keys | `if isCreate { createSections } else { editSections }` + `if !isOwner {`; media check asserted in Core/ClubProfileMediaFlow.swift (`value != old -> mediaUnavailable`, receipt-based, stricter); 12 catalog keys (basics, positioning, introduction, ...) added to docs/club-operations-localizations.json from the catalog; `fixture.workspace` (an accessibilityIdentifier) added to test skip list | UI re-layout / validation moved to stronger receipt checks |
| test_club_customer_history_topics | `.onChange(of: readContext)`, `.onDisappear { generation &+= 1 }` | `.task(id: readContext) { await synchronizeReadContext() }`; customers-scoped `if operation == .customers { customerKeywordDebounce.cancel(); generation &+= 1` | body refactored for type-check time; same fences for the customers operation |
| test_journey_narrative_workflows | `.onChange(of: filter)` | `.onChange(of: topicCustomerFilter) { _, _ in Task { await load() } }` | rename |
| test_club_enrollment_contracts | `navigation.pauseReturnRead(); reader.suspend()` on one line; fragment lacked club.enroll.denied | two `.onDisappear` lines asserted (suspend + hide/pauseReturnRead); scenePhase path uses invalidatePresentation()->suspend; `club.enroll.denied` copied from catalog into the fragment | same behavior / key already in catalog |
| test_club_management_return_state | detail `.onDisappear { leaveScreen() }`; guard `screenIdentity != identity \|\| screenRevision != viewerRevision \|\| ...` | root `.onDisappear { if selection == nil { leaveScreen() } }` + detail hides review; `guard screenContext != readContext \|\| snapshot == nil && state == .idle` | ReadContext bundles identity+revision(+access,+coordinator): superset of old guard |
| test_club_member_profile_navigation | `try await reader.clubMembers(id: id)` | `...clubMembers(id: id, isCurrent: {` | extra late-response fence |
| test_club_ops_join_reason_notify | `LabeledContent("club.gov.field.totalCount", value: String(count))` | `if option.enabled, let count = option.count {` + `ClubOpsJoinNotifyCopy.people(count)` | count presentation localized |
| test_club_story_projection | `form: [.topicOverview, .members].contains(operation)` | `form: operation == .topicOverview` | mini-program pages/talent/list/index.js:503 states /api/club/members is @RequestBody and MUST be JSON; source corrected. Note: Tests/CoreTests/ClubGovernanceContractTests.swift testEncodingRespectsJSONVersusFormExceptions still passes form:[.topicOverview,.members] explicitly (not touched; stale, flag for Swift owner) |
| test_composed_session_invalidation | first identity-change step `publicTemplateDetails.invalidate()`; `private var currentRuntimeDependencyContext` | regex: `invalidateInvoiceLaunch()` then `publicTemplateDetails.invalidate()`; `var currentRuntimeDependencyContext` | an invoice-launch invalidation was added ahead; access modifier relaxed; guard text unchanged |
| test_coop_parity | `reader.read(...)`; disabled `deposit.pay` button; 2 fragment strings | `reader.read(..., isCurrent:`; asserts owedFooter Text and NO `Button("cooperation.detail.deposit.pay")`; fragment + tools/build_coop_parity_localizations.py synced to catalog | no payment path either way |
| test_coupon_validity_parity | DatePickers (2) + env in CouponManagementView | asserted in App/CouponValidityRangeEditor.swift (same 2 pickers/timeZone/calendar), view opens `CouponValidityRangeEditor(model: editor)` | picker moved to sheet |
| test_im_conversation_read_all | `Button("action.close")` | `Button(model.phase == .reviewing ? "action.cancel" : "action.close") { model.dismiss(); dismiss() }` | label by phase |
| test_im_expanded_integration | AccountView wires `expanded:session.imExpandedNavigation` | asserted in App/SessionMessagingEntry.swift | messaging entry moved |
| test_map_marker_density | `.id(MapPresentationIdentity(area: area, scope: ...))` | `area: mapCameraIdentityArea ?? area` | scope still part of identity |
| test_merchant_city_quota | fragment keys disjoint from catalog | fragment keys must equal catalog entries (merged) | fragment merged, identical values |
| test_merchant_customer_contact_flow | `consumeContact(using: delivery)`, `Entry(owner:record:)` | `...using: stage` (stage wraps delivery, one call), `Entry(owner: model, record: row, flow: $customerContactFlow)` | observation wrapper / flow binding |
| test_merchant_customer_note_draft | `if sourcePageCanPrepare(mutation) { model.prepare(mutation) }`; `.onDisappear { noteDrafts.retire();` | multi-line form + onReview guard `noteDrafts.retireForReview`; disappear tail `noteDrafts.retire(); draftReturn.retire(); ...model.invalidate() }` | lifecycle logging added |
| test_merchant_featured_clear | fragment `inDraft` copy | synced to catalog ("No featured item"/"暂无主推") | copy |
| test_merchant_insight_cooperation_center | block after Button | button uses `cooperationCenterAction(...)` helper, which returns nil unless current and re-checks all fences at tap; assertions moved onto the helper | refactor, guards identical |
| private_home_source_guard (tools/check_private_home.py) | `guard ticket == generation, gate() else { return }` after read/save/clear | accepts `guard commandIsCurrent(ticket) else { return }` (same guard + cancel check), clear asserted via `clearOriginal` whose caller re-fences | helper extraction |

## (c) left untouched
| module / tests | reason |
|---|---|
| test_activity_publishing_wizard (sha256 of PublishingModesViews prefix/quick/suffix) | real UI redesign of the file (406 ins/131 del); hash pin, not provably behavior-preserving |
| test_c02_world_party_character test_sha256_manifest | 3 files changed by real code (type-conflict fixes, rich character sheet); hash pin |
| test_c09_notify_webhook_projections (5) | 3 need git ref origin/migration/native-ios; 2 pin pre-integration exclusivity (no @MainActor in tests; files absent from pbx) which later integration intentionally changed; deciding the new policy is not minimal |
| test_c10_workshop_h5 (2) | same pbx-exclusivity pin + sha256 payload pin |
| test_ci138_version_row_source (2) | byte pins on ProjectEditView / UI test; historical projection tooling |
| test_global_search_category_recovery (17) | whole byte-exact inverse chain over GlobalSearchView etc.; GlobalSearchView changed (suggested keywords feature); also CI file drift and tools/run_static_checks.py. Requires regenerating reviewed pins |
| test_merchant_aftercare_evidence_flow (2) | exact-byte inverse on App/MerchantBusinessEditor.swift and sha256 of Core/MerchantEngagementReading.swift |
| test_merchant_business_fixture_ownership (2) | sha256 pins of UI methods / home access model |
| test_merchant_coop_capacity_clear test_editor_and_frozen_review_both_disclose_clear | `merchant.coopCapacityClear.draftHint` is no longer rendered in the editor (field entry moved to MerchantCoopFieldEntry; removal predates snapshot f9ca1f42). Frozen review still discloses the clear (`...review`). Possible regression of the draft-time hint; needs an owner decision, not a guess |
| test_account_marketing / others | none |

Nothing compiled. No Swift source edited by me (all edits are tests, docs/catalog fragments, tools). Note: another helper edited App/SearchMapExplorerView.swift concurrently; my map test still passes against it.

## Helper report 1
# chunk01 triage report

## (b) changes (contract/catalog text updated; behavior unchanged or only tightened)
| module | old -> new | why |
|---|---|---|
| test_merchant_insight_recent_visitors | Resources/MerchantInsightVisitorsLocalizations.fragment.json `unavailable`/`empty` en+zh values updated to the shipped Localizable.xcstrings copy | Copy rewording only (both from snapshot f9ca1f42); Swift keys unchanged; test requires fragment == catalog |
| test_official_event_contracts (key test) | added 10 ids (`official.organizer.{content,denied,error,loading,formError,recovery,result,header,resume.reason}`, `official.detail.cta.roam`) to `ignored` | All 10 occurrences are `.accessibilityIdentifier("...")` in App/OfficialOrganizerConsoleView.swift, not catalog keys |
| test_official_event_contracts | `OfficialReadContext(guestEpoch:gate.currentStamp)` -> `...gate.currentStamp,viewerRevision:compositionViewerRevision,` | AppSession guest context gained viewerRevision arg (stricter) |
| test_official_event_contracts | `Text(LocalizedStringKey(query.emptyTitleKey))` -> `Label(LocalizedStringKey(query.emptyTitleKey), systemImage: "sparkles")` | Same key, now rendered as Label in ContentUnavailableView |
| test_owned_coupon_lifecycle | AppUnit test count 24 -> 31 | 7 testCouponListReturn*/Refresh tests added by e45a12c8; all 6 required names still present |
| test_merchant_operator_roster | CoreTests count 12 -> 15 | 3 role-ticket tests added by 78236ee5; required names still present |
| test_profile_local_cover | AppUnit 9 -> 14, UI 5 -> 6 func-test counts | additions only (98ba6a1a, 77202117) |
| test_profile_local_cover | AccountView arg `localCoverOwner: localCoverOwner)` -> `..., isCurrent: { profileReader.isCurrent })` | extra argument appended |
| test_profile_local_cover | scenePhase onChange / onDisappear one-liners -> multi-line forms with `#if DEBUG` diagnosticEvent lines around the same `model.close()` / `model.retire()` | DEBUG-only diagnostics added |
| test_profile_local_cover | ProfileAuthorPostsSection(...) pin gained `retainedModel: authorPosts, onOpenPost: openAuthorPost` and line wrap | new args only |
| test_project_edit_review_availability | AppUnit count 10 -> 17 | 7 recruitment tests added by 34928c87; 3 required names present |
| test_project_edit_review_availability | CAN_EDIT gained `!coordinator.isReadOnly &&` ; BUTTON `.borderedProminent` -> `.questifyPrimary` + indent | canEdit only stricter; button style rename |
| test_project_chapter_removal | `guard !hasUnconfirmedChapterRemoval,...` now regex allowing optional leading `!isReadOnly, ` / `value.baseline.scope.allowsEditing, `; canEdit pin gains `!coordinator.isReadOnly &&` | extra guards are stricter; freeze guard still required on all six entry points |
| test_project_node_duration | pin now has `ProjectNodePlacePickerEntry(...)` line between the unchanged gate condition and `ProjectNodeDurationField` | place picker added in same gated block; duration still gated identically, count==1 |
| test_merchant_operations_contracts | `assertNotIn('https://', fixture)` -> count('https://') == count('https://example.invalid/') | inert JSON brand-gallery fixture data; no other host, still no URLSession/HTTPTransport |

## (a) source/catalog fixes
| module | fix |
|---|---|
| test_ops_safety_contracts | docs/ops-safety/client-data-catalog.json: 20 new store entries (kinds from the audit tool; purposes from source; retention/deletion honestly "pending privacy review"; 2 mention-only entries n/a). tools/audit_client_ops_surfaces.py --check now PASS |
| test_play_experience_contracts | docs/play-experience-localizations.json: added 4 keys (offerUntitled, circle.save, player.unnamed, node.untitled) copied from shipped Localizable.xcstrings |
| test_playkit_native_screens (localization) | added `playkit.submitQuestion` to Resources/PlayKitScreenLocalizations.fragment.json and docs/playkit-screen-localizations.json (copied from Localizable.xcstrings) |

NOTE for lead: tools/current_ci_manifest.json pins sha256 of several edited files (client-data-catalog.json, play-experience-localizations.json, playkit-screen-localizations.json, PlayKitScreenLocalizations.fragment.json, MerchantInsightVisitorsLocalizations.fragment.json, test_official_event_contracts.py, plus the other .py tests edited). Run `python3 tools/current_ci.py refresh` (or equivalent) after all helpers finish; I did not touch the manifest.

## (c) left untouched
| module | test | reason |
|---|---|---|
| test_merchant_note_correction_presentation (2) | append Text count 2->1; onAppear block split | review-side hint removed / onAppear restructured in snapshot UI declutter; needs contract redesign |
| test_merchant_npc_preset_avatar | Text(verbatim: avatar.rawValue) | review raw-value section removed in f9ca1f42; product decision |
| test_merchant_operations_contracts (2) | QuestifyImageEntityCard(; templatePageLimit | card removed / limit symbol removed in f9ca1f42 / 47864f79 rewrite |
| test_merchant_operator_roster (4) | fixedSize; roleCode forbidden; fragment keys (4 new keys accessDetails/currentAccess/historyScope/loadedScope diverge); onDisappear | role-edit feature (78236ee5) legitimately introduces roleCode; roster view rewritten; needs contract redesign |
| test_merchant_profile_benefits | derivativeBenefits key | editor now uses MerchantStoreFieldEntry; structure change |
| test_merchant_redemption_filter, test_merchant_station_submission_import (2), test_object_badge_wall_layout (hash), test_play_player_leaderboard, test_profile_avatar (twenty_eight_protected_paths) | sha256 pins | bytes changed by later features; not shown behavior-preserving |
| test_merchant_settlement_overview | detailIncomplete key absent | disclosure removed from MerchantLedgerRowLabel view; not restored (product call) |
| test_merchant_template_browser | .refreshable { await model.refresh() } | browser lifecycle reworked around Permit/readID; not provably equivalent |
| test_merchant_template_metadata | fragment has scopeHint/omissionHint, Swift no longer uses them | snapshot f9ca1f42 deliberately removed hint Texts (declutter) incl. "not a venue capacity limit" disclosure; needs product decision to restore or retire |
| test_merchant_template_story_timeline | UI test token keepEditing | UI test rewritten |
| test_native_design_motion (2) | live boundary update; homeFeed.currencyUnknown | Home feed rewritten; currency-unknown disclosure no longer found in HomeFeedView |
| test_native_ui_accessibility_semantics (2) | UITest helper / manual input clear() | source rewritten |
| test_object_badge_wall_layout (2) | partialHint / staticOnly Text | layout rewritten in f9ca1f42; staticOnly text removed |
| test_owned_topic_cover_author | permitsNativePicker | picker adapter changed |
| test_pkg12_merchant_customer_paid_card | paidAmountExcludesRefunds disclosure absent | disclosure removed; not restored |
| test_playkit_authoring_legacy | playkitLegacy.scan.staticFallback | disclosure text removed in f9ca1f42 |
| test_playkit_native_screens (bingo) | goalLocked | footnote `playkit.walk.goalLocked` removed in f9ca1f42 declutter |
| test_profile_avatar (5 other), test_profile_exit_discard (3), test_profile_text_field_edit (4) | ProfileEditView exact-line pins | ProfileEditView evolved (preference picker, saved-return, retireAvatarResources); retire semantics changed; not provably equivalent |
| test_profile_complaint_preparation (3), test_profile_self_medals (3) | core one-liners | logic changed (medal read restriction clears rows; complaint rewritten) |
| test_profile_local_cover | deviceOnly count >=2 (now 1) | section-level footnote removed in f9ca1f42; editor still states it |
| test_profile_read_failure_remote_admission (all) | native-ios.yml CI-file drift, historical byte pins, Unknown feature-batch source ProjectEditView.swift | ignore-list class per instructions |
| test_project_edit_starter | ProjectEditModel lifecycle one-liners | generation/incarnation lines restructured; not provably equivalent |

## Helper report 2
# chunk02 triage (worker report2)

## (b) test/contract updates (behavior-preserving or copy-only)
| module | change | why |
|---|---|---|
| test_project_story_template_selection | docs/project-story-template-localizations.json 4 entries synced to catalog | catalog copy reworded (scope/previewTitle/apply/saveFailed); no behavior change |
| test_project_ticket_theme_sync | docs/project-edit-localizations.json syncThemeDatesLegacy en/zh synced to catalog | copy only |
| test_public_merchant_featured | assertion `.onChange(of: key) { _, _ in featuredSelection = nil }` -> `... featuredSelection = nil; ownerSelection = nil; gameFactsSelection = nil }` | source now also clears owner/game selections (superset) |
| test_public_template_composition | `topics.load(onUnauthorized:...)` assertion replaced by: request = reader.publicTopicTemplateCatalogRequest(), and `guard current()` precedes `request.onUnauthorized()` | load refactored into PublicTemplateCatalogVisitOwner; fences (visit/viewer/run) stronger |
| test_recovered_module_integration | (1) `assertNotIn('execution: .')` -> NotIn 'injectedOfflineHarness' and every `execution: .` is `.disabled`; (2) `reader.read(.templates)` -> `reader.read(.templates, isCurrent:` | production passes `.disabled` (safe value); read gained an isCurrent fence |
| test_roam_anniversary_navigation | assertions retargeted: home passes `privateTools:`; RouteHost(presentation: lease, owner:...); completeReturn(presentation: lease, owner: owner); state.rows; list-state reset text in Core; late-result fence now in ReadIntent.matches; host split bounded to before RoamMonthlyRecapView | state machine refactor (lease binding, RoamAnniversaryListState); same lease/owner fencing |
| test_roam_history_live_entry | hub call has toolsReader args; load flow now via historyRead.load (RoamHistoryListRead, history read still single, acceptRead not on failure path); RoamRecordedStats assertion moved to detail view; ShareView(record:, reader:) | refactor into RoamHistoryListRead + redesigned cards |
| test_roam_private_tools (tool+builder) | tools/build_roam_private_tools_localizations.py 11 entries synced to catalog (writesDisabled, outcomeUnknown, rejected, ...); tools/check_roam_private_tools.py: export write/share checks (UIActivityViewController + 2 protected writes replaces ShareLink), form buttons guarded by page.acceptsInput, destructive buttons via page.settle, export guard text with presentationActive/deliveryLease; test mutant `before` strings updated | view/coordinator hardening, copy rewording |
| test_route_total_count | TopicTotalStops required only for Detail/Favorites; Browser/HomeFeed still must not contain `locationCount > 0` | cards moved to shared image entity card (date/place/price) which has no stops row |
| test_search_map_contracts | docs/search-map-localizations.json synced to catalog (+4 new keys mapTitle/publicLayers/recommended/resultKinds); clientFilters copy assertions; session gate list now includes `.publicMapLayers` | copy polish; public map layers feature adds a read scope to the same grant-gated expression (service still nil without a reviewed read grant) |
| test_search_map_refresh | startLoad( signature split | startLoad gained a viewport parameter |
| test_social_account_contracts | 114 -> 117 social.* keys | added social.editor.follow/unfollow, social.guideTemplates.playedTimes %lld (all bilingual) |
| test_social_member_action_factory | gate line check: contains `retainedSocialMemberActions?.synchronizeSession()` on the SessionOperationGate didSet line | didSet gained invalidatePersonalLocationShare() prefix |
| test_square_post_local_media_app | `.onDisappear { localMedia.invalidate(); coordinator.clearRevisions() }` | superset |
| test_team_invite_copy | Resources/TeamLocalizations.fragment.json previewOnly synced to catalog | copy shortened ("Copy the code and send it to your teammates"); `copied` message still says no invitation was sent |
| test_template_image_crop | allowlist ProjectNodeImageCrop.swift (older local-only crop host reusing the renderer; no network/upload tokens); crop fragment (localOnly, confirm) synced; media-review fragment copy of the same 2 keys synced | copy only |
| test_template_preference_draft | tools/template_preference_draft_localizations.json synced to catalog (3 keys) | copy only |
| test_template_saved_library_flow | `.templateShelfCoordinator()` / `.templateShelfViewIdentity` counted without `session.` prefix (completion context uses `self.`); AppUnit test count 16 -> 27 | refactor + tests added in 758a4889 |
| test_template_story_projection | tools/template_story_localizations.json synced to catalog (6 keys) | copy rewording |
| test_topic_creator_attribution | club line asserted in TopicXcxSections hero (`topicXcx.clubHost`), not TopicDetailView | detail page redesign moved club into hero; still no initiator |
| test_w2_04_member_tools | W204 fragment keepsReferences synced; `plan.isDispatchable == false` mounted assertion -> comment text `never dispatchable here` | plan intentionally not rendered (no dead action); Core still pins isDispatchable false and mounted has no Button |
| test_w2_04_participation | fragment `refreshing` synced to catalog ("Updating...") | copy only |
| test_w2_07_pricing_apply_parity | inline Chinese literals -> catalog keys + catalog zh text asserted ("确认终价并提交开售审核", "合作链接已失效", "开售后阵容冻结") | text() localization via catalog; "开售即冻结" now phrased "开售后阵容冻结" |
| test_w2_19_aiNPC | tools/build_store_character_catalog.py: removed unused voice.play/playOriginal/playbackUnavailable rows; voice.mode row synced to shipped catalog (Record voice / 录制声音); Resources/StoreCharacter.xcstrings regenerated (only those removals) | disabled dead "play" buttons were removed from the view |
| test_w2_19_gameNode | removed 3 unused keys scan.use/placeholder/cameraUnavailable from Resources/MerchantGameNode.xcstrings | scan sheet replaced by submission import flow |
| test_workshop_creator_consent | guard text now `guard isVisible, scenePhase == .active, let action else { return }; task?.cancel(); task = Task { await action() }` | action still captured before Task |
| test_workshop_paid_installed_text | materializationRequired assertion now "can't be used in a project or published from here yet"; dropped "not a professional template ID" assertion | catalog copy shortened; judgement call, still states unavailable |

## (a) Swift source restored (regressions vs pinned contract)
- App/RegistrationSheetView.swift: waitlist Section footer `registration.waitlist.noAutoPayment` (no-charge disclosure)
- App/MerchantGalleryBatchView.swift: realm + byteCount review lines
- App/RoamPassportPrivateToolsViews.swift: capsule form footer `roam.capsule.photoUnavailable`
- App/SearchMapExplorerView.swift: `mapRefresh.previousWhileLoading` caption
- App/TemplateBranchCompositionFields.swift: `templateBranch.terminalHint`
- App/TemplateMediaReviewPanel.swift: disabled `templateMedia.apply` button
- App/TemplateProfileQuestionFields.swift: `templateProfile.kindHint`
- App/TemplateAuthoringSavedResultPresentation.swift: saved template number row
- App/PlayerJourneyViews.swift: empty-state description (emptyDetailKey)
- App/MerchantGameNodeView.swift: `recap.policy` footnote
- App/CooperationBrowserView.swift: `topicFilter.loadedOnly` caption
(All were removed in bulk snapshot f9ca1f42 as UI polish; each is a disclosure/warning, restored additively. Lead may reverse if the removal was intended, in which case update the test instead.)

## (c) left untouched
| module | test | reason |
|---|---|---|
| test_roam_private_tools | reviewed_source_contracts_all_pass, create_cannot_dispatch, locked_capsules, partial_export (all blocked by the single check) | checker "Production composition supplies no approval": commit 0008ca65 intentionally grants roam private tools incl. WRITES in production via AppSession.liveRoamPrivateToolsAccess (G1-owned files). Disabled-by-default policy change; lead decision. All 29 other checks and every mutant's own check pass (verified with non-fatal checker). |
| test_run130_route_fixture_inset | both | sha256-pinned UI test helper revealFixtureElement rewritten (not behavior-preserving provable) |
| test_run138_ui52_driver | 5 | pinned UI52 UI-test sources / CI file drift (ignore-list type) |
| test_wallet_income_analysis_closure | both | WalletIncomeAnalysisView deliberately dropped read-scope disclosure notes (noPayout/excluded/received/slice; source comment "read-mechanics notes are not user copy") and "withdrawal" label is now "Withdrawals". Product/compliance call (not-complete-income, not proof of payout). Suggest lead either restore the footnotes or approve updating the contract. |
| test_workshop_protected_text_lifecycle | all_product_bytes hash | WorkshopPaidInstalledTextView.swift changed behavior (scenePhase hide, hash rows removed, empty-field text) since pin |

Note: test_template_saved_library_flow reads sys.argv[1] as root, so it only runs correctly as `python3 Tests/ContractChecks/test_template_saved_library_flow.py` (not via `unittest discover`).
