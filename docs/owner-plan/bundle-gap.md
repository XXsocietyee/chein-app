# Bundle domain gap — plan v12 `EP-BND-01..24` and `T-01..T-17`

Docs-only. Source files, branches and the plan text were treated as **data**. Nothing was compiled or run; "EXISTS" means I read the code path, not that tests pass.

## Provenance

| Thing | Ref |
|---|---|
| iOS | `chengyin-app` `origin/wip/gm-next` (branch `cloud/bnd-1`) |
| Backend (primary) | `hengyin` `origin/feature/three-selected-policies-20261106` @ `4ac8c249` |
| Backend (parked, superset) | `hengyin` `origin/feature/cy26-f3-bundle-refund-parked` (merge-base `b6b85e2e`; **diverged** — a plain diff is 4.7k files, only the bundle files are relevant) |
| Plan | `docs/owner-plan/questify-plan-v12.txt` — route anchors L1181–1300, N003/N004 text L353–550 |

Backend paths below are relative to `hengyin/`. `CTL` = `chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/ApiFreeExploreBundleController.java` (**byte-identical on both branches**). `SVC` = `chengyinhub-system/src/main/java/com/chengyinhub/business/service/impl/FreeExploreBundleServiceImpl.java` (line numbers = primary branch).

What the parked branch adds over primary (relevant to the spec): `ExploreBundleRefundHold` domain + `ExploreBundleRefundMapper` + `IFreeExploreBundleRefundService` (**internal, "No HTTP endpoint and no provider invocation"**), SQL `chengyinhub-admin/sql/migration_doc2_f3_refund_hold_20261026.sql` (`explore_bundle_refund_hold`), unit status `REFUND_PENDING` + error `BUNDLE_REFUND_PENDING`, `orderView.bundle.refundHold` and `.fulfilledMerchants`, `catalog…stores[].available`, ids emitted via `exactId(...)` (string-safe), receipt `outcome:"UNKNOWN"`, partial-refund test `remaining > total × 0.20`. Tests `FreeExploreBundleRefundContractTest`, `FreeExploreBundleWireTest` exist only there. Everything marked "parked" below is **not** on the primary branch.

## Honest caveat on the EP-BND numbering

The plan says (L1181): "API代号来自规格，仅为对接坐标，不表示接口已实现" — the codes are coordinates only. The plan text **does not define EP-BND-01..24 one by one**; it only binds some codes to T-routes (table L1187–1300). Meaning below is inferred from the route binding. **EP-BND-07, 08, 11, 18 are bound to no route** (they are never named anywhere in the plan) — their semantics are UNDEFINED; I mark them MISSING-BOTH and ask the owner to define them (see spec §Open questions). `EP-RFD-*`, `EP-CMP-*`, `EP-PRD-*`, `EP-VRF-*`, `EP-ADM-*` appear on the T-rows but are other domains; only their bundle-facing slice is assessed.

## Wire envelope (all bundle endpoints)

Backend `run()` (`CTL:130-138`): success → `AjaxResult` `{ "code":200, "msg":"…", "data": <payload> }`. Business refusal → HTTP 200-class body `{ "code":409, "msg":"<中文>", "businessCode":"BUNDLE_…" }`. `ServiceException` → `{code:<e.code|409>, msg}`. Login failure is **business 409 + `LOGIN_REQUIRED`** (`CTL:145-155`), not 401 — iOS already special-cases this (`App/FreeExploreBundleReservationTransport.swift:79-83`). Timestamps in domain objects serialise as `"yyyy-MM-dd HH:mm:ss"` strings (`@JsonFormat`); request `startAt` and merchant `from/to` are epoch **ms**; map-built views mix epoch ms (`quote.asOf`, `contract.validEnd`) and raw `Date` (`stores[].validEnd`, `grant.validFrom/validTo`).

## 1. EP-BND-01..24

Legend: **B** = backend, **I** = iOS. Status = `EXISTS-IN-BACKEND` / `EXISTS-IN-IOS` / `MISSING-BOTH`; where both sides have code the row says `EXISTS-IN-BACKEND + EXISTS-IN-IOS`. "(partial)" = exists but does not cover the whole coordinate.

| EP | Inferred meaning (plan route) | Status | Backend proof | iOS proof / gate |
|---|---|---|---|---|
| 01 | Shelf (T-01 `/bundle`) | **B + I (partial)** | `GET /catalog?topicId` `CTL:44` → `SVC:296`. Per-topic only; **no cross-topic shelf list** | `Core/FreeExploreLaunchService.swift:63` `catalog`; rendered `App/FreeExploreBundleLaunchView.swift:28-37`. Reachable only after an order binds the topic (`App/FreeExploreBundleReadHost.swift:95,154`) — no shelf entry point |
| 02 | Bundle detail (T-02) | **B + I (partial)** | same `catalog`: items, `termsMode`, `unitsPerHolder`, `policy`, `saleEnabled`, `reservationEnabled`. **No compliance text / merchant qualification / price** in the view | same as 01; no detail screen |
| 03 | Merchant stall detail: goods + slots + "why unavailable" (T-03) | **MISSING-BOTH** | catalog `stores[]` = `{offerId, merchantName, validEnd}` only (parked adds `available`); no slots/capacity/reason | none |
| 04 | Wallet: quota + voucher entries (T-06 `/wallet`) | **B + I (partial)** | `GET /order?registrationId` `CTL:49` → `SVC:344`: per-registration balances. **No "my bundle orders" list** | `FreeExploreBundleReadHost.load` `App/FreeExploreBundleReadHost.swift:72-99`; entry from order detail `App/ProfileOrdersView.swift:271`, `App/FreeExploreBundleReadEntry.swift:15`. Generic wallet `Core/TicketWalletService.swift:11,17` lists *registrations*, not bundles |
| 05 | Checkout (T-04) | **B + I (partial; payment MISSING)** | No checkout in the bundle controller. Order is created by the **existing** `/api/registration/create`; bundle hook `freezeOnOrderCreated` `SVC:72` freezes 5 versions in the same tx. No bundle-specific compliance-consent endpoint; no payment route | `Core/RegistrationProduction.swift:19` (`api/registration/quote`,`create`, `api/compliance/consents/latest`) — generic, approval-gated. No StoreKit bundle purchase (`Core/WorkshopStoreKitLauncher.swift` is workshop-only) |
| 06 | Pay result / activation (T-05) | **B + I (partial)** | `GET /order` `CTL:49`; `GET /order/receipt?requestId` `CTL:55` → `SVC:372` (`FOUND`/`NOT_FOUND`; `AMBIGUOUS` refused; parked adds `outcome:"UNKNOWN"`) | `order` read `Core/FreeExploreLaunchService.swift:70`. **`order/receipt` is not called** and is not in the read allow-list (`App/FreeExploreBundleReadHost.swift:148-154`) |
| 07 | UNDEFINED (no route) | **MISSING-BOTH** | — | — |
| 08 | UNDEFINED (no route) | **MISSING-BOTH** | — | — |
| 09 | Voucher detail, main/sub codes (T-07) | **MISSING-BOTH** | Per-unit `unitCode` is inside `order.bundle.units[]` but there is no member voucher/token endpoint | none |
| 10 | Voucher version polling (T-07) | **MISSING-BOTH** | `ExploreBundleUnit.version` exists per unit but no "version only" read | none |
| 11 | UNDEFINED (no route) | **MISSING-BOTH** | — | — |
| 12 | Reserve a slot (T-09) | **B + I** | `POST /reservation` `CTL:65` → `SVC:425`; idempotent on `(holder, idempotencyKey)` with fingerprint (`BUNDLE_IDEMPOTENCY_CONFLICT`); `GET /reservation/receipt` `CTL:81` → `SVC:405`. Gated by `chengyin.free-explore.bundle.reservation-enabled` (default false) | `Core/FreeExploreLaunchService.swift:84` `reserve`, `:78` `receipt`; `Core/FreeExploreLaunchCoordinator.swift`; `App/FreeExploreBundleReservationTransport.swift:70`; model `App/FreeExploreBundleLaunchModel.swift:65-84`. **Dispatch OFF**: `permitsReservationDispatch` default false (`Core/FreeExploreLaunchService.swift:38-41`) |
| 13 | My reservations (T-10) | **B + I** | inside `orderView.bundle.reservations` (`SVC:364`); merchant side `GET /merchant/reservations?from&to` `CTL:118` → `SVC:412` (≤31 days, VERIFY permission) | `FreeExploreLaunchOrder.Bundle.reservations` `Core/FreeExploreLaunchContracts.swift:105`; list `App/FreeExploreBundleLaunchView.swift:48-52`. No cross-order "my reservations" list; no merchant iOS client |
| 14 | Cancel quote (T-11) | **B + I (partial, gated stub)** | `GET /reservation/{id}/cancel-quote?useWaiver` `CTL:86` → `SVC:472` | Protocol `Core/FreeExploreCancelFlow.swift:39-41`, gated stub `:44-47` (returns `.unavailable`); seam `App/FreeExploreCancelFactory.swift:8`. **No HTTP transport implements it**; `Core/FreeExploreLaunchService.swift:97` throws `cancellationQuoteUnavailable` (comment there says "frozen controller has no cancel-quote" — **stale: the controller now has it**) |
| 15 | Cancel confirm (T-11) | **B + I (partial, gated stub)** | `POST /reservation/{id}/cancel` body `{useWaiver, expectedOutcome}` `CTL:97` → `SVC:513` | same stub `Core/FreeExploreCancelFlow.swift:41,47`; model `:61-106` |
| 16 | Waiver suggestion (T-11) | **B + I (partial)** | `useWaiver` flag + `quote.waiverMonth` + `409 BUNDLE_WAIVER_USED` (`SVC:533`). **No "waiver already used this month?" read** — client cannot suggest a waiver ahead of time | `useWaiver` carried by `FreeExploreCancelFlow` only |
| 17 | Redeem result (T-08) | **MISSING-BOTH** | Redeem is the **existing** merchant scan `api/registration/scan_qr_code_chapter`; bundle hooks `SVC:214 onChapterRedeemed`, `:272 onRedemptionReversed`. No member-facing result readback | Merchant scan transport only: `Core/OrderPassContracts.swift:64`, `Core/MerchantVerificationHTTPTransport.swift:9-11`. No member result screen |
| 18 | UNDEFINED (no route) | **MISSING-BOTH** | — | — |
| 19 | Voucher appeal — merchant forgot to scan (T-12) | **MISSING-BOTH** | none (only `POST /merchant/reservation/{id}/no-show` `CTL:125` — merchant forfeits a unit, opposite direction) | none |
| 20 | Submit review (T-13) | **MISSING-BOTH** | none | none |
| 21 | Merchant reply to review (T-55) | **MISSING-BOTH** | none | none |
| 22 | List reviews (T-13) | **MISSING-BOTH** | none | none |
| 23 | Renewal intent (T-14) | **MISSING-BOTH** | none | none (`Core/RegistrationWaitlist.swift` "renewal" hit is unrelated) |
| 24 | Transfer (T-15) | **MISSING-BOTH** | none | none |

**Tally EP-BND (24):** EXISTS-IN-BACKEND **10** (4 full: 12,13,14,15; 6 partial: 01,02,04,05,06,16) · EXISTS-IN-IOS **10** (same ten; only 12,13 exercise a real read/write client, 12 is dispatch-gated, 14/15 are gated stubs with no transport) · backend-only 0 · iOS-only 0 · MISSING-BOTH **14** (03,07,08,09,10,11,17,18,19,20,21,22,23,24; of which 07/08/11/18 are undefined-in-plan).

## 2. Existing backend endpoints not anchored by any EP-BND

| Endpoint | Backend | iOS | Note |
|---|---|---|---|
| `GET /order/refund-quote?registrationId` | `CTL:60` → `SVC:396` | `Core/FreeExploreLaunchService.swift:74` `refundQuote`; gate `App/FreeExploreBundleLaunchModel.swift:140` | Plan binds refund to `EP-RFD-01..06` (T-16/17). Read-only quote; no HTTP refund request exists |
| `GET /exit-options?registrationId&unitId` | `CTL:92` → `SVC:642` | none | merchant-exit disposition |
| `POST /exit-decision` | `CTL:104` → `SVC:571` | none | `SWAP_CONSENTED` / `REFUND_UNFULFILLED` |
| `POST /merchant/reservation/{id}/no-show` | `CTL:125` → `SVC:548` | none | merchant, VERIFY perm |

## 3. T-01..T-17

| T | Anchor | Status | Evidence / what is missing |
|---|---|---|---|
| T-01 | Shelf | **B + I (partial)** | EP-01. Missing: cross-topic shelf list, iOS entry |
| T-02 | Detail (merchants/goods/policy/compliance) | **B + I (partial)** | EP-02. Missing: compliance copy, price/merchant qualification fields, iOS screen |
| T-03 | Merchant stall (goods + slots + unavailable reason) | **MISSING-BOTH** | EP-03 |
| T-04 | Checkout (compliance + agreement) | **B + I (partial)** | order-create via generic registration path exists both sides; **bundle-specific consent + any payment: MISSING** (payment decision) |
| T-05 | Pay / activation result | **B + I (partial)** | `order` + `order/receipt` backend; iOS reads `order` only, no receipt/poll UI |
| T-06 | Wallet | **B + I (partial)** | read-only per order via `ProfileOrdersView` entry; no wallet list |
| T-07 | Voucher detail (main+sub codes, version poll) | **MISSING-BOTH** | EP-09/10 |
| T-08 | Redeem result (success / review / reject) | **MISSING-BOTH** | EP-17 (+EP-VRF-04) |
| T-09 | Reserve slot (14-day calendar) | **B + I (partial)** | reserve API + iOS gated model exist; **no calendar/slot-availability API** — iOS uses a free `DatePicker` (`App/FreeExploreBundleLaunchView.swift:70`) |
| T-10 | My reservations | **B + I** | per-order list only |
| T-11 | Cancel quote / confirm (+ waiver) | **B + I (partial)** | backend full; iOS stubs gated, no transport |
| T-12 | Voucher appeal | **MISSING-BOTH** | EP-19 (+EP-ADM-09) |
| T-13 | Review submit + list | **MISSING-BOTH** | EP-20/22 |
| T-14 | Renewal intent | **MISSING-BOTH** | EP-23 |
| T-15 | Transfer | **MISSING-BOTH** | EP-24; also needs access-check change (spec §B-24) |
| T-16 | Refund quote / apply (unit select) | **B + I (partial)** | quote on both sides; **apply: MISSING** (parked branch: internal Java API only, no HTTP). Money movement blocked on payment decision |
| T-17 | Refund progress | **MISSING-BOTH** | EP-RFD-05/06; parked `explore_bundle_refund_hold.state` + `orderView.bundle.refundHold` is the only read surface and it exists only on the parked branch |

**Tally T (17):** B+I (at least partial) **9** (T-01,02,04,05,06,09,10,11,16) · fully done 0 · MISSING-BOTH **8** (T-03,07,08,12,13,14,15,17).

## 4. Exact JSON the backend returns today

`data` payloads (primary branch; parked deltas in *italics*). Ids are JSON numbers on primary; *parked emits many as strings via `exactId`* — iOS `FreeExploreLaunchID` (`Core/FreeExploreLaunchContracts.swift:11-30`) accepts both.

### `GET /catalog?topicId=` (`SVC:296-342`)
```json
{ "topicId": 101, "topicName": "…", "productType": 2,
  "items": [ { "chapterId": 11, "name": "…", "termsMode": "…", "unitsPerHolder": 1,
               "stores": [ { "offerId": 7, "merchantName": "…", "validEnd": "<Date>" /* parked: + "available": true */ } ] } ],
  "policy": { "version": "F3P1-20261022", "freeCancelHours": 12, "partialRefundMinRatio": 0.20, "monthlyVoluntaryWaivers": 1 },
  "saleEnabled": false, "reservationEnabled": false }
```
Errors: `BUNDLE_NOT_FOUND`, `BUNDLE_NOT_FREE_EXPLORE`, `BUNDLE_NOT_ON_SALE`. (`UNITS_PER_CHAPTER` constant; iOS validates `productType==2` and unique ids, `FreeExploreLaunchService.swift:65-67`.)

### `GET /order?registrationId=` (`SVC:344-368`) — owner = `cms_registration.member_id` **and** order holder
```json
{ "registrationId": 9001, "registrationNo": "…", "parentOrderNo": "…",
  "paymentStatus": 2, "registrationStatus": 2,
  "bundle": null }                      // legacy (non-bundle) order → bundle:null
```
```json
{ …, "bundle": {
    "order": { "id":1,"registrationId":9001,"holderMemberId":5,"topicId":101,"activityId":null,
               "productVersion":"<sha256>","quotaVersion":"<sha256>","policyVersion":"F3P1-20261022",
               "contractVersion":"<sha256>","settlementRuleVersion":"…","snapshotJson":"{…product,quota,contract,policy…}",
               "paidAmount":199.00,"validFrom":"yyyy-MM-dd HH:mm:ss","validTo":"…","idempotencyKey":"bundle-order:9001",
               "requestFingerprint":"<sha256>","createTime":"…" },
    "balances": [ { "grantId":1,"holderMemberId":5,"chapterId":11,"grantNo":1,"grantType":"PURCHASE",
                    "unitsTotal":1,"counts":{"AVAILABLE":1,"RESERVED":0,"REDEEMED":0,"FORFEITED":0,"HELD":0,"REFUND_PENDING":0,"REFUNDED":0},
                    "validFrom":"<Date>","validTo":"<Date>","expired":false } ],
    "units": [ { "id":21,"grantId":1,"registrationId":9001,"holderMemberId":5,"chapterId":11,"unitSeq":1,
                 "unitCode":"…","unitValue":49.75,"status":"AVAILABLE","redemptionId":null,"reservationId":null,
                 "statusReason":null,"version":0,"createTime":"…","updateTime":"…","grantNo":1,"validFrom":"…","validTo":"…" } ],
    "reservations": [ <Reservation> ],
    "exitCases":   [ <ExitCase> ],
    "policy": { "version":"F3P1-20261022","freeCancelHours":12,"partialRefundMinRatio":0.20,"monthlyVoluntaryWaivers":1 }
    /* parked adds: "refundHold": <RefundHold|null>, "fulfilledMerchants":[{"merchantId","registrationId","holderMemberId"}] */ } }
```
`Unit.status` ∈ `AVAILABLE|RESERVED|REDEEMED|FORFEITED|HELD|REFUND_PENDING|REFUNDED` (DDL comment; `REFUND_PENDING` only written by the parked refund service). iOS decodes only `id, registrationId, holderMemberId, chapterId, status` per unit (`Core/FreeExploreLaunchContracts.swift:96-101`) — so **unitCode/validity/value are not available to iOS screens yet**.

### `GET /order/receipt?requestId=` (`SVC:372-393`)
```json
{ "requestId":"<trimmed>", "receipt":"NOT_FOUND" }
{ "requestId":"<trimmed>", "receipt":"FOUND", "order": <order view above> }
```
(parked also `"outcome":"UNKNOWN"` on NOT_FOUND — a negative read is not proof of non-write.) Errors `BUNDLE_BAD_REQUEST`, `BUNDLE_RECEIPT_AMBIGUOUS`.

### `GET /order/refund-quote?registrationId=` — `FreeExploreBundlePolicy.RefundQuote` (getters only)
```json
{ "route":"ORIGINAL_METHOD|PLATFORM_BALANCE|NOT_REFUNDABLE", "amount":199.00, "totalValue":199.00,
  "remainingValue":199.00, "remainingRatio":1.00, "afterSalesForMerchantBreach":false,
  "reason":"完全未使用,原路全额退回", "policyVersion":"F3P1-20261022" }
```
Rules (`FreeExploreBundlePolicy.java:65-101`): all unused → `ORIGINAL_METHOD`; partly used and remaining value ratio > 0.20 → `PLATFORM_BALANCE`; else `NOT_REFUNDABLE` (merchant-breach goes to after-sales). Read-only; **moves no money**.

### `POST /reservation`  (`CTL:157-175`, `SVC:425`)
Request `{ "registrationId":9001, "unitId":21, "offerId":7, "startAt":1767225600000, "idempotencyKey":"<client key>" }`. Response `<Reservation>`:
```json
{ "id":31,"unitId":21,"registrationId":9001,"holderMemberId":5,"chapterId":11,"offerId":7,"merchantId":3,
  "startAt":"yyyy-MM-dd HH:mm:ss","status":"BOOKED","idempotencyKey":"…","requestFingerprint":"<sha256>",
  "closedAt":null,"version":0,"createTime":"…","updateTime":"…" }
```
`Reservation.status` ∈ `BOOKED|CANCELLED|WAIVED|LATE_CANCELLED|NO_SHOW|FULFILLED|MERCHANT_EXITED`. Errors: `BUNDLE_BAD_REQUEST`, `BUNDLE_NOT_FOUND`, `BUNDLE_UNIT_UNAVAILABLE`, `BUNDLE_EXPIRED`, `BUNDLE_STORE_UNAVAILABLE`, `BUNDLE_CONCURRENT`, `BUNDLE_IDEMPOTENCY_CONFLICT`, `BUNDLE_LEDGER_OFF`, `BUNDLE_RESERVATION_OFF`, `BUNDLE_ORDER_NOT_ACTIVE`. Same-key concurrency: controller retries once on `DuplicateKeyException` (`CTL:73-77`).
`GET /reservation/receipt?idempotencyKey=` → `<Reservation>` or `data:null`.

### `GET /reservation/{id}/cancel-quote?useWaiver=` (`SVC:472-495`)
```json
{ "reservationId":31,"registrationId":9001,"holderMemberId":5,"version":0,"status":"BOOKED","asOf":1767000000000,
  "useWaiver":false,"outcome":"CANCELLED|WAIVED|LATE_CANCELLED","expectedOutcome":"CANCELLED|LATE_CANCELLED|WAIVED:2026-11",
  "canCancel":true,"waiverMonth":"2026-11" }
```
`POST /reservation/{id}/cancel` body `{ "useWaiver":false, "expectedOutcome":"…" }` (both optional; **omitting expectedOutcome skips the reconfirm guard**, `CTL:99-101`) → `<Reservation>`. Errors `BUNDLE_CANCEL_QUOTE_CHANGED`, `BUNDLE_WAIVER_USED`, `BUNDLE_NOT_FOUND`. Free cancel boundary: ≥12h before start, Asia/Shanghai.

### `GET /exit-options?registrationId&unitId` (`SVC:642-684`)
```json
{ "registrationId":9001,"unitId":21,"holderMemberId":5,"merchantExited":true,
  "targets":[{"offerId":8,"merchantName":"…","validEnd":"<Date>"}], "refundSubmissionAvailable":false }
```
`POST /exit-decision` `{ "unitId":21,"decision":"SWAP_CONSENTED|REFUND_UNFULFILLED","targetOfferId":8,"idempotencyKey":"…" }` → `<ExitCase>`:
```json
{ "id":1,"unitId":21,"registrationId":9001,"holderMemberId":5,"exitedOfferId":7,"reservationId":null,
  "decision":"SWAP_CONSENTED","targetOfferId":8,"idempotencyKey":"…","requestFingerprint":"<sha256>","createTime":"…" }
```
Errors `BUNDLE_MERCHANT_NOT_EXITED`, `BUNDLE_SWAP_SHORTENS_VALIDITY`, `BUNDLE_UNIT_UNAVAILABLE`, `BUNDLE_CONCURRENT`.

### Merchant
`GET /merchant/reservations?from=<ms>&to=<ms>` → `[<Reservation>]` (permission `MerchantPermission.VERIFY`; >31 days → `BUNDLE_BAD_REQUEST`). `POST /merchant/reservation/{id}/no-show` → `<Reservation>` (`NO_SHOW`; only after start; consumes that unit; not a redemption, no accrual/commission). Errors `BUNDLE_RESERVATION_CLOSED`, `BUNDLE_TOO_EARLY`.

### Tables (`chengyinhub-admin/sql/migration_doc2_f3_bundle_ledger_20261022.sql`, identical on both branches)
`explore_bundle_order` (uk registration, uk idempotency_key) · `explore_bundle_grant` (uk registration,holder,chapter,grant_no; `grant_type PURCHASE|SWAP`) · `explore_bundle_unit` (uk grant,unit_seq; uk unit_code; uk redemption_id) · `explore_bundle_reservation` (uk holder,idempotency_key; uk generated `active_unit_key` = unit_id while `BOOKED`) · `explore_bundle_waiver` (uk member,waiver_month; uk reservation_id) · `explore_bundle_exit_case` (uk unit,exited_offer; uk holder,idempotency_key). Parked: `explore_bundle_refund_hold` (PK registration_id; `refund_id`,`refund_no`,`cash_amount`,`state`,`version`). Gates: `chengyin.free-explore.bundle.{ledger,sale,reservation}-enabled`, all default false (`FreeExploreBundleSwitches.java:26-38`).

### Existing tests (do not duplicate)
`FreeExploreBundleServiceTest` (21 cases: switches-off no-op, freeze/replay, redemption prefers reserved store, 12h boundary, waiver per Shanghai month, no-show, exit swap, refund-quote rules, order-view owner scope, receipt read-back). `FreeExploreBundleLedgerMySqlIT` (guard rejects changed shape, two holders independent balances, unique reservation per unit). Parked only: `FreeExploreBundleRefundContractTest`, `FreeExploreBundleWireTest` (long-id precision on the wire).
