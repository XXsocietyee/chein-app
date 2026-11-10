# Motion and haptics spec (E1)

Code: `App/DesignSystem/CYMotion.swift`. Lab: `--design-fixture e1-motion-hero | e1-motion-list | e1-motion-scroll` (DEBUG, 8 s loops with a timeline). Clips: `design-reports/e1/*.mp4`.

## Principles
1. Motion explains, never decorates: it shows where something came from (card to detail), that a touch registered (press), or that content arrived (fade, stagger).
2. Short and interruptible: 0.18 to 0.35 s. Navigation and reads never wait for an animation.
3. Reduce Motion is a first-class path: system setting, in-app setting, or DEBUG `--uitesting-reduce-motion` (all through `@QuestifyReduceMotion`). Fallback is an instant change or a 0.18 s cross-fade; no scale, slide, parallax or zoom.
4. Reduce Transparency: sticky material bars become the solid elevated surface.
5. Haptics confirm, they do not narrate: one per user-visible outcome, 120 ms cooldown.

Apple HIG basis: Motion ("use motion to communicate; make motion optional; keep it brief and precise"), Accessibility > Motion (replace large movement and zoom with cross-fades, support Reduce Motion), Playing haptics ("use system haptics consistently for their meaning; don't overuse"), Pull to refresh and Loading (show content-shaped placeholders, not blank).

## Durations
| Token | Value | Used for |
|---|---|---|
| `CYMotion.Duration.quick` | 0.18 s | fades, scroll reveal, Reduce Motion cross-fade, sticky bar |
| `.standard` | 0.25 s | skeleton to content, list state swap |
| `.emphasized` | 0.35 s | entrance (empty state, staggered cards) |
| hero zoom | system (about 0.35 s) | card to detail |

## Springs
| Token | response / damping | Used for |
|---|---|---|
| `press` | 0.12 / 0.90 | touch-down scale to 0.97 |
| `release` | 0.25 / 0.70 | touch-up, slight overshoot |
| `standard` | 0.30 / 0.85 | insert, delete, reorder |
| `entrance` | 0.35 / 0.80 | empty state, stagger (50 ms apart, max 6 items, once per screen) |
| `reduced` | ease-in-out 0.18 | every Reduce Motion replacement |

## Components
| Piece | API | Reduce Motion fallback |
|---|---|---|
| Press feedback | `CYPressableStyle` / `.cyPressable()`; built into `CYPillButton`, `CYImageCard`, `CYListRow` (`cyPressTracking`), `QuestifyCardButtonStyle` | dim to 0.7, no scale |
| Hero transition | `cyHeroSource` + `cyHeroDestination` (`matchedTransitionSource`, `navigationTransition(.zoom)`), iOS 18+ via `#available`; iOS 17 default push | default push |
| Parallax / stretch | `cyHeroParallax(height:)` (`visualEffect`) | static |
| Card reveal at edges | `cyScrollReveal()` (`scrollTransition`) | none |
| Sticky header | `cyStickyHeader {}`, material blur fades in once content scrolls under it (iOS 18 `onScrollGeometryChange`) | solid surface under Reduce Transparency; fade is quick anyway |
| Large title collapse | native `.navigationBarTitleDisplayMode(.large)` | system |
| Stagger | `cyStaggeredAppear(index:gate:)` | appears at once |
| Insert / delete | `cyRowTransition()` + `cyAnimation(value: ids)` | fade only |
| Skeleton to content | `CYContentSwap`, state switches animated with `cyAnimation` | instant |
| Pull to refresh | `cyRefreshable` (light tick on trigger, spinner floor 0.45 s, no skeleton flash on refresh) | same (not motion) |
| Empty state | `cyEntrance` inside `CYEmptyState` (icon scale 0.8, text rise) | appears at once |

## Haptics map (`CYHaptics`, the only place that picks a generator)
| Case | Where |
|---|---|
| `.selection` | tab change (`QuestifyApp` player tabs), chips and segments, hero banner page, city selection, consent check |
| `.success` | join / welcome arrival, badge unlock, stamp, consent agree, outcome applied, newly lit badges |
| `.warning` | blocked registration tap |
| `.impactLight` | pull-to-refresh trigger, list delete (lab) |
| `.impactMedium` | dice roll, welcome primary press |
| `.impactHeavy` | GO press, collectible stamp landing |
Use `.cyHaptic(_, trigger:)` in views and `CYHaptics.x.play()` in non-view code.

## Screens wired in E1
| Screen | Hero zoom | Press | Stagger | Skeleton fade | Refresh | Insert/delete |
|---|---|---|---|---|---|---|
| Official routes list to detail | yes | yes | yes | yes | yes | n/a |
| Activity browser to detail | yes | yes | yes | yes | yes | yes |
| Bundle shelf | source only: the host uses `onSelect`, pass `heroNamespace` and `cyHeroDestination` if it pushes with a NavigationLink | yes | yes | yes | yes | yes |
| Club directory to detail | yes | yes | yes | (kit) | (kit) | n/a |
| Empty states (all) | | | | | | entrance |

## Benchmarks (Mobbin stills; motion itself is not capturable, see HIG above)
- Expedia detail hero with floating save and primary pill, content that a zoom lands on: https://mobbin.com/screens/a1be0e87-676c-4ea9-bed0-7188e8b06949
- Swiggy card-shaped skeleton (same silhouette as the loaded cards, so the cross-fade does not jump): https://mobbin.com/screens/157d2a19-df5e-4eb7-9cf4-0e134d591baa
- Airbnb Explore skeleton (photo block + two lines, chips kept real): https://mobbin.com/screens/511f785b-c4a3-49c4-8e30-caf824b037ff
- Perplexity Discover loading (large rounded photo placeholders): https://mobbin.com/screens/66081153-ddf2-42a1-8efa-a16a80c14731
- Jomo empty state (one illustration, one line, one pill: the entrance animates exactly these three): https://mobbin.com/screens/f411397c-dd78-42b5-a0be-459254324774
- talabat empty cart (icon over title over secondary pill): https://mobbin.com/screens/be84c29b-7400-467d-b736-d722ca4d5414

## Verification
Stills cannot show motion. Use the lab clips. With `--uitesting-reduce-motion` the hero lab shows a plain push and a dim instead of scale.
