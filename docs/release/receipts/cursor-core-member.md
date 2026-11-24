# Receipt: cursor/core-member (K1)

Owner: Cursor, area `member`, `Core/` and `Tests/` only. App screens were not edited.
Base: `origin/ui/combined-r7` at `7fdfad1f177fadb76f7fd54a82b27fa69b82f1f8` (`integrate(r7): fix Gemini compile errors`).
This VM has no `swiftc` or `xcodebuild`. Nothing here was parsed, compiled, or run. Tests were written to pin the request and the decoded fields; they were not executed.

Handbook native iOS rule (system list/form/sheet, system navigation, Dynamic Type, keep MP content) stays with the F-agent. This slice does not restyle screens.

Money stays on the existing TEST-only paths. `MerchantPublicReviewGate` still defaults off. No new Swift folder, so `tools/generate_project.py` is unchanged. `project.pbxproj` and `tools/current_ci_manifest.json` were not edited. New copy is only the xcstrings fragment `docs/port/strings/cursor-core-member.json`. The big catalog was not hand-edited.

## Skipped because another branch already owns them

- `restyle/r1`–`restyle/r6` are visual. Nearest member surface is `restyle/r4-me-account`. No screen restyle here.
- `port/p1`–`port/p6` are already in `ui/combined-r7`.
- `gap/g1-player` and `gap/g2-ops` own `App/MPGap` and `Core/MPGap`. Their member client (`MemberRound2Service`) calls paths the mini-program does not (`api/registration/my`, GET points, `api/club/follow`, `api/template/my/list`, `api/orient/appeal`). Not adopted. `r7-rev-c` F-C04 / F-C06 say the same.
- `origin/cursor/ut-d4-members` is unrelated to this area.
- `origin/review/r7-rev-a` is play runtime, not member.
- B-16 and B-21 are Claude P5, not this Core slice.
- The r7 member audit already dropped items those in-flight branches cover. Those rows were not reopened.

## Fixed

| id | what changed |
|---|---|
| MKT-4-3 | `PlatformPassTermFacts.parse` follows `utils/platform-pass.js` `passTerms` (string list, first match, `有效期：` stripped; older object keys). `PlatformPassOverview.terms` decodes `overview.terms` on `GET /api/platform-pass`. |
| R7-MEM-10-1 | `POST /api/coupon/mypublishlist` always sends `is_select=0`. `scope=MERCHANT` only for `CouponPublishListScope.merchant`. A player omits `scope`. The read route accepts only those two bodies. |
| MKT-9-5 | Coupon QR: body `msg` containing `无权查看该券` is `CouponCodeFailure.notMine` / phase `.notMine`, checked before 401 / 410 / 503. |
| PLY-25-4 | Orient appeal: a timeline `entryId` still wins and sends no `nodeId`. A missed-task appeal with no entry sends `nodeId` and omits `entryId`. Neither id is `请选择一条计分记录`. |
| PLY-26-5 | Template shelf writes and `my-list` add `scope=MERCHANT` only when `operationScope == "MERCHANT"`. Player requests omit it. The page-10 read route accepts that one extra field. |
| FIN-16-2 | New `ProfileService.orderHistory` posts `pageNum`, `pageSize` (10, `app.getPageSize()`), `owner_type=3`, `status=0`. `orders()` stays the unpaged owner list (no `status`). |
| FIN-11-1 | `subpackageMember/invoice/index` is an optional-id page. Bare path and `?id=` (positive decimal) both parse. `id=0` and unknown keys do not. |
| R7-MEM-21-3 | `TicketWalletTicket.coverURL` is `cmsActivity.imgUrl`, else `cmsTopic.imgUrl`. |
| B-13, B-20 | `INVOICE_NOT_FOUND` on the original application read and on `api/invoice/titles/request` is `.notFound`. The journal is kept. Command-receipt reads stay `.outcomeUnknown`. |
| B-18 | Public home requires `data.memberId` to equal the requested member. Public reviews require `eligibility.requestedRegistrationId` to equal this registration. `canCreate` is malformed unless `eligibility.registrationId` is the same registration. Gate still defaults off. |
| B-19 | `POST /api/merchant/reviews/create` always sends `imageUrls: []`. HTTP/envelope 400, 403, or 409 whose `msg` contains `已评价` is `.rejected(code, msg)`. Other 4xx is malformed. 5xx stays unavailable. |

## Files

- `Core/PlatformPass.swift`
- `Core/CouponManagementContract.swift`
- `Core/CouponManagementReadTransport.swift`
- `Core/CouponManagementRuntime.swift`
- `Core/CouponManagementCoordinator.swift` (`publishListScope`, default `.merchant`)
- `Core/CouponCodePresentation.swift`
- `Core/OrientScoreReviewWriter.swift`
- `Core/TemplateAuthoringContract.swift`
- `Core/TemplateAuthoringShelf.swift` (`operationScope` on the page reader and the authoring coordinator)
- `Core/TemplateAuthoringService.swift`
- `Core/TemplateAuthoringCoordinator.swift`
- `Core/TemplateShelfReadApproval.swift`
- `Core/ProfileService.swift`
- `Core/MiniProgramPageLink.swift`
- `Core/InvoiceLaunchService.swift`
- `Core/TicketWalletContracts.swift`
- `Core/PublicMerchantReviews.swift` (`Eligibility.requestedRegistrationId`)
- `Core/MerchantPublicReviewHook.swift`
- `docs/port/strings/cursor-core-member.json`

## Tests added or updated

Not run (no Swift toolchain).

- `Tests/CoreTests/PlatformPassReadTests.swift` — `GET /api/platform-pass` plus string-list terms and the older object shape.
- `Tests/CoreTests/CouponPublishedBatchCodeTests.swift` — merchant body `is_select=0` + `scope=MERCHANT`; player body `is_select=0` only.
- `Tests/AppUnitTests/CouponRuntimeCompositionTests.swift` — the live list route now requires `is_select=0`. A body that only has `scope` + `keyword` is rejected.
- `Tests/CoreTests/CouponCodePresentationTests.swift` — `POST /api/coupon/qr-token` with `无权查看该券` becomes `.notMine`; the coordinator phase is `.notMine`.
- `Tests/CoreTests/OrientScoreReviewWriterTests.swift` — node-only appeal body contains `nodeId=12` and no `entryId`.
- `Tests/CoreTests/TemplateAuthoringTests.swift` — merchant `scope=MERCHANT` on my-list, delete, market status, market-submit; player omits it.
- `Tests/CoreTests/TemplateShelfReadTests.swift` — page-10 `my-list` with `scope=MERCHANT` is the same read route.
- `Tests/CoreTests/ProfileServiceTests.swift` — `orderHistory` field names and `rows` / `total` / `hasMore`. `orders()` still asserts no `status`.
- `Tests/CoreTests/MiniProgramPageLinkTests.swift` — invoice history with and without `id`.
- `Tests/CoreTests/TicketWalletTests.swift` — cover URL prefers the activity image.
- `Tests/CoreTests/InvoiceLaunchServiceTests.swift`, `InvoiceLaunchCoordinatorTests.swift`, `WiringR6ClientTests.swift` — original and title `INVOICE_NOT_FOUND` are `.notFound` and keep the journal.
- `Tests/CoreTests/WiringR6ClientTests.swift` — mismatched or missing `memberId` and a wrong `requestedRegistrationId` are malformed; 403 and 409 `已评价` are `.rejected`; a bare 409 and HTTP 500 are not; create body `imageUrls` is `[]`.

## F-agent (App) — required, not done here

`App/CouponCodeView.swift` `content` switches on `CouponCodeCoordinator.Phase` and has no `.notMine` arm (around the `.unavailable` arm). The app target will not compile until that arm exists. Show `couponCode.notMine` (这张券不在你的券包里) and `couponCode.notMine.back` (返回). Keys are in `docs/port/strings/cursor-core-member.json`. Do not merge that fragment by hand into the big catalog unless the string pipeline already does.

Also wire, without changing the Core contracts:

- `App/CouponManagementView.swift` (the `.task` / refresh that calls `model.core.load()`): set `core.publishListScope = .player` when the page is not a merchant shelf, `.merchant` when `operationScope` is `MERCHANT`, before `load()`.
- `App/TemplateAuthoringMineView.swift`: set `coordinator.operationScope = "MERCHANT"` for the merchant theme. The page reader `TemplateOwnShelfReader.operationScope` needs the same value or its `my-list` page stays the player body.
- `App/PassMembershipViews.swift` `termFacts`: use `overview.terms` (seat as 适用范围; server renewal / refund text when present). Do not keep inventing the fixed OR-024 lines when the server sent a line.
- `App/ProfileOrdersView.swift` (load is `reader.profileOrders()`, which still calls unpaged `ProfileService.orders`): call `orderHistory` and append on the bottom sentinel. Do not switch `orders()` itself.
- `App/MPReviewedPageScreen.swift` `subpackageMember/invoice/index`: when `query["id"]` is present, mount `InvoiceLaunchDetailView(applicationID:)`. A bare path stays `InvoiceLaunchHistoryView`.
- `App/TicketWalletView.swift`: show `ticket.coverURL`; keep the illustration only when that URL is absent. `focusId` still needs `reader.ticketDetail` when the id is not in the usable list (`Core/TicketWalletReading.swift` already has `ticketDetail`).

## Leftovers

| id | why left |
|---|---|
| FIN-16-2 screen | The paged request exists. `OwnedOrderSessionReader.profileOrders` and `ProfileOrdersView` still call unpaged `orders()`. Changing that reader would put `status=0` on every existing order screen. The history screen has to opt in. |
| R7-MEM-21-1 | Verification-code tick still expires tickets and then waits for a manual retry, and reissues a city voucher at expiry. The 30-second silent reissue, keeping the old code on failure, needs its own state machine and the tests that already pin the current tick. Not in this slice. |
| PLY-21-14 | `TicketWalletListReadRoute` byte-compares an `owner_type`-only body. Adding `pageSize` there fails those guards and needs a confirmed server default. Left. |
| PLY-21-2 | Core `ticketDetail` (`registration/info`) already exists. The wallet screen still does not open it when `focusId` is missing from the usable list. |
| PLY-21-5 | Status chip, party line, and 已核销 x/y are screen copy. No new Core field in this slice. |
| R7-MEM-21-2 | `isWalletLocked` exclusion is `App/TicketWalletView.swift`. |
| R7-MEM-7-2 | `BUNDLE_LEDGER_OFF` is `App/FreeExploreBundleLaunchView`. |
| R7-MEM-23-1 | Character probe gate and `GET /api/play/character` stay on the character screen. |
| R7-MEM-24-1 | Splitting character `.unknown` into unavailable / session-changed / upgrade is `App/CharacterCardReadbackView` plus the states in `character.js`. |
| FIN-19-1 | Withdrawal history paging is an owner item, not this slice. |
| MKT-3-1, MKT-5-3 | Gift claim and pass cancel / refund stay behind the money gate. |
| MKT-4-4 | Plan facts are already on `PlatformPassHolding`. Screen still has to read them. |
| Gemini `Core/MPGap` | Wrong endpoints. Not adopted. |
