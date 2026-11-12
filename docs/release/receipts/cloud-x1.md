# X1 port-time bugs

Branch: `ui/cloud-x1-audit-bugs`
Base: `origin/ui/next` `b87ab5aad675eda15e5dc2cc25e10f4debadfdce`
Money: OFF. No payment, payout, or IAP write was enabled. Unknown-payment and disabled-CTA copy says this device will not collect payment or mark an order paid. A missing payment code inside that explanation is an em dash (U+2014). Copy is English and zh-Hans.

`python3 tools/check_design_lint.py` exit 0. `python3 tools/check_scaffold.py` still fails the pre-existing AppSession (8206 > 8181) and AppCompositionRoot (4784 > 4498) line ratchet. This commit does not add lines to either file, and the player-write paths stay in `AppCompositionRoot.swift`. Swift was not compiled on this machine; no `swift`/`xcodebuild` result is claimed.

One test per item in `Tests/CoreTests/CloudX1AuditBugTests.swift`.

| # | Corrected behavior | Lock |
|---|---|---|
| 1 | `SUBMIT_REACTION` / `SUBMIT_BALL_SHAKE` / `SUBMIT_QUIET_HOLD` are rejected until `START_CHALLENGE` for that session and kind has succeeded, or the segment already says `started`. | `testReactionBallShakeAndQuietHoldRequireStartBeforeSubmit` |
| 2 | An unrecognized payment code, or both statuses absent, explains itself on order detail, order history, and topic self-play. Known codes 0–4 keep their existing observation. | `testUnknownPaymentStateExplainsItself` |
| 3 | A topic self-play order encodes `sourceClubId` when the topic has a positive club id. Money fields stay `isUsePoint` 0 and `payChannel` APP. | `testTopicOrderCarriesSourceClubId` |
| 4 | Null remaining inventory is unknown. A literal zero is sold out. | `testNullRemainingInventoryIsUnknownNotSoldOut` |
| 5 | The registration form re-checks `signupDeadline` for timed sessions, not only self-guided tickets. `MoneyTicketWindow` is unchanged. | `testRegistrationFormRechecksSignupDeadline` |
| 6 | The club role picker writes the chosen member and role into the draft. The form no longer clears the seeded role code. | `testClubRolePickerUpdatesTheDraft` |
| 7 | Silent-order give-up stops the local clock and marks the page dirty. The action catalog stays empty. | `testSilentOrderGiveUpActsWithoutACompletionAction` |
| 8 | A mode-2 shop visit is complete only when `node.done` is true (merchant redemption). Scan, photo, self-report, and route `COMPLETED` do not complete it. Arrival proof settlement is unchanged. | `testMode2ShopVisitCompletesOnlyFromMerchantRedemption` |
| 9 | A failed advanced-leaderboard fetch is an error state. A ready board with zero rows stays empty. Player-leaderboard failure stays hidden. | `testLeaderboardFetchFailureIsAnErrorNotEmpty` |
| 10 | Closing the advanced panel clears the playkit review sheet. It does not dismiss the playkit screen. | `testClosingTheAdvancedPanelClosesThePlayKitSheet` |
| 11 | The advanced continue button is tappable while disabled and shows why. | `testDisabledCallToActionExplainsWhy` |
| 12 | `api/topic/v2/create` accepts a scalar `data` topic id. An object bundle acknowledgment is still a bundle. `ProjectEditBundleAcknowledgment.decode` still rejects a bare number. | `testCreateResponseDataIsAScalarTopicId` |
| 13 | Restoring a publishing draft opens the saved wizard step, including when earlier steps are incomplete. | `testResumeDraftAtTheSavedStep` |
| 14 | A `citynode_` code scanned at ticket/activity redemption says to redeem it at the city-node entry. Other unknown v1 codes stay unsupported. | `testCityNodeCodeFromTheWrongPlaceSaysWhereToRedeem` |
| 15 | Missing or non-positive countdown TTL is 300 seconds. A positive TTL is unchanged. | `testCountdownFallbackTTLIs300Seconds` |
