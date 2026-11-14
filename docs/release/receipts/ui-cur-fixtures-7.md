# ui-cur-fixtures-7

DEBUG fixtures for the screens on `ui/h-offline` and `ui/h-sweep`. The diff against `origin/ui/main` (`3ac970ec20191014b4b9a8779a3a94b961e99c9c`) is those two merges plus this fixture file. It is not fixtures-only.

## Merged branches

| Branch | SHA |
|---|---|
| `ui/h-offline` | `46497191b6c87ed571e045f50737a68d588de571` |
| `ui/h-sweep` | `a17d8f27d885e046dccf321788173fa7817321a0` |

Merge `04a91a9ba7e59ff24be09362abd55e48f7430252` brings in offline banners and sync status. Parents: `3ac970ec20191014b4b9a8779a3a94b961e99c9c`, `46497191b6c87ed571e045f50737a68d588de571`.

Merge `b5e1322f1c883bcc942b303cdb7f998c0201988b` brings in the Challenge POI writer, my-project mutations, the merchant home chip, and the character sheet detail. Parents: `04a91a9ba7e59ff24be09362abd55e48f7430252`, `a17d8f27d885e046dccf321788173fa7817321a0`.

Conflicts kept both sides where both added a grant or a matrix note:

- `Core/AuthService.swift`: the request-reference ledger record stays, and `sendWithHeaders` still returns the response headers the read-retry transport needs.
- `App/ReviewedPlayerWriteLeases.swift`: the audit-timeline paths and the my-project mutation paths both stay. `PayoutReceiverRouteGrant` and `acceptsMyProjectMutation` both stay. `ReviewedAreaSwitch` is not redeclared.
- `docs/release/completeness-matrix.csv`: current `ui/main` rows stay. The four `PKG-63-*` rows from `ui/h-offline` are appended. The my-project row keeps the `ui/wp-02` DONE evidence and the `ui/h-sweep` mutation note.

`App/RegionalLaunchConfiguration.swift` changes only as part of the `ui/h-offline` merge. This fixture work does not edit it. No methods were added to `App/AppSession.swift` or `App/AppCompositionRoot.swift`. `docs/release/contract-failing-baseline.txt` was not raised.

## Fixtures

`App/DesignFixtures/Cur7Fixtures.swift` is wrapped in `#if DEBUG`. Launch with `--design-fixture <id>`. `DesignFixtureRegistry.make` hands `cur7-*` to `Cur7Fixtures.make`. Account `990001` and token `synthetic-fixture-token` match the G-parity fixtures. The character read uses `https://fixture.example/native/`. Unknown is an em dash (`—`). A decoded 0 stays 0: sync failures start at 0, character Strength is 0, momentum is 0/5, and merchant revenue `"0"` is `¥0.00`. No new copy was added.

Money stays behind the existing `ReviewedAreaSwitch`. Nothing in these fixtures sends to `www.chengyinhub.com`.

| Surface | Fixture ids | Normal | Non-happy |
|---|---|---|---|
| Offline banners | `cur7-offline-banner`, `cur7-offline-banner-still` | `CYStatusOfflineBanner` and `SearchMapOfflineBannerView` with a cached time and retry | same banners, `stillOffline` and serious tone |
| Sync status | `cur7-sync-status`, `cur7-sync-status-offline` | `RoamSyncStatusTracker` online, failure count `0` | two transport failures, count `2`, `roam.sync.offline` banner |
| Challenge POI writer | `cur7-poi-writer`, `cur7-poi-writer-blocked` | `ChallengePOIHostView` on node 闸口 with a non-gated writer, so the unavailable banner is hidden | factory left on `GatedChallengePOIWriter`, unavailable banner shown |
| My-project mutations | `cur7-myproject-mutation`, `cur7-myproject-mutation-failed` | topic toggle (expected user status 0) reaches Done | same toggle, empty failure becomes the existing failure sentence |
| Merchant home chip | `cur7-merchant-chip`, `cur7-merchant-chip-unknown` | `MerchantHomeView` business-status chip Open, revenue `¥0.00` | operations read fails, chip absent, fixture draws `—`; revenue null is `—` |
| Character sheet detail | `cur7-character-sheet`, `cur7-character-sheet-unknown` | `CharacterCardReadbackView` → `CharacterSheetDetailView`, Strength `0` | malformed character payload, unknown phase, em dash |

Each fixture screen sets an accessibility label. The offline, search-map, sync-count, merchant-unknown, and character-unknown labels are on the fixture. The production banners and the character unknown state keep the labels they already had.

The POI fixture sets `ChallengePOIWriterFactory.makeWriter` for that screen only. It does not open a route on the production host.

## Gates

- `python3 tools/generate_project.py` registers `Cur7Fixtures.swift` and keeps design-fixture sources on the Release exclusion list.
- `python3 tools/check_design_fixture_release_exclusion.py --write`, then the check without `--write`.
- `python3 tools/check_scaffold.py` and `python3 tools/check_design_lint.py` passed before push.
- `swiftc` is absent. This receipt does not claim a typecheck or an XCTest run.
