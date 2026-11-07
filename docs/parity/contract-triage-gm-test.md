# Contract Triage — GM-TEST (`ClubPostDiscussionReadTests.testNextPageAvailabilityUsesAcceptedPageSize`)

## Context & `f9ca1f42` Evidence

In commit `f9ca1f42405122d54561193546a351753ac63c8b` (`chore: 保存已审查 iOS 3fb0705 源码快照 [skip ci]`), inline club post comment reading (`ClubPostDiscussionReader` in `App/ClubPostDiscussion.swift`, `ClubCommunityRead.comments` in `Core/ClubCommunityContracts.swift`, and `ClubCommunityReadRoute.comments` in `Core/ClubCommunityReadRuntime.swift`) was updated from client-invented 50-item pagination (`page > 0`, request body `["postId": id, "pageNum": page, "pageSize": 50]`, `hasNext = comments.count >= 50 && page < Int.max`) to the mini-program's full-list contract:

1. `App/ClubPostDiscussion.swift`:
   - `ClubPostDiscussionReader.load(page:isCurrent:)` guards `page == 1` (`guard page == 1, isCurrent(), ... else { invalidate(); return }`).
   - On completion, `comments = result.comments; hasNext = false; phase = .ready`.
2. `Core/ClubCommunityContracts.swift` & `Core/ClubCommunityReadRuntime.swift`:
   - `ClubCommunityRead.comments(postID:page:)` sends `["postId": id]` and rejects `page != 1`.
   - `ClubCommunityReadRoute` accepts only `["postId": postID]` on `api/club/post/comment/list`.
3. Backing test suites added in `f9ca1f42`:
   - `Tests/AppUnitTests/ClubPostDiscussionFullListTests.swift`:
     - `testFullSixtyCommentsHaveNoNextPageAndRefreshUsesOriginalPostOnly` asserts `reader.comments.count == 60`, `reader.hasNext == false`, and request body `["postId": 91]`.
     - `testPageTwoIsNotADispatchableOriginalRead` asserts `reader.load(page: 2, ...)` dispatches no request (`transport.requests.isEmpty`) and invalidates the reader (`reader.comments.isEmpty`, `reader.phase != .ready`).
   - `Tests/CoreTests/ClubCommentsFullReadContractTests.swift`:
     - `testFullListBeyondOldPageSizeAndExactBody` and `testOldPageTwoCannotDispatchAndMatcherRejectsInventedPaging` assert `service.read(.comments(postID: 7, page: 2), ...)` throws without dispatching a request and `ClubCommunityReadRoute` rejects `["postId": 7, "pageNum": 2, "pageSize": 50]`.

## Superseded Test & Deadlock Hazard

`ClubPostDiscussionReadTests.testNextPageAvailabilityUsesAcceptedPageSize` (written in earlier commit `41571fed5c27d4766d0bebb02e2800d798f1edbd`) still asserted the superseded paginated contract and called an un-timed `await transport.waitForRequests(2)` after `model.load(page: 2, ...)`. Because `load(page: 2, ...)` returns early under the `f9ca1f42` full-list contract without sending a second HTTP request, `waitForRequests(2)` suspended forever on an unresumed `CheckedContinuation`, deadlocking the test runner and holding `/private/tmp/xcodebuild-global.lock`.

## Old vs. New Assertion in `ClubPostDiscussionReadTests.testNextPageAvailabilityUsesAcceptedPageSize`

### Old (pre-`f9ca1f42`)
```swift
    func testNextPageAvailabilityUsesAcceptedPageSize() async throws {
        let transport = Transport(), owner = Owner(), model = try make(transport, owner)
        let task = Task { await model.load(page: 1, isCurrent: { owner.current }) }
        await transport.waitForRequests(1); try await transport.reply(0, rows: (1...50).map { row($0) }); await task.value
        XCTAssertTrue(model.hasNext)
        let next = Task { await model.load(page: 2, isCurrent: { owner.current }) }
        await transport.waitForRequests(2); try await transport.reply(1, rows: []); await next.value
        XCTAssertFalse(model.hasNext); XCTAssertTrue(model.comments.isEmpty); XCTAssertEqual(model.phase, .ready)
    }
```

### New (aligned with `f9ca1f42` full-list contract, bounded wait)
```swift
    func testNextPageAvailabilityUsesAcceptedPageSize() async throws {
        let transport = Transport(), owner = Owner(), model = try make(transport, owner)
        let task = Task { await model.load(page: 1, isCurrent: { owner.current }) }
        await transport.waitForRequests(1); try await transport.reply(0, rows: (1...50).map { row($0) }); await task.value
        XCTAssertFalse(model.hasNext)
        XCTAssertEqual(model.comments.count, 50)
        XCTAssertEqual(model.phase, .ready)
        let next = Task { await model.load(page: 2, isCurrent: { owner.current }) }
        for _ in 0..<20 {
            if await transport.requests.count >= 2 { break }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        await next.value
        let requestCount = await transport.requests.count
        XCTAssertEqual(requestCount, 1)
        XCTAssertFalse(model.hasNext)
        XCTAssertTrue(model.comments.isEmpty)
        XCTAssertEqual(model.phase, .idle)
    }
```


---

## GM-TEST Full Summary by Target

### Target (1): RoamPassport / RoamPrivate Host Test Classes (49 tests, 44 failures reported by P2)
- **Pre-existing proof at commit `e3ba3c1b`** (`/private/tmp/gm-test-e3ba3c1b-roam.log`, `TEST_EXIT=65`):
  - `RoamPassportHomeScopeRecoveryTests`: `Executed 7 tests, with 12 failures (6 unexpected) in 22.286 (22.291) seconds`
  - `RoamPassportServerHistoryHostTests`: `Executed 8 tests, with 8 failures (0 unexpected) in 14.060 (14.063) seconds`
  - `RoamPassportToolsGrantScopeHostTests`: `Executed 9 tests, with 10 failures (5 unexpected) in 16.902 (16.905) seconds`
  - `RoamPrivateGrantScopeHostTests`: `Executed 10 tests, with 4 failures (0 unexpected) in 4.864 (4.868) seconds`
  - `RoamPrivatePageHostRecoveryTests`: `Executed 10 tests, with 5 failures (0 unexpected) in 8.221 (8.228) seconds`
  - `RoamPrivateReadDenialHostTests`: `Executed 5 tests, with 5 failures (0 unexpected) in 7.875 (7.878) seconds`
  - **Combined at `e3ba3c1b`**: `Executed 49 tests, with 44 failures (11 unexpected) in 74.210 (74.244) seconds`
- **Root Causes & Code Fixes**:
  1. SwiftUI `List` / `Form` rows on iOS Simulator do not materialize `UIAccessibilityIdentification` nodes in the `UIView`/`accessibilityElements` hierarchy unless VoiceOver/Accessibility Inspector is active, and raw `UIWindow(frame:)` instances created in `RoamPassportHomeScopeRecoveryTests`, `RoamPrivatePageHostRecoveryTests`, and `RoamPrivateReadDenialHostTests` lacked a `windowScene`, preventing subsequent SwiftUI render updates.
  2. Existential `reader`/`tools` view properties wrapping the same object reference caused SwiftUI to skip child `View.body` evaluation when a grant or scope was replaced (`r.replaceGrant()`, `tools.isConfigured = false`), and `.id(owner)` on `RoamAnniversaryContent` destroyed the view while its child `.navigationDestination` (`RoamAnniversaryRouteHost`) was pushed, causing `InvalidTransition`.
  3. Added `RoamHostedAccessibilityGroup`, `RoamHostedAccessibilityAnchor`, and `RoamHostedScopeTracker` in `App/RoamExperienceComponents.swift` (attaching `window.windowScene` on `didMoveToWindow` when `nil`), wired accessibility groups and scope tracking across the Roam views, and updated `RoamAnniversaryView` / `RoamAnniversaryContent` to handle `pageOwner` changes via `.onChange(of: pageOwner)` without destroying the container during a pushed route.
- **After Fix** (`/private/tmp/gm-test-appunit-final3.log`, `TEST_EXIT=0`):
  - `RoamPassportHomeScopeRecoveryTests`: `Executed 7 tests, with 0 failures (0 unexpected) in 0.823 (0.824) seconds`
  - `RoamPassportServerHistoryHostTests`: `Executed 8 tests, with 0 failures (0 unexpected) in 0.472 (0.474) seconds`
  - `RoamPassportToolsGrantScopeHostTests`: `Executed 9 tests, with 0 failures (0 unexpected) in 1.593 (1.596) seconds`
  - `RoamPrivateGrantScopeHostTests`: `Executed 10 tests, with 0 failures (0 unexpected) in 0.517 (0.519) seconds`
  - `RoamPrivatePageHostRecoveryTests`: `Executed 10 tests, with 0 failures (0 unexpected) in 1.022 (1.025) seconds`
  - `RoamPrivateReadDenialHostTests`: `Executed 5 tests, with 0 failures (0 unexpected) in 0.585 (0.586) seconds`

### Target (2): `ProfileFavoriteDetailRevisionPresentationRegressionTests`
- **Before / After** (`/private/tmp/gm-test-appunit-final3.log`, `TEST_EXIT=0`):
  - Already resolved in `origin/wip/rc2-merged` (`FavoriteDetailSheet` uses `@State private var selection = 0` rather than binding tab selection to `item.revisions.count`).
  - `ProfileFavoriteDetailRevisionPresentationRegressionTests`: `Executed 3 tests, with 0 failures (0 unexpected) in 0.522 (0.523) seconds`

### Target (3): `ClubPostDiscussionReadTests.testNextPageAvailabilityUsesAcceptedPageSize`
- **Before**: Hung indefinitely (`await transport.waitForRequests(2)` never resumed under the `f9ca1f42` single-page full-list contract).
- **After Fix** (`/private/tmp/gm-test-appunit-final3.log`, `TEST_EXIT=0`):
  - `ClubPostDiscussionReadTests`: `Executed 1 test, with 0 failures (0 unexpected) in 0.140 (0.142) seconds`

### Target (4): Cloud-Written Suites (`MoneyParityRulesTests`, `TopicUnlikeFactoryTests`, `PlayRPGPresentationTests`, `IMCoopInviteCardsTests`)
- **Before**:
  - `QuestifyCoreTests` failed to compile (`/private/tmp/gm-test-core-final.log`, `TEST_EXIT=1`):
    `error: .../Tests/CoreTests/AccessGateAndSeparateConsentTests.swift:80:1 expected #else or #endif at end of conditional compilation block`
- **Fix**:
  - Added the missing closing `#endif` for `#if canImport(QuestifyCore)` at the end of `Tests/CoreTests/AccessGateAndSeparateConsentTests.swift`.
  - All four target suites (`IMCoopInviteCardsTests` in `QuestifyAppUnitTests`; `MoneyParityRulesTests`, `TopicUnlikeFactoryTests`, `PlayRPGPresentationTests` in `QuestifyCoreTests`) plus `AccessGateAndSeparateConsentTests` compiled cleanly and passed with zero code bugs exposed.
- **After Fix** (`/private/tmp/gm-test-appunit-final3.log` and `/private/tmp/gm-test-core-final2.log`, both `TEST_EXIT=0`):
  - `IMCoopInviteCardsTests`: `Executed 6 tests, with 0 failures (0 unexpected) in 0.009 (0.010) seconds`
  - `MoneyParityRulesTests`: `Executed 33 tests, with 0 failures (0 unexpected) in 0.005 (0.006) seconds`
  - `PlayRPGPresentationTests`: `Executed 10 tests, with 0 failures (0 unexpected) in 0.005 (0.005) seconds`
  - `TopicUnlikeFactoryTests`: `Executed 4 tests, with 0 failures (0 unexpected) in 0.002 (0.002) seconds`
  - `AccessGateAndSeparateConsentTests`: `Executed 8 tests, with 0 failures (0 unexpected) in 0.002 (0.003) seconds`
  - Combined `QuestifyAppUnitTests.xctest`: `Executed 59 tests, with 0 failures (0 unexpected) in 5.682 (5.700) seconds`
  - Combined `QuestifyCoreTests.xctest`: `Executed 55 tests, with 0 failures (0 unexpected) in 0.014 (0.017) seconds`
