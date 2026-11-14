# ui-cur-uitests-3

Base: `ui/h-rm-02` at `eda3e9773f93767a8ca5ba52dfe66bc4c642347e`. This branch does not move `ui/h-rm-02`. `ui/cur-fixtures-8` was not merged. `ui/main` was not pushed.

All three screens are already on this branch. None was rebuilt or restyled.

| Test | Screen already on the branch | Fixture | What the test does |
|---|---|---|---|
| `Cur3OfflineUITests.testTeamPlaySharedHintSkipTimerExpiryAndTotalScore` | `TeamPoolHintSection` and `TeamPoolRunStatusSection` | one launch, `--design-fixture cur3-team-play` | Shared hint, then skip confirm, then timer expiry, then team total score `42`. Before a score exists the run total is an em dash (`—`). Hint and skip are answered in memory. The test does not tap a pay or create submit. |
| `Cur3OfflineUITests.testRegistrationPointsRefusalAsksForRequoteAndKeepsPayClosed` | `RegistrationSheetView` plus `RegistrationPaySection` | `--uitesting-registration-fixture pointsRefused` | Points are on, the quote deducts nothing, the viewer has 300 points, the sheet shows `registration.form.pointsRefusal` and quotes again. Refresh price stays on the in-memory quote. The pay block is `registration.pay.closed`. `registration.pay.submit` is absent. No StoreKit product id was added. Ticket ids stay 9401, 9402, and 9403. Ticket id 0 was not rewritten. |
| `Cur3OfflineUITests.testPayoutBindStaysClosedOnProductionAndCanOpenOnTestHost` | `ClubPayoutReceiverView` | `--design-fixture cur3-payout-closed`, then `cur3-payout-open` | Host `https://www.chengyinhub.com` shows `payoutReceiver.closed` and does not show bind. That launch does not call the transport. Host `https://8120.example.test` can show `payoutReceiver.bind`. The test does not tap bind on either launch, and the confirm control stays absent. |

`www.chengyinhub.com` stays closed. This receipt does not claim that host succeeded. `moneyPayments`, `payout`, `merchantWrites`, and `passwordLogin` were not opened for that host. `ReleaseMoneyWriteSwitch` was not installed. The open payout host is a DEBUG session whose area switch reads `8120.example.test`. Bind and unbind throw `APIError.notConfigured` inside `Cur3OfflineTransport` before any body is returned. The transport never uses `URLSession`. The open launch’s session read and unbound status are in-memory replies, not a bind.

`App/DesignFixtures/Cur3UITestFixtures.swift` is on the Release exclusion list. `RegistrationFixtureSupport.swift` was already DEBUG-only; the points case was added there so the existing sheet could launch offline.

Not edited: `RegionalLaunchConfiguration.swift`, `AppSession.swift`, `ReviewedAreaSwitch.swift`, `OwnerDecisionFixtureHost.swift`, `docs/release/contract-failing-baseline.txt`.

## Checks

- `python3 tools/generate_project.py`
- `python3 tools/check_design_fixture_release_exclusion.py` (source check only; Release was not compiled)
- `python3 tools/check_scaffold.py`
- `python3 tools/check_design_lint.py`

XCUITest was not run. This receipt does not claim a Swift compile. `swiftc` and `xcodebuild` were not run.
