# cursor/r9-merchant-a

Base `d9115273d70e5b88343b2a14f81d111bf515c561`. Implementation `cf6eceb7621f8ea0c3ab04627320272149f41017`. No `swiftc` and no `xcodebuild`, so this receipt does not claim a parse.

`App/AppSession.swift` stays 7994 lines and `App/AppCompositionRoot.swift` stays 4177. `tools/check_appsession_ratchet.py` ceilings were not raised. `Questify.xcodeproj/project.pbxproj` and `tools/current_ci_manifest.json` were not edited. `Resources/Localizable.xcstrings` was not hand-merged.

Money stays off. Deposit create, deposit create/app, and deposit refund retry do not send. Pay, refund execution, payout, withdrawal, paid orders, quote, registration create, and pricing confirm were not newly built.

## P1 boundary

Cursor Core P1 in file order has N = 11. This branch owns the first N//2 = 5.

Last owned P1: **MC9-23-4**. First row left for `cursor/r9-merchant-b`: **MC9-23-5**. Not owned after that: MC9-23-6, MC9-28-2, MC9-30-4, MC9-30-5, MC9-31-2, and every Claude row.

## Owned rows

| Row | Status | SHA | file:line |
|---|---|---|---|
| MC9-13-1 | done | `cf6eceb7621f8ea0c3ab04627320272149f41017` | `Core/MerchantBusinessProduction.swift:149`, `App/MerchantApprovals/MPFirstMerchantApprovals.swift:15` |
| MC9-14-1 | done | `cf6eceb7621f8ea0c3ab04627320272149f41017` | `Core/MerchantEngagementProduction.swift:49`, `App/MerchantApprovals/MPFirstMerchantApprovals.swift:54` |
| MC9-17-1 | done | `cf6eceb7621f8ea0c3ab04627320272149f41017` | `Core/MerchantEngagementProduction.swift:52`, `Core/MerchantEngagementProduction.swift:89`, `App/MerchantApprovals/MPFirstMerchantApprovals.swift:120` |
| MC9-24-1 | done | `cf6eceb7621f8ea0c3ab04627320272149f41017` | `Core/MerchantContentService.swift:171` |
| MC9-26-1 | done | `cf6eceb7621f8ea0c3ab04627320272149f41017` | `Core/MerchantCityNPCParityGates.swift:27`, `Core/MerchantCityNPCParityGates.swift:38` |
| MC9-29-1 | done | `cf6eceb7621f8ea0c3ab04627320272149f41017` | `Core/MerchantBusinessProduction.swift:169`, `App/MerchantOperatorInvitationLandingView.swift:4` |
| MC9-30-2 | done | `cf6eceb7621f8ea0c3ab04627320272149f41017` | `Core/ChinaReviewedRouteCapability.swift:513`, `Core/ChinaReviewedRouteCapability.swift:2737` |
| MC9-33-1 | done | `cf6eceb7621f8ea0c3ab04627320272149f41017` | `Core/MerchantContentService.swift:124`, `App/MerchantContentMPWriteRoute.swift:14` |
| MC9-01-2 | done | `cf6eceb7621f8ea0c3ab04627320272149f41017` | `Core/MerchantContracts.swift:176`, `Core/MerchantService.swift:99`, `App/MerchantWorkbenchProjectCards.swift:77` |
| MC9-14-9 | done | `cf6eceb7621f8ea0c3ab04627320272149f41017` | `Core/MerchantEngagementProduction.swift:54`, `App/MerchantApprovals/MPFirstMerchantApprovals.swift:34` |
| MC9-17-3 | done | `cf6eceb7621f8ea0c3ab04627320272149f41017` | `Core/MerchantAftercareParity.swift:259`, `Core/MerchantBusinessService.swift:152`, `App/MerchantAftercareParityViews.swift:101` |
| MC9-21-1 | done | `cf6eceb7621f8ea0c3ab04627320272149f41017` | `App/CoopFlowPreviewWrite.swift:21` |
| MC9-23-4 | done | `cf6eceb7621f8ea0c3ab04627320272149f41017` | `Core/StoreCharacterCoordinator.swift:368` |

## What shipped

- Review report `POST api/merchant/reviews/manage/report` is in the live catalog. `saveSku` stays false.
- CRM contact `POST api/merchant/crm/customers/{id}/contact` is admitted. Device consume for the phone stays off.
- Aftercare evidence upload is admitted only when the multipart boundary is `MerchantEvidence-` and the body carries `merchant_aftercare_evidence` plus `refundId`. The evidence picker grant opens on that same catalog. Bare `uploadOSS` stays out.
- City-node claim, cancel, offline, and save return `MerchantCoopLiveWrites.cityNode` on a non-closed approval.
- `MerchantCityNPCParityGates.mpFirst.stationCommands` is true. `POST api/game/session/command` is admitted only for a station action. `GET api/game/session/receipt?activityId&requestId` is the readback. The stored default `stationCommands = false` is unchanged.
- Accept-invitation permits `merchantID` 0 when access/me is inactive. The landing button uses that gate.
- Non-money coop paths already in the wired catalog stay admitted, including `api/coop/handle`. `api/coop/candidates/reject` is an owner grant. `api/coop/deposit/create`, `create/app`, and `refund/retry` are money kinds and `admitsChinaProductionCall` is false while the switches are off. `api/coop/deposit/status` stays a read.
- Chapter invite defaults on and `api/merchant/chapter-application/invite` is on the merchant-content route. Respond, apply, and withdraw stay off.
- Project cards decode `imgUrl` / `topicImgUrl`. Upcoming runs are `POST api/merchant/upcoming-runs` JSON `{}`, only with verify-record read. The visit line follows the mini-program join-card rule.
- CRM segment save, export create, `POST exports/{id}/status` `{}`, and `GET exports/{id}/download` are in the MP-first catalog. Campaigns and broadcasts stay off.
- Manual case detail is `POST api/merchant/aftercare/manual-case-detail?manualCaseId=` and the detail view renders 工单编号 and amount from that read.
- Perk-template save/delete executor opens on `www.chengyinhub.com` when MP-first is on, and still on the reviewed test host. Money blocks stay on the switch.
- `acceptRecordedSample` stores a real uploaded clip and the existing confirm posts `api/merchant/npc/voice/enroll`. The recorder button itself is MC9-23-3.
