# WP-11 follow-ups: no client point rate, server-timed countdown

Branch `ui/cur-wp11-followups`. Parent `1e48434aaa7ec692265f73e343394ff799440be8` (`ui/wp-11`).

`swiftc` is not on this machine. No typecheck, no `swift test`, no simulator. Gates that did run: `python3 tools/check_scaffold.py` and `python3 tools/check_design_lint.py`, plus the Python contract checks named below.

## Removed

The client parameter `pointDeductRate` is gone from `App/` and `Core/`.

- `RegistrationCoreLoopRules.computeOrderPrice` no longer takes a rate, a points balance, or a points cap. It still totals the order, member discount, and coupon. `pointsDeductYuan` and `pointsUsed` on that result stay `0`. The signup screen keeps using `RegistrationQuote.pointsDeductYuan` and `pointsUsed`.
- `MoneyPricingAdapter.compute` no longer accepts a caller-supplied yuan-per-point rate. Order detail still shows the server snapshot `pointUsed` and `pointDeductAmount` (`App/ProfileOrdersView.swift`). It does not reprice them.

`MoneyPricing.defaultRateMicroYuan` (`20_000`, the port of `CmsConstants.POINT_DEDUCT_RATE`) stays inside `MoneyPricing.compute` for the fen-exact formula tests. Signup does not call it, and nothing in `App/` passes a rate into it.

No new strings. Existing en and zh-Hans catalogs are unchanged. The unknown countdown is the em dash `—` (U+2014), the same mark both languages already use for an unknown value.

## What times the countdown

| Surface | Clock |
|---|---|
| Opening-window countdown (`App/NativeMotionReminderViews.swift`) | `NativeTimeWindow.countdownSeconds`, which is `nextOpenAt − serverNow` from `GET api/play/advanced/time-window`. The phone clock is not subtracted. Returning to the foreground still calls `refresh()`, which replaces that pair. A failed read (`readIssue != nil`, no window) shows `—` and does not tick. |
| Play-kit session remaining (`App/PlayKitScreen.swift`, `App/PlayAdvancedView.swift`) | `PlayAdvancedState` has `deadlineAt` and no `serverNow`. `remainingSeconds` returns nil. The row shows `—` and does not tick. |
| Play-kit countdown challenge (`App/PlayKitTimedChallengeView.swift`, kind `.countdown`) | The segment fields in this tree are `seconds` and `submitted`. `seconds` is a duration, not a server instant. The clock shows `—`. The device uptime is not used to finish `SUBMIT_COUNTDOWN`. |
| Team turn expiry chip | Same missing server clock. It does not flip to expired from `Date()`. |

## Left alone

- `ReviewedAreaSwitch`, `RegionalLaunchConfiguration.swift`, `AppSession`, and `AppCompositionRoot` were not edited.
- No new route. Production money on `www.chengyinhub.com` stays closed.
- No new Swift file, so `tools/generate_project.py` was not required to register one.

## Tests

- `Tests/ContractChecks/test_wp11_session_location.py`: `test_own_d01c_app_and_core_have_no_client_point_deduct_rate`, `test_own_opt042b_countdown_does_not_tick_from_the_device_clock`.
- `WP11SessionLocationTests.testOwnD01cClientPriceDoesNotApplyAPointRate`, `testOwnOPT042bCountdownUsesServerClockOrAnEmDash` (written, not executed).
- `NativePlatformContractTests.testServerWindowRequiresZoneFutureInstantAndLocalProvider` now also expects `countdownSeconds` of 3600 and 90 (written, not executed).
