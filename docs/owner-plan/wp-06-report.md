# WP-06 report

## Files written
- Core/DirectMessageSendGate.swift (new)
- Core/ContactFrequencyLimiter.swift (new)
- Core/NativeFriendFlow.swift (edit): `isPeerBlocked` hook (nil default), `NativeFriendRequestPolicy`, `NativeFriendRejectMessage`; reject-code -> issue key now via the mapping
- Core/NativeBlacklistService.swift (edit): `NativeBlacklistRelationPolicy` (appended only)
- Tests/CoreTests/WP06DMSendGateTests.swift, WP06ContactFrequencyLimiterTests.swift, WP06FriendBlockPriorityTests.swift
- docs/owner-plan/wp-06-new-strings.md (new key `friend.reviewUnavailable`)

## Tests written
WP06DMSendGateTests: testExistingNonFriendSessionStillSendable, testBlockedSenderRefused, testBannedRefused, testSelfRejectRefused
WP06ContactFrequencyLimiterTests: testSecondContactInsideWindowRefused, testWindowResetsWithInjectedClock, testBlockEndsContactImmediately
WP06FriendBlockPriorityTests: testRequestToBlockedPeerNeverSent, testUnblockDoesNotRestoreFriendship, testReviewFailClosedMapsToUserMessage

## NOT verified
- Nothing was compiled or run (Linux cloud, no Swift toolchain). Layer reached: source written only.
- Tests were not run red-first.
- That server code 403 is the Apple-only/phone-only fail-closed review code is an assumption; no doc pins the code.
- "self-rejected" is modelled as the viewer's own DM-reject preference (`selfRejected` fact); the WP does not define it.
- `isPeerBlocked` is not wired to any caller (AppCompositionRoot is off-limits), so the production flow is unchanged until wired.
- New key `friend.reviewUnavailable` is absent from the catalog; 403 rejects show the raw key until it is added.
- The gate and limiter are not yet used by any messaging path; NativeFriendFlow perform/reviewRequest block paths are covered only via the pure policy helpers, not the @MainActor flow.
- Existing tests asserting "friend.rejected" for 403 were not found by grep, but not run.
