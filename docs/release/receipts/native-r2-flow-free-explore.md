# Receipt: native-r2/flow-free-explore (自由探索, step 3)

Branch `native-r2/flow-free-explore`, from `origin/ui/combined-r7` (2446657fb). **Held until owner approval** (step 3 waits on the step-2 designs); pushed for review only.

Inputs: `design/handoff-r2:docs/briefs/native-r2.md` ("EVERYTHING native"), `docs/briefs/COORDINATOR-HANDOVER.md` §4, spec `design/native-r2-free-explore:docs/design/native-r2/free-explore.md` (84c15ba6c, re-checked after 20 min, unchanged).

## What is built (Apple components only)

All new screens are in `App/NativeR2/FreeExplore/` and sit behind `NativeR2Flags.freeExplore` (`App/NativeR2/NativeR2Flags.swift`, default `true`). Switching it off brings back the old screens unchanged.

| Screen | New file | Routed from (existing entry point) | Components |
|---|---|---|---|
| Bundle detail | `NativeFreeExploreBundleDetailView.swift` | `FreeExploreTopicCatalogScreen` (every `free-explore?topicId=` link) | inset-grouped `List`; header `Image` (`MPAsset.BannerCover.coverRoute`); `LabeledContent` facts (章节, 门店, 预约, 销售); one `Section` per chapter with a `LabeledContent` row per store; bottom-bar `ToolbarItemGroup` with the price / sale status and one `.borderedProminent` 开始探索; `.refreshable`; loading = the same list `.redacted(.placeholder)`; signed-out / failed = `ContentUnavailableView` |
| Next-stop map | `NativeFreeExploreMapView.swift` | `PlayExperienceView` mode 2 (`gameplayMode == .freeExploration`) | full-screen `Map` with `UserAnnotation`, one `Annotation` per store (done ✓ / next ⦿ / locked 🔒 / open), `MapPolyline` in backend order, `.mapControls { MapUserLocationButton; MapCompass; MapScaleView }`; bottom `.sheet` with `[.height(120), .medium, .large]`, `.presentationBackgroundInteraction(.enabled(upThrough: .medium))`, `.interactiveDismissDisabled()`; next-stop card (name, state, hook, crowded), `ProgressView(value:total:)` for redeemed, `LabeledContent` for stories unlocked, 步行前往 (`.bordered`) and 跳过 (`.bordered`) and one `.borderedProminent` (我已到达 or 查看门店); a stop `List` with swipe action 我已到达 and context menu 在地图上显示; rewards, ending and archive as plain `Section`s |
| Stop arrival unlock | `NativeFreeExploreArrivalSheet.swift` | 我已到达 on the map card / stop row | `.sheet` `[.medium, .large]`, `NavigationStack` + `List`, unlock rule as the section footer, status rows per `PlayArrivalService.Phase`, `.borderedProminent` 我已到达, `.sensoryFeedback(.success)` on unlock |
| Stamp capture | `NativeStampCaptureView.swift` | `RoamStampCameraView` (every caller, incl. `SessionRoamStampCameraView`) | existing `RoamNativeStampCamera` in `.fullScreenCover`; review `Form` (photo, status `LabeledContent`, caption `TextField(axis: .vertical)` with count / limit in the footer); toolbar 重拍 (`.cancellationAction`) and 存入集邮册 (`.confirmationAction`); `.borderedProminent` 拍照 in a `.bar` inset; camera denied = `ContentUnavailableView` + 去设置; exchange result as `LabeledContent` rows (出发, 签号, 留签人, 留于) and a 留给你的一句 section |
| Stamp album | `NativeStampAlbumView.swift` | `RoamStampAlbumView` (all callers: Account, Roam hub, collection album, created-stamp page, live session, MP-reviewed pages) | `LazyVGrid(.adaptive(96))` of circular images (`clipShape(Circle())`) with a caption (or date) under each; `Picker(.segmented)` 全部 / 邮票 / 照片; count as `LabeledContent`; exchange row (换来的邮票 → existing `RoamReceivedStampMetadataDestination`); `ContentUnavailableView` for empty / denied / error / filter-empty; `ProgressView` paging; toolbar camera link |

## Behaviour kept (no new requests)

- Bundle: the screen still owns `FreeExploreLaunchService.catalog(topicID:)`; same reload key, same BUNDLE_LEDGER_OFF rule (刷新 hidden). 开始探索 opens `SessionTopicDetailView`, which keeps the existing purchase / registration gate. **Payment gate unchanged.** The catalog read has no price, so the bottom bar shows 在售 / 暂未开售 (`priceText` is wired for when a host has one).
- Map: `PlayExperienceCoordinator.load()`, `loadFreeExplorationEnding()`; arrival through `PlayArrivalService.arrive` (one fix, `PlayArrivalPolicy` radius, `/api/play/arrive`; unknown re-reads, never re-sends). Store pages are still `FreeExplorationStoreView` via `storeDestination` (NPC, device tasks, store day, story unchanged). Tools menu (切换章节, 紧急求助), chapter filter, reward rows, ending, cast ending, archive (offline / expired) all kept. Identity / mode change resets local state, as before.
- 步行前往 uses the same policy-gated `PlatformExternalMaps` (`select`, reviewed `openReviewedDestination`) as the store page.
- Capture: identical `RoamStampCaptureCoordinator` sequence (`upload` → `performWriteOptIn` → `create` with the same key → optional `exchange`), the same SCAM-2 auto-open, `CYPermissionSystemPrompt.precede(.camera)` before the system prompt, celebration enqueue, offline write banner, created-stamp page.
- Album: the same `RoamAlbumReadPresentation` / `RoamAlbumPager` (50 per page), read-only scope, remote-image policy, `StampAlbumErrorPresentation`, last-tile paging, received-stamp owner checks. The filter is local over `kind` (0 photo, 1 stamp).
- accessibilityIdentifiers kept: `freeBundle.topicCatalog*`, `freeBundle.catalog.notOnSale`, `playFree.overview`, `playFree.refresh`, `playFree.store.<id>`, `playFree.redeemed.count`, `playFree.story.unlocked.count`, `playFree.reward.*`, `playFree.archive.place.<id>`, `playArrival.action`, `platform.map.open`, `media.stamp.*` (capture, caption, caption.limit, caption.remaining, caption.section, cameraDenied, openSettings, cameraIssue.back, exchange, createDormant, upload, retake), `roam.createdStamp.open`, `roamSub.w208.stamp.done/noExchange`, `roam.experience.album*` (total, stamp, empty, openCamera, fab, more, denied, unknown, scopeExpired, notice), `roam.experience.error/retry`, `roam.receivedMetadata.open`. New: `nativeR2.freeExplore.*`, `nativeR2.stamp.capture`.

## Decisions / deviations to review

1. **"Next stop" vs spec §0.** The spec says free explore has no next-stop card (MP deleted `.nextcard`). This task asked for one, so "next" is **local only**: the first store in backend order that is not done and not unavailable; 跳过 moves to the following one without any request. Nothing about order is sent to the server. If the owner keeps the §0 decision, drop the card section in `nextStopSection` (the map and list stay).
2. The card pack (tear / deal animation) is not shown: the stores are visible at once in backend order (spec §5 "smoother").
3. Map pins use system colours (green done, accent next, secondary locked, red open) and SF Symbols, not MP pin images (spec §0 default).
4. The custom in-view camera primer sheet is not drawn; `CYPermissionSystemPrompt.precede` still runs the existing one-time primer before the iOS prompt.
5. The exchange receipt's tear / scratch printer (`RoamStampSlipView`) is replaced by plain rows, so 收下，出发 is enabled at once (no reveal step).
6. Album tiles are circles as asked (the spec §11 suggested Photos squares).
7. `PlayExperienceView` still applies `.cyDomainScreen(.game)` and `.tint(CYColor.gameAccent)` around the play screen (coordinator-owned theme); the brief says player pages follow the system appearance. Left for the coordinator.
8. `tools/generate_project.py` now globs `App/NativeR2/**/*.swift` (other native-r2 flow lanes need the same line; same edit, trivial merge). `NativeR2Flags` lives in `App/NativeR2/NativeR2Flags.swift`; other lanes adding flags should add a `static let` to this enum rather than a second type.
9. Unused but harmless string key `nativeR2.freeExplore.capture.purpose` was added with the fragment.

## Strings

37 new keys `nativeR2.freeExplore.*` in `Resources/Localizable.xcstrings` and `docs/port/strings/native-r2-free-explore.json` (xcstrings-shaped, merged with `tools/merge_localization_fragments.py`, 0 overridden). Everything else reuses existing keys.

## Gates

- `python3 tools/generate_project.py` then `python3 tools/check_scaffold.py`: `PASS structural checks: 5135 Swift source files, 18903 bilingual keys, references, scheme, read-only expected project equivalence`.
- **No Swift compiler in the cloud.** Every type, init and modifier was grepped against the repo (or is iOS 17 SwiftUI/MapKit: `Map(position:selection:)`, `Annotation`, `MapPolyline`, `UserAnnotation`, `MapUserLocationButton`, `MapCompass`, `MapScaleView`, `ContentUnavailableView`, `presentationBackgroundInteraction`, `sensoryFeedback`; deployment target is 17.0). Handover §4 traps checked: no local shadowing a method (renamed `open` → `candidates`), no tuple-keyed `ForEach`, no `String(localized:)` literals, no hex colours, no interpolated `LocalizedStringKey`, no `else` branches in `@ToolbarContentBuilder`, memberwise init order matches the call site, no new enum cases. **Needs a simulator build** (XcodeBuildMCP `build_sim`) before merge.
