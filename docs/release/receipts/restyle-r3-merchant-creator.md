# Restyle R3: merchant & creator (receipt)

Branch `restyle/r3-merchant-creator`, base `origin/ui/combined-r6` (f1115875e), with `origin/restyle/r6-system-rest` merged in at round 2. Brief: `design/handoff-r2:docs/briefs/restyle-native-r1.md`. Spec: `design/native-ios-r1:docs/design/native-ios-r1.md`.
Scope: 436 files (`Merchant*`, `MerchantKit/`, `Coop*`, `Cooperation*`, `Workshop*`, `Mod*`, `Creator*`, `Project*`, `Publishing*`, `Editor*`, `Template*`). None of them is in plan §4 (P1–P5). No `App/DesignSystem/*` file is touched.

## Batch 1 (33 files): merchant workbench and the most-used merchant screens
Files were chosen by how many restyle issues they had, starting with the workbench (`MerchantHomeView`).

### Before → after patterns
- `.font(CYTypography.x)` / `.font(Theme.Font.x)` (static, not Dynamic Type) → `.cyText(.x)` (scaled with the text style).
- `.font(CYTypography.x.weight(.w))` → `.cyText(.x, weight: .w)`.
- `.cyText(.caption)` (11 pt, caption2) and `.cyText(.micro)` (10 pt) → `.cyText(.meta)` (12 pt, `.caption`): nothing below `.caption`.
- `.font(.caption2…)` → `.font(.caption…)`.
- `MerchantOpsWp03Panel.copy(font: Font)` → `copy(style: CYTextStyle)` with `.cyText(style)`.
- Workbench (`MerchantHomeView`):
  - The access gate (not configured / not signed in), the access error and the shared `MerchantFailureView` → `ContentUnavailableView` with one `.borderedProminent` action (retry / 申请入驻 / 登录). The accessibility identifiers are unchanged.
  - `MerchantInlineFailure`: the retry pill → a system `.bordered` button (44 pt).
  - The inactive-identity actions → `.borderedProminent` (primary) plus `.bordered` (secondary) system buttons.
  - The quick-action circles lose the drop shadow.
- Title truncation: `MerchantInboxPreviewSection` item title and `MerchantTopicDetailSection+Wire2` template title use `lineLimit(1)` → `lineLimit(2)`.
- Kept as they are: the N-07 hidden workbench title, every function, request, state, navigation target, Chinese copy, `CYMotion`, and the identifiers.

### Files changed
- `App/MerchantAftercareParityViews.swift`
- `App/MerchantAftercareProgressView.swift`
- `App/MerchantAndPublishAuthoringSectionView.swift`
- `App/MerchantAuthoringLocalization.swift`
- `App/MerchantBundleReservationsView.swift`
- `App/MerchantBusinessViews.swift`
- `App/MerchantCityNodeCreateView.swift`
- `App/MerchantCoopCenterView.swift`
- `App/MerchantCustomerDetailSections.swift`
- `App/MerchantCustomerListParityViews.swift`
- `App/MerchantDecorAndShopApplyWizardSectionView.swift`
- `App/MerchantGameNodeView.swift`
- `App/MerchantHomeView.swift`
- `App/MerchantInboxPreviewSection.swift`
- `App/MerchantKit/MerchantR1Kit.swift`
- `App/MerchantLedgerParityViews.swift`
- `App/MerchantLedgerSettlementOverview.swift`
- `App/MerchantMarketingHomeSections.swift`
- `App/MerchantOnboardingCategoryPicker.swift`
- `App/MerchantOnboardingView.swift`
- `App/MerchantOperatorRosterSections.swift`
- `App/MerchantOpsWp03Panel.swift`
- `App/MerchantOrdersView.swift`
- `App/MerchantPayoutAccountView.swift`
- `App/MerchantPerkTemplatesView.swift`
- `App/MerchantPredictionInboxView.swift`
- `App/MerchantProjectsView.swift`
- `App/MerchantRedemptionProgressView.swift`
- `App/MerchantReviewCard.swift`
- `App/MerchantSettlementProgressView.swift`
- `App/MerchantStoreCharacterView.swift`
- `App/MerchantTopicDetailSection+Wire2.swift`
- `App/MerchantVerifyRecordsSections.swift`

### Held back: frozen by contract-check hashes (resolved in round 2; see "Re-pinned contract tests")
These files are guarded by whole-file SHA-256 checks (`Tests/ContractChecks/test_merchant_station_submission_import.py` `PROTECTED`, among others). Any edit fails a currently-passing test, so batch 1 reverted its edits to them:
- `MerchantContentViews.swift`
- `MerchantBusinessEditor.swift`
- `MerchantEngagementViews.swift`
- `MerchantOperationsViews.swift`

Other files in this package that have frozen hashes somewhere in ContractChecks:
- `CoopFinanceSummarySection`
- `MerchantAftercareEvidenceFlow`
- `MerchantBusinessRecordViews`
- `MerchantContentEditor`
- `MerchantEngagementComposer`
- `MerchantEngagementViewModel`
- `MerchantEvidenceSelectionView`
- `MerchantImageCropView`
- `MerchantNPCViews`
- `MerchantOperationsEditor`
- `MerchantOperatorInvitationReceiptView`
- `MerchantReading`
- `MerchantReviewPhotoGallery`
- `MerchantStationLiveCodeView`
- `MerchantStationServiceTimeFields`
- `ProjectChapterRemovalPresentation`
- `ProjectClubLeadFields`
- `ProjectEditDetailForms`
- `ProjectEditIssueNavigation`
- `ProjectEditNodeDescriptionField`
- `ProjectNodeImageCrop`
- `ProjectThoughtDefinitionsEditor`
- `TemplateAuthoringMineView`
- `WorkshopPaidInstalledTextView`

Not every one of these hashes is enforced by a currently-passing test. Coordinator decision (round 2): yes. Update the hash or text pin in the same commit and list it here. Never weaken a behavioural assertion.

`MerchantCustomerDetailSections.swift:43` keeps `.font(CYTypography.dataXL)` because `test_pkg12_merchant_customer_paid_card` asserts that literal line.

## Batch 2 (34 files): type pass on Coop/Cooperation, Mod, Workshop, Creator, Template, Project, Editor
### Patterns
- These are the same type rewrites as batch 1.
- Added in this batch:
  - `.font(CYTypography.x.monospaced())` → `.cyText(.x).monospaced()`;
  - `.font(c ? CYTypography.a : CYTypography.b)` → `.cyText(c ? .a : .b)`;
  - `CooperationContextualViews.valueLine(font: Font)` → `valueLine(style: CYTextStyle)`.
### Files changed
- `App/CoopSettlementDetailView.swift`
- `App/CooperationBrowserView.swift`
- `App/CooperationContextualViews.swift`
- `App/CooperationFlowEditors.swift`
- `App/CooperationInviteActionSections.swift`
- `App/CooperationInviteDetailView.swift`
- `App/CreatorApplicationView.swift`
- `App/CreatorContentViews.swift`
- `App/CreatorMaintenanceViews.swift`
- `App/EditorKitCards.swift`
- `App/MerchantInStoreGameDraftSectionView.swift`
- `App/MerchantOfferWithdrawalOriginalView.swift`
- `App/MerchantReviewSummaryHeader.swift`
- `App/MerchantTemplateBrowserView.swift`
- `App/ModInstallationQaEditorView.swift`
- `App/ModInstallationSavedRehearsalView.swift`
- `App/ModInstallationTemplateEditorView.swift`
- `App/ModInstallationView.swift`
- `App/ModInstalledTextReadView.swift`
- `App/ModOwnedContentReportView.swift`
- `App/ModUpgradeView.swift`
- `App/ModVenueOperationsView.swift`
- `App/ProjectEditFlowParity.swift`
- `App/ProjectEditOverviewKit.swift`
- `App/ProjectEditView.swift`
- `App/PublishingAIDraftSheet.swift`
- `App/PublishingAIPromptControls.swift`
- `App/PublishingContextHandoffViews.swift`
- `App/TemplateAuthoringRuleFields.swift`
- `App/TemplateDetailXbChrome.swift`
- `App/TemplatePlayerPreviewPager.swift`
- `App/TemplateQuestionMediaPickers.swift`
- `App/WorkshopCommerceView.swift`
- `App/WorkshopLicenseLibraryView.swift`

### Held back: frozen by contract checks (resolved in round 2)
- `PublishingModesViews.swift`: section hashes in `test_activity_publishing_wizard`.
- `CoopRelationDiscoveryView.swift`: normalized hash in `test_coop_fixture_lifecycle_diagnostic`.
- Literal line asserts are kept as `.font(CYTypography.x)`:
  - `CooperationBrowserView.swift:122` (`test_x01_existing_entry_ui_closeout`);
  - `CreatorContentViews.swift:41` (`test_creator_content_contracts`).
### Verification
- Contract checks: 0 new failures against r6.
- Typography lint: PASS (Theme.Font 61 → 39).
- Scaffold: PASS.

## Verification, batch 1 (no Swift compiler in the cloud; `acceptance.yml` does not exist yet)
- Contract checks (`python3 -m unittest discover -s Tests/ContractChecks`): 85 failures, 100 errors. That is identical to the base (diffed by test id), so there are 0 new failures.
- `tools/check_typography_lint.py`: PASS (one count below the baseline).
- `tools/check_scaffold.py`: PASS.
- `tools/contract_ratchet.py --check`: 185 against a baseline of 184. The extra failure (`test_workshop_paid_professional…bounded_paging`) also fails on the base r6, so it is not from R3.
- Acceptance screens: `docs/port/accept/r3-merchant-creator.txt` (20 fixture routes).
- The acceptance run is pending; it starts once `.github/workflows/acceptance.yml` lands.

## Round 2: structural native pass (batches 3–7)

**Merged:** `origin/restyle/r6-system-rest` (aa235bbab, coordinator decision 2). It brings:
- `CYEmptyState` / `CYStateView` / `CYErrorState` rendered as `ContentUnavailableView`, so the ~99 R3 call sites are native without per-site edits;
- `CYCard` radius 12 with no shadow;
- semantic text-style tokens;
- `cySheet`, `cyCardRow`, `CYContentState`.

**`origin/ci/acceptance` not merged** (coordinator decision 3). It has no green run: all three runs (45382432691, 45382725772, 45382894882) concluded `failure`. It is also unrunnable from here:
- the workflow triggers on `port/**`, `ui/combined-r7` and `ci/acceptance` only;
- `workflow_dispatch` returns 403 for this integration (A0 receipt).

The scan covered all 436 owned files. A file with nothing left to change was left alone. 142 files changed in round 2, in five commits of ≤ 40 files.

### Before → after patterns (round 2)

| pattern | before → after | count |
|---|---|---:|
| sheet detents (spec §3.4) | a `.sheet { X }` with no detents in the closure or in the presented type → `{ Group { X }.presentationDetents([...]).presentationDragIndicator(.visible) }`. Pickers, filters, confirmations and removals get `[.medium, .large]`; editors and long forms get `[.large]`. Camera, photo and share pickers are skipped. | 93 sheets |
| title mode unset (spec §3.1) | pushed `.navigationTitle(…)` / `.appNavigationTitle(…)` with no mode → `+ .navigationBarTitleDisplayMode(.inline)` | 90 sites |
| literal radii (spec §2.3) | `RoundedRectangle(cornerRadius: n)` → `CYRadius.inner` (≤ 10) / `.card` (11–16) / `.hero` (≥ 18), always `.continuous`; the settings tile 15 → `.inner` | 39 |
| glass on cards (spec §3.3) | `.background(.regularMaterial, in: RoundedRectangle(…))` on content cards (city node hub/create, coop center) → `CYColor.bgSurface` + `CYRadius.card` | 6 |
| static fonts, including the formerly frozen files | `.font(CYTypography.x)` → `.cyText(.x)`; `.x.weight(.w)` → `.cyText(.x, weight: .w)`; ternaries → `.cyText(c ? .a : .b)`. R3 now has **0** `CYTypography` / `Theme.Font` / `.caption2` sites. | 50 |
| custom state views (spec §3.5) | the hand-built VStack states in `MerchantCityNodeCreateView.stateView`, `MerchantCoopCenterView.emptyView` / `issueView` (sign-in, denied, failed) and `MerchantGameNodeView.stateView` → `ContentUnavailableView` with a system `.bordered` retry or a `.borderedProminent` refresh, 44 pt; identifiers kept on the same elements | 6 |
| system buttons (spec §3.6) | `.buttonStyle(.questifyPrimary)` (custom capsule) → `.borderedProminent` in `Merchant*` files (graphite tint on light, so the label stays legible); `CYSecondaryButtonStyle()` → `.bordered` (`PublishingManagementViews`) | 23 + 3 |
| destructive role (spec §3.2) | buttons that remove, revoke or withdraw and lacked a role → `role: .destructive`: `merchant.business.removeTag` / `removeOperator` / `revokeInvite`, `merchant.content.withdraw` / `cancelClaim`, `merchant.noteDraft.clear`, `merchant.aftercareRemoveEvidence.remove`. Each one already runs through a confirmation (prepared review sheet, editor or `confirm…` flag). | 7 |
| List/Form (spec §3.2) | chapter-invitation detail (`MerchantChapterInvitationViews`): `ScrollView { VStack … .padding() }` → `Form { Section { … } }.listStyle(.insetGrouped)` (a detail page with `LabeledContent` rows) | 1 |

### Audited and left as they are (with the reason)
- **Destructive actions:**
  - 88 `role: .destructive` sites. Every one that commits to the server goes through a confirmation first: `prepare(…)` → review sheet, `.confirmationDialog`, `cyModalConfirm` or a removal controller.
  - The rest are local draft edits (removing an editor row or a picked image) that 保存 still has to commit.
  - No confirmation was added on top of an existing one.
- **ScrollView pages:**
  - 24 left. They are card feeds (merchant content entry cards), hero screens (`Cloud25Screen`), previews and pagers, transcripts, galleries and the rule editor host. These are content, not settings or detail pages (spec §3.2 and §3.10).
  - 260+ R3 screens were already `List` / `Form`.
- **`CYPillButton`:** 212 call sites are kept. Spec §3.6 keeps it as the call-site API and re-points it centrally to `.borderedProminent` / `.bordered` / `.borderless`, which is R6 / R0 work (component request 1).
  - The `.questifyPrimary` sites outside `Merchant*` are kept too (`Project*`, `Template*`). They can render in the player-dark domain, where a near-white-tint `.borderedProminent` would be white on white (spec §2.2 gotcha).
- **Tab roots:** `MerchantHomeView`, `MerchantMarketingView`, `MerchantProjectsView` and `CoopRelationDiscoveryView` keep their contract-pinned hidden bar titles (N-07). Spec §4.10 (the store name as the large title) changes those tests' behaviour, so it was not done in a visual-only pass.
- **`lineLimit(1)`:** the 10 remaining are meta lines, codes, dates and number tiles, not titles.
- **Fixture banners and the floating toast:** `.regularMaterial` is kept; they are chrome over content.

### Batch 3 (29 files): Merchant A–M, plus `MerchantStationServiceTimeFields` (pinned by the same test)
- `App/MerchantAICommerceFixtureHost.swift`
- `App/MerchantAftercareEvidenceFlow.swift`
- `App/MerchantAndPublishAuthoringSectionView.swift`
- `App/MerchantBrandImagesView.swift`
- `App/MerchantBusinessEditor.swift`
- `App/MerchantBusinessRecordViews.swift`
- `App/MerchantBusinessViews.swift`
- `App/MerchantCRMDateRangePicker.swift`
- `App/MerchantChapterInvitationViews.swift`
- `App/MerchantCityAddressChoice.swift`
- `App/MerchantCityNodeCreateView.swift`
- `App/MerchantCityNodeHubView.swift`
- `App/MerchantCityTemplateHandoffFixture.swift`
- `App/MerchantCityTemplateHandoffView.swift`
- `App/MerchantContentEditor.swift`
- `App/MerchantContentViews.swift`
- `App/MerchantCoopCenterView.swift`
- `App/MerchantCustomerContactEntry.swift`
- `App/MerchantCustomerContactFlow.swift`
- `App/MerchantCustomerDetailSections.swift`
- `App/MerchantDecorAndShopApplyWizardSectionView.swift`
- `App/MerchantDecorTagEditor.swift`
- `App/MerchantEngagementComposer.swift`
- `App/MerchantEngagementViews.swift`
- `App/MerchantFeaturedActivityPicker.swift`
- `App/MerchantGameNodeView.swift`
- `App/MerchantGamePlayerView.swift`
- `App/MerchantMarketingView.swift`
- `App/MerchantStationServiceTimeFields.swift`

### Batch 4 (26 files): Merchant N–Z and `MerchantKit/`
- `App/MerchantNPCFieldEntry.swift`
- `App/MerchantNPCFixtureView.swift`
- `App/MerchantNPCGreetingPreview.swift`
- `App/MerchantNPCKnowledgeDraftView.swift`
- `App/MerchantNPCMapPointView.swift`
- `App/MerchantNPCPresetPicker.swift`
- `App/MerchantNPCViews.swift`
- `App/MerchantOfferWithdrawalOriginalComposition.swift`
- `App/MerchantOnboardingView.swift`
- `App/MerchantOperationsEditor.swift`
- `App/MerchantOperationsViews.swift`
- `App/MerchantOperatorInvitationLandingView.swift`
- `App/MerchantPerkValidityCalendar.swift`
- `App/MerchantPersonalIncomeHandoff.swift`
- `App/MerchantPredictionInboxView.swift`
- `App/MerchantRegistrationAvailabilityPicker.swift`
- `App/MerchantReviewPhotoGallery.swift`
- `App/MerchantStationSubmissionImportView.swift`
- `App/MerchantStoreCharacterView.swift`
- `App/MerchantStoreFieldEntry.swift`
- `App/MerchantStoreIndustryPicker.swift`
- `App/MerchantTemplateAssistSheet.swift`
- `App/MerchantTemplateBrowserView.swift`
- `App/MerchantTemplateCategoryPicker.swift`
- `App/MerchantTemplateSuggestionEditSheet.swift`
- `App/MerchantTopicDetailSection+Wire2.swift`

### Batch 5 (29 files): Coop/Cooperation, Creator, Editor, Mod, Workshop, Publishing
- `App/CoopRelationDiscoveryView.swift`
- `App/CooperationBrowserView.swift`
- `App/CooperationFlowEditors.swift`
- `App/CreatorApplicationView.swift`
- `App/CreatorContentViews.swift`
- `App/CreatorMaintenanceViews.swift`
- `App/CreatorPostGameOutcomeView.swift`
- `App/EditorKitLists.swift`
- `App/EditorKitResults.swift`
- `App/ModInstallationQaEditorView.swift`
- `App/ModInstallationSavedRehearsalView.swift`
- `App/ModInstallationTemplateEditorView.swift`
- `App/ModInstallationView.swift`
- `App/ModInstalledTextReadView.swift`
- `App/ModVenueOperationsView.swift`
- `App/PublishingAIDraftSheet.swift`
- `App/PublishingManagementViews.swift`
- `App/PublishingModesFixtureSupport.swift`
- `App/PublishingModesViews.swift`
- `App/WorkshopCommerceView.swift`
- `App/WorkshopCreatorConsentView.swift`
- `App/WorkshopLicenseLibraryView.swift`
- `App/WorkshopOwnedLibraryView.swift`
- `App/WorkshopOwnedPackageView.swift`
- `App/WorkshopPaidInstallView.swift`
- `App/WorkshopPaidInstalledTextView.swift`
- `App/WorkshopPaidProfessionalView.swift`
- `App/WorkshopPurchasedLibraryView.swift`
- `App/WorkshopPurchasedUpgradeEntry.swift`

### Batch 6 (35 files): Project
- `App/ProjectAlbumImageAuthorField.swift`
- `App/ProjectAlbumPhotoRemovalButton.swift`
- `App/ProjectCategoryPicker.swift`
- `App/ProjectChapterAtmosphereFields.swift`
- `App/ProjectChapterAudioAuthorView.swift`
- `App/ProjectCityStoryNodeRemovalController.swift`
- `App/ProjectDraftNodeOverview.swift`
- `App/ProjectDraftStoryPreviewView.swift`
- `App/ProjectEditChapterRulesSection.swift`
- `App/ProjectEditDatePicker.swift`
- `App/ProjectEditDetailForms.swift`
- `App/ProjectEditModeReviewController.swift`
- `App/ProjectEditPendingPresentation.swift`
- `App/ProjectEditPreparedReview.swift`
- `App/ProjectEditStarterPresentation.swift`
- `App/ProjectEndingConditionPicker.swift`
- `App/ProjectInitialAttributesEditor.swift`
- `App/ProjectInitialStateEditor.swift`
- `App/ProjectMerchantDraftViews.swift`
- `App/ProjectNodeBusinessHoursField.swift`
- `App/ProjectNodeDurationField.swift`
- `App/ProjectNodeImageAuthorView.swift`
- `App/ProjectNodeNarrativeFields.swift`
- `App/ProjectNodePlacePicker.swift`
- `App/ProjectNodeRouteMappingEditor.swift`
- `App/ProjectNodeTemplateCreationField.swift`
- `App/ProjectNodeTemplateSelectionField.swift`
- `App/ProjectPendingNodeRemovalController.swift`
- `App/ProjectStoryAudioAuthorView.swift`
- `App/ProjectStoryImageAuthorView.swift`
- `App/ProjectStoryVariablePicker.swift`
- `App/ProjectTeamConfigurationEditor.swift`
- `App/ProjectThoughtDefinitionsEditor.swift`
- `App/ProjectTicketMeetingPointFields.swift`
- `App/ProjectTopicMediaHost.swift`

### Batch 7 (23 files): Template
- `App/TemplateAdditionalSampleBrowserView.swift`
- `App/TemplateAuthoringDetailForms.swift`
- `App/TemplateAuthoringIntroExperience.swift`
- `App/TemplateAuthoringMetadataSelectors.swift`
- `App/TemplateAuthoringPublishFlow.swift`
- `App/TemplateAuthoringSaveFlow.swift`
- `App/TemplateCreatorConfigurationView.swift`
- `App/TemplateDailyPoemEditor.swift`
- `App/TemplateMediaReviewPanel.swift`
- `App/TemplateMultiplayerPlanEditor.swift`
- `App/TemplateOptionalModuleManager.swift`
- `App/TemplatePhotoFrameEditor.swift`
- `App/TemplatePictureChoiceEditor.swift`
- `App/TemplatePredictionPlanEditor.swift`
- `App/TemplatePreferenceRemovalPanel.swift`
- `App/TemplateProfileOverrideEditor.swift`
- `App/TemplateProfileQuestionFields.swift`
- `App/TemplateQuestionMediaPickers.swift`
- `App/TemplateReactionRehearsalView.swift`
- `App/TemplateRootAuthoringView.swift`
- `App/TemplateSampleBrowserView.swift`
- `App/TemplateScanResponseEditor.swift`
- `App/TemplateTimerRehearsalView.swift`

### Re-pinned contract tests (coordinator decision 1; same commit as the files; no behavioural assertion changed)

| test | pin | why | commit |
|---|---|---|---|
| `test_merchant_station_submission_import` | `PROTECTED` SHA-256 for `MerchantContentViews`, `MerchantBusinessEditor`, `MerchantAftercareEvidenceFlow`, `MerchantEngagementViews`, `MerchantOperationsViews`, `MerchantStationServiceTimeFields`; `EDITOR_BASE_SHA` (`MerchantContentEditor` with the hunk swapped) | type tokens, inline title, sheet detents | batch 3 |
| `test_merchant_customer_contact` | `BASE_VIEW_SHA256` (`MerchantBusinessRecordViews` minus the insertion) | sheet detents | batch 3 |
| `test_merchant_aftercare_remove_evidence` | split anchor `Button("merchant.aftercareRemoveEvidence.remove", role: .destructive)` | destructive role | batch 3 |
| `test_pkg12_merchant_customer_paid_card` | expects `Text(verbatim: text).cyText(.dataXL)` | type token | batch 3 |
| `test_x01_existing_entry_ui_closeout` | expects `Text("cooperation.topicFilter.loadedOnly").cyText(.meta)` | type token | batch 5 |
| `test_coop_fixture_lifecycle_diagnostic` | normalized SHA of `CoopRelationDiscoveryView` (comment added) | type tokens | batch 5 |
| `test_creator_content_contracts` | expects `}.cyText(.body)…` before `creatorContent.issue` | type token | batch 5 |
| `test_workshop_protected_text_lifecycle` | SHA of `WorkshopPaidInstalledTextView` | sheet detents | batch 5 |
| `test_publishing_ai_prompt_suggestions` | expects `.navigationTitle("contextPublish.ai.title").navigationBarTitleDisplayMode(.inline)` | inline title | batch 5 |
| `test_activity_publishing_wizard` | `QUICK_SHA` and `SUFFIX_SHA` slices of `PublishingModesViews` | type tokens, sheet detents | batch 5 |

### Verification (round 2)
**There is no Swift compiler in the cloud.** Nothing in round 2 has been compiled.
- What was checked instead:
  - Every edited file was checked for balanced brackets with a string- and comment-aware scanner.
  - The sheet codemod rewrote `$0` bodies to a named parameter, because a nested `Group {}` closure cannot use `$0`.
  - Expressions were kept short, and only existing APIs were used (`ContentUnavailableView`, `presentationDetents`, `CYRadius.card/hero/inner`, `CYColor.bgSurface`, `.cyText`).
- Contract checks (`python3 -B -m unittest discover -s Tests/ContractChecks`), diffed by test id against the merged base (dec89f93c):
  - result: **0 new failures, 0 fixed** (85 failures and 100 errors, identical ids to the base);
  - the base has 85 failures and 100 errors (186 ids).
- Lints:
  - `tools/check_typography_lint.py`: PASS (Theme.Font 16, raw text style 25, all below the baseline);
  - `tools/check_design_lint.py`: PASS;
  - `tools/check_scaffold.py`: PASS.
- `tools/contract_ratchet.py --check`: 185 failing against a baseline of 184, new 1 (`test_workshop_paid_professional…bounded_paging`, the known pre-existing failure, identical on the merged base), fixed 0.
- **Acceptance: NOT RUN.** The workflow is not on this branch, its triggers exclude `restyle/**`, and dispatch is 403. The first acceptance run will be the compiler.
  - Screens: `docs/port/accept/r3-merchant-creator.txt` (20 fixture routes, unchanged).
  - Watch in those screenshots: the `[.medium]` initial detent on confirmation sheets, and the coop center / city node / game node empty and error states (now `ContentUnavailableView`).

## Component requests (for R6 / R0)
1. **`CYPillButton` re-point (spec §3.6):** `.primary` → `.borderedProminent` with the label set to `actionPrimaryFg`, `.secondary` → `.bordered`, `.tertiary` → `.borderless`. This covers R3's 212 call sites and `CYPillButtonStyle(…)` (37).
2. **`.questifyPrimary` (`QuestifyMotionComponents.swift`, an R6 file):** re-point it to the same system style with the label colour fix. That is the safe path for the player-dark `Project*` / `Template*` sites.
3. **`cySheet`:** it applies `roleThemedPresentation()`. That forces the *role* domain, plus `presentationCornerRadius` and a custom background, onto the sheet. R3 used plain `.presentationDetents` + `.presentationDragIndicator(.visible)` instead, because some R3 pages force a domain that differs from the role. Consider a variant without the domain override, as spec §3.4 asks: "no `presentationCornerRadius` or custom background".
4. The `CYRadius.lg`, `.md` and `.sm` aliases are still used in R3 (they map to card / inner). Dropping the aliases is an R6 codemod.

## Left
- **For R3:** nothing in the owned files that a visual-only pass can safely do without a compiler.
- **Spec items that need a decision or a component first:**
  - the store name as the large title on the merchant tab roots (contract-pinned N-07; needs the coordinator / owner);
  - `CYPillButton` / `.questifyPrimary` system styles (component requests 1–2);
  - a full Section rewrite of the remaining hand-built detail stacks inside existing Lists, once the acceptance run can compile and screenshot them.

DONE-ROUND-2
