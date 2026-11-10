# Motion spec: loading-to-content choreography (all lists)

Branch `ui/e4`. Advisor input: `/Users/fanning/chengyin-refs/specs/motion-system.md` (sections "Global tokens" and "Subsystem C"). The advisor text is advice; this file records what was built and where it differs. Code only, cloud-verified, no behaviour change (no Core, Tests or Config edits, no new catalog keys).

Code: `App/DesignSystem/CYLoadingChoreography.swift` (new kit), `App/DesignSystem/CYMotion.swift`, `App/DesignSystem/CYPhase.swift`, `App/DesignFixtures/E4LoadingFixtures.swift`.

## Kit
| Piece | What it does | Reduce Motion |
| --- | --- | --- |
| `CYMotion.Duration` | Four steps: `instant` 0.12, `quick` 0.20, `standard` 0.35, `slow` 0.60. `emphasized` stays as an alias of `standard`, so no caller breaks | n/a |
| `CYPhaseView` (changed) | Skeleton shows only after 120 ms of loading, stays at least 350 ms once shown, then cross-fades to the phase over `quick`. Explicit init (adds `loadingIdentifier`). Skeleton is top-aligned and labelled | skeleton still shown (it is information), swap is instant |
| `cySkeletonTiming(isLoading:visible:)` | The 120 ms / 350 ms rule as a modifier, for List screens that cannot sit inside a `CYPhaseView` | n/a |
| `CYLoadSlot` | `CYPhaseView<Void, Never>` for screens that keep their own empty / failure UI and only expose a loading flag. Wraps the whole branch chain so the cross-fade has both sides | as above |
| `CYListChoreography` | `CYPhaseView` + `LazyVStack` of rows; first six rows `cyStaggeredAppear` once per instance (`CYStaggerGate`), rows diff with `cyRowTransition`, skeleton rows capped at six | rows at once, fade only |
| `CYStatNumber` | Header stat; changed digits roll (`numericText`), same pattern as `CYAnimatedPrice`. `rollsOnAppear` rolls up from zeros only when the value has at most four digits | 0.20 s cross-fade, no roll from zero |
| `CYSegmentedContent` | In-screen tab swap: outgoing fades 0.20 s, incoming fades and rises 8 pt; one `.selection` haptic (`haptic: false` when the picker already plays one); posts `.layoutChanged` | cross-fade only |

## Adoption (8 screens, every list loads the same way)
| Screen | Where | How |
| --- | --- | --- |
| Club directory (and every `ClubReadScreen` list) | `ClubReadScreen.swift` | `CYLoadSlot` around the branch chain; `.loading` identifier kept; directory rows already stagger |
| Messages (and every `MessagingReadScreen`) | `MessagingComponents.swift` | `CYLoadSlot`; both old loading branches (`CYSkeleton`, `ProgressView`) now `Color.clear` inside the slot |
| Orders (and every `ProfileReadScreen`) | `ProfileReadScreen.swift` | `CYLoadSlot`; screen-specific loading key kept |
| Notices (and every `OfficialReadScreen`) | `OfficialEventComponents.swift` | `CYLoadSlot` |
| Favorites (topics and posts) | `AccountCollectionFavoritesView.swift` | `cySkeletonTiming` + `CYLoadingStateView`, topic rows stagger |
| Home feed | `HomeFeedView.swift` | `CYLoadSlot` for the shell, timed skeleton for the first stream page, stream rows stagger |
| Search results | `GlobalSearchView.swift` | timed skeleton, results hidden while it is held, result rows stagger |
| Wallet stats | `WalletEarningsOverview.swift`, `WalletIncomeAnalysisView.swift` | `CYStatNumber` on the withdrawable amount and the month headline |

## Differences from the advisor spec
- Durations: the advisor proposed aliasing `quick/standard/emphasized` (0.18/0.25/0.35) onto the grid. Done as `quick` 0.20, `standard` 0.35, `emphasized = standard`. Two existing `Duration.standard` callers (`OfficialRouteViews`, `ActivityBrowserView`) therefore move from 0.25 s to 0.35 s; `CYContentSwap` moved from 0.25 s to `quick` 0.20 s to match the crossfade rule.
- The advisor `CYListChoreography` took a `CYPhase<[Item], Error>` and a `phase.kind`-keyed `.task`. The real one delegates all timing to `CYPhaseView` so there is a single implementation, and `Failure` stays generic.
- Almost no screen has a `CYPhase<[Item], _>`: they own their own state and empty / failure UI. `CYLoadSlot` and `cySkeletonTiming` map those loading flags on without touching empty / failure behaviour; `CYListChoreography` is available for new lists and is exercised by the fixture.
- List-based screens (home stream, search, favorites) cannot wrap `List` rows in a `CYPhaseView` ZStack without losing row semantics, so they use the same timing rule through `cySkeletonTiming` and a `.transition(.opacity)` placeholder inside the list.
- `CYStatNumber` takes `font` and `color` (the advisor hard-coded `data2XL`) and sets the VoiceOver label to the final string.
- Reload keeps content (no skeleton) only where the host screen already did; `CYPhaseView` itself replaces content with the skeleton while `.loading`, as before. The 120 ms rule makes a fast reload invisible.
- Not done: shimmer (the only looping decoration the spec allows) and `matchedGeometryEffect` on a tab indicator; those need a design pass of their own. Wallet income-analysis loading, the funds-stage `ProgressView` and the home rails keep their existing placeholders.
- VoiceOver announcements: `CYPhaseView` announces "Loaded" / "Nothing here yet" / "Couldn't load" when a load ends. Slots on one screen announce from only one (`announces:`); the held skeleton does not delay the announcement.

## Fixture
`--design-fixture motion-lab-loading` (DEBUG, offline, timer-driven): first load (700 ms: skeleton, hold, cross-fade, six-row stagger), tab swap (`CYSegmentedContent`), fast reload (50 ms: no skeleton), slow reload, rolling header stat; loops forever. The step name is printed above the stat.
