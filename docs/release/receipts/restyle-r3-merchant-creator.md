# Restyle R3: merchant & creator (receipt, in progress)

Branch `restyle/r3-merchant-creator`, base `origin/ui/combined-r6` (f1115875e). Brief: `design/handoff-r2:docs/briefs/restyle-native-r1.md`.
Scope: about 447 files (`Merchant*` 178, `MerchantKit/` 1, `Coop*` 23, `Cooperation*` 11, `Workshop*` 31, `Mod*` 16, `Creator*` 10, `Project*` 87, `Publishing*` 8, `Editor*` 7, `Template*` 75). No P1–P5 file or `App/DesignSystem/*` file is touched.

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

### Held back: frozen by contract-check hashes
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

Not every one of these hashes is enforced by a currently-passing test. **Coordinator decision needed:** may the restyle refresh these frozen hashes, which edits test files R3 does not own?

`MerchantCustomerDetailSections.swift:43` keeps `.font(CYTypography.dataXL)` because `test_pkg12_merchant_customer_paid_card` asserts that literal line.

## Verification (no Swift compiler in the cloud; `acceptance.yml` does not exist yet)
- Contract checks (`python3 -m unittest discover -s Tests/ContractChecks`): 85 failures, 100 errors. That is identical to the base (diffed by test id), so there are 0 new failures.
- `tools/check_typography_lint.py`: PASS (one count below the baseline).
- `tools/check_scaffold.py`: PASS.
- `tools/contract_ratchet.py --check`: 185 against a baseline of 184. The extra failure (`test_workshop_paid_professional…bounded_paging`) also fails on the base r6, so it is not from R3.
- Acceptance screens: `docs/port/accept/r3-merchant-creator.txt` (20 fixture routes).
- The acceptance run is pending; it starts once `.github/workflows/acceptance.yml` lands.

## Component requests (for R6)
- `CYEmptyState` / `CYStateView` (about 99 call sites in R3 files) should render `ContentUnavailableView`. R3 relies on R6's state-kit change instead of rewriting every call site.
- `CYPillButton` should map `.primary` → `.borderedProminent` and `.secondary` → `.bordered`, so the remaining pills follow without per-site edits.
- `CYTextStyle.caption` / `.micro` sit below `.caption`. Please raise them to `.caption`, or deprecate them.

## Left (next batches, ≤ 40 files each)
- Batch 2: the rest of `Merchant*`, then `MerchantKit/`.
- Batch 3: `Coop*`, `Cooperation*`.
- Batch 4–5: `Workshop*`, `Mod*`, `Creator*`, `Publishing*`, `Editor*`.
- Batch 6–8: `Project*`, `Template*`.
- Structural `List`/`Form` conversions where a page is still a custom ScrollView stack.
