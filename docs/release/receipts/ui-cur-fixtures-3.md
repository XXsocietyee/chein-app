# ui-cur-fixtures-3 — DEBUG fixtures, round 3

Base when this branch was cut: `origin/ui/main` `a2a9d82e78459df7c22c5545e2c5bf19f2f0ff46`.
Launch: `--design-fixture <name>`. Registry: `CurFixtures3.make` in `App/DesignFixtures/DesignFixtureRegistry.swift`.
Host used by the purchased reader context: `https://fixture.example`. Token: `synthetic-fixture-token`. A missing or unknown value is an em dash.

`moneyPayments`, `payout`, `merchantWrites`, and `passwordLogin` stay closed on `www.chengyinhub.com`. `ReviewedAreaSwitch` was not redeclared. A blank `AppSession` is the purchased-library session, so `paymentsOpen` stays false and the list is not requested. No fixture shows a successful charge, a redeem, or a payout as done.

`AppSession` and `AppCompositionRoot` gained no methods. `RegionalLaunchConfiguration.swift` was not edited. `docs/release/contract-failing-baseline.txt` was not raised. `docs/release/completeness-matrix.csv` was not imported. Feature implementations were not copied onto this branch.

`swiftc` is not on this machine (`swiftc` and `xcodebuild` are absent). No parse and no typecheck were run. This is not a green typecheck.

English and zh-Hans: each mounted screen has a `-zh` name that sets `Locale(identifier: "zh-Hans")`. The views' own catalogs supply the two languages. The fixture footer is the English label `DEBUG fixture · synthetic`.

## Fixtures added (view type already on the base)

| Screen | Normal | Non-happy |
|---|---|---|
| Purchased workshop `WorkshopPurchasedLibraryView` (`ui/cur-workshop-v2`) | `cur3-ws-purchased` (`cur3-ws-purchased-zh`). Closed copy. The list is not requested. | `cur3-ws-purchased-unavailable` (`-zh`). `WorkshopPurchasedAccountLink(browser: nil)` |
| Paid install entry `WorkshopPaidInstallEntry` | `cur3-ws-install` (`-zh`). Sample item decodes. `makeController` returns nil, so a tap records that install is not configured. No charge. | `cur3-ws-install-undecoded` (`-zh`). The sample is withheld and the screen is an em dash |
| Video bounty `VideoBountyView` (`ui/cur-wp-08` parent page) | `cur3-video-bounty` (`-zh`). One approved submission. Platform is nil. Accrual amount, views, and group views are nil, so the accruals tab renders em dashes and the payout-off note. No pay page. | `cur3-video-bounty-failed` (`-zh`). Submissions and accruals are a failed read |

The v2 purchased-license document is not on this base. The closed copy is the populated fixture for that paid screen.

## Waiting on the batch-7 merge

These view types are not in `a2a9d82e`. A fixture was not added, and the feature files were not copied here.

### `ui/cur-wp-03` `0b309ba6e895fca1304dfb85722d9b3578029805`

- `MerchantOpsWp03Panel` (decor, AI NPC review, team invite preview, coupon summary, chapter-invite revoke)

### `ui/cur-wp-04` `e83825c86ab600ba8aebc729e35e65efe7b795c8`

- `CoopInviteReceiptSections`
- `CoopInviteReadReceiptRow` (received-invite read receipt)
- `CreativeSquareAuthorDeleteSection`

### `ui/cur-wp-06` `c361789de116d144068c895f5d0a278c9b101c2b`

- `QuickPublishSimplePageStatus`

`WP06ComplaintWrite` is a write installer, not a view. `ProfileComplaintPreparationView` is already on the base and already has `e4-complaint` / `e4-complaint` error hosts.

### `ui/cur-wp-07` `4a0ba4fa6821a20ea219de6b2142085bde547beb`

- `GroupCheckoutPanel`
- `PassActivatePanel`
- `CouponUsabilitySection`

Quote, activate, and usability are payment-adjacent. When those types land, a populated paid screen uses the closed sentence, not a successful charge.

### `ui/cur-wp-08` `0242ef8d3d585d9a4955209642365cd7fb4fe601`

- `HostTipConfigScreen`
- `HostTipPlayerScreen` (prepare stays closed; `paymentSucceeded` stays false)
- `ChannelRedeemSheet`
- `ContentLandingScreen`
- `VideoBountyAttributionSheet` (private sheet on the bounty page)

`VideoBountyView` itself is on the base and is fixtured above. The attribution sheet is not.

### `ui/cur-wp-09` `6eeb3c7df1786e247f48217a4f3114fbffb988e0`

- `GameplayPresetSection`
- `SourceLineageSection`
- `TeamRoleAndSharedSection`
- `OrderDeliverySection`
- `OrderPaymentReturnSection`
- `OrderPartialRefundSection`
- `CreatorAccrualSection`

Order payment return, partial refund, and creator accrual are money screens. The closed copy is the fixture when the types land.

### `ui/cur-wp-10` `bcdb4d00e91f2867d51f6d2f6ce704235f9668c7`

- `ClubPayoutReceiverView`
- `ClubPayoutReceiverEntry`
- `MerchantPayoutAccountView`
- `MerchantPayoutAccountEntry`
- `OwnerDecisionFixtureHost`

### `ui/wp-0105` `051e5cde7974e8bf94ef42b24a8fdd75cd11a5eb`

Payout receivers and money writes. Same filenames as WP-10, different view types. All stay closed on `www.chengyinhub.com`. A populated payout screen uses `PayoutAreaClosedNote` / the closed sentence, not a successful bind or charge.

- `ClubPayoutReceiverView`
- `ClubSettlementMineView`
- `ClubPersonalSettlementView`
- `ClubPayoutReceiverLink`
- `ClubDirectLedgerSection`
- `PayoutAccountLinks`
- `MerchantPayoutAccountView`
- `PayoutReceiverIssueText`
- `PayoutAreaClosedNote`
- `RegistrationPaymentReadinessSection`

### `ui/cur-cl-01` `dc546dba157335e7a001950fe0d504be52fb2958`

No new view type. The completeness matrix on that branch was not imported.

### `ui/cur-workshop-v2` `fad4709993c284face1fe8cfdeeab6d349797458`

The library and install entry types are on the base and are fixtured above in the closed state. The v2 contract types in `Core/` are not on this base, so a decoded v2 license row is not shown.

## Checks

`python3 tools/generate_project.py` registered `App/DesignFixtures/CurFixtures3.swift`.
`python3 tools/check_design_fixture_release_exclusion.py` passed (source gate; Release was not compiled).
`python3 tools/check_scaffold.py` PASS.
`python3 tools/check_design_lint.py` PASS.
`swiftc` did not run.
