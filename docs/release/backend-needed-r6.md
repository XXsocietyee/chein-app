# Backend needed after combined-r6 (parity r2)

Collected from the six round-2 fix receipts merged into `ui/combined-r6`:
`docs/release/receipts/fix-parity2-{club,play-roam,player-content,member,account-publish,merchant-coop}.md`.
Carried-over items from round 1 remain in `docs/release/backend-needed-r5.md`; only **new** items from round 2 are listed below.

## 1. New backend changes (server work)

| finding | area | endpoint | fields / change | page (app) |
|---|---|---|---|---|
| CLB-customer-detail-06 | club | `POST /api/club/crm/customers/detail` | If the MP line 「最近互动…」 should be server-rendered, add `summary.lastInteractionText` (the MP binds it, but `ClubCustomerVO.Summary` has no such field today). | Club governance → 客户详情 |
| JREPORT-5 | play-roam | `GET /api/play/player-journey/report` | Return `reasonCode: "RUN_NOT_FOUND"` (or HTTP 404 consistently) for a deleted or unknown run, so the app can distinguish 本局已不存在 from a network failure. | Journey report |

## 2. New client / gate notes on existing endpoints

| finding | area | endpoint | note | page (app) |
|---|---|---|---|---|
| merchant/index-P1 (我的消息 read mark) | merchant-coop | `POST /api/im/read` (`{conversation_id}`) | Currently marks conversations read locally only; `IMExpandedService.canWriteOrdinaryRead` gates the server write. Opening it here is a gate decision, not a backend change. | Merchant 工作台 → 我的消息 |
| coop/settlement `source=club` | merchant-coop | `GET /api/club/settlement/summary` | Exists on the server; needs wiring into `CoopFlowRead` (app-side work, deferred). | Coop settlement detail (`source=club`) |
| MKT-7-2 | member | `POST /api/merchant/public-home`, `POST /api/merchant/reviews/public`, `POST /api/merchant/reviews/create` | Contract wired in `BundleCommerceMount`; `RetainedPublicMerchantReviewHost` still builds its reader and writer with `enabled: false` (existing gate). | 我的订单 → 自由探索套餐 → 评价 |

## 3. Areas with nothing new

- **player-content**: unchanged from round 1 (`PC-C-4-1` `safetyNotice` on `GET /api/official/events/{id}`).
- **account-publish**: none new (`A3-01` reuses `POST /api/common/uploadOSS` and `POST /api/user/update`, behind `ProfileAvatarDependencies`; `A3-07` reads `NICKNAME_TAKEN` / `NICKNAME_INVALID` from `/api/user/update`).
