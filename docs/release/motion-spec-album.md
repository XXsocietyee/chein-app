# Motion spec: collection album (HERO)

Code: `App/DesignSystem/CYAlbum.swift` (kit), wired into `RoamStampViews.swift` (stamp album), `ObjectBadgeViews.swift` + `ObjectBadgeWallParityViews.swift` (badge wall) and `ObjectCardViews.swift` (object cards). Fixtures: `--design-fixture album-*` (DEBUG, `App/DesignFixtures/AlbumFixtures.swift`). Extends `docs/release/motion-spec.md`; every rule there (durations, Reduce Motion, one haptic per outcome, 120 ms cooldown) still applies.

## Idea
The three collections are one object: an album you leaf through. Pages turn on a spine, a card flips to show its back, unlocked pieces catch the light, locked pieces are grey silhouettes waiting, a fresh piece pulses once, and the album cover counts how full it is. Nothing loops forever; every effect explains a state (collected, locked, new, progress) or confirms a touch (flip, page, unlock).

## System
| Piece | API | What moves | Driver | Reduce Motion |
|---|---|---|---|---|
| Page turn | `CYAlbumPager(items:height:pageLabel:page:)` | each page rotates on its spine up to 42° (`rotation3DEffect`, anchor leading/trailing, perspective 0.7), scales to 0.94, darkens 22 % as it leaves | the scroll (`scrollTransition(.interactive)`), `.viewAligned` paging | plain paging, no rotation |
| Flip card | `CYFlipCard(flipped:flipActionTitle:front:back:)` | front turns 0→90°, back lands 90→180° (pre-rotated so text reads); face swap exactly at 90° via an `Animatable` modifier | tap, or VoiceOver action "flip"; spring 0.55 / 0.78 | 0.18 s cross-fade, no rotation |
| Foil sheen | `.cyFoilSheen(active:trigger:cornerRadius:)` | 22° white band sweeps left→right once (`screen` blend) | appear, or `trigger` change (flip, page land); 1.1 s ease-in-out after 0.25 s | static soft top-left highlight |
| Locked silhouette | `.cyLockedSilhouette(_:cornerRadius:showsLock:)` | none (state): saturation 0, contrast 0.85, opacity 0.62, dashed rim, lock chip | — | same (not motion) |
| New pulse | `CYNewPulseBadge` / `.cyNewPulse(_:text:)` | gold "NEW" capsule; halo breathes 3 × 1.3 s then rests | appear | static capsule |
| Progress ring | `CYAlbumProgressRing(value:total:size:accessibilityLabel:)` | gold ring fills and the number counts up together, 0.9 s ease-out; unknown total = dim track and a dash | appear, value change | final state at once |
| Unlock moment | `.cyUnlockCelebration(trigger:)` | 26-piece confetti (1.9 s) + one ring pulse (0.6 s) + `.success` haptic | first open of a collectible that is `new` and not yet `seen` | haptic only |
| Shared-element zoom | `cyHeroSource` / `cyHeroDestination` (E1 kit) | tile zooms into the detail | tap on a tile (iOS 18+) | default push |

Tokens live in `CYAlbumMotion` (`pageTurnAngle`, `flip`, `sheen`, `countUp`, `pulse`, `gold`, `amber`). Gold is the only metallic colour in the app; medals, rings and the NEW capsule share it.

## Facts, not nudges
- **New** = collected within 7 days by the server date (`CYAlbumRecency.isNew`). Unparsable or missing dates are never new.
- **Seen** = `@CYAlbumSeen` (local `AppStorage`, ids only, capped at 500). The pulse and the unlock moment play once per item, then stop. Nothing is sent anywhere.
- **Progress** = received rows only: stamps `loaded / total` from the album page, badges `unlocked / (identities + medals)`. A failed medal read (partial wall) hides the ring instead of showing zero.
- **Locked** only exists where the API says so (identity badges). Stamps and medals are earned the moment they exist.
- **Foil** on object cards follows the API's `cardStyle` (`foil` vs `plain`), not a guess.

## Haptics (additions to the E1 map)
| Case | Where |
|---|---|
| `.selection` | flip card turn, album page land |
| `.success` | unlock moment (first open of a new collectible) |
Each once per user-visible change; `sensoryFeedback` on a state change, never in a loop.

## Where it is wired
| Screen | Pager | Flip | Sheen | Silhouette | New | Ring | Unlock | Zoom |
|---|---|---|---|---|---|---|---|---|
| Stamp album (`RoamStampAlbumView`) | recent stamps (≤ 6) | page front = art, back = number/date/caption | grid tiles + pages | n/a (no locked stamps) | stamps ≤ 7 days | collected / total | n/a | tile → stamp detail |
| Badge wall (`ObjectBadgeWallView`, wall layout) | unlocked showcase (≤ 8) | page front = medal, back = how it was earned | unlocked tiles + pages | locked identity badges | unlocked ≤ 7 days, until opened | unlocked / total (hidden when partial) | detail, first open of a new badge | tile → badge detail |
| Badge detail (`ObjectBadgeDetailView`) | — | stage front = medal, back = obtained date + condition | medal | locked medal | — | — | yes | destination |
| Object cards (`ObjectCardsView`) | — | detail: front = artwork (drag still rotates frames), back = facts | foil cards only | n/a | — | — | — | tile → card detail |

## Accessibility
- Pager dots are one adjustable element ("page n of m", swipe up/down to turn). Pages keep their own labels.
- Flip card exposes the visible face only (the hidden face is `accessibilityHidden`) and a custom action named "flip"/"翻面".
- Ring, sheen, halo, confetti and silhouette chrome are hidden; the state is always also in text (status chip, "collected", "locked", "new").
- Dynamic Type: pages and tiles use kit text styles, wrap, and the grid drops to one column at accessibility sizes (`CYCollectionGrid`). The ring number scales with the ring only (decorative); the sentence next to it scales normally.

## Verification
Stills cannot show motion. DEBUG fixtures `album-kit` (every piece and state), `album-stamps`, `album-badges`, `album-badges-new` (fresh unlock: pulse + first-open moment), `album-badges-locked`, `album-cards`, `album-unlock`; add `--uitesting-reduce-motion` to see the fallbacks (plain paging, cross-fade flip, static highlight, no confetti).
