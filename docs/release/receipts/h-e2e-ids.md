# h-e2e-ids receipt: accessibility identifiers for E2E Maestro flows

Branch `ui/h-e2e-ids` from `origin/ui/h-e2e-flows` (`2295579ec`). No `xcodebuild`, `swift build`, or `swift test` was run in this workspace; verification is `swiftc -parse` per edited Swift file, `maestro check-syntax` across all 18 flows, and the Python structural/lint/ratchet gates.

## Identifiers Added

| Surface | File & Line | Identifier(s) |
|---|---|---|
| Native `TabView` `UITabBarItem` identifier helper (`cyTabBarAccessibilityIdentifiers`) | `App/DesignSystem/CYDomainTabBar.swift:122-207` | Assigns identifier list onto `UITabBar.items` without altering item labels |
| Player root `TabView` tabs (`home`, `roam`, `club`, `mine`) | `App/QuestifyApp.swift:272,296,302,309,323` | `rootTabBar.tab.player.0` .. `rootTabBar.tab.player.3` |
| Merchant `SessionMerchantRootContainerView` tabs (`workbench`, `marketing`, `templates`, `cooperation`, `mine`) | `App/HomeSearchTabParityViews.swift:1130,1166,1187,1208,1225,1231` | `rootTabBar.tab.merchant.0` .. `rootTabBar.tab.merchant.4` |
| Passport toolbar Settings gear | `App/AccountView.swift:181` | `account.settings` |
| `roam.more` Menu items (City, Nearby Teams) | `App/RoamBrowserView.swift:284,288` | `roam.more.city`, `roam.more.nearbyTeams` |
| Registration confirmation `.alert` confirm button | `App/RegistrationSheetView.swift:135` | `registration.form.confirm` |
| `TopicXcxActionBar` CTA buttons (matching sibling `topic.cta.pricing`) | `App/TopicXcxSections.swift:161,166,170` | `topic.cta.sessions`, `topic.cta.selfPlay`, `topic.cta.signUp` |
| Play hint `.confirmationDialog` confirm button | `App/PlayExperienceView.swift:792` | `playx.hints.confirm` |
| Sheet toolbar `action.close` buttons | `App/SessionHomeFeedView.swift:46,54,73,84,173`, `App/UsageConsentGateView.swift:162` | `globalSearch.close`, `projectEditor.close`, `create.close`, `templates.close`, `miniGames.close`, `usageConsent.legal.close` |
| `LoginView` toolbar `action.close` button | `App/LoginView.swift:145` | `auth.close` |
| `RoamHistoryToolsRow` & Passport Tools export links | `App/RoamSubpageParityViews.swift:130`, `App/RoamPassportToolsViews.swift:65` | Already present (`roamSub.w208.history.tool.export`, `roam.export.open`); preserved intact for existing tests |

## YAML Flows & Docs Updated

- `e2e/maestro/city-game.yaml`: uses `rootTabBar.tab.player.1` -> `roam.more` -> `roam.more.city` -> `city.read.screen`, plus `globalSearch.close`.
- `e2e/maestro/roam.yaml`: uses `rootTabBar.tab.player.1` (instead of `chein://roam/go` deep link) and checks `roam.more` -> `roam.more.nearbyTeams` -> `nearby.w208.header`.
- `e2e/maestro/im-dm-preview.yaml`, `e2e/maestro/rewards-store.yaml`, `e2e/maestro/wallet.yaml`: navigate to Passport via `rootTabBar.tab.player.3`.
- `e2e/maestro/workshop-purchased-install.yaml`: navigates via `rootTabBar.tab.player.3` -> `account.settings` -> `account.workshopPurchased` and conditional `workshopPurchased.row.*` / `workshopPaidInstall.*`.
- `e2e/maestro/discover-activity-signup.yaml`: taps `registration.form.confirm` (when alert appears) and `registration.form.close`.
- `e2e/maestro/play-session.yaml`: taps `playx.hints.confirm` (when dialog appears).
- `e2e/maestro/permissions.yaml`: opens legal sheet via `authEntry.gate.privacyGuide` and closes with `usageConsent.legal.close`.
- `e2e/maestro/merchant-ops-payout.yaml`: exercises `rootTabBar.tab.merchant.0` and `rootTabBar.tab.merchant.1`.
- `e2e/maestro/external-game.yaml`, `e2e/maestro/search-filters.yaml`: close sheets via `miniGames.close` / `globalSearch.close`.
- `e2e/maestro/account-export-deletion.yaml`, `e2e/maestro/creator-publish-review-appeal.yaml`, `e2e/maestro/MISSING_IDS.md`, `e2e/maestro/RESULTS_TEMPLATE.md`: updated gap notes/status.

## Gates

- `swiftc -parse` on all 11 modified Swift files: PASS
- `maestro check-syntax` on all 18 `e2e/maestro/*.yaml` flows: PASS (18/18 OK)
- `python3 tools/check_scaffold.py`: PASS (4767 Swift files, 16558 bilingual keys, 262 page routes)
- `python3 tools/check_design_lint.py`: PASS (1632 App Swift files outside DesignSystem/Theme, 0 new violations)
- `python3 tools/check_appsession_ratchet.py`: PASS
