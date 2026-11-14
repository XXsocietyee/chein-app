# ui-cur-fixtures-5 — DEBUG fixtures

Cut from `origin/ui/main` `3e2dca3ec5d5c732ea7d286cbb0fe856944ffce6`, then rebased onto `origin/ui/main` `6feee423adc8962d7613f8ba93b77ffdc93ea1c4`. That tip adds WP-06, WP-09, and WP-10, and this commit fixtures those screens. Launch: `--design-fixture <id>`. Registry: `CurFixtures5.make` in `App/DesignFixtures/DesignFixtureRegistry.swift`. `CurFixtures2` is not on this tip (reverted at `9209d33cb`). `CurFixtures3` and `CurFixtures4` are not on this tip. This file follows the registry that is here.

Host used by the purchased reader and the WP-03 transport: `https://fixture.example`. Token: `synthetic-fixture-token`. A missing or unknown value is an em dash (`U+2014`). A decoded `0` stays `0`. Each id also has a `-zh` name that sets `Locale(identifier: "zh-Hans")` and `W8Text.languageOverride` to `zh-Hans` (the English id sets it to `en`). The screens' own catalogs and `W8Text` supply English and zh-Hans. The fixture footer is `DEBUG fixture · synthetic` or `调试夹具 · 合成数据`.

`moneyPayments`, `payout`, `merchantWrites`, and `passwordLogin` stay closed on `www.chengyinhub.com`. `ReviewedAreaSwitch` was not redeclared. The WP-03 closed fixture passes that host string into the existing switch and a transport that throws, so money and merchant writes stay withheld and a read does not succeed. The purchased list sits on a blank `AppSession`, so purchase reads stay off and the list is not requested. No fixture shows a charge, a redeem, or a payout as done.

`AppSession` and `AppCompositionRoot` gained no methods. `RegionalLaunchConfiguration.swift` was not edited. `docs/release/contract-failing-baseline.txt` was not raised. Feature branches were not merged and their types were not copied.

`swiftc` is not on this machine. No parse and no typecheck were run. This is not a green typecheck. No curl was run.

## Fixtures added (view type already on this base)

| Screen | Normal | Non-happy |
|---|---|---|
| Purchased workshop `WorkshopPurchasedLibraryView` | `cur5-ws-purchased`. Closed copy. The list is not requested. | `cur5-ws-purchased-unavailable`. `WorkshopPurchasedAccountLink(browser: nil)` |
| Paid install `WorkshopPaidInstallEntry` | `cur5-ws-install`. The v2 sample item decodes. `makeController` returns nil, so a tap records that install is not configured. No charge. | `cur5-ws-install-undecoded`. The sample is withheld and the screen is an em dash |
| Group quote `GroupCheckoutPanel` | `cur5-wp07-group`. Kind 5, name set, tier and total nil, so those two lines are an em dash. Create stays on the closed sentence. `cur5-wp07-group-zero` keeps total text `0`. | `cur5-wp07-group-empty`. `cur5-wp07-group-failed` (retry) |
| Activation `PassActivatePanel` | `cur5-wp07-activate`. Topic `topic-7`. Activate stays closed. | `cur5-wp07-activate-empty`. Missing topic |
| Coupon usability `CouponUsabilitySection` | `cur5-wp07-coupon`. A nil name and a reason outside the known set are an em dash. A known `AVAILABLE` row stays named. The deduction line stays `0`. | `cur5-wp07-coupon-empty`. `cur5-wp07-coupon-failed` (retry) |
| Host tip config `HostTipConfigScreen` | — | `cur5-host-config`. Blank session. Signed out. No save and no payment success |
| Host tip intents `HostTipPlayerScreen` | — | `cur5-host-player`. Blank session. Signed out. Prepare is not a payment success |
| Channel redeem `ChannelRedeemSheet` | — | `cur5-channel`. Idle. The provider-off note stays. No redeemed receipt |
| Landing editor `ContentLandingScreen` | — | `cur5-landing`. `session` nil. Resting phase is empty. Sitemap, hreflang, and robots stay the screen's own not-live note |
| Video bounty `VideoBountyView` | `cur5-video-bounty`. One approved submission, platform nil. Accrual amount nil is an em dash. Views is the decoded `0`. Group views nil is an em dash. Seeded attribution is `VideoBountyAttributionFact.unknown` (status UNKNOWN, counts an em dash). The attribution sheet is private and opens from the attribution button. No pay page. | `cur5-video-bounty-failed`. Submissions, accruals, and attribution are a failed read |
| Store decoration `MerchantOpsWp03Panel` `.decor` | — | `cur5-wp03-decor-signedout` (no bridge). `cur5-wp03-decor-closed` (production host string, throwing transport: money and writes withheld, a read fails as an em dash) |
| Invite receipts `CoopInviteReceiptSections` | `cur5-coop-receipt-unknown`. One row whose state and request id are null, drawn as an em dash. | `cur5-coop-receipt-signedout`. `cur5-coop-receipt-failed` (retry, do not send again) |
| Author square delete `CreativeSquareAuthorDeleteSection` | `cur5-square-delete`. Post `7`. Delete is not confirmed by this fixture. | `cur5-square-delete-empty`. `cur5-square-delete-failed` (retry). `cur5-square-delete-signedout` |
| Quick publish `QuickPublishSimplePageStatus` | `cur5-quick-zero`. Themes and AI remaining are the decoded `0`. | `cur5-quick-empty` (blank draft, quota an em dash). `cur5-quick-unknown` (missing themes, remaining `UNKNOWN` is an em dash). `cur5-quick-failed` |
| Gameplay presets `GameplayPresetSection` | — | `cur5-preset`. No client. The list cannot be read. Draft stays off |
| Source version `SourceLineageSection` | `cur5-lineage`. Revision `rev-7`. Diff and save-as-new stay an em dash | `cur5-lineage-unknown`. No revision. History still needs checking. Continue, diff, and save-as-new are an em dash |
| Team role `TeamRoleAndSharedSection` | `cur5-team-role`. Session participants is the decoded `0`. Missing role lines are an em dash | `cur5-team-role-unknown`. Role and shared facts are nil |
| Delivery `OrderDeliverySection` | `cur5-delivery-zero`. Ticket name set. Server amount is the decoded `0` | `cur5-delivery-unknown` |
| Payment return `OrderPaymentReturnSection` | `cur5-pay-return-zero`. Payment status `0` stays pending confirmation. It does not unlock the purchase. Empty channels are an em dash | `cur5-pay-return-unknown`. Payment and registration are nil. The phase title is an em dash |
| Partial refund `OrderPartialRefundSection` | `cur5-refund-zero`. Pending amount is the decoded `0`. The other amounts are an em dash. The total stays incomplete | — |
| Creator accrual `CreatorAccrualSection` | — | `cur5-accrual-unknown`. Earnings unavailable. The reason is an em dash. No amount, including no zero. The public factory is `unknown`; an available projection is not constructed from this module |
| Club receiver `ClubPayoutReceiverView` | `cur5-receiver`. Verified, payout off, unbind not offered. Binding stays in the mini-program | `cur5-receiver-empty`. `cur5-receiver-error` |
| Merchant payout account `MerchantPayoutAccountView` | `cur5-merchant-account`. Needs a signature. The signing link is `https://fixture.example/sign`. The masked account is an em dash. No cash-out | `cur5-merchant-account-empty` (`NONE`). `cur5-merchant-account-denied`. `cur5-merchant-account-unavailable` (available false shows the unavailable sentence) |

## Skipped — type is not on `origin/ui/main`

These branches were not merged. Their types were not copied.

| Source | Screen or type | Reason |
|---|---|---|
| Handover 41 `ui/cur-appstore` | none | App Store notes, privacy manifest, and a StoreKit file. No new view |
| `ui/cur-wp11-followups` (on `ui/wp-11`) | `SessionLocationHoldsSection`, `RequestReferenceRow`, `SessionBackgroundLocationTracker` | Not on this tip |
| Handover 47 `ui/cur-fixtures-4` (merged `ui/wp-02` and `ui/wp-11` on that branch only) | `CreatorAuditSheet`, `PlayGuardAppealSection`, `PlayLeadChapterTools`, `ClubEditionEmptyReasonView` | Not on this tip. That branch was not merged |
| `ui/cur-visual-parity`, handover 49 `ui/cur-visual-parity-2` | none | Copy and layout edits on screens that already exist. Those edits are not on this tip, and there is no new view type |
| Handover 50 `ui/cur-copy` | none | Catalog strings only. Not copied |
| Handover 51 `ui/cur-states` | `OfficialEventDetailView`, `PlayKitTimedChallengeView`, `NearbyTeamViews`, `PlayExperienceView`, `PlayerJourneyViews`, `RoamPassportToolsViews`, `RoamPassportPrivateToolsViews`, `SquareReportProgressView`, `MemberReportProgressDetailView`, `SocialPublicProfileView` | The view types exist. The em-dash and retry edits from that branch are not in those files on this tip, so they were not copied and were not given a new fixture |
| Handover 52 `ui/cur-deeplinks-2` | `MPReviewedPageScreen` | Not on this tip. The older `ia-deeplinks` registry entry is unchanged |
| Handover 53 `ui/cur-push` | `SubscribeMessageTapEntry`, `SubscribeMessageProjectsEntry` | Not on this tip. Order, cooperation, project, and ledger destinations already exist; the tap router that opens them does not |
| `ui/cur-analytics` | `MiniProgramAnalytics` | Not a screen and not on this tip. No `track` call site from that branch was copied, so the screens on this tip stay analytics-free |
| `ui/cur-appearance` | none | Token and Dynamic Type edits. No new view type. Not copied. `MerchantOpsWp03Panel` itself is already on this tip and is fixtured above |
| Handover 56 `ui/cur-perf` | `PlayerFeedImage`, `PlayerFeedJSON` | Not on this tip |
| `ui/cur-uitests` | `WorkflowJourneyGoldenPathUITests` | A test, not a screen. Not on this tip |
| This tip | `VideoBountyAttributionSheet` | Private. The parent `VideoBountyView` is fixtured and the seeded fact is UNKNOWN |
| This tip | `CoopInviteReadReceiptRow` | Private. `CoopInviteReceiptSections` is the public host and is fixtured |

## Checks

`python3 tools/generate_project.py` registered `App/DesignFixtures/CurFixtures5.swift`.
`python3 tools/check_design_fixture_release_exclusion.py --write`, then the check without `--write`, passed. Source gate only. Release was not compiled.
`python3 tools/check_scaffold.py` PASS.
`python3 tools/check_design_lint.py` PASS.
`swiftc` did not run.

## 中文

分支先从 `3e2dca3e` 切开，再变基到 `6feee423a`。夹具覆盖已购工坊 v2、WP-07、WP-08、WP-03 装修、邀请回执、广场删除，以及这个基线上的 WP-06 快捷发布、WP-09 预设与售后、WP-10 收款账户。未知值是破折号，解码出来的 0 仍是 0。付钱、打款和商家写入在 `www.chengyinhub.com` 上保持关闭。收款账户没有提现按钮。

推送落地、无埋点屏幕、未知值改破折号、深链落地，以及名单里的其他功能分支都没有合进 `ui/main`。那些类型没有抄过来，上表写了跳过原因。本机没有 `swiftc`，没有编译，也没有跑测试，没有 curl。
