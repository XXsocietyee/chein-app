# PAGE-READY `subpackageMember/couponInfo/couponInfo`

CB295. 创建与编辑优惠券设置. Map status stays `partial` on `App/CouponManagementView.swift`. This lane does not edit a view.

- Contract already in the repo: `CouponManagementContract.published` reads `POST /api/coupon/mypublishlist`. Create uses `POST /api/coupon/publish` on `CouponManagementContract.publish`. `CouponInfoSettingsPage.load` calls the published list only when an edit id is present. It never publishes. `routeMarkedLive` is false. No route was added. `paymentEnabled` is false. `virtualGoodsEnabled` is false. `saveEnabled` is false.
- Capability: `CouponInfoSettingsCapability(canRead:canSubmitPublish:)` follows the existing host switches and does not turn either one on. A missing read stays hidden and does not call the adapter. A missing publish grant leaves create empty and `showsPublishAction` false. An edit never shows publish. `showsSaveAction` is false.
- Model: `CouponInfoSettingsPage` in `Core/CouponManagementDomain.swift` has loading, empty, error, unknown, and ready. A missing count or amount displays `—`. A literal 0 stays `0`. Status `0` stays scheduled. Wire type `0` stays `couponManagement.gift`. The existing list decoder still accepts a numeric amount string as `Decimal` (`testNumericAndStringMoneyPreserveAbsentCurrency`); this page does not recode that. `CouponInfoAmount.parse` treats text, including `"0"` and `"UNKNOWN"`, as `—` while the token is still text. A non-numeric amount fails the existing decode and the page is `malformed`, not 0.
- Tests: `testSettingsPageStaysHiddenWithoutAReadAndDoesNotCallTheAdapter`, `testLoadingEmptyReadyAndLiteralZero`, `testUnknownAmountsAreEmDashAndALiteralZeroStaysZero`, and `testEditLoadUsesThePublishedListAndKeepsFailuresOffZero` in `Tests/CoreTests/CouponInfoSettingsPageTests.swift`. `Tests/ContractChecks/test_coupon_info_page_ready.py` checks the partial row, the existing keys, and that payment stays off.

## Missing keys

No new key was written. The keys this model references already have translated en and zh-Hans in `Resources/Localizable.xcstrings` and `Resources/CouponManagementLocalizations.fragment.json`:

`couponManagement.loading`, `couponManagement.empty`, `couponManagement.signIn`, `couponManagement.unavailable`, `couponManagement.malformed`, `couponManagement.serverError`, `couponManagement.unknownOutcome`, `couponManagement.forbidden`, `couponManagement.storage`, `couponManagement.changed`, `couponManagement.invalid`, `couponManagement.refresh`, `couponManagement.checkPendingResults`.

These keys are not in the catalog. They were not added:

- `couponManagement.save` — saving an edit of an existing definition. There is no update contract. The action stays hidden.
- `couponManagement.range.completed` — the mini-program toast 时间设置完成 after the validity range is confirmed. No key.
- `couponManagement.network` — a submit failure is not split into network versus data.
- `couponManagement.dataError` — the same gap. The existing error keys stay `unavailable`, `malformed`, `serverError`, and `unknownOutcome`.
- `couponManagement.retry` — the model uses the existing `couponManagement.refresh` for an error retry. There is no separate retry key.

## Left

`App/CouponManagementView.swift` still reads `CouponManagementCoordinator` and `CouponManagementDraft`. It does not read `CouponInfoSettingsPage`. The create sheet still opens when review is allowed and writes are dormant, and a blank description still uses `couponManagement.noDescription`. A missing amount on the detail screen is already an em dash in that view. The host write grant stays off (`dormantWritesEnabled` defaults false). This machine has no `swift` or `xcodebuild`. The XCTest file was not executed.

`python3 -B -m unittest Tests/ContractChecks/test_coupon_info_page_ready.py` passed (3 tests). `python3 -B tools/check_scaffold.py` passed. `Tests/ContractChecks/test_coupon_management_integration.py` still fails its catalog count (`90 != 77`). That catalog was not edited.
