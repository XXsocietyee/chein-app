# Pop-Up Parity Receipt: member / passport / wallet / market / orders / tickets / coupons / settings / account (`ui/h-popups-member`)

- **Branch**: `ui/h-popups-member` (based on `origin/ui/h-design-v1` `5d652cc08` merged with `origin/ui/main`)
- **Code Commit Verified on Mac + VPS**: `7e6b5b733e88ffba8e1074425d6986f6f3cc0e79`
- **Mini-Program Source**: `chengyinhub-xcx` (`origin/master`) audited against `pages/member*`, `subpackageMember/*`, `subpackageA/pages/assetcenter*`, `pages/shezhi*`, and shared danger-action utilities
- **Parity CSV**: `docs/parity/popups-member.csv` — 84 entries (`DONE`: 73, `DONE (gated behind MPCommerceGate)`: 1, `MISSING`: 10 unmounted/upstream navigation or write-path gaps)

## Changes Summary

### 1. Design System & Reusable Member Area Popup Surfaces
- `App/DesignSystem/CYSheetModal.swift`: added optional `confirmIdentifier: String? = nil` and `cancelIdentifier: String? = nil` on `CYModal` with `ViewThatFits(in: .horizontal)` button layout for long Chinese copy and AX5 Dynamic Type.
- `App/MemberAreaPopupSurfaces.swift`: added bilingual (`en` + `zh-Hans`, mini-program copy for `zh-Hans`) reusable `CYConfirmSheet`, `CYSheetContainer`, and `CYModal` views:
  - `MemberSignOutConfirmSheet`, `MemberDeregistrationCancelConfirmSheet`, `MemberDeregistrationSubmitConfirmSheet`, `MemberMarketingConsentConfirmSheet`
  - `MemberFavoritesRecommendNoteSheet`, `MemberTopicUnlikeConfirmSheet`, `MemberBankWithdrawalDiscardConfirmSheet`, `MemberBundleSwapConfirmSheet`
  - `MemberReportAppealConfirmSheet`, `MemberCouponShowConfirmSheet`, `MemberCouponDiscardConfirmSheet`, `MemberCouponStopConfirmModal`
  - `MemberInvoiceWithdrawConfirmSheet`, `MemberInvoiceTitleDeleteConfirmSheet`, `MemberNPCLogDeleteConfirmSheet`, `MemberOrientScoreConfirmSheet`
  - `MemberProfileDiscardConfirmSheet` (`.exitDiscard`, `.reloadDiscard`, `.reviewRestore`, `.avatarDiscard`), `MemberParticipantDeleteConfirmSheet`, `MemberComplaintSubmitConfirmSheet`

### 2. Native Pop-Up / Sheet / Toast Migrations & Fixes
- Converted system `.alert` / `.confirmationDialog` presentations to `.sheet` + `Member*ConfirmSheet` (`CYConfirmSheet` / `CYSheetContainer`):
  - `App/AccountView.swift`, `App/AccountComplianceViews.swift`, `App/AccountDeregistrationImpactSection.swift`
  - `App/AccountCollectionFavoritesView.swift`, `App/TopicUnlikeControls.swift`, `App/NPCChatDataView.swift`
  - `App/ProfileParticipantsView.swift`, `App/ProfileComplaintPreparationView.swift`, `App/BankWithdrawalView.swift`
  - `App/BundleExitSwapView.swift`, `App/CommunityTrustPlayerViews.swift`, `App/CouponCodeView.swift`
  - `App/CouponManagementView.swift`, `App/InvoiceLaunchDetailView.swift`, `App/InvoiceLaunchHistoryView.swift`
  - `App/InvoiceLaunchTitlesView.swift`, `App/OrientScoreReviewSection.swift`, `App/ProfileEditView.swift`
  - `App/ProfileDraftReviewSection.swift`, `App/ProfileAvatarDraftSection.swift`
- Standardized sheet presentations onto `.cyDomainSheet(...)` / `CYSheetContainer`:
  - `App/InvoiceLaunchApplyView.swift`, `App/WalletCommerceViews.swift`, `App/OrderLifecycleView.swift`, `App/TeamReportReasonSheet.swift`, `App/TemplateAuthoringMineView.swift`, `App/PassMarketViews.swift`, `App/SettingsPrivacyLocationView.swift`, `App/SettingsPostGovernanceView.swift`, `App/WithdrawalSupportContactView.swift`
- Added missing `.cyToast(...)` feedback:
  - `App/SettingsAboutView.swift` (pending player code + attribution copy)
  - `App/WithdrawalSupportContactView.swift` (WeChat copy)
  - `App/TemplateAuthoringMineView.swift` (shelf action confirmation)
  - `App/SettingsPostGovernanceView.swift` (appeal submission/warning toast)
  - `App/ProfileOrderNumberCopySection.swift` + `App/ProfileOrdersView.swift` (order number copy toast)

### 3. DEBUG Fixtures & Project Regeneration
- `App/DesignFixtures/MemberAreaPopupFixtures.swift` registered in `App/DesignFixtures/DesignFixtureRegistry.swift` with 23 fixtures (`member-popup-*`):
  - `member-popup-sign-out`, `member-popup-deregister-cancel`, `member-popup-deregister-submit`, `member-popup-marketing-opt-in`, `member-popup-marketing-opt-out`, `member-popup-favorites-note`, `member-popup-topic-unlike`, `member-popup-bank-discard`, `member-popup-bundle-swap`, `member-popup-report-appeal`, `member-popup-coupon-code`, `member-popup-coupon-discard`, `member-popup-coupon-stop`, `member-popup-invoice-withdraw`, `member-popup-invoice-title-delete`, `member-popup-npc-delete`, `member-popup-orient-score`, `member-popup-profile-exit`, `member-popup-profile-reload`, `member-popup-profile-review-restore`, `member-popup-profile-avatar-discard`, `member-popup-participant-delete`, `member-popup-complaint-submit`
- `Questify.xcodeproj/project.pbxproj` regenerated (`tools/generate_project.py`: 3638 native sources, 217 catalogs).
- `App/DesignFixtures/DesignFixtureReleaseExclusionAudit.swift` regenerated (`tools/check_design_fixture_release_exclusion.py --write`: 194 symbols).

### 4. Updated Source-Contract Checks for DS Sheet Migration
- Updated legacy `.confirmationDialog` / raw `Button` text checks to verify the new `Member*ConfirmSheet` / `CYConfirmSheet` components in:
  - `Tests/ContractChecks/test_pkg19_login_deletion_chain.py`
  - `Tests/ContractChecks/test_profile_draft_review_layout.py`
  - `Tests/ContractChecks/test_profile_draft_review_restore.py`
  - `Tests/ContractChecks/test_profile_exit_discard.py`
  - `Tests/ContractChecks/test_profile_reload_discard.py`

## Verification Results

### Local `xcrun swiftc -parse` (all 38 modified/new Swift files, default + `-D DEBUG`)
Note: `xcodebuild`, `swift build`, and `swift test` were NOT run on this Mac.

```
PARSE 0/0 App/AccountCollectionFavoritesView.swift
PARSE 0/0 App/AccountComplianceViews.swift
PARSE 0/0 App/AccountDeregistrationImpactSection.swift
PARSE 0/0 App/AccountView.swift
PARSE 0/0 App/BankWithdrawalView.swift
PARSE 0/0 App/BundleExitSwapView.swift
PARSE 0/0 App/CommunityTrustPlayerViews.swift
PARSE 0/0 App/CouponCodeView.swift
PARSE 0/0 App/CouponManagementView.swift
PARSE 0/0 App/DesignFixtures/DesignFixtureRegistry.swift
PARSE 0/0 App/DesignFixtures/DesignFixtureReleaseExclusionAudit.swift
PARSE 0/0 App/DesignFixtures/MemberAreaPopupFixtures.swift
PARSE 0/0 App/DesignSystem/CYSheetModal.swift
PARSE 0/0 App/FreeExploreBundleLaunchView.swift
PARSE 0/0 App/InvoiceLaunchApplyView.swift
PARSE 0/0 App/InvoiceLaunchDetailView.swift
PARSE 0/0 App/InvoiceLaunchHistoryView.swift
PARSE 0/0 App/InvoiceLaunchTitlesView.swift
PARSE 0/0 App/MemberAreaPopupSurfaces.swift
PARSE 0/0 App/NPCChatDataView.swift
PARSE 0/0 App/OrderLifecycleView.swift
PARSE 0/0 App/OrientScoreReviewSection.swift
PARSE 0/0 App/PassMarketViews.swift
PARSE 0/0 App/ProfileAvatarDraftSection.swift
PARSE 0/0 App/ProfileComplaintPreparationView.swift
PARSE 0/0 App/ProfileDraftReviewSection.swift
PARSE 0/0 App/ProfileEditView.swift
PARSE 0/0 App/ProfileOrderNumberCopySection.swift
PARSE 0/0 App/ProfileOrdersView.swift
PARSE 0/0 App/ProfileParticipantsView.swift
PARSE 0/0 App/SettingsAboutView.swift
PARSE 0/0 App/SettingsPostGovernanceView.swift
PARSE 0/0 App/SettingsPrivacyLocationView.swift
PARSE 0/0 App/TeamReportReasonSheet.swift
PARSE 0/0 App/TemplateAuthoringMineView.swift
PARSE 0/0 App/TopicUnlikeControls.swift
PARSE 0/0 App/WalletCommerceViews.swift
PARSE 0/0 App/WithdrawalSupportContactView.swift
```

### VPS `instabox exec --timeout 360 work` (`/data/workspace/appcheck-ui-h-popups-member` @ `7e6b5b733e88ffba8e1074425d6986f6f3cc0e79`, exit code 0)

```
VPS_HEAD=7e6b5b733e88ffba8e1074425d6986f6f3cc0e79
PASS design lint: scanned 1636 App Swift files outside DesignSystem and Theme; allowlist 29 files (44 existing violations)
PASS accessibility lint: 10 scoped screens, helper checked, 2 range views left, 3115 other App views not scanned
LEFT ExternalGameCatalogLaunch, CYFloatingTabBarClearance
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
PASS design lint: scanned 1636 App Swift files outside DesignSystem and Theme; allowlist 29 files (44 existing violations)
PASS accessibility lint: 10 scoped screens, helper checked, 2 range views left, 3115 other App views not scanned
LEFT ExternalGameCatalogLaunch, CYFloatingTabBarClearance
NOTE App/AppCompositionRoot.swift: 4171 < ratchet 4184; lower CEILINGS in tools/check_appsession_ratchet.py
PASS appsession ratchet
PASS page route table: 262 pages
PASS structural checks: 4776 Swift source files, 16562 bilingual keys, references, scheme, read-only expected project equivalence
SCOPE: this script does not run Swift/Xcode, previews, simulator/device, accessibility or live backend checks; see separate evidence
CB46 design-fixture release exclusion: source check only.
Release was not compiled. xcodebuild was not run.
App target Release excludes 39 design-fixture sources.
Release projection contains none of the audited fixture symbols.
contract ratchet: 186 failing, baseline 186, new 0, fixed 0
```
