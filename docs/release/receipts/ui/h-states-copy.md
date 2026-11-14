# Receipt: `h-states-copy` — Empty / Error / Offline Copy, Retry & State Integrity Review

- **Branch**: `ui/h-states-copy`
- **Base**: `origin/ui/h-design-v1` (`5d652cc08ac5ccc668db315fc57253b909b9e058`) merged with latest `origin/ui/main` (`5ba7b0f2c5f10dea10905895da947c350b3e24ac`, already an ancestor)
- **Verified Code SHA (before receipt commit)**: `15fc38fd0e7591a1204e0fa3fbb364e0d48b62bf`
- **Verification Scope**: Local `xcrun swiftc -parse` (and `-D DEBUG` for preview blocks) on every changed `.swift` file, plus full Python lint/scaffold/ratchet suite executed on Instabox VPS (`/data/workspace/appcheck-ui-h-states-copy`). No `xcodebuild`, `swift build`, or `swift test` was run on this Mac.

---

## 1. Summary of Changes Across Design System & 14 Templates

### 1.1 Design System Shared State Components (`App/DesignSystem/`)
- [`App/DesignSystem/CYSharedStates.swift`](file:///Users/fanning/orca/workspaces/native-ios/DES-ag7/App/DesignSystem/CYSharedStates.swift): Added `@Environment(\.dynamicTypeSize)` vertical stacking (`>= .xxLarge`) and `.fixedSize(horizontal: false, vertical: true)` wrapping on `CYOfflineBanner` and `CYInlineError`, plus `.fixedSize(horizontal: false, vertical: true)` on `CYToastPill` text so long `zh-Hans` strings and large Dynamic Type never truncate horizontally.
- [`App/DesignSystem/CYStates.swift`](file:///Users/fanning/orca/workspaces/native-ios/DES-ag7/App/DesignSystem/CYStates.swift): Fixed `CYEmptyState` line 48 (`detail.map { Text($0, tableName: tableName) }`) so explicit `tableName` resolves `detail` keys as well as `title`.
- [`App/DesignSystem/CYStateKit.swift`](file:///Users/fanning/orca/workspaces/native-ios/DES-ag7/App/DesignSystem/CYStateKit.swift): Updated `CYOfflineStrip` to stack vertically at `dynamicTypeSize >= .xxLarge` with rounded-rectangle surface geometry (`CYRadius.lg`) and `.fixedSize(horizontal: false, vertical: true)` wrapping.
- [`App/DesignSystem/CYBusinessComponents.swift`](file:///Users/fanning/orca/workspaces/native-ios/DES-ag7/App/DesignSystem/CYBusinessComponents.swift): Replaced hardcoded Chinese string `"进度读取失败，未能确认当前节点状态。"` in `CYProgressBar` with localized key `"cy.progress.loadFailed"` + `"cy.state.offline.retry"` retry button, and added `dynamicTypeSize >= .xxLarge` header stacking.

### 1.2 Eliminating `'0'` and `'暂无数据'` for Unknown Values
- `Resources/Localizable.xcstrings`, `docs/growth-center-localizations.json`, `docs/release/ui-strings-subpackageP3-pages-growthcenter-index-index.json`, `docs/release/ui-strings-subpackageP3-pages-growthcenter-leaderboard-index.json`: Updated `growth.unknownValue` from `en: "Not available"` / `zh-Hans: "暂无数据"` to `en: "Unknown"` / `zh-Hans: "未知"`. Audited `App/`, `Core/`, and `Resources/` for any remaining `'暂无数据'` (0 occurrences remain outside `CYStateTone.banned`).
- [`App/PlayAdvancedTeamViews.swift`](file:///Users/fanning/orca/workspaces/native-ios/DES-ag7/App/PlayAdvancedTeamViews.swift): Replaced `?? 0` fallbacks in `PlayAdvancedLeaderboardView` (`rank`, `elapsedSeconds`, `completedUnits`, `score`) with `"—"` and `.accessibilityLabel(Text("growth.unknownValue"))` when `nil`.
- [`App/PlaySharedPlanLifecycleView.swift`](file:///Users/fanning/orca/workspaces/native-ios/DES-ag7/App/PlaySharedPlanLifecycleView.swift): Replaced `row.version ?? 0` fallback with `"—"`.
- [`App/NearbyTeamMapViews.swift`](file:///Users/fanning/orca/workspaces/native-ios/DES-ag7/App/NearbyTeamMapViews.swift): Separated `joined == nil` in `NearbyMineMembersText` from `joined ?? 0` using new bilingual keys `nearby.w208.mine.membersUnknownCap %lld` and `nearby.w208.mine.membersUnknown` (`"—"`).

### 1.3 Actionable Empty / Error / Offline Copy, Retry & CY Component Alignment (14 Templates)
- [`App/OfficialOrganizerConsoleView.swift`](file:///Users/fanning/orca/workspaces/native-ios/DES-ag7/App/OfficialOrganizerConsoleView.swift) (Templates 4/10): Replaced banned `"The network is unavailable. Try again."` with `"Check your connection and try again."` / `"检查网络后再试一次"`.
- [`App/AccountCollectionCouponsView.swift`](file:///Users/fanning/orca/workspaces/native-ios/DES-ag7/App/AccountCollectionCouponsView.swift) (Templates 7/8): Migrated empty & filtered-empty `ContentUnavailableView` instances to `CYEmptyStateView` with constructive `en` + `zh-Hans` guidance (`accountCollection.coupons.empty.detail`, `accountCollection.coupons.filteredEmpty.detail`).
- [`App/SearchMapResultsCapsule.swift`](file:///Users/fanning/orca/workspaces/native-ios/DES-ag7/App/SearchMapResultsCapsule.swift) (Template 3): Migrated `ContentUnavailableView` failed/empty states to `CYErrorStateView` (with `retry` action + `searchMap.w208.sheet.failed.detail`) and `CYEmptyStateView` (with `searchMap.w208.sheet.emptyHint`), synchronized with `docs/search-map-localizations.json`.
- [`App/DiscoveryTemplateBrowserView.swift`](file:///Users/fanning/orca/workspaces/native-ios/DES-ag7/App/DiscoveryTemplateBrowserView.swift) & [`App/DiscoveryTemplateDetailView.swift`](file:///Users/fanning/orca/workspaces/native-ios/DES-ag7/App/DiscoveryTemplateDetailView.swift) (Template 2): Migrated unconfigured `ContentUnavailableView` states to `CYEmptyState(..., kind: .offline)` without adding retry (preserving unconfigured fail-closed gate).
- [`App/CityCurrentSnapshotView.swift`](file:///Users/fanning/orca/workspaces/native-ios/DES-ag7/App/CityCurrentSnapshotView.swift) & [`App/CityOrderedMapView.swift`](file:///Users/fanning/orca/workspaces/native-ios/DES-ag7/App/CityOrderedMapView.swift) (Template 6): Migrated expired/unloaded `ContentUnavailableView` states to `CYStateLayout` with `citySnapshot.expired` / `citySnapshot.unloaded`, preserving foreground-only `"重新读取"` action and accessibility identifiers (`city.currentSnapshot.refresh`, `city.orderedMap.refresh`).
- [`App/BundleAppealView.swift`](file:///Users/fanning/orca/workspaces/native-ios/DES-ag7/App/BundleAppealView.swift), [`App/BundleCancelView.swift`](file:///Users/fanning/orca/workspaces/native-ios/DES-ag7/App/BundleCancelView.swift), [`App/BundleReviewComposeView.swift`](file:///Users/fanning/orca/workspaces/native-ios/DES-ag7/App/BundleReviewComposeView.swift), [`App/BundleReviewListView.swift`](file:///Users/fanning/orca/workspaces/native-ios/DES-ag7/App/BundleReviewListView.swift), [`App/CityActionBudgetView.swift`](file:///Users/fanning/orca/workspaces/native-ios/DES-ag7/App/CityActionBudgetView.swift) (Templates 6/8/10): Replaced `CYStateTone.banned` wording (`暂不可用`, `unavailable`, `Please`) with calm mini-program wording and added actionable detail on empty review list while keeping all locked/unavailable gates free of invented retries.
- [`App/GlobalSearchView.swift`](file:///Users/fanning/orca/workspaces/native-ios/DES-ag7/App/GlobalSearchView.swift) (Template 3): Removed `.lineLimit(1)` on `kindPill`, stacked `searchMap.partialFailure` vertically at `dynamicTypeSize >= .xxLarge`, and updated `CURRENT_VIEW_SHA256` in `Tests/ContractChecks/test_global_search_category_recovery.py` (following `ui/h-tokens-v1` precedent; historical `VIEW_SHA256` / `OLD_VIEW_SHA256` unchanged).
- `Resources/Localizable.xcstrings` & `Resources/StoreCharacter.xcstrings`: Cleaned up banned/non-actionable copy across shared state keys (`cy.kit.offline.body`, `暂时无法加载内容`, `请检查网络连接后重试`, `merchantNPCHistory.failed`, `couponCode.serviceDisabled`, `couponCode.serviceDisabled.detail`, `activity.unavailable`, `storeCharacter.error.request`, `storeCharacter.error.network`).

---

## 2. Local `swiftc -parse` Results

Executed on every changed `.swift` file (and `-D DEBUG` for files containing `#Preview` / fixture references):

```text
swiftc -parse App/AccountCollectionCouponsView.swift -> exit 0
swiftc -parse App/BundleAppealView.swift -> exit 0
swiftc -parse App/BundleCancelView.swift -> exit 0
swiftc -parse App/BundleReviewComposeView.swift -> exit 0
swiftc -parse App/BundleReviewListView.swift -> exit 0
swiftc -parse App/CityActionBudgetView.swift -> exit 0
swiftc -parse App/CityCurrentSnapshotView.swift -> exit 0
swiftc -parse App/CityOrderedMapView.swift -> exit 0
swiftc -parse App/DesignSystem/CYBusinessComponents.swift -> exit 0
swiftc -parse App/DesignSystem/CYSharedStates.swift -> exit 0
swiftc -parse App/DesignSystem/CYStateKit.swift -> exit 0
swiftc -parse App/DesignSystem/CYStates.swift -> exit 0
swiftc -parse App/DiscoveryTemplateBrowserView.swift -> exit 0
swiftc -parse App/DiscoveryTemplateDetailView.swift -> exit 0
swiftc -parse App/GlobalSearchView.swift -> exit 0
swiftc -parse App/NearbyTeamMapViews.swift -> exit 0
swiftc -parse App/OfficialOrganizerConsoleView.swift -> exit 0
swiftc -parse App/PlayAdvancedTeamViews.swift -> exit 0
swiftc -parse App/PlaySharedPlanLifecycleView.swift -> exit 0
swiftc -parse App/SearchMapResultsCapsule.swift -> exit 0
swiftc -parse -D DEBUG App/DesignSystem/CYSharedStates.swift App/DesignSystem/CYStateView.swift -> exit 0
```

---

## 3. VPS Verification Results (`instabox exec work` in `/data/workspace/appcheck-ui-h-states-copy`)

Verified on clean checkout at `HEAD=15fc38fd0e7591a1204e0fa3fbb364e0d48b62bf`:

```text
HEAD=15fc38fd0e7591a1204e0fa3fbb364e0d48b62bf
PASS design lint: scanned 1634 App Swift files outside DesignSystem and Theme; allowlist 29 files (44 existing violations)
PASS accessibility lint: 10 scoped screens, helper checked, 2 range views left, 3096 other App views not scanned
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
PASS design lint: scanned 1634 App Swift files outside DesignSystem and Theme; allowlist 29 files (44 existing violations)
PASS accessibility lint: 10 scoped screens, helper checked, 2 range views left, 3096 other App views not scanned
LEFT ExternalGameCatalogLaunch, CYFloatingTabBarClearance
NOTE App/AppCompositionRoot.swift: 4171 < ratchet 4184; lower CEILINGS in tools/check_appsession_ratchet.py
PASS appsession ratchet
PASS page route table: 262 pages
PASS structural checks: 4774 Swift source files, 16570 bilingual keys, references, scheme, read-only expected project equivalence
SCOPE: this script does not run Swift/Xcode, previews, simulator/device, accessibility or live backend checks; see separate evidence
contract ratchet: 186 failing, baseline 186, new 0, fixed 0
```
