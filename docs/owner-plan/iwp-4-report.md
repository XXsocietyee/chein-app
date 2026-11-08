# IWP-4 report — Shelf + detail

Branch `cloud/iwp-4` (from `origin/cloud/iwp-0`). Cloud builder: **nothing compiled or run** (no Swift toolchain). Evidence layer: source written and desk-checked only.

## Files (all new)
`Core/BundleShelfClient.swift`, `Core/BundleShelfModel.swift`, `App/BundleShelfView.swift`, `App/BundleDetailView.swift`, `Tests/CoreTests/BNDShelfModelTests.swift`, `docs/owner-plan/iwp-4-new-strings.md`, this report. No existing file touched; nothing wired into AppSession/composition; no routes; gates unchanged.

## Public types
- `BundleShelfItem`, `BundleShelfPage` (Decodable, Equatable; B-01 shape from `bundle-backend-spec.md`, all fields except ids optional), `BundleShelfFailure { unavailable, failed }`.
- `@MainActor protocol BundleShelfClient { page(cursor:limit:) }`, `UnavailableBundleShelfClient` (always throws `.unavailable`; B-01 has no backend yet, so no real client).
- `@MainActor @Observable BundleShelfModel` — `refresh()`, `loadMore()`, `state`, `items`, `nextCursor`, `hasMore`, `saleEnabled`, `reservationEnabled`. Dedupes by topicId; a nil/empty/repeated cursor ends paging; page size clamped 1…50.
- `BundleDetailExtras` (lenient optional B-02 fields: compliance, merchants, price, validityDays), `BundleDetailContent` (`decode(_:)`, `showsPurchase`, `showsNotOnSale`, `complianceDeclarations`, `agreementURL` https-only, `hasCompliance`).
- Views `BundleShelfView`, `BundleDetailView`: purchase button needs `saleEnabled` AND a caller-supplied `onPurchase` (checkout is blocked, so none is supplied). No bundled legal text.

## Tests (`BNDShelfModelTests`)
testShelfUnavailableDefaultShowsNothingNotMockCards, testDetailHidesPurchaseWhenSaleDisabled, testDetailToleratesMissingComplianceFields, testShelfPaginationCursorStopsOnNil, plus extra testRepeatedCursorIsTreatedAsEnd. (The spec's file list names no AppUnitTests file, so no view tests.)

## NOT verified
- Not compiled, no test run, red-first not performed.
- View code (`.task`/`.refreshable`, `case .idle, .loading where …` pattern, `navigationTitle(Text)`) never type-checked.
- Strings in table `BundleCommerce` do not exist yet (orchestrator adds per `iwp-4-new-strings.md`); views will show raw keys until then.
- B-01/B-02 wire shapes are from the spec, not a live backend. Not added to the .xcodeproj.
