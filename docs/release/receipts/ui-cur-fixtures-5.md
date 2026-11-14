# ui-cur-fixtures-5 — DEBUG fixtures

Base when this branch was cut: `origin/ui/main` `3e2dca3ec5d5c732ea7d286cbb0fe856944ffce6`. That tip had not moved. Launch: `--design-fixture <id>`. Registry: `CurFixtures5.make` in `App/DesignFixtures/DesignFixtureRegistry.swift`. `CurFixtures2` is not on this tip (reverted at `9209d33cb`). `CurFixtures3` and `CurFixtures4` are not on this tip. This file follows the registry that is here.

Host used by the purchased reader and the WP-03 transport: `https://fixture.example`. Token: `synthetic-fixture-token`. A missing or unknown value is an em dash (`U+2014`). A decoded `0` stays `0`. Each id also has a `-zh` name that sets `Locale(identifier: "zh-Hans")`. The screens' own catalogs supply English and zh-Hans. The fixture footer is `DEBUG fixture · synthetic` or `调试夹具 · 合成数据`.

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
| Handover 35 `ui/cur-wp-06` | `QuickPublishSimplePageStatus` | Not on this tip |
| Handover 38 `ui/cur-wp-09` | `GameplayPresetSection`, `SourceLineageSection`, `TeamRoleAndSharedSection`, `OrderDeliverySection`, `OrderPaymentReturnSection`, `OrderPartialRefundSection`, `CreatorAccrualSection` | Not on this tip |
| Handover 39 `ui/cur-wp-10` | `ClubPayoutReceiverView`, `MerchantPayoutAccountView`, `OwnerDecisionFixtureHost` | Not on this tip |
| This tip | `VideoBountyAttributionSheet` | Private. The parent `VideoBountyView` is fixtured and the seeded fact is UNKNOWN |
| This tip | `CoopInviteReadReceiptRow` | Private. `CoopInviteReceiptSections` is the public host and is fixtured |

## Checks

`python3 tools/generate_project.py` registered `App/DesignFixtures/CurFixtures5.swift`.
`python3 tools/check_design_fixture_release_exclusion.py --write`, then the check without `--write`, passed. Source gate only. Release was not compiled.
`python3 tools/check_scaffold.py` PASS.
`python3 tools/check_design_lint.py` PASS.
`swiftc` did not run.

## 中文

基线是 `origin/ui/main` `3e2dca3e`。只给已经能在这个基线上编译的页面加了 DEBUG 夹具：已购工坊 v2、WP-07 的报价/激活/券可用性、WP-08 的主持小费、渠道兑换、落地页和视频赏金，以及已经在这个基线上的 WP-03 装修面板、合作邀请回执、广场作者删除。未知值是破折号，解码出来的 0 仍是 0。付钱、打款和商家写入在 `www.chengyinhub.com` 上保持关闭。

推送落地、无埋点屏幕、未知值改破折号、深链落地，以及名单里的其他功能分支都没有合进 `ui/main`。那些类型没有抄过来，上表写了跳过原因。本机没有 `swiftc`，没有编译，也没有跑测试，没有 curl。
