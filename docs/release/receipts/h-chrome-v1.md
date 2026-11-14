# Receipt: Global Chrome + Domain Switch (`ui/h-chrome-v1`)

- **Branch**: `ui/h-chrome-v1` (HELD; not merged)
- **Base**: `origin/ui/h-tokens-v1` (`81e60e080245572b64a4601c3cfb535d77903cd5`)
- **Spec**: `DESIGN.md` on `origin/docs/design-md` (`0b4069ace`, parts 3, 7, and hard rules); screen template/domain map derived from `docs/design/mp-design-system.md` §5 and `docs/parity/page-map.csv` (`ui/cur-view-map` / `docs/design/view-template-map.csv` was absent on base).

---

## 1. Per-Screen / Role Domain Switching

`ThemeDomain` (`App/Theme/Theme.swift`) and `CYDomainPalette` (`App/DesignSystem/CYDomainPalette.swift`) bind each surface by role/screen independently of system Dark/Light Mode:

| Role / Screen Surface | `ThemeDomain` | Appearance / Surface Summary | Key Files |
| :--- | :--- | :--- | :--- |
| Player root tabs & L2+ detail/social/roam/club/account | `.player` | Dark scheme; `#000000` canvas, `#1C1C1E` cards, `#F8F8F8` primary CTA | `QuestifyApp.swift`, `RoamBrowserView.swift`, `ClubHomeView.swift`, `SessionHomeFeedView.swift`, `AccountView.swift`, `ActivityDetailView.swift`, `TopicDetailView.swift`, `ClubDetailView.swift`, `DiscoveryTemplateDetailView.swift`, `OfficialEventDetailView.swift`, `RoamItemDetailView.swift`, `SquareDetailView.swift`, `TicketWalletView.swift`, `TicketWalletDetailView.swift` |
| Merchant / Coop / Workbench / Ledger / Storefront | `.merchant` | Light scheme; `#F3F4F4` canvas, `#FFFFFF` cards, `#000000` primary CTA | `MerchantHomeView.swift`, `MerchantProjectsView.swift`, `CooperationBrowserView.swift`, `CooperationFlowWorkbench.swift`, `CooperationInviteDetailView.swift`, `CoopFinanceProfitView.swift`, `CoopSettlementDetailView.swift`, `MerchantCoopCenterView.swift`, `MerchantBusinessViews.swift`, `MerchantOrdersView.swift`, `MerchantPayoutAccountView.swift`, `MerchantPredictionInboxView.swift`, `MerchantCityNodeHubView.swift`, `MerchantCityNodeCreateView.swift`, `MerchantLedgerSettlementOverview.swift`, `MerchantMarketingView.swift`, `MerchantOnboardingView.swift`, `CouponManagementView.swift`, `PublisherLifecycleViews.swift`, `CityNodeRedeemView.swift` |
| Creator Studio / Topic Editor | `.topicEditor` | Light scheme (`creator studio` / topic authoring) | `ProjectEditView.swift`, `SessionPublishingModesView.swift`, `TemplateAuthoringView.swift`, `StoryRuleEditorView.swift`, `CreatorContentViews.swift` |
| Play Runtime | `.game` | Fixed `.colorScheme = .dark`; dark play stage (`surfaceDomain` -> `.player`) + `--cy-game-*` runtime tokens | `Theme.swift`, `CYDomainPalette.swift`, `PlayExperienceView.swift`, `PlaySessionView.swift`, `PlayRouteMapView.swift`, `PlayKitTimedChallengeView.swift`, `PlayKitSensorChallengeView.swift`, `CityOnsiteTaskView.swift`, `CityNeutralTaskView.swift`, `OrientScoreView.swift`, `PlayKitScreen.swift` |

Notes on hash-pinned source files:
- `App/MerchantOperationsViews.swift`, `App/MerchantEngagementViews.swift`, and `App/MerchantContentEditor.swift` are SHA-256 pinned by `Tests/ContractChecks/test_merchant_station_submission_import.py`. They were left untouched, and `MerchantHomeView.swift` wraps their pushed destinations (`MerchantOperationsHomeView`, `MerchantEngagementHomeView`, `MerchantContentHomeView`) with `.cyPushedChrome(domain: .merchant)`.
- `App/PublishingModesViews.swift` is SHA-256 pinned by `Tests/ContractChecks/test_activity_publishing_wizard.py`. It was left untouched, and `SessionPublishingModesView.swift` wraps it with `.cyPushedChrome(domain: .topicEditor)`.

Also fixed in `App/DesignSystem/CYScreenStyle.swift` & `CYDomainPalette.swift`:
- `CYScreenChrome.correct(_:domain:)` resolves the effective UIKit navigation/tab bar appearance against `effectiveDomain(for:rootDomain:)` so nested `.merchant` / `.topicEditor` / `.game` destinations pushed from `.player` (and vice versa) style their bars for the child domain rather than inheriting the root host domain.
- `CYDomainPalette.cardShadowColor` replaces `0x0F172B` with neutral `0x000000` (alpha `0.08`).

---

## 2. Tab Bar Visibility & Styling

- `CYTabBarAppearance` (`App/DesignSystem/CYDomainTabBar.swift`) applies `Theme.MiniProgramChrome.tabUnselectedOpacity` instead of fallback accent tints; `QuestifyApp.swift` and `HomeSearchTabParityViews.swift` replace `QuestifyPalette.accent` usages on root/chrome controls with domain `CYColor.brand`.
- Added `CYTabBarHiddenPreferenceKey`, `EnvironmentValues.cyTabBarHidden`, and `View.cyHideTabBar(_:)` (`App/DesignSystem/CYDomainTabBar.swift`).
- `QuestifyApp.swift` observes `.onPreferenceChange(CYTabBarHiddenPreferenceKey.self)` and hides the custom `CYNightTabBar` overlay pill (`App/DesignSystem/CYNightTabBar.swift`), zeroes `CYFloatingTabBarClearance`, and applies `.toolbar(isTabBarHidden ? .hidden : .visible, for: .tabBar)`.
- Every pushed L2+ view using `.cyPushedChrome(...)` or `.cyHeroPushedChrome(...)` sets `.cyHideTabBar(true)` and `.toolbar(.hidden, for: .tabBar)`.

---

## 3. Back Navigation Split (Bare Chevron vs Hero Glass Pill)

- `CYBareBackButton` (`App/DesignSystem/CYScreenStyle.swift`): borderless `44×44pt` `chevron.left` button without circular glass background for standard L2+ pushed screens via `.cyPushedChrome(domain:)`.
- `CYHeroBackButton` (`App/DesignSystem/CYScreenStyle.swift`): `32pt` circular `.ultraThinMaterial` glass pill with `CYColor.heroBackStroke` border for full-bleed hero cover views via `.cyHeroPushedChrome(domain:backAccessibilityIdentifier:onBack:)`:
  - Applied on `App/ActivityDetailView.swift` and `App/ClubDetailView.swift` only.

---

## 4. Pinned Footer Bars (`CYFooterBar`)

`CYFooterBar` (`App/DesignSystem/CYScreenStyle.swift`: `CYColor.bgPage` surface with `0.5pt` `CYColor.borderSubtle` top divider and `safeAreaInset(edge: .bottom)`) applied across detail/checkout/form pages:
- `App/ActivityDetailView.swift`
- `App/TopicXcxSections.swift` (`TopicDetailBottomBar`)
- `App/RegistrationSheetView.swift`
- `App/OrderLifecycleView.swift`
- `App/ParticipantFormView.swift`
- `App/InvoiceLaunchApplyView.swift`
- `App/InvoiceLaunchTitleEditor.swift`
- `App/ProfileEditView.swift`
- `App/ProjectEditView.swift`
- `App/MerchantCityNodeCreateView.swift`
- `App/SquareDetailView.swift`
- `App/QuestifyMotionComponents.swift` (`QuestifyStickyActionFooter`)

---

## 5. Player Sheet Glass

- Added `.cyPlayerSheetGlass()` (`App/Theme/RoleTheme.swift`), applying `.presentationCornerRadius(CYRadius.sheet)` and `.presentationBackground(CYColor.sheetGlass)` (`CYDomainPalette(.player)`), and updated `.roleThemedPresentation()` corner radius to `CYRadius.sheet`.
- Replaced legacy `CYNight` tokens on sheets/popovers with `CYColor.sheetGlass` / `CYColor` tokens in `CYConfirmSheet.swift`, `CYAnchoredMenu.swift`, `CYSquareShareSheet.swift`, `CYSquareActivityPicker.swift`, `CYSquarePostDraftsSheet.swift`, `CYMapChrome.swift`, and `MemberReportProgressDetailView.swift`.
- Applied `.cyPlayerSheetGlass()` to sheet presentations across `QuestifyApp.swift`, `AccountView.swift`, `ActivityDetailView.swift`, `TopicDetailView.swift`, `RegistrationSheetView.swift`, `TicketPassSheet.swift`, `CatalogShareCardView.swift`, `SettingsView.swift`, `ContextualReviewComposer.swift`, `ProfileComplaintPreparationView.swift`, `JourneyLandingViews.swift`, `PlayStoreDayMerchantView.swift`, `BundleDetailView.swift`, `ProjectEditView.swift`, `MerchantProjectsView.swift`, `CoopFinanceProfitView.swift`, `CoopSettlementDetailView.swift`, `CooperationInviteDetailView.swift`, `MerchantCoopCenterView.swift`, `MerchantOrdersView.swift`, and `CouponManagementView.swift`.

---

## 6. Verification (No Xcode Builds Run; `swiftc -parse` + Python Gates Only)

Added static contract test suite: `Tests/ContractChecks/test_global_chrome_domain_contract.py`.

All checks run on the final working tree after the last edit (command exited `0`):

1. `git diff --name-only -- '*.swift' | xargs xcrun swiftc -parse` -> **PASS** (exit `0`)
2. `python3 -B tools/check_design_lint.py` -> **PASS** (`scanned 1633 App Swift files outside DesignSystem and Theme; allowlist 29 files (44 existing violations)`, 0 new violations)
3. `python3 -B tools/check_a11y.py` -> **PASS** (`10 scoped screens, helper checked, 2 range views left, 3078 other App views not scanned`)
4. `python3 -B tools/check_scaffold.py` -> **PASS** (`page route table: 262 pages`, `4768 Swift source files, 16562 bilingual keys`, privacy manifest & release config checks passed)
5. `python3 -B tools/contract_ratchet.py --check` -> **PASS** (`contract ratchet: 186 failing, baseline 186, new 0, fixed 0`)
   - Note: `186` baseline pre-existing contract failures remain unchanged from `origin/ui/h-tokens-v1`; `0` new failures and `0` regressions introduced by this branch.
6. `python3 -B -m unittest Tests/ContractChecks/test_design_token_unification_contract.py Tests/ContractChecks/test_global_chrome_domain_contract.py -v` -> **PASS** (`Ran 11 tests in 1.463s — OK`)

*Scope limit*: As required by the dispatch environment constraints, no `xcodebuild` compilation, simulator run, or UI visual inspection was performed on this Mac.
