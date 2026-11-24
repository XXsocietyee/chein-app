# cursor/wire-merchant-coop

Base: `origin/ui/combined-r7` `82388e4a5e7391e0c5a286735d6b30613a860ae8`.

Merged before the call-site edits, and kept:

- `origin/fix/r3-merchant-coop-a` `c58d34e3b177d9df2205920c6946769a7a41b3eb` (merge `c31af613c`)
- `origin/fix/r3-merchant-coop-b` `605129e344f77da869e10f9d23bf175017d6ebed` (merge `73d782527`)

The only conflict on A was `tools/check_typography_lint.py` (kept the combined-r7 lint). The only conflict on B was `App/MerchantBusinessViews.swift` (kept A's customer updating row and B's team sign-in / denied states).

This VM has no `swiftc` or `xcodebuild`. This receipt does not claim a parse.

No payout, refund, or withdrawal was enabled. Money stays TEST-only. New gates stay at their defaults. `pbxproj` and `tools/current_ci_manifest.json` were not edited. The coop-list deep link (`CoopListLink`) was not wired.

## B-11 club settlement is POST

The production club-settlement read is `CoopFlowRead.clubSettlementSummary(clubID:personal:)`. `usesGet` is false for that case. The body is `{clubId}`, and `personal: true` is added only when the Bool is true.

`pages/coop/settlement-detail/index` now resolves `MerchantSettlementDetailLink`.

| Source | Caller |
|---|---|
| Missing link | `缺少结算记录信息` |
| `finance` | Existing `CoopSettlementDetailView` source `.finance` |
| ledger (anything else) | Existing `CoopSettlementDetailView` source `.mybiz` |
| `club` | `reader.read(.clubSettlementSummary(clubID:personal:))` then `CoopClubSettlementDetail` for the matching topic |

`personal` is the link flag, which is true only when the query is `personal=1`. The club path does not use the finance/mybiz adapter and does not add a `CoopSettlementDetailModel.Value` case. The fixture `case .clubSettlementSummary` still matches. No GET club-settlement caller was left on this path.

## B-12 IM mark-read, gate off

`IMExpandedWriter.markInboxConversationRead(conversationID:)` calls `IMExpandedService.markInboxConversationRead`. The merchant inbox local mark still happens, then each conversation id is passed to that writer. `APIError.notConfigured` is swallowed, so a closed gate does not undo the local mark.

Neither `IMExpandedService` construction in `AppSession` passes `inboxConversationReadEnabled`. The default remains `false`, so `canWriteInboxConversationRead` stays false and the form POST is not sent.

## Other call sites

| Site | What the screen does now |
|---|---|
| Review tabs other than 全部 | The segmented picker is still `MerchantReviewFilter` and still filters the loaded page. Choosing pending, low, or photos reloads through `MerchantReviewManageRead` (`photos` → server `photo`). 全部 stays `.reviews(page:)`, which is filter `all`. A reader without the new method falls back to that all-tab read. There is no platform segment on this picker, so `platform` is not requested. |
| Ledger `topicId` | `pages/merchant/ledger/index` with a redemptions `topicId` opens the ledger overview and `MerchantFinanceRedemptionList` includes `topicId`. A ledger with no topic still uses `.redemptions(filter:page:)`, which omits it. |
| Typed redemption ids | `pages/merchant/ledger/order-detail/index` passes `MerchantOrderDetailLink.record` into `.redemption(recordID: record.recordKey)`. A missing pair shows `缺少核销记录信息`. |
| Verification append | Page 1 stays `.verificationRecords`. A full page still short of `total` calls `verificationPage`. Appending stops when `MerchantVerificationRecordPage.hasMore` is false, or when the reader does not implement paging. |
| Settlement-detail routing | The page above. Finance and ledger keep their existing screens. |
| Station accept | When the invite has `supplyStationId`, the name is shown and confirm calls `acceptSupplyStation`. Accepts without a station still use the 3-argument `.handle`. The dormant handle grant is unchanged, so the default still sends nothing. |
| Slot bars | The insight check-in rows use `MerchantInsightSlots.build` (`slotBuckets`). An empty or non-positive total draws nothing. |
| Ready-draft field errors | `readyFieldIssues` is shown on the ready card. Submit is still `submitReady()`. |
| Manual-code row | The verify-records list shows the row when the session supplies it. The client is built with `MerchantDeskManualCodeGate.off`. Empty and over-long codes show `请输入核销码` and `核销码过长`. A classified route is not submitted. |
| Batch copy | A batch load whose rejection matches `MerchantFinanceDetailLoad.isMissingRecord` shows `这条结算批次不存在或已不可见` on both batch detail screens. |

New text uses `cyText` semantic styles. The screen work from the two fix branches was left in place.
