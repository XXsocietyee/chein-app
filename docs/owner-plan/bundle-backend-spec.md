# Bundle backend spec — minimal implementable specs for MISSING endpoints

Docs-only. Companion to `bundle-gap.md` (read its provenance + caveat first). Nothing here is implemented, nothing was run, **nothing is to be pushed to the `hengyin` repo from this task** — this is a spec for whoever owns the backend.

## 0. Ground rules (all new endpoints)

1. **Same controller family and envelope.** New routes live under `/api/free-explore/bundle` (member) and `/api/free-explore/bundle/merchant` (merchant). Reuse `ApiFreeExploreBundleController.run()` semantics: success `{code:200,data}`, refusal `{code:409,msg,businessCode}`; login failure = `LOGIN_REQUIRED`. Extend `FreeExploreBundleException` codes; do not invent a new error type.
2. **Additive SQL only.** New tables / nullable columns / new indexes. No `DROP`, no `MODIFY` of existing columns, no rewrite of `explore_bundle_*` rows. Migration files named `migration_doc2_f3_<topic>_<yyyymmdd>.sql`, each with the same temp-table guard idiom as `migration_doc2_f3_bundle_ledger_20261022.sql` (`doc2_f3_bundle_guard`), idempotent via `CREATE TABLE IF NOT EXISTS`. **Never run on production**; scratch-schema IT only (existing `FreeExploreBundleLedgerMySqlIT.createScratchSchema` pattern).
3. **Gating.** Every new write hook sits behind a new default-OFF property in `FreeExploreBundleSwitches` (`chengyin.free-explore.bundle.<feature>-enabled`), plus the existing `ledger-enabled`. With all off, behaviour is byte-identical to today.
4. **Idempotency.** All writes take `idempotencyKey` (≤96 chars, trimmed, non-blank, else `BUNDLE_BAD_REQUEST`), unique `(holder_member_id, idempotency_key)`, store `request_fingerprint` = SHA-256 of canonical fields (same helper as reservation at `FreeExploreBundleServiceImpl.java:~820-838`). Same key + same fingerprint → replay original row; same key + different fingerprint → `BUNDLE_IDEMPOTENCY_CONFLICT`. Controller wraps with the existing one-shot `DuplicateKeyException` retry (`CTL:73-77`). Every write has a `…/receipt?idempotencyKey=` GET that returns the row or `data:null` (client uses it after UNKNOWN). A negative receipt is **not** proof of non-write (parked branch rule).
5. **Ownership.** Existing check `requireOwnRegistration` compares `cms_registration.member_id` (the payer) and `requireOwnOrder` compares `explore_bundle_order.holder_member_id` (`SVC:757-773`). Not-yours and not-found must stay indistinguishable (`BUNDLE_NOT_FOUND`) to block id enumeration.
6. **Ids on the wire as strings** for new endpoints (parked `exactId` convention) — JS/Swift `Double` precision.
7. **No money movement** in anything marked BUILD-NOW. Anything that calls a PSP, creates a refund/payout row, or writes `cms_registration.payment_status` is BLOCKED-PAYMENT.

### Decision matrix (payment = IAP vs WeChat Pay)

| EP | Endpoint | Class |
|---|---|---|
| 01 | shelf list | BUILD-NOW (pure read) |
| 02 | detail (extend catalog) | BUILD-NOW (pure read) |
| 03 | merchant stall detail | BUILD-NOW for offer/unavailable-reason; **slot grid blocked on EP-PRD-04..06 store hours/capacity (not payment)** |
| 04 | wallet list | BUILD-NOW (pure read) |
| 05 | checkout / pay / activation | **BLOCKED-PAYMENT** (order *create* already exists via `/api/registration/create`; the *pay* leg and `payment_status→2` activation callback are the decision) |
| 06 | pay result / activation read | order + receipt reads exist; **iOS-side confirmation of "paid" depends on payment channel** → backend read BUILD-NOW, nothing new needed |
| 09/10 | voucher view + version | BUILD-NOW (pure read) |
| 12–15 | reservation / cancel | EXIST; cancel has **no money** (penalty = unit consumption) → already safe |
| 16 | waiver-used read | BUILD-NOW (pure read) |
| 17 | redeem-result read | BUILD-NOW (pure read) |
| 19 | appeal submit/status/admin decision | BUILD-NOW **record + decision only**; *applying* an approved appeal (consume unit → settlement claim) **BLOCKED on settlement owner**, not on IAP/WeChat |
| 20–22 | reviews | BUILD-NOW |
| 23 | renewal intent | BUILD-NOW (intent only, no price lock, no order) |
| 24 | transfer | BUILD-NOW ledger move; **SMS delivery of the one-time code blocked on SMS provider**; in-app sharing works now |
| RFD-01..04 | refund *request* | request/ledger freeze BUILD-NOW **behind** a switch; the **cash leg** (PSP refund / platform-balance credit / manual payout) **BLOCKED-PAYMENT** |
| RFD-05/06 | refund progress read | BUILD-NOW read of hold state; real states depend on payment channel outcomes |

Why IAP vs WeChat matters: App Store rules for digital goods/entitlements could force IAP (StoreKit; `Core/WorkshopStoreKitLauncher.swift` is the only existing client precedent) and make "refund to original method" an Apple-controlled flow, while WeChat Pay keeps `ORIGINAL_METHOD` refunds in our hands. The policy numbers (12h, 20%, one monthly waiver, original-route vs platform-balance) are payment-neutral and already in `FreeExploreBundlePolicy`; only the **route executor** differs.

---

## B-01 / EP-BND-01 — Shelf list  (BUILD-NOW)

- `GET /api/free-explore/bundle/shelf?cursor=&limit=` — member auth (any logged-in member; no registration needed).
- Response `data`: `{ "items":[{"topicId":"101","topicName":"…","coverUrl":null,"chapterCount":3,"unitsPerHolder":1,"fromPrice":"199.00","validityDays":30}], "nextCursor":null, "saleEnabled":false, "reservationEnabled":false }`.
- Logic: `cms_topic` where `product_type=2`, `del_flag=0`, lifecycle `isDirectSaleOpen()` (same predicate as `catalog` `SVC:~303-310`); order by `id desc`; keyset pagination; `limit` ≤ 50 (default 20). Read only, no locks.
- Schema: none (read-only; price from existing ticket/activity tables, same source `freezeOnOrderCreated` uses).
- Errors: `BUNDLE_BAD_REQUEST` (bad cursor/limit).
- Tests: unit `shelfListsOnlyOnSaleFreeExploreTopics`, `shelfHidesNonFreeExploreAndDeletedTopics`, `shelfPaginatesWithKeysetAndCapsLimit`, `shelfWritesNothingAndTakesNoLock` (mirror `browsingCatalogAcrossCategoriesTakesNoLockAndWritesNothing`). IT: none needed.

## B-02 / EP-BND-02 — Detail  (BUILD-NOW; extend `catalog`)

- Extend existing `GET /catalog` **additively** (new optional keys, old keys unchanged so iOS/mini-program decoders keep working): `compliance:{ "agreementVersion":"…","agreementUrl":"…","declarations":["…"] }`, `merchants:[{ "offerId","merchantName","qualificationSummary" }]`, `price:"199.00"`, `validityDays`.
- Compliance source: existing `api/compliance/consents/latest` data (iOS already calls it, `Core/RegistrationProduction.swift:19`); do **not** copy text into bundle tables.
- Tests: unit `catalogKeepsLegacyKeysUnchanged`, `catalogAddsComplianceFromLatestConsent`; wire test (copy parked `FreeExploreBundleWireTest` pattern) asserting old key set ⊆ new key set.

## B-03 / EP-BND-03 — Merchant stall detail  (BUILD-NOW partial; slot grid BLOCKED on EP-PRD)

- `GET /api/free-explore/bundle/offer/{offerId}?registrationId=&from=<ms>&to=<ms>` — member auth. `registrationId` optional (browse before purchase gives generic reasons).
- Response: `{ "offerId":"7","merchantName":"…","chapterId":"11","termsMode":"…","perHeadFee":"0.00","validEnd":<ms|null>,"live":true,"unavailableReasons":["MERCHANT_EXITED"|"OFFER_EXPIRED"|"NOT_YET_VALID"|"NO_BALANCE"|"RESERVED_ELSEWHERE"|"LEDGER_OFF"|"RESERVATION_OFF"|"OUTSIDE_VALIDITY"], "slots":[{"startAt":<ms>,"remaining":2}] }`.
- `unavailableReasons` derive from the existing predicates `isLive(offer)` (`SVC` helper), `withinValidity(unit,…)`, the `reserve` guards (`BUNDLE_UNIT_UNAVAILABLE`, `BUNDLE_STORE_UNAVAILABLE`, `BUNDLE_EXPIRED`) — **reuse, don't reimplement**; one reason enum per existing `businessCode`.
- `slots`: v1 returns `[]` and `slotsSource:"UNAVAILABLE"` until the store-hours / capacity model (plan `EP-PRD-04..06`, `EP-PRD-10/11`, tasks T-44/T-46) exists. Ledger currently has **no capacity concept** (`uk_bundle_reservation_active_unit` only prevents double-booking one *unit*). Do not add capacity to `explore_bundle_reservation`.
- Tests: unit `offerDetailExplainsEveryUnavailableReason` (table-driven over the 8 reasons), `offerDetailWithoutRegistrationGivesOnlyGenericReasons`, `offerDetailOfOthersRegistrationLooksNotFound`.

## B-04 / EP-BND-04 — Wallet list  (BUILD-NOW)

- `GET /api/free-explore/bundle/wallet?cursor=&limit=` — member auth.
- Response: `{ "orders":[{ "registrationId":"9001","topicId":"101","topicName":"…","validFrom":"…","validTo":"…","expired":false,"paymentStatus":2,"registrationStatus":2,"counts":{"AVAILABLE":1,"RESERVED":0,"REDEEMED":0,"FORFEITED":0,"HELD":0,"REFUND_PENDING":0,"REFUNDED":0},"nextReservation":{"reservationId":"31","startAt":<ms>}|null }], "nextCursor":null }`.
- Logic: `explore_bundle_order where holder_member_id=?` (index `idx_bundle_order_holder (holder_member_id, create_time)` exists) joined to units grouped by status. **Holder-keyed, not payer-keyed** (this is what makes B-24 transfer work).
- Schema: none.
- Tests: unit `walletListsOnlyHoldersOwnOrders`, `walletCountsMatchOrderViewBalances`; IT `walletPaginationStableUnderConcurrentInsert`.

## B-05 / EP-BND-05 — Checkout / pay / activation  (**BLOCKED-PAYMENT**)

What already exists: order creation (`/api/registration/create` → `freezeOnOrderCreated` freezes the 5 versions + issues units in the same tx; `order/receipt` for UNKNOWN). What is missing and **must not be built before the owner decides IAP vs WeChat Pay**:
- the pay leg (PSP prepay / StoreKit transaction verification),
- the activation callback that sets `payment_status=2, registration_status=2` (all bundle writes already require this via `requirePaid`).

What **can** be specced without choosing: the contract between pay and ledger is already the `payment_status/registration_status == 2` pair read by `requirePaid` (`SVC:~775`). Whichever channel is chosen must flip those fields through the **existing** registration payment-fact path (parked branch shows `WechatVerifiedPaymentFact` / `CmsRegistrationPaymentFactMapper` live on the *other* lineage; do not re-create). The bundle-specific bit that is safe now: a **consent receipt** recorded at order create (`explore_bundle_order.snapshot_json` already freezes `contract`/`policy`; add `consent_version` + `consent_at` nullable columns via `ALTER TABLE … ADD COLUMN`, written by `freezeOnOrderCreated` when the client sends the latest consent version). That is BUILD-NOW and payment-neutral.

## B-06 / EP-BND-06 — Pay result / activation read  (BUILD-NOW = nothing new)

`GET /order` + `GET /order/receipt` already return `paymentStatus/registrationStatus`. Spec addition (additive): add `activation:"PENDING_PAYMENT|ACTIVE|EXPIRED|REFUNDED"` computed from those two fields + order validity, so clients stop re-deriving from raw ints. Tests: unit `activationStateDerivedFromPaymentAndValidity` (table). No schema.

## B-09 / B-10 / EP-BND-09, 10 — Voucher view + version poll  (BUILD-NOW)

- `GET /api/free-explore/bundle/voucher?registrationId=` → `{ "registrationId","voucherVersion":"<sha256-16>","main":{"code":"…","validTo":"…"},"subs":[{"unitId","chapterId","unitCode","status","validFrom","validTo","reservationId":null}] }` — holder-keyed.
- `GET /api/free-explore/bundle/voucher/version?registrationId=` → `{ "voucherVersion":"…" }` (cheap; polled by T-07).
- `voucherVersion` = first 16 hex of SHA-256 over sorted `unitId:status:version` of the holder's units (the `explore_bundle_unit.version` column already exists and is bumped on each transition). Poll cadence is a client concern (spec for iOS: ≥5 s, stop when screen hidden).
- **Open question (blocking exact `main.code`)**: how does the existing merchant scan (`api/registration/scan_qr_code_chapter`, `Core/OrderPassContracts.swift:64`) decode the player QR? I did not read that backend code. Rule: `main.code` must be **whatever that scanner already accepts** (the registration's existing QR/dynamic code), not a new token scheme. `subs[].unitCode` is display/support only (`uk_bundle_unit_code`). Do not mint a new redeemable token without the scanner owner.
- Schema: none. Tests: unit `voucherVersionChangesOnlyWhenUnitStatusChanges`, `voucherOfOthersLooksNotFound`, `voucherNeverReturnsRefundedUnitsAsRedeemable`; wire test for string ids.

## B-16 / EP-BND-16 — Waiver status read  (BUILD-NOW)

- `GET /api/free-explore/bundle/waiver?month=yyyy-MM` (default current Shanghai month) → `{ "month":"2026-11","used":false,"usedReservationId":null,"monthlyLimit":1 }` from `explore_bundle_waiver (uk member_id, waiver_month)`.
- Lets T-11 pre-suggest the waiver. The write path still enforces (`BUNDLE_WAIVER_USED`, `SVC:~533`); this read is advisory only.
- Tests: unit `waiverStatusFollowsShanghaiMonth`, `waiverStatusIsMemberScoped`. No schema.

## B-17 / EP-BND-17 — Redeem result read  (BUILD-NOW)

- `GET /api/free-explore/bundle/redemption/result?registrationId=&unitId=` (or `&redemptionId=`) → `{ "outcome":"SUCCESS|REVIEW|REJECTED|NONE","unitId","status":"REDEEMED|…","redemptionId":"…","merchantName":"…","at":<ms>,"reason":null }`.
- Source of truth: unit row (`status`, `redemption_id`) + existing `Redemption` row (`status ACTIVE`). `REVIEW` and `REJECTED` map from the verification-decision domain (`EP-VRF-02/04`); until that exists, return `SUCCESS` or `NONE` only and document `REVIEW/REJECTED` as reserved. Do not synthesise review state from the bundle ledger.
- Tests: unit `redeemResultSuccessAfterOnChapterRedeemed`, `redeemResultNoneBeforeScan`, `redeemResultOfOthersLooksNotFound`.

## B-19 / EP-BND-19 — Voucher appeal (merchant forgot to scan)  (BUILD-NOW record; apply BLOCKED on settlement)

- Member: `POST /api/free-explore/bundle/voucher/appeal` body `{ "registrationId","unitId","reasonCode":"MERCHANT_FORGOT_SCAN|OTHER","note":"≤500 chars","evidenceRefs":["<media-id>"…≤6],"idempotencyKey" }` → `<Appeal>`; `GET /voucher/appeal/receipt?idempotencyKey=`; `GET /voucher/appeal?registrationId=` (list own).
- Eligibility: unit `status in (AVAILABLE,RESERVED)`, order active (`requirePaid`), holder owns unit, within validity, **no open appeal for that unit** (unique active key), reservation (if any) `startAt` already passed.
- Admin (`EP-ADM-09`): `POST /admin/…/bundle/appeal/{id}/decide {decision:"APPROVE|REJECT",reasonText}` on the ruoyi admin side with permission `bundle:appeal:decide`, audit row via existing `BusinessAuditEvent` mechanism. Decision is **insert-only history** (like `exit_case`).
- **Applying APPROVE** = consuming the unit through the same hook as a scan (`onChapterRedeemed` with a redemption id) — that creates a redemption → merchant settlement/commission. **Do not implement the apply in the first slice.** First slice stores `status=APPROVED` and exposes `applyState:"PENDING_SETTLEMENT_DECISION"`. Owner must decide: appeal-approved consumption pays merchant? (this is not IAP/WeChat, it is settlement policy).
- Schema (new):
```sql
CREATE TABLE IF NOT EXISTS explore_bundle_appeal (
  id BIGINT NOT NULL AUTO_INCREMENT,
  registration_id BIGINT NOT NULL, unit_id BIGINT NOT NULL, holder_member_id BIGINT NOT NULL,
  merchant_id BIGINT NULL,
  reason_code VARCHAR(32) NOT NULL, note VARCHAR(500) NULL, evidence_json JSON NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'OPEN' COMMENT 'OPEN/APPROVED/REJECTED/WITHDRAWN',
  active_unit_key BIGINT GENERATED ALWAYS AS (IF(status='OPEN', unit_id, NULL)) STORED,
  idempotency_key VARCHAR(96) NOT NULL, request_fingerprint CHAR(64) NOT NULL,
  decided_by BIGINT NULL, decided_at DATETIME NULL, decision_reason VARCHAR(500) NULL,
  apply_state VARCHAR(32) NOT NULL DEFAULT 'NOT_APPLIED',
  version INT NOT NULL DEFAULT 0,
  create_time DATETIME NOT NULL, update_time DATETIME NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_bundle_appeal_idem (holder_member_id, idempotency_key),
  UNIQUE KEY uk_bundle_appeal_active_unit (active_unit_key),
  KEY idx_bundle_appeal_status (status, create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='F3 套票申诉';
```
- Errors: `BUNDLE_APPEAL_NOT_ELIGIBLE`, `BUNDLE_APPEAL_DUPLICATE`, `BUNDLE_APPEAL_CLOSED`, plus common.
- Tests: unit `appealRequiresPaidOrderAndOwnUnit`, `secondOpenAppealForSameUnitIsRejected`, `appealReplaySameKeyReturnsSameRow`, `appealSameKeyDifferentBodyConflicts`, `approveDoesNotConsumeUnitInFirstSlice`, `decisionHistoryIsInsertOnly`; IT `appealActiveUnitKeyAllowsReappealAfterReject`, `twoThreadsSameKeyCreateOneAppeal`.

## B-20 / B-21 / B-22 / EP-BND-20, 21, 22 — Reviews  (BUILD-NOW)

- Member: `POST /review` `{ "registrationId","rating":1..5,"content":"≤500","idempotencyKey" }` → `<Review>`; `GET /review/list?topicId=&cursor=&limit=` (public to logged-in members, approved only); `GET /review/mine?registrationId=`.
- Merchant (EP-21, T-55): `POST /merchant/review/{id}/reply` `{ "reply":"≤300","idempotencyKey" }` — permission `MerchantPermission.VERIFY` is too narrow for replies; **add a distinct permission** (open question) rather than overload VERIFY. One reply per review; reply allowed only for reviews that reference the merchant's own `merchantId`.
- Eligibility: holder, order active, **≥1 unit `REDEEMED`** (cannot review without using), one review per `(registration_id, holder_member_id)`.
- Moderation: status `PENDING→APPROVED/REJECTED`; text must pass the platform's existing content-review hook (I did not locate it; open question) — **do not ship without it**; default to `PENDING` + not listed.
- Schema:
```sql
CREATE TABLE IF NOT EXISTS explore_bundle_review (
  id BIGINT NOT NULL AUTO_INCREMENT,
  registration_id BIGINT NOT NULL, holder_member_id BIGINT NOT NULL, topic_id BIGINT NOT NULL,
  rating TINYINT NOT NULL, content VARCHAR(500) NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'PENDING' COMMENT 'PENDING/APPROVED/REJECTED/HIDDEN',
  idempotency_key VARCHAR(96) NOT NULL, request_fingerprint CHAR(64) NOT NULL,
  create_time DATETIME NOT NULL, update_time DATETIME NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_bundle_review_order_holder (registration_id, holder_member_id),
  UNIQUE KEY uk_bundle_review_idem (holder_member_id, idempotency_key),
  KEY idx_bundle_review_topic (topic_id, status, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='F3 套票评价';
CREATE TABLE IF NOT EXISTS explore_bundle_review_reply (
  id BIGINT NOT NULL AUTO_INCREMENT,
  review_id BIGINT NOT NULL, merchant_id BIGINT NOT NULL, replier_member_id BIGINT NOT NULL,
  reply VARCHAR(300) NOT NULL, idempotency_key VARCHAR(96) NOT NULL,
  create_time DATETIME NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_bundle_review_reply_review (review_id),
  UNIQUE KEY uk_bundle_review_reply_idem (replier_member_id, idempotency_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='F3 套票评价商家回复';
```
- Errors: `BUNDLE_REVIEW_NOT_ELIGIBLE`, `BUNDLE_REVIEW_DUPLICATE`, `BUNDLE_REPLY_DUPLICATE`, `BUNDLE_REPLY_NOT_YOURS`.
- Tests: unit `reviewRequiresRedeemedUnit`, `oneReviewPerOrderPerHolder`, `pendingReviewNotListed`, `listShowsApprovedOnly`, `replyOnlyByReviewedMerchant`, `secondReplyRejected`, `reviewIdempotentReplayAndConflict`; IT `concurrentSameKeyCreatesOneReview`.

## B-23 / EP-BND-23 — Renewal intent  (BUILD-NOW; intent only)

- `POST /renewal-intent` `{ "registrationId","intent":"WILL_RENEW|MAYBE|NO","note":"≤200","idempotencyKey" }` → `<RenewalIntent>`; `GET /renewal-intent?registrationId=` (latest). Latest-wins per order: new row with `supersedes_id`, insert-only history.
- Explicitly **no price lock, no reservation of a new bundle, no order creation, no notification promise**. Eligibility: holder, order paid, within validity or ≤30 days after `valid_to` (policy constant — owner to confirm).
- Schema:
```sql
CREATE TABLE IF NOT EXISTS explore_bundle_renewal_intent (
  id BIGINT NOT NULL AUTO_INCREMENT,
  registration_id BIGINT NOT NULL, holder_member_id BIGINT NOT NULL, topic_id BIGINT NOT NULL,
  intent VARCHAR(16) NOT NULL, note VARCHAR(200) NULL, supersedes_id BIGINT NULL,
  idempotency_key VARCHAR(96) NOT NULL, request_fingerprint CHAR(64) NOT NULL,
  create_time DATETIME NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_bundle_renewal_idem (holder_member_id, idempotency_key),
  KEY idx_bundle_renewal_order (registration_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='F3 套票续费意向';
```
- Tests: unit `renewalLatestWinsAndHistoryKept`, `renewalRequiresOwnPaidOrder`, `renewalCreatesNoOrderAndNoMoneyRow`; IT `renewalSameKeyConcurrentCreatesOneRow`.

## B-24 / EP-BND-24 — Transfer unused whole bundle  (BUILD-NOW ledger; SMS BLOCKED on provider; **needs access-check change**)

Plan constraints (N004, L49–63): only an **entirely unused** bundle; **atomic move** of usage right, voucher and grant; **payer and contract retained**; no clawback after effective; one-time code must not leak order info; independent from S16 reward coupons and W18 licences; unknown / double-claim / wrong-account / expiry must never lose the original right and must not auto-re-transfer.

- Sender: `POST /transfer` `{ "registrationId","receiverPhone":"<E.164 or CN mobile>","channel":"IN_APP|SMS","idempotencyKey" }` → `<Transfer>` `{ "id","status":"PENDING","expiresAt":<ms>,"claimCode":"<plaintext shown ONCE to sender only>" }`. `GET /transfer/receipt?idempotencyKey=`; `GET /transfer?registrationId=`; `POST /transfer/{id}/revoke` (sender, only while `PENDING`).
- Receiver: `POST /transfer/claim` `{ "code","idempotencyKey" }` → `{ "status":"CLAIMED","registrationId" }`. Code is looked up by hash, never by order id; failure messages identical for wrong/expired/used code (`BUNDLE_TRANSFER_CODE_INVALID`) so nothing about the order leaks.
- Eligibility at create **and re-checked in the claim transaction under `SELECT … FOR UPDATE`** on units (lock order **unit → reservation**, as `lockReservationAfterUnit` documents): all units `AVAILABLE`, none `RESERVED/HELD/REFUND_PENDING/REDEEMED/FORFEITED/REFUNDED`, no `BOOKED` reservation, no refund hold, order within validity, order active, no other `PENDING` transfer for the order, not self-transfer, receiver ≠ blocked/banned (reuse the existing account-status check).
- Claim effect (one tx): `UPDATE explore_bundle_order SET holder_member_id`? — **NO: `explore_bundle_order` is "只插不改" (insert-only snapshot)**. Do not mutate it. Instead the effective holder lives in a new `explore_bundle_holder_assignment` table (current = latest row) and **every reader** (`requireOwnOrder`, `orderView`, wallet, voucher, reserve, cancel, refund-quote) resolves holder via one new helper `effectiveHolder(registrationId)`. `explore_bundle_grant.holder_member_id` / `explore_bundle_unit.holder_member_id` / `explore_bundle_reservation.holder_member_id` are `NOT NULL` and part of unique keys (`uk_bundle_grant_key`, `uk_bundle_reservation_idem`) → a bulk `UPDATE` of those columns is allowed (not DDL) but must be done in the same tx for all units+grants, and bumps `explore_bundle_unit.version` so voucher polling sees it.
- **Access-check change is mandatory.** Today `requireOwnRegistration` demands `cms_registration.member_id == caller` (the payer). After transfer the **payer is retained** (plan) but the **holder** is someone else, so the receiver would get `BUNDLE_NOT_FOUND` on every call and the payer would still see the order. Required: split into `requireHolder(memberId, registrationId)` (use for balance/voucher/reserve/cancel/exit) and `requirePayer(memberId, registrationId)` (use for refund-quote/refund — refunds go to the payer, plan "保留原付款人"). Mechanical but touches every method in `FreeExploreBundleServiceImpl`; do it as its own reviewed slice **before** transfer.
- Schema:
```sql
CREATE TABLE IF NOT EXISTS explore_bundle_transfer (
  id BIGINT NOT NULL AUTO_INCREMENT,
  registration_id BIGINT NOT NULL, bundle_order_id BIGINT NOT NULL,
  sender_member_id BIGINT NOT NULL,
  receiver_phone_hash CHAR(64) NOT NULL COMMENT 'SHA-256(salt||normalized phone); plaintext phone never stored',
  receiver_member_id BIGINT NULL,
  channel VARCHAR(8) NOT NULL,
  code_hash CHAR(64) NOT NULL COMMENT 'SHA-256(salt||code); plaintext returned once',
  attempts TINYINT NOT NULL DEFAULT 0,
  status VARCHAR(12) NOT NULL DEFAULT 'PENDING' COMMENT 'PENDING/CLAIMED/REVOKED/EXPIRED',
  active_order_key BIGINT GENERATED ALWAYS AS (IF(status='PENDING', registration_id, NULL)) STORED,
  expires_at DATETIME NOT NULL, claimed_at DATETIME NULL,
  idempotency_key VARCHAR(96) NOT NULL, request_fingerprint CHAR(64) NOT NULL,
  version INT NOT NULL DEFAULT 0,
  create_time DATETIME NOT NULL, update_time DATETIME NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_bundle_transfer_idem (sender_member_id, idempotency_key),
  UNIQUE KEY uk_bundle_transfer_code (code_hash),
  UNIQUE KEY uk_bundle_transfer_active_order (active_order_key),
  KEY idx_bundle_transfer_receiver (receiver_phone_hash, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='F3 套票转赠';
CREATE TABLE IF NOT EXISTS explore_bundle_holder_assignment (
  id BIGINT NOT NULL AUTO_INCREMENT,
  registration_id BIGINT NOT NULL, holder_member_id BIGINT NOT NULL,
  cause VARCHAR(16) NOT NULL COMMENT 'PURCHASE/TRANSFER', transfer_id BIGINT NULL,
  create_time DATETIME NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_bundle_holder_transfer (transfer_id),
  KEY idx_bundle_holder_order (registration_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='F3 套票持有人变更历史(只插不改)';
```
- Code rules: ≥8 chars from a 31-char unambiguous alphabet (≈40 bits) from `SecureRandom`; TTL 72 h (owner to confirm); max 5 failed claim attempts per code then `EXPIRED`; per-member claim rate limit; code and phone never logged. Phone must match the claimer's verified phone (plan: "手机号…需匹配授权").
- Not touched: reward coupons (S16, account-bound), qmod licences (W18), the club invitation (P118).
- Errors: `BUNDLE_TRANSFER_NOT_ELIGIBLE`, `BUNDLE_TRANSFER_DUPLICATE_PENDING`, `BUNDLE_TRANSFER_CODE_INVALID`, `BUNDLE_TRANSFER_PHONE_MISMATCH`, `BUNDLE_TRANSFER_SELF`.
- Tests: unit `transferRefusedWhenAnyUnitUsedReservedOrHeld`, `transferRefusedWithRefundHold`, `claimMovesAllUnitsAndGrantsAtomically`, `claimKeepsPayerAndContractVersions`, `receiverCanReadOrderAndSenderCannotAfterClaim`, `payerStillOwnsRefundQuote`, `wrongCodeAndExpiredCodeLookIdentical`, `fifthWrongAttemptBurnsCode`, `claimReplaySameKeyReturnsSameResult`, `revokeOnlyWhilePending`, `noAutoRetransfer`; IT `twoReceiversRaceExactlyOneWins`, `claimVsReserveRaceKeepsUnitLockOrder`, `claimVsRefundHoldRace`, `holderAssignmentIsInsertOnly`.

---

## R. Refund request / progress (T-16 / T-17, EP-RFD-01..06) — split

State today: quote only (`GET /order/refund-quote`). Parked branch contains an **internal** same-transaction API `IFreeExploreBundleRefundService` (`prepareFullRefund → bindFullRefund → completeZeroCashRefund → syncRefundOutcome → onRegistrationRefundApproved`) with its own rule: "Rejection, UNKNOWN and manual payout retain the freeze; this API never unfreezes units" and "Legacy releasePerks hook is approval-only, never evidence of cash arrival."

| Part | Class | Spec |
|---|---|---|
| Refund **request** record (user picks units, server re-quotes, freezes units → `REFUND_PENDING`/`HELD`, stores intent) | BUILD-NOW **only behind** new switch `refund-request-enabled` (default OFF) and **only on the parked-branch lineage** | `POST /order/refund` `{registrationId,unitIds[],idempotencyKey,expectedRoute,expectedAmount}`; server computes quote, requires `expectedRoute/Amount` == fresh quote else `BUNDLE_REFUND_QUOTE_CHANGED` (same pattern as `expectedOutcome` on cancel). Writes `explore_bundle_refund_hold`. No PSP call. |
| Refund **progress** read | BUILD-NOW | `GET /order/refund?registrationId=` → hold `state` + `refundNo`; already half-present as parked `orderView.bundle.refundHold` |
| **Cash leg** (PSP refund; platform-balance credit; manual payout; app-store refund reconciliation) | **BLOCKED-PAYMENT** | route executor differs for IAP vs WeChat Pay. Do not build until decided. `completeZeroCashRefund` (zero-amount branch) has no money but is only reachable from a real refund application → also wait |
| Per-unit (partial) selection | **Owner decision** | quote rule is whole-order; T-16 "单元勾选" implies partial. Reconcile with the 20 % rule before building |

Required prerequisite: decide which backend branch is the base. The primary branch lacks refund-hold/units `REFUND_PENDING`; the parked branch is 4.7k files away from it. **Spec items B-19..B-24 and R must be built on whichever branch becomes the integration base — recommend rebasing the parked bundle slice onto the primary lineage first** (a separate task; I did not attempt it).

---

## Build order (backend) — recommended WPs

| WP | Content | Why first |
|---|---|---|
| **BWP-1** | Holder/payer access split (`requireHolder`/`requirePayer`) + `explore_bundle_holder_assignment` + `effectiveHolder()` helper, **no behaviour change** (assignment table seeded lazily from `order.holder_member_id`). Plus B-04 wallet list, B-09/10 voucher view+version, B-16 waiver read, B-17 redeem-result read, B-06 `activation` field | all pure reads; unblocks iOS T-06/07/08/11 and de-risks transfer; zero money, zero new write |
| **BWP-2** | Base-branch reconciliation: land the parked refund-hold slice (domain, mapper, `IFreeExploreBundleRefundService`, wire/contract tests, `exactId`) onto the primary lineage behind switches; B-01 shelf, B-02 detail, B-03 offer/unavailable-reason (slots `[]`) | iOS cannot show real status/refund progress without parked fields; shelf/detail unblock T-01..T-03 |
| **BWP-3** | B-20/21/22 reviews + B-23 renewal intent (new tables, independent, no money, small blast radius) + B-19 appeal **record/decision only** | independent features, can be parallel to BWP-2 |
| later | B-24 transfer (after BWP-1), R refund request (after base decision + switch), B-05 pay and the cash leg (after payment decision), appeal "apply" (after settlement decision), slots (after EP-PRD) | |

## Open questions for the owner (cannot be answered from the repos)

1. **Payment channel**: IAP vs WeChat Pay for iOS (blocks B-05, cash leg of R, and how "ORIGINAL_METHOD" is executed).
2. **EP-BND-07, 08, 11, 18** are never bound to a route or described — what are they?
3. Appeal approved ⇒ does the merchant get paid (settlement claim) as if scanned?
4. Which backend branch is the integration base (primary vs parked)? Parked changes `requireOwnRegistration` use sites, ids-as-strings, refund hold.
5. Voucher `main.code`: reuse the exact QR/dynamic-code payload the `scan_qr_code_chapter` scanner accepts (needs the scanner owner).
6. Review moderation hook + merchant-reply permission (VERIFY is too narrow).
7. Transfer TTL (72 h proposed), SMS provider for `channel=SMS`, claimer phone verification source.
8. Refund unit-level selection vs whole-order rule (20 %).
9. Renewal window (30 days after `valid_to` proposed).
