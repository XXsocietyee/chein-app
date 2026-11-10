# View state machines (CYPhase)

Code: `App/DesignSystem/CYPhase.swift`. Goal: replace `loading` / `issue` / `failed` boolean soup with one enum so impossible
combinations (loading AND failed, failed AND loaded) cannot be represented or rendered. UX: one visible state per screen.
DX: one source of truth, read-only computed accessors for call sites. AX: a state table an agent can read, plus a VoiceOver announcement on `CYPhaseView`.

## The type
```
enum CYPhase<Value, Failure> { idle, loading, loaded(Value), empty, failed(Failure, retry: (() -> Void)?) }
```
| From | Event | To | Guard |
|---|---|---|---|
| any | `load()` starts | `loading` | `generation` bumped first; unconfigured or signed-out readers stay `idle` |
| `loading` | read succeeds | `loaded(v)` / `empty` | `operation == generation` and request key still current |
| `loading` | read throws | `failed(e, retry)` | same guard; `CancellationError` never fails |
| `loading` | cancelled, screen left, superseded | `idle` | `settleLoading()`: only an in-flight `loading` falls back; `loaded`/`failed` are kept |
| `loaded`/`empty`/`failed` | reload, retry, refresh | `loading` | explicit user or identity event |

`CYPhaseView(phase:loadingLabel:emptyMessage:content:)` maps phases to the kit: `CYLoadingStateView` (skeleton), `CYEmptyState`, `CYErrorState` (retry), caller content.
Swaps cross-fade over `CYMotion.Duration.quick` (instant under Reduce Motion via `@QuestifyReduceMotion`). When a load ends it posts
one `UIAccessibility` announcement (failed: retry available; loaded; empty). The views below keep their screen-specific bodies (their error/empty
visuals differ from the kit) and use the enum with an exhaustive `switch`, or read-only computed `loading` / `issue` accessors where one phase is
only the fetch lifecycle of data held elsewhere (pagination, retained results).

## Migrated views

### TopicDetailView (`phase: CYPhase<TopicDetail, TopicScreenIssue>` + `loadedKey`)
Replaces `detail`, `issue`, `loading`.
| State | Renders |
|---|---|
| idle / loading, or `loadedKey != key` | `CYLoadingStateView(rows: 1)` |
| failed(issue) | `TopicIssueView` + retry |
| loaded(detail) | topic content |
| reader not configured (outside the machine) | `TopicIssueView(.notConfigured)` |
Events: `.task(id: key)`, retry, review composer saved, disappear. Guards: `generation`, `captured == key`, `!Task.isCancelled`.
Transitions: load start -> loading; success -> loaded; error -> failed; disappear while loading -> idle.

### ActivityDetailView (`phase: CYPhase<ActivityDetailAccess, Void>`)
Replaces `access`, `loading`, `failed`. `access` is now a computed view of `phase.value`.
| State | Renders |
|---|---|
| idle, loading | skeleton (keeps the `.task` host mounted) |
| failed | `CYStateArt(.failure)` + retry pill |
| loaded(.clubRequired) | club gate |
| loaded(.allowed) | activity detail |
Guards: `generation`, profile identity, gate reader/activity ids, presentation identity (a stale success leaves `idle`).

### SquareBrowserView (`phase: CYPhase<Void, Error>`)
Replaces `loading`, `issue`. Items stay in `pagination`, so a failed load-more keeps the list and shows the issue above it.
| State | Meaning |
|---|---|
| idle | no fetch in flight, no issue (also closed gate, unconfigured, signed-out) |
| loading | feed fetch; skeleton below the rows |
| loaded(()) | last page accepted |
| failed(error) | issue banner with retry; empty-state suppressed |
Guards: `reset || !loading`, community gate open, `generation`, `captured == key`. Reset clears pagination and issue.

### MessagingHistoryView (`phase`, `earlierPhase`: both `CYPhase<Void, MessagingLoadIssue>`)
Replaces `isLoading`, `issue`, `isLoadingEarlier`, `earlierIssue`. Two independent machines.
| Machine | States | Notes |
|---|---|---|
| transcript `phase` | loading (initial) -> loaded / failed / idle | terminal failure while paging earlier moves it to `failed` and drops the transcript |
| `earlierPhase` | idle -> loading -> idle / failed | non-terminal failure shows the "earlier failed" row with retry |
Guards: `isCurrent(request, identity, source)`, `!isLoading && !isLoadingEarlier` before paging, `generation`. Reload resets both machines.

### GlobalSearchView (`phase: CYPhase<Void, String>`)
Replaces `loading`, `issue`. Results live in `retainedResults`.
| State | Renders |
|---|---|
| idle / loaded | suggestions or results |
| loading | spinner row (results retained underneath) |
| failed(key) | `SearchMapIssue` with retry |
Events: keyword change / owner change -> idle; search -> loading -> loaded / failed; cancellation -> idle; disappear while loading -> idle.

### RoamBrowserView (`phase: CYPhase<Void, RoamScreenIssue>` + `loadedKey`)
Replaces `loading`, `issue`. Items live in `items`.
| State | Renders |
|---|---|
| loading, or `loadedKey != requestKey` | `CYSkeleton` |
| failed | `RoamStatusView` with retry |
| idle / loaded | map and list |
Guards: reader configured + identity + search area, `generation`, `key == requestKey`. Layer/radius change reloads.

## Not migrated (and why)
Most remaining 3+ flag hits in `viewstate-candidates.txt` (SessionHomeFeedView, MerchantOnboardingView, WalletCommerceViews, AccountView,
RegistrationSheetView, PlayExperienceView, ClubChannelMessagingView, MerchantCityNodeHubView) are independent sheet / confirmation presentation flags
(`showsX`), which are orthogonal by design, or already own an enum (`ClubChannelMessagingView.LoadPhase`, `WalletScreen`, `ChannelSendStateMachine`).
`PlayerJourneyViews` (rows + stale issue) needs a richer "stale data plus refresh banner" type and is left for a build-verified pass.
