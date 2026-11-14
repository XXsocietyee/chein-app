# ui-cur-uitests-2 — Task 66 XCUITest golden paths

Base: `origin/ui/main` at `3ac970ec20191014b4b9a8779a3a94b961e99c9c` (unchanged at branch time). Head: `ui/cur-uitests-2`.

`Tests/AppUITests/WorkflowJourneyGoldenPathUITests.swift` was not on this tip, so it was added rather than mirrored. New Swift is registered by `python3 tools/generate_project.py`.

DEBUG fixtures only. No network. `ReviewedAreaSwitch` is not redeclared. `www.chengyinhub.com` is not shown as a succeeded payout or payment. `App/RegionalLaunchConfiguration.swift`, `App/AppSession.swift`, and `App/AppCompositionRoot.swift` were not edited. The contract baseline was not raised.

This VM has no `swiftc`. XCUITest was not executed.

## Journeys

| Journey | Test method | Fixture | What the test does |
|---|---|---|---|
| Merchant | `WorkflowJourneyGoldenPathUITests.testMerchantHomeOpensOrdersThenProjects` | `--design-fixture merchant-home` (`MerchantConsoleFixture` / `DesignMerchantReader`) | Store name, then order `101`, back, then the Activities tab and project `activity:201`. The design rows are activities, so the default Themes tab is empty. |
| Wallet / payout | `WorkflowJourneyGoldenPathUITests.testWalletAndPayoutDoNotShowSuccessOnProductionHost` | `--wallet-commerce-fixture`; `--design-fixture cur4-edition-empty-closed`; `--design-fixture cur4-edition-empty`; `--owner-decision-fixture receiver` | Income row `wallet.income.detail.open.4` and no Pay button. Closed host is `www.chengyinhub.com`: `ClubEditionEmptyReasonView` calls `ReviewedAreaSwitch.moneyPayments(apiHost:)` (same `openMoney` gate as `payout`) and stays on the generic empty line. Open host is `fixture.example` and shows `NO_PERMISSION`, still with no payment success. Receiver fixture is `payoutEnabled: false` and the “starts when the platform turns payouts on” line. `已开通` is absent. The merchant payout fixture that embeds `https://www.chengyinhub.com/sign/example` is not launched. |
| External games | `WorkflowJourneyGoldenPathUITests.testExternalGamesFailClosedWithoutSessionDoesNotSubmit` | `--design-fixture e5-external-game` (`ExternalGameLibrarySection` with no session) | Catalog fails closed (`externalGame.catalog.error`). Install buttons are absent, so catalog → detail → install is not tapped. `externalGame.submitReview` is not tapped. My submissions opens and shows `externalGame.submissions.error`. |
| Compliance delete | `WorkflowJourneyGoldenPathUITests.testComplianceDeleteReviewStaysUnconfirmed` | `--design-fixture e4-deregister` (`AccountComplianceSheet` review) | Review warning and server status are on screen. `compliance.submit` stays disabled. Confirm is not tapped. `compliance.completed` is absent. |

## Skipped

| Journey | Reason |
|---|---|
| External games catalog → detail → install, and submit → my submissions as a successful submit | The only external-game DEBUG host on this tip is `e5-external-game`. It mounts `ExternalGameLibrarySection` with no session, so `ExternalGameReviewModel.reload` fails closed before any catalog row exists. Submit is not tapped. No second fixture was copied in. |
| Compliance export | `NPCChatDataExportButton` exists (`npcData.export`), but no DEBUG fixture on this tip mounts it. The offline host is `cur6-chat-export` on `ui/cur-fixtures-6` `e18da8f4860439030041d1708afa3ee10cecab01`, which is not merged. That type was not copied. |
| Search filters (handover 62) | `SearchListSort`, `search.sort.recent`, and the `cur6-search-*` hosts are on that same unmerged commit (`App/SearchMapFilterSheet.swift` there adds the sort picker). They are not on `origin/ui/main`. Older min/max/date controls in `SearchMapFilterSheet` are not the handover-62 controls, so that journey is skipped. |

## Gates

- `python3 tools/generate_project.py`
- `python3 tools/check_scaffold.py`
- `python3 tools/check_design_lint.py`
- `swiftc` / XCUITest: not run
