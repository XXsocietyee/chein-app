# cursor/perf-r8 — second static performance pass

Base: `origin/ui/combined-r7` at `aee32a61f0f69b880bc9e33811463ccc73351bbe` (`fix: 给 Core 的七处 Swift 6 并发警告补最小标注`, 2026-11-24 10:43:10 -0800).

`origin/cursor/perf-r7` at `6ebdcafb9dec` is already an ancestor of this base. Those ten fixes stay as they are. This pass does not repeat them.

This pass did not run `swiftc`, Xcode, or XCTest. The notes below are a source reading plus the edits, not a typecheck and not a test run.

## Static-pass method

Production Swift under `Core/` and `App/` only. `Tests/`, `Vendor/`, and fixture trees were skipped. The same three checks as r7:

1. Image caches. Search for stores that retain image bytes, and for image readers that start a transfer with `urlCache = nil` and no in-flight join.
2. Eager stacks. Walk `ScrollView` bodies. A `ForEach` counts as lazy only when it is a direct child of `LazyVStack` / `LazyHStack` and every stack between that child and the `ScrollView` is lazy. Skip `ForEach` over `allCases`, a `prefix`, or a fixed small range. Skip chip and tab rows, a `ForEach` inside `CYCard`, and a `Grid`.
3. Duplicate Core reads. A read with no in-flight map sends again when two callers overlap. Writes, payment, wallet, coupons, and fenced reads stay out of the join set.

`CYCachedAsyncImageStore` already has the r7 count cap, 8 MB total, and in-flight coalesce. `ObjectCardBoundedImageLoader` already joins. The next image transfers that still start twice are the per-call retained public reader and the per-call social message media service.

## Fixes

1. `SquareService` (`Core/SquareService.swift`) keeps an instance `InFlightReadCoalescer<InFlightHTTPBody>`. `feed`, `get`, and `post` join. Feed and `get` key on the path, sorted query items, and token. `post` keys on sorted form fields, so the multipart boundary is not part of the key. Status checks (`401`, HTTP, envelope code 200, `SquareReadFailure.server`) stay outside the join. Delete and own-id reads still go through `CreativeSquareAuthorDeleteClient`.
2. `SearchMapService` joins `form`, `json`, `get`, and `publicLayers` on its own instance. The JSON key uses sorted keys; the body that is sent stays the unsorted `JSONSerialization` bytes. `publicLayers` still checks size and `aggregatedQueryEnabled` before the join, then joins on the exact body. `merchant(id:)` still builds a throwaway `RoamService` and does not use this coalescer.
3. `RoamService` joins `get`, `post`, and `merchantDetail`. `merchantDetail` uses one JSON body for the key and the request. `nodeDetail` error mapping (410, 节点不存在 / 据点不存在) stays outside the join and is not part of the key. `writeMutation`, `toggleFavorite`, `completeNode`, and `exchangeStamp` are not joined.
4. `MessagingService.execute` joins `conversations` and `messages` on sorted form fields plus the token. HTTP status and envelope decode stay outside the join.
5. `RoamExperienceService` joins `album` (`POST api/roam/stamp/list`) and `get` (session, tiles, historical tiles, shop badge). The GET URL is built before the join; the send is inside it.
6. `CreatorContentService.post` joins the read paths (`api/project/my`, registration merchant list, `chapter-application/mine`, `api/creator/center`). Token validity is checked before the join. `401`, HTTP status, and `CreatorContentReadFailure.rejected` stay outside.
7. `ProfileEditService.read` joins `POST api/user/info`. The key is the path plus the token, so the random `ProfileRead-` boundary is not part of the key. The boundary is still generated inside the join, once per flight. `save` and `saveAvatar` are not joined.
8. `SocialMessageMediaService` (`Core/SocialMessageMedia.swift`) joins on a static `InFlightReadCoalescer<InFlightHTTPBody>` keyed by `media.url.absoluteString`. Call sites build a new service per image. Origin check and `authorize` run before the join. Status, `maximumBytes`, and the JPEG / PNG / GIF / WEBP signature stay outside. The request still sends no cookies and no `Authorization`. The value is dropped when the flight finishes.
9. `RetainedPublicImageReader.image` stays `@MainActor` and still rejects a disabled reader or a refused origin before any transfer. The download itself is `RetainedPublicImageFlights`, a file-private nonisolated enum with a static `InFlightReadCoalescer<Data>`, so the join closure is not MainActor-isolated. `urlCache` stays `nil`. Two callers of the same absolute URL share the transfer already running.
10. `PublicCatalogViews.content` changes the page stack under `ScrollView` from `VStack` to `LazyVStack` (leading, `CYSpacing.lg`). The chapter `ForEach(Array(chapters.enumerated()), id: \.offset)` is the only view in its `if`, so it is a direct child of that lazy stack. This screen is outside the six area pages.

No new tests, no `project.pbxproj` edit, no `tools/current_ci_manifest.json` edit. The coalescer type is still `InFlightReadCoalescer` in `Core/PlayerFeedJSON.swift`.

## Findings left

Area pages, one line each. Not edited.

- `App/HomeFeedView` (player-content): stream `ForEach` is still inside an inner `VStack`, so the page `LazyVStack` does not lazy-load those rows.
- `App/DiscoveryHomeView` and `App/DiscoveryTemplateBrowserView` (player-content): shelf and tag `ForEach` still sit in eager stacks.
- `App/TopicXcxSections` (player-content): members `HStack` `ForEach` is still eager inside a horizontal `ScrollView`.
- `App/SquareXcxPostCard` (player-content): item `HStack` `ForEach` is still eager.
- `App/ClubCommunityViews` (club): comment and history `ForEach` still sit in eager `VStack`s.
- `App/ClubChannelMessagingView` (club): channel `ForEach` is still in an eager `VStack`.
- `App/SearchRoutePreviewView` (play-roam): route-step `ForEach` is still in an eager `VStack`.
- `App/RoamHistoryViews` (play-roam): medal and poi `ForEach` are still in eager `VStack`s.
- `App/FreeExplorationViews` (play-roam): visible-node `ForEach` is still in an eager `VStack`.
- `App/ChapterStoryView` (play-roam): segment `ForEach` is still in an eager `VStack`.
- `App/CastViews` (play-roam): cast `ForEach` is still in an eager `VStack`.
- `App/MerchantReviewPhotoGallery` (merchant-coop): photo `HStack` `ForEach` is still eager.

Behaviour left as it is:

- `App/RetainedImageContextCache.entries`: no count or byte cap. Evicting an unlocked entry can drop a live picker.
- `Core/PublicTopicTemplateDetail.swift` `PublicTemplateDetailOwner.entries`: no coordinator cap. Dropping a coordinator that is still on screen restarts its loads.
- `CYHeroBanner`, `CYImageCard`, `CYCarouselArt`, and the business-component covers still use `AsyncImage` / `URLCache.shared`. Pointing them at `PlayerFeedRemoteImage` would change the placeholder and the decoded bitmap.
- `App/NativeMediaGallery`: the strip is `prefix(100)` inside an `HStack`. The full-screen `TabView` still builds every page. Left because a lazy strip would change the compact layout.
- `CYChipRow`, `CYTabs`, and the short chip rows in `CYBusinessComponents`: a lazy stack would change layout.
- `App/TeamHomeView` members and `App/CharacterSheetDetailView` attributes: the `ForEach` sits inside `CYCard`. Hoisting it would restyle the card.
- `App/DesignSystem/CYSheetModal.swift` `CYOptionSheet`: the option `VStack` is not inside a `ScrollView`.
- `Core/PlayExperienceCoordinator.load()`: the generation fence stays out of the join.
- `Core/IMUnreadTotal.swift` `total`: one small POST. Left in favor of the image and feed joins above.
- Fenced reads stay out: `ProfileFollowListService`, `NativeFriendService`, `ClubCommunityReadRuntime`, `MemberIdentityAvatarTransport`, `OwnMediaPrivateImageReader`, `ProfileSavedMediaURLSessionTransport`. Joining them can hand a body to a caller after revocation.
- Money and gates stay as they are: `TicketWallet`, `NonCashReward`, `Wallet`, coupons, bundle reservations and wallet, bank withdrawal, host tip, pass market, and `SocialAccountService` points (`api/user/points/list`).
