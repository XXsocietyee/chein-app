# cursor-mp-cov-member

Base `aee32a61f0f69b880bc9e33811463ccc73351bbe` (`origin/ui/combined-r7`). Branch `cursor/mp-cov-member`. No pull request.

Coverage source: `origin/cursor/mp-contract-coverage` `569fca241951`. Mini-program: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`. Rows and the count change: `docs/mp-contract-coverage/member.md`.

## What landed

Three endpoints that were missing, plus the profile chat contract on a path Core already had:

- `POST api/platform-pass/orders/{}/cancel` — `PlatformPass.passOrderCancelPath`. No `data` key. JSON body `{}`. Decodes `data.status` (`CANCELLED`).
- `POST api/platform-pass/orders/{}/refund-apply` — `PlatformPass.passOrderRefundApplyPath`. Field `reason` (trimmed). Decodes `data.refund.reviewStatus`.
- `POST api/platform-pass/orders/{}/confirm` — `PlatformPass.passOrderConfirmPath`. No `data` key. JSON body `{}`. Decodes `data.status` (`PAID`).
- `POST api/im/start` — `ProfileIMStartContract`. Form body `target_member_id`. Header `content-type: application/x-www-form-urlencoded;`. Decodes `data.conversationId`.

Tests, all in `Tests/CoreTests/MiniProgramMemberContractTests.swift`:

- `testPassOrderCancelPinsPostAndDecodesCancelled`
- `testPassOrderRefundApplyPinsReasonAndDecodesReviewStatus`
- `testPassOrderConfirmPinsPostAndDecodesPaid`
- `testProfileIMStartPinsTargetMemberIdAndDecodesConversationId`

`PlatformPass.moneyEnabled` is false. Cancel, confirm, and refund-apply throw `PlatformPassWriteRefusal.unreachable` and do not send. Create and pay were not redone. No pay sender was added.

The coverage tool, run on these rows, records a symbol for all four. It records a pinning test for refund-apply and `api/im/start`. Cancel and confirm stay `MISSING` in the test column because the tool's field list is unknown when the call has no `data` key. That is left unknown. The tests still record the `{}` body.

Count change against the published baseline (total 102, matched 19, missing endpoint 42, missing test 82): matched 21, missing endpoint 39, missing test 80. Endpoints added: 3. Tests added: 4. This branch does not include the 16 pins from `cursor/mp-contract-coverage`.

## Not taken

Coupon, invoice, ticket wallet, and profile order HTTP calls are `sendRequest(` or `req(`. They are not rows. `subscribe.request` rows under member pages are not HTTP. `profile/index.js:83` is a helper whose URL is a parameter. `profile/index.js:914` is `api/merchant/public-home`.

## Screens

No App screen was edited. To call the new pass writes, `App/PassMarketViews.swift` would have to change; it still shows `mp.passOrder.gated` for resume, cancel, and refund. To send the profile form contract, `App/SocialPublicProfileView.swift` would have to change; it still starts a chat through `SocialActionRequestBuilder`.

## Not claimed

No `swiftc` run. The tests were not executed. The tool does not parse JavaScript concatenation or a missing `data` key, and those field lists stay unknown.
