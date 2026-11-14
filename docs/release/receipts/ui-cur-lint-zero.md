# Receipt: `ui/cur-lint-zero`

Parent is `ui/h-design-v1` at `5d652cc08ac5ccc668db315fc57253b909b9e058`. That commit already contains `origin/ui/main` at `5ba7b0f2c5f10dea10905895da947c350b3e24ac`. `ui/main` was not merged again. The cur-t restyle branches were not merged. `ui/h-design-v1` was not moved.

`tools/check_design_lint.py` started with 29 allowlisted files and 44 hits (raw hex, fixed font size, violet/purple). Each hit below now calls a token that already existed on this branch. The production allowlist is empty. The linter still fails a new hit, an extra hit in a listed file, and a stale list entry. The last two checks install a temporary `App/WelcomeView.swift` entry inside `check_rules` and remove it before the scan, so they keep working after the production map is empty. No new allowlist entry was added. No rule was loosened.

`#7A5CFF` stays on `CYColor.tabSelected`, `CYColor.avatarRing`, and `CYColor.resultSpinner`. No slate-blue `#0F172B`, `#334155`, or `#64748B`. No `CYRadius.card`. Cards stay borderless. Copy, data bindings, grants, and money switches are unchanged. Unknown stays an em dash. `RegionalLaunchConfiguration`, `AppSession`, and `AppCompositionRoot` were not edited. `OwnerDecisionFixtureHost` was not re-added. The contract baseline was not edited. No new Swift file. No body was split: each edit is a token substitution inside the existing view. `swiftc` was not run.

## Replacements

| File | Old hit | Token |
| --- | --- | --- |
| `App/AccountComplianceViews.swift` | `.font(.system(size: 24, weight: .semibold))` | `CYTypography.sheetTitle` |
| `App/AuthChannelView.swift` | `.font(.system(size: 26, weight: .semibold))` | `CYTypography.display` |
| `App/UsageConsentGateView.swift` | `.font(.system(size: 30, weight: .semibold))` | `CYTypography.display` |
| `App/WelcomeView.swift` | `.font(.system(size: 46, weight: .semibold))` | `CYTypography.data2XL` |
| `App/CityArrivalEvidenceView.swift` | `.font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())` | `CYTypography.data2XL` |
| `App/ClubPostDiscussion.swift` | `.font(.system(size: 1))` on the clipped fixture trace | `CYTypography.micro` |
| `App/CoopSettlementDetailView.swift` | `.font(.system(size: 7))` timeline dot | `CYTypography.micro` |
| `App/CreatorApplicationView.swift` | `.font(.system(size: 24, weight: .semibold))` | `CYTypography.sheetTitle` |
| `App/CreatorApplicationView.swift` | `SettingsTint.purple` | `SettingsTint.indigo` (`CYNight.indigo`, same colour as the removed alias) |
| `App/ProfileComplaintPreparationView.swift` | `.font(.system(size: 24, weight: .semibold))` | `CYTypography.sheetTitle` |
| `App/ShopNPCView.swift` | `.font(.system(size: 17, weight: .bold))` send icon | `CYTypography.button` |
| `App/ShopNPCView.swift` | `.font(.system(size: 17, weight: .semibold))` mic icon | `CYTypography.button` |
| `App/TicketWalletView.swift` | `Color(red: 0.24, green: 0.20, blue: 0.46)` cover stop | `CYNight.indigo` |
| `App/TicketWalletView.swift` | `.font(.system(size: 120))` ticket mark | `CYTypography.data2XL` |
| `App/TicketWalletView.swift` | `.font(.system(size: 34))` QR mark | `CYTypography.dataXL` |
| `App/ChatMessageBubble.swift` | comment word `violet` | `CYColor.tabSelected` |
| `App/ClubComponents.swift` | `.font(.system(size: 34))` map pin | `CYTypography.dataXL` |
| `App/ClubComponents.swift` | comment `#1C1C1E` | `CYColor.bgElevated` on `CYColor.bgPage`, radius named `CYRadius.xxl` |
| `App/PublishingContextHandoffViews.swift` | comment `#2F6DF0` | `CYColor.infoText` |
| `App/PublishingContextHandoffViews.swift` | comment word `purple` | `CYColor.brand` / `CYColor.tabSelected` |
| `App/SettingsView.swift` | `SettingsTint.purple` (two call sites) | `SettingsTint.indigo` |
| `App/SettingsView.swift` | `static let purple` | removed; `SettingsTint.indigo` is the same `CYNight.indigo` |
| `App/SettingsView.swift` | comment word `violet` | `CYColor.tabSelected` |
| `App/PushNotificationAndLiveActivitySectionView.swift` | `tint: .purple` | `CYColor.infoText` |
| `App/DesignFixtures/E3Fixtures.swift` | `.purple` stop on the story avatar ring | `CYColor.avatarRing` |
| `App/MerchantBusinessEditor.swift` | `"#2E6D5A"` tag-colour default | `MerchantCustomerBatchTag.defaultColor` (same submitted string) |
| `App/PlayJourneyContentViews.swift` | `.font(.system(size: 56, weight: .bold, design: .rounded))` | `CYTypography.data2XL` (em dash for an unknown total unchanged) |
| `App/PlayKitTimedChallengeView.swift` | `.font(.system(size: 76, weight: .bold, design: .rounded))` clock | `CYTypography.data2XL` |
| `App/PlayKitTimedChallengeView.swift` | `.font(.system(size: 44, weight: .semibold))` idle hand | `CYTypography.data2XL` |
| `App/PlayKitTimedChallengeView.swift` | `.font(.system(size: 44, weight: .semibold))` go / wait hand | `CYTypography.data2XL` |
| `App/PlayKitTimedChallengeView.swift` | `.font(.system(size: 34, weight: .semibold))` result icon | `CYTypography.dataXL` |
| `App/PlayKitTimedChallengeView.swift` | `.font(.system(size: 44, weight: .bold, design: .rounded))` result value | `CYTypography.data2XL` |
| `App/ObjectBadgeViews.swift` | `.font(.system(size: 76, weight: .semibold))` medal | `CYTypography.data2XL` |
| `App/OrderLifecycleView.swift` | `.font(.system(size: 34, weight: .regular))` | `CYTypography.dataXL` |
| `App/HomeSearchTabParityViews.swift` | `.font(.system(size: 40))` play mark | `CYTypography.dataXL` |
| `App/RoamPassportToolsViews.swift` | `.font(.system(size: 64, weight: .heavy, design: .rounded))` | `CYTypography.data2XL` |
| `App/SocialGuideViews.swift` | `.system(size: 56, weight: .thin)` large article mark | `CYTypography.data2XL` |
| `App/E1CommerceComponents.swift` | `.font(.system(size: min(width, height) * 0.3, weight: .light))` | `CYTypography.display`, scaled by that ratio over `--cy-type-display` |
| `App/E1CommerceComponents.swift` | `.font(.system(size: 8, weight: .semibold))` debug label | `CYTypography.micro` |
| `App/DiceD20View.swift` | `.font(.system(size: max(12, radius * 0.36), weight: .bold, design: .rounded))` | `CYTypography.numericBody`, scaled by that size over `--cy-type-body` |
| `App/IMInboxViews.swift` | `.font(.system(size: symbolSize, weight: .semibold))` | `CYTypography.dataXL`, scaled by `symbolSize / --cy-type-data-xl` |
| `App/WalletCommerceViews.swift` | `.font(.system(size: size * 0.7, ...))` currency symbol | `CYTypography.dataXL` |
| `App/WalletCommerceViews.swift` | `.font(.system(size: size, ...))` amount | `CYTypography.data2XL` (unknown currency still `—`) |

## Checks

`python3 tools/check_scaffold.py` passed, including catalog coverage, privacy, the design lint, accessibility lint, the AppSession ratchet, and the page route table. `python3 tools/check_design_lint.py` passed on its own: `allowlist 0 files (0 existing violations)`. `swiftc` was not run.
