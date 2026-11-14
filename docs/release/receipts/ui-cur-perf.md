# ui-cur-perf receipt

Handover 56. Base is `origin/ui/main` `9209d33cb2d7ceed6f95a1b9d90b556e531a63b0`. Branch `ui/cur-perf`. `ui/main` was not pushed.

`swiftc` is not installed. Nothing here is a Swift typecheck, an XCTest run, or a simulator observation. `python3 tools/check_scaffold.py` and `python3 tools/check_design_lint.py` were run before push. `docs/release/contract-failing-baseline.txt` was not edited. `ReviewedAreaSwitch` was not redeclared. `RegionalLaunchConfiguration`, `AppSession`, and `AppCompositionRoot` were not edited.

No new cache library. List artwork reuses `CYCachedAsyncImageStore` (a dedicated 64-entry instance, not `coversAndShelves`), `ObjectCardBoundedImageLoader`, and the existing ImageIO thumbnail options (`kCGImageSourceCreateThumbnailFromImageAlways`, `WithTransform`, `ThumbnailMaxPixelSize`, `ShouldCacheImmediately`) followed by a JPEG re-encode at quality 0.82. The bounded loader accepts only an exact `ObjectCardMediaPolicy.origin` (https, no redirects, ephemeral, no cookies). A URL that fails that check keeps the previous `AsyncImage` path where one still exists, or the existing placeholder. Full-size bitmaps are not stored.

Large JSON uses `PlayerFeedJSON.perform`: the decode or projection runs on `DispatchQueue.global(qos: .userInitiated)`, then the caller reads the value. That hop stays off the main actor even when a nonisolated async reader is called from a `@MainActor` view. Models are not `Sendable`; the slot stores the result and the continuation resumes with no value. `ClubCommunityService.decode` keeps its synchronous signature. Detail, member, and status envelopes that were already small stay on the caller.

## Home feed

The vertical stream was an inner `VStack` inside the page `LazyVStack`, so every loaded row was built at once. The stream `ForEach` is now a direct child of that `LazyVStack` (header, pickers, retry, empty, and load-more stay siblings). Row pitch stays 12pt. The three horizontal rails and the banner carousel were already one section each and were not turned into a second list.

`HomeFeedShelfCard`, `HomeFeedCard`, and `HomeTodayCard` opt into the cached thumbnail. Other `CYImageCard` and `QuestifyImageEntityCard` callers stay on `AsyncImage` unless they pass the same flag. The shared hero banner still uses its existing loader.

`HomeFeedService.activities`, `TopicService.list` (the document used by the feed, not topic detail), and the discovery banner/category decodes those readers call now go through `PlayerFeedJSON`.

## Discover and club lists

Already lazy, and left as lists: `DiscoveryHomeView`, `ClubHomeView`, `ClubDirectoryView`.

`DiscoveryTemplateBrowserView` had an outer `LazyVStack` whose topic and game shelves were eager `VStack`s, so one shelf built every row. Each tab is now its own `ScrollView` + `LazyVStack`, and the topic and play `ForEach` rows are written in that stack. Search chrome stays one child. Hero cards and topic thumbs use the cached thumbnail. `DiscoveryPlayRow` has no remote image.

Club photo cards and club row logos on those lists use the same cache. The club community post list (`ClubCommunityFeedView`) was a `ScrollView` + `VStack`; it is now a `LazyVStack` with the post `ForEach` as a direct child. Post images whose URL has an approved origin use the cache and still hand a SwiftUI `Image` to the existing preview. Other post URLs stay on `AsyncImage`. The linked-topic cover on that tile uses the cache. Review and history screens were not restructured.

`ClubService` home, owned, and directory payloads, `DiscoveryService` template home / play templates / topic templates, `ClubCommunityService.read`, and `ClubTabPageModel.project(homeBody:)` run off the main actor. Club detail, members, and post status decodes stay on the caller.

## IM list

`MessagingConversationListView` was already a `List` (inset grouped, 30 rows then “more”). It was not rewritten. Conversation rows use generated cover art. There is no remote avatar loader on this list, so nothing was cached there.

`MessagingService.execute` success envelopes (the conversation list and message pages) decode off the main actor. `MessagingReadFailure` from a non-200 `code` still propagates. The failure-status envelope stays on the caller.
