# cursor/1128-perf — static performance pass

Base: `origin/ui/combined-r7` at `c4e43841afaddd576a72104f8bf8641af2060732` (`fix: K13 RuntimeDependencyConfiguration argument order (devices, sensors, artworkHosts); contract pin updated`, 2026-11-28 07:20:56 -0800). The branch was created from that tip. Nothing was rebased and nothing was force-pushed. `main` was not pushed.

`cursor/perf-r7` and `cursor/perf-r8` are already ancestors. Those caps and joins stay. This pass does not repeat them and does not change `App/AppSession.swift` (still 7977 lines). `DiscoveryService` still receives `coalescesReads: false` from the session. `ClubService` still defaults `coalescesReads` to false.

Merchant stays gated. Money switches stay as they are. Coupon reads (`api/coupon/myrecvlist`) are not joined. No `String(localized:)` literals were added. Screen edits are the list-container type only (`HStack` to `LazyHStack`), with the same alignment and spacing.

## Static-pass method

Production Swift under `Core/` and `App/` only. The same three checks as r7:

1. Image caches. Count cap plus a byte budget, and an in-flight join for a transfer that starts with `urlCache = nil`.
2. Eager stacks. A `ForEach` is lazy only when it is a direct child of `LazyVStack` / `LazyHStack` and every stack between it and the `ScrollView` is lazy. Skip `allCases`, `prefix`, fixed small ranges, chip and tab rows, a `ForEach` inside `CYCard`, and a `Grid`. A `ForEach` inside an `if` is not a direct child of the outer stack, so the outer stack was not changed.
3. Duplicate Core reads. Join an in-flight read only. Writes, payment, wallet, coupons, and fenced reads stay out. Status and decode stay outside the join, so a finished read is dropped and the next call sends again.

`CYCachedAsyncImageStore` already has the r7 count cap, 8 MB total, and in-flight coalesce. `PlayerFeedImages.store` uses that budget. `ObjectCardBoundedImageLoader`, `RetainedPublicImageReader`, and `SocialMessageMediaService` already join. `WeatherKitReader` already caps at 32. `ProgressiveArtworkRenderer` already caps 16 MB / 2 entries. `RequestReferenceLedger` already caps at 32.

## Fixes

1. `ProfileService` (`Core/ProfileService.swift`) keeps an instance `InFlightReadCoalescer<InFlightHTTPBody>`. Orders, participants, the badge wall, and `postOwnedOrderForm` share `send(_:)`. The key is `InFlightReadKey.request`, which drops the random multipart boundary and keeps the method, path, query, and token. `execute` still decodes outside the join. Its signature is unchanged.
2. `PlayerJourneyService` joins `finish` (participations, detail, completed, member template, completed for a public reference). `readsEnabled` still defaults to false and still throws `APIError.notConfigured` before any send.
3. `OfficialEventService` joins `eventsReceipt` and `get` through one `send(_:)` helper. `httpMethod = "GET"` still appears exactly twice. No request body was added.
4. `GrowthCenterService.read` joins the center, tasks, level, and leaderboard GETs, including the anonymous urlencoded body. The anonymous split and `leaderboardContract: GrowthLeaderboardReadContract = .legacy` stay.
5. `IMUnreadTotalService.total` joins on a static coalescer. The session builds a new service on every badge read, so an instance map would never meet. `httpShouldHandleCookies = false` stays on the request before the join. Decode stays outside.
6. `AccountCollectionService` joins favorite topics and favorite posts. `coupons()` calls `post(..., joins: false)`, so overlapping coupon reads still send twice. The three `post("api/...")` paths stay `api/topic/like_list`, `api/coupon/myrecvlist`, and `api/creativesquare/list`.
7. `PublicTemplateDetailOwner` caps idle coordinators at 32, oldest first. A repeat visit moves that id to the end. The id just requested is not dropped. A coordinator with `isLoading == true` is not dropped, so an on-screen load is not restarted to make room. A dropped idle coordinator is `invalidate()`d. `invalidate()` also clears the recency list.
8. `TopicChapterCardsSection` changes the horizontal chapter-card stack from `HStack` to `LazyHStack`. Alignment and spacing stay `.top` and `CYSpacing.md`. `ForEach(cards)` is a direct child.
9. `DiscoveryTemplateDetailView` node shelf changes its horizontal stack from `HStack` to `LazyHStack` (`.top`, `CYSpacing.md`). The gallery `let` stays between the stack and the `ForEach`. Both lines are after the `Uses only the server` marker.
10. `DiscoveryTemplateDetailView` image mosaic changes its horizontal stack from `HStack` to `LazyHStack` (`CYSpacing.sm`). The mosaic `ForEach` is a direct child. The head-row `HStack` above the marker was not changed.

`InFlightReadKey.request` lives next to the existing key helpers in `Core/PlayerFeedJSON.swift`. Tests: `Tests/CoreTests/ReadCoalescingPassTests.swift` (one overlapping send, a later call sends again, a different token does not join, coupon overlap still sends twice, boundary is not part of the key) and three owner-cap cases in `Tests/CoreTests/PublicTopicTemplateTests.swift`. No `project.pbxproj` edit. Core tests are not an Xcode source-membership target.

## Findings left

- Fenced reads stay unjoined: `PlayExperienceService` (`checkReadLifetime`), `PrivateHomeService` (gate), `OwnMediaPrivateImageReader`, and `MemberIdentityAvatarTransport`. Joining those can hand a body back after revocation.
- Writes, payment, wallet, `TicketWallet`, and `NonCashReward` stay unjoined. `StoreCharacterService` was left: the two parallel reads use different paths, and the production holder is already one service.
- `RetainedImageContextCache` stays uncapped. Evicting an unlocked entry can drop a live picker (r8).
- Chip, tab, `allCases`, and `prefix` rows stay eager.
- A `ForEach` inside `if` or `CYCard` was not made lazy by changing the outer stack (`SearchRoutePreviewView`, `RoamHistoryDetailView`, `FreeExplorationViews`).
- `App/RoamHistoryViews.swift` and `App/MerchantReviewPhotoGallery.swift` stay untouched. Their bytes are pinned by contract tests.
- `ChapterStoryView` keeps its eager segment column. Scroll-position preferences depend on those rows existing.
- `RoamFinishStampStrip` (`App/RoamStampPhotoStrip.swift`), the square upcoming-registration `HStack`, roam home cards, and the roam city guide stay eager. They are the next horizontal shelves after the three taken here.
