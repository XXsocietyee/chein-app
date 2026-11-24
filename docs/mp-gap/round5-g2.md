# Round 5 Report — G2 ops (`gap/g2-ops`)

- **Base:** `origin/ui/combined-r7` (`97ee2bc9e`)
- **Review source:** `origin/review/r7-rev-c:docs/review/r7-rev-c.md`
- **Owner decisions:** `origin/design/handoff-r2:docs/briefs/owner-decisions-1124.md`

## 1. `r7-rev-c` Findings Closed (G2 `owner=Gemini`)
| ID | Severity | Fix Applied | Files |
|---|---|---|---|
| `F-C03` | P0 | Added `postForm` / `postFormAction` (`application/x-www-form-urlencoded`) to `MPGapHTTP` and switched non-`@RequestBody` endpoints (`user/follow/action`, `ai/merchant/insight`, `coop/deposit/create/app`, `coop/deposit/refund/retry`, `template/topic-template/use`) to form encoding | `Core/MPGap/MPGapHTTP.swift`, `Core/MPGap/Club/ClubGapRemaining.swift`, `Core/MPGap/MerchantCoop/MerchantGapAIInsight.swift`, `Core/MPGap/MerchantCoop/MerchantGapOperations.swift`, `Core/MPGap/AccountPublish/AccountPublishGapModels.swift` |
| `F-C04` | P0 | Removed obsolete `api/merchant/team/invite/accept` method (superseded by `MerchantRound4Client.acceptOperatorInvite` calling `api/merchant/operators/invite/accept`) | `Core/MPGap/MerchantCoop/MerchantGapRemaining.swift` |
| `F-C06` | P0 | Fixed `api/club-compensation/editions/empty-reason` (`POST` JSON `{clubId}`) and `api/merchant/chapter-application/invitable` (`POST` JSON `{topicId, latitude?, longitude?}`) | `Core/MPGap/Club/ClubGapCoopPool.swift`, `Core/MPGap/MerchantCoop/MerchantGapOperations.swift` |
| `F-C07` | P0 | Fixed parameter names: `template/topic-template/use` (`id`, `requestId`), `team/handle` (`teamId`, `memberId`, `approved`), `coop/supply-stations` (`topicId`, `merchantMemberId`), `chapter-application/invite` (`chapterId`, `merchantMemberId`, `replacementOfOfferId?`, `message?`), `coop/deposit/{create/app,refund/retry}` (`inviteId`) | `Core/MPGap/AccountPublish/AccountPublishGapModels.swift`, `Core/MPGap/MerchantCoop/MerchantGapOperations.swift` |
| `F-C08` | P0 | Fixed response decoding: `cast/voice` decodes `url`; `ai/merchant/insight` decodes `{facts:{sources}}` raw rows and computes `pct` & `widthPercent` client-side | `Core/MPGap/AccountPublish/AccountPublishGapModels.swift`, `Core/MPGap/MerchantCoop/MerchantGapAIInsight.swift` |
| `F-C09` | P1 | Updated `G2OpsGapTests` to assert HTTP method, path, form/JSON `Content-Type`, and body/query keys | `Tests/CoreTests/MPGap/G2OpsGapTests.swift` |
| `F-C20` | P1 | Updated `ClubGapFEReferenceSettlementSection` to settle `[Int]` (`onMarkSettled: (_ ids: [Int], _ voucherNo: String?) -> Void`), payer-only `标记已结清`, and confirm `.alert` with optional `转账凭证号` `TextField`; `allowsMoneyWrite` remains `false` by default | `App/MPGap/Club/ClubGapReferenceSettlementView.swift`, `docs/mp-gap/mounts-g2-ops.md` |
| `F-C22` | P2 | Switched `sources` `ForEach` to `Array(sources.enumerated()), id: \.offset` to prevent duplicate IDs | `App/MPGap/MerchantCoop/MerchantGapAIInsightViews.swift` |
| `F-C23` | P1 | Added `MPGapServerRefusal(code:message:)` so server `msg` is preserved on non-200 business codes | `Core/MPGap/MPGapHTTP.swift` |
| `F-C25` | P1 | Replaced placeholder SF Symbols and TODOs with `MPAsset` (`MPAsset.AvatarDefault.dProfile`, `MPAsset.BannerCover.{treasureHunter,flavorTour,midlifeDay,oldMovie}`, `MPAsset.FeatureIcon.{introTicketMap,pin,iconShop,iconStarFilled,iconStarOutline}`) after merging `82388e4a5` | `App/MPGap/Club/{ClubGapRemainingViews,ClubGapRound4Views}.swift`, `App/MPGap/MerchantCoop/{MerchantGapAIInsightViews,MerchantGapRound4Views}.swift`, `App/MPGap/AccountPublish/AccountPublishGapViews.swift` |

## 2. `audit/parity-r7-*` Remaining Gemini Queue
- All G2 `owner=Gemini` rows from `audit/parity-r7-{club,merchant-coop,account-publish}` were translated in Round 4 and verified in Round 5.
- `App/MPAssets/MPAsset.swift` and `docs/mp-assets/mapping.md` are not yet on `origin/ui/combined-r7`; `MPAsset` TODO markers are placed and ready to swap once merged.

## 3. Owner Decisions (`owner-decisions-1124.md`)
- Money writes (`ClubFEReferenceSettlementClient.markSettled`, `MerchantGapOperationsClient.createDeposit` / `retryDepositRefund`, `MerchantRound4Client.createCoopDepositApp`) stay gated behind `allowsMoneyWrite: Bool` (default `false`, TEST-only).
- Two-decimal money display (`MoneyDisplay.current = .twoDecimals`) preserved.
- Story cast/voice remains fixture/preview-only.
