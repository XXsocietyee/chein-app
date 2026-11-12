# Cloud X4 — Integrated and NonCash UITests

Base: `ui/main` `72d2eb9ec498de21ded7cf9215f2638d7195786f`.
Branch: `ui/cloud-x4-uitests` only. `main`, `rc`, and `ui/main` were not pushed.

## Result

**NOT_RUN.** This agent is Linux. There is no Xcode, no iOS Simulator, and no self-hosted Mac worker. `xcodebuild` was not run. Nothing was compiled. No UITest pass or failure was observed, so this receipt does not claim that IntegratedDenied, IntegratedActivityPlay, IntegratedNativeAcceptance, or NonCashReward passed.

`docs/release/receipts/uitest-14.md` rounds 1–3 were code-only and were never simulator-verified. The edits below follow those notes plus the current SwiftUI (Passport title, Roam overflow menu, Favorites closed gate, Settings sign-out sheet, ticket-wallet preload).

`python3 tools/check_scaffold.py` exited 0 after this receipt was added. The script does not compile Swift or run XCUITest.

## What changed

- Roam list/area actions live in `roam.more`, not an "Official city" bar button. The three integrated suites open that menu and still require exactly one "Show list only" and exactly one "Choose a search area".
- Ready and denied ledgers now require the two ticket-wallet preloads (`wallet-list` owner_type `1` and `2`) in addition to the six home routes. Passport `userInfo` repeats are not treated as home reads. Owned-order fields stay exact: `owner_type` `3`, detail `id` `41`.
- Favorites with no grant shows "Favorites can't be shown right now." and hides the Posts/Topics control. The test still requires no retry, no `profile.favoriteRemoval.*`, and none of the forbidden favorite paths in the ledger. The root bar title is Passport.
- Sign out is `settings.signOut` on Settings. The sheet must show "Sign out of this account?" and an enabled `settings.signOut.confirm` labeled "Sign out". Logout route, nil account, token not stored, and epoch increase stay.
- `rewards.open` is the Passport collection row. The opt-out test still requires identifier `rewards.unavailable` and no example row or `rewards.present`.
- Reward fact labels are the localized name plus ", " plus the value, so the disclosure test still requires "Context identifier, example-map", "Season identifier, example-season", and "Eligibility" / "Claim progress" / "Allocation method" plus ", Not available". "Claim reward" must still be absent.
- `profile.order.lifecycle` is shown only when the coordinator `canDispatch` or `canSimulate`. The `XCTAssertFalse` that the button exists on the read-only order stays in all four suites and in `OwnedOrderFlowTests`.

## Assertions that were not weakened

Money and sign-out checks left in place:

- `XCTAssertEqual(owned.first?.fields, ["owner_type": "3"])`
- `XCTAssertEqual(owned.last?.fields, ["id": "41"])`
- `XCTAssertFalse(app.buttons["profile.order.lifecycle"].exists)`
- `XCTAssertFalse(rest.contains { ... $0.route.hasPrefix("orders.") })` on the denied journey
- SMS and phone field assertions, including nil tokens on `sms-send` and `phone`, and exactly one `sms-send`
- `XCTAssertEqual(confirm.label, "Sign out")` plus `logout` as the last ledger route, nil `accountID`, `tokenStored == false`, and a greater epoch
- Reward disclosure strings and `XCTAssertFalse(app.buttons["Claim reward"].exists)`
- `XCTAssertTrue(value.violations.isEmpty, value.violations.joined(separator: ", "))` inside `evidence` and `wait`

No test was deleted, skipped, or given `XCTSkip`.

## Unverified failure (exact assertion)

Because the suites were not executed, the remaining failure is the unobserved run itself. The first assertion a Test-lane re-run will hit if an unexpected request still reaches `IntegratedNativeAcceptanceFixture` is:

```swift
XCTAssertTrue(value.violations.isEmpty, value.violations.joined(separator: ", "))
```

in `evidence` / `wait` of `IntegratedDeniedAcceptanceFlowTests`, `IntegratedActivityPlayJourneyFlowTests`, and `IntegratedNativeAcceptanceFlowTests`. The failure message is the fixture violation text, for example `unreviewed endpoint: <path>` or `exact form: <path>`. That string was not observed here.

If the home and wallet reads settle but the activity detail is not requested a second time when Explore is reselected, the next exact assertion is in `IntegratedActivityPlayJourneyFlowTests.testActualPhoneHomeDetailManualMapPlayAndFreshOwnedOrderJourney`:

```swift
XCTAssertEqual(self.journeyRoutes(final), ["activity-detail", "map.places", "activity-detail", "play-nodes", "play-route", "orders.list", "orders.detail"])
```

That equality was not observed.
