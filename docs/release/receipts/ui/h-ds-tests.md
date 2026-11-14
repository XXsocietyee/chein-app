# Receipt: `ui/h-ds-tests` — Shared Design System Unit Tests & Contract Checks

- **Branch**: `ui/h-ds-tests`
- **Base**: `origin/ui/h-design-v1` (`5d652cc08ac5ccc668db315fc57253b909b9e058`)
- **Upstream sync**: `origin/ui/main` (`5ba7b0f2c5f10dea10905895da947c350b3e24ac`) is already an ancestor of `origin/ui/h-design-v1` (`git merge-base origin/ui/h-design-v1 origin/ui/main == 5ba7b0f2c5f10dea10905895da947c350b3e24ac`).
- **Verification Scope**:
  - **Local Mac** (no `xcodebuild`, `swift build`, or `swift test` run on this Mac): `xcrun swiftc -parse` and `xcrun swiftc -parse -D DEBUG` on all 14 modified/added Swift files; `python3 -B tools/generate_project.py` to register new unit tests; `python3 -B -m unittest` on design contract checks.
  - **VPS (`instabox exec work` in `/data/workspace/appcheck-ui-h-ds-tests`)**: `check_design_lint.py`, `check_a11y.py`, `check_scaffold.py`, `contract_ratchet.py --check`, and `Tests/ContractChecks/test_design_system_component_contracts.py`.

---

## 1. Deliverables & Token-Mapping Helpers

### 1.1 Pure State -> Token Mapping Helpers (Self-Hosted by Existing Component Views)

No duplicate UI logic was introduced; each helper is invoked directly by its owning component's view rendering:

| Component Group | File | Exposed Testable Helper(s) |
|---|---|---|
| Button (base + domain + pill) | [CYDesignComponents.swift](file:///Users/fanning/orca/workspaces/native-ios/DES-ag6/App/DesignSystem/CYDesignComponents.swift) | `CYButtonTokens.resolve(variant:isEnabled:isPressed:)` |
| Button (domain) | [CYDomainPalette.swift](file:///Users/fanning/orca/workspaces/native-ios/DES-ag6/App/DesignSystem/CYDomainPalette.swift) | `CYDomainButtonTokens.resolve(kind:isEnabled:isPressed:in:)`, `isDarkDomain`, `resolvedSurfaceDomain` |
| Button (pill) | [CYPillButton.swift](file:///Users/fanning/orca/workspaces/native-ios/DES-ag6/App/DesignSystem/CYPillButton.swift) | `CYPillButtonStyle.tokens(style:isEnabled:in:)` |
| Tag / Badge / Avatar | [CYStatusChip.swift](file:///Users/fanning/orca/workspaces/native-ios/DES-ag6/App/DesignSystem/CYStatusChip.swift), [CYDesignComponents.swift](file:///Users/fanning/orca/workspaces/native-ios/DES-ag6/App/DesignSystem/CYDesignComponents.swift) | `CYStatusChip.tokens(for:isSelected:in:)`, `CYCountBadge.formattedLabel(count:showsZero:)`, `CYUnreadBadge.fillColor(for:)`, `CYUnreadBadge.foregroundColor(for:)`, `CYAvatarView.ringColor(showAccentRing:)`, `CYAvatarView.onlineDotColor(isOnline:)` |
| Chip | [CYChipRow.swift](file:///Users/fanning/orca/workspaces/native-ios/DES-ag6/App/DesignSystem/CYChipRow.swift) | `CYFilterChip.tokens(isSelected:in:)` |
| Tabs | [CYTabs.swift](file:///Users/fanning/orca/workspaces/native-ios/DES-ag6/App/DesignSystem/CYTabs.swift) | `CYTabsTokens.resolve(variant:isSelected:in:)` |
| Cell | [CYListRow.swift](file:///Users/fanning/orca/workspaces/native-ios/DES-ag6/App/DesignSystem/CYListRow.swift) | `CYListRowTokens.resolve(tone:isDisabled:isPressed:in:)` |
| Card | [CYDesignComponents.swift](file:///Users/fanning/orca/workspaces/native-ios/DES-ag6/App/DesignSystem/CYDesignComponents.swift) | `CYCardSurfaceModifier.backgroundColor(for:)` |
| Field | [CYField.swift](file:///Users/fanning/orca/workspaces/native-ios/DES-ag6/App/DesignSystem/CYField.swift) | `CYField.resolveState(...)`, `CYField.tokens(for:hasText:colorScheme:in:)` |
| Sheet / Modal | [CYSheetModal.swift](file:///Users/fanning/orca/workspaces/native-ios/DES-ag6/App/DesignSystem/CYSheetModal.swift) | `CYSheetModalTokens.sheet(in:)`, `optionRowForeground(isDanger:in:)`, `modal(isDestructive:in:)` |
| Footer / Nav Chrome | [CYChromeBars.swift](file:///Users/fanning/orca/workspaces/native-ios/DES-ag6/App/DesignSystem/CYChromeBars.swift) | `CYNavBarTokens.resolve(mode:colorScheme:in:)`, `CYFooterBarTokens.resolve(isAccessibilitySize:in:)` |
| Tab Bar | [CYDomainTabBar.swift](file:///Users/fanning/orca/workspaces/native-ios/DES-ag6/App/DesignSystem/CYDomainTabBar.swift) | `CYRootTabBarStrip.stripTokens(isSelected:in:)` |
| Business: Activity Card | [CYBusinessComponents.swift](file:///Users/fanning/orca/workspaces/native-ios/DES-ag6/App/DesignSystem/CYBusinessComponents.swift) | `CYActivityFeedCard.tokens(in:)` |
| Business: Route Node | [CYBusinessComponents.swift](file:///Users/fanning/orca/workspaces/native-ios/DES-ag6/App/DesignSystem/CYBusinessComponents.swift) | `CYRouteNodeRow.tokens(for:in:)` |
| Business: Task Status | [CYBusinessComponents.swift](file:///Users/fanning/orca/workspaces/native-ios/DES-ag6/App/DesignSystem/CYBusinessComponents.swift) | `CYTaskStatusCard.tokens(for:in:)` |

### 1.2 Unit Tests & Static Contract Checks Added

- [Tests/AppUnitTests/DesignSystemTokenMappingTests.swift](file:///Users/fanning/orca/workspaces/native-ios/DES-ag6/Tests/AppUnitTests/DesignSystemTokenMappingTests.swift):
  - `testMerchantDomainGivesLightTokensAndPlayerGivesDarkTokens` (verifies `.merchant` -> `.light`, `#F3F4F4` / `#FFFFFF` / `#000000` / `#737373` / `#D0323B`, neutral shadow; `.player` -> `.dark`, `#000000` / `#111111` / `#F8F8F8` / `#0A0A0A`; `.game` -> `.player` stage).
  - `testDisabledStatesMapToTextDisabledAndButtonDisabledSurface` (verifies `textDisabled` `#737373` on disabled cells, fields, locked route nodes, locked task status cards, offline avatar dots, and `textPlaceholder` on `bgSurfaceSubtle` for disabled buttons per WCAG AA).
  - `testDangerStatesResolveToDangerRedD0323B` (verifies `#D0323B` across destructive buttons, count/unread danger badges, danger chips, field error strokes/footers, danger list rows, destructive sheets/modals, and retryable failure task status cards).
  - `testReservedPurpleTokensMatchVioletAndNoComponentLeaksPurpleOutsideThreeUses` (verifies `#7A5CFF` ONLY on `tabSelected`/`tabSelectedTint`, `avatarRing`, and `resultSpinner`; sweeps every button, chip, tag, tab, cell, card, field, sheet/modal, chrome bar, and business component state in both `.player` and `.merchant` to ensure HSB hue stays outside `245°...295°`).
  - `testTabsCellsChipsNavFooterBusinessTokenMatrices` (verifies `CYTabs` neutral indicators, `CYFilterChip` swaps, `CYNavBar`/`CYFooterBar` modes & AX stacking, `CYField` priority rules, `CYRouteNodeRow` progression, `CYTaskStatusCard` all 6 states).
- [Tests/AppUnitTests/DesignSystemSharedComponentsTests.swift](file:///Users/fanning/orca/workspaces/native-ios/DES-ag6/Tests/AppUnitTests/DesignSystemSharedComponentsTests.swift):
  - `UIHostingController.sizeThatFits` layout checks for all 10 base components + 3 business components across `.player` (dark), `.merchant` (light), `en`, `zh-Hans`, long Chinese copy, and `.accessibility5` Dynamic Type (`320pt` width, zero horizontal overflow, positive height), plus deterministic badge formatting and merchant/player tab parity assertions.
- [Tests/ContractChecks/test_design_system_component_contracts.py](file:///Users/fanning/orca/workspaces/native-ios/DES-ag6/Tests/ContractChecks/test_design_system_component_contracts.py):
  - Scans `App/**/*.swift` and forbids raw `Color(...)`/`UIColor(...)`, raw hex literals outside `App/DesignSystem/` & `App/Theme/`, and hardcoded `.cornerRadius(<number>)` outside `App/DesignSystem/` (with exact pre-existing per-file allowlist ratchets so `new = 0`).
  - Enforces `#7A5CFF` / purple restraint outside the 3 reserved uses and verifies `disabled -> textDisabled`, `danger -> #D0323B`, and `merchant -> .light` tokens plus synthetic negative self-tests.
- Regenerated Xcode project & sharded unit test plans via `python3 -B tools/generate_project.py`.

---

## 2. Local `swiftc -parse` Verification (Mac)

Toolchain: `Apple Swift version 6.4.2 (swiftlang-6.4.2.1.9 clang-2100.4.1.1)`, iOS Simulator SDK `27.2`.

| File | `xcrun swiftc -parse <file>` | `xcrun swiftc -parse -D DEBUG <file>` |
|---|---|---|
| `App/DesignSystem/CYStatusChip.swift` | `exit=0` | `exit=0` |
| `App/DesignSystem/CYChipRow.swift` | `exit=0` | `exit=0` |
| `App/DesignSystem/CYTabs.swift` | `exit=0` | `exit=0` |
| `App/DesignSystem/CYListRow.swift` | `exit=0` | `exit=0` |
| `App/DesignSystem/CYDomainPalette.swift` | `exit=0` | `exit=0` |
| `App/DesignSystem/CYDesignComponents.swift` | `exit=0` | `exit=0` |
| `App/DesignSystem/CYPillButton.swift` | `exit=0` | `exit=0` |
| `App/DesignSystem/CYField.swift` | `exit=0` | `exit=0` |
| `App/DesignSystem/CYSheetModal.swift` | `exit=0` | `exit=0` |
| `App/DesignSystem/CYChromeBars.swift` | `exit=0` | `exit=0` |
| `App/DesignSystem/CYDomainTabBar.swift` | `exit=0` | `exit=0` |
| `App/DesignSystem/CYBusinessComponents.swift` | `exit=0` | `exit=0` |
| `Tests/AppUnitTests/DesignSystemTokenMappingTests.swift` | `exit=0` | `exit=0` |
| `Tests/AppUnitTests/DesignSystemSharedComponentsTests.swift` | `exit=0` | `exit=0` |

Local design contract unittest run (`python3 -B -m unittest Tests/ContractChecks/test_design_system_component_contracts.py Tests/ContractChecks/test_design_token_unification_contract.py Tests/ContractChecks/test_global_chrome_domain_contract.py -v`):
- **PASS** (`Ran 14 tests in 10.840s`, `OK`, `exit=0`).

---

## 3. VPS Verification (`instabox exec work` in `/data/workspace/appcheck-ui-h-ds-tests`)

Verified against pushed code commit `c69e4a575bc870c160699efe96ea0814bd905f90`:

1. **`python3 tools/check_design_lint.py`**:
   - **PASS** (`exit=0`)
   - Output: `PASS design lint: scanned 1634 App Swift files outside DesignSystem and Theme; allowlist 29 files (44 existing violations)`
2. **`python3 tools/check_a11y.py`**:
   - **PASS** (`exit=0`)
   - Output:
     `PASS accessibility lint: 10 scoped screens, helper checked, 2 range views left, 3096 other App views not scanned`
     `LEFT ExternalGameCatalogLaunch, CYFloatingTabBarClearance`
3. **`python3 tools/check_scaffold.py`**:
   - **PASS** (`exit=0`)
   - Output highlights: `Release config check passed`, `PASS privacy manifest: tracking off, 12 collected types, 3 required-reason categories match source`, `PASS appsession ratchet`, `PASS page route table: 262 pages`, `PASS structural checks: 4776 Swift source files, 16562 bilingual keys, references, scheme, read-only expected project equivalence`.
4. **`python3 tools/contract_ratchet.py --check`**:
   - **PASS** (`exit=0`)
   - Output: `contract ratchet: 186 failing, baseline 186, new 0, fixed 0`
5. **`python3 -m unittest Tests/ContractChecks/test_design_system_component_contracts.py -v`**:
   - **PASS** (`exit=0`)
   - Output: `Ran 3 tests in 2.497s` -> `OK` (`test_app_outside_design_system_has_no_unratcheted_raw_color_hex_or_corner_radius`, `test_state_token_mappings_in_design_system_sources`, `test_synthetic_violations_are_caught`).

---

## 4. Remaining Gap / Scope Note

- As required, `xcodebuild` / `swift build` / `swift test` were not executed on this Mac or on Linux VPS (Linux lacks UIKit/SwiftUI), so runtime execution of the XCTest methods in `DesignSystemTokenMappingTests.swift` and `DesignSystemSharedComponentsTests.swift` remains to be run on an iOS simulator / Xcode Cloud runner; syntax and preprocessor branches (`-D DEBUG`) were verified via `xcrun swiftc -parse` across all 14 Swift files (`exit=0`), and all Python design/scaffold/contract gates passed on the VPS.

