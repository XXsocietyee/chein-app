# cursor-wire2-merchant-coop

Base `origin/ui/combined-r7` `b0ac0108d0a5a9739ababecbbc61284cae5a8043` (message starts "Integrate F-agent round 2"). Tip had not moved. No rebase. Branch `cursor/wire2-merchant-coop`. No pull request.

Source: `docs/release/receipts/cursor-mp-cov-merchant-coop.md` and `docs/mp-contract-coverage/merchant-coop.md`. The twelve pin tests in `Tests/CoreTests/MiniProgramMerchantCoopContractPinTests.swift` were not redone. No endpoint was added. `api/creativesquare/list` was not taken.

No `swiftc` run. This receipt does not claim a parse. `project.pbxproj` and `tools/current_ci_manifest.json` were not edited. No secret and no mini-program screenshot.

## Sites checked

The coverage receipt named these App files and did not change them. On this base each one already calls the Core constructor that receipt aligned. Zero call sites moved.

| Site on this base | Already calls | Contract | Moved |
|---|---|---|---|
| `App/MerchantReading.swift:200` `merchantEvents` | `MerchantService.events` | `POST api/merchant/events` JSON `{}` | no |
| `App/AppSession.swift:7868` `merchantEvents` | `MerchantService.events` | same empty JSON object | no |
| `App/MerchantHomeView.swift:206` and `:750` | `reader.merchantEvents` | same | no |
| `App/MerchantProjectRecentEventsView.swift:35` | `reader.merchantEvents` | same | no |
| `App/MerchantBusinessViews.swift:313` home destinations | `.aftercare`, `.overview`, `.redemptions(filter:page:)`, `.entries(source:page:)`, `.batches(page:)`, `.verificationRecords` | query + empty JSON aftercare list; overview `{}`; redemptions without `topicId`; entries `source` default `all`, page size 20; batches page size 20; verify-records page size 50 | no |
| `App/MerchantBusinessViews.swift:225` aftercare reload | `snapshot(.aftercare(bucket, page: 1))` | `POST api/merchant/aftercare/list` query `bucket` / `pageNum` / `pageSize` and JSON `{}` | no |
| `App/MerchantHomeView.swift:774` and `:920` | `.aftercare(.pending, page: 1)` | same aftercare list | no |
| `App/MerchantHomeView.swift:475` 核销记录 | `.verificationRecords` | `POST api/merchant/finance/redemptions` `filter=all`, `pageNum`, `pageSize` 50 | no |
| `App/MerchantLedgerSettlementOverview.swift:71` | `section.query(page:)` | overview `{}`, entries, batches | no |
| `App/MerchantLedgerSettlementOverview.swift:103` | `MerchantLedgerRedemptionsModel(topicID:)` | `topicId` only when the ledger link carried one; otherwise `.redemptions(filter:page:)` | no |
| `App/MerchantSettlementOverviewView.swift:47` | `section.query(page:)` | overview, entries, batches | no |
| `App/MerchantPersonalIncomeHandoff.swift:34` and `:200` | `snapshot(baseline.document.query)` and `snapshot(.overview)` | finance overview JSON `{}` | no |
| `App/NativeVerificationView.swift:17` readback | `.redemptions(filter: "all", page: 1)` | ledger redemptions, no `topicId`, page size 20. The verify-records page stays `.verificationRecords` | no |
| `App/MPReviewedPageScreen.swift:404` ledger | `MerchantLedgerSettlementOverview(topicID:)` | topic from `MerchantFinanceRoute.normalize` | no |
| `App/MPReviewedPageScreen.swift:441` verify-records | `.verificationRecords` | page size 50 | no |
| `App/MerchantBusinessEditor.swift:311` aftercare opinion | `MerchantBusinessMutation.aftercare` | Core `permits` stays false and `execute` throws `.disabled`. Nothing is sent | no |
| `App/MerchantBusinessEditor.swift:312` review reply | `MerchantBusinessMutation.review` | `reviewId` decimal string, `expectedVersion` number, delete omits `content`. The same service still refuses the send | no |
| `App/MerchantReviewOriginalRecoveryEntry.swift:75` | `reader.read(intent)` | `MerchantReviewReplyOriginal.receiptPath` / `receiptFields` (`reviewId` string, `action`, `requestId`) | no |
| `App/AppSession.swift:5739` and `App/AppCompositionRoot.swift:247` | `MerchantReviewOriginalReceiptReader` | same receipt constructor. The reader stays behind its own default-off grant | no |
| `App/PublicMerchantHomeFixtureView.swift:20` and `:45` | `PublicMerchantHomeHTTPReader.home(.ownerMemberID)` | `POST api/merchant/public-home` JSON `{"memberId": ...}` | no |
| `App/AppCompositionRoot.swift:983` `PublicMerchantHomeCompositionScope.accepts` | admits that JSON `memberId` | same public-home body | no |
| `App/AppSessionSocialRoam.swift:25` | `readOnlyPublicMerchantHomeContext.reader` | the same home reader | no |
| `App/BundleCommerceMount.swift:867` | `PublicMerchantHomeView(target: .ownerMemberID)` | `memberId`, not a legacy row `id` | no |
| `App/AppSession.swift:2787` channel-host `IMExpandedService` | `ordinaryReadRequestEnabled: factory.permits(.imRead)` only | does not pass `inboxConversationReadEnabled` | no |
| `App/AppSession.swift:6436` `imExpandedWriter` | neither read flag | both default false, so `markInboxConversationRead` throws `APIError.notConfigured` and sends nothing. Chat `read_to` stays on `performOrdinaryRead` | no |

`MerchantService.events` posts `JSONSerialization` of `[:]`, which is `{}`. `MerchantBusinessQuery.aftercare` is `.queryJSON` with an empty object. `MerchantBusinessMutation.review` stores `reviewId` as `.string`. `IMExpandedService.merchantInboxMarkReadRequest` is the urlencoded `conversation_id` body, and no App construction turns that switch on.

## Left as they were

- Payout, withdrawal, and refund response. `ReleaseMoneyWriteSwitch` was not edited. `MerchantBusinessService.execute(.aftercare)` still fails closed with `MerchantBusinessFailure.disabled` and an empty transport.
- Both IM mark-read switches. Inbox mark-read is not enabled. Ordinary read is still only the existing `permits(.imRead)` on the channel-host writer.
- `api/club/settlement/summary` stays `POST {clubId}`. `CoopFlowRead.clubSettlementSummary` is not in `usesGet`. `personal: true` is added only when the Bool is true. `MerchantSettlementDetailLink` sets that Bool only when `query["personal"] == "1"`. `App/MPReviewedPageScreen.swift` club settlement still mounts `CoopClubSettlementDetailView` with that link. It was not flipped to GET.
- `pages/merchant/relation` still opens `SessionCoopRelationDiscoveryView`. `api/creativesquare/list` was not added.
- Signatures of `SettingsView`, `MerchantVerifyRecordsSections` (`MerchantDeskManualCodeAction` kept), `PlatformConsumerSessionOwner`, `RoamPOIActions`, `JourneyReportViews`, `TeamHomeView`, `TicketWalletView`, `TopicXcxSections`, `ClubDetailView`, and `ClubWorkbenchKit` (`ownerStage` kept).
