# `ui/h-premerge` Pre-Merge Receipt

Base: `origin/ui/main` (`a31949367a58056d926d204e3bfdc6020b12cb8e`; `origin/ui/next` `6feee423a` is 44 commits behind `origin/ui/main` and 0 ahead).

## Group A — Functional

| Branch | Source SHA | Conflicts | Resolution |
| --- | --- | --- | --- |
| `origin/ui/cur-fixtures-9` | `6d482286f2` | `App/ClubChannelMessagingView.swift`, `App/ClubGovernanceViews.swift`, `App/MerchantHomeView.swift`, `App/PlayGapMiscSurfaces.swift`, `App/ReviewedPlayerWriteLeases.swift`, `Resources/Localizable.xcstrings`, `docs/release/completeness-matrix.csv`, `App/Sweep2Surfaces.swift`, `Core/Sweep2Routes.swift`, `Tests/CoreTests/Sweep2HttpClientTests.swift`, `App/DesignFixtures/Cur9Fixtures.swift`, `Tests/AppUITests/Cur9SweepFixtureTests.swift`, `App/DesignFixtures/DesignFixtureReleaseExclusionAudit.swift` | Kept `--ours` for views/strings/matrix already superseded/resolved on `origin/ui/main`; kept deleted (`git rm`) the three `Sweep2*` files dropped in `origin/ui/main` (`87f976187`); adapted `Cur9LedgerHost` in `App/DesignFixtures/Cur9Fixtures.swift` to `ClubDirectLedgerSection(scope: .merchant(topicID: nil))` + `PayoutAreaClosedNote()` and updated expected copy in `Tests/AppUITests/Cur9SweepFixtureTests.swift` and `App/DesignFixtures/DesignFixtureReleaseExclusionAudit.swift`. |
| `origin/ui/h-appsec-csp` | `c4548a95c5` | None | Clean merge. |
| `origin/ui/h-ci-manifest` | `5090049b21` | None | Clean merge. |
| `origin/ui/cur-offline-tests` | `9d8ad2852a` | `docs/release/completeness-matrix.csv` | Kept `--ours` (`PKG-63-*` rows and CRLF rollup already present on `HEAD`). |
| `origin/ui/cur-view-map` | `8746ae3b33` | None | Clean merge. |
| `origin/ui/cur-api-contract` | `894a6411bb` | None (post-merge contract check in `Tests/ContractChecks/test_merchant_station_submission_import.py`) | Clean merge; updated `PROTECTED` SHA256 hashes in `Tests/ContractChecks/test_merchant_station_submission_import.py` for `Core/MerchantContentCommands.swift`, `Core/MerchantContentService.swift` (changed by `ui/cur-api-contract`), and `App/MerchantContentViews.swift` (updated on `origin/ui/main`). |
| `origin/ui/cur-fixtures-8` | `9d998c11d0` | `App/ClubGovernanceViews.swift`, `Tests/CoreTests/OwnerDecisionGuardTests.swift`, `docs/release/completeness-matrix.csv`, `docs/release/completeness-matrix.md`, `App/DesignFixtures/DesignFixtureRegistry.swift`, `App/DesignFixtures/DesignFixtureReleaseExclusionAudit.swift`, `App/MerchantOpsWp03Panel.swift` | Kept `--ours` for `ClubGovernanceViews.swift`, `OwnerDecisionGuardTests.swift` (`ClubPayoutReceiverLink` one-entry rule per `af74412be`), and completeness matrix files; preserved both fixture sets in `DesignFixtureRegistry.swift` and `DesignFixtureReleaseExclusionAudit.swift`; preserved CY typography tokens and `.accessibilityLabel` in `MerchantOpsWp03Panel.swift`. |
| `origin/ui/cur-uitests-3` | `d46d32054e` | `App/DesignFixtures/DesignFixtureRegistry.swift`, `App/DesignFixtures/DesignFixtureReleaseExclusionAudit.swift` | Kept both `CurFixtures3` and `Cur3Fixtures` entries and both exclusion-audit symbol lists. |
| `origin/ui/cur-l10n-qa` | `b56cf060de` | Branch ancestry included `origin/ui/h-design-v1` (Group B); `tools/current_ci_manifest.json` | Cherry-picked `b56cf060de` onto Group A (`181c0359e`, keeping `--ours` on `tools/current_ci_manifest.json`) so Group A stays independent of Group B; recorded full branch ancestry in Group B via `git merge -s ours origin/ui/cur-l10n-qa`. |
| `origin/ui/cur-mp-delta-3` | `2d6e8ff4b8` | None | Clean merge. |
| `origin/ui/cur-merchant-mode` | `353a9710b4` | None | Already merged into `origin/ui/main`. |
