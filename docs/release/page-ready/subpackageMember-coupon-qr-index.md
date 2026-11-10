# CB293 subpackageMember/coupon-qr/index

PAGE-READY on rc/20261108 (`e8299803711abd007e33731bdd534c40d6536ea2`). Native screen `App/CouponCodeView.swift`. Map status stays **exists**. No route was invented and none was marked live. `POST api/coupon/qr-token` and `POST api/coupon/status` were already wired with `couponHistoryId`. `CouponCodeHTTPService` still defaults to `enabled: false`. Payment, coupon verification, and virtual goods stay off.

The read and issue contract is `CouponCodeHTTPService` plus `CouponCodeCoordinator`. Loading is phase `.loading` and shows no token. Empty is `historyID <= 0`: the screen uses `couponCode.missing`, and confirm sends nothing and lands on `.invalid`. Error stays an error (`.failed`, `.unavailable`, `.serviceDisabled`, `.login`, `.stale`, `.disabled`). A failed issue does not become an empty success.

UNKNOWN is a missing, null, numeric-string, or object `expiresIn`, and a missing or null `useStatus`. Those are not stored as 0. `expiresInText` and a hidden `remainingText` are an em dash (`—`, U+2014). A literal JSON 0 stays 0: a used coupon with `"expiresIn": 0` displays `0`, and a displayed countdown of 0 stays `0`. An active code (`useStatus` 0) still requires a TTL of 1...90 and a credential. A numeric-string status is rejected. `OrderCouponStatus.stateKey` is `unknown` when `useStatus` is missing, and `available` only for a literal 0.

## Missing EN and zh-Hans keys

None. Every user-facing key on `CouponCodeView` already has translated en and zh-Hans in `Resources/Localizable.xcstrings`.

`accountCollection.coupon.validFrom`, `accountCollection.coupon.validUntil`, `action.retry`, `couponCode.authority`, `couponCode.disabled`, `couponCode.expired`, `couponCode.failed`, `couponCode.failed.detail`, `couponCode.fetchAgain`, `couponCode.image`, `couponCode.invalid`, `couponCode.loading`, `couponCode.login`, `couponCode.missing`, `couponCode.missing.detail`, `couponCode.paused`, `couponCode.pollDelayed`, `couponCode.presentToMerchant`, `couponCode.refresh`, `couponCode.remaining`, `couponCode.renderFailed`, `couponCode.review`, `couponCode.review.detail`, `couponCode.serviceDisabled`, `couponCode.serviceDisabled.detail`, `couponCode.show`, `couponCode.stale`, `couponCode.title`, `couponCode.unavailable`, `couponCode.used`, `couponCode.waiting`.

`couponCode.qr`, `couponCode.view`, `couponCode.waiting.start`, and `couponCode.serviceDisabled.retry` are accessibility identifiers, not catalog keys.

## Tests

`Tests/CoreTests/CouponCodePageReadyTests.swift`:

- `testUnknownTTLIsEmDashAndLiteralZeroStaysZero`
- `testUnknownStatusIsNotStoredAsAvailable`
- `testMissingHistoryIsEmptyAndSendsNothing`
- `testLoadingEmptyCountdownAndReadyLiteralZero`
- `testIssueErrorShowsNoCodeAndNoZeroCountdown`

Existing `CouponCodePresentationTests`, `CouponCodePermitTests`, and `CouponCodeServiceDisabledTests` were not weakened. `Tests/ContractChecks/test_owned_coupon_lifecycle.py` passed (12). The coupon assertions in `tools/check_native_navigation_completion.py` passed (`coupon history ID and existing exact source adapters`, `coupon lifecycle independent from metadata and redemption`). Tree-sitter parsed the two Swift files with 0 recovery nodes. `swift`, `swiftc`, and `xcodebuild` are not on this machine. No Swift run. No Xcode Cloud result.

## Left

`App/CouponCodeView` still draws `remainingSeconds` with `.number` only while `canDisplay`. `remainingText` is the model label for a later view bind. This lane did not edit the view, string catalogs, the page map, the Xcode project, or `tools/current_ci_manifest.json`.
