# cursor/core-merchant-coop

Base: `origin/ui/combined-r7` at `7fdfad1f177fadb76f7fd54a82b27fa69b82f1f8`.

Owner: Cursor K3. Core and Tests only. No App screen edits. No `project.pbxproj`, no `tools/current_ci_manifest.json`, no new Swift folder (files stay in `Core/` and `Tests/CoreTests/`). No swiftc in this run, so this receipt does not claim a parse.

Money movement stays test-only. No payout, refund, or withdrawal path was enabled. New gates default off. `gap/g2-ops` `Core/MPGap/MerchantCoop` was not edited.

## Closed

| Gap | What Core now does |
|---|---|
| MC7-02-4 | `MerchantOnboardingDraft` sends `locationLat` / `locationLng` on `merchant_registration` only when both are finite and in range, and restores them on reapply. |
| MC7-03-1 | `pages/merchant/profile/index` keeps `id` xor `poiId` (`MerchantPublicHomeLink`). |
| MC7-06-1 | Ledger links follow `normalizeMerchantFinanceRoute`. Unknown `view` is rejected (`链接已失效`). Bare path stays legacy tab 0. |
| MC7-06-4 / MC7-07-2 | `activity_ticket` and `session_fee` record keys decode and `POST api/merchant/finance/redemption-detail` sends that `recordType`. A bare decimal is still `redemption`. |
| MC7-06-10 | `MerchantFinanceRedemptionList` adds `topicId` only when the caller passes one. `.redemptions(filter:page:)` still omits it. |
| MC7-07-1 | Order-detail links accept `recordType` + `recordId`. Missing pair is `缺少核销记录信息`. |
| MC7-13-2 | `.reviews(page:)` sends `filter=all`. `MerchantReviewManageRead` sends `all/pending/low/photo/platform` and decodes `filterCounts`. |
| MC7-04-2 | `MerchantVerificationRecordPage` posts `pageNum` + `pageSize` 50. `hasMore` is a full page whose collected count is still under `total`. |
| B-11 / MC7-35-1 | `CoopFlowRead.clubSettlementSummary(clubID:personal:)` is `POST api/club/settlement/summary` with `{clubId}` and `personal:true` only when asked. Response requires `data.topics`. `CoopClubSettlementDetail` reads the server amount strings. It does not withdraw. |
| MC7-35-2 | `MerchantSettlementDetailLink` reads `source`, `id` / `topicId`, `clubId`, `personal`. Missing club id or record id is `缺少结算记录信息`. |
| MC7-30-2 / 31-10 / 32-7 / 33-9 / 29-12 | Coop list (`topicId`, `topicName`, `scope=MERCHANT`, `tab`), invite (`type`, `toId`, `topicId`), invite-detail (`inviteId`, `box`), nearby (`topicId`, `topicName`), and team `invite` (same token rule as `MerchantOperatorAcceptance`) parse. |
| MC7-30-6 / MC7-32-3 | `CooperationInvite` decodes `supplyStationId` and `supplyStationName`. `CoopSupplyStationAccept` builds `POST api/coop/handle` `{id,status:1,supplyStationId,handleReason?}`. `CoopFlowService.acceptSupplyStation` uses the existing dormant handle grant. Default configuration sends nothing. |
| B-12 / B-17 | `markInboxConversationRead` is a form POST of `conversation_id` and stays off unless `writesEnabled`, `inboxConversationReadEnabled`, and `enabledPaths` contains `api/im/read`. |
| MC7-11-3 | `MerchantInsightSlots.build` reads `facts.checkin.slotBuckets` (empty or non-positive total is nil). |
| MC7-26-4 | `MerchantGameNodeReadyDraft.fieldIssues(routePlay:)` and `MerchantGameNodeCoordinator.readyFieldIssues` split capacity, date, time window, and checklist. `ready()` is unchanged. |
| MC7-01-7 | `MerchantDeskManualCodeClient` posts `{code, mode:MANUAL}` to `api/merchant/desk/redeem/resolve` and classifies the route. `MerchantDeskManualCodeGate.off` is the default. It does not redeem. |
| MC7-08-4 | `MerchantFinanceDetailLoad.isMissingRecord` matches code 404 or a message containing `记录不存在` / `记录不可见`. Batch copy is `这条结算批次不存在或已不可见`. |

Tests that pin a touched call: `MerchantCoopCoreTests`, `WiringR6IMReadTests`, `WiringR6ClubSettlementTests`, `MerchantBusinessContractsTests` (reviews `filter=all`), `MiniProgramPageLinkTests`.

## For the Claude F-agent (App)

Do not change these Core signatures. Call the new types.

- Reviews tabs other than 全部: load `MerchantReviewManageRead(filter:page:)`. `.reviews(page:)` is the all tab. Keep `MerchantReviewFilter` from pretending it is the server tab.
- Ledger `topicId`: call `MerchantFinanceRedemptionList.request(filter:page:pageSize:topicID:)` instead of `.redemptions`, which still omits `topicId`.
- Order detail: pass `MerchantOrderDetailLink.record` into `.redemption(recordID:)`. A non-redemption id is `activity_ticket:9` or `session_fee:9`, not a bare number.
- Verify records: append with `MerchantVerificationRecordPage`. Stop when `hasMore` is false.
- Club settlement: construct `.clubSettlementSummary(clubID:personal:)` (`personal` is `query personal == "1"`). Render `CoopClubSettlementDetail`. Do not add cases to `CoopSettlementDetailModel.Value`. `App/CooperationFlowFixtures.swift` `case .clubSettlementSummary:` still matches.
- Settlement and finance screens: `MerchantSettlementDetailLink.resolve`. Missing params use `缺少结算记录信息`. The finance page case itself is still App (MC7-34-3).
- Station accept: show `supplyStationName`, confirm, then `acceptSupplyStation`. Do not put `supplyStationId` on the 3-argument `.handle`. Leave the dormant grant off.
- Inbox mark-read: call `markInboxConversationRead` only with the write switch, the inbox flag, and an `api/im/read` path grant. Default sends nothing.
- Insight: replace the `hourBuckets` loop with `MerchantInsightSlots.build`.
- Game node: show `readyFieldIssues` on the draft. Submit still goes through `ready()`.
- Manual code: the row can call `MerchantDeskManualCodeClient` only after a separate gate is turned on. Default is off. Do not submit a redemption from the classify response.
- Batch detail: if `MerchantFinanceDetailLoad.isMissingRecord` is true, show `batchMissingRecord`, not a generic load error.
- Coop list deep link: hold `CoopListLink` until the inbox has loaded. `CooperationInboxTopicFilter` only selects a topic that is already in that inbox.

## Leftovers

- MC7-23-6: `GET api/merchant/npc/review` is already `MerchantOpsWp03Catalog.npcReview`. The status line is an App render. No new reader.
- MC7-28-2: relation feed `scope:"all"` and the creativesquare merge stay with the club reader. Not edited here, and not in the `gap/g2-ops` merchant-coop files.
- MC7-33-4 / MC7-33-5 and MC-G18: Gemini P0 (un-park nearby). Not a Cursor row.
- MC7-34-3: finance screen case is App-only. The Core page link was already open.
- REV-A is play runtime. REV-C has no owner=Cursor rows. REV-B B-10, B-13, B-18, B-19, B-20, B-26, B-27 are play, invoice, club share, or the free-explore review hook, outside this area's pages.
- X6 / `merchantBusinessApproval` and city-node / AI NPC writes stay off. No production payout, refund, or withdrawal.
- In-flight `restyle/r3-merchant-creator` and `port/p5-contracts` had no Core merchant diff against this base. `gap/g2-ops` owns `Core/MPGap/MerchantCoop` and was left untouched.
