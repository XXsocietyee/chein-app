# Receipt: cursor/r8-member

Owner: Cursor Core, area member. Base is `origin/ui/combined-r7` at `f5f3006d781ac4d61c225a079ef74e2e2a86befd` (`Integrate Cursor round 5`). This branch was not rebased.

This VM did not run `swiftc` or `xcodebuild`. Nothing here was parsed or compiled. Python contract checks that this change edits were run. Swift tests were written and were not executed.

`AppSession.swift`, `AppCompositionRoot.swift`, `project.pbxproj`, and `tools/current_ci_manifest.json` were not edited. `broadcastRecoverPath` and `ClubCommunityService` were not touched. No new Swift file, so the project file stays as it is.

Money stays off. `PlatformPass.moneyEnabled` is still false. Pay, gift claim, payout, withdrawal, and paid orders send nothing. Cancel, confirm, and refund-apply send only when a TEST derivation for that kind is on. The default derivation is nil, so they send nothing. Release has no derivation.

## Rows taken

P0 Cursor Core: none.

| id | what changed |
|---|---|
| R8-MEM-1-1 | `ChannelRedeemSource.status` GETs `/api/channel/redeem/status`. The flag is true only for JSON `true`. The path is on `hostTipSurfaceGrant`. |
| R8-MEM-3-1 | Gift links allow `mode` as well as `token`. `redeemPlatformCode` POSTs `/api/channel/redeem` with `{code, requestId}` and `requestId` `code_<millis>_<8 chars>`. Host-tip redeem still uses the `cred-` prefix. This path was already a non-money grant. Pay is not involved. |
| MKT-5-3 | `PlatformPass.orderWriteTestDerivation` defaults off. `sendCancelPassOrder`, `sendConfirmPassOrder`, and `sendRefundApplyPassOrder` throw `unreachable` and send nothing until the matching kind is on. China production admits cancel, confirm, and refund-apply only then. Pay stays refused. The old synchronous methods still throw and send nothing. |
| FIN-17-4 | `ProfileOrder` decodes `teamMode`, `teamOpen`, `seatsOpen`, `club`, and `merchantOwnerMemberID` (`cmsTopic.memberId`, else `cmsActivity.memberId`). `ProfileOrderConsentOffer.pick` matches one unpaid consent row. Follow stays `POST /api/user/follow/action`. |
| R8-MEM-21-1 | `WalletSeatInvitationSource.load` POSTs `/api/play/seat-invitations/claim-phone` with `{}`, then GETs `/api/play/seat-invitations/mine`. A failed claim still reads mine. A failed mine returns `[]` and does not throw. Both paths are on `playerJourneyOwnerGrant`. |
| R7-MEM-21-1 | A ticket code reissues silently when 30 seconds or less remain. Failure keeps the old code and does not enter `.loading`. City vouchers still reissue only at expiry. |
| PLY-21-4 | `TicketWalletTicket.activityHasGame` / `hasGame`. A missing activity object has a game. An activity ticket has a game only when `topicId` or `templateId` is positive. |
| PLY-21-6 | Removed the contract pin that required the wallet-wide `TeamHomeView` section. The per-ticket team section pin stays. The App section was not deleted. |
| PLY-26-2 | Retired the shelf search pins in `test_owned_template_pagination.py` and the four keyword UI tests. Core paging is unchanged. The page itself is not retired (`R8-MEM-26-1` is still an owner decision). |
| R7-MEM-2-1 | `subpackageMember/market/pass/index` no longer requires `id`. |
| R7-MEM-5-1 | `subpackageMember/market/pass-order/index` no longer requires `orderNo`. |
| R7-MEM-7-1 | `store.available` decodes, missing means false. `unitsPerHolder == 0` no longer rejects the catalog. |
| R8-MEM-7-3 | `FreeExploreLaunchFailure.response` carries server `msg`. Catalog, order, and receipt failures from `FreeExploreLaunchService` pass it through. |
| R8-MEM-10-1 | `subpackageMember/coupon/coupon` allows `scope`. The value is not a closed set. |
| R7-MEM-12-1 | `subpackageMember/invoice-detail/index` no longer requires `id`. A non-canonical `id` still rejects. |
| FIN-16-7 | `ProfileOrder.coverURL`: activity `imgUrl` then `imgArr[0]`; topic `imgArr[0]` then `imgUrl`. |
| R7-MEM-17-2 | `ProfileOrder.settlementView` follows `order-settlement-view.js` (stage text, zero omitted, null is `金额待确认` when amounts are incomplete). Amount text uses `MoneyDisplay`. This does not send a refund. |
| FIN-17-8 | `ProfileOrder.party.text` and `walletExpired` (`usableState == "EXPIRED"`). |
| PLY-21-14 | Wallet list POSTs `owner_type`, `pageNum`, and `pageSize` 10, and follows pages while `rows.length >= 10`, `page < 10`, and `total` names another page. A bare array is one page. |
| PLY-23-6 | `ParticipationDetail.templateBannerURL` is the first image of `topicImgArr`, else `cmsTopic.imgArr`. |
| PLY-25-5 | `OrientSessionScore.disputeWindowDeadline` and `canDispute` (status 1 or 2, a deadline, no dispute still in status 0). `OrientScoreSummary` carries both. |

## Not taken

- MKT-3-1 gift claim is money. `PlatformPass.claim` still throws and sends nothing.
- PLY-25-2 sync / settle / recovery stays off. The audit says there is no ruling, and `settleEnabled` / `syncEnabled` stay false.
- FIN-19-1 is a withdrawal read. Withdrawal stays off and sends nothing.
- Owner-decision rows whose fix is product copy, a sheet, or retiring a page (MKT-4-1, MKT-4-6, MKT-8-2, MKT-9-2, MKT-10-2, MKT-10-3, R7-MEM-16-1, FIN-20-6, R8-MEM-26-1, PLY-21-8, R7-MEM-24-2) were not turned into writes.
- Claude App rows were not implemented.

## App call sites left for Claude

These screens were not given the new behavior. Six files only gained a wildcard or `message: nil` on `FreeExploreLaunchFailure.response` so the new associated value still type-checks. They do not show `message`.

| file | call |
|---|---|
| `App/PassMarketViews.swift` | Show the 兑换码 row when `ChannelRedeemSource.status` is true, and open gift with `mode=code`. `refuse()` still calls the throwing `cancelPassOrder` / `confirmPassOrder` / `refundApplyPassOrder`. To exercise MKT-5-3, call `sendCancelPassOrder` / `sendConfirmPassOrder` / `sendRefundApplyPassOrder` only when the TEST derivation for that kind is on. Default still sends nothing. |
| `App/MPParityKit.swift` | Gift route still reads `token` only. Build `mode=code` (title 兑换码, input max 64, `redeemPlatformCode`, the six result texts, 去玩). |
| `App/ProfileOrdersView.swift` | Fill the team / seats / club / consent sections from `teamOpen`, `seatsOpen`, `club`, `merchantOwnerMemberID`, and `ProfileOrderConsentOffer.pick` after the existing marketing-consent GET. Follow is `POST /api/user/follow/action`. Show `coverURL`. Show `settlementView` (hide when `show` is false). |
| `App/ProfileOrderSourceDetailSections.swift` | Show `party.text` and the expired wallet state from `walletExpired`. |
| `App/TicketWalletView.swift` | On wallet load, call `WalletSeatInvitationSource.load` and merge companion cards. No entry code. A failed read shows no error. After the team pin was retired, the wallet-wide `TeamHomeView` section can come out. |
| `App/TicketWalletDetailView.swift` | When `hasGame` is false, open the no-game session on its code. |
| `App/PlayerJourneyViews.swift` | Pass `templateBannerURL` into `ParticipationDetailGapSections`. |
| `App/OrientScoreReviewSection.swift` | Show `disputeDeadline` and gate 成绩争议 on `canDispute`. Do not turn sync or settle on. |
| `App/FreeExploreTopicCatalogScreen.swift` | Show `store.available`. Prefer `FreeExploreLaunchFailure.response` `message` before the fixed fallback. The catch still ignores `message`. |
| `App/TemplateAuthoringMineView.swift` | Search pins are retired. The keyword field can come out. Do not delete the page; `R8-MEM-26-1` is still an owner decision. |
