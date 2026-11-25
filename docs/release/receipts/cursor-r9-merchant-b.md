# cursor-r9-merchant-b

Base `d9115273d70e5b88343b2a14f81d111bf515c561`. First owned row: **MC9-23-5**. No `swiftc` run, so this receipt does not claim a parse. Pay, refund execution, payout, withdrawal, paid orders, quote, registration create, pricing confirm, `saveSku`, review report, poster code, and station commands stay off and send nothing.

Code SHA `5c11b5c96d29abb715fd5aea9360c35afe013284`.

## Owned rows

| Row | Status | SHA | file:line |
|---|---|---|---|
| MC9-23-5 | done | `5c11b5c96d29abb715fd5aea9360c35afe013284` | `Core/StoreCharacterService.swift:135` `Core/StoreCharacterService.swift:188` `App/MerchantStoreCharacterView.swift:753` |
| MC9-23-6 | done | `5c11b5c96d29abb715fd5aea9360c35afe013284` | `Core/StoreCharacterService.swift:258` `App/MerchantStoreCharacterSessionBinding.swift:25` |
| MC9-28-2 | done | `5c11b5c96d29abb715fd5aea9360c35afe013284` | `Core/ClubCommunityService.swift:127` `App/AppSession.swift:999` |
| MC9-30-4 | done | `5c11b5c96d29abb715fd5aea9360c35afe013284` | `Core/MiniProgramPageLink.swift:95` `Core/MerchantCoopLink.swift:117` `App/MPReviewedPageScreen.swift:571` |
| MC9-30-5 | done | `5c11b5c96d29abb715fd5aea9360c35afe013284` | `Core/CooperationFlowContracts.swift:281` `App/CooperationBrowserView.swift:385` |
| MC9-31-2 | done | `5c11b5c96d29abb715fd5aea9360c35afe013284` | `Core/CooperationFlowContracts.swift:319` |
| MC9-06-3 | done | `5c11b5c96d29abb715fd5aea9360c35afe013284` | `Core/MPGap/MerchantCoop/MerchantGapRemaining.swift:208` `App/MerchantLedgerSettlementOverview.swift:169` |
| MC9-11-3 | done | `5c11b5c96d29abb715fd5aea9360c35afe013284` | `Core/MerchantInsightRecentVisitors.swift:16` `App/MerchantInsightRecentVisitorsSection.swift:23` |
| MC9-19-4 | done | `5c11b5c96d29abb715fd5aea9360c35afe013284` | `Core/MerchantOperationsContracts.swift:17` `App/MerchantOperationsViews.swift:65` |
| MC9-23-7 | done | `5c11b5c96d29abb715fd5aea9360c35afe013284` | `Core/StoreCharacterService.swift:262` `App/MerchantStoreCharacterView.swift:268` |

## Not taken

Cursor Core P0 stays with the other lane: MC9-13-1, MC9-14-1, MC9-17-1, MC9-24-1, MC9-26-1, MC9-29-1, MC9-30-2, MC9-33-1.

The first five Cursor Core P1 rows stay with the other lane: MC9-01-2, MC9-14-9, MC9-17-3, MC9-21-1, MC9-23-4.

Claude App rows were not touched.

## Notes

- MC9-23-5 posts JSON `{}` to `api/merchant/npc/voice/reset`, already on the China voice-enrollment allowlist, then re-reads voice status. The toast is only when the reread status is none.
- MC9-28-2 follows `utils/community-post-api.js`: `/api/creativesquare/list` with `is_my=0` is GET `api/v1/community/feeds/LATEST`. The lane is included only when `communityPostRead` is a literal true. The club `beforeId` stays the club page's last paging id. No new path was added.
- MC9-06-3 does not invent an HTTP opt-in. The settlement segment toggles `coopSettle` and asks the existing notification permission adapter. Template `Z10x9KV0jciDbFGTS6javEjqz0abOi-ik6x_0e_pt-o`, landing `pages/merchant/ledger/index`.
- MC9-30-5 sends `scope` on candidates confirm/reject. It does not create a registration and does not send money.
- MC9-31-2 adds `supplyStationId` on merchant invites only. The station picker UI is not this row.
