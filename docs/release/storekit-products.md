# StoreKit products: proposal for the owner

Lane T (`claude/testflight-prep`), 2026-11-26. **Proposal only. Nothing here is turned on.**

- Virtual goods stay **off** in the iOS app. `ReleaseMoneyWriteSwitch` / `ReviewedAreaSwitch.releaseMoneyDerivation` still returns false for `.virtualGoods`. `Config/QuestifySandbox.storekit` still has an empty product array. No product exists in App Store Connect.
- Real-money player flows that are **not** virtual goods (event tickets, guided tickets, refunds) stay on, per the owner decision of 11-26 06:35 UTC.
- Source of truth: the 11 payment call sites in the mini program (`wx.requestPayment` = WeChat Pay JSAPI, `wx.requestVirtualPayment` = WeChat virtual payment XPAY) traced to the backend in `liboyang42-cpu/hengyin` at `7e524aa0`. Points can only be earned, never bought (`chengyinhub-xcx/subpackageMember/market/passes/index.js:97`). There is no coin, top-up, cart or physical-goods checkout.

Product id prefix: the Release bundle id `com.chengyinhub.chengyinApp`. Apple product ids are permanent and cannot be reused after deletion, so the owner confirms each id before creating it.

## 1. Digital goods → in-app purchase (owner creates these in App Store Connect)

| # | Good (zh / en) | MP page | Backend (order endpoint · kind) | Buyer gets | StoreKit type | Proposed product id(s) | Price / tier |
|---|---|---|---|---|---|---|---|
| D1 | 通行证 年卡 / Platform Pass, year | `subpackageMember/market/membership`, `market/pass-order`, `market/library` | `POST /api/platform-pass/orders` → `/orders/{no}/pay` (XPAY) · `PLATFORM_PASS`, plan `YEAR` | Free self-play claims on platform-owned topics in the pass catalogue for 365 days. Buying again extends from the current end date. No auto-renew (`PlatformPassService.java:28`). | Non-renewing subscription | `com.chengyinhub.chengyinApp.pass.year` | MP ¥299 (`chengyinhub-admin/sql/migration_20261110_platform_pass.sql:92`, seeded `status=0`, not on sale). Pick the nearest Apple CNY price point. |
| D2 | 通行证 月卡 / Platform Pass, month | same as D1 | same, plan `MONTH` | Same for 30 days | Non-renewing subscription | `com.chengyinhub.chengyinApp.pass.month` | MP ¥39 (same file, line 92). Nearest Apple CNY price point. |
| D3 | 自玩通行证（单主题）/ Self-play ticket, one topic | `pages/topic/index` checkout; resume in `scene-member-order-history` / `-detail` | `POST /api/registration/create` → `/api/registration/pay` (+ `/xpay/confirm`) · `TOPIC_TICKET`, `PurchaseKind.SELF_PLAY_PASS = 2` | Self-guided play of one topic for 90 days or until the topic run ends (`CmsRegistrationServiceImpl.java:1086-1094`) | Consumable, one SKU per **price tier** | `com.chengyinhub.chengyinApp.selfplay.cny<price>` e.g. `…selfplay.cny38` | Data-driven: `CmsTopic.selfPlayPrice`, set per topic. XPAY already maps price in fen → WeChat goods id (`platformpass/SelfPlayXpayProperties.java`, config `chengyin.selfplay.xpay.goods`); the Apple map copies that pattern. |
| D4 | 单主题 / 双人票 / 四人小队票 · Single quest, 2-seat, 4-seat pack | `subpackageMember/market/pass`, `pages/topic/index` | `POST /api/marketing/product/quote` → `/order` → `/orders/{no}/pay` (JSAPI) · `MARKETING_PRODUCT`, `KIND_SINGLE_QUEST = 1`, route `SELF_PLAY_GRANT` | Self-play for 1, 2 or 4 people on one topic (codes `SEAT2-T<id>`, `SEAT4-T<id>`) | Consumable (price tier) | `com.chengyinhub.chengyinApp.seats.cny<price>` | 2 seats = 83 %, 4 seats = 75 % of seats × self-play price, rounded up to end in .90 (`migration_20261124_seat_products_backfill.sql:6-9`). Apple CNY points do not end in .90, so the iOS price moves to the nearest point. |
| D5 | 城市合集 / City bundle | `market/passes` → `market/pass` | same as D4 · `KIND_CITY_BUNDLE = 2` | Several topics; validity relative days, fixed window, or from first use | Consumable (price tier) | `com.chengyinhub.chengyinApp.bundle.cny<price>` | Data-driven (`MarketingProduct.cashPrice`) |
| D6 | 限时通票 / 定期通票 · Time-limited / fixed-term pass | same as D5 | same · `KIND_TIME_LIMITED_PASS = 3`, `KIND_FIXED_TERM_PASS = 4` | A topic set for `validDays` or the window `fixedValidFrom`–`fixedValidTo` | Non-renewing subscription | `com.chengyinhub.chengyinApp.termpass.cny<price>` | Data-driven |
| D7 | 礼品通票 / Gift pass | `market/pass` gift sheet; claimed in `market/gift` | same, `FULFILLMENT_GIFT` · `KIND_GIFT_PASS = 7` | A claim token for one recipient, valid `giftClaimDays` | Consumable (gifting is allowed under 3.1.1; only the buyer can be refunded) | `com.chengyinhub.chengyinApp.gift.cny<price>` | Data-driven |
| D8 | 加座 / Extra seat | `pages/topic/index` | same, `FULFILLMENT_EXTRA_SEAT` · `KIND_EXTRA_SEAT = 8` | One more seat on an already-paid order | Consumable | `com.chengyinhub.chengyinApp.seat.extra.cny<price>` | Data-driven (needs `parentProductId`) |
| D9 | 玩法模板付费版 / Workshop paid template | not sold in the MP | `/api/workshop/v2/apple-iap` · `WORKSHOP_TEMPLATE` | Permanent install of one template version | Non-consumable | from table `workshop_apple_product` (no default SKUs; `migration_z_workshop_paid_review_20261109.sql:36-50`) | Per version (`price_fen`). **The Apple path is already built** on the server (`appleiap/WorkshopAppleIapService.java`) and in the app (`Core/WorkshopStoreKitLauncher.swift`, gated on a reviewed approval list that ships empty). |

### Why price tiers, not one SKU per topic

D3–D8 prices are set per item by admins and creators, and Apple products must exist before sale. The proposal is a small ladder of consumable SKUs per family (`…selfplay.cny<price>` etc.), one per Apple CNY price point in use. The server picks the SKU for an order's price, passes the order number as `appAccountToken`, and grants the entitlement after verifying the signed transaction, the same shape as XPAY's price → goods-id map. To size the ladder, the owner (or ops) can list prices in use with a read-only query such as `SELECT DISTINCT self_play_price FROM cms_topic WHERE self_play = 1 AND del_flag = '0'` and `SELECT DISTINCT cash_price, kind FROM marketing_product WHERE status = 1`.

## 2. Paid things that are not IAP (stay on WeChat Pay / existing flow)

| Thing | Endpoint · kind | Why not IAP |
|---|---|---|
| 有人带票 / Guided ticket (`PurchaseKind.GUIDED_TICKET = 1`) | `/api/registration/create` + `/pay` · `TOPIC_TICKET` | Staff-led session in the physical world (3.1.3(e)) |
| 活动报名 / Activity or event ticket (`pages/activity/baoming`) | same · `ACTIVITY_TICKET` | Attendance at a real-world event (3.1.3(e)) |
| 团体 / 学校团 · Group team, school group (`KIND_GROUP_TEAM = 5`, `KIND_SCHOOL_GROUP = 6`) | sent to registration checkout with an `oms_ticket` (`MarketingProductPurchaseServiceImpl.java:124-131`) | Seats on a real-world ticket, if that ticket is guided or on-site |
| 俱乐部会费 / Club dues | `/api/club/membership/renew` · `CLUB_DUES` (no MP call site today) | Membership of a real-world club; see open question Q5 |
| 商家权益 / Merchant premium template, promotion slot, custom event | `/api/merchant/commerce/order` · `MERCHANT_PURCHASE` (self-checkout off by default) | Business purchase; hidden from the player Release (merchant center off) |
| 协作保证金 / Co-op deposit | `/api/coop/deposit/create` · `COOP_DEPOSIT` | Refundable deposit between businesses |
| 视频悬赏、推荐奖励 / Video and referral bounties | payouts | Money goes to the user; nothing is sold |
| 积分、积分礼品 / Points, points gifts | `PAY_MODE_POINTS` | No money changes hands |

## 3. Open questions for the owner (decide before turning virtual goods on)

1. **Self-play is played on foot but unlocked and played in the app.** Recommended: IAP (D3–D8). WeChat already routes platform-owned self-play through its virtual-goods payment, which points the same way.
2. **Topics owned by merchants or clubs** still use JSAPI and may settle to the seller's WeChat sub-merchant (`SellerOfRecordPolicy`). On iOS they would also need IAP, so the platform collects through Apple and settles to the seller itself.
3. **Explore pass (`PurchaseKind.EXPLORE_PASS = 3`)** mixes a digital game with merchant perks. If the money is mainly for the game, it is IAP; if mainly for the perks, it is not.
4. **Redeem codes (`/api/channel/redeem`)** unlock self-play with codes sold outside the app. Guideline 3.1.1 allows that only when the same content is also sold as IAP (3.1.3(b)). Platform-issued codes could become Apple Offer Codes.
5. **Club dues** include a self-play discount, which is a digital perk. Main value is the real-world club; not sold in the MP today.
6. **Platform pass refunds**: the server refunds only if nothing was claimed. Apple refunds on its own terms; the App Store Server Notification `REFUND` would need to revoke the pass period.
7. **Pricing**: Apple CNY price points will not match ¥299, ¥39 or the .90 seat prices exactly. Decide whether the iOS price rounds to the nearest point or the MP prices move.

## 4. When the owner says go (not in this lane)

1. Create D1/D2 (and any chosen D3–D8 tiers) in App Store Connect > the app > Monetization; add them to `Config/QuestifySandbox.storekit` for local testing.
2. Server: an Apple verification + `appAccountToken` path for registration, marketing product and platform pass orders (the workshop path is the template).
3. App: flip `.virtualGoods` in the reviewed release composition only after 1 and 2 pass a sandbox purchase, refund and restore.
