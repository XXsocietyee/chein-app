# Backend needed after combined-r5 (parity r1)

Collected from the six fix receipts merged into `ui/combined-r5`:
`docs/release/receipts/fix-parity-{club,play-roam,player-content,member,account-publish,merchant-coop}.md`.
Only rows those receipts mark **blocked-backend** or list under **Backend needed** / **Backend / gate needed** are here.
Owner rulings that are not backend work (money gates, WeChat auth, glossary, chrome calls) stay in the receipts.

## 1. Backend changes (server work)

| finding | area | endpoint | fields / change | page (app) |
|---|---|---|---|---|
| CLB-detail-12 | club | `POST /api/club/post/create` | Accepts `type` from the body with no role check (`post.setType(body.getType() …)`). For `type == 2` (公告) require owner / admin / `club:content:manage`. Today the gate is client-only. | Club page → 动态 → 发布动态 (作为公告发布 toggle) |
| PLAYM-2 | play-roam | `GET /api/play/nodes` | Row `perk: { name, redeemRule }` is not in the decoded row; add it (or confirm the field name). Status **blocked-backend**. | Free-exploration store card → 到店体验 (PlayStoreDayMerchantView) |
| ROAM-7 | play-roam | `GET /api/roam/entry/nearby` | Confirm the GET accepts no `Authorization` (MP 2026-11-14 guest rule) so the app can read it signed out. | Roam tab → 附近活动 (guest) |
| PC-C-4-1 | player-content | `GET /api/official/events/{id}` (and the v2 detail) | Return `safetyNotice: { title: string, version: string }` when an event has a safety notice (MP official-detail js:482-483 reads it). Client is done; without the field the consent row never shows. | Official event detail → 立即报名 (安全须知 checkbox) |

## 2. Client work on existing endpoints (no backend change; listed under "Backend needed" in the receipts)

| finding | area | endpoints | fields | page (app) |
|---|---|---|---|---|
| MKT-7-2 | member | `POST /api/merchant/public-home {memberId}` → `merchantRowId`; `POST /api/merchant/reviews/public?merchantRowId&registrationId&pageNum&pageSize=20`; `POST /api/merchant/reviews/create {merchantRowId, registrationId, rating, content, imageUrls: [], requestId}` | Backend has no `/api/free-explore/bundle/review`; the app uses `UnavailableBundleReviewClient`. All three routes are `.liveInProduction` in the route table. | 自由探索权益 bundle page → 评价 |
| FIN-11-4 | member | invoice original-request read | Core maps `INVOICE_NOT_FOUND` to "unknown"; needs a Core change in `InvoiceLaunchService`, not backend. | 我的发票 → 查询结果 |
| CLB-detail-11 | club | universal link `pages/topic/index/index?id=&sourceClubId=&clubCode=` | No backend change: the app's link parser must accept `sourceClubId` / `clubCode` and carry them into registration as `sourceChannelCode`. Status **blocked-platform** (needs an iOS attribution decision). | Club 活动 card → 带票分享 |
| relation-P0b | merchant-coop | club post feed | MP sends `scope: "all"` (site-wide); the app's club community reader omits `scope`, so the server returns joined/cooperated clubs only. Client change in the club community reader. | Merchant 合作 tab → 发现 → 帖子 |

## 3. Reviewed-route gate entries (owner adds a grant; backend routes already exist)

| finding | area | endpoint | note | page (app) |
|---|---|---|---|---|
| MKT-1-1, MKT-5-1 | member | `GET /api/platform-pass/orders`, `GET /api/platform-pass/orders/{orderNo}` (also `/api/platform-pass`, `/library`) | Not in `ChinaReviewedRouteCapability`, so the production route gate refuses them. Exist in `ApiPlatformPassController`. | 我的 → 通行证 → 我的订单 / 通行证订单 |
| MKT-5-3 | member | `POST /api/platform-pass/orders/{orderNo}/cancel`, `POST …/refund-apply {reason}` | Exist; owner decides whether they count as money under the gate. Transport refuses every non-GET child today. | 通行证订单 → 取消 / 申请退款 |
| B-PV-01 | account-publish | `POST /api/media/asset/{id}/retry` | Existing endpoint (`ApiMediaAssetController.retry`); no mark in `ChinaReviewedRouteCapability`. Admitted only under the own-media status approval. Add a mark if the gate review wants one. | 设置 → 隐私与定位 → 我的待审媒体 → 重新提审 |
| ai-npc-P0, citynode-P0, citynode-create-P0, game-node-P0 | merchant-coop | city-node `save` / `claim` / `claim/cancel` / 上下线, station commands, store character save / voice | `MerchantCityNPCParityGates.reviewedEndpoints` is empty until a deployment review approves exact routes. | Merchant 品牌中心 → AI 店铺角色 / 城市节点 / 游戏节点 |
| X6 | merchant-coop | 口碑 / 客户 / 售后 writes | `MerchantBusinessProductionApproval` grants (per merchant + exact target) are never supplied. | Merchant 工作台 → 口碑 / 客户 / 售后 |

## Areas with nothing new

- account-publish: "None new" (B-PV-01 uses the existing retry endpoint; gate note above).
- merchant-coop: "None required for the fixes above"; the two open questions are the gate rows in §3.
