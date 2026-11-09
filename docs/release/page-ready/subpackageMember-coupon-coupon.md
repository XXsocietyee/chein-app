# CB294 page-ready — subpackageMember/coupon/coupon

Base: `rc/20261108` `e8299803711abd007e33731bdd534c40d6536ea2`.
Branch: `cursor/cb294`.

Page: 商家我发布的优惠券管理. Native screen: `App/CouponManagementView.swift`. Page-map status: `exists`. This note does not change that status.

This lane is already complete on rc. No Core, test, view, ui-strings JSON, string catalog, project, or ledger file was edited. Payment and virtual goods stay off. No route was added and none was marked live. The page stays off the player-first entry. `xcodebuild` was not run.

## Already on rc

- Read model: `CouponManagementCoordinator.load` calls `CouponManagementAdapter.published`, which posts the existing `CouponManagementContract.published` body to `/api/coupon/mypublishlist` (`scope=MERCHANT`, optional nonempty `keyword`). `CouponManagementContract.decodePublished` requires HTTP 2xx and `code=200` with a `data` array of unique positive ids. A missing array, a duplicate id, or a body that is not that envelope is `malformed`, not an empty list. The host is `AppSession.couponManagementCoordinator`. `SessionCouponManagementView` passes that coordinator into `CouponManagementView` only as `merchantCouponManagementDestination`.
- The page-map names `Core/CouponManagementService.swift`. That file is not in this tree. The live types are `CouponManagementCoordinator`, `CouponManagementContract`, and `CouponDefinition`. The catalog was not edited.
- Routes: `/api/coupon/mypublishlist`, `/api/coupon/publish`, and `/api/coupon/stop` were already `.liveInProduction` in `Core/ChinaReviewedRouteCapability.swift`. They were not retouched. Publish and stop stay behind the existing write lease. With no lease, the authorizer is `CouponPublisherUnavailable` and `writeEnabled` stays false. This note does not turn a write on.
- Loading: `loading` is set for the in-flight list read. The list draws `couponManagement.loading`. A nil session does not start that read.
- Empty: a finished read with `rows` empty and `issue` nil is the empty list. The list draws `couponManagement.empty`. An empty array is not a count of 0.
- Error: `load` stores `signedOut` when there is no session, and `unavailable` or the thrown `CouponManagementError` when the read fails. The notice uses `issue.messageKey` (`invalid`, `malformed`, `unavailable`, `signIn`, `changed`, `forbidden`, `storage`, `unknownOutcome`, `serverError`). A failed read is not stored as an empty success.
- UNKNOWN: a status other than 0 scheduled, 1 active, 2 ended, 3 invalidated, or 4 stopped is `CouponDefinitionStatus.unknown` (`couponManagement.unknownStatus`). It cannot be stopped. An unknown publish or stop outcome stays `.locked` (`couponManagement.unknownOutcome`) until the original result can be verified. A missing session is sign-in, not an unknown count.
- Counts: `publishCount`, `receiveCount`, `useCount`, and `perLimit` decode with `decodeIfPresent(Int.self)`. A missing key or JSON null stays nil. A JSON number `0` stays `0`. A string, a boolean, a fraction, or `UNKNOWN` fails that row, so the list is `malformed` and the value is not stored as 0. `remaining` is nil unless both published and received are present and `>= 0`. When received is at least published, `remaining` is the literal `0`. The detail row draws nil as `—` (U+2014) and draws `0` as `0`. `amount` null stays nil and draws `—`. A numeric amount string is accepted only when it is a plain decimal; anything else fails the row. No count uses `?? 0`.
- Player-first: `WelcomeView.showsMerchantChoice` stays `false`. `CouponManagementView` defaults `isSourceVisible` to false and then draws `couponManagement.unavailable` without loading. The production host is `SessionCouponManagementView`, injected only as `merchantCouponManagementDestination` and opened from merchant recruiting (`MerchantContentDocumentView`, query `.recruiting`) after that screen’s marketing read. Welcome, home, and the player account tab do not construct this view. DEBUG hosts (`--ui-coupon-management` and `merchantCouponFixture`) are merchant-themed fixtures, not a player entry. The player coupon wallet is `subpackageMember/coupon-wallet/index`, a different page.
- Claim, pay, and virtual goods: the contract has no claim, receive, pay, or redemption route. `couponManagement.claimUnavailable` is the existing sentence for that gap. Nothing in this lane enables a purchase or a claim.

## Missing keys

The list, detail, and notice look these keys up in `Resources/Localizable.xcstrings`. Each one has a translated `en` value and a translated `zh-Hans` value.

Missing keys: none.

`active`, `amount`, `batchCode.title`, `changed`, `checkPendingResults`, `chinaTime`, `counts`, `coupon`, `create`, `currency`, `detail`, `empty`, `end`, `ended`, `experience`, `forbidden`, `gift`, `invalid`, `invalidated`, `loading`, `malformed`, `noDescription`, `perLimit`, `published`, `readbackPending`, `readbackVerified`, `received`, `recoveryFinished`, `refresh`, `remaining`, `reviewStop`, `scheduled`, `serverError`, `signIn`, `simulated`, `start`, `status`, `stopPolicy`, `stopped`, `storage`, `synthetic`, `tenPercent`, `title`, `twentyPercent`, `type`, `unavailable`, `unknownOutcome`, `unknownStatus`, `used`.

`couponManagement.claimUnavailable` and `couponManagement.batchCode.referenceOnly` are already in that catalog. No Swift file references them, so they are not missing keys. They were not copied into a new table.

The create and edit screen is the sibling page `subpackageMember/couponInfo/couponInfo` (page-map `partial`) in the same view file. Its keys (`name`, `dates`, `range.*`, `span.*`, `publishConfirm`, `stopConfirm`, `stopQuestion %@`, and the draft blockers) are also already translated. This lane does not add any of them and does not mark that page `exists`.

## Left

- The list row draws remaining only when `remaining` is non-nil. An unknown remaining count is omitted there. The detail already draws `—`. Showing the dash on the list row would be a view change.
- A failed `load` clears `rows` before setting `issue`. The view then draws the empty state under the error notice. Core still keeps `issue`. Hiding the empty state on error would be a view change.
- `couponManagement.claimUnavailable` and `couponManagement.batchCode.referenceOnly` are translated and unused. Drawing them would be a view change. Claim, pay, and redemption stay off.
- `docs/parity/page-map.csv` still names `Core/CouponManagementService.swift`. The catalog was not edited.
- `python3 -B tools/current_ci.py check` fails because this note is a new tracked file and `tools/current_ci_manifest.json` was not refreshed. That failure is the unchanged ledger rule for this lane.
- No new Swift test. Existing coverage stays in `CouponManagementTests.testMissingMoneyCountsAndUnknownStatusesStayUnknown` (nil amount, currency, and per-limit; remaining 17 versus nil; unknown status). `swift` and `xcodebuild` are not claimed.
