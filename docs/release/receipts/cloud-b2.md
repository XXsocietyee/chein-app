# Cloud B2 — pass and market reads

Rebased onto `origin/ui/next` `ac32c5b4bf1fbd4370fd18b18764b1238f7aaa84`. Branch `ui/cloud-b2-pass` only.

Mini-program reference: `liboyang42-cpu/hengyin` `chengyinhub-xcx` master `1c80c5aea8f721ca8575e6108048495b100f5576`.

`struct MPParityBindings` in `App/MPParityKit.swift` is the only binding type. The duplicate `enum MPParityBindings` is gone. Closures are filled from `App/MPParityPassSession.swift` (AppSession and AppCompositionRoot stay at the scaffold ceiling). `Core/PlatformPass.swift` keeps the readers. Purchase, quote, order, and claim still throw `PlatformPassWriteRefusal.unreachable`, and the read transport refuses those paths.

## Closures

| Closure | Behavior |
|---|---|
| `viewerIsMerchant` | Role `merchant`, or an empty role with `userType == 2`. `debugView == "user"` stays a player. Presentation only. |
| `passStoreCard` | City, period, and year passes with a cash price and covered works. Nil for merchants and when nothing is on sale. |
| `passCheckoutCover` | `platformPassCovered` hides city-pass rows and marks the order covered. Gift and extra-seat products stay out. |
| `orderDetail` | Existing registration order screen, without a lifecycle coordinator, so pay and refund stay off that push. |
| market / detail / gift / membership / library | Read the platform-pass and marketing list endpoints. Detail shows prices as facts. Gift `claim()` does not send. |

Unknown is an em dash (`—`). A server 0 stays 0. Missing points stay nil.

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

`purchase`, `quote`, `order`, and `claim` return `throws -> Never`. They do not build a payment body and do not call the transport. Paths they refuse: `api/platform-pass/orders`, `api/marketing/product/quote`, `api/marketing/product/order`, `api/marketing/product/gifts/claim`.

`PlatformPass.moneyEnabled` and `MPParityBindings.moneyEnabled` are false. `ReleaseMoneyWriteSwitch` payment, payout, withdrawal, and virtual goods are unchanged and off. `writesReachable` is false. `MPCommerceGate` purchases, claims, and payout stay false.

## Tests

- `Tests/CoreTests/PlatformPassReadTests.swift` — the six reads, merchant skip, string code `200`, nil count, zero points, China clock.
- `Tests/CoreTests/PlatformPassPurchaseUnreachableTests.swift` — purchase, quote, order, and claim throw, the transport stays on the one overview GET, money stays off.
- `Tests/AppUnitTests/MPParityPassBindingTests.swift` — the filled closures' facts, the read-only transport, and a source scan that the session file does not call the write methods.
