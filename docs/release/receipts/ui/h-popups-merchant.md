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

## 4. Merge Resolution (`origin/ui/main` `a31949367`)

Resolved 22 merge conflicts keeping `ui/h-design-v1` + `ui/h-popups-merchant` design tokens/chrome (`CYColor.*`, `CYTabBarHiddenPreferenceKey`, `CYFooterBar`, `.cyPushedChrome`, `CYConfirmSheet`) while preserving `origin/ui/main` additions (`UGCSafetyMenuButton` on `DiscoveryTemplateDetailView` and `TopicDetailView`, `.appSwitcherPrivacyShield()` on `BankWithdrawalView` and `TicketWalletDetailView`, `.cyTabBarAccessibilityIdentifiers` on `QuestifyApp`, `isMerchantViewer` role label in `HomeSearchTabParityViews`, and `topic.cta.*` / bookmark / ShareLink controls in `TopicXcxSections` wrapped inside `CYFooterBar`).

## 5. Local Verification (`swiftc -parse` & Lints)

No `xcodebuild`, `swift build`, or `swift test` was run on Mac.

```text
xcrun swiftc -parse "${files[@]}" (80 files: branch + merge-resolved .swift files)
RELEASE_EXIT=0

xcrun swiftc -parse -D DEBUG "${files[@]}" (80 files: branch + merge-resolved .swift files)
DEBUG_EXIT=0
```

Parsed files (`80`):
`App/BankWithdrawalView.swift`, `App/CharacterSheetDetailView.swift`, `App/CityMerchantOperationsView.swift`, `App/CityNodeRedeemView.swift`, `App/ClubChannelMessagingView.swift`, `App/ClubDetailView.swift`, `App/CoopFinanceProfitView.swift`, `App/CoopListParitySections.swift`, `App/CoopPoolApplicationEditor.swift`, `App/CoopWithdrawShellViews.swift`, `App/CooperationContextualViews.swift`, `App/CooperationFlowEditors.swift`, `App/CooperationInviteActionSections.swift`, `App/CooperationInviteDetailView.swift`, `App/DesignFixtures/DesignFixtureRegistry.swift`, `App/DesignFixtures/DesignFixtureReleaseExclusionAudit.swift`, `App/DesignFixtures/MerchantAreaPopupFixtures.swift`, `App/DesignSystem/CYAlbum.swift`, `App/DesignSystem/CYCityKit.swift`, `App/DesignSystem/CYDomainTabBar.swift`, `App/DesignSystem/CYNightTabBar.swift`, `App/DesignSystem/CYSharedStates.swift`, `App/DesignSystem/CYSheetModal.swift`, `App/DiscoveryTemplateDetailView.swift`, `App/HomeSearchTabParityViews.swift`, `App/MerchantAreaPopupSurfaces.swift`, `App/MerchantBusinessEditor.swift`, `App/MerchantBusinessViews.swift`, `App/MerchantCityNodeCreateView.swift`, `App/MerchantCityNodeHubView.swift`, `App/MerchantContentEditor.swift`, `App/MerchantContentViews.swift`, `App/MerchantCoopCenterView.swift`, `App/MerchantCoopFieldEntry.swift`, `App/MerchantDeskAnchorSection.swift`, `App/MerchantDiscoverView.swift`, `App/MerchantGameNodeView.swift`, `App/MerchantGamePlayerView.swift`, `App/MerchantNPCFieldEntry.swift`, `App/MerchantNPCKnowledgeDraftView.swift`, `App/MerchantNPCRecoveryPresentation.swift`, `App/MerchantNPCVoiceSamplesView.swift`, `App/MerchantOfferWithdrawalOriginalView.swift`, `App/MerchantOfferWithdrawalView.swift`, `App/MerchantOnboardingBrandImagesView.swift`, `App/MerchantOnboardingView.swift`, `App/MerchantOperationsViews.swift`, `App/MerchantOrdersView.swift`, `App/MerchantPerkTemplatesView.swift`, `App/MerchantPerkValidityCalendar.swift`, `App/MerchantPredictionInboxView.swift`, `App/MerchantProjectsView.swift`, `App/MerchantStoreCharacterView.swift`, `App/MerchantStoreFieldEntry.swift`, `App/MyProjectMutationViews.swift`, `App/NearbyMerchantView.swift`, `App/OfficialEventDetailView.swift`, `App/PlayStoreDayMerchantView.swift`, `App/ProjectChapterAudioField.swift`, `App/ProjectEditFlowParity.swift`, `App/ProjectEditView.swift`, `App/ProjectInitialAttributesEditor.swift`, `App/ProjectNodeGameplayRemovalField.swift`, `App/ProjectNodePhotoRemovalField.swift`, `App/ProjectThoughtDefinitionsEditor.swift`, `App/PublishingModesViews.swift`, `App/QuestifyApp.swift`, `App/TemplateAdoptionViews.swift`, `App/TemplateAuthoringExitGuard.swift`, `App/TemplateAuthoringView.swift`, `App/TemplatePreferenceDraftEditor.swift`, `App/TicketWalletDetailView.swift`, `App/TopicCreatorToolsView.swift`, `App/TopicDetailView.swift`, `App/TopicLocationTodosSection.swift`, `App/TopicUnlikeControls.swift`, `App/TopicXcxSections.swift`, `App/UsageConsentGateView.swift`, `Tests/AppUITests/MerchantCoopFieldFlowTests.swift`, `Tests/AppUITests/TopicUnlikeFlowTests.swift`.

Local lints:
- `python3 tools/check_design_lint.py` -> exit `0` (`PASS design lint: scanned 1649 App Swift files outside DesignSystem and Theme; allowlist 28 files (43 existing violations)`)
- `python3 tools/check_a11y.py` -> exit `0` (`PASS accessibility lint: 10 scoped screens, helper checked, 2 range views left, 3149 other App views not scanned`)

## 6. VPS Heavy Checks (`instabox exec work`)

Pending VPS run after push.
