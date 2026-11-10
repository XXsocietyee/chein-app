# CB292 page-ready — `subpackageMember/coupon-wallet/index`

玩家优惠券卡包. Native page `App/AccountCollectionCouponsView.swift`. Page map status stays `exists`. This pass does not mark a route live, does not edit views, string catalogs, the Xcode project, or the ledger, and does not enable payment, redemption, or virtual goods.

Source checked: `hengyin` `chengyinhub-xcx/subpackageMember/coupon-wallet` (deep link to `scene-game-coupon-wallet`) and `ApiCouponController.myrecvlist` / `ViewCouponHistory`.

## Already on rc

The read contract is already wired. `AccountCollectionService.coupons` posts `api/coupon/myrecvlist` with an optional `keyword`. `ProfileOwnedCouponReader` performs that read. `ProfileOwnedCouponReadRoute` still accepts only that path.

The four phases are already represented:

- **loading** — `OwnedCouponReadScreenModel.isLoading` until the offered request is the loaded request. The list shows the existing skeleton.
- **empty** — a JSON array `data: []` is an empty wallet. A filter or search with no rows is the filtered empty state. A missing `data`, `null`, an object, or a malformed row stays an error and is not turned into an empty list.
- **error** — `AccountCollectionIssue` covers sign-in, not configured, unavailable, network, failure, and a literal server message.
- **UNKNOWN** — `useStatus` other than 0, 1, 2, or 3, including a missing status, is `.unknown` (`状态待确认`). It is not unused, and it is not recomputed from the device clock.

There is no coupon count on this page. A missing status is not stored as 0. A literal `useStatus` of 0 stays unused.

## Model wiring added

`myrecvlist` projects a public shop onto each row (`shopName`, `shopAddress`, `shopLat`, `shopLng`). Those four fields were not decoded. `AccountCollectionCoupon` now keeps them.

- A missing key, JSON null, blank text, non-string label, boolean, object, or numeric string stays unknown. It is not stored as `0` or as an empty place.
- A literal JSON `0` stays `0`. `countText` renders that as `0`. An unknown number renders as `—` (U+2014).
- `hasShopNavigation` is true only when both coordinates are present, including `0`. It does not open a map, a URL, or a route.
- `couponCode`, `qrcodeUrl`, and `token` are still not decoded. Two rows that differ only by those secrets stay equal.

The list and detail views were not changed, so the shop name, address, and navigation control are not on screen yet.

## Missing keys

These source strings have no entry in `Resources/Localizable.xcstrings` or `docs/account-collection-localizations.json`. They were not added. The catalog and the ui-strings JSON are out of scope.

| Source string | Where the mini program uses it |
| --- | --- |
| 当前身份不能查看这些优惠券 | permission empty state (HTTP 403) |
| 优惠券暂时没能打开 | error title |
| 优惠券暂时没能打开，请稍后重试。 | malformed list message |
| 网络异常，请重试。 | network failure message |
| 起可用 | future start date line (`{day} 起可用`) |
| 导航 | shop navigation control |
| 在地图中打开 | shop address accessibility label |

Nearby copy that already has a key, and is not listed above: 这里还没有优惠券, 当前筛选暂无优惠券, 全部 / 待使用 / 已使用 / 已过期, 状态待确认, 该券已被平台手动失效, 查看可用时间, 登录后查看收藏和优惠券 (`accountCollection.signInRequired`), 请检查网络后重试 (`accountCollection.network`). 登录 exists as `auth.signIn` and other sign-in keys, not as a coupon-wallet key. 出示核销码 exists as `roamSub.w208.poi.primary.showVoucher`. This page's code action uses `couponCode.show` (出示券码). 有效期至 exists on other pages. This page's label is `accountCollection.coupon.validUntil` (截止日期).

## Left

- The views still do not render shop name, address, or navigation. Doing that needs the seven keys above and a view change.
- HTTP 403 is still a generic failure or a server message. It is not a separate permission phase. A new phase needs a catalog key.
- A missing end date is omitted on the list row. The mini program draws `—` in that date line. That is view copy, not a count. The model does not turn the missing date into 0.
- The mini program's `Number(lat) && Number(lng)` treats coordinate 0 as absent. This model keeps a literal 0, so `0,0` still counts as present. No view reads that flag.
- `memberId` stays off the row. `ProfileOwnedCouponReadRoute.validateResponse` already requires it to match the signed-in account before that route accepts the payload. `getType`, `orderId`, `orderSn`, `couponType`, `delFlag`, and `couponDelFlag` are not read by this page.
- Redemption, QR issuance, publish, stop, and payment stay unwired on this read model.
- `xcodebuild` was not run. Swift is not available in this environment.
