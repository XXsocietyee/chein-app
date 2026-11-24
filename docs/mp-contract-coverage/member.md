# Member rows

Baseline is `origin/cursor/mp-contract-coverage` at `569fca241951` (`docs/mp-contract-coverage.md` on that branch). This file lists only the member rows taken on `cursor/mp-cov-member`. The full table stays on that branch.

Mini-program source: public `liboyang42-cpu/hengyin`, folder `chengyinhub-xcx`, commit `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`.

A row is a `request(` call from that table. `sendRequest(` and `req(` are not rows. Coupon, invoice, ticket wallet, and the profile order list use `sendRequest(` or `req(`, so they have no row in the table and none were added here.

## Count change

Published baseline: total 102, matched 19, missing endpoint 42, missing test 82.

| count | baseline | after these rows |
|---|---|---|
| total | 102 | 102 |
| matched | 19 | 21 |
| missing endpoint | 42 | 39 |
| missing test | 82 | 80 |
| endpoints added |  | 3 |
| tests added |  | 4 |

Matched rises by the refund-apply row and the profile `api/im/start` row. Missing endpoint falls by cancel, confirm, and refund-apply. Missing test falls by refund-apply and `api/im/start`. Cancel and confirm stay in missing test: their calls have no `data` key, so the tool's field list stays unknown and a test cannot pin them. This branch does not contain the 16 pins from `cursor/mp-contract-coverage`, so a fresh scan of this tree is not the baseline plus this delta.

## Taken

| MP file:line | method | path | fields | Core symbol | test |
|---|---|---|---|---|---|
| `subpackageMember/market/pass-order/index.js:77` | `POST` | `api/platform-pass/orders/{}/cancel` | tool: unknown (no `data` key). Wire body is `{}` | `PlatformPass.passOrderCancelPath` | `MiniProgramMemberContractTests.testPassOrderCancelPinsPostAndDecodesCancelled` (tool still `MISSING`) |
| `subpackageMember/market/pass-order/index.js:116` | `POST` | `api/platform-pass/orders/{}/refund-apply` | `reason` | `PlatformPass.passOrderRefundApplyPath` | `MiniProgramMemberContractTests.testPassOrderRefundApplyPinsReasonAndDecodesReviewStatus` |
| `subpackageMember/utils/platform-pass-pay.js:84` | `POST` | `api/platform-pass/orders/{}/confirm` | tool: unknown (no `data` key). Wire body is `{}` | `PlatformPass.passOrderConfirmPath` | `MiniProgramMemberContractTests.testPassOrderConfirmPinsPostAndDecodesPaid` (tool still `MISSING`) |
| `subpackageMember/components/cy/profile/index.js:1789` | `POST` | `api/im/start` | `target_member_id` | `ProfileIMStartContract.path` | `MiniProgramMemberContractTests.testProfileIMStartPinsTargetMemberIdAndDecodesConversationId` |

Cancel, confirm, and refund-apply build the request and decode `data.status` / `data.refund.reviewStatus`. `PlatformPass.moneyEnabled` stays false. `cancelPassOrder`, `confirmPassOrder`, and `refundApplyPassOrder` throw `PlatformPassWriteRefusal.unreachable` and do not send.

`api/im/start` was already a Core path. `ProfileIMStartContract` is the form body the profile page sends (`content-type: application/x-www-form-urlencoded;`, field `target_member_id`). The test decodes `data.conversationId`.

## Not taken

| MP file:line | why |
|---|---|
| `subpackageMember/utils/platform-pass-pay.js:23` | Create is already pinned on `cursor/mp-contract-coverage` (`testPlatformPassOrderCreateStaysRefused`). Not redone. |
| `subpackageMember/utils/platform-pass-pay.js:76` | Pay is already pinned there (`testPlatformPassPayStaysUnsent`). Not redone. No pay sender was added. |
| `subpackageMember/market/pass-order/index.js:114` | `subscribe.request(['refund'])`. Not an HTTP path. |
| `subpackageMember/components/cy/scene-member-order-detail/index.js:647` | `subscribe.request(['refund'])`. |
| `subpackageMember/components/cy/scene-member-order-history/index.js:394` | `subscribe.request(['refund'])`. |
| `subpackageMember/components/scene-member-participation-detail/index.js:609` | `subscribe.request(['refund'])`. |
| `subpackageMember/components/cy/coop-invite-sheet/index.js:215` | `subscribe.request(['coopStatus'])`. |
| `subpackageMember/components/cy/profile/index.js:83` | `req(url, data)` passes the URL in. The tool leaves the path unknown. Call sites were not turned into rows. |
| `subpackageMember/components/cy/profile/index.js:914` | `POST api/merchant/public-home`. Merchant row, not taken. |

No App screen was edited. `App/PassMarketViews.swift` still shows the gated note for resume, cancel, and refund. `App/SocialPublicProfileView.swift` still starts a chat through `SocialActionRequestBuilder`.
