# Popup Parity Receipt: Merchant / Coop / Publish / Creator Studio / Templates

- **Branch**: `ui/h-popups-merchant`
- **Base / Merge**: `origin/ui/h-design-v1` (`5d652cc08`) merged with latest `origin/ui/main` (`a31949367`) at `44e09cd8a043b2726307ca559fdf2aa5356bf97d`
- **Mini-program Source**: `hengyin` `master` (`chengyinhub-xcx`)

## 1. Parity Audit (`docs/parity/popups-merchant.csv`)

Audited `wx.showModal`, `wx.showActionSheet`, `wx.showToast`, `<cy-sheet>`, `<cy-modal>`, `<cy-option-sheet>`, `<cy-scene-sheet>` across mini-program `pages/merchant/*`, `pages/coop/*`, `pages/publish/*`, `pages/template*`, and subpackage topic editor:

- **Total rows**: 747 (`DONE`: 334, `MISSING`: 312, `DIFFERENT`: 101)
- **CSV path**: `docs/parity/popups-merchant.csv`

## 2. Design-System Extensions & Migrations

- `App/DesignSystem/CYSheetModal.swift`: Extended `CYModal` (`showCancel`, `cancelIdentifier`, `confirmIdentifier`, `ViewThatFits` adaptive button layout), added `CYPromptModal` and `.cyModalOverlay(isPresented:content:)`.
- `App/DesignSystem/CYSharedStates.swift`: Added `CYToastVerbatimModifier` and `.cyToast(verbatimMessage:tone:...)`.
- `App/MerchantAreaPopupSurfaces.swift`: Added shared helpers (`MerchantAreaCopy`, `View.cyModalConfirm(...)`, `View.cyPromptModalOverlay(...)`, `MerchantChoiceOption`, `MerchantChoiceOptionSheet`, `CoopReviewScore`).
- Replaced all native `.alert(...)`, `.confirmationDialog(...)`, and raw non-player `.cyPlayerSheetGlass()` calls in the merchant / coop / publish / creator studio / template / topic-editor area with DesignSystem surfaces (`CYModal`, `CYPromptModal`, `CYConfirmSheet`, `MerchantChoiceOptionSheet`, `.cyDomainSheet(...)`, `.cyToast(...)`), preserving all triggers, `zh-Hans` mini-program copy, `en` translations, destructive roles, data bindings, grants, and safety gates.
- Verification grep on area files (`App/*Coop*`, `App/*Merchant*`, `App/*Nearby*`, `App/*Publish*`, `App/*Project*`, `App/*Template*`, `App/*Topic*`, `App/PlayStoreDayMerchantView.swift`, `App/CityNodeRedeemView.swift`, `App/CityMerchantOperationsView.swift`, `App/MyProjectMutationViews.swift`, `App/DiscoveryTemplateDetailView.swift`) confirms `ZERO_REMAINING` `.alert(` / `.confirmationDialog(`.
- Updated contract & UI tests in `Tests/AppUITests/MerchantCoopFieldFlowTests.swift`, `Tests/AppUITests/TopicUnlikeFlowTests.swift`, and `Tests/ContractChecks/`.

## 3. `#if DEBUG` Fixtures

Added 7 `#if DEBUG` fixtures in `App/DesignFixtures/MerchantAreaPopupFixtures.swift`, registered in `App/DesignFixtures/DesignFixtureRegistry.swift`, with Xcode project and fixture exclusion audit regenerated via `python3 tools/generate_project.py` and `python3 tools/check_design_fixture_release_exclusion.py --write` (257 symbols):

- `merchant-popup-discard`
- `merchant-popup-exit-guard`
- `merchant-popup-danger-confirm`
- `merchant-popup-prompt`
- `merchant-popup-coop-score`
- `merchant-popup-bind-node`
- `merchant-popup-toast`

## 4. Merge Resolution & Contract Alignment (`origin/ui/main` `a31949367`)

- Resolved 22 merge conflicts keeping `ui/h-design-v1` + `ui/h-popups-merchant` design tokens/chrome (`CYColor.*`, `CYTabBarHiddenPreferenceKey`, `CYFooterBar`, `.cyPushedChrome`, `CYConfirmSheet`) while preserving `origin/ui/main` additions (`UGCSafetyMenuButton` on `DiscoveryTemplateDetailView` and `TopicDetailView`, `.appSwitcherPrivacyShield()` on `BankWithdrawalView` and `TicketWalletDetailView`, `.cyTabBarAccessibilityIdentifiers` on `QuestifyApp`, `isMerchantViewer` role label in `HomeSearchTabParityViews`, and `topic.cta.*` / bookmark / ShareLink controls in `TopicXcxSections` wrapped inside `CYFooterBar`).
- Replaced retired `CYColor.accent` / `CYColor.accentSoft` tokens in newly merged `App/UGCSafetyComponents.swift` with `CYColor.brand` / `CYColor.brandSoft`.
- Aligned `App/MerchantOnboardingView.swift` closure variable naming (`request`) and updated contract checks (`test_merchant_aftercare_decision_change.py`, `test_merchant_coop_field_editing.py`, `test_merchant_discovery_redemption_contracts.py`, `test_merchant_npc_recovery.py`, `test_merchant_onboarding_license_removal.py`, `test_merchant_store_field_editing.py`, `test_native_entry_wiring.py`) to assert the DesignSystem modal/sheet equivalents while keeping every state/safety invariant intact.

## 5. Local Verification (`swiftc -parse` & Lints)

No `xcodebuild`, `swift build`, or `swift test` was run on Mac.

```text
xcrun swiftc -parse "${files[@]}" (all 344 changed/merged .swift files vs origin/ui/h-design-v1 + UGCSafetyComponents.swift + MerchantOnboardingView.swift)
RELEASE_EXIT=0

xcrun swiftc -parse -D DEBUG "${files[@]}" (344 files)
DEBUG_EXIT=0
```

Parsed branch-direct + merge-resolved files (`81` = prior `80` + `App/UGCSafetyComponents.swift`):
`App/BankWithdrawalView.swift`, `App/CharacterSheetDetailView.swift`, `App/CityMerchantOperationsView.swift`, `App/CityNodeRedeemView.swift`, `App/ClubChannelMessagingView.swift`, `App/ClubDetailView.swift`, `App/CoopFinanceProfitView.swift`, `App/CoopListParitySections.swift`, `App/CoopPoolApplicationEditor.swift`, `App/CoopWithdrawShellViews.swift`, `App/CooperationContextualViews.swift`, `App/CooperationFlowEditors.swift`, `App/CooperationInviteActionSections.swift`, `App/CooperationInviteDetailView.swift`, `App/DesignFixtures/DesignFixtureRegistry.swift`, `App/DesignFixtures/DesignFixtureReleaseExclusionAudit.swift`, `App/DesignFixtures/MerchantAreaPopupFixtures.swift`, `App/DesignSystem/CYAlbum.swift`, `App/DesignSystem/CYCityKit.swift`, `App/DesignSystem/CYDomainTabBar.swift`, `App/DesignSystem/CYNightTabBar.swift`, `App/DesignSystem/CYSharedStates.swift`, `App/DesignSystem/CYSheetModal.swift`, `App/DiscoveryTemplateDetailView.swift`, `App/HomeSearchTabParityViews.swift`, `App/MerchantAreaPopupSurfaces.swift`, `App/MerchantBusinessEditor.swift`, `App/MerchantBusinessViews.swift`, `App/MerchantCityNodeCreateView.swift`, `App/MerchantCityNodeHubView.swift`, `App/MerchantContentEditor.swift`, `App/MerchantContentViews.swift`, `App/MerchantCoopCenterView.swift`, `App/MerchantCoopFieldEntry.swift`, `App/MerchantDeskAnchorSection.swift`, `App/MerchantDiscoverView.swift`, `App/MerchantGameNodeView.swift`, `App/MerchantGamePlayerView.swift`, `App/MerchantNPCFieldEntry.swift`, `App/MerchantNPCKnowledgeDraftView.swift`, `App/MerchantNPCRecoveryPresentation.swift`, `App/MerchantNPCVoiceSamplesView.swift`, `App/MerchantOfferWithdrawalOriginalView.swift`, `App/MerchantOfferWithdrawalView.swift`, `App/MerchantOnboardingBrandImagesView.swift`, `App/MerchantOnboardingView.swift`, `App/MerchantOperationsViews.swift`, `App/MerchantOrdersView.swift`, `App/MerchantPerkTemplatesView.swift`, `App/MerchantPerkValidityCalendar.swift`, `App/MerchantPredictionInboxView.swift`, `App/MerchantProjectsView.swift`, `App/MerchantStoreCharacterView.swift`, `App/MerchantStoreFieldEntry.swift`, `App/MyProjectMutationViews.swift`, `App/NearbyMerchantView.swift`, `App/OfficialEventDetailView.swift`, `App/PlayStoreDayMerchantView.swift`, `App/ProjectChapterAudioField.swift`, `App/ProjectEditFlowParity.swift`, `App/ProjectEditView.swift`, `App/ProjectInitialAttributesEditor.swift`, `App/ProjectNodeGameplayRemovalField.swift`, `App/ProjectNodePhotoRemovalField.swift`, `App/ProjectThoughtDefinitionsEditor.swift`, `App/PublishingModesViews.swift`, `App/QuestifyApp.swift`, `App/TemplateAdoptionViews.swift`, `App/TemplateAuthoringExitGuard.swift`, `App/TemplateAuthoringView.swift`, `App/TemplatePreferenceDraftEditor.swift`, `App/TicketWalletDetailView.swift`, `App/TopicCreatorToolsView.swift`, `App/TopicDetailView.swift`, `App/TopicLocationTodosSection.swift`, `App/TopicUnlikeControls.swift`, `App/TopicXcxSections.swift`, `App/UGCSafetyComponents.swift`, `App/UsageConsentGateView.swift`, `Tests/AppUITests/MerchantCoopFieldFlowTests.swift`, `Tests/AppUITests/TopicUnlikeFlowTests.swift`.

Local lints:
- `python3 tools/check_design_lint.py` -> exit `0` (`PASS design lint: scanned 1649 App Swift files outside DesignSystem and Theme; allowlist 28 files (43 existing violations)`)
- `python3 tools/check_a11y.py` -> exit `0` (`PASS accessibility lint: 10 scoped screens, helper checked, 2 range views left, 3149 other App views not scanned`)

## 6. VPS Heavy Checks (`instabox exec work`)

Ran in `/data/workspace/appcheck-ui-h-popups-merchant` at commit `722f4988dfbbf21d5b4087dca8d6a1c9aaf2d093` (command exit code `0`):

```text
VPS_HEAD=722f4988dfbbf21d5b4087dca8d6a1c9aaf2d093
=== check_design_lint ===
PASS design lint: scanned 1649 App Swift files outside DesignSystem and Theme; allowlist 28 files (43 existing violations)
=== check_a11y ===
PASS accessibility lint: 10 scoped screens, helper checked, 2 range views left, 3149 other App views not scanned
LEFT ExternalGameCatalogLaunch, CYFloatingTabBarClearance
=== check_scaffold ===
missing_keys: 0
untranslated_values: 0
key_identifier_mismatches: 0
gaps: 0
missing_keys: 0
wrong_table: 0
incomplete_locales: 0
missing: 0
Release config check passed
PASS privacy manifest: tracking off, 12 collected types, 3 required-reason categories match source
PASS design lint: scanned 1649 App Swift files outside DesignSystem and Theme; allowlist 28 files (43 existing violations)
PASS accessibility lint: 10 scoped screens, helper checked, 2 range views left, 3149 other App views not scanned
LEFT ExternalGameCatalogLaunch, CYFloatingTabBarClearance
PASS log redaction: App/ and Core/ log calls do not interpolate phone, OpenID, token, or street fields raw (0 findings)
NOTE App/AppCompositionRoot.swift: 4171 < ratchet 4184; lower CEILINGS in tools/check_appsession_ratchet.py
PASS appsession ratchet
PASS page route table: 262 pages
PASS structural checks: 4806 Swift source files, 16596 bilingual keys, references, scheme, read-only expected project equivalence
SCOPE: this script does not run Swift/Xcode, previews, simulator/device, accessibility or live backend checks; see separate evidence
=== check_design_fixture_release_exclusion ===
CB46 design-fixture release exclusion: source check only.
Release was not compiled. xcodebuild was not run.
App target Release excludes 44 design-fixture sources.
Release projection contains none of the audited fixture symbols.
=== contract_ratchet ===
contract ratchet: 186 failing, baseline 186, new 0, fixed 0
```
