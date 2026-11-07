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
