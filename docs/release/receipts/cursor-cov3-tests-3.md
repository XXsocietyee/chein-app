# cursor-cov3-tests-3

Base `6afe54b4acee8786a9f3f3cbe8cd85d90be1e35a`. Branch `cursor/cov3-tests-3` was created from that commit and was not moved onto a later tip. Mini-program: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`.

`python3 -B tools/check_mp_contract_coverage.py --mp-root` that tree, against this branch's `Core/` and `Tests/CoreTests/`.

| | total | matched | missing endpoint | missing test |
|---|---:|---:|---:|---:|
| before | 1038 | 779 | 120 | 256 |
| after | 1038 | 782 | 120 | 253 |

`docs/mp-contract-coverage.md` was not rewritten. Its totals were not edited. No Core path was added. `AppSession.swift`, `AppCompositionRoot.swift`, and `project.pbxproj` were not edited. `swiftc` was not run. The tests were not executed.

## Rows owned

44 missing-test rows. Orders, wallet, pass, coupons, and profile, under `subpackageMember/` and the other member pages named below. Play, roam, and merchant rows were not taken.

The checker records a test on 3 of them. Each of those calls has a literal path and a literal method:

- `pages/gerenziliao/gerenziliao.js:311` `POST` `api/user/nickname/suggest` — literals `baseName`, `cursor` (the call passes `data`)
- `pages/gerenziliao/gerenziliao.js:667` `GET` `api/user/profile/review`
- `pages/gerenziliao/gerenziliao.js:713` `POST` `api/user/update` — literals `name`, `avatar`, `introduction`, `website`, `caseIntroducton`, `casePics`, `wechat`, `tagIds` (`JSON.stringify`)

The other 41 stay missing-test. The call forwards `url`, `opts`, `options`, or `data`, or the method is only on a helper the checker does not copy onto `req(`. The tests still quote the method and the literal fields. The checker was not edited.

Profile, `subpackageMember/components/cy/profile/index.js`:

- `:83` `req` quotes `POST`. URL and body are arguments.
- `:734` verification forwards `options`.
- `:1277` `POST` `api/common/banner` `showType`
- `:1300` `POST` `api/user/info` or `api/user/public-info` `member_id`
- `:1395` `POST` `api/growth/center`. The `api/play/growth` call on the same line was not taken.
- `:1459` `POST` `api/medal/wall`
- `:1491` `POST` `api/user/points/statistics`
- `:1492` `POST` `api/growth/leaderboard` `metric`, `period`, `limit`
- `:1541` `POST` `api/registration/list` `pageNum`, `pageSize`, `owner_type`, `status`, `is_online`
- `:1620` `POST` `api/topic/list` `is_my`, `pageNum`, `pageSize`
- `:1697` `POST` `api/points/result_list`
- `:1758` `POST` `api/user/follow/action` `follow_member_id`, `follow`
- `:2056` `POST` `api/creativesquare/list` `is_my`, `pageNum`, `pageSize`, `user_id`
- `:2109` `POST` `api/club/post/feed` `scope`, `author`, `limit`, header `content-type`
- `:2156` `POST` `api/publish/home`
- `:2183` `POST` `api/user/balance/list` `pageNum`, `pageSize`. Read. Withdrawal stays off. The test sends nothing.
- `:2215` `POST` `api/creativesquare/like` `id`, `type`
- `:2238` `POST` `api/creativesquare/bookmark` `id`, `bookmark`, `request_id`

Orders:

- `scene-member-order-detail/index.js:658` `POST` `api/registration/cancel-refund` or `api/registration/cancel` `id`
- `scene-member-order-history/index.js:425` same pair, `id`
- `scene-member-participation-detail/index.js:149` forwards `options`
- `scene-member-participation-detail/index.js:636` same cancel pair, `id`
- `utils/user-invoice.js:81`–`:91` eleven `sendRequest` rows. Method `POST` is quoted at `invoice/base.js:125` and `:141`. `titles/save-request` and `apply` add `requestId`. Cancel sends `{ id }` (`invoice/base.js:165`) and this test sends nothing.
- `free-explore/index.js:83` forwards `url` and `method`. The test quotes the bundle paths and their literal fields. Merchant review calls on that page are not quoted.

Pass:

- `market/membership/index.js:17` forwards `opts`
- `market/membership/index.js:27` `GET`. The page calls `get('/api/platform-pass')`.
- `market/pass-order/index.js:13` forwards `opts`
- `market/passes/index.js:19` `GET` and `limit` for the catalog, product orders, gift reads, and `api/platform-pass/orders`

Other member pages:

- `subpackageP3/pages/badge-wall/index/index.js:245` `POST` `api/medal/wall` and `POST` `api/badge/wall-v2`. `req` sends `{}` (`badge-wall/index/index.js:180`).
- `subpackageP3/pages/growthcenter/index/index.js:35` helper quotes `POST` and `{}`. The play URLs passed into it were not taken.

Coupon pages (`coupon`, `coupon-qr`, `coupon-wallet`) have no missing-test row on this SHA.

## Money

`PlatformPass.moneyEnabled` stays false. Pay, gift claim, payout, and withdrawal send nothing. A payment TEST derivation does not make pay or gift claim send. `refuseRegistrationPay` throws `Adapt5PayRefusal.blocked` and sends nothing. No payout or withdrawal request is built.

Cancel, confirm, and refund-apply send only while `PlatformPass.orderWriteTestDerivation` for that kind is on. With the derivation nil, `sendCancelPassOrder`, `sendConfirmPassOrder`, and `sendRefundApplyPassOrder` throw `PlatformPassWriteRefusal.unreachable` and the transport stays empty. With the matching kind on, that one POST is sent (`{}` for cancel and confirm, `{reason}` for refund-apply). The other two stay off.

Registration `cancel-refund` stays blocked while `ReleaseMoneyWriteSwitch.testDerivation` is nil. Turning on `.refund` opens that switch. Those order tests still send nothing.

## Tests added

46 functions in `Tests/CoreTests/ZzZzCov3MemberContractPinTests.swift`.

## Not taken

Play: `subpackageMember/orient-score/index.js:91`, `:117`, `:155`, `:205`, `:240`, `:313`; `profile/index.js:1395` `api/play/growth`; `profile/index.js:1440` `api/play/my-completed`; `npc-chat/index.js:129`; `utils/checkout/selfplay-xpay-pay.js`.

Roam: no roam missing-test row was taken. `scene-route-content/index.js:260` and `:521` forward a scene URL and were left, because that loader also serves merchant forms.

Merchant: `profile/index.js:1095` `api/merchant/access/me`, `:1126` `api/merchant/info`, `:1592` `api/merchant/chapter-application/mine`. Free-explore merchant review calls were not quoted.
