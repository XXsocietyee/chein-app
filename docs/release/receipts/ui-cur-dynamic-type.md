# ui-cur-dynamic-type

Dynamic Type and long-text pass on `ui/h-design-v1` @ `5d652cc08ac5ccc668db315fc57253b909b9e058`. No restyle branch was merged. No new screen was added. Copy and colors are unchanged. Prices and counts stay on existing tabular APIs (`CYTypography.numericBody` / `dataXL` / `data2XL`, or `.monospacedDigit()`). No new font.

Base already contains `origin/ui/main`. This branch does not merge `ui/main` again.

## Templates

All 14 templates already have screens on this branch. None are absent.

| Template | Screens touched | What clipped | Change |
|---|---|---|---|
| Hero feed | `HomeSearchTabParityViews` | Search placeholder forced to one line | `.cyWrapText()`; search trait kept |
| Square | `SquareXcxPostCard`, `SquareCloudFeedViews`, `SquareCloudComposerView`, `DiscoveryTemplateBrowserView` | Nickname, post title, stat, chip, composer name and draft name at one line | Wrap those titles. Count pill stays `.caption2.monospacedDigit()` |
| Map search | `GlobalSearchView`, `SearchMapComponents` | Kind pill and keyword chips used `lineLimit(1)` plus `minimumScaleFactor` | Chips and tags wrap. Kind pill wraps and uses `.monospacedDigit()` |
| Immersive detail | `DiscoveryTemplateDetailView`, `TopicXcxSections` | Stop name, node name, member name, template title | Those titles wrap. Horizontal category chips stay one line because the chip grows with the label |
| Checkout | `WalletCommerceViews`, `RegistrationSheetView`, `ProfileOrdersView`, `OrderCardComponents` | Month title, amounts, ticket name, checkout total beside the review button, order labels | Titles and amounts wrap. `dataXL` / `data2XL` / `numericBody` kept. Total and review button stack from `.xxLarge` via `CurA11yActions`. Ticket name and price stack the same way |
| Game runtime | `PlayExperienceView`, `PlayStoreDayMerchantView`, `RoamLiveSessionView`, `RoamPassportToolsViews`, `JourneyReportViews` | Chapter name, stat values, recap count shrunk with `minimumScaleFactor` | Titles and figures wrap. Existing `dataXL` / `.monospacedDigit()` kept, including the allowlisted 64pt recap glyph |
| Profile and growth | `GrowthCenterView`, `GrowthLeaderboardView`, `PassportView`, `MemberHomeHeader`, `SocialPublicProfileView` | Nickname, podium name, score, action labels, stat labels | Names and labels wrap. Score row stacks from `.xxLarge` via `CurA11yPair`. Counts stay `data2XL` / `.monospacedDigit()` |
| Lists and inbox | `InvoiceLaunchHistoryView`, `PublishingManagementViews`, `RoamHistoryViews`, `RoamSubpageParityViews`, `CYListRow` | Row titles, filter label, distance and run titles, trailing values | Titles and trailing values wrap. Times and amounts use `.monospacedDigit()` or `numericBody` |
| Chat | `MessagingHistoryView`, `IMInboxViews`, `ClubChannelMessagingView` | Conversation name in the bar, channel name at two lines, attachment title | In-transcript hero wraps. At accessibility sizes the bar keeps the avatar and the wrapping name lives in the transcript so it does not collide with the toolbar. Channel names and attachment titles wrap |
| Forms | `RegistrationSheetView`, `AuthChannelView` | Checkout titles (above) and the send-code label | Send-code label wraps. No copy change |
| Creator studio | `PublishingModesViews`, `ActivityPublishingWizardView`, `CYPublishStatusBar` | Activity publish title, wizard step titles, footer pair, publish-status steps | Titles wrap. Wizard steps and the two footer buttons stack at accessibility sizes. The `xxxLarge` cap on the time-range footer is gone |
| Merchant workbench | `MerchantHomeView`, `MerchantMarketingHomeSections` | Store name at two lines; revenue and tile counts shrunk to half size | Store name and revenue wrap. Revenue stays `CYTypography.display` plus `.monospacedDigit()`. Unknown revenue is still an em dash. Tile counts wrap and stay `dataXL` / `data2XL` |
| Club ops | `CoopSettlementDetailView`, `ClubOpsSettlementViews`, `ClubOwnerFundsView` | Settlement amount and fund row title/amount forced to one line | Amounts wrap and keep `dataXL` / `data2XL` / `numericBody`. Unknown stays the existing em dash or 「金额待核验」 |
| Settings and legal | `SettingsView`, `SettingsAboutView` | Account nickname at two lines; about fact value at one line | Nickname and fact values wrap. Fact values stay `numericBody` |

Shared controls cover the other screens of the same templates (feed, square browser, detail, settings legal, creator lists) without new views:

- `CYNavBar`: title wraps. At an accessibility size the title sits under the button row instead of inside the 44pt bar.
- `CYPrimary` / `Secondary` / `Ghost` / `Destructive` and domain button styles: labels wrap and grow downward.
- `CYSectionHeader`: title and action stack at an accessibility size.
- `CYTabs` and `CYRootTabBarStrip`: tab titles wrap.
- `CYListRow` and `CYMoneyRow`: title and amount wrap. Amounts stay `numericBody`.
- `CYPublishStatusBar`: step titles wrap and stack at an accessibility size.

## Left in place

- Avatar, icon, hairline, and cover frames.
- `PlayKitQuestionForms` wheel rows stay one line inside the system wheel.
- Allowlisted `.system(size:)` glyphs in `WalletCommerceViews` (2) and `RoamPassportToolsViews` (1) were not removed and not added to.
- No DEBUG fixture file changed. Touched screens keep their existing fixtures; none of those fixtures encoded a one-line title assertion.
- No new network call. `RegionalLaunchConfiguration`, `AppSession`, `AppCompositionRoot`, and `docs/release/contract-failing-baseline.txt` were not edited.

## Contract pins that follow the bytes

- `Tests/ContractChecks/test_global_search_category_recovery.py` `CURRENT_VIEW_SHA256` matches the wrapped `GlobalSearchView`. The historical `VIEW_SHA256` is unchanged.
- `Tests/ContractChecks/test_activity_publishing_wizard.py` `SUFFIX_SHA` matches the publishing suffix after the Dynamic Type cap was removed. Prefix and quick slices are unchanged.
- `Tests/ContractChecks/test_merchant_project_workspace_entry.py` records the store-name and revenue wrap so the existing inverse still restores the historical home hash.
- `Tests/ContractChecks/test_accessibility_hardening_wave.py` expects the search placeholder and channel name to wrap.

## Checks

`python3 tools/check_design_lint.py` PASS (allowlist still 29 files, 44 existing violations). `python3 tools/check_scaffold.py` PASS. No `swiftc`.

## Screen count

40 existing screens were edited. 9 shared design-system files were edited. 0 templates are absent.
