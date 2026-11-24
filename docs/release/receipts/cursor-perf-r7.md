# cursor/perf-r7 — static performance pass

Base: `origin/ui/combined-r7` at `7fdfad1f177fadb76f7fd54a82b27fa69b82f1f8` (`integrate(r7): fix Gemini compile errors (11 + arrayValue); park App/MPGap screens until the 31 remaining are fixed`, 2026-11-24 06:51:52 -0800).

This pass did not run `swiftc`, Xcode, or XCTest. The notes below are a source reading plus the edits, not a typecheck and not a test run.

## Static-pass method

Production Swift under `Core/` and `App/` only. `Tests/`, `Vendor/`, and fixture trees were skipped.

1. Image caches. Search for `UIImage`, `NSCache`, and dictionaries or arrays that retain `Data` or image bytes (`entries`, `cache`, `images`). For each hit, record whether a count cap and a total byte cap exist, and whether an in-flight duplicate starts another transfer.
2. Eager stacks. Walk `ScrollView` bodies and list `VStack` / `HStack` whose `ForEach` is fed by a page, history, comment, or other collection that grows with the server. Skip `ForEach` over `allCases`, a `prefix`, or a fixed small range. A `ForEach` counts as lazy only when it is a direct child of `LazyVStack` / `LazyHStack` and every stack between that child and the `ScrollView` is lazy.
3. Duplicate Core reads. Read each Core service `post` / `get` / `load` that calls `transport.send` or `URLSession`. A read with no in-flight map will send again when two callers overlap. Writes, payment, and `PlayExperienceCoordinator.load()` (generation fence) stay out of the join set.

Image stores found: `CYCachedAsyncImageStore` (count plus 8 MB per entry, no total bytes), `RetainedImageContextCache.entries` (no count or byte cap), `PublicTemplateDetailOwner.entries` (one coordinator per template id, no cap), `FogMaskCache` (one mask), `MapWeatherModel` (already capped at 64 cells). URL-session image readers set `urlCache = nil` and did not share an in-flight transfer.

Eager `ForEach` hits were classified by area. Area screens (member, account-publish, merchant-coop, club, player-content, play-roam) are listed under findings left and were not edited.

## Fixes

1. `CYCachedAsyncImageStore` (`App/DesignSystem/CYCachedAsyncImage.swift`) now keeps a total byte budget, `maximumTotalBytes` (8 MB, the same ceiling as one entry). `insert` evicts least-recently-used entries while more than one entry remains and the count or the byte budget is over. A single image larger than the budget is refused before decode. `Tests/AppUnitTests/CYCachedAsyncImageTests.swift` covers eviction and refusal.
2. The same store coalesces an in-flight load by key (`coalesce` / `isCoalescing`). `CYCachedAsyncImageModel.resolve` and `PlayerFeedImages.image` go through it, so two covers or two feed thumbnails of the same key share one body. The value is not kept after the body finishes. `testOverlappingResolvesShareOneLoad` covers the cover path.
3. `ObjectCardBoundedImageLoader` (`Core/ObjectCardMedia.swift`) joins identical absolute URLs on a static `InFlightReadCoalescer<Data>`. Call sites still construct a new loader. The loader still sends no cookies, no credentials, no redirects, and no stored response cache (`urlCache = nil`).
4. `TopicService` `post` and `get` join on `InFlightReadCoalescer<InFlightHTTPBody>`. Form keys use sorted fields, so the random multipart boundary is not part of the key. The token is part of the key and is not logged. Status checks stay outside the join, so a finished read is dropped and the next call sends again.
5. `DiscoveryService.post` joins the same way. The key tag records whether the body is the empty JSON object, so that request does not share a multipart post of the same path. Template error mapping stays outside the join.
6. `ClubService.post` builds the sorted JSON body once and joins on those bytes plus the token.
7. `ActivityService.post` joins the transport body and decodes outside the join.
8. `HomeFeedService.activities` joins `api/activity/list`. Banners, categories, and topic pages use the `DiscoveryService` and `TopicService` instances this service already owns, so those reads pick up fixes 4 and 5.
9. `CityTaskHistoryView` changes the page stack under `ScrollView` from `VStack` to `LazyVStack` (spacing 16, leading). `ForEach(controller.items)` is a direct child. This screen is outside the six area pages.
10. `IMConversationReadAllView` changes the page stack and the conversation stack to `LazyVStack`, keeping `CYSpacing.xxl` and `CYSpacing.md`. `ForEach(model.items)` is a direct child of the inner lazy stack. This screen is outside the six area pages.

`InFlightHTTPBody`, `InFlightReadKey`, and `InFlightReadCoalescer` live in the existing `Core/PlayerFeedJSON.swift` file. No new folder, no `project.pbxproj` edit, no `tools/current_ci_manifest.json` edit. Core tests are `Tests/CoreTests/InFlightReadCoalescerTests.swift` (SPM directory). They cover one shared body, distinct keys, a finished read starting again, a shared failure then a later success, field order and token in the key, sequential banner sends, overlapping banner sends, and two tokens.

## Findings left

- `App/HomeFeedView` (player-content), stream `ForEach`: move that `ForEach` out of the inner `VStack` so it is a direct child of the page `LazyVStack`.
- `App/ClubCommunityViews` (club), comment and history `ForEach`: change the `ScrollView` content stack to `LazyVStack` and keep each `ForEach` a direct child.
- `App/DiscoveryHomeView` and `App/DiscoveryTemplateBrowserView` (player-content), shelf and tag stacks: change those stacks to lazy stacks with each `ForEach` as a direct child.
- `App/SearchRoutePreviewView` (play-roam), route steps: change the scroll content stack to `LazyVStack`.
- `App/RoamHistoryViews` (play-roam), medals and pois: change those stacks to `LazyVStack`.
- `App/TopicXcxSections` (player-content), members `HStack`: use `LazyHStack` inside the existing horizontal `ScrollView`.
- `App/MerchantReviewPhotoGallery` (merchant-coop), photo `HStack`: use `LazyHStack` inside the existing horizontal `ScrollView`.
- `App/RetainedImageContextCache.entries`: no count or byte cap. Left because evicting an unlocked entry can drop a live picker.
- `Core/PublicTopicTemplateDetail.swift` `PublicTemplateDetailOwner.entries`: no coordinator cap. Left because dropping a coordinator that is still on screen restarts its loads.
- `App/DesignSystem/CYSheetModal.swift` `CYOptionSheet`: the option `VStack` is not inside a `ScrollView`. Wrapping it would restyle the sheet.
- `CYChipRow`: the chip `HStack` is a short row. A lazy stack would change layout.
- `Core/PlayExperienceCoordinator.load()`: the generation fence must not be joined, or a waiter would observe a stale generation.
- `App/TeamHomeView` members: the `ForEach` sits inside `CYCard`. Hoisting it would restyle the card.
