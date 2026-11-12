# Cloud B2 — pass and market reads

Base `origin/ui/main` `72d2eb9ec498de21ded7cf9215f2638d7195786f`. Branch `ui/cloud-b2-pass` only.

Mini-program reference: `liboyang42-cpu/hengyin` `chengyinhub-xcx` master `1c80c5aea8f721ca8575e6108048495b100f5576`.

## Bindings (`Core/MPParityBindings.swift`)

| Binding | Mini-program | Behavior |
|---|---|---|
| `viewerIsMerchant` | `utils/identity/identity-policy.js` `isMerchantView` | Role `merchant`, or empty role with `userType == 2`. `debugView == "user"` stays a player. |
| `passStoreCard` | `subpackageMember/market/passes` `loadMember` | Hidden for merchants and when overview `enabled` is not true. Side text is the coverage date, else plan prices, else library count. `purchaseReachable` is false. |
| `passCheckoutCover` | `pages/topic/utils/checkout-view.js` | `platformPassCovered` with pay ≤ 0 is ¥0, bill line 通行证, label 免费领取, covering passes hidden. `purchaseReachable` is false. |
| `orderDetail` | `cy-scene-member-order-detail` `id="orderDetail"` | Self-play pass (`purchaseKind == 2`, or topic order with no ticket and an expiry), until text, actual paid (0 stays 0). Pay and refund are false. |

## Reads (`Core/PlatformPass.swift`)

| Read | Request |
|---|---|
| overview | `GET /api/platform-pass` (merchant returns before the request) |
| library | `GET /api/platform-pass/library?limit=100` plus `productType` for city/free |
| product list | `GET /api/marketing/product/list?limit=20` |
| orders | `GET /api/marketing/product/orders?limit=20` |
| gifts | `GET /api/marketing/product/gifts/bought` and `.../received` |
| points | `POST /api/user/info`, field `point` (missing stays nil, 0 stays 0) |

## Writes

`purchase`, `quote`, `order`, and `claim` are compiled and return `throws -> Never` with `PlatformPassWriteRefusal.unreachable`. They do not build a payment body and do not call the transport. Paths they refuse: `api/platform-pass/orders`, `api/marketing/product/quote`, `api/marketing/product/order`, `api/marketing/product/gifts/claim`.

`PlatformPass.moneyEnabled` and `MPParityBindings.moneyEnabled` are false. `ReleaseMoneyWriteSwitch` payment, payout, withdrawal, and virtual goods are unchanged and off. `writesReachable` is false.

## Tests

- `Tests/CoreTests/PlatformPassReadTests.swift` — the six reads, merchant skip, string code `200`, nil count, zero points, and the four bindings.
- `Tests/CoreTests/PlatformPassPurchaseUnreachableTests.swift` — purchase, quote, order, and claim throw, the transport stays on the one overview GET, money stays off.

No Swift toolchain on this Linux host, so those XCTest cases were not executed here. `python3 -B tools/check_scaffold.py` passed after `tools/generate_project.py` (project diff is the two new Core sources only).
