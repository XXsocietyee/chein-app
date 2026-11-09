# CB76 merge queue C

Base: `origin/rc/20261108` `89dcba807e7e5439182ff8852d6600d1fa9fdd49`.

Queue order is the design branches first, then the UI lanes. A lane whose tip is already contained in `rc/20261108` is skipped. `origin/ui/d6` (`6da55e127b99e99b790a593d8e0e6987e43ca2ca`) is not in this queue and is not in this branch.

Version stays `0.1.0` (`1`) in `Config/Base.xcconfig`. `.github/workflows/ios-ci.yml` and `tools/current_ci_manifest.json` are unchanged from the base. No test path was deleted. `Questify.xcodeproj/project.pbxproj` was regenerated with `python3 tools/generate_project.py` and was not hand-edited. This VM has no Xcode; nothing here is a build.

For a UI-lane merge, the design side of a view, fixture, or catalog conflict is the side already on this branch (`HEAD` / ours). The incoming UI lane is theirs. Design branches were merged before those lanes, so `--theirs` would drop the design. T1 screens (launch path in `docs/release/ui-tiers.md` on `cursor/cb25`: `HomeFeedView`, `DiscoveryTemplateBrowserView`, `ClubHomeView`, `AccountView`, `RoamBrowserView`, `PrivacyProtectionView`, `SettingsLegalDocumentView`, `TeamHomeView`, `PlayExperienceView`, `ActivityDetailView`, `RegistrationSheetView`, `OfficialEventsBrowserView`, `GrowthCenterView`, `TopicDetailView`, `GlobalSearchView`, `SettingsView`, `ProfileOrdersView`, `OrderLifecycleView`, `TicketWalletView`, `RoamItemDetailView`) were not conflicted by any UI lane. No T1 hunk was left unresolved, and no design edit to a T1 file was dropped.

## Lanes

| Order | Lane | Lane tip | Result |
|---|---|---|---|
| 1 | `origin/ui/kit` | `292417cddde11e98ceae91580c2aff963851353f` | Skipped. Already contained in rc. No merge commit. |
| 2 | `origin/ui/d1` | `da6bed72d31bec4033382f90f5e43e9b3ca3336b` | Skipped. Already contained in rc. No merge commit. |
| 3 | `origin/ui/d2` | `d7509d1a2311ab2cd73e51901dce218b428d9d75` | Skipped. Already contained in rc. No merge commit. |
| 4 | `origin/ui/d3` | `939b0e6b4217e17cc44606f6c91de7bad564ae9e` | Skipped. Already contained in rc. No merge commit. |
| 5 | `origin/ui/d4` | `8c52c4638bcff1a4298fd2ffa13bf9f433ae8c36` | Skipped. Already contained in rc. No merge commit. |
| 6 | `origin/ui/d5` | `032c7d2333aff2b4ccece665c2c46da81b45d988` | Merge `14e0526776d9e191cb05f920a8801b9eb0ff4ffd`. |
| 7 | `origin/cursor/theme` | `cfd65e7fddcece2dc3b7e40b2cc708934188a562` | Merge `fe7ce718f2938012258f1d39da2487cc486e3ec7`. |
| 8 | `origin/cursor/ui-list` | `0765d3053ea2d29d5afa52d72ed8c0fff547f0d6` | Merge `c5f6d9aa666fb35939fc99fdd3d7c3a76991e1fc`. |
| 9 | `origin/cursor/ui-detail` | `3c8016846bdbde0533e861e563bc9d18bfd2239e` | Merge `a5d8ed91a9b2b11caaacc1b37cb2fc6f42d00621`. |
| 10 | `origin/cursor/ui-form` | `2b957c7348d0c3b528d2d6a2f2635957c51759af` | Merge `45fc9b8c653e91df085409dc6806011afed66c7a`. |
| 11 | `origin/cursor/ui-settings` | `c4109d858e6e99340fdfca20a7c9af13e3fdbee3` | Merge `a48a5c03007646626c9ecc1b1282134b321aa590`. |
| 12 | `origin/cursor/ui-chat` | `e3a173ac96b2319d8956ab30d780922f8563c35c` | Merge `905ba021fc350d7e0a67e8e6f2c72835640fd06a`. |
| 13 | `origin/cursor/ui-empty` | `6284f2ce7aa6403f7e665acb6048e16d01096c12` | Merge `1c5abb9426e3af3db3e6f385c0e934469a13f697`. |

## Conflicts

### `origin/ui/d5` → `14e0526776d9e191cb05f920a8801b9eb0ff4ffd`

- `App/DesignFixtures/DesignFixtureRegistry.swift` (fixture). Both sides inserted cases at the same switch. `--theirs` alone would drop the D4 cases already on rc. Kept both design case lists: D4 directory/detail/channels/confirm/settings/growth/leaderboard/badges, and D5 `merchant-home`, `merchant-home-unknown`, `merchant-orders`, `merchant-projects`, `merchant-customers`, `merchant-finance`, `merchant-coupons`.
- `Questify.xcodeproj/project.pbxproj`. Not hand-edited. Regenerated so `App/DesignFixtures/MerchantConsoleFixtures.swift` is registered (12 lines).

### `origin/cursor/theme` → `fe7ce718f2938012258f1d39da2487cc486e3ec7`

No content conflict. The auto-merged project used the lane's file ids for `CYScreenStyle.swift`. Regenerated so those ids come from `tools/generate_project.py`.

### `origin/cursor/ui-list` → `c5f6d9aa666fb35939fc99fdd3d7c3a76991e1fc`

View conflicts. Each hunk kept the design side (`HEAD`). Non-conflicting kit edits in the same files stayed. None of these files are T1.

- `App/GrowthLeaderboardView.swift`. Kept `.cyDomainPageBackground()`. Did not take the lane's `.navigationBarTitleDisplayMode(.inline)` replacement of that modifier.
- `App/ObjectBadgeViews.swift`. Kept `.cyDomainPageBackground()` on the badge list. Did not take `.themeDomain(.player)` in place of it.
- `App/WalletCommerceViews.swift`. Kept the design income badge (`Text` in an accent capsule). Did not take `CYStatusChip(verbatim: badge, tone: .info)`.

### `origin/cursor/ui-detail` → `a5d8ed91a9b2b11caaacc1b37cb2fc6f42d00621`

View conflicts kept the design side. None are T1. `WalletCommerceViews.swift` had diverged as a page (D3 earnings hero, quick actions, and month income versus the lane's overview links), so the whole path stayed the design file already on the branch. A hunk-wise mix would have kept a `WalletOverviewIssue` call without that page.

- `App/ClubDetailView.swift`. Kept `VStack(alignment: .leading, spacing: Theme.Space.s2)`. Did not insert `CYHeroHeader("club.detail")` at that spot.
- `App/MerchantHomeView.swift`. Kept the D5 store title (`CYTypography.pageTitle`, identifier `merchant.store.name`) and the elevated circle (`.background(CYColor.bgElevated, in: Circle())` plus the subtle stroke and shadow). Did not take `CYHeroHeader(verbatim:titleIdentifier:)` or the lane's palette circle.
- `App/WalletCommerceViews.swift`. Whole file kept from `HEAD`.

Kit files are not views, fixtures, or catalogs. Call sites from both lanes were kept:

- `App/DesignSystem/CYHeroHeader.swift`. Kept `tableName` (used by `WalletIncomeAnalysisView`) and added the lane's verbatim initializer, `titleIdentifier`, and `CYOptionalAccessibilityIdentifier`.
- `App/DesignSystem/CYPillButton.swift`. Kept `tableName` and added `init(verbatim:)`.
- `App/DesignSystem/CYImageCard.swift`, `CYListRow.swift`, `CYStatusChip.swift`. Kept `HEAD`. The lane's alternate storage did not add a call the `HEAD` APIs lack. Image-card meta stays the design line (`monospacedDigit()`, `lineLimit(2)`).

### `origin/cursor/ui-form` → `45fc9b8c653e91df085409dc6806011afed66c7a`

No conflict.

### `origin/cursor/ui-settings` → `a48a5c03007646626c9ecc1b1282134b321aa590`

No conflict.

### `origin/cursor/ui-chat` → `905ba021fc350d7e0a67e8e6f2c72835640fd06a`

- `App/DesignSystem/CYConfirmSheet.swift`. Not a view, fixture, or catalog, and not T1. Kept the design consequence list, scroll, and cancel-left / confirm-right layout. Added the chat lane's `cancelIdentifier` and `titleIdentifier` so `MessagingHistoryView` can still set `im.safety.cancel` and `im.safety.reviewTitle`.

### `origin/cursor/ui-empty` → `1c5abb9426e3af3db3e6f385c0e934469a13f697`

- `App/DesignSystem/CYStates.swift`. Not a view, fixture, or catalog, and not T1. Kept `tableName` (used by `WalletIncomeAnalysisView`) and added the lane's `detail`, `actionIdentifier`, and `actionStyle` used by `PlayCircleRetiredLinkView`.

## Not merged

`origin/ui/d6` `6da55e127b99e99b790a593d8e0e6987e43ca2ca`.
