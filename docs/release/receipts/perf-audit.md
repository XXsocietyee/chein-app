# Performance static audit (DES-e5)

Scope: code-only audit of the files in `tail-all-sorted.txt`, `App/DesignSystem/*`, `App/DesignFixtures/*`, and the 10 most visited screens
(home, search, roam, activity detail, route detail, order detail, club detail, chat, me, wallet). Merged `origin/ui/main` first (already up to date).
Files changed on any `origin/ui/cloud-*` branch (243 of the 415 candidates, including `ActivityDetailView`, `AccountView`) were skipped as instructed;
171 files / ~32k lines were scanned. No local build; verification is the cloud check-runs on the pushing commit.
Method: pattern scans (ForEach identity, AnyView, formatters, shadows, GeometryReader, AsyncImage, lazy containers, animation scope, observation) plus a read of the hot screens.

## Fixed (minimal, no behaviour change)

| File | Issue | Fix |
|---|---|---|
| `App/ActivityBrowserView.swift` `AmountLabel` | A new `NumberFormatter` was built on every render of every activity row price | Formatter cached per locale identifier (same style and 2-digit fraction settings) |
| `App/DesignSystem/CYDesignComponents.swift` card surface | `.elevated` cards applied a radius-10 shadow with a `.clear` colour in dark mode, which still costs an offscreen blur pass per card | Radius and offset are 0 unless the shadow is actually drawn (light + elevated). Visual output is identical |

## Clean (checked, nothing to do)

- `AnyView`: only in `DesignFixtureRegistry` (fixture dispatch) and `CooperationBrowserView.topicDestination` (a public closure type; changing it alters the call-site API).
- Long lists: browser/home/messaging/order/square/roam results use `List`, `LazyVStack`, `LazyHStack` or `LazyVGrid`. No long non-lazy `VStack` list found in the scanned set.
- `GeometryReader`: 6 uses, none wrapping a list (map chrome sheet, confetti, walking nav, publishing handoff, motion lab).
- Animations: all `.animation` calls are value-scoped and sit on small views (button styles, banner dots, sheets). None on a large container.
- `id: \.self` is used on `allCases`, static string arrays and enums (stable). Remaining `id: \.offset` is on static or append-only arrays.
- Big shadows (radius ≥ 12) appear only on single overlays (`CYMapChrome` sheet and chrome, collectible stamp), not on list rows.
- No `.blur`, `drawingGroup` or `compositingGroup` in scope. `TimelineView(.animation)` in the confetti is paused when idle.

## Not fixed (listed for owners)

1. **Raw `AsyncImage` without a cache or downsampling**: `CYHeroBanner.cover` (~L87), `CYImageCard.cover` (~L116), `CYAvatar`-style view in `CYDesignComponents` (~L491), `RoamHomeTabsView` (~L255), `RoamPassportPrivateToolsViews` (~L288), `RoamSubpageParityViews` (~L527), `SocialPublicProfileView` (~L388), `ClubDetailView.ClubDetailCover` (~L378).
   Not swapped to `CYCachedAsyncImage`: it never fetches on its own and needs an injected loader plus an image gate, so the swap changes behaviour. Needs a design-owner decision (a shared loader), or the iOS 27 `AsyncImage` cache.
2. `ForEach(Array(x.enumerated()), id: \.element.id)` rebuilds an array on each body in `ActivityBrowserView`, `OrderLifecycleView`, `CYHeroBanner`. It is cheap at page size; the index is needed for the stagger effect. Low priority.
3. `ActivityBrowserView` `.cyAnimation(value: model.items.map(\.id))` allocates an id array on every body. Low priority (page-size lists); could be a precomputed `[Int]` on the model (Core-owned).
4. `SearchMapExplorerView` ~L105 `pins.filter { $0.id == selectedPin }.count == 1` runs inside body; `pins.count` is small but an `O(n)` per-update scan. Equivalent only if ids are unique, so left alone.
5. `ClubDetailView.detailFacts` serialises JSON and builds a page model on each call (headline meta). Should move into the model; behaviour risk if inlined here.
6. `ClubDetailView<Reader: ObservableObject>` and other screens hold whole-object `@ObservedObject`/`@StateObject` models (138 usages in scope), so any published change re-evaluates the full screen. Splitting into `@Observable` or smaller models is Core/model work.
7. `ModVenueOperationsView` creates `ISO8601DateFormatter()` per element in form setup and parsing (user-action path, not render). Low priority.
8. `NativeChannelNotificationConversationView` L237 builds and sorts the full time-zone identifier list inside a Picker body each render. Move to a static constant; picker only, low traffic.
9. `CYImageCard` shadow (radius 8 per card) and `CYCollectible` stamp shadow (radius 16): fine individually; if shelf scrolling shows hitches, replace with a pre-rendered or border-only treatment.
